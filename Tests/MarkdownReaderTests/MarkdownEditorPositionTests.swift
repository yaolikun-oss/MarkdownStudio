import Foundation
import Testing
@testable import MarkdownReader

struct MarkdownEditorPositionTests {
    @Test func readingSplitDoesNotSendVisualFormattingToHiddenSource() {
        for mode in [ReaderDisplayMode.read, .edit, .split] {
            #expect(!MarkdownEditingTarget.sourceIsVisible(hasReadingDocument: true,
                usesReadingSplit: true, sourceOnly: false, displayMode: mode))
            #expect(MarkdownEditingTarget.sourceIsVisible(hasReadingDocument: true,
                usesReadingSplit: true, sourceOnly: true, displayMode: mode))
        }
        #expect(MarkdownEditingTarget.sourceIsVisible(hasReadingDocument: false,
            usesReadingSplit: false, sourceOnly: true, displayMode: .edit))
    }
    @Test func sourceAndVisualPositionsAgreeThroughChineseFormatting() {
        let source = "##### 联系强度\n\n正文中**加粗重点**和<u>下划线重点</u>都在同一段，末尾还有 😀。\n"
        let document = MarkdownVisualDocument(source: source, blocks: MarkdownBlock.parse(source))
        for word in ["联系强度", "加粗重点", "下划线重点", "末尾还有", "😀"] {
            let range = (source as NSString).range(of: word)
            for offset in [range.location, NSMaxRange(range)] {
                let visual = document.visualAnchor(forSourceOffset: offset)
                let restored = document.sourceOffset(for: visual)
                // At a formatting boundary the DOM caret may sit just outside
                // its closing marker. The visible character must stay identical.
                #expect(abs(restored - offset) <= 4)
                #expect(visual.index == (word == "联系强度" ? 0 : 1))
            }
        }
    }

    @Test func editsBeforeTheCaretUseCurrentBlockOffsetsRatherThanOldLineNumbers() throws {
        let source = "开头。\n\n##### 联系强度\n\n最后**重点**所在的段落。\n"
        var document = MarkdownVisualDocument(source: source, blocks: MarkdownBlock.parse(source))
        _ = document.replaceBlock(at: 0, with: "开头增加一行。\n又增加一行。\n\n再增加一段。")
        let caret = MarkdownVisualAnchor(index: 2, offset: "最后重点".utf16.count)
        let offset = document.sourceOffset(for: caret)
        let expected = (document.source as NSString).range(of: "**重点**").location + "**重点**".utf16.count
        #expect(offset == expected)
        #expect(document.visualAnchor(forSourceOffset: offset) == caret)
    }
}
