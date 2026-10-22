import AppKit
import SwiftUI

/// Routes the red close button and Command-W through the document coordinator.
/// The proxy forwards the other window delegate methods back to SwiftUI.
struct WindowCloseGuard: NSViewRepresentable {
    let onCloseRequest: (NSWindow) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCloseRequest: onCloseRequest) }
    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.proxy.onCloseRequest = onCloseRequest
        DispatchQueue.main.async { [weak view, weak coordinator = context.coordinator] in
            guard let window = view?.window, let coordinator else { return }
            coordinator.install(on: window)
        }
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.restoreDelegate()
    }

    @MainActor final class Coordinator {
        let proxy: CloseProxy
        private weak var window: NSWindow?

        init(onCloseRequest: @escaping (NSWindow) -> Void) {
            proxy = CloseProxy(onCloseRequest: onCloseRequest)
        }

        func install(on window: NSWindow) {
            guard window.delegate !== proxy else { return }
            restoreDelegate()
            self.window = window
            proxy.previous = window.delegate
            window.delegate = proxy
        }

        func restoreDelegate() {
            if window?.delegate === proxy { window?.delegate = proxy.previous }
            window = nil
        }
    }

    final class CloseProxy: NSObject, NSWindowDelegate {
        weak var previous: NSWindowDelegate?
        var onCloseRequest: (NSWindow) -> Void

        init(onCloseRequest: @escaping (NSWindow) -> Void) {
            self.onCloseRequest = onCloseRequest
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            onCloseRequest(sender)
            return false
        }

        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || previous?.responds(to: selector) == true
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            if previous?.responds(to: selector) == true { return previous }
            return super.forwardingTarget(for: selector)
        }
    }
}
