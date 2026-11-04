import AppKit
import Testing
import WebKit
@testable import MarkdownReader

struct EPUBArrowKeyRoutingTests {
    @Test func arrowsRouteOnlyForTheActiveEPUBPane() {
        #expect(EPUBArrowKeyRouting.chapterOffset(keyCode: 123, modifiers: [], enabled: true) == -1)
        #expect(EPUBArrowKeyRouting.chapterOffset(keyCode: 124, modifiers: [], enabled: true) == 1)
        #expect(EPUBArrowKeyRouting.chapterOffset(keyCode: 124, modifiers: [], enabled: false) == nil)
        #expect(EPUBArrowKeyRouting.chapterOffset(keyCode: 123, modifiers: [.command], enabled: true) == nil)
        #expect(EPUBArrowKeyRouting.chapterOffset(keyCode: 0, modifiers: [], enabled: true) == nil)
    }

    @Test @MainActor func explicitFocusRequestReturnsKeyboardToCurrentEPUBWebView() async {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let webView = WKWebView(frame: window.contentView?.bounds ?? .zero)
        window.contentView?.addSubview(webView)
        let coordinator = EPUBChapterView.Coordinator(onBodyChange: { _ in })
        coordinator.webView = webView
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }

        coordinator.requestFocus(1)
        await Task.yield()
        #expect(window.firstResponder === webView)
        #expect(WorkspaceKeyboardFocus.containsFirstResponder(webView))
    }
}
