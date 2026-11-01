import Foundation

/// A window owns only its layout. Documents and web sessions are shared by the
/// workspace, so moving a tab between windows never copies or discards content.
struct WorkspaceWindowLayout: Codable, Equatable {
    struct Window: Codable, Equatable, Identifiable {
        var id: UUID
        var layout: WorkspaceGridLayout
        init(id: UUID = UUID(), layout: WorkspaceGridLayout = WorkspaceGridLayout()) {
            self.id = id
            self.layout = layout
        }
    }
    var windows: [Window] = [Window()]
    var mainWindowID: UUID { windows[0].id }
    var allTabs: [WorkspaceTab] { windows.flatMap { $0.layout.allTabs } }
    var isValid: Bool {
        !windows.isEmpty && Set(windows.map(\.id)).count == windows.count &&
        windows.allSatisfy { $0.layout.isValid } && Set(allTabs.map(\.id)).count == allTabs.count
    }

    /// Detach one existing tab. The main window remains alive even if empty.
    @discardableResult mutating func detach(_ tabID: UUID) -> UUID? {
        guard let origin = windows.firstIndex(where: { $0.layout.allTabs.contains(where: { $0.id == tabID }) }),
              let tab = windows[origin].layout.allTabs.first(where: { $0.id == tabID }) else { return nil }
        windows[origin].layout.remove(tabID)
        var detached = Window()
        detached.layout.add(tab)
        windows.append(detached)
        removeEmptyDetachedWindows()
        return detached.id
    }

    /// Validate the complete destination before modifying either window.
    @discardableResult mutating func move(_ tabID: UUID, to windowID: UUID, groupID: UUID,
                                         edge: WorkspaceDropEdge = .center, index: Int? = nil) -> Bool {
        guard let origin = windows.firstIndex(where: { $0.layout.allTabs.contains(where: { $0.id == tabID }) }),
              let target = windows.firstIndex(where: { $0.id == windowID }),
              windows[target].layout.groups.contains(where: { $0.id == groupID }),
              let tab = windows[origin].layout.allTabs.first(where: { $0.id == tabID }) else { return false }
        if origin == target {
            windows[origin].layout.move(tabID, to: groupID, edge: edge, index: index)
        } else {
            windows[origin].layout.remove(tabID)
            windows[target].layout.add(tab, group: groupID, index: index)
            if edge != .center { windows[target].layout.move(tabID, to: groupID, edge: edge) }
        }
        removeEmptyDetachedWindows()
        return true
    }

    private mutating func removeEmptyDetachedWindows() {
        guard windows.count > 1 else { return }
        windows = [windows[0]] + windows.dropFirst().filter { !$0.layout.allTabs.isEmpty }
    }
}
