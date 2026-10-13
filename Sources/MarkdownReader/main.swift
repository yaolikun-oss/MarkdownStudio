import EPUBCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct MarkdownReaderApp: App {
    @NSApplicationDelegateAdaptor(ReaderAppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup(id: "main") {
            ReaderView()
                .frame(minWidth: 900, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("显示主窗口") { ReaderActions.reopenWindow() }
                    .keyboardShortcut("0", modifiers: [.command])
            }
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("打开 Markdown 文件…") { ReaderActions.openFile() }
                    .keyboardShortcut("o", modifiers: [.command])
                Button("打开文件夹…") { ReaderActions.openFolder() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Divider()
                Button("关闭当前文件") { ReaderActions.closeFile() }
                Button("关闭文件夹") { ReaderActions.closeFolder() }
            }
            CommandMenu("阅读") {
                Button("字体与行距…") { ReaderActions.openSettings() }
                    .keyboardShortcut(",", modifiers: [.command])
                Divider()
                Button("放大当前区域字体") { ReaderActions.adjustTypographySize(1) }
                    .keyboardShortcut("+", modifiers: [.command])
                Button("缩小当前区域字体") { ReaderActions.adjustTypographySize(-1) }
                    .keyboardShortcut("-", modifiers: [.command])
                Button("恢复当前区域默认字号") { ReaderActions.resetTypographySize() }
                    .keyboardShortcut("0", modifiers: [.command])
            }
            CommandMenu("模式") {
                Button("阅读器") { ReaderActions.setDisplayMode(.read) }
                Button("编辑器") { ReaderActions.setDisplayMode(.edit) }
                Button("左右分栏") { ReaderActions.setDisplayMode(.split) }
                Divider()
                Button("切换阅读 / 编辑") { ReaderActions.toggleEditPreview() }
                    .keyboardShortcut("r", modifiers: [.command])
            }
            CommandMenu("EPUB 笔记") {
                Button("只看 EPUB 原书") { ReaderActions.setEPUBNotebookLayout(.epub) }
                    .keyboardShortcut("1", modifiers: [.command, .control])
                Button("只看 Markdown 笔记") { ReaderActions.setEPUBNotebookLayout(.notes) }
                    .keyboardShortcut("2", modifiers: [.command, .control])
                Button("三栏工作区：原书 + 预览 + 编辑") { ReaderActions.setEPUBNotebookLayout(.stacked) }
                    .keyboardShortcut("3", modifiers: [.command, .control])
                Divider()
                Button("最大化 EPUB 面板") { ReaderActions.maximizeEPUBNotebookPane(.epub) }
                    .keyboardShortcut("1", modifiers: [.command, .shift])
                Button("笔记预览占满右侧") { ReaderActions.maximizeEPUBNotebookPane(.rightPreview) }
                    .keyboardShortcut("2", modifiers: [.command, .option])
                Button("笔记编辑占满右侧") { ReaderActions.maximizeEPUBNotebookPane(.rightEditor) }
                    .keyboardShortcut("3", modifiers: [.command, .option])
                Button("最大化笔记预览面板") { ReaderActions.maximizeEPUBNotebookPane(.preview) }
                    .keyboardShortcut("2", modifiers: [.command, .shift])
                Button("最大化笔记编辑面板") { ReaderActions.maximizeEPUBNotebookPane(.editor) }
                    .keyboardShortcut("3", modifiers: [.command, .shift])
                Button("恢复三栏布局") { ReaderActions.restoreEPUBNotebookLayout() }
                    .keyboardShortcut("0", modifiers: [.command, .shift])
            }
            CommandMenu("EPUB 注释") {
                Button("为所选文字添加注释…") { ReaderActions.addEPUBAnnotation() }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                Button("查看注释列表…") { ReaderActions.showEPUBAnnotations() }
                    .keyboardShortcut("m", modifiers: [.command, .option])
            }
            CommandMenu("语法") {
                ForEach(1...6, id: \.self) { level in
                    Button("标题 \(level)") { ReaderActions.applyHeadingLevel(level) }
                        .keyboardShortcut(KeyEquivalent(Character(String(level))), modifiers: [.command])
                }
                Divider()
                Button("加粗") { ReaderActions.applyInlineSyntax("**", "**") }
                    .keyboardShortcut("b", modifiers: [.command])
                Button("斜体") { ReaderActions.applyInlineSyntax("*", "*") }
                    .keyboardShortcut("i", modifiers: [.command])
                Button("下划线") { ReaderActions.applyInlineSyntax("<u>", "</u>") }
                    .keyboardShortcut("u", modifiers: [.command])
                Button("删除线") { ReaderActions.applyInlineSyntax("~~", "~~") }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("行内代码") { ReaderActions.applyInlineSyntax("`", "`") }
                    .keyboardShortcut("k", modifiers: [.command])
                Button("链接") { ReaderActions.applyInlineSyntax("[", "](链接地址)") }
                    .keyboardShortcut("l", modifiers: [.command, .control])
                Menu("图片") {
                    Button("插入图片语法") { ReaderActions.insertTemplate("![替代文字](图片地址)") }
                }
                Divider()
                Button("插入表格…") { ReaderActions.insertTable() }
                    .keyboardShortcut("t", modifiers: [.command])
                Button("无序列表") { ReaderActions.applyLinePrefix("- ") }
                    .keyboardShortcut("u", modifiers: [.control])
                Button("有序列表") { ReaderActions.applyLinePrefix("1. ") }
                    .keyboardShortcut("o", modifiers: [.control, .shift])
                Button("任务列表") { ReaderActions.applyLinePrefix("- [ ] ") }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
                Button("引用") { ReaderActions.applyLinePrefix("> ") }
                    .keyboardShortcut("b", modifiers: [.command, .shift])
                Divider()
                Button("代码块") { ReaderActions.wrapSelection("```\\n", "\\n```") }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                Button("行内数学公式") { ReaderActions.applyInlineSyntax("$", "$") }
                    .keyboardShortcut("k", modifiers: [.command, .control])
                Button("数学公式块") { ReaderActions.wrapSelection("$$\\n", "\\n$$") }
                    .keyboardShortcut("k", modifiers: [.control, .shift])
                Button("段落") { ReaderActions.clearLinePrefix() }
                    .keyboardShortcut("0", modifiers: [.control, .shift])
                Button("插入分隔线") { ReaderActions.insertHorizontalRule() }
                    .keyboardShortcut("s", modifiers: [.command, .option])
            }
            CommandGroup(replacing: .saveItem) {
                Button("保存") { ReaderActions.save() }
                    .keyboardShortcut("s", modifiers: [.command])
            }
            CommandGroup(replacing: .undoRedo) {
                Button("撤销") { NSApp.sendAction(Selector(("undo:")), to: nil, from: nil) }
                    .keyboardShortcut("z", modifiers: [.command])
                Button("重做") { NSApp.sendAction(Selector(("redo:")), to: nil, from: nil) }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
            }
            CommandMenu("视图") {
                Button("切换预览 / 编辑器") { ReaderActions.toggleEditPreview() }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                Button("在侧边打开预览") { ReaderActions.openPreviewToSide() }
                    .keyboardShortcut("v", modifiers: [.command, .option])
                Divider()
                Button(ReaderActions.sidebarVisible ? "隐藏目录侧栏" : "显示目录侧栏") {
                    ReaderActions.toggleSidebar()
                }
                .keyboardShortcut("1", modifiers: [.command, .option])
            }
        }
    }
}

@MainActor
enum ReaderActions {
    static var reopenWindowHandler: (() -> Void)?
    static var openFileHandler: (() -> Void)?
    static var openFolderHandler: (() -> Void)?
    static var openDocumentHandler: ((URL) -> Void)?
    static var openSettingsHandler: (() -> Void)?
    static var adjustBodySizeHandler: ((Double) -> Void)?
    static var resetBodySizeHandler: (() -> Void)?
    static var adjustTypographySizeHandler: ((Double) -> Void)?
    static var resetTypographySizeHandler: (() -> Void)?
    static var toggleSidebarHandler: (() -> Void)?
    static var setDisplayModeHandler: ((ReaderDisplayMode) -> Void)?
    static var applyHeadingLevelHandler: ((Int) -> Void)?
    static var applyInlineSyntaxHandler: ((String, String) -> Void)?
    static var applyLinePrefixHandler: ((String) -> Void)?
    static var wrapSelectionHandler: ((String, String) -> Void)?
    static var clearLinePrefixHandler: (() -> Void)?
    static var insertTemplateHandler: ((String) -> Void)?
    static var toggleEditPreviewHandler: (() -> Void)?
    static var toggleSplitModeHandler: (() -> Void)?
    static var openPreviewToSideHandler: (() -> Void)?
    static var setEPUBNotebookLayoutHandler: ((EPUBNotebookLayout) -> Void)?
    static var maximizeEPUBNotebookPaneHandler: ((EPUBNotebookPane) -> Void)?
    static var restoreEPUBNotebookLayoutHandler: (() -> Void)?
    static var addEPUBAnnotationHandler: (() -> Void)?
    static var showEPUBAnnotationsHandler: (() -> Void)?
    static var saveHandler: (() -> Void)?
    static var insertTableHandler: (() -> Void)?
    static var insertHorizontalRuleHandler: (() -> Void)?
    static var closeFileHandler: (() -> Void)?
    static var closeFolderHandler: (() -> Void)?
    static var sidebarVisible = true
    static func reopenWindow() { reopenWindowHandler?() }
    static func openFile() { openFileHandler?() }
    static func openFolder() { openFolderHandler?() }
    static func openDocument(_ url: URL) { openDocumentHandler?(url) }
    static func openSettings() { openSettingsHandler?() }
    static func adjustBodySize(_ amount: Double) { adjustBodySizeHandler?(amount) }
    static func resetBodySize() { resetBodySizeHandler?() }
    static func adjustTypographySize(_ amount: Double) { adjustTypographySizeHandler?(amount) }
    static func resetTypographySize() { resetTypographySizeHandler?() }
    static func toggleSidebar() { toggleSidebarHandler?() }
    static func setDisplayMode(_ mode: ReaderDisplayMode) { setDisplayModeHandler?(mode) }
    static func applyHeadingLevel(_ level: Int) { applyHeadingLevelHandler?(level) }
    static func applyInlineSyntax(_ opening: String, _ closing: String) { applyInlineSyntaxHandler?(opening, closing) }
    static func applyLinePrefix(_ prefix: String) { applyLinePrefixHandler?(prefix) }
    static func wrapSelection(_ opening: String, _ closing: String) { wrapSelectionHandler?(opening, closing) }
    static func clearLinePrefix() { clearLinePrefixHandler?() }
    static func insertTemplate(_ text: String) { insertTemplateHandler?(text) }
    static func toggleEditPreview() { toggleEditPreviewHandler?() }
    static func toggleSplitMode() { toggleSplitModeHandler?() }
    static func openPreviewToSide() { openPreviewToSideHandler?() }
    static func setEPUBNotebookLayout(_ layout: EPUBNotebookLayout) { setEPUBNotebookLayoutHandler?(layout) }
    static func maximizeEPUBNotebookPane(_ pane: EPUBNotebookPane) { maximizeEPUBNotebookPaneHandler?(pane) }
    static func restoreEPUBNotebookLayout() { restoreEPUBNotebookLayoutHandler?() }
    static func addEPUBAnnotation() { addEPUBAnnotationHandler?() }
    static func showEPUBAnnotations() { showEPUBAnnotationsHandler?() }
    static func save() { saveHandler?() }
    static func insertTable() { insertTableHandler?() }
    static func insertHorizontalRule() { insertHorizontalRuleHandler?() }
    static func closeFile() { closeFileHandler?() }
    static func closeFolder() { closeFolderHandler?() }
}

