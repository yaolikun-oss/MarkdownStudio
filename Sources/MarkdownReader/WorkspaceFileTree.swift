import SwiftUI
import AppKit

struct WorkspaceFileEntry: Identifiable, Sendable {
    let url: URL
    let isDirectory: Bool
    var id: URL { url }

    static let supported = Set(["md", "markdown", "mdworkspace", "pdf", "epub", "mobi", "azw", "azw3", "doc", "docx", "pages"])
    static func children(of directory: URL) throws -> [WorkspaceFileEntry] {
        let urls = try FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey], options: [.skipsHiddenFiles])
        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey]),
                  values.isSymbolicLink != true else { return nil }
            let unpackedEPUB = WorkspaceResourceImporter.isUnpackedEPUBDirectory(url)
            let folder = values.isDirectory == true && values.isPackage != true && !unpackedEPUB
            guard folder || unpackedEPUB || supported.contains(url.pathExtension.lowercased()) else { return nil }
            return WorkspaceFileEntry(url: url, isDirectory: folder)
        }.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
        }
    }
}

struct WorkspaceFileTree: View {
    let folder: URL
    let selected: URL?
    let open: (URL) -> Void
    let delete: ((URL) -> Void)?
    let importFiles: ((URL) -> Void)?
    let initiallyExpanded: Bool
    let remove: (() -> Void)?
    @State private var expanded: Bool
    @State private var items: [WorkspaceFileEntry] = []
    @State private var error: String?
    @State private var revision = 0

    init(folder: URL, selected: URL?, initiallyExpanded: Bool = false, remove: (() -> Void)? = nil,
         delete: ((URL) -> Void)? = nil, importFiles: ((URL) -> Void)? = nil,
         open: @escaping (URL) -> Void) {
        self.folder = folder; self.selected = selected; self.initiallyExpanded = initiallyExpanded; self.open = open
        self.remove = remove; self.delete = delete; self.importFiles = importFiles
        _expanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Button {
                expanded.toggle()
                if expanded { refresh() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right").frame(width: 12)
                    Image(systemName: expanded ? "folder.fill" : "folder")
                    Text(folder.lastPathComponent).lineLimit(1)
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).help(folder.path)
                .contextMenu {
                    Button("刷新目录") { refresh() }
                    if let importFiles { Button("导入文件到此文件夹…") { importFiles(folder) } }
                    Button("在访达中显示") { NSWorkspace.shared.activateFileViewerSelecting([folder]) }
                    if let remove { Button("从工作区移除文件夹", action: remove) }
                }
            if expanded {
                if let error { Text(error).font(.caption2).foregroundStyle(.secondary).padding(.leading, 18) }
                ForEach(items) { item in
                    if item.isDirectory {
                        AnyView(WorkspaceFileTree(folder: item.url, selected: selected, delete: delete,
                                                  importFiles: importFiles, open: open).padding(.leading, 14))
                    } else {
                        Button { open(item.url) } label: {
                            HStack(spacing: 5) {
                                Image(systemName: icon(item.url)).frame(width: 13)
                                Text(item.url.lastPathComponent).lineLimit(1)
                                Spacer(minLength: 0)
                            }.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).help(item.url.path)
                        .padding(.leading, 17).padding(.vertical, 3)
                        .background(selected?.standardizedFileURL == item.url.standardizedFileURL ? Color.accentColor.opacity(0.12) : .clear,
                                    in: RoundedRectangle(cornerRadius: 4))
                        .draggable(item.url)
                        .contextMenu {
                            Button("在访达中显示") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                            if let delete {
                                Divider()
                                Button("移到废纸篓…", role: .destructive) { delete(item.url) }
                            }
                        }
                    }
                }
            }
        }.font(.system(size: 12)).padding(.vertical, 2)
            .onAppear { if expanded && items.isEmpty { refresh() } }
    }

    private func refresh() {
        revision += 1
        let request = revision
        Task {
            let result = await Task.detached(priority: .userInitiated) { Result { try WorkspaceFileEntry.children(of: folder) } }.value
            guard request == revision else { return }
            switch result {
            case .success(let values): items = values; error = nil
            case .failure(let failure): error = "无法读取：\(failure.localizedDescription)"
            }
        }
    }

    private func icon(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "mdworkspace": "square.stack.3d.up"
        case "pdf": "doc.richtext"
        case "epub", "mobi", "azw", "azw3": "book"
        case "doc", "docx", "pages": "doc.text"
        default: "doc.plaintext"
        }
    }
}
