import SwiftUI

struct MarkdownNoteTree: View {
    let node: MarkdownNoteNode
    let selected: URL?
    let open: (URL) -> Void
    let delete: (URL) -> Void
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                if node.children.isEmpty {
                    Image(systemName: "chevron.right").opacity(0).frame(width: 12)
                } else {
                    Button { expanded.toggle() } label: {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right").frame(width: 12)
                    }.buttonStyle(.plain).help(expanded ? "收起子笔记" : "展开子笔记")
                }
                Button { open(node.url) } label: {
                    Label(node.url.deletingPathExtension().lastPathComponent, systemImage: "doc.text")
                        .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).help(node.url.path)
                    .contextMenu {
                        if MarkdownNoteHierarchy.parent(of: node.url) != nil {
                            Button("删除子笔记", role: .destructive) { delete(node.url) }
                        }
                    }
            }
            .font(.system(size: 12)).padding(.vertical, 5).padding(.horizontal, 5)
            .background(selected?.standardizedFileURL == node.url.standardizedFileURL ? Color.accentColor.opacity(0.11) : .clear, in: RoundedRectangle(cornerRadius: 5))
            if expanded {
                ForEach(node.children) { child in
                    MarkdownNoteTree(node: child, selected: selected, open: open, delete: delete).padding(.leading, 14)
                }
            }
        }
    }
}