private enum PendingDocumentOperation {
    case open(URL)
    case openFolder(URL)
    case closeFile
}

enum ReaderDisplayMode: String, CaseIterable {
    case read, edit, split
    var title: String {
        switch self { case .read: "阅读"; case .edit: "编辑"; case .split: "分栏" }
    }
}

enum EPUBNotebookLayout: String, CaseIterable {
    case epub, notes, stacked
    var title: String {
        switch self { case .epub: "原书"; case .notes: "笔记"; case .stacked: "上下" }
    }
}

enum EPUBNotebookPane: String {
    case epub, preview, editor, rightPreview, rightEditor

    var title: String {
        switch self {
        case .epub: "EPUB 原书"
        case .preview: "Markdown 笔记预览"
        case .editor: "Markdown 笔记编辑"
        case .rightPreview: "笔记预览占满右侧"
        case .rightEditor: "笔记编辑占满右侧"
        }
    }
}

enum FontSizeTarget {
    case body
    case outline
}

@MainActor
final class ReaderAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { ReaderActions.reopenWindow() }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        ReaderActions.openDocument(url)
    }
}

struct ReaderView: View {
    @Environment(\.openWindow) private var openWindow
    private let documentStore = LocalMarkdownDocumentStore()
    @AppStorage("reader.width") private var readerWidth = 720.0
    @AppStorage("reader.sidebarWidth") private var sidebarWidth = 270.0
    @AppStorage("reader.bodySize") private var bodySize = 15.0
    @AppStorage("reader.outlineFontScale") private var outlineFontScale = 1.0
    @AppStorage("reader.bodyFamily") private var bodyFamily = "系统默认"
    @AppStorage("reader.bodyColor") private var bodyColorHex = "#282725"
    @AppStorage("reader.backgroundColor") private var readerBackgroundHex = "#FFFFFF"
    @AppStorage("epubNotebook.previewBackgroundColor") private var notebookPreviewBackgroundHex = "#FFFFFF"
    @AppStorage("reader.lineHeight") private var lineHeight = 1.85
    @AppStorage("reader.paragraphSpacing") private var paragraphSpacing = 13.0
    @AppStorage("reader.strongColor") private var strongColorHex = "#A5563A"
    @AppStorage("reader.strongSize") private var strongSize = 15.0
    @AppStorage("reader.strongFamily") private var strongFamily = "系统默认"
    @AppStorage("reader.annotationFontSize") private var annotationFontSize = 11.0
    @AppStorage("reader.annotationFontFamily") private var annotationFontFamily = "系统默认"
    @AppStorage("reader.annotationTextColor") private var annotationTextColorHex = "#777777"
    @AppStorage("reader.headingStyles") private var headingStylesData = Data()
    @AppStorage("reader.outlineColors") private var outlineColorsData = Data()
    @AppStorage("reader.systemFontMigrationV1") private var systemFontMigrationDone = false
    @AppStorage("reader.lastFolder") private var lastFolderPath = ""

    @State private var folderURL: URL?
    @State private var markdownFiles: [URL] = []
    @State private var selectedFile: URL?
    @State private var source = ""
    @State private var editorSelection = NSRange(location: 0, length: 0)
    @State private var savedSource = ""
    @State private var documentTitle = "选择一个 Markdown 文件开始阅读"
    @State private var headings: [MarkdownBlock] = []
    @State private var blocks: [MarkdownBlock] = []
    @State private var expandedHeadings: Set<String> = []
    @State private var showSettings = false
    @State private var showSidebar = true
    @State private var fontSizeTarget: FontSizeTarget = .body
    @State private var showFolderContents = true
    @State private var scrollTarget: String?
    @State private var scrollRequest = 0
    @State private var synchronizedSourceLine = 1
    @State private var sourceLineRequest = 0
    @State private var editorFocusRequest = 0
    @State private var focusEditorAfterTableInsert = false
    @State private var showTableInsertion = false
    @State private var displayMode: ReaderDisplayMode = .read
    @State private var parseTask: Task<Void, Never>?
    @State private var pendingDocumentOperation: PendingDocumentOperation?
    @State private var showUnsavedAlert = false
    @State private var saveError: String?
    @State private var epubDocument: EPUBPackageDocument?
    @State private var epubCurrentChapter = 0
    @State private var epubHasChanges = false
    @State private var epubTargetFragment: String?
    @State private var epubNavigationRequest = 0
    @State private var epubAnnotations: [EPUBAnnotation] = []
    @State private var epubSelection: EPUBTextAnchor?
    @State private var epubEditingAnnotation: EPUBAnnotation?
    @State private var showEPUBAnnotationComposer = false
    @State private var showEPUBAnnotationList = false
    @State private var epubAnnotationJumpID: String?
    @State private var epubAnnotationJumpRequest = 0
    @State private var pendingEPUBURL: URL?
    @State private var showEPUBModeChoice = false
    @State private var isEPUBNotebook = false
    @State private var epubNotebookLayout: EPUBNotebookLayout = .stacked
    @State private var maximizedNotebookPane: EPUBNotebookPane?

    private var headingStyles: [HeadingStyle] {
        (try? JSONDecoder().decode([HeadingStyle].self, from: headingStylesData)) ?? HeadingStyle.defaults
    }
    private var outlineColors: [String] {
        guard let saved = try? JSONDecoder().decode([String].self, from: outlineColorsData), saved.count == 6 else {
            return Array(repeating: "#222222", count: 6)
        }
        return saved
    }

