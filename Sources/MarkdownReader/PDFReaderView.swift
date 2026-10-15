import AppKit
import PDFKit
import SwiftUI

struct PDFReaderView: NSViewRepresentable {
    let document: PDFDocument
    @Binding var zoomPercent: Double
    @Binding var currentPageIndex: Int
    @Binding var readingPosition: PDFReadingPosition?
    let documentID: String
    let navigationRequest: Int
    let isReadingProfileLoading: Bool
    let backgroundColor: Color
    let onActivate: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> PDFView {
        let view = ActivatingPDFView(frame: .zero)
        view.onActivate = onActivate
        view.document = document
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displayBox = .cropBox
        view.displaysPageBreaks = true
        view.pageBreakMargins = NSEdgeInsets(top: 14, left: 8, bottom: 14, right: 8)
        view.backgroundColor = NSColor(backgroundColor)
        view.autoScales = true
        view.minScaleFactor = 0.25
        view.maxScaleFactor = 5
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        context.coordinator.parent = self
        (view as? ActivatingPDFView)?.onActivate = onActivate
        view.backgroundColor = NSColor(backgroundColor)
        let isFirstUpdate = context.coordinator.lastNavigationRequest == -1
        if view.document !== document {
            view.document = document
            view.autoScales = true
            context.coordinator.lastNavigationRequest = navigationRequest
            context.coordinator.restoredDocumentID = nil
            // The owner resets these when opening a new PDF. Clearing them here
            // can erase a profile that finished loading before this view update.
        }

        if !isFirstUpdate && context.coordinator.lastNavigationRequest != navigationRequest {
            context.coordinator.lastNavigationRequest = navigationRequest
            let safeIndex = min(max(0, currentPageIndex), max(0, document.pageCount - 1))
            if let page = document.page(at: safeIndex) { view.go(to: page) }
        }

        let requestedZoom = min(300, max(25, zoomPercent))
        if abs(context.coordinator.lastAppliedZoom - requestedZoom) > 0.5 {
            context.coordinator.applyZoom(requestedZoom, to: view)
        }

        if isFirstUpdate {
            context.coordinator.lastNavigationRequest = navigationRequest
        }
        if context.coordinator.restoredDocumentID != documentID,
           let readingPosition, readingPosition.documentID == documentID {
            context.coordinator.restoreReadingPosition(readingPosition, in: view)
            context.coordinator.restoredDocumentID = documentID
        } else if context.coordinator.wasReadingProfileLoading && !isReadingProfileLoading {
            context.coordinator.schedulePositionSave()
        }
        context.coordinator.wasReadingProfileLoading = isReadingProfileLoading
    }

