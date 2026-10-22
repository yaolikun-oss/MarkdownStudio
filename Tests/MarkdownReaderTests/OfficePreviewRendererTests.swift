import AppKit
import PDFKit
import Testing
import ZIPFoundation
@testable import MarkdownReader

@Suite(.serialized) struct OfficePreviewRendererTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["MD_PAGES_QA_FIXTURE"] != nil))
    @MainActor func pagesPreviewRetainsAllPagesInOriginalOrder() async throws {
        let path = try #require(ProcessInfo.processInfo.environment["MD_PAGES_QA_FIXTURE"])
        let source = URL(fileURLWithPath: path)
        let original = try Data(contentsOf: source)
        let output = try await OfficePreviewRenderer().render(source)
        let document = try #require(PDFDocument(url: output))
        #expect(document.pageCount == 3)
        #expect(document.page(at: 0)?.string?.contains("0730") == true)
        #expect(document.page(at: 0)?.string?.contains("123") == true)
        #expect(document.page(at: 2)?.string?.contains("第二页") == true)
        #expect(try Data(contentsOf: source) == original)
    }

    @Test @MainActor func explicitWordPageBreakPreservesPagesAndSelectableText() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("Pagination.docx")
        let archive = try Archive(url: source, accessMode: .create)
        let files = [
            "[Content_Types].xml": """
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>
            """,
            "_rels/.rels": """
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
            """,
            "word/document.xml": """
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>FIRST PAGE 第一页</w:t></w:r></w:p><w:tbl><w:tblPr/><w:tblGrid><w:gridCol w:w="4000"/></w:tblGrid><w:tr><w:tc><w:p><w:r><w:t>TABLE CELL</w:t></w:r></w:p></w:tc></w:tr></w:tbl><w:p><w:r><w:br w:type="page"/></w:r></w:p><w:p><w:r><w:t>SECOND PAGE 第二页</w:t></w:r></w:p><w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr></w:body></w:document>
            """
        ]
        for (name, text) in files {
            let data = Data(text.utf8)
            try archive.addEntry(with: name, type: .file, uncompressedSize: Int64(data.count), provider: { position, size in
                data.subdata(in: Int(position)..<Int(position) + size)
            })
        }
        let original = try Data(contentsOf: source)
        let layout = OfficePreviewRenderer.pageLayout(for: source)
        #expect(abs(layout.width - 595.3) < 0.1)
        #expect(layout.top == 72)
        let output = try await OfficePreviewRenderer().render(source)
        let document = try #require(PDFDocument(url: output))
        #expect(document.pageCount == 2)
        let first = try #require(document.page(at: 0))
        let second = try #require(document.page(at: 1))
        #expect(first.string?.contains("FIRST PAGE") == true)
        #expect(first.string?.contains("TABLE CELL") == true)
        #expect(first.string?.contains("SECOND PAGE") == false)
        #expect(second.string?.contains("SECOND PAGE") == true)
        #expect(first.selection(for: first.bounds(for: .mediaBox))?.string?.contains("FIRST PAGE") == true)
        #expect(abs(first.bounds(for: .mediaBox).width - layout.width) < 1)
        let container = OfficePreviewContainer(frame: NSRect(x: 0, y: 0, width: 600, height: 800))
        container.show(document, destination: nil, zoom: 175)
        #expect(abs(container.pdfView.scaleFactor - 1.75) < 0.01)
        container.setZoom(50)
        #expect(abs(container.pdfView.scaleFactor - 0.5) < 0.01)
        #expect(container.pdfView.document === document)
        container.previewView?.close()
        let state = OfficePreviewState()
        state.reset(for: source)
        state.document = document
        state.clear()
        state.reset(for: source)
        #expect(state.document == nil)
        #expect(try Data(contentsOf: source) == original)
        let legacy = directory.appendingPathComponent("Pagination.doc")
        let converter = Process()
        converter.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
        converter.arguments = ["-convert", "doc", "-output", legacy.path, source.path]
        try converter.run()
        converter.waitUntilExit()
        #expect(converter.terminationStatus == 0)
        let legacyOriginal = try Data(contentsOf: legacy)
        let legacyOutput = try await OfficePreviewRenderer().render(legacy)
        let legacyDocument = try #require(PDFDocument(url: legacyOutput))
        #expect(legacyDocument.pageCount == 2)
        #expect(legacyDocument.page(at: 0)?.string?.contains("FIRST PAGE") == true)
        #expect(legacyDocument.page(at: 1)?.string?.contains("SECOND PAGE") == true)
        #expect(try Data(contentsOf: legacy) == legacyOriginal)
        // Cached rendering must be reusable without touching the source.
        #expect(try await OfficePreviewRenderer().render(source) == output)
    }
}