    var body: some View {
        HStack(spacing: 0) {
            if showSidebar {
                sidebar.frame(width: sidebarWidth)
                SidebarWidthResizeHandle(width: $sidebarWidth)
            }
            VStack(spacing: 0) {
                toolbar
                Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
                documentPane
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .coordinateSpace(name: "mainWindow")
        .preferredColorScheme(.light)
        .sheet(isPresented: $showSettings) {
            SettingsView(readerWidth: $readerWidth, bodyColorHex: $bodyColorHex, readerBackgroundHex: $readerBackgroundHex,
                         strongColorHex: $strongColorHex,
                         strongSize: $strongSize, strongFamily: $strongFamily,
                         headingStylesData: $headingStylesData, bodySize: $bodySize,
                         bodyFamily: $bodyFamily, lineHeight: $lineHeight,
                         paragraphSpacing: $paragraphSpacing, outlineColorsData: $outlineColorsData,
                         annotationFontSize: $annotationFontSize, annotationFontFamily: $annotationFontFamily,
                         annotationTextColorHex: $annotationTextColorHex)
        }
        .sheet(isPresented: $showTableInsertion, onDismiss: {
            if focusEditorAfterTableInsert {
                editorFocusRequest += 1
                focusEditorAfterTableInsert = false
            }
        }) {
            TableInsertionSheet { cells, formatted in
                insertTable(cells: cells, formatted: formatted)
            }
        }
        .sheet(isPresented: $showEPUBAnnotationComposer, onDismiss: { epubEditingAnnotation = nil }) {
            if let anchor = epubEditingAnnotation?.anchor ?? epubSelection {
                EPUBAnnotationComposer(anchor: anchor, existing: epubEditingAnnotation) { note, colorHex, markStyle in
                    saveEPUBAnnotation(note: note, colorHex: colorHex, markStyle: markStyle)
                }
            }
        }
        .sheet(isPresented: $showEPUBAnnotationList) {
            EPUBAnnotationListSheet(annotations: epubAnnotations, onSelect: jumpToEPUBAnnotation,
                                    onEdit: { annotation in
                                        epubEditingAnnotation = annotation
                                        DispatchQueue.main.async { showEPUBAnnotationComposer = true }
                                    },
                                    onDelete: deleteEPUBAnnotation)
        }
        .alert("文档有未保存的修改", isPresented: $showUnsavedAlert) {
            Button("保存") {
                if saveDocument() { continuePendingDocumentOperation() }
            }
            Button("不保存", role: .destructive) { continuePendingDocumentOperation() }
            Button("取消", role: .cancel) { pendingDocumentOperation = nil }
        } message: {
            Text("继续此操作前，要先保存当前修改吗？")
        }
        .alert("保存失败", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("好", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }
        .confirmationDialog("打开 EPUB 的方式", isPresented: $showEPUBModeChoice, titleVisibility: .visible) {
            Button("编辑 EPUB 原文") { openEPUBOriginal() }
            Button("写配套 Markdown 笔记") { openEPUBNote() }
            Button("取消", role: .cancel) { pendingEPUBURL = nil }
        } message: {
            Text("原文编辑会另存为新的 EPUB；笔记会与原书同名保存为 .md 文件。")
        }
        .onAppear {
            ReaderActions.reopenWindowHandler = { openWindow(id: "main") }
            ReaderActions.openFileHandler = chooseFile
            ReaderActions.openFolderHandler = chooseFolder
            ReaderActions.openDocumentHandler = open
            ReaderActions.openSettingsHandler = { showSettings = true }
            ReaderActions.adjustBodySizeHandler = { bodySize = min(24, max(12, bodySize + $0)) }
            ReaderActions.resetBodySizeHandler = { bodySize = 15 }
            ReaderActions.adjustTypographySizeHandler = { amount in
                switch fontSizeTarget {
                case .body: bodySize = min(24, max(12, bodySize + amount))
                case .outline: outlineFontScale = min(1.6, max(0.75, outlineFontScale + amount * 0.1))
                }
            }
            ReaderActions.resetTypographySizeHandler = {
                switch fontSizeTarget {
                case .body: bodySize = 15
                case .outline: outlineFontScale = 1
                }
            }
            ReaderActions.sidebarVisible = showSidebar
            ReaderActions.toggleSidebarHandler = {
                showSidebar.toggle()
                ReaderActions.sidebarVisible = showSidebar
            }
            ReaderActions.setDisplayModeHandler = { displayMode = $0 }
            ReaderActions.applyHeadingLevelHandler = applyHeadingLevel
            ReaderActions.applyInlineSyntaxHandler = applyInlineSyntax
            ReaderActions.applyLinePrefixHandler = applyLinePrefix
            ReaderActions.wrapSelectionHandler = wrapSelection
            ReaderActions.clearLinePrefixHandler = clearLinePrefix
            ReaderActions.insertTemplateHandler = insertTemplate
            ReaderActions.toggleEditPreviewHandler = {
                if isEPUBNotebook, epubNotebookLayout == .epub {
                    epubNotebookLayout = .notes
                    displayMode = .edit
                } else {
                    displayMode = displayMode == .read ? .edit : .read
                }
            }
            ReaderActions.toggleSplitModeHandler = {
                if isEPUBNotebook {
                    epubNotebookLayout = epubNotebookLayout == .stacked ? .notes : .stacked
                } else if epubDocument != nil {
                    displayMode = displayMode == .edit ? .read : .edit
                } else {
                    displayMode = displayMode == .split ? .edit : .split
                }
            }
            ReaderActions.openPreviewToSideHandler = {
                if isEPUBNotebook {
                    if epubNotebookLayout == .epub { epubNotebookLayout = .stacked }
                    displayMode = .split
                } else if epubDocument != nil {
                    displayMode = .edit
                } else {
                    displayMode = .split
                }
            }
            ReaderActions.setEPUBNotebookLayoutHandler = { epubNotebookLayout = $0 }
            ReaderActions.maximizeEPUBNotebookPaneHandler = { pane in
                guard isEPUBNotebook else { return }
                epubNotebookLayout = .stacked
                maximizedNotebookPane = pane
            }
            ReaderActions.restoreEPUBNotebookLayoutHandler = { maximizedNotebookPane = nil }
            ReaderActions.addEPUBAnnotationHandler = {
                guard epubDocument != nil, epubSelection != nil else { return }
                epubEditingAnnotation = nil
                showEPUBAnnotationComposer = true
            }
            ReaderActions.showEPUBAnnotationsHandler = {
                guard epubDocument != nil else { return }
                showEPUBAnnotationList = true
            }
            ReaderActions.saveHandler = { _ = saveDocument() }
            ReaderActions.closeFileHandler = closeFile
            ReaderActions.closeFolderHandler = closeFolder
            ReaderActions.insertHorizontalRuleHandler = insertHorizontalRule
            ReaderActions.insertTableHandler = {
                guard selectedFile != nil, displayMode != .read else { return }
                showTableInsertion = true
            }
            migrateDefaultHeadingColors()
            migrateSystemFontDefaults()
            if !lastFolderPath.isEmpty {
                let url = URL(fileURLWithPath: lastFolderPath)
                if FileManager.default.fileExists(atPath: url.path) { loadFolder(url) }
            }
        }
        .onChange(of: source) { _, newSource in
            scheduleParse(for: newSource)
        }
        .onChange(of: epubNotebookLayout) { _, layout in
            if layout != .stacked { maximizedNotebookPane = nil }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("阅读空间").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Button(action: chooseFolder) { Image(systemName: "folder.badge.plus") }
                    .buttonStyle(.plain).help("打开文件夹").toolbarHint("打开文件夹")
                Button(action: chooseFile) { Image(systemName: "doc.badge.plus") }
                    .buttonStyle(.plain).help("打开文件").toolbarHint("打开文件")
            }.padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 12)

            if !markdownFiles.isEmpty {
                Button { showFolderContents.toggle() } label: {
                    HStack(spacing: 7) {
                        Image(systemName: showFolderContents ? "chevron.down" : "chevron.right").font(.system(size: 9, weight: .bold))
                        Text(folderURL?.lastPathComponent ?? "文件夹").font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(markdownFiles.count)").font(.system(size: 11, design: .rounded)).foregroundStyle(.tertiary)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.vertical, 7)
                if showFolderContents {
                    ScrollView {
                        VStack(spacing: 1) {
                            ForEach(markdownFiles, id: \.path) { url in
                                Button { open(url) } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "doc.text").font(.system(size: 12)).foregroundStyle(.secondary)
                                        Text(relativePath(url)).lineLimit(1).truncationMode(.middle)
                                            .font(.system(size: 12))
                                        Spacer(minLength: 0)
                                    }.padding(.horizontal, 18).padding(.vertical, 7)
                                        .background(selectedFile == url ? Color.accentColor.opacity(0.11) : .clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }.buttonStyle(.plain).foregroundStyle(selectedFile == url ? Color.accentColor : Color.primary.opacity(0.8))
                                    .padding(.horizontal, 8)
                            }
                        }.padding(.bottom, 8)
                    }.frame(maxHeight: 170)
                }
                Divider().padding(.horizontal, 14)
            }

            HStack {
                Text("目录").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                if !headings.isEmpty {
                    Button { expandedHeadings = Set(headings.map(\.id)) } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left").font(.system(size: 10))
                    }.buttonStyle(.plain).help("展开全部目录").toolbarHint("展开全部目录")
                    Button { expandedHeadings.removeAll() } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 10))
                    }.buttonStyle(.plain).help("收起子目录").toolbarHint("收起子目录")
                }
            }.padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 8)

            if let epubDocument {
                if epubDocument.tableOfContents.isEmpty {
                    Text("此 EPUB 没有可识别的目录")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                        .padding(.horizontal, 18).padding(.top, 8)
                    Spacer()
                } else {
                    List {
                        ForEach(Array(epubDocument.tableOfContents.enumerated()), id: \.element.id) { _, item in
                            Button {
                                if let target = epubDocument.navigationTarget(for: item) {
                                    epubCurrentChapter = target.chapterIndex
                                    epubTargetFragment = target.fragment
                                    epubSelection = nil
                                    epubAnnotationJumpID = nil
                                    epubNavigationRequest += 1
                                }
                            } label: {
                                Text(item.title).lineLimit(2)
                                    .font(.system(size: max(11, 12 * outlineFontScale), weight: item.level == 0 ? .medium : .regular))
                                    .padding(.leading, CGFloat(min(item.level, 6) * 12))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                                    .background(epubDocument.navigationTarget(for: item)?.chapterIndex == epubCurrentChapter ? Color.accentColor.opacity(0.11) : .clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 8))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .simultaneousGesture(TapGesture().onEnded { fontSizeTarget = .outline })
                }
            } else if headings.isEmpty {
                Text("文档中的标题会显示在这里").font(.system(size: 11)).foregroundStyle(.tertiary)
                    .padding(.horizontal, 18).padding(.top, 8)
                    .simultaneousGesture(TapGesture().onEnded { fontSizeTarget = .outline })
                Spacer()
            } else {
                List {
                    ForEach(topHeadings) { heading in
                        HeadingRow(heading: heading, allHeadings: headings, expanded: $expandedHeadings,
                                   styles: headingStyles, outlineColors: outlineColors,
                                   fontScale: outlineFontScale, onSelect: jumpTo)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 8))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .simultaneousGesture(TapGesture().onEnded { fontSizeTarget = .outline })
            }
            Spacer(minLength: 0)
            HStack(spacing: 7) {
                Image(systemName: "text.alignleft").font(.system(size: 11))
                Text(epubDocument != nil ? "EPUB" : displayMode == .read ? "预览" : displayMode == .edit ? "编辑器" : "编辑 + 预览")
                    .font(.system(size: 11))
                Spacer()
            }.foregroundStyle(.tertiary).padding(.horizontal, 18).padding(.vertical, 14)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        .onHover { isInside in
            if isInside { fontSizeTarget = .outline }
        }
    }

    private func toolbarModeSegment(_ symbol: String, selected: Bool, hint: String,
                                    action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity).frame(height: 22)
                .background(selected ? Color.accentColor.opacity(0.18) : .clear,
                            in: RoundedRectangle(cornerRadius: 3))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(hint)
        .toolbarHint(hint)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                showSidebar.toggle()
                ReaderActions.sidebarVisible = showSidebar
            } label: {
                Image(systemName: showSidebar ? "sidebar.left" : "sidebar.right")
                    .font(.system(size: 13))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help(showSidebar ? "隐藏目录侧栏（⌘⌥1）" : "显示目录侧栏（⌘⌥1）")
            .toolbarHint(showSidebar ? "隐藏目录侧栏 · ⌘⌥1" : "显示目录侧栏 · ⌘⌥1")
            Text(selectedFile?.deletingPathExtension().lastPathComponent ?? documentTitle)
                .font(.system(size: 13, weight: .medium)).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let epubDocument, !epubDocument.chapters.isEmpty {
                Button {
                    epubCurrentChapter = max(0, epubCurrentChapter - 1)
                    epubTargetFragment = nil
                    epubSelection = nil
                    epubAnnotationJumpID = nil
                    epubNavigationRequest += 1
                } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.plain)
                .disabled(epubCurrentChapter == 0)
                .help("上一章 / 上一页（←）")
                .toolbarHint("上一章 / 上一页 · ←")
                Text("\(epubCurrentChapter + 1) / \(epubDocument.chapters.count)")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    .help("EPUB 阅读顺序中的章节位置")
                Button {
                    epubCurrentChapter = min(epubDocument.chapters.count - 1, epubCurrentChapter + 1)
                    epubTargetFragment = nil
                    epubSelection = nil
                    epubAnnotationJumpID = nil
                    epubNavigationRequest += 1
                } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.plain)
                .disabled(epubCurrentChapter >= epubDocument.chapters.count - 1)
                .help("下一章 / 下一页（→）")
                .toolbarHint("下一章 / 下一页 · →")
                Button { epubEditingAnnotation = nil; showEPUBAnnotationComposer = true } label: {
                    Image(systemName: "highlighter").font(.system(size: 13)).frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .disabled(epubSelection == nil)
                .help(epubSelection == nil ? "先在原书中选中文字，再添加注释（⇧⌘M）" : "为所选文字添加注释（⇧⌘M）")
                .toolbarHint("选择原书文字后添加注释 · ⇧⌘M")
                Button { showEPUBAnnotationList = true } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "text.book.closed").font(.system(size: 12))
                        if !epubAnnotations.isEmpty { Text("\(epubAnnotations.count)").font(.system(size: 10, design: .rounded)) }
                    }.frame(height: 22)
                }
                .buttonStyle(.plain)
                .help("查看 EPUB 注释（⌥⌘M）")
                .toolbarHint("查看、修改或删除注释 · ⌥⌘M")
            }
            HStack(spacing: 7) {
                Image(systemName: "rectangle.center.inset.filled").font(.system(size: 11)).foregroundStyle(.secondary)
                    .help("调整阅读区域宽度；拖动旁边的滑块")
                    .toolbarHint("阅读区域宽度")
                Slider(value: $readerWidth, in: 520...1040, step: 20)
                    .frame(width: 118).help("调整阅读宽度：\(Int(readerWidth)) 像素")
                    .toolbarHint("拖动调整阅读区域宽度：\(Int(readerWidth)) px")
                Button { ReaderActions.adjustTypographySize(-1) } label: { Text("A−").font(.system(size: 12, weight: .medium)) }
                    .buttonStyle(.plain).help("缩小当前区域字体（⌘−）")
                    .toolbarHint("缩小当前区域字体 · ⌘−")
                Button { ReaderActions.adjustTypographySize(1) } label: { Text("A+").font(.system(size: 12, weight: .medium)) }
                    .buttonStyle(.plain).help("放大当前区域字体（⌘+）")
                    .toolbarHint("放大当前区域字体 · ⌘+")
                Button { showSettings = true } label: { Label("样式", systemImage: "textformat.size").font(.system(size: 12)) }
                    .buttonStyle(.plain).help("字体与行距（⌘,）")
                    .toolbarHint("字体、行距与注释文字样式 · ⌘,")
                if isEPUBNotebook {
                    HStack(spacing: 1) {
                        toolbarModeSegment("book", selected: epubNotebookLayout == .epub,
                                           hint: "只看 EPUB 原书 · ⌃⌘1") { epubNotebookLayout = .epub }
                        toolbarModeSegment("doc.text", selected: epubNotebookLayout == .notes,
                                           hint: "只看 Markdown 笔记 · ⌃⌘2") { epubNotebookLayout = .notes }
                        toolbarModeSegment("rectangle.split.3x1", selected: epubNotebookLayout == .stacked,
                                           hint: "原书 + 笔记预览 + 编辑 · ⌃⌘3") { epubNotebookLayout = .stacked }
                    }
                    .padding(2).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                    .frame(width: 86).help("切换原书、笔记或三栏工作区")
                    if epubNotebookLayout == .notes {
                        HStack(spacing: 1) {
                            toolbarModeSegment("eye", selected: displayMode == .read,
                                               hint: "只看笔记预览 · ⇧⌘V") { displayMode = .read }
                            toolbarModeSegment("pencil.line", selected: displayMode == .edit,
                                               hint: "编辑 Markdown 笔记 · ⌘R") { displayMode = .edit }
                            toolbarModeSegment("rectangle.split.2x1", selected: displayMode == .split,
                                               hint: "笔记编辑与预览并排") { displayMode = .split }
                        }
                        .padding(2).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                        .frame(width: 86).help("切换 Markdown 笔记的编辑与预览")
                    }
                } else if epubDocument != nil {
                    HStack(spacing: 1) {
                        toolbarModeSegment("eye", selected: displayMode == .read,
                                           hint: "阅读 EPUB 原书 · ⌘R") { displayMode = .read }
                        toolbarModeSegment("pencil.line", selected: displayMode == .edit,
                                           hint: "所见即所得编辑 EPUB · ⌘R") { displayMode = .edit }
                    }
                    .padding(2).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                    .frame(width: 58).help("阅读或编辑 EPUB 原文（⌘R 切换）")
                } else {
                    HStack(spacing: 1) {
                        toolbarModeSegment("eye", selected: displayMode == .read,
                                           hint: "只看 Markdown 预览 · ⇧⌘V") { displayMode = .read }
                        toolbarModeSegment("pencil.line", selected: displayMode == .edit,
                                           hint: "只看编辑器 · ⌘R") { displayMode = .edit }
                        toolbarModeSegment("rectangle.split.2x1", selected: displayMode == .split,
                                           hint: "编辑器与预览并排") { displayMode = .split }
                    }
                    .padding(2).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                    .frame(width: 86).help("切换编辑器与 Markdown 预览")
                }
                if isDirty {
                    Button("保存") { _ = saveDocument() }.buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium)).help("保存修改（⌘S）")
                        .toolbarHint("保存修改 · ⌘S")
                }
            }.fixedSize()
        }
        .padding(.leading, 12)
        .padding(.trailing, 74)
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .zIndex(10)
    }

    private func readingPane(backgroundHex: String? = nil) -> some View {
        let paneBackgroundHex = backgroundHex ?? readerBackgroundHex
        return Group {
            if blocks.isEmpty && selectedFile == nil {
                VStack(spacing: 14) {
                    Image(systemName: "book.closed").font(.system(size: 36, weight: .ultraLight)).foregroundStyle(.tertiary)
                    Text("让 Markdown 回到阅读的样子").font(.system(size: 17, weight: .medium)).foregroundStyle(.secondary)
                    Text("打开一个文件，或选择文件夹浏览文档").font(.system(size: 12)).foregroundStyle(.tertiary)
                    HStack(spacing: 10) {
                        Button("打开文件") { chooseFile() }.buttonStyle(.bordered)
                        Button("打开文件夹") { chooseFolder() }.buttonStyle(.bordered)
                    }.padding(.top, 4)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ReaderWebView(blocks: blocks, readerWidth: readerWidth, headingStyles: headingStyles,
                              bodyColorHex: bodyColorHex, readerBackgroundHex: paneBackgroundHex,
                              strongColorHex: strongColorHex, strongSize: strongSize, strongFamily: strongFamily,
                              bodySize: bodySize, bodyFamily: bodyFamily, lineHeight: lineHeight,
                              paragraphSpacing: paragraphSpacing,
                              baseURL: selectedFile?.deletingLastPathComponent(), scrollTarget: scrollTarget,
                              scrollRequest: scrollRequest, sourceLineTarget: synchronizedSourceLine,
                              sourceLineRequest: sourceLineRequest, onSourceLineChange: synchronizeSourceLine)
            }
        }
        .background(Color(hex: paneBackgroundHex))
    }

    private var documentPane: some View {
        Group {
            if let epubDocument, epubDocument.chapters.indices.contains(epubCurrentChapter), isEPUBNotebook {
                switch epubNotebookLayout {
                case .epub:
                    epubChapterPane(epubDocument, editable: false)
                case .notes:
                    markdownWorkspacePane
                case .stacked:
                    epubNotebookWorkspace(epubDocument)
                }
            } else if let epubDocument, epubDocument.chapters.indices.contains(epubCurrentChapter) {
                switch displayMode {
                case .read:
                    epubChapterPane(epubDocument, editable: false)
                case .edit:
                    epubChapterPane(epubDocument, editable: true)
                case .split:
                    epubChapterPane(epubDocument, editable: true)
                }
            } else {
                markdownWorkspacePane
            }
        }
        .simultaneousGesture(TapGesture().onEnded { fontSizeTarget = .body })
        .onHover { isInside in
            if isInside { fontSizeTarget = .body }
        }
    }

    @ViewBuilder
    private func epubNotebookWorkspace(_ document: EPUBPackageDocument) -> some View {
        if let maximizedNotebookPane {
            switch maximizedNotebookPane {
            case .epub:
                notebookEPUBPane(document)
            case .preview:
                notebookPreviewPane
            case .editor:
                notebookEditorPane
            case .rightPreview:
                HSplitView {
                    notebookEPUBPane(document).frame(minWidth: 300)
                    notebookPreviewPane.frame(minWidth: 300)
                }
            case .rightEditor:
                HSplitView {
                    notebookEPUBPane(document).frame(minWidth: 300)
                    notebookEditorPane.frame(minWidth: 300)
                }
            }
        } else {
            HSplitView {
                notebookEPUBPane(document)
                    .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                VSplitView {
                    notebookPreviewPane
                        .frame(minHeight: 180, maxHeight: .infinity)
                    notebookEditorPane
                        .frame(minHeight: 180, maxHeight: .infinity)
                }
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func notebookEPUBPane(_ document: EPUBPackageDocument) -> some View {
        VStack(spacing: 0) {
            notebookPaneHeader(.epub)
            epubChapterPane(document, editable: false)
        }
    }

    private var notebookPreviewPane: some View {
        VStack(spacing: 0) {
            notebookPaneHeader(.preview)
            readingPane(backgroundHex: notebookPreviewBackgroundHex)
        }
    }

    private var notebookEditorPane: some View {
        VStack(spacing: 0) {
            notebookPaneHeader(.editor)
            editorPane
        }
    }

    private func notebookPaneHeader(_ pane: EPUBNotebookPane) -> some View {
        HStack(spacing: 6) {
            Text(pane.title).font(.system(size: 11, weight: .medium))
            Spacer()
            Button {
                cycleNotebookExpansion(for: pane)
            } label: {
                Image(systemName: maximizedNotebookPane == pane ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10))
                    .frame(width: 22, height: 20)
            }
            .buttonStyle(.plain)
            .help(notebookExpansionHelp(for: pane))
            .accessibilityLabel(notebookExpansionHelp(for: pane))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.78))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1) }
    }

    private func cycleNotebookExpansion(for pane: EPUBNotebookPane) {
        switch pane {
        case .epub:
            maximizedNotebookPane = maximizedNotebookPane == .epub ? nil : .epub
        case .preview:
            switch maximizedNotebookPane {
            case nil: maximizedNotebookPane = .rightPreview
            case .rightPreview: maximizedNotebookPane = .preview
            case .preview: maximizedNotebookPane = nil
            default: maximizedNotebookPane = .rightPreview
            }
        case .editor:
            switch maximizedNotebookPane {
            case nil: maximizedNotebookPane = .rightEditor
            case .rightEditor: maximizedNotebookPane = .editor
            case .editor: maximizedNotebookPane = nil
            default: maximizedNotebookPane = .rightEditor
            }
        case .rightPreview, .rightEditor:
            break
        }
    }

    private func notebookExpansionHelp(for pane: EPUBNotebookPane) -> String {
        switch (pane, maximizedNotebookPane) {
        case (.epub, .epub): "恢复三栏布局"
        case (.epub, _): "最大化 EPUB 原书"
        case (.preview, .rightPreview): "将笔记预览最大化到整个工作区"
        case (.preview, .preview): "恢复三栏布局"
        case (.preview, _): "让笔记预览占满右侧"
        case (.editor, .rightEditor): "将笔记编辑最大化到整个工作区"
        case (.editor, .editor): "恢复三栏布局"
        case (.editor, _): "让笔记编辑占满右侧"
        case (.rightPreview, _): "让笔记预览占满右侧"
        case (.rightEditor, _): "让笔记编辑占满右侧"
        }
    }

    private var markdownWorkspacePane: some View {
        Group {
            switch displayMode {
            case .read:
                readingPane()
            case .edit:
                editorPane
            case .split:
                HSplitView {
                    editorPane.frame(minWidth: 260)
                    readingPane().frame(minWidth: 300)
                }
            }
        }
    }

    private func epubChapterPane(_ document: EPUBPackageDocument, editable: Bool) -> some View {
        EPUBChapterView(chapter: document.chapters[epubCurrentChapter], resourceRoot: document.workingDirectory,
                        editable: editable, width: readerWidth,
                        bodySize: bodySize, bodyFamily: bodyFamily, bodyColorHex: bodyColorHex,
                        annotationFontSize: annotationFontSize, annotationFontFamily: annotationFontFamily,
                        annotationTextColorHex: annotationTextColorHex,
                        backgroundColorHex: readerBackgroundHex,
                        lineHeight: lineHeight,
                        scrollFragment: epubTargetFragment, scrollRequest: epubNavigationRequest,
                        annotations: epubAnnotations, annotationJumpID: epubAnnotationJumpID,
                        annotationJumpRequest: epubAnnotationJumpRequest,
                        onNavigateChapter: { offset in
            let target = epubCurrentChapter + offset
            guard document.chapters.indices.contains(target) else { return }
            epubCurrentChapter = target
            epubTargetFragment = nil
            epubSelection = nil
            epubAnnotationJumpID = nil
            epubNavigationRequest += 1
        }, onTextSelection: { epubSelection = $0 }, onEditAnnotation: { id in
            guard let annotation = epubAnnotations.first(where: { $0.id == id }) else { return }
            epubEditingAnnotation = annotation
            showEPUBAnnotationComposer = true
        }, onDeleteAnnotation: { id in
            guard let annotation = epubAnnotations.first(where: { $0.id == id }) else { return }
            deleteEPUBAnnotation(annotation)
        }) { body in
            do {
                try document.replaceChapterBody(at: epubCurrentChapter, with: body)
                epubHasChanges = true
            } catch {
                saveError = error.localizedDescription
            }
        }
        .background(Color(hex: readerBackgroundHex))
    }

    private func loadEPUBAnnotations(for document: EPUBPackageDocument) {
        do {
            epubAnnotations = try EPUBAnnotationStore.load(for: document.sourceURL)
        } catch {
            epubAnnotations = []
            saveError = "无法读取注释文件：\(error.localizedDescription)"
        }
        epubSelection = nil
        epubAnnotationJumpID = nil
        epubAnnotationJumpRequest += 1
    }

    private func saveEPUBAnnotation(note: String, colorHex: String, markStyle: EPUBAnnotationMarkStyle) {
        guard let document = epubDocument else { return }
        var updated = epubAnnotations
        if let existing = epubEditingAnnotation, let index = updated.firstIndex(where: { $0.id == existing.id }) {
            updated[index].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            updated[index].colorHex = colorHex
            updated[index].markStyle = markStyle
        } else {
            guard let anchor = epubSelection, document.chapters.indices.contains(epubCurrentChapter) else { return }
            updated.append(EPUBAnnotation(chapterHref: document.chapters[epubCurrentChapter].href,
                                          anchor: anchor,
                                          note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                          colorHex: colorHex, markStyle: markStyle))
        }
        do {
            try EPUBAnnotationStore.save(updated, for: document.sourceURL)
            epubAnnotations = updated
            epubSelection = nil
            epubEditingAnnotation = nil
        } catch {
            saveError = "无法保存注释：\(error.localizedDescription)"
        }
    }

    private func deleteEPUBAnnotation(_ annotation: EPUBAnnotation) {
        guard let document = epubDocument else { return }
        let updated = epubAnnotations.filter { $0.id != annotation.id }
        do {
            try EPUBAnnotationStore.save(updated, for: document.sourceURL)
            epubAnnotations = updated
        } catch {
            saveError = "无法保存注释：\(error.localizedDescription)"
        }
    }

    private func jumpToEPUBAnnotation(_ annotation: EPUBAnnotation) {
        guard let document = epubDocument,
              let chapter = document.chapters.firstIndex(where: { $0.href == annotation.chapterHref }) else { return }
        epubCurrentChapter = chapter
        epubTargetFragment = nil
        epubAnnotationJumpID = annotation.id
        epubAnnotationJumpRequest += 1
        epubNavigationRequest += 1
        epubSelection = nil
    }

    private var editorPane: some View {
        VStack(spacing: 0) {
            if !(isEPUBNotebook && epubNotebookLayout == .stacked) {
            HStack(spacing: 7) {
                Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 11))
                Text(isEPUBNotebook ? "Markdown 笔记" : "Markdown 源码").font(.system(size: 11, weight: .medium))
                Spacer()
                if isDirty { Text("未保存").font(.system(size: 10)).foregroundStyle(.secondary) }
            }
            .foregroundStyle(.secondary).padding(.horizontal, 16).frame(height: 34)
            Divider()
            }
            MarkdownSourceEditor(text: $source, selection: $editorSelection,
                                 fontSize: CGFloat(max(13, bodySize)),
                                 headingStyles: headingStyles,
                                 bodyColorHex: bodyColorHex,
                                 strongColorHex: strongColorHex,
                                 sourceLineTarget: synchronizedSourceLine,
                                 sourceLineRequest: sourceLineRequest,
                                 focusRequest: editorFocusRequest,
                                 onSourceLineChange: synchronizeSourceLine)
                .background(Color(nsColor: .textBackgroundColor))
                .disabled(selectedFile == nil)
                .overlay {
                    if selectedFile == nil {
                        Text("打开一个 Markdown 文件即可开始编辑")
                            .font(.system(size: 13)).foregroundStyle(.tertiary)
                    }
                }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .frame(maxWidth: readerWidth + 76)
        .frame(maxWidth: .infinity)
    }

    private var isDirty: Bool { source != savedSource || epubHasChanges }

    private var topHeadings: [MarkdownBlock] { headings.filter { $0.parentID == nil } }

    private func jumpTo(_ id: String) {
        fontSizeTarget = .outline
        scrollTarget = id
        scrollRequest += 1
        if let heading = headings.first(where: { $0.id == id }) {
            synchronizedSourceLine = heading.sourceLine
            sourceLineRequest += 1
        }
    }
    private func synchronizeSourceLine(_ line: Int) {
        guard line > 0, abs(line - synchronizedSourceLine) > 1 else { return }
        synchronizedSourceLine = line
        sourceLineRequest += 1
    }

    private func insertTable(cells: [[String]], formatted: Bool) {
        guard selectedFile != nil, displayMode != .read else { return }
        let table = MarkdownTableFormatter.markdown(cells, formatted: formatted)
        let original = source as NSString
        let location = min(editorSelection.location, original.length)
        let length = min(editorSelection.length, original.length - location)
        let before = original.substring(to: location)
        let after = original.substring(from: location + length)
        let prefix = before.isEmpty || before.hasSuffix("\n\n") ? "" : before.hasSuffix("\n") ? "\n" : "\n\n"
        let suffix = after.isEmpty || after.hasPrefix("\n\n") ? "" : after.hasPrefix("\n") ? "\n" : "\n\n"
        let insertion = prefix + table + suffix
        source = original.replacingCharacters(in: NSRange(location: location, length: length), with: insertion)
        let firstCellOffset = location + (prefix as NSString).length + 2
        let firstHeader = cells.first?.first ?? ""
        editorSelection = NSRange(location: firstCellOffset, length: (firstHeader as NSString).length)
        synchronizedSourceLine = (source as NSString).substring(to: firstCellOffset).components(separatedBy: "\n").count
        sourceLineRequest += 1
        focusEditorAfterTableInsert = true
    }
    private func migrateDefaultHeadingColors() {
        let previousPalettes = [
            ["#252525", "#303030", "#373737", "#444444", "#505050", "#626262"],
            Array(repeating: "#333333", count: 6)
        ]
        guard var saved = try? JSONDecoder().decode([HeadingStyle].self, from: headingStylesData),
              saved.count == 6,
              previousPalettes.contains(where: { palette in
                  saved.sorted(by: { $0.id < $1.id }).enumerated().allSatisfy({ $0.element.colorHex.uppercased() == palette[$0.offset] })
              }) else { return }
        for index in saved.indices { saved[index].colorHex = "#0797C2" }
        headingStylesData = (try? JSONEncoder().encode(saved)) ?? headingStylesData
    }
    private func migrateSystemFontDefaults() {
        guard !systemFontMigrationDone else { return }
        if bodySize == 16, bodyFamily == "PingFang SC", lineHeight == 1.85, paragraphSpacing == 13 { bodySize = 15 }
        if bodyFamily == "PingFang SC" { bodyFamily = "系统默认" }
        if strongFamily == "PingFang SC" { strongFamily = "系统默认" }
        if var saved = try? JSONDecoder().decode([HeadingStyle].self, from: headingStylesData) {
            for index in saved.indices where saved[index].fontFamily == "PingFang SC" {
                saved[index].fontFamily = "系统默认"
            }
            headingStylesData = (try? JSONEncoder().encode(saved)) ?? headingStylesData
        }
        systemFontMigrationDone = true
    }
    private func relativePath(_ url: URL) -> String {
        guard let folderURL else { return url.lastPathComponent }
        return String(url.path.dropFirst(folderURL.path.count + 1))
    }
    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .init(filenameExtension: "md")!, .init(filenameExtension: "epub")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.treatsFilePackagesAsDirectories = true
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            if isUnpackedEPUBDirectory(url) { open(url) }
            else { loadFolder(url) }
        }
    }
    private func loadFolder(_ url: URL) {
        if isDirty {
            pendingDocumentOperation = .openFolder(url)
            showUnsavedAlert = true
            return
        }
        openFolderContents(url)
    }
    private func openFolderContents(_ url: URL) {
        folderURL = url
        lastFolderPath = url.path
        markdownFiles = (try? documentStore.listMarkdownDocuments(in: url)) ?? []
        if let first = markdownFiles.first {
            open(first)
        } else {
            selectedFile = nil
            source = ""
            savedSource = ""
            blocks = []
            headings = []
            documentTitle = "此文件夹中没有 Markdown 文件"
        }
    }
    private func open(_ url: URL) {
        if url == selectedFile { return }
        guard !isDirty else {
            pendingDocumentOperation = .open(url)
            showUnsavedAlert = true
            return
        }
        performOpen(url)
    }

    private func performOpen(_ url: URL) {
        if url.pathExtension.lowercased() == "epub" || isUnpackedEPUBDirectory(url) {
            pendingEPUBURL = url
            showEPUBModeChoice = true
        } else if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            saveError = "所选文件夹不是已解压的 EPUB：找不到 META-INF/container.xml。"
        } else {
            loadDocument(url)
        }
    }

    private func isUnpackedEPUBDirectory(_ url: URL) -> Bool {
        guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return false }
        return FileManager.default.fileExists(atPath: url.appendingPathComponent("META-INF/container.xml").path)
    }

    private func openEPUBOriginal() {
        guard let url = pendingEPUBURL else { return }
        pendingEPUBURL = nil
        do {
            let document = try EPUBPackageDocument.open(url)
            epubDocument = document
            loadEPUBAnnotations(for: document)
            isEPUBNotebook = false
            maximizedNotebookPane = nil
            epubCurrentChapter = 0
            epubHasChanges = false
            selectedFile = nil
            source = ""
            savedSource = ""
            blocks = []
            headings = []
            documentTitle = epubDocument?.title ?? url.deletingPathExtension().lastPathComponent
            displayMode = .edit
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func openEPUBNote() {
        guard let url = pendingEPUBURL else { return }
        pendingEPUBURL = nil
        let noteURL = url.deletingPathExtension().appendingPathExtension("md")
        do {
            let document = try EPUBPackageDocument.open(url)
            epubDocument = document
            loadEPUBAnnotations(for: document)
        } catch {
            saveError = error.localizedDescription
            return
        }
        if !FileManager.default.fileExists(atPath: noteURL.path) {
            guard FileManager.default.createFile(atPath: noteURL.path, contents: Data()) else {
                saveError = "无法在 EPUB 所在文件夹中创建 Markdown 笔记。"
                return
            }
        }
        isEPUBNotebook = true
        epubNotebookLayout = .stacked
        maximizedNotebookPane = nil
        epubCurrentChapter = 0
        loadDocument(noteURL, preservingEPUB: true)
        displayMode = .edit
    }

    private func loadDocument(_ url: URL, preservingEPUB: Bool = false) {
        do {
            let document = try documentStore.openDocument(at: url)
            if !preservingEPUB {
                epubDocument = nil
                isEPUBNotebook = false
            }
            epubHasChanges = false
            source = document.source
            savedSource = document.source
            selectedFile = url
            documentTitle = document.title
            scrollTarget = nil
            synchronizedSourceLine = 1
            sourceLineRequest += 1
            blocks = MarkdownBlock.parse(source)
            headings = blocks.filter { $0.headingLevel != nil }
            expandedHeadings = Set(headings.filter { $0.parentID == nil }.map(\.id))
        } catch {
            documentTitle = "无法读取文件：\(url.lastPathComponent)"
            selectedFile = nil
            source = ""
            savedSource = ""
            blocks = []; headings = []
        }
    }

    private func saveDocument() -> Bool {
        if isEPUBNotebook, let selectedFile {
            do {
                try documentStore.save(MarkdownDocument(url: selectedFile, source: source), to: selectedFile)
                savedSource = source
                return true
            } catch {
                saveError = error.localizedDescription
                return false
            }
        }
        if let epubDocument {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.init(filenameExtension: "epub")!]
            panel.nameFieldStringValue = "\(epubDocument.sourceURL.deletingPathExtension().lastPathComponent)-edited.epub"
            panel.directoryURL = epubDocument.sourceURL.deletingLastPathComponent()
            guard panel.runModal() == .OK, let destination = panel.url else { return false }
            do {
                try epubDocument.writeEPUBCopy(to: destination)
                epubHasChanges = false
                return true
            } catch {
                saveError = error.localizedDescription
                return false
            }
        }
        guard let selectedFile else { return false }
        do {
            try documentStore.save(MarkdownDocument(url: selectedFile, source: source), to: selectedFile)
            savedSource = source
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }

    private func continuePendingDocumentOperation() {
        let operation = pendingDocumentOperation
        pendingDocumentOperation = nil
        switch operation {
        case .open(let url): performOpen(url)
        case .openFolder(let url): openFolderContents(url)
        case .closeFile: clearCurrentDocument()
        case nil: break
        }
    }

    private func closeFile() {
        guard selectedFile != nil || epubDocument != nil else { return }
        if isDirty {
            pendingDocumentOperation = .closeFile
            showUnsavedAlert = true
        } else {
            clearCurrentDocument()
        }
    }

    private func clearCurrentDocument() {
        epubDocument = nil
        isEPUBNotebook = false
        epubHasChanges = false
        selectedFile = nil
        source = ""
        savedSource = ""
        blocks = []
        headings = []
        expandedHeadings = []
        scrollTarget = nil
        synchronizedSourceLine = 1
        sourceLineRequest += 1
        editorSelection = NSRange(location: 0, length: 0)
        documentTitle = markdownFiles.isEmpty ? "选择一个 Markdown 文件开始阅读" : "从文件夹中选择一个 Markdown 文件"
    }

    private func closeFolder() {
        guard folderURL != nil || !markdownFiles.isEmpty else { return }
        folderURL = nil
        markdownFiles = []
        showFolderContents = true
        lastFolderPath = ""
        if selectedFile == nil {
            documentTitle = "选择一个 Markdown 文件开始阅读"
        }
    }

    private func insertHorizontalRule() {
        guard selectedFile != nil, displayMode != .read else { return }
        let original = source as NSString
        let location = min(editorSelection.location, original.length)
        let length = min(editorSelection.length, original.length - location)
        let before = original.substring(to: location)
        let after = original.substring(from: location + length)
        let prefix = before.isEmpty || before.hasSuffix("\n\n") ? "" : before.hasSuffix("\n") ? "\n" : "\n\n"
        let suffix = after.isEmpty || after.hasPrefix("\n\n") ? "" : after.hasPrefix("\n") ? "\n" : "\n\n"
        let insertion = prefix + "---" + suffix
        source = original.replacingCharacters(in: NSRange(location: location, length: length), with: insertion)
        let caretOffset = location + (prefix as NSString).length + ("---" as NSString).length
        editorSelection = NSRange(location: caretOffset, length: 0)
        synchronizedSourceLine = (source as NSString).substring(to: caretOffset).components(separatedBy: "\n").count
        sourceLineRequest += 1
        editorFocusRequest += 1
    }

    private func applyHeadingLevel(_ level: Int) {
        guard (1...6).contains(level), selectedFile != nil, displayMode != .read else { return }
        let original = source as NSString
        let cursor = min(editorSelection.location, original.length)
        let lineRange = original.lineRange(for: NSRange(location: cursor, length: 0))
        let line = original.substring(with: lineRange) as NSString
        var contentLength = line.length
        while contentLength > 0 {
            let unit = line.character(at: contentLength - 1)
            if unit == 10 || unit == 13 { contentLength -= 1 } else { break }
        }
        let content = line.substring(to: contentLength) as NSString
        var prefixEnd = 0
        while prefixEnd < content.length {
            let unit = content.character(at: prefixEnd)
            guard unit == 32 || unit == 9 else { break }
            prefixEnd += 1
        }
        var textStart = prefixEnd
        while textStart < content.length, content.character(at: textStart) == 35 { textStart += 1 }
        if textStart > prefixEnd, textStart < content.length,
           content.character(at: textStart) == 32 || content.character(at: textStart) == 9 {
            while textStart < content.length, content.character(at: textStart) == 32 || content.character(at: textStart) == 9 {
                textStart += 1
            }
        } else {
            textStart = prefixEnd
        }
        let indent = content.substring(to: prefixEnd)
        let headingPrefix = String(repeating: "#", count: level) + " "
        let updatedLine = indent + headingPrefix + content.substring(from: textStart) + line.substring(from: contentLength)
        source = original.replacingCharacters(in: lineRange, with: updatedLine)
        editorSelection = NSRange(location: lineRange.location + (indent as NSString).length + (headingPrefix as NSString).length,
                                  length: 0)
    }

    private func applyInlineSyntax(_ opening: String, _ closing: String) {
        guard selectedFile != nil, displayMode != .read else { return }
        let original = source as NSString
        let location = min(editorSelection.location, original.length)
        let length = min(editorSelection.length, original.length - location)
        let openingLength = (opening as NSString).length
        let closingLength = (closing as NSString).length

        if length > 0, location >= openingLength, location + length + closingLength <= original.length {
            let before = original.substring(with: NSRange(location: location - openingLength, length: openingLength))
            let after = original.substring(with: NSRange(location: location + length, length: closingLength))
            if before == opening, after == closing {
                let wrappedRange = NSRange(location: location - openingLength, length: openingLength + length + closingLength)
                let selected = original.substring(with: NSRange(location: location, length: length))
                source = original.replacingCharacters(in: wrappedRange, with: selected)
                editorSelection = NSRange(location: location - openingLength, length: length)
                return
            }
        } else if length == 0, location >= openingLength, location + closingLength <= original.length {
            let before = original.substring(with: NSRange(location: location - openingLength, length: openingLength))
            let after = original.substring(with: NSRange(location: location, length: closingLength))
            if before == opening, after == closing {
                let wrappedRange = NSRange(location: location - openingLength, length: openingLength + closingLength)
                source = original.replacingCharacters(in: wrappedRange, with: "")
                editorSelection = NSRange(location: location - openingLength, length: 0)
                return
            }
        }

        let selected = original.substring(with: NSRange(location: location, length: length))
        let replacement = opening + selected + closing
        source = original.replacingCharacters(in: NSRange(location: location, length: length), with: replacement)
        editorSelection = NSRange(location: location + openingLength, length: (selected as NSString).length)
    }

    private func applyLinePrefix(_ prefix: String) {
        guard selectedFile != nil, displayMode != .read else { return }
        let original = source as NSString
        let selectionStart = min(editorSelection.location, original.length)
        let selectionEnd = min(selectionStart + editorSelection.length, original.length)
        let firstLine = original.lineRange(for: NSRange(location: selectionStart, length: 0))
        let lastProbe = selectionEnd > selectionStart ? selectionEnd - 1 : selectionStart
        let lastLine = original.lineRange(for: NSRange(location: lastProbe, length: 0))
        let range = NSRange(location: firstLine.location, length: NSMaxRange(lastLine) - firstLine.location)
        let selectedText = original.substring(with: range)
        let lines = selectedText.components(separatedBy: "\n")
        let prefixText = prefix.trimmingCharacters(in: .whitespaces)
        let alreadyPrefixed = lines.filter { !$0.isEmpty }.allSatisfy { line in
            line.trimmingCharacters(in: .whitespaces).hasPrefix(prefixText)
        }
        let updated = lines.enumerated().map { index, line -> String in
            guard !line.isEmpty else { return line }
            if alreadyPrefixed, let range = line.range(of: prefixText, options: [.anchored, .caseInsensitive]) {
                return String(line[..<range.lowerBound]) + String(line[range.upperBound...]).replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
            }
            let linePrefix = prefix == "1. " ? "\(index + 1). " : prefix
            return linePrefix + line
        }.joined(separator: "\n")
        source = original.replacingCharacters(in: range, with: updated)
        editorSelection = NSRange(location: range.location, length: (updated as NSString).length)
        editorFocusRequest += 1
    }

    private func wrapSelection(_ opening: String, _ closing: String) {
        guard selectedFile != nil, displayMode != .read else { return }
        let original = source as NSString
        let location = min(editorSelection.location, original.length)
        let length = min(editorSelection.length, original.length - location)
        let before = original.substring(to: location)
        let after = original.substring(from: location + length)
        let selected = original.substring(with: NSRange(location: location, length: length))
        let prefix = before.isEmpty || before.hasSuffix("\n\n") ? "" : before.hasSuffix("\n") ? "\n" : "\n\n"
        let suffix = after.isEmpty || after.hasPrefix("\n\n") ? "" : after.hasPrefix("\n") ? "\n" : "\n\n"
        let insertion = prefix + opening + selected + closing + suffix
        source = original.replacingCharacters(in: NSRange(location: location, length: length), with: insertion)
        let contentStart = location + (prefix as NSString).length + (opening as NSString).length
        editorSelection = NSRange(location: contentStart, length: (selected as NSString).length)
        editorFocusRequest += 1
    }

    private func clearLinePrefix() {
        guard selectedFile != nil, displayMode != .read else { return }
        let original = source as NSString
        let cursor = min(editorSelection.location, original.length)
        let range = original.lineRange(for: NSRange(location: cursor, length: 0))
        let line = original.substring(with: range)
        let cleaned = line.replacingOccurrences(of: #"^(\\s*)(?:#{1,6}\\s+|[-+*]\\s+|\\d+[.)]\\s+|>\\s?)"#, with: "$1", options: .regularExpression)
        source = original.replacingCharacters(in: range, with: cleaned)
        editorSelection = NSRange(location: range.location + (cleaned as NSString).length, length: 0)
        editorFocusRequest += 1
    }

    private func insertTemplate(_ template: String) {
        guard selectedFile != nil, displayMode != .read else { return }
        let original = source as NSString
        let location = min(editorSelection.location, original.length)
        let length = min(editorSelection.length, original.length - location)
        source = original.replacingCharacters(in: NSRange(location: location, length: length), with: template)
        editorSelection = NSRange(location: location + (template as NSString).length, length: 0)
        editorFocusRequest += 1
    }

    private func scheduleParse(for text: String) {
        parseTask?.cancel()
        parseTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            let parsed = await Task.detached(priority: .userInitiated) { MarkdownBlock.parse(text) }.value
            guard !Task.isCancelled, source == text else { return }
            blocks = parsed
            headings = parsed.filter { $0.headingLevel != nil }
            expandedHeadings.formIntersection(Set(headings.map(\.id)))
        }
    }
}

struct HeadingRow: View {
    let heading: MarkdownBlock
    let allHeadings: [MarkdownBlock]
    @Binding var expanded: Set<String>
    let styles: [HeadingStyle]
    let outlineColors: [String]
    let fontScale: Double
    let onSelect: (String) -> Void

    private var children: [MarkdownBlock] { allHeadings.filter { $0.parentID == heading.id } }
    private var levelIndex: Int { min(max((heading.headingLevel ?? 1) - 1, 0), 5) }
    private var tocFontSize: Double {
        let defaultSizes = [31.0, 24, 20, 17, 15, 14]
        let outlineSizes = [15.0, 13.8, 12.8, 12.1, 11.6, 11.2]
        let adjusted = outlineSizes[levelIndex] + (styles[levelIndex].size - defaultSizes[levelIndex]) * 0.18
        return min(22, max(9, adjusted * fontScale))
    }
    private var tocFont: Font {
        let family = styles[levelIndex].fontFamily
        let base = family == "系统默认" ? Font.system(size: tocFontSize) : Font.custom(family, size: tocFontSize)
        return base.weight(styles[levelIndex].bold ? .semibold : .regular)
    }

    private func toggleExpansion() {
        guard !children.isEmpty else { return }
        if expanded.contains(heading.id) {
            expanded.remove(heading.id)
        } else {
            expanded.insert(heading.id)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                if !children.isEmpty {
                    Button { toggleExpansion() } label: {
                        Image(systemName: expanded.contains(heading.id) ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold)).frame(width: 14, height: 20)
                    }.buttonStyle(.plain).foregroundStyle(.tertiary)
                } else { Spacer().frame(width: 14) }
                Button { onSelect(heading.id) } label: {
                    Text(heading.title ?? "").lineLimit(2).multilineTextAlignment(.leading)
                        .font(tocFont)
                        .lineSpacing(levelIndex < 2 ? 2 : 1)
                        .foregroundStyle(Color(hex: outlineColors[levelIndex]))
                        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture(count: 2).onEnded { toggleExpansion() })
            }.padding(.leading, CGFloat(levelIndex * 14)).frame(minHeight: levelIndex == 0 ? 27 : 24)
            if expanded.contains(heading.id) {
                ForEach(children) { child in
                    HeadingRow(heading: child, allHeadings: allHeadings, expanded: $expanded,
                               styles: styles, outlineColors: outlineColors, fontScale: fontScale, onSelect: onSelect)
                }
            }
        }.listRowBackground(Color.clear)
    }
}

