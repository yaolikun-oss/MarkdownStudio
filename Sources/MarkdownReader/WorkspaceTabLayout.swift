import Foundation

/// Layout state is independent of document contents, so moving a tab cannot
/// discard unsaved text or replace a reader session.
struct WorkspaceTab: Codable, Hashable, Identifiable {
    enum Kind: String, Codable { case reading, web, source, visual }
    var id: UUID
    var kind: Kind
    var location: URL?

    init(_ kind: Kind, id: UUID = UUID(), location: URL? = nil) {
        self.id = id; self.kind = kind; self.location = location
    }
}

struct WorkspaceTabLayout: Codable, Equatable {
    struct Group: Codable, Equatable {
        var tabs: [WorkspaceTab]
        var selected: UUID?
        init(tabs: [WorkspaceTab] = [], selected: UUID? = nil) {
            self.tabs = tabs
            self.selected = selected ?? tabs.first?.id
        }
    }
    var left: Group
    var right: Group?

    init(left: Group = Group(), right: Group? = nil) { self.left = left; self.right = right }

    var allTabs: [WorkspaceTab] { left.tabs + (right?.tabs ?? []) }

    mutating func add(_ tab: WorkspaceTab, toRight: Bool = false) {
        guard !allTabs.contains(where: { $0.id == tab.id }) else { return }
        if toRight {
            if right == nil { right = Group() }
            right?.tabs.append(tab); right?.selected = tab.id
        } else {
            left.tabs.append(tab); left.selected = tab.id
        }
    }

    mutating func select(_ id: UUID) {
        if left.tabs.contains(where: { $0.id == id }) { left.selected = id }
        else if right?.tabs.contains(where: { $0.id == id }) == true { right?.selected = id }
    }

    mutating func move(_ id: UUID, toRight: Bool, at index: Int? = nil) {
        guard let tab = allTabs.first(where: { $0.id == id }) else { return }
        remove(id, normalizeGroups: false)
        if toRight {
            if right == nil { right = Group() }
            let position = min(max(0, index ?? right!.tabs.count), right!.tabs.count)
            right!.tabs.insert(tab, at: position); right!.selected = id
        } else {
            let position = min(max(0, index ?? left.tabs.count), left.tabs.count)
            left.tabs.insert(tab, at: position); left.selected = id
        }
        normalize()
    }

    mutating func remove(_ id: UUID) { remove(id, normalizeGroups: true) }

    private mutating func remove(_ id: UUID, normalizeGroups: Bool) {
        func removeFrom(_ group: inout Group) {
            guard let index = group.tabs.firstIndex(where: { $0.id == id }) else { return }
            group.tabs.remove(at: index)
            if group.selected == id { group.selected = group.tabs.indices.contains(index) ? group.tabs[index].id : group.tabs.last?.id }
        }
        removeFrom(&left)
        if right != nil { removeFrom(&right!) }
        if normalizeGroups { normalize() }
    }

    private mutating func normalize() {
        if right?.tabs.isEmpty == true { right = nil }
        if left.tabs.isEmpty, let remaining = right { left = remaining; right = nil }
    }
}
