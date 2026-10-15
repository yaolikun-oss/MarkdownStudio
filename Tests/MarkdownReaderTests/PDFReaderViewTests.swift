import AppKit
import PDFKit
import SwiftUI
import Testing
@testable import MarkdownReader

@Suite struct PDFReaderViewTests {
    @Test @MainActor func initialPDFKitPositionDoesNotReplaceSavedProfileWhileLoading() async throws {
        let document = try #require(makeDocument())
        var pageIndex = 0
        var position: PDFReadingPosition?
        var zoom = 100.0
        let reader = PDFReaderView(
            document: document,
            zoomPercent: Binding(get: { zoom }, set: { zoom = $0 }),
            currentPageIndex: Binding(get: { pageIndex }, set: { pageIndex = $0 }),
            readingPosition: Binding(get: { position }, set: { position = $0 }),
            documentID: "test.pdf", navigationRequest: 0,
            isReadingProfileLoading: true, backgroundColor: .white, onActivate: {})
        let coordinator = PDFReaderView.Coordinator(parent: reader)
        let pdfView = PDFView(frame: NSRect(x: 0, y: 0, width: 600, height: 800))
        pdfView.document = document
        coordinator.attach(to: pdfView)
        defer { coordinator.detach() }

        coordinator.schedulePositionSave()
        try await Task.sleep(for: .milliseconds(450))
        #expect(position == nil)

        let saved = PDFReadingPosition(documentID: "test.pdf", pageIndex: 2, x: 30, y: 300)
        position = saved
        coordinator.restoreReadingPosition(saved, in: pdfView)
        try await Task.sleep(for: .milliseconds(100))
        #expect(document.index(for: try #require(pdfView.currentPage)) == 2)
        #expect(coordinator.readingPosition(in: pdfView)?.pageIndex == 2)
    }

    @MainActor private func makeDocument() -> PDFDocument? {
        let document = PDFDocument()
        for index in 0..<3 {
            let image = NSImage(size: NSSize(width: 500, height: 700))
            image.lockFocus()
            NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: 500, height: 700).fill()
            ("Page \(index + 1)" as NSString).draw(at: NSPoint(x: 40, y: 640),
                                                    withAttributes: [.font: NSFont.systemFont(ofSize: 24)])
            image.unlockFocus()
            guard let page = PDFPage(image: image) else { return nil }
            document.insert(page, at: index)
        }
        return document
    }
}