struct HeadingStyle: Codable, Identifiable, Equatable {
    var id: Int
    var colorHex: String
    var size: Double
    var fontFamily: String
    var bold: Bool
    static let defaults = [
        HeadingStyle(id: 1, colorHex: "#0797C2", size: 31, fontFamily: "系统默认", bold: true),
        HeadingStyle(id: 2, colorHex: "#0797C2", size: 24, fontFamily: "系统默认", bold: true),
        HeadingStyle(id: 3, colorHex: "#0797C2", size: 20, fontFamily: "系统默认", bold: true),
        HeadingStyle(id: 4, colorHex: "#0797C2", size: 17, fontFamily: "系统默认", bold: true),
        HeadingStyle(id: 5, colorHex: "#0797C2", size: 15, fontFamily: "系统默认", bold: true),
        HeadingStyle(id: 6, colorHex: "#0797C2", size: 14, fontFamily: "系统默认", bold: true)
    ]
}

struct SettingsView: View {
    @Binding var readerWidth: Double
    @Binding var bodyColorHex: String
    @Binding var readerBackgroundHex: String
    @Binding var strongColorHex: String
    @Binding var strongSize: Double
    @Binding var strongFamily: String
    @Binding var headingStylesData: Data
    @Binding var bodySize: Double
    @Binding var bodyFamily: String
    @Binding var lineHeight: Double
    @Binding var paragraphSpacing: Double
    @Binding var outlineColorsData: Data
    @Binding var annotationFontSize: Double
    @Binding var annotationFontFamily: String
    @Binding var annotationTextColorHex: String
    @Environment(\.dismiss) private var dismiss
    @State private var styles: [HeadingStyle]
    @State private var outlineColors: [String]
    private let families = ["系统默认", "PingFang SC", "Songti SC", "Heiti SC", "SF Pro Text", "Avenir Next", "Georgia", "Menlo"]

