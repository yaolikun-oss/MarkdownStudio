import Foundation

enum WorkspaceDropEdge: String, CaseIterable {
    case center, left, right, top, bottom

    static func nearest(x: Double, y: Double) -> WorkspaceDropEdge {
        let distances: [(WorkspaceDropEdge, Double)] = [(.left, x), (.right, 1 - x), (.top, y), (.bottom, 1 - y)]
        return distances.min(by: { $0.1 < $1.1 })!.0
    }
}

struct WorkspaceGridLayout: Codable, Equatable {
    struct Group: Codable, Equatable, Identifiable {
        var id = UUID()
        var tabs: [WorkspaceTab] = []
        var selected: UUID?
    }
    indirect enum Node: Codable, Equatable {
        case group(Group)
        case split(horizontal: Bool, first: Node, second: Node)

        var groups: [Group] {
            switch self {
            case .group(let value): [value]
            case .split(_, let first, let second): first.groups + second.groups
            }
        }
        func updating(_ id: UUID, _ change: (inout Group) -> Void) -> Node {
            switch self {
            case .group(var group):
                if group.id == id { change(&group) }
                return .group(group)
            case .split(let horizontal, let first, let second):
                return .split(horizontal: horizontal, first: first.updating(id, change), second: second.updating(id, change))
            }
        }
        func pruningEmpty() -> Node? {
            switch self {
            case .group(let group): return group.tabs.isEmpty ? nil : self
            case .split(let horizontal, let first, let second):
                switch (first.pruningEmpty(), second.pruningEmpty()) {
                case let (a?, b?): return .split(horizontal: horizontal, first: a, second: b)
                case let (a?, nil): return a
                case let (nil, b?): return b
                case (nil, nil): return nil
                }
            }
        }
        func splitting(_ target: UUID, edge: WorkspaceDropEdge, newGroup: Group) -> Node {
            switch self {
            case .group(let group):
                guard group.id == target else { return self }
                let horizontal = edge == .left || edge == .right
                let newFirst = edge == .left || edge == .top
                return .split(horizontal: horizontal, first: newFirst ? .group(newGroup) : self,
                              second: newFirst ? self : .group(newGroup))
            case .split(let horizontal, let first, let second):
                return .split(horizontal: horizontal,
                              first: first.splitting(target, edge: edge, newGroup: newGroup),
                              second: second.splitting(target, edge: edge, newGroup: newGroup))
            }
        }
        func mappingTabs(_ transform: (WorkspaceTab) -> WorkspaceTab) -> Node {
            switch self {
            case .group(var group): group.tabs = group.tabs.map(transform); return .group(group)
            case .split(let horizontal, let first, let second):
                return .split(horizontal: horizontal, first: first.mappingTabs(transform), second: second.mappingTabs(transform))
            }
        }
    }
    var root: Node = .group(Group())
    var activeGroup: UUID?
    var groups: [Group] { root.groups }
    var allTabs: [WorkspaceTab] { groups.flatMap(\.tabs) }

    func arranged(_ edge: WorkspaceDropEdge) -> WorkspaceGridLayout {
        let tabs = allTabs
        guard let first = tabs.first else { return self }
        var result = WorkspaceGridLayout()
        for tab in tabs { result.add(tab) }
        if edge != .center, tabs.count > 1 {
            let base = tabs.first(where: { $0.kind == .reading }) ?? tabs.first(where: { $0.kind == .visual }) ?? first
            guard let other = tabs.first(where: { $0.kind == .source && $0.id != base.id }) ?? tabs.first(where: { $0.id != base.id }) else { return result }
            result.select(base.id)
            result.move(other.id, to: result.groups[0].id, edge: edge)
        }
        return result
    }

    var isValid: Bool {
        let groupIDs = groups.map(\.id), tabIDs = allTabs.map(\.id)
        return !groups.isEmpty && Set(groupIDs).count == groupIDs.count && Set(tabIDs).count == tabIDs.count &&
            groups.allSatisfy { group in
                group.tabs.isEmpty ? (groups.count == 1 && group.selected == nil) : group.tabs.contains { $0.id == group.selected }
            } && (activeGroup == nil || groupIDs.contains(activeGroup!))
    }

    mutating func add(_ tab: WorkspaceTab, group id: UUID? = nil, index: Int? = nil) {
        guard !allTabs.contains(where: { $0.id == tab.id }) else { return }
        let target = id.flatMap { value in groups.contains(where: { $0.id == value }) ? value : nil }
            ?? activeGroup.flatMap { value in groups.contains(where: { $0.id == value }) ? value : nil }
            ?? groups[0].id
        root = root.updating(target) { group in
            let position = min(max(index ?? group.tabs.count, 0), group.tabs.count)
            group.tabs.insert(tab, at: position); group.selected = tab.id
        }
        activeGroup = target
    }

    mutating func select(_ id: UUID) {
        guard let group = groups.first(where: { $0.tabs.contains(where: { $0.id == id }) }) else { return }
        root = root.updating(group.id) { $0.selected = id }; activeGroup = group.id
    }

    mutating func remove(_ id: UUID) {
        guard let group = groups.first(where: { $0.tabs.contains(where: { $0.id == id }) }) else { return }
        root = root.updating(group.id) { value in
            guard let index = value.tabs.firstIndex(where: { $0.id == id }) else { return }
            value.tabs.remove(at: index)
            if value.selected == id { value.selected = value.tabs.indices.contains(index) ? value.tabs[index].id : value.tabs.last?.id }
        }
        root = root.pruningEmpty() ?? .group(Group())
        if !groups.contains(where: { $0.id == activeGroup }) { activeGroup = groups.first?.id }
    }

    mutating func move(_ id: UUID, to target: UUID, edge: WorkspaceDropEdge = .center, index: Int? = nil) {
        guard let tab = allTabs.first(where: { $0.id == id }),
              let source = groups.first(where: { $0.tabs.contains(where: { $0.id == id }) }),
              groups.contains(where: { $0.id == target }) else { return }
        if edge != .center && source.id == target && source.tabs.count == 1 { return }
        if edge == .center && source.id == target {
            root = root.updating(source.id) { group in
                guard let old = group.tabs.firstIndex(where: { $0.id == id }) else { return }
                group.tabs.remove(at: old)
                let adjusted = index.map { $0 > old ? $0 - 1 : $0 } ?? group.tabs.count
                group.tabs.insert(tab, at: min(max(0, adjusted), group.tabs.count))
                group.selected = id
            }
            activeGroup = source.id
            return
        }
        remove(id)
        guard groups.contains(where: { $0.id == target }) else { add(tab); return }
        if edge == .center { add(tab, group: target, index: index); return }
        let group = Group(tabs: [tab], selected: id)
        root = root.splitting(target, edge: edge, newGroup: group)
        activeGroup = group.id
    }
}
