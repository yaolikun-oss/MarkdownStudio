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
            displayPresetRequest: .init(sequence: 0, preset: .fitWidth),
            isReadingProfileLoading: true, backgroundColor: .white, onActivate: {})
        let coordinator = PDFReaderView.Coordinator(parent: reader)
        #expect(coordinator.lastDisplayPresetSequence == 0)
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

    @Test @MainActor func fitWidthRecalculatesAfterReaderResize() throws {
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
            displayPresetRequest: .init(sequence: 1, preset: .fitWidth),
            isReadingProfileLoading: true, backgroundColor: .white, onActivate: {})
        let coordinator = PDFReaderView.Coordinator(parent: reader)
        #expect(coordinator.lastDisplayPresetSequence == 1)
        let pdfView = PDFView(frame: NSRect(x: 0, y: 0, width: 600, height: 800))
        pdfView.document = document
        pdfView.displayBox = .cropBox
        pdfView.pageBreakMargins = NSEdgeInsets(top: 14, left: 8, bottom: 14, right: 8)
        pdfView.autoScales = true
        pdfView.layoutSubtreeIfNeeded()
        coordinator.attach(to: pdfView)
        defer { coordinator.detach() }

        coordinator.applyDisplayPreset(.fitWidth, to: pdfView)

        let page = try #require(pdfView.currentPage)
        let viewportWidth = try #require(findScrollView(in: pdfView)).contentView.frame.width
        let displayedPageWidth = page.bounds(for: .cropBox).width * pdfView.scaleFactor
        #expect(!pdfView.autoScales)
        #expect(displayedPageWidth <= viewportWidth)
        #expect(displayedPageWidth >= viewportWidth - 50)

        let firstScale = pdfView.scaleFactor
        pdfView.frame.size.width = 800
        pdfView.layoutSubtreeIfNeeded()
        coordinator.applyDisplayPreset(.fitWidth, to: pdfView)
        #expect(pdfView.scaleFactor > firstScale)
    }

    @Test @MainActor func fitHeightUsesVisibleReaderHeight() throws {
        let document = try #require(makeDocument())
        let reader = makeReader(document: document)
        let coordinator = PDFReaderView.Coordinator(parent: reader)
        let pdfView = makePDFView(document: document)
        coordinator.attach(to: pdfView)
        defer { coordinator.detach() }

        coordinator.applyDisplayPreset(.fitHeight, to: pdfView)

        let page = try #require(pdfView.currentPage)
        let viewportHeight = try #require(findScrollView(in: pdfView)).contentView.frame.height
        let displayedPageHeight = page.bounds(for: .cropBox).height * pdfView.scaleFactor
        #expect(displayedPageHeight <= viewportHeight)
        #expect(displayedPageHeight >= viewportHeight - 60)
    }

    @Test @MainActor func fullPageRasterUsesOneSourcePixelPerBackingPixel() throws {
        let image = NSImage(size: NSSize(width: 600, height: 800))
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 1200, pixelsHigh: 1600,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0))
        image.addRepresentation(bitmap)
        let document = PDFDocument()
        document.insert(try #require(PDFPage(image: image)), at: 0)
        let data = try #require(document.dataRepresentation())
        let reopened = try #require(PDFDocument(data: data))
        let page = try #require(reopened.page(at: 0))

        let scale = try #require(PDFRasterScaleDetector.nativePixelScale(for: page, backingScale: 2))
        #expect(abs(scale - 1) < 0.05)
        let standardDisplayScale = try #require(PDFRasterScaleDetector.nativePixelScale(for: page, backingScale: 1))
        #expect(abs(standardDisplayScale - 2) < 0.05)
    }

    @Test @MainActor func vectorPageBestDisplayShowsWholePage() throws {
        let document = try #require(makeVectorDocument())
        let page = try #require(document.page(at: 0))
        #expect(PDFRasterScaleDetector.nativePixelScale(for: page, backingScale: 2) == nil)
        let coordinator = PDFReaderView.Coordinator(parent: makeReader(document: document))
        let pdfView = makePDFView(document: document)
        coordinator.attach(to: pdfView)
        defer { coordinator.detach() }

        coordinator.applyDisplayPreset(.best, to: pdfView)

        let viewport = try #require(findScrollView(in: pdfView)).contentView.frame.size
        let bounds = page.bounds(for: .cropBox)
        #expect(bounds.width * pdfView.scaleFactor <= viewport.width)
        #expect(bounds.height * pdfView.scaleFactor <= viewport.height)
    }

    @Test @MainActor func smallIllustrationIsNotMistakenForPageScan() throws {
        let data = NSMutableData()
        let consumer = try #require(CGDataConsumer(data: data as CFMutableData))
        var box = CGRect(x: 0, y: 0, width: 500, height: 700)
        let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 1200, pixelsHigh: 1200,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0))
        let image = try #require(bitmap.cgImage)
        context.beginPDFPage(nil)
        context.draw(image, in: CGRect(x: 100, y: 100, width: 150, height: 150))
        context.endPDFPage()
        context.closePDF()
        let document = try #require(PDFDocument(data: data as Data))
        let page = try #require(document.page(at: 0))
        #expect(PDFRasterScaleDetector.nativePixelScale(for: page, backingScale: 2) == nil)
    }

    @MainActor private func makeReader(document: PDFDocument) -> PDFReaderView {
        PDFReaderView(document: document,
                      zoomPercent: .constant(100), currentPageIndex: .constant(0),
                      readingPosition: .constant(nil), documentID: "test.pdf",
                      navigationRequest: 0,
                      displayPresetRequest: .init(sequence: 0, preset: .fitWidth),
                      isReadingProfileLoading: true, backgroundColor: .white, onActivate: {})
    }

    @MainActor private func makePDFView(document: PDFDocument) -> PDFView {
        let pdfView = PDFView(frame: NSRect(x: 0, y: 0, width: 600, height: 800))
        pdfView.document = document
        pdfView.displayBox = .cropBox
        pdfView.pageBreakMargins = NSEdgeInsets(top: 14, left: 8, bottom: 14, right: 8)
        pdfView.autoScales = true
        pdfView.layoutSubtreeIfNeeded()
        return pdfView
    }

    @MainActor private func findScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView { return scrollView }
        for child in view.subviews {
            if let scrollView = findScrollView(in: child) { return scrollView }
        }
        return nil
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

    @MainActor private func makeVectorDocument() -> PDFDocument? {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }
        var box = CGRect(x: 0, y: 0, width: 500, height: 700)
        guard let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
        context.beginPDFPage(nil)
        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 30, y: 30, width: 200, height: 100))
        context.endPDFPage()
        context.closePDF()
        return PDFDocument(data: data as Data)
    }
}