    init(readerWidth: Binding<Double>, bodyColorHex: Binding<String>, readerBackgroundHex: Binding<String>, strongColorHex: Binding<String>, strongSize: Binding<Double>, strongFamily: Binding<String>, headingStylesData: Binding<Data>, bodySize: Binding<Double>, bodyFamily: Binding<String>, lineHeight: Binding<Double>, paragraphSpacing: Binding<Double>, outlineColorsData: Binding<Data>, annotationFontSize: Binding<Double>, annotationFontFamily: Binding<String>, annotationTextColorHex: Binding<String>) {
        _readerWidth = readerWidth; _strongColorHex = strongColorHex; _strongSize = strongSize
        _bodyColorHex = bodyColorHex
        _readerBackgroundHex = readerBackgroundHex
        _strongFamily = strongFamily; _headingStylesData = headingStylesData
        _bodySize = bodySize; _bodyFamily = bodyFamily; _lineHeight = lineHeight; _paragraphSpacing = paragraphSpacing
        _outlineColorsData = outlineColorsData
        _annotationFontSize = annotationFontSize
        _annotationFontFamily = annotationFontFamily
        _annotationTextColorHex = annotationTextColorHex
        _styles = State(initialValue: (try? JSONDecoder().decode([HeadingStyle].self, from: headingStylesData.wrappedValue)) ?? HeadingStyle.defaults)
        _outlineColors = State(initialValue: (try? JSONDecoder().decode([String].self, from: outlineColorsData.wrappedValue)) ?? Array(repeating: "#222222", count: 6))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("阅读样式").font(.system(size: 18, weight: .semibold)); Spacer(); Button("完成") { save(); dismiss() }.keyboardShortcut(.defaultAction) }
            Form {
                Section("正文") {
                    LabeledContent("阅读宽度", value: "\(Int(readerWidth)) px")
                    Slider(value: $readerWidth, in: 520...1040, step: 20)
                    HStack {
                        Text("阅读背景颜色"); Spacer()
                        ColorPicker("", selection: Binding(get: { Color(hex: readerBackgroundHex) }, set: { readerBackgroundHex = $0.hexString }), supportsOpacity: false).labelsHidden()
                        TextField("#FFFFFF", text: $readerBackgroundHex).frame(width: 90).textFieldStyle(.roundedBorder)
                    }
                    Picker("正文字体", selection: $bodyFamily) {
                        ForEach(families, id: \.self) { Text($0).font($0 == "系统默认" ? .system(size: 12) : .custom($0, size: 12)).tag($0) }
                    }
                    HStack {
                        Text("正文字体颜色"); Spacer()
                        ColorPicker("", selection: Binding(get: { Color(hex: bodyColorHex) }, set: { bodyColorHex = $0.hexString }), supportsOpacity: false).labelsHidden()
                        TextField("#282725", text: $bodyColorHex).frame(width: 90).textFieldStyle(.roundedBorder)
                    }
                    LabeledContent("正文大小", value: "\(Int(bodySize)) pt · ⌘+ / ⌘−")
                    Slider(value: $bodySize, in: 12...24, step: 1)
                    LabeledContent("行距", value: String(format: "%.2f", lineHeight))
                    Slider(value: $lineHeight, in: 1.4...2.2, step: 0.05)
                    LabeledContent("段落间距", value: "\(Int(paragraphSpacing)) pt")
                    Slider(value: $paragraphSpacing, in: 4...24, step: 1)
                    HStack {
                        Text("加粗文字颜色"); Spacer()
                        ColorPicker("", selection: Binding(get: { Color(hex: strongColorHex) }, set: { strongColorHex = $0.hexString }), supportsOpacity: false).labelsHidden()
                        TextField("#A5563A", text: $strongColorHex).frame(width: 90).textFieldStyle(.roundedBorder)
                    }
                    Picker("加粗文字字体", selection: $strongFamily) {
                        ForEach(families, id: \.self) { Text($0).font(.custom($0, size: 12)).tag($0) }
                    }
                    LabeledContent("加粗文字字号", value: "\(Int(strongSize)) pt")
                    Slider(value: $strongSize, in: 13...22, step: 1)
                }
                Section("EPUB 注释文字") {
                    HStack {
                        Text("注释文字颜色"); Spacer()
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: annotationTextColorHex) },
                            set: { annotationTextColorHex = $0.hexString }
                        ), supportsOpacity: false).labelsHidden()
                        TextField("#777777", text: $annotationTextColorHex).frame(width: 90).textFieldStyle(.roundedBorder)
                    }
                    Picker("注释字体", selection: $annotationFontFamily) {
                        ForEach(families, id: \.self) { Text($0).font($0 == "系统默认" ? .system(size: 12) : .custom($0, size: 12)).tag($0) }
                    }
                    LabeledContent("注释字号", value: "\(Int(annotationFontSize)) pt")
                    Slider(value: $annotationFontSize, in: 9...18, step: 1)
                }
                Section("标题样式") {
                    ForEach($styles) { $style in
                        HStack(spacing: 10) {
                            Text("H\(style.id)").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.secondary).frame(width: 25)
                            ColorPicker("", selection: Binding(get: { Color(hex: style.colorHex) }, set: { style.colorHex = $0.hexString }), supportsOpacity: false).labelsHidden()
                            Picker("字体", selection: $style.fontFamily) {
                                ForEach(families, id: \.self) { Text($0).font($0 == "系统默认" ? .system(size: 12) : .custom($0, size: 12)).tag($0) }
                            }.labelsHidden().frame(width: 130)
                            Slider(value: $style.size, in: 13...40, step: 1).frame(width: 95)
                            Text("\(Int(style.size))").font(.system(size: 10, design: .rounded).monospacedDigit()).foregroundStyle(.tertiary).frame(width: 22)
                            Toggle("粗体", isOn: $style.bold).labelsHidden().toggleStyle(.switch).scaleEffect(0.75)
                        }
                    }
                }
                Section("目录文字颜色") {
                    ForEach(0..<6, id: \.self) { index in
                        HStack {
                            Text("H\(index + 1)").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary).frame(width: 32, alignment: .leading)
                            Text("目录颜色").font(.system(size: 12))
                            Spacer()
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: outlineColors[index]) },
                                set: { outlineColors[index] = $0.hexString }
                            ), supportsOpacity: false).labelsHidden()
                            TextField("#222222", text: $outlineColors[index]).frame(width: 90).textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }.formStyle(.grouped)
            HStack {
                Spacer()
                Button("恢复所有默认设置") { restoreDefaults() }
            }
        }
        .padding(22)
        .frame(width: 640, height: 760)
        .onDisappear(perform: save)
    }
    private func restoreDefaults() {
        styles = HeadingStyle.defaults
        strongColorHex = "#A5563A"
        bodyColorHex = "#282725"
        readerBackgroundHex = "#FFFFFF"
        strongSize = 15
        strongFamily = "系统默认"
        annotationFontSize = 11
        annotationFontFamily = "系统默认"
        annotationTextColorHex = "#777777"
        bodySize = 15
        bodyFamily = "系统默认"
        lineHeight = 1.85
        paragraphSpacing = 13
        readerWidth = 720
        outlineColors = Array(repeating: "#222222", count: 6)
        save()
    }
    private func save() {
        headingStylesData = (try? JSONEncoder().encode(styles)) ?? Data()
        outlineColorsData = (try? JSONEncoder().encode(outlineColors)) ?? Data()
    }
}

