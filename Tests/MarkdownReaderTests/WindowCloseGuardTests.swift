import AppKit
import Testing
@testable import MarkdownReader

struct WindowCloseGuardTests {
    @Test @MainActor func closeRequestWaitsForDocumentDecision() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        var requests = 0
        let proxy = WindowCloseGuard.CloseProxy { requestedWindow in
            #expect(requestedWindow === window)
            requests += 1
        }
        window.delegate = proxy
        #expect(window.delegate?.windowShouldClose?(window) == false)
        #expect(requests == 1)
        window.close()
    }
}
