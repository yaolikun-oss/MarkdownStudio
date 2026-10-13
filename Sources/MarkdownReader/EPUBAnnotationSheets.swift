import EPUBCore
import SwiftUI

struct EPUBAnnotationComposer: View {
    @Environment(\.dismiss) private var dismiss
    let anchor: EPUBTextAnchor
    let onSave: (String, String) -> Void
    @State private var note = ""
    @State private var colorHex = "#FFE58A"

    private let colors = ["#FFE58A", "#BFE8C5", "#B9DDF5", "#F5C5D7"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("添加 EPUB 注释").font(.system(size: 17, weight: .semibold))
            Text(anchor.quote).font(.system(size: 13)).foregroundStyle(.secondary)
                .lineLimit(5).padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
            HStack(spacing: 10) {
                Text("标记颜色").font(.system(size: 12)).foregroundStyle(.secondary)
                ForEach(colors, id: \.self) { color in
                    Button { colorHex = color } label: {
                        Circle().fill(Color(hex: color)).frame(width: 20, height: 20)
                            .overlay(Circle().stroke(Color.primary.opacity(color == colorHex ? 0.6 : 0.15), lineWidth: color == colorHex ? 2 : 1))
                    }.buttonStyle(.plain).accessibilityLabel("选择标记颜色")
                }
            }
            Text("批注（可选）").font(.system(size: 12)).foregroundStyle(.secondary)
            TextEditor(text: $note).font(.system(size: 13)).frame(minHeight: 110)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12)))
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存注释") { onSave(note, colorHex); dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 480)
    }
}

struct EPUBAnnotationListSheet: View {
    @Environment(\.dismiss) private var dismiss
    let annotations: [EPUBAnnotation]
    let onSelect: (EPUBAnnotation) -> Void
    let onDelete: (EPUBAnnotation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("EPUB 注释").font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            if annotations.isEmpty {
                ContentUnavailableView("还没有注释", systemImage: "highlighter",
                                       description: Text("在原书中选中一段文字，再点工具栏的批注按钮。"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(annotations.sorted(by: { $0.createdAt > $1.createdAt })) { annotation in
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 2).fill(Color(hex: annotation.colorHex)).frame(width: 5)
                        Button { onSelect(annotation); dismiss() } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(annotation.anchor.quote).font(.system(size: 12, weight: .medium))
                                    .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                                if !annotation.note.isEmpty {
                                    Text(annotation.note).font(.system(size: 11)).foregroundStyle(.secondary)
                                        .lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                                }
                                Text(annotation.chapterHref).font(.system(size: 10)).foregroundStyle(.tertiary).lineLimit(1)
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Button(role: .destructive) { onDelete(annotation) } label: {
                            Image(systemName: "trash").font(.system(size: 11))
                        }.buttonStyle(.plain).help("删除注释")
                    }.padding(.vertical, 5)
                }.listStyle(.plain)
            }
        }
        .padding(18).frame(width: 520, height: 460)
    }
}