private struct SidebarWidthResizeHandle: View {
    @Binding var width: Double
    @State private var widthAtDragStart: Double?
    @State private var isHovered = false

    var body: some View {
        ZStack {
            Rectangle().fill(Color.clear)
            Rectangle()
                .fill(isHovered ? Color.accentColor.opacity(0.75) : Color.primary.opacity(0.12))
                .frame(width: isHovered ? 2 : 1)
                .padding(.vertical, 4)
        }
        .frame(width: 8)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if widthAtDragStart == nil { widthAtDragStart = width }
                    let start = widthAtDragStart ?? width
                    width = min(480, max(190, start + Double(value.translation.width)))
                }
                .onEnded { _ in widthAtDragStart = nil }
        )
        .accessibilityLabel("拖动调整目录栏宽度")
        .help("拖动调整目录栏宽度")
    }
}

struct TableInsertionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cells = [["标题 1", "标题 2", "标题 3"], ["", "", ""]]
    @State private var formatted = true
    let onInsert: ([[String]], Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("插入 Markdown 表格").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button { addColumn() } label: { Image(systemName: "plus.square") }.help("添加列")
                Button { removeColumn() } label: { Image(systemName: "minus.square") }.help("删除末列").disabled(cells[0].count <= 1)
                Button { addRow() } label: { Image(systemName: "plus.rectangle") }.help("添加行")
                Button { removeRow() } label: { Image(systemName: "minus.rectangle") }.help("删除末行").disabled(cells.count <= 2)
            }
            Text("第一行作为表头。点击单元格输入内容，可添加或删除行列。").font(.system(size: 12)).foregroundStyle(.secondary)
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    ForEach(cells.indices, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(cells[row].indices, id: \.self) { column in
                                TextField(row == 0 ? "标题" : "", text: cellBinding(row, column))
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 13, weight: row == 0 ? .semibold : .regular))
                                    .padding(.horizontal, 8).frame(width: 132, height: 34)
                                    .background(row == 0 ? Color.primary.opacity(0.045) : Color.clear)
                                    .overlay(Rectangle().stroke(Color.primary.opacity(0.14), lineWidth: 0.5))
                            }
                        }
                    }
                }
            }
            .frame(minHeight: 78, maxHeight: 260)
            Toggle("格式化输出", isOn: $formatted).toggleStyle(.checkbox).font(.system(size: 12))
            HStack {
                Button("清空") { cells = Array(repeating: Array(repeating: "", count: cells[0].count), count: cells.count) }
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("确定") { onInsert(cells, formatted); dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(minWidth: 470, idealWidth: 470, minHeight: 230, idealHeight: 300)
    }

    private func cellBinding(_ row: Int, _ column: Int) -> Binding<String> {
        Binding(get: { cells[row][column] }, set: { cells[row][column] = $0 })
    }
    private func addRow() {
        guard cells.count < 20 else { return }
        cells.append(Array(repeating: "", count: cells[0].count))
    }
    private func removeRow() { if cells.count > 2 { cells.removeLast() } }
    private func addColumn() {
        guard cells[0].count < 12 else { return }
        for index in cells.indices { cells[index].append("") }
    }
    private func removeColumn() {
        guard cells[0].count > 1 else { return }
        for index in cells.indices { cells[index].removeLast() }
    }
}

