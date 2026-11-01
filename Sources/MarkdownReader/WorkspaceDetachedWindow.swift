import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor final class WorkspaceDetachedWindowManager: ObservableObject {
    static let shared = WorkspaceDetachedWindowManager()
    private struct Entry {
        let tab: WorkspaceTab
        let window: NSWindow
        let delegate: WindowDelegate
    }
    private var entries: [UUID: Entry] = [:]

    func tab(id: UUID) -> WorkspaceTab? { entries[id]?.tab }
    var allTabs: [WorkspaceTab] { entries.values.map(\.tab) }

    func open(tab: WorkspaceTab, title: String, content: AnyView, near point: CGPoint,
              onDock: @escaping (WorkspaceTab) -> Void, onClose: @escaping (WorkspaceTab) -> Void) {
        guard entries[tab.id] == nil else { entries[tab.id]?.window.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: NSRect(x: point.x - 280, y: point.y - 80, width: 720, height: 620),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = title
        window.minSize = NSSize(width: 360, height: 280)
        let delegate = WindowDelegate { [weak self] in
            guard let self, self.entries.removeValue(forKey: tab.id) != nil else { return }
            onClose(tab)
        }
        window.delegate = delegate
        window.contentView = NSHostingView(rootView: DetachedWorkspaceTab(tab: tab, title: title, content: content,
            onDock: { [weak self] in
                guard let self, let entry = self.entries.removeValue(forKey: tab.id) else { return }
                entry.window.delegate = nil
                entry.window.close()
                onDock(tab)
            }, onClose: { window.performClose(nil) }))
        entries[tab.id] = Entry(tab: tab, window: window, delegate: delegate)
        window.makeKeyAndOrderFront(nil)
    }

    @discardableResult func take(_ id: UUID) -> WorkspaceTab? {
        guard let entry = entries.removeValue(forKey: id) else { return nil }
        entry.window.delegate = nil
        entry.window.close()
        return entry.tab
    }

    func closeAllSilently() {
        let current = entries.values
        entries.removeAll()
        for entry in current {
            entry.window.delegate = nil
            entry.window.close()
        }
    }

    private final class WindowDelegate: NSObject, NSWindowDelegate {
        let close: () -> Void
        init(close: @escaping () -> Void) { self.close = close }
        func windowWillClose(_ notification: Notification) { close() }
    }
}

private struct DetachedWorkspaceTab: View {
    let tab: WorkspaceTab
    let title: String
    let content: AnyView
    let onDock: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.on.rectangle")
                Text(title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Spacer()
                Button("停靠回主窗口", action: onDock).buttonStyle(.borderless)
                    .help("把此标签停靠回主工作区")
                Button(action: onClose) { Image(systemName: "xmark") }.buttonStyle(.borderless)
                    .help("关闭此标签")
            }
            .padding(.horizontal, 10).frame(height: 34)
            .background(Color(nsColor: .controlBackgroundColor))
            .contentShape(Rectangle())
            .onDrag {
                let provider = NSItemProvider()
                if let data = try? JSONEncoder().encode(WorkspaceDrag(id: tab.id)) {
                    provider.registerDataRepresentation(forTypeIdentifier: WorkspaceDrag.type.identifier,
                                                        visibility: .all) { completion in completion(data, nil); return nil }
                }
                return provider
            }
            Divider()
            content
        }
        .frame(minWidth: 360, minHeight: 280)
    }
}
