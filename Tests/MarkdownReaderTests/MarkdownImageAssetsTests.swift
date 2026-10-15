import AppKit
import Testing
@testable import MarkdownReader

@Suite struct MarkdownImageAssetsTests {
    @Test @MainActor func pastingScreenshotWritesAnAdjacentPNGAndRendersAnImage() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let note = directory.appendingPathComponent("我的 笔记.md")
        let image = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
                                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                  isPlanar: false, colorSpaceName: .deviceRGB,
                                                  bytesPerRow: 0, bitsPerPixel: 0))
        image.setColor(.red, atX: 0, y: 0)
        let png = try #require(image.representation(using: .png, properties: [:]))
        let clipboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        clipboard.clearContents()
        #expect(clipboard.setData(png, forType: .png))
        #expect(MarkdownImageAssets.canImportClipboard(clipboard))

        let imported = try MarkdownImageAssets.importClipboard(clipboard, beside: note)
        let markdown = try #require(imported)
        #expect(markdown.contains("%20"))
        let assets = directory.appendingPathComponent("我的 笔记.assets")
        let files = try FileManager.default.contentsOfDirectory(at: assets, includingPropertiesForKeys: nil)
        #expect(files.count == 1)
        let saved = try Data(contentsOf: #require(files.first))
        #expect(saved == png)
        #expect(MarkdownBlock.parse(markdown).first?.html.contains("<img ") == true)
    }

    @Test @MainActor func imageClipboardDetectionLeavesPlainTextPasteAlone() {
        let clipboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        clipboard.clearContents()
        #expect(clipboard.setString("普通文字", forType: .string))
        #expect(!MarkdownImageAssets.canImportClipboard(clipboard))
    }

    @Test @MainActor func editorEnablesPasteForAnImageAndInsertsTheLink() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let note = directory.appendingPathComponent("笔记.md")
        let image = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
                                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                  isPlanar: false, colorSpaceName: .deviceRGB,
                                                  bytesPerRow: 0, bitsPerPixel: 0))
        let png = try #require(image.representation(using: .png, properties: [:]))
        let clipboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        clipboard.clearContents()
        #expect(clipboard.setData(png, forType: .png))

        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        editor.string = "正文"
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        editor.imagePasteboard = clipboard
        editor.onImagePaste = { board, textView in
            guard let markdown = try? MarkdownImageAssets.importClipboard(board, beside: note) else { return false }
            let range = textView.selectedRange()
            textView.insertText(MarkdownImageAssets.blockInsertion(markdown, in: textView.string,
                                                                  replacing: range), replacementRange: range)
            return true
        }
        let pasteItem = NSMenuItem(title: "Paste", action: #selector(NSTextView.paste(_:)), keyEquivalent: "v")
        #expect(editor.validateMenuItem(pasteItem))
        editor.paste(nil)
        #expect(editor.string.contains("![截图]("))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("笔记.assets").path).count == 1)
    }

    @Test @MainActor func imageInsertionRespectsParagraphBoundaries() {
        let image = "![截图](笔记.assets/image.png)"
        let source = "前文\n后文"
        let insertion = MarkdownImageAssets.blockInsertion(image, in: source,
                                                            replacing: NSRange(location: 3, length: 0))
        #expect(insertion == "\n\(image)\n\n")
        #expect((source as NSString).replacingCharacters(in: NSRange(location: 3, length: 0),
                                                         with: insertion) == "前文\n\n\(image)\n\n后文")
    }
}