extension Color {
    init(hex: String) {
        let normalized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: normalized).scanHexInt64(&value)
        let r, g, b: Double
        if normalized.count == 6, normalized.allSatisfy(\.isHexDigit) { r = Double((value >> 16) & 255) / 255; g = Double((value >> 8) & 255) / 255; b = Double(value & 255) / 255 }
        else { r = 0.647; g = 0.337; b = 0.227 }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.deviceRGB) ?? .black
        return String(format: "#%02X%02X%02X", Int(ns.redComponent * 255), Int(ns.greenComponent * 255), Int(ns.blueComponent * 255))
    }
}

private extension View {
    func toolbarHint(_ text: String) -> some View {
        modifier(ToolbarHoverHint(text: text))
    }
}

private struct ToolbarHoverHint: ViewModifier {
    let text: String
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { isHovering = $0 }
            .overlay(alignment: .bottom) {
                GeometryReader { geometry in
                    if isHovering {
                        let position = geometry.frame(in: .named("mainWindow")).midX
                        let windowWidth = NSApp.keyWindow?.contentView?.bounds.width ?? 1000
                        let bubbleWidth: CGFloat = 268
                        let horizontalOffset = position > windowWidth * 0.68 ? geometry.size.width - bubbleWidth : 0
                        Text(text)
                            .font(.system(size: 11))
                            .foregroundStyle(.primary)
                            .frame(width: 250, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12)))
                            .shadow(color: .black.opacity(0.14), radius: 5, y: 2)
                            .offset(x: horizontalOffset, y: geometry.size.height + 8)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
            }
            .zIndex(isHovering ? 100 : 0)
    }
}
