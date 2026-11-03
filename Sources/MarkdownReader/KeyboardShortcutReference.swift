import SwiftUI

struct KeyboardShortcutReferenceView: View {
    let onDone: () -> Void

    private struct Entry: Identifiable {
        let id = UUID()
        let action: String
        let keys: String
        let note: String?
        init(_ action: String, _ keys: String, note: String? = nil) {
            self.action = action; self.keys = keys; self.note = note
        }
    }

    private struct Section: Identifiable {
        let id = UUID()
        let title: String
        let entries: [Entry]
    }

    private let sections: [Section] = [
        Section(title: "文件与工作区", entries: [
            Entry("打开文件", "⌘ O"),
            Entry("临时打开文件", "⌥ ⌘ O", note: "不导入当前 Workspace"),
            Entry("打开文件夹", "⇧ ⌘ O"),
            Entry("新建 Workspace", "⇧ ⌘ N"),
            Entry("保存", "⌘ S"),
            Entry("显示主窗口", "⌥ ⌘ 0")
        ]),
        Section(title: "视图与焦点", entries: [
            Entry("切换阅读区与编辑区", "⇧ ⌘ R", note: "并排时移动焦点，单区时切换显示"),
            Entry("切换可视化与 Markdown 源码", "⌘ R"),
            Entry("切换 Markdown 预览与编辑器", "⇧ ⌘ V"),
            Entry("在侧边打开 Markdown 预览", "⌥ ⌘ V"),
            Entry("显示或隐藏左侧栏", "⌥ ⌘ 1"),
            Entry("打开本快捷键面板", "⌘ /"),
            Entry("整体样式设置", "⌘ ,")
        ]),
        Section(title: "阅读", entries: [
            Entry("上一章或上一页", "←", note: "EPUB / PDF 阅读焦点内"),
            Entry("下一章或下一页", "→", note: "EPUB / PDF 阅读焦点内"),
            Entry("放大当前区域", "⌘ +"),
            Entry("缩小当前区域", "⌘ −"),
            Entry("恢复当前区域默认字号", "⌘ 0"),
            Entry("添加 EPUB 注释", "⇧ ⌘ M"),
            Entry("查看 EPUB 注释", "⌥ ⌘ M")
        ]),
        Section(title: "阅读与笔记布局", entries: [
            Entry("只看原文", "⌃ ⌘ 1"),
            Entry("只看 Markdown 笔记", "⌃ ⌘ 2"),
            Entry("阅读与可视化笔记", "⌃ ⌘ 3"),
            Entry("最大化原文", "⇧ ⌘ 1"),
            Entry("最大化可视化笔记", "⇧ ⌘ 2"),
            Entry("最大化 Markdown 源码", "⇧ ⌘ 3"),
            Entry("可视化笔记占满右侧", "⌥ ⌘ 2"),
            Entry("Markdown 源码占满右侧", "⌥ ⌘ 3"),
            Entry("恢复三栏布局", "⇧ ⌘ 0")
        ]),
        Section(title: "网页", entries: [
            Entry("打开网页", "⌘ L"),
            Entry("网页后退", "⌘ ["),
            Entry("网页前进", "⌘ ]"),
            Entry("收藏当前网页", "⌥ ⌘ B"),
            Entry("剪藏选中文字到 Markdown", "⌃ ⌘ C")
        ]),
        Section(title: "章节关联", entries: [
            Entry("关联当前原文章节与笔记标题", "⌥ ⌘ L")
        ]),
        Section(title: "Markdown 标题与行内格式", entries: [
            Entry("标题 1–6", "⌘ 1 … ⌘ 6"),
            Entry("加粗", "⌘ B"),
            Entry("斜体", "⌘ I"),
            Entry("下划线", "⌘ U"),
            Entry("删除线", "⇧ ⌘ E"),
            Entry("行内代码", "⌘ K"),
            Entry("链接", "⌃ ⌘ L"),
            Entry("插入图片文件", "⌥ ⌘ I")
        ]),
        Section(title: "Markdown 块与列表", entries: [
            Entry("插入表格", "⌘ T"),
            Entry("无序列表", "⌃ U"),
            Entry("有序列表", "⌃ ⇧ O"),
            Entry("任务列表", "⇧ ⌘ T"),
            Entry("引用", "⇧ ⌘ B"),
            Entry("代码块", "⇧ ⌘ K"),
            Entry("行内数学公式", "⌃ ⌘ K"),
            Entry("数学公式块", "⌃ ⇧ K"),
            Entry("段落", "⌃ ⌥ P"),
            Entry("分隔线", "⌥ ⌘ S")
        ]),
        Section(title: "编辑", entries: [
            Entry("撤销", "⌘ Z"),
            Entry("重做", "⇧ ⌘ Z"),
            Entry("光标逐字移动", "←  →", note: "Markdown 编辑焦点内"),
            Entry("光标逐行移动", "↑  ↓", note: "Markdown 编辑焦点内")
        ])
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "keyboard").font(.system(size: 17, weight: .medium)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("键盘快捷键").font(.system(size: 18, weight: .semibold))
                    Text("快捷键会作用于当前获得焦点的阅读区、网页或编辑区")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("完成", action: onDone).keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 22).padding(.vertical, 16)
            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(section.title).font(.system(size: 14, weight: .semibold))
                            VStack(spacing: 0) {
                                ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.action).font(.system(size: 13))
                                            if let note = entry.note {
                                                Text(note).font(.system(size: 10)).foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer(minLength: 20)
                                        Text(entry.keys)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .padding(.horizontal, 9).padding(.vertical, 4)
                                            .background(Color.primary.opacity(0.065), in: RoundedRectangle(cornerRadius: 6))
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, entry.note == nil ? 8 : 6)
                                    if index + 1 < section.entries.count { Divider().padding(.leading, 12) }
                                }
                            }
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.62),
                                        in: RoundedRectangle(cornerRadius: 9))
                        }
                    }
                }
                .padding(22)
            }
        }
        .frame(width: 660, height: 760)
    }
}
