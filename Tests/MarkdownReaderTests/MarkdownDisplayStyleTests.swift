import Foundation
import Testing
@testable import MarkdownReader

@Suite struct MarkdownDisplayStyleTests {
    @Test func previewAndSourceProfilesRoundTripIndependently() throws {
        let original = MarkdownDisplayStyle(readerWidth: 720, outlineFontScale: 1,
                                            bodySize: 15, bodyFamily: "系统默认",
                                            bodyColorHex: "#282725", backgroundHex: "#FFFFFF",
                                            lineHeight: 1.85, paragraphSpacing: 13,
                                            strongColorHex: "#A5563A", strongSize: 15,
                                            strongFamily: "系统默认", headingStylesData: Data("[]".utf8),
                                            outlineColorsData: Data("[]".utf8))
        var preview = original
        var source = original
        preview.bodySize = 20
        preview.readerWidth = 880
        source.lineHeight = 1.4
        source.paragraphSpacing = 8
        source.backgroundHex = "#F8F8F8"

        let previewData = try JSONEncoder().encode(preview)
        let sourceData = try JSONEncoder().encode(source)
        #expect(try JSONDecoder().decode(MarkdownDisplayStyle.self, from: previewData) == preview)
        #expect(try JSONDecoder().decode(MarkdownDisplayStyle.self, from: sourceData) == source)
        #expect(original.bodySize == 15)
        #expect(source.bodySize == 15)
        #expect(preview.lineHeight == 1.85)
    }
}
