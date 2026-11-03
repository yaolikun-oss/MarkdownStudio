import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceDrag: Codable {
    let id: UUID
    static let type = UTType(exportedAs: "local.markdownstudio.workspace-tab")
}

@MainActor final class WorkspaceGroupFrames: ObservableObject {
    static let shared = WorkspaceGroupFrames()
    @Published var previewGroup: UUID?
    @Published var previewEdge: WorkspaceDropEdge?
    @Published var dragTitle: String?
    @Published var dragPoint: CGPoint = .zero
    var frames: [UUID: CGRect] = [:]
    var tabFrames: [UUID: [UUID: CGRect]] = [:]
    func destination(at point: CGPoint, groups: [WorkspaceGridLayout.Group]) -> (UUID, WorkspaceDropEdge, Int?)? {
        guard let id = groups.first(where: { frames[$0.id]?.contains(point) == true })?.id,
              let frame = frames[id] else { return nil }
        if point.y < frame.minY + 33 {
            let tabs = groups.first(where: { $0.id == id })?.tabs ?? []
            let index = tabs.firstIndex { tab in
                guard let rect = tabFrames[id]?[tab.id] else { return false }
                return point.x < rect.midX
            }
            return (id, .center, index)
        }
        let x = (point.x - frame.minX) / max(1, frame.width)
        let y = (point.y - frame.minY - 33) / max(1, frame.height - 33)
        return (id, WorkspaceDropEdge.nearest(x: x, y: y), nil)
    }
}

struct WorkspaceDragGhost: View {
    @ObservedObject private var state = WorkspaceGroupFrames.shared
    var body: some View {
        GeometryReader { geometry in
            if let title = state.dragTitle {
                let origin = geometry.frame(in: .global).origin
                Label(title, systemImage: "rectangle.on.rectangle")
                    .font(.system(size: 12, weight: .medium)).lineLimit(1)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .frame(maxWidth: 240)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.35)))
                    .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
                    .position(x: state.dragPoint.x - origin.x + 50, y: state.dragPoint.y - origin.y + 20)
                    .allowsHitTesting(false)
            }
        }.allowsHitTesting(false)
    }
}

