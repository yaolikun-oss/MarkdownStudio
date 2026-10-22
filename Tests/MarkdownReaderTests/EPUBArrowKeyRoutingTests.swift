import AppKit
import Testing
@testable import MarkdownReader

struct EPUBArrowKeyRoutingTests {
    @Test func arrowsRouteOnlyWhileEPUBOwnsKeyboardFocus() {
        #expect(EPUBArrowKeyRouting.chapterOffset(keyCode: 123, modifiers: [], enabled: true,
                                                  firstResponderInsideEPUB: true) == -1)
        #expect(EPUBArrowKeyRouting.chapterOffset(keyCode: 124, modifiers: [], enabled: true,
                                                  firstResponderInsideEPUB: true) == 1)
        #expect(EPUBArrowKeyRouting.chapterOffset(keyCode: 123, modifiers: [], enabled: true,
                                                  firstResponderInsideEPUB: false) == nil)
        #expect(EPUBArrowKeyRouting.chapterOffset(keyCode: 124, modifiers: [], enabled: false,
                                                  firstResponderInsideEPUB: true) == nil)
        #expect(EPUBArrowKeyRouting.chapterOffset(keyCode: 123, modifiers: [.command], enabled: true,
                                                  firstResponderInsideEPUB: true) == nil)
        #expect(EPUBArrowKeyRouting.chapterOffset(keyCode: 0, modifiers: [], enabled: true,
                                                  firstResponderInsideEPUB: true) == nil)
    }
}
