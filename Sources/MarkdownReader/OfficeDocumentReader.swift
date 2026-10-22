import AppKit
import Quartz
import PDFKit
import SwiftUI

/// Reading formats rendered by macOS, without changing the original document.
enum OfficeReadingFormat {
    static let extensions: Set<String> = ["doc", "docx", "pages"]
    static func supports(_ url: URL) -> Bool { extensions.contains(url.pathExtension.lowercased()) }
}

@MainActor
final class OfficePreviewState {
    var url: URL?
    var displayState: Any?
    var document: PDFDocument?
    var destination: PDFDestination?
    func clear() {
        url = nil
        displayState = nil
        document = nil
        destination = nil
    }
    func reset(for url: URL) {
        guard self.url != url else { return }
        self.url = url
        displayState = nil
        document = nil
        destination = nil
    }
}

@MainActor
final class OfficePDFView: PDFView {
    var onActivate: (() -> Void)?
    override func mouseDown(with event: NSEvent) {
        WorkspaceMouseDownHandling.perform(nativeMouseDown: { super.mouseDown(with: event) },
            activateWorkspace: { [weak self] in self?.onActivate?() })
    }
}

/// Selectable PDF pages are the preferred reader. Native Quick Look is retained
/// as a readable fallback for documents for which macOS cannot generate pages.
@MainActor
final class OfficePreviewContainer: NSView {
    let pdfView = OfficePDFView()
    let scrollView = NSScrollView()
    let canvas = NSView()
    private(set) var previewView: QLPreviewView?
    let status = NSTextField(labelWithString: "正在准备分页预览…")
    let spinner = NSProgressIndicator()
    var showsPDF: Bool { pdfView.document != nil }

    override init(frame: NSRect) {
        super.init(frame: frame)
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.autoScales = false
        pdfView.minScaleFactor = 0.25
        pdfView.maxScaleFactor = 5
        pdfView.isHidden = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.25
        scrollView.maxMagnification = 5
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = canvas
        scrollView.isHidden = true
        spinner.style = .spinning
        status.alignment = .center
        status.font = .systemFont(ofSize: 12)
        status.textColor = .secondaryLabelColor
        addSubview(scrollView)
        addSubview(pdfView)
        addSubview(status)
        addSubview(spinner)
        spinner.startAnimation(nil)
    }
    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        pdfView.frame = bounds
        scrollView.frame = bounds.insetBy(dx: 0, dy: status.isHidden ? 0 : 18)
        canvas.frame = NSRect(origin: .zero, size: scrollView.contentView.frame.size)
        previewView?.frame = canvas.bounds
        status.frame = NSRect(x: 8, y: bounds.midY - 35, width: max(0, bounds.width - 16), height: 22)
        if !scrollView.isHidden { status.frame.origin.y = bounds.height - 24 }
        spinner.frame = NSRect(x: bounds.midX - 12, y: bounds.midY, width: 24, height: 24)
    }

    func show(_ document: PDFDocument, destination: PDFDestination?, zoom: Double) {
        pdfView.document = document
        pdfView.isHidden = false
        scrollView.isHidden = true
        status.isHidden = true
        spinner.stopAnimation(nil)
        spinner.isHidden = true
        WorkspaceKeyboardFocus.readingView = pdfView
        setZoom(zoom)
        if let destination { DispatchQueue.main.async { [weak self] in self?.pdfView.go(to: destination) } }
    }

    func showFallback(_ source: URL, displayState: Any?) {
        if previewView == nil {
            let preview = QLPreviewView(frame: canvas.bounds, style: .normal)!
            preview.shouldCloseWithWindow = false
            canvas.addSubview(preview)
            previewView = preview
        }
        guard let previewView else { return }
        previewView.previewItem = source as NSURL
        if let displayState { previewView.displayState = displayState }
        scrollView.isHidden = false
        status.stringValue = "分页预览不可用，已使用系统原格式预览。"
        spinner.stopAnimation(nil)
        spinner.isHidden = true
        WorkspaceKeyboardFocus.readingView = previewView
        needsLayout = true
    }

    func setZoom(_ percent: Double) {
        let scale = min(5, max(0.25, percent / 100))
        if showsPDF {
            if abs(pdfView.scaleFactor - scale) > 0.001 { pdfView.scaleFactor = scale }
        } else if abs(scrollView.magnification - scale) > 0.001 {
            let visible = scrollView.documentVisibleRect
            scrollView.setMagnification(scale, centeredAt: NSPoint(x: visible.midX, y: visible.midY))
        }
    }
}