/// One VS Code style editor group. The owner commits pending editor input
/// before switching, moving, or closing a tab.
struct WorkspaceTabGroup<Content: View>: View {
    let group: WorkspaceGridLayout.Group
    let groups: [WorkspaceGridLayout.Group]
    let allTabs: [WorkspaceTab]
    let title: (WorkspaceTab) -> String
    let isDirty: (WorkspaceTab) -> Bool
    let select: (WorkspaceTab) -> Void
    let move: (WorkspaceTab, UUID, WorkspaceDropEdge, Int?) -> Void
    let close: (WorkspaceTab) -> Void
    let detach: (WorkspaceTab, CGPoint) -> Void
    let companionNoteActionTitle: (WorkspaceTab) -> String?
    let performCompanionNoteAction: (WorkspaceTab) -> Void
    let addWeb: (UUID) -> Void
    let openFile: (URL, UUID, WorkspaceDropEdge) -> Void
    @ViewBuilder let content: (WorkspaceTab) -> Content
    @State private var targetedEdge: WorkspaceDropEdge?
    @ObservedObject private var dragFrames = WorkspaceGroupFrames.shared
    private func dragged(_ value: WorkspaceDrag) -> WorkspaceTab? {
        allTabs.first { $0.id == value.id } ?? WorkspaceDetachedWindowManager.shared.tab(id: value.id)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(group.tabs.enumerated()), id: \.element.id) { index, tab in
                            HStack(spacing: 6) {
                                Button { select(tab) } label: {
                                    HStack(spacing: 5) {
                                        Text(title(tab))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                            .frame(maxWidth: tab.id == group.selected ? 240 : 168,
                                                   alignment: .leading)
                                        if isDirty(tab) { Circle().frame(width: 6, height: 6).accessibilityLabel("未保存") }
                                    }.font(.system(size: 12))
                                }.buttonStyle(.plain)
                                    .help("\(title(tab))\n拖动标签可分屏或合并；右键可选择拆分方向")
                                    .accessibilityLabel(title(tab))
                                    .simultaneousGesture(DragGesture(minimumDistance: 5, coordinateSpace: .global)
                                        .onChanged { value in
                                            let destination = dragFrames.destination(at: value.location, groups: groups)
                                            dragFrames.dragTitle = title(tab)
                                            dragFrames.dragPoint = value.location
                                            dragFrames.previewGroup = destination?.0
                                            dragFrames.previewEdge = destination?.1
                                        }
                                        .onEnded { value in
                                            let destination = dragFrames.destination(at: value.location, groups: groups)
                                            dragFrames.previewGroup = nil; dragFrames.previewEdge = nil; dragFrames.dragTitle = nil
                                            guard let (target, edge, index) = destination else {
                                                detach(tab, value.location)
                                                return
                                            }
                                            move(tab, target, edge, index)
                                        })
                                Button { close(tab) } label: { Image(systemName: "xmark").font(.system(size: 9)) }
                                    .buttonStyle(.plain).help("关闭\(title(tab))")
                            }
                            .padding(.horizontal, 9).frame(height: 32)
                            .background(tab.id == group.selected ? Color(nsColor: .textBackgroundColor) : Color.clear)
                            .overlay(alignment: .bottom) {
                                if tab.id == group.selected { Rectangle().fill(Color.accentColor).frame(height: 2) }
                            }
                            .contentShape(Rectangle())
                            .background {
                                GeometryReader { geometry in
                                    Color.clear
                                        .onAppear { WorkspaceGroupFrames.shared.tabFrames[group.id, default: [:]][tab.id] = geometry.frame(in: .global) }
                                        .onChange(of: geometry.frame(in: .global)) { _, frame in WorkspaceGroupFrames.shared.tabFrames[group.id, default: [:]][tab.id] = frame }
                                }
                            }
                            .onDrop(of: [WorkspaceDrag.type], delegate: WorkspaceHeaderDropDelegate { value in
                                guard let item = dragged(value) else { return }
                                move(item, group.id, .center, index)
                            })
                            .contextMenu {
                                if let actionTitle = companionNoteActionTitle(tab) {
                                    Button(actionTitle) { performCompanionNoteAction(tab) }
                                    Divider()
                                }
                                Button("拆分到左侧") { move(tab, group.id, .left, nil) }
                                Button("拆分到右侧") { move(tab, group.id, .right, nil) }
                                Button("拆分到上方") { move(tab, group.id, .top, nil) }
                                Button("拆分到下方") { move(tab, group.id, .bottom, nil) }
                                Divider()
                                Button("移到新窗口") { detach(tab, NSEvent.mouseLocation) }
                                Button("关闭") { close(tab) }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .onDrop(of: [WorkspaceDrag.type], delegate: WorkspaceHeaderDropDelegate { value in
                    guard let item = dragged(value) else { return }
                    move(item, group.id, .center, nil)
                })
                Button { addWeb(group.id) } label: { Image(systemName: "plus").frame(width: 28, height: 30) }
                    .buttonStyle(.plain).help("在此分组新建网页标签")
            }.background(Color(nsColor: .controlBackgroundColor)).zIndex(1)
            Divider()
            GeometryReader { geometry in
                ZStack {
                    ForEach(group.tabs) { tab in
                        content(tab)
                            .opacity(group.selected == tab.id ? 1 : 0)
                            .allowsHitTesting(group.selected == tab.id)
                            .accessibilityHidden(group.selected != tab.id)
                    }
                    if let edge = targetedEdge ?? (dragFrames.previewGroup == group.id ? dragFrames.previewEdge : nil) {
                        Color.accentColor.opacity(0.17)
                            .frame(width: edge == .left || edge == .right ? geometry.size.width / 2 : geometry.size.width,
                                   height: edge == .top || edge == .bottom ? geometry.size.height / 2 : geometry.size.height)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment(for: edge))
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .onDrop(of: [WorkspaceDrag.type, UTType.fileURL], delegate: WorkspaceAreaDropDelegate(size: geometry.size,
                    targetedEdge: $targetedEdge, perform: { value, edge in
                        guard let tab = dragged(value) else { return }
                        move(tab, group.id, edge, nil)
                    }, openFile: { url, edge in openFile(url, group.id, edge) }))
            }
        }
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { WorkspaceGroupFrames.shared.frames[group.id] = geometry.frame(in: .global) }
                    .onChange(of: group.id) { _, id in
                        WorkspaceGroupFrames.shared.frames[id] = geometry.frame(in: .global)
                    }
                    .onChange(of: geometry.frame(in: .global)) { _, frame in
                        WorkspaceGroupFrames.shared.frames[group.id] = frame
                    }
            }
        }
        .onDisappear {
            WorkspaceGroupFrames.shared.frames.removeValue(forKey: group.id)
            WorkspaceGroupFrames.shared.tabFrames.removeValue(forKey: group.id)
            if WorkspaceGroupFrames.shared.previewGroup == group.id {
                WorkspaceGroupFrames.shared.previewGroup = nil
                WorkspaceGroupFrames.shared.previewEdge = nil
            }
        }
    }

    private func alignment(for edge: WorkspaceDropEdge) -> Alignment {
        switch edge {
        case .center: .center
        case .left: .leading
        case .right: .trailing
        case .top: .top
        case .bottom: .bottom
        }
    }
}

private struct WorkspaceHeaderDropDelegate: DropDelegate {
    let perform: @MainActor (WorkspaceDrag) -> Void
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [WorkspaceDrag.type]).first else { return false }
        _ = provider.loadDataRepresentation(for: WorkspaceDrag.type) { data, _ in
            guard let data, let value = try? JSONDecoder().decode(WorkspaceDrag.self, from: data) else { return }
            Task { @MainActor in perform(value) }
        }
        return true
    }
}

private struct WorkspaceAreaDropDelegate: DropDelegate {
    let size: CGSize
    @Binding var targetedEdge: WorkspaceDropEdge?
    let perform: @MainActor (WorkspaceDrag, WorkspaceDropEdge) -> Void
    let openFile: @MainActor (URL, WorkspaceDropEdge) -> Void

    private func edge(_ point: CGPoint) -> WorkspaceDropEdge {
        let x = point.x / max(1, size.width), y = point.y / max(1, size.height)
        return WorkspaceDropEdge.nearest(x: x, y: y)
    }
    func dropEntered(info: DropInfo) { targetedEdge = edge(info.location) }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        targetedEdge = edge(info.location)
        return DropProposal(operation: .move)
    }
    func dropExited(info: DropInfo) { targetedEdge = nil }
    func performDrop(info: DropInfo) -> Bool {
        let destination = edge(info.location)
        targetedEdge = nil
        if let provider = info.itemProviders(for: [WorkspaceDrag.type]).first {
            _ = provider.loadDataRepresentation(for: WorkspaceDrag.type) { data, _ in
                guard let data, let value = try? JSONDecoder().decode(WorkspaceDrag.self, from: data) else { return }
                Task { @MainActor in perform(value, destination) }
            }
            return true
        }
        guard let provider = info.itemProviders(for: [UTType.fileURL]).first else { return false }
        _ = provider.loadObject(ofClass: NSURL.self) { value, _ in
            guard let url = (value as? NSURL) as URL?, url.isFileURL else { return }
            Task { @MainActor in openFile(url, destination) }
        }
        return true
    }
}