    static func dismantleNSView(_ view: PDFView, coordinator: Coordinator) {
        if !coordinator.parent.isReadingProfileLoading,
           let position = coordinator.readingPosition(in: view) {
            let positionBinding = coordinator.parent.$readingPosition
            DispatchQueue.main.async { positionBinding.wrappedValue = position }
        }
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: PDFReaderView
        weak var pdfView: PDFView?
        var lastNavigationRequest = -1
        var lastAppliedZoom = 100.0
        var restoredDocumentID: String?
        var wasReadingProfileLoading = false
        private var observers: [NSObjectProtocol] = []
        private var positionSaveTask: Task<Void, Never>?

        init(parent: PDFReaderView) { self.parent = parent }

        func attach(to view: PDFView) {
            pdfView = view
            view.layoutSubtreeIfNeeded()
            let center = NotificationCenter.default
            observers.append(center.addObserver(forName: .PDFViewPageChanged, object: view, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.publishCurrentPage() }
            })
            observers.append(center.addObserver(forName: .PDFViewScaleChanged, object: view, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.publishCurrentZoom() }
            })
            if let scrollView = Self.findScrollView(in: view) {
                scrollView.postsBoundsChangedNotifications = true
                observers.append(center.addObserver(forName: NSView.boundsDidChangeNotification,
                                                    object: scrollView, queue: .main) { [weak self] _ in
                    Task { @MainActor in self?.schedulePositionSave() }
                })
            }
        }

        func detach() {
            positionSaveTask?.cancel()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
        }

        func applyZoom(_ percent: Double, to view: PDFView) {
            lastAppliedZoom = percent
            if percent == 100 {
                view.autoScales = true
                return
            }
            view.autoScales = false
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view else { return }
                let fitScale = view.scaleFactorForSizeToFit
                guard fitScale.isFinite, fitScale > 0 else { return }
                view.scaleFactor = min(view.maxScaleFactor, max(view.minScaleFactor, fitScale * percent / 100))
                self.publishCurrentZoom()
            }
        }

        func restoreReadingPosition(_ position: PDFReadingPosition?, in view: PDFView) {
            guard let position, position.documentID == parent.documentID else { return }
            positionSaveTask?.cancel()
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view,
                      self.parent.documentID == position.documentID,
                      let page = view.document?.page(at: position.pageIndex) else { return }
                view.layoutSubtreeIfNeeded()
                let destination = PDFDestination(page: page, at: NSPoint(x: position.x, y: position.y))
                view.go(to: destination)
                self.publishCurrentPage()
            }
        }

        func readingPosition(in view: PDFView) -> PDFReadingPosition? {
            guard let page = view.currentPage, let document = view.document else { return nil }
            let pageIndex = document.index(for: page)
            // In continuous mode, currentDestination can still refer to the
            // preceding page while currentPage (and the toolbar) have advanced.
            // Keep the stored page consistent with the visible page.
            let point: NSPoint
            if let destination = view.currentDestination, destination.page === page,
               destination.point.x.isFinite, destination.point.y.isFinite {
                point = destination.point
            } else {
                let bounds = page.bounds(for: view.displayBox)
                point = NSPoint(x: bounds.minX, y: bounds.maxY)
            }
            guard pageIndex >= 0, point.x.isFinite, point.y.isFinite else { return nil }
            return PDFReadingPosition(documentID: parent.documentID, pageIndex: pageIndex,
                                      x: point.x, y: point.y)
        }

        private func publishCurrentPage() {
            guard let view = pdfView, let page = view.currentPage,
                  let document = view.document else { return }
            let index = document.index(for: page)
            if index >= 0, parent.currentPageIndex != index { parent.currentPageIndex = index }
            schedulePositionSave()
        }

        func schedulePositionSave() {
            guard !parent.isReadingProfileLoading else { return }
            positionSaveTask?.cancel()
            positionSaveTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled, let self, let view = self.pdfView,
                      let position = self.readingPosition(in: view) else { return }
                self.parent.readingPosition = position
            }
        }

        private static func findScrollView(in view: NSView) -> NSScrollView? {
            if let scrollView = view as? NSScrollView { return scrollView }
            for child in view.subviews { if let found = findScrollView(in: child) { return found } }
            return nil
        }

        private func publishCurrentZoom() {
            guard let view = pdfView else { return }
            if view.autoScales {
                if parent.zoomPercent != 100 { parent.zoomPercent = 100 }
                lastAppliedZoom = 100
                return
            }
            let fitScale = view.scaleFactorForSizeToFit
            guard fitScale.isFinite, fitScale > 0 else { return }
            let percent = min(300, max(25, (view.scaleFactor / fitScale * 100).rounded()))
            lastAppliedZoom = percent
            if parent.zoomPercent != percent { parent.zoomPercent = percent }
        }
    }
}

struct PDFReadingPosition: Equatable {
    let documentID: String
    let pageIndex: Int
    let x: CGFloat
    let y: CGFloat
}

@MainActor
private final class ActivatingPDFView: PDFView {
    var onActivate: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onActivate?()
        super.mouseDown(with: event)
    }
}

struct PDFBookmarkItem: Identifiable {
    let id: String
    let title: String
    let pageIndex: Int?
    let children: [PDFBookmarkItem]?
}

extension PDFDocument {
    var markdownStudioBookmarks: [PDFBookmarkItem] {
        guard let root = outlineRoot else { return [] }

        func convert(_ outline: PDFOutline, path: String) -> PDFBookmarkItem {
            let children = (0..<outline.numberOfChildren).compactMap { index -> PDFBookmarkItem? in
                guard let child = outline.child(at: index) else { return nil }
                return convert(child, path: "\(path).\(index)")
            }
            let pageIndex = outline.destination?.page.map { self.index(for: $0) }
                .flatMap { $0 >= 0 ? $0 : nil }
            let title = outline.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return PDFBookmarkItem(id: path, title: title.isEmpty ? "未命名书签" : title,
                                  pageIndex: pageIndex, children: children.isEmpty ? nil : children)
        }

        return (0..<root.numberOfChildren).compactMap { index in
            root.child(at: index).map { convert($0, path: "bookmark.\(index)") }
        }
    }
}