struct OfficeDocumentReader: NSViewRepresentable {
    let url: URL
    let state: OfficePreviewState
    @Binding var zoomPercent: Double
    let onActivate: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

    func makeNSView(context: Context) -> OfficePreviewContainer {
        let view = OfficePreviewContainer(frame: .zero)
        context.coordinator.attach(view, onZoomChange: { zoomPercent = $0 })
        return view
    }

    func updateNSView(_ view: OfficePreviewContainer, context: Context) {
        view.pdfView.onActivate = onActivate
        context.coordinator.load(url, in: view, zoom: zoomPercent)
        view.setZoom(zoomPercent)
        if view.showsPDF { WorkspaceKeyboardFocus.readingView = view.pdfView }
    }

    static func dismantleNSView(_ view: OfficePreviewContainer, coordinator: Coordinator) {
        coordinator.state.displayState = view.previewView?.displayState
        coordinator.state.destination = view.pdfView.currentDestination
        coordinator.detach()
        view.previewView?.close()
    }

    @MainActor final class Coordinator {
        let state: OfficePreviewState
        var loadedURL: URL?
        var latestZoom = 100.0
        var observers: [NSObjectProtocol] = []
        var task: Task<Void, Never>?
        var onZoomChange: (@MainActor (Double) -> Void)?
        init(state: OfficePreviewState) { self.state = state }
        func attach(_ view: OfficePreviewContainer, onZoomChange: @escaping @MainActor (Double) -> Void) {
            self.onZoomChange = onZoomChange
            observers.append(NotificationCenter.default.addObserver(forName: NSScrollView.didEndLiveMagnifyNotification,
                object: view.scrollView, queue: .main) { [weak self, weak view] _ in
                    Task { @MainActor in
                        guard let view else { return }
                        self?.onZoomChange?((view.scrollView.magnification * 100).rounded())
                    }
                })
            observers.append(NotificationCenter.default.addObserver(forName: .PDFViewScaleChanged,
                object: view.pdfView, queue: .main) { [weak self, weak view] _ in
                    Task { @MainActor in
                        guard let view, view.showsPDF else { return }
                        self?.onZoomChange?((view.pdfView.scaleFactor * 100).rounded())
                    }
                })
        }
        func detach() {
            task?.cancel()
            task = nil
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
        }
        func load(_ url: URL, in view: OfficePreviewContainer, zoom: Double) {
            latestZoom = zoom
            guard loadedURL != url else { return }
            task?.cancel()
            state.reset(for: url)
            loadedURL = url
            if let document = state.document {
                view.show(document, destination: state.destination, zoom: zoom)
                return
            }
            task = Task { @MainActor [weak self, weak view] in
                do {
                    let pdfURL = try await OfficePreviewRenderer().render(url)
                    try Task.checkCancellation()
                    guard let self, let view, self.loadedURL == url,
                          let document = PDFDocument(url: pdfURL), document.pageCount > 0 else { return }
                    self.state.document = document
                    view.show(document, destination: nil, zoom: self.latestZoom)
                } catch is CancellationError { }
                catch {
                    guard let self, let view, self.loadedURL == url else { return }
                    view.showFallback(url, displayState: self.state.displayState)
                    view.setZoom(self.latestZoom)
                }
            }
        }
    }
}

/// Keep both panes mounted so switching tabs does not reload the reading engine.
struct RetainedWorkspaceTabs<Reading: View, Notes: View>: View {
    let showsNotes: Bool
    let reading: Reading
    let notes: Notes
    var body: some View {
        ZStack {
            reading.opacity(showsNotes ? 0 : 1)
                .allowsHitTesting(!showsNotes).accessibilityHidden(showsNotes)
            notes.opacity(showsNotes ? 1 : 0)
                .allowsHitTesting(showsNotes).accessibilityHidden(!showsNotes)
        }
    }
}

@MainActor
enum WorkspaceKeyboardFocus {
    static weak var readingView: NSView?

    static func containsFirstResponder(_ view: NSView?) -> Bool {
        guard let view, let responder = view.window?.firstResponder as? NSView else { return false }
        return responder === view || responder.isDescendant(of: view)
    }

    static var readingHasFocus: Bool { containsFirstResponder(readingView) }

    @discardableResult
    static func focusReading() -> Bool {
        guard let view = readingView, let window = view.window else { return false }
        func focus(_ candidate: NSView) -> Bool {
            if candidate.acceptsFirstResponder && window.makeFirstResponder(candidate) { return true }
            for child in candidate.subviews where focus(child) { return true }
            return false
        }
        return focus(view)
    }
}
