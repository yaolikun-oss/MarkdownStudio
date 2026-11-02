import EPUBCore
import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct MarkdownReaderApp: App {
    init() { WorkspacePreferenceUpgrade.importPreviousDefaultsIfNeeded() }
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
                    .keyboardShortcut("0", modifiers: [.command, .option])
            }
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("新建 Workspace…") { ReaderActions.newWorkspaceHandler?() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("打开文件…") { ReaderActions.openFile() }
                    .keyboardShortcut("o", modifiers: [.command])
                Button("临时打开文件…") { ReaderActions.openTemporaryFile() }
                    .keyboardShortcut("o", modifiers: [.command, .option])
                Button("打开文件夹…") { ReaderActions.openFolder() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("打开工作区…") { ReaderActions.openWorkspaceHandler?() }
                Button("保存工作区…") { ReaderActions.saveWorkspaceHandler?() }
                Divider()
                Button("关闭当前区域的文件") { ReaderActions.closeFile() }
                Button("关闭阅读源") { ReaderActions.closeReadingSource() }
                Button("关闭 Markdown 笔记") { ReaderActions.closeNote() }
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
                Button("切换阅读 / 编辑区域") { ReaderActions.toggleReadingEditingFocusHandler?() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("所见即所得") { ReaderActions.setDisplayMode(.read) }
                Button("编辑器") { ReaderActions.setDisplayMode(.edit) }
                Button("左右分栏") { ReaderActions.setDisplayMode(.split) }
                Divider()
                Button("切换所见即所得 / 源码") { ReaderActions.toggleEditPreview() }
                    .keyboardShortcut("r", modifiers: [.command])
            }
            CommandMenu("阅读工作区") {
                Button("只看原文") { ReaderActions.setEPUBNotebookLayout(.epub) }
                    .keyboardShortcut("1", modifiers: [.command, .control])
                Button("只看 Markdown 笔记") { ReaderActions.setEPUBNotebookLayout(.notes) }
                    .keyboardShortcut("2", modifiers: [.command, .control])
                Button("阅读 + 可视化笔记") { ReaderActions.setEPUBNotebookLayout(.stacked) }
                    .keyboardShortcut("3", modifiers: [.command, .control])
                Divider()
                Button("最大化原文面板") { ReaderActions.maximizeEPUBNotebookPane(.epub) }
                    .keyboardShortcut("1", modifiers: [.command, .shift])
                Button("可视化笔记占满右侧") { ReaderActions.maximizeEPUBNotebookPane(.rightPreview) }
                    .keyboardShortcut("2", modifiers: [.command, .option])
                Button("Markdown 源码占满右侧") { ReaderActions.maximizeEPUBNotebookPane(.rightEditor) }
                    .keyboardShortcut("3", modifiers: [.command, .option])
                Button("最大化可视化笔记面板") { ReaderActions.maximizeEPUBNotebookPane(.preview) }
                    .keyboardShortcut("2", modifiers: [.command, .shift])
                Button("最大化 Markdown 源码面板") { ReaderActions.maximizeEPUBNotebookPane(.editor) }
                    .keyboardShortcut("3", modifiers: [.command, .shift])
                Button("恢复三栏布局") { ReaderActions.restoreEPUBNotebookLayout() }
                    .keyboardShortcut("0", modifiers: [.command, .shift])
            }
            CommandMenu("网页") {
                Button("打开网页…") { ReaderActions.openWebPage() }
                    .keyboardShortcut("l", modifiers: [.command])
                Button("后退") { ReaderActions.webBack() }
                    .keyboardShortcut("[", modifiers: [.command])
                Button("前进") { ReaderActions.webForward() }
                    .keyboardShortcut("]", modifiers: [.command])
                Button("收藏当前网页…") { ReaderActions.bookmarkCurrentPage() }
                    .keyboardShortcut("b", modifiers: [.command, .option])
                Button("剪藏选中文字到 Markdown") { ReaderActions.clipWebSelection() }
                    .keyboardShortcut("c", modifiers: [.command, .control])
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
                    Button("插入图片文件…") { ReaderActions.insertImageFile() }
                        .keyboardShortcut("i", modifiers: [.command, .option])
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
                    .keyboardShortcut("p", modifiers: [.control, .option])
                Button("插入分隔线") { ReaderActions.insertHorizontalRule() }
                    .keyboardShortcut("s", modifiers: [.command, .option])
            }
            CommandGroup(replacing: .saveItem) {
                Button("保存") { ReaderActions.save() }
                    .keyboardShortcut("s", modifiers: [.command])
            }
            CommandGroup(replacing: .undoRedo) {
                Button("撤销") { ReaderActions.undoRedo(isRedo: false) }
                    .keyboardShortcut("z", modifiers: [.command])
                Button("重做") { ReaderActions.undoRedo(isRedo: true) }
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
    static var didRestoreWorkspace = false
    static var toggleReadingEditingFocusHandler: (() -> Void)?
    static var reopenWindowHandler: (() -> Void)?
    static var openFileHandler: (() -> Void)?
    static var openTemporaryFileHandler: (() -> Void)?
    static var openFolderHandler: (() -> Void)?
    static var newWorkspaceHandler: (() -> Void)?
    static var openWorkspaceHandler: (() -> Void)?
    static var saveWorkspaceHandler: (() -> Void)?
    static var openWebPageHandler: (() -> Void)?
    static var bookmarkCurrentPageHandler: (() -> Void)?
    static var clipWebSelectionHandler: (() -> Void)?
    static var webBackHandler: (() -> Void)?
    static var webForwardHandler: (() -> Void)?
    static var openDocumentHandler: ((URL) -> Void)?
    private(set) static var pendingOpenDocuments: [URL] = []
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
    static var insertImageFileHandler: (() -> Void)?
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
    static var closeReadingSourceHandler: (() -> Void)?
    static var closeNoteHandler: (() -> Void)?
    static var closeFolderHandler: (() -> Void)?
    static var terminationHandler: (() -> NSApplication.TerminateReply)?
    static var sidebarVisible = true
    static func undoRedo(isRedo: Bool) {
        if let editor = NSApp.keyWindow?.firstResponder as? MarkdownSourceTextView {
            if isRedo { editor.undoManager?.redo() } else { editor.undoManager?.undo() }
            return
        }
        if WorkspaceKeyboardFocus.containsFirstResponder(MarkdownVisualCommandHub.activeWebView) {
            _ = MarkdownVisualCommandHub.perform(isRedo ? "redo" : "undo")
            return
        }
        NSApp.sendAction(NSSelectorFromString(isRedo ? "redo:" : "undo:"), to: nil, from: nil)
    }
    static func reopenWindow() { reopenWindowHandler?() }
    static func openFile() { openFileHandler?() }
    static func openTemporaryFile() { openTemporaryFileHandler?() }
    static func openFolder() { openFolderHandler?() }
    static func openWebPage() { openWebPageHandler?() }
    static func bookmarkCurrentPage() { bookmarkCurrentPageHandler?() }
    static func clipWebSelection() { clipWebSelectionHandler?() }
    static func webBack() { webBackHandler?() }
    static func webForward() { webForwardHandler?() }
    static func openDocument(_ url: URL) {
        guard let openDocumentHandler else {
            pendingOpenDocuments.append(url)
            return
        }
        openDocumentHandler(url)
    }
    static func queueOpenDocumentForReopenedWindow(_ url: URL) {
        pendingOpenDocuments.append(url)
        reopenWindow()
    }
    static func setOpenDocumentHandler(_ handler: @escaping (URL) -> Void) {
        openDocumentHandler = handler
        let pending = pendingOpenDocuments
        pendingOpenDocuments.removeAll()
        pending.forEach(handler)
    }
    static func openSettings() { openSettingsHandler?() }
    static func insertImageFile() { insertImageFileHandler?() }
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
    static func closeReadingSource() { closeReadingSourceHandler?() }
    static func closeNote() { closeNoteHandler?() }
    static func closeFolder() { closeFolderHandler?() }
    static func requestTermination() -> NSApplication.TerminateReply {
        terminationHandler?() ?? .terminateNow
    }
}

private enum PendingDocumentOperation {
    case open(URL, importIntoWorkspace: Bool)
    case openWorkspace(URL)
    case openProjectFolder(URL)
    case createWorkspace
    case navigateNote(URL, Int)
    case openRecentWorkspace(RecentWorkspace)
    case createNote(URL)
    case openEPUBNote(URL, URL?)
    case closeNote
    case closeWorkspaceTab(UUID)
    case closeReadingSource
    case closeWindow
    case terminate
}

enum ReaderDisplayMode: String, CaseIterable {
    case read, edit, split
    var title: String {
        switch self { case .read: "可视化"; case .edit: "源码"; case .split: "分栏" }
    }
}

enum EPUBNotebookLayout: String, CaseIterable {
    case epub, notes, stacked
    var title: String {
        switch self { case .epub: "原书"; case .notes: "笔记"; case .stacked: "阅读 + 笔记" }
    }
}

enum EPUBNotebookPane: String {
    case epub, preview, editor, rightPreview, rightEditor

    var title: String {
        switch self {
        case .epub: "EPUB 原书"
        case .preview: "Markdown 笔记 · 可视化编辑"
        case .editor: "Markdown 笔记 · 源码"
        case .rightPreview: "笔记预览占满右侧"
        case .rightEditor: "笔记编辑占满右侧"
        }
    }
}

private enum PDFNotesLayout: String, CaseIterable {
    case visual, source

    var title: String {
        switch self {
        case .visual: "可视化笔记"
        case .source: "Markdown 源码"
        }
    }
}

private enum FocusedWorkspaceArea {
    case pdf, epub, web, office, markdownPreview, markdownEditor, markdownReader, outline
}

private enum WorkspaceStyleScope: CaseIterable {
    case reading, preview, source

    var title: String {
        switch self {
        case .reading: "阅读样式"
        case .preview: "MD 预览样式"
        case .source: "MD 源码样式"
        }
    }

    var shortTitle: String {
        switch self {
        case .reading: "阅读"
        case .preview: "MD 可视化"
        case .source: "MD 源码"
        }
    }

    var symbol: String {
        switch self {
        case .reading: "book"
        case .preview: "text.cursor"
        case .source: "chevron.left.forwardslash.chevron.right"
        }
    }
}

private enum SidebarOutlineTab: String, CaseIterable {
    case files, reading, markdown, webBookmarks

    var title: String {
        switch self {
        case .files: "文件"
        case .reading: "阅读"
        case .markdown: "Markdown"
        case .webBookmarks: "网页收藏"
        }
    }
    var symbol: String {
        switch self {
        case .files: "folder"
        case .reading: "book"
        case .markdown: "list.bullet.indent"
        case .webBookmarks: "bookmark"
        }
    }
}

private enum ReaderSheetRoute: Identifiable {
    case settings, tableInsertion, webAddress, webBookmark(WebBookmark), epubAnnotationComposer, epubAnnotationList

    var id: String {
        switch self {
        case .settings: "settings"
        case .tableInsertion: "tableInsertion"
        case .webAddress: "webAddress"
        case .webBookmark(let bookmark): "webBookmark-\(bookmark.id)"
        case .epubAnnotationComposer: "epubAnnotationComposer"
        case .epubAnnotationList: "epubAnnotationList"
        }
    }
}

enum FontSizeTarget {
    case body
    case outline
    case pdf, web, office
}

@MainActor
final class ReaderAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        ReaderActions.requestTermination()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { ReaderActions.reopenWindow() }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        if !application.windows.contains(where: { $0.isVisible }) {
            ReaderActions.queueOpenDocumentForReopenedWindow(url)
            return
        }
        ReaderActions.openDocument(url)
    }
}

private final class EditorSelectionStorage {
    var range = NSRange(location: 0, length: 0)
}

struct ReaderView: View {
    @Environment(\.openWindow) private var openWindow
    private let documentStore = LocalMarkdownDocumentStore()
    private let projectStore = WorkspaceProjectStore.makeDefault()
    @AppStorage("reader.width") private var readerWidth = 720.0
    @AppStorage("epub.readerWidth") private var epubReaderWidth = 720.0
    @AppStorage("reader.sidebarWidth") private var sidebarWidth = 270.0
    @AppStorage("reader.bodySize") private var bodySize = 15.0
    @AppStorage("reader.outlineFontScale") private var outlineFontScale = 1.0
    @AppStorage("markdown.sourceSyntaxHighlighting") private var sourceSyntaxHighlighting = true
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
    @AppStorage("markdown.previewStyle.v1") private var previewStyleData = Data()
    @AppStorage("markdown.previewTypographyDefaultsV2") private var previewTypographyDefaultsApplied = false
    @AppStorage("markdown.sourceStyle.v1") private var sourceStyleData = Data()
    @AppStorage("reader.systemFontMigrationV1") private var systemFontMigrationDone = false
    @AppStorage("reader.lastFolder") private var lastFolderPath = ""
    @AppStorage("reader.recentWorkspaces.v1") private var recentWorkspacesData = Data()
    @AppStorage("pdf.zoomPercent") private var pdfZoomPercent = 100.0
    @AppStorage("office.zoomPercent") private var officeZoomPercent = 100.0
    @State private var officeZoomInput = "100"
    @AppStorage("web.zoomPercent") private var webZoomPercent = 100.0
    @AppStorage("pdf.notesPaneWidth") private var notebookRightPaneWidth = 720.0
    @AppStorage("markdown.previewPaneWidth") private var markdownPreviewPaneWidth = 720.0
    @AppStorage("pdf.notesVerticalRatio") private var notebookVerticalRatio = 0.5

    @State private var readingLibrary = ReadingLibraryStore.makeDefault()
    @StateObject private var webSessions = WebBrowserSessions()
    @StateObject private var documentSessions = WorkspaceDocumentSessions()
    @StateObject private var detachedWindows = WorkspaceDetachedWindowManager.shared
    private var webBrowser: WebBrowserSession { webSessions.activeSession }
    @State private var workspaceTabs = WorkspaceGridLayout()
    @State private var workspaceNoteIdentity: URL?
    @State private var activeWorkspaceMarkdownURL: URL?
    @State private var workspaceReadingIdentity: URL?
    @State private var workspaceEPUBDocuments: [String: EPUBPackageDocument] = [:]
    @State private var workspaceEPUBChapters: [String: Int] = [:]
    @State private var workspaceEPUBNavigationTargets: [String: WorkspaceEPUBNavigationTarget] = [:]
    @State private var pendingWorkspaceFileDrop: (url: URL, group: UUID, edge: WorkspaceDropEdge)?
    @AppStorage("workspace.grid.layout.v1") private var workspaceGridData = Data()
    @AppStorage("workspace.current.file") private var currentWorkspacePath = ""
    @State private var workspaceRestorationComplete = false
    @State private var webBookmarks: [WebBookmark] = []
    @State private var webBookmarkReloadGeneration = 0
    @State private var webBookmarkReloadInFlight = false
    @State private var activeSheet: ReaderSheetRoute?
    @State private var settingsScope: WorkspaceStyleScope = .reading
    @State private var currentBookID: String?
    @State private var currentBookProfile: BookReadingProfile?
    @State private var savedEPUBPosition: SavedReadingPosition?
    @State private var epubPositionRestoreRequest = 0
    @State private var identityLoadTask: Task<Void, Never>?

    @State private var folderURL: URL?
    @State private var workspaceFolders: [URL] = []
    @State private var workspaceFiles: [URL] = []
    @State private var workspaceReadingNotes: [WorkspaceReadingNoteLink] = []
    @State private var pendingWorkspaceFileDeletion: URL?
    @State private var showWorkspaceFileDeletionConfirmation = false
    @State private var workspaceFileTreeRevision = 0
    @State private var workspaceFileURL: URL?
    @State private var workspaceHasMissingReferences = false
    @State private var markdownFiles: [URL] = []
    @State private var selectedFile: URL?
    @State private var noteHistory: [URL] = []
    @State private var noteHistoryIndex = -1
    @State private var requestedHistoryIndex: Int?
    @State private var notePositions: [String: (NSRange, MarkdownViewportAnchor?)] = [:]
    @State private var noteTreeRevision = 0
    @State private var source = ""
    // The caret moves far more often than the document changes. Keep its range
    // outside SwiftUI's invalidation path so an arrow key or IME selection
    // update does not rebuild the whole reader workspace.
    @State private var editorSelectionStorage = EditorSelectionStorage()
    private var editorSelection: NSRange {
        get { editorSelectionStorage.range }
        nonmutating set { editorSelectionStorage.range = newValue }
    }
    @State private var savedSource = ""
    @State private var documentTitle = "选择一个 Markdown 文件开始阅读"
    @State private var headings: [MarkdownBlock] = []
    @State private var blocks: [MarkdownBlock] = []
    @State private var parsedSource = ""
    @State private var expandedHeadings: Set<String> = []
    @State private var showSidebar = true
    @State private var fontSizeTarget: FontSizeTarget = .body
    @State private var focusedWorkspaceArea: FocusedWorkspaceArea = .markdownReader
    @State private var lastReadingFocus: FocusedWorkspaceArea = .pdf
    @State private var lastContentFocus: FocusedWorkspaceArea = .markdownReader
    @State private var sidebarOutlineTab: SidebarOutlineTab = .markdown
    @State private var showFolderContents = true
    @State private var showRecentWorkspaces = false
    @State private var scrollTarget: String?
    @State private var scrollRequest = 0
    @State private var synchronizedSourceLine = 1
    @State private var sourceLineRequest = 0
    @State private var visualSourceLineRequest = 0
    @State private var visualScrollState = MarkdownVisualScrollState()
    @State private var visualRestoreRequest = 0
    @State private var sourcePositionRestoreRequest = 0
    @State private var editorFocusRequest = 0
    @State private var readerWidthInput = "720"
    @State private var previewWidthInput = "720"
    @State private var sourceWidthInput = "720"
    @State private var epubReaderWidthInput = "720"
    @State private var pdfZoomInput = "100"
    @State private var pdfDisplayPresetRequest = PDFDisplayPresetRequest(sequence: 0, preset: .fitWidth)
    @State private var webZoomInput = "100"
    @State private var pdfPageInput = "1"
    @State private var focusEditorAfterTableInsert = false
    @State private var pendingTableSessionURL: URL?
    @State private var displayMode: ReaderDisplayMode = .read
    @State private var parseTask: Task<Void, Never>?
    @State private var pendingDocumentOperation: PendingDocumentOperation?
    @State private var pendingRecentWorkspace: RecentWorkspace?
    @State private var suppressRecentRecording = false
    @State private var pendingWindowToClose: NSWindow?
    @State private var showUnsavedAlert = false
    @State private var saveError: String?
    @State private var epubDocument: EPUBPackageDocument?
    @State private var pdfDocument: PDFDocument?
    @State private var pdfSourceURL: URL?
    @State private var pdfCurrentPage = 0
    @State private var pdfNavigationRequest = 0
    @State private var pdfReadingPosition: PDFReadingPosition?
    @State private var pdfProfileLoading = false
    @State private var readingProfileLoadRevision = 0
    @State private var pendingPDFURL: URL?
    @State private var pdfPassword = ""
    @State private var showPDFPasswordPrompt = false
    @State private var epubCurrentChapter = 0
    @State private var epubHasChanges = false
    @State private var epubTargetFragment: String?
    @State private var epubNavigationRequest = 0
    @State private var epubAnnotations: [EPUBAnnotation] = []
    @State private var epubSelection: EPUBTextAnchor?
    @State private var epubEditingAnnotation: EPUBAnnotation?
    @State private var epubAnnotationJumpID: String?
    @State private var epubAnnotationJumpRequest = 0
    @State private var pendingEPUBURL: URL?
    @State private var pendingConvertedEPUBURL: URL?
    @State private var showEPUBModeChoice = false
    @State private var showCalibreInstallAlert = false
    @State private var isConvertingKindle = false
    @State private var kindleConversionRevision = 0
    @State private var kindleConversionTask: Task<URL, Error>?
    @State private var isImportingReadingResource = false
    @State private var readingImportTask: Task<Void, Never>?
    @State private var isEPUBNotebook = false
    @State private var epubNotebookLayout: EPUBNotebookLayout = .stacked
    @State private var officeDocumentURL: URL?
    @State private var officePreviewState = OfficePreviewState()
    @AppStorage("workspace.switchDisplay") private var usesSwitchDisplay = false
    @State private var showsNotesTab = false

    private var hasReadingSource: Bool {
        officeDocumentURL != nil || pdfDocument != nil || epubDocument != nil ||
        webSessions.tabIDs.contains { webSessions.session(for: $0)?.currentURL != nil }
    }
    private var hasBookSource: Bool { officeDocumentURL != nil || pdfDocument != nil || epubDocument != nil }
    private var hasOpenWorkspace: Bool {
        hasReadingSource || selectedFile != nil || !workspaceTabs.allTabs.isEmpty || !detachedWindows.allTabs.isEmpty
    }
    private var hasNotebookReadingSource: Bool {
        hasReadingSource && selectedFile != nil
    }
    private var activeReadingURL: URL? { officeDocumentURL ?? activeBookURL }
    private var activeWorkspaceReadingURL: URL? {
        guard let groupID = workspaceTabs.activeGroup,
              let group = workspaceTabs.groups.first(where: { $0.id == groupID }),
              let selected = group.selected,
              let tab = group.tabs.first(where: { $0.id == selected && $0.kind == .reading }) else { return nil }
        return tab.location?.standardizedFileURL
    }

    private var activeWorkspaceTab: WorkspaceTab? {
        guard let groupID = workspaceTabs.activeGroup,
              let group = workspaceTabs.groups.first(where: { $0.id == groupID }),
              let selected = group.selected else { return nil }
        return group.tabs.first(where: { $0.id == selected })
    }

    private func readingArea(for url: URL) -> FocusedWorkspaceArea {
        if url.pathExtension.lowercased() == "pdf" { return .pdf }
        if OfficeReadingFormat.supports(url) { return .office }
        return .epub
    }

    private func workspaceTab(_ tab: WorkspaceTab, matches area: FocusedWorkspaceArea) -> Bool {
        switch area {
        case .web:
            return tab.kind == .web
        case .pdf, .epub, .office:
            guard tab.kind == .reading, let url = tab.location else { return false }
            return readingArea(for: url) == area
        case .markdownEditor:
            return tab.kind == .source
        case .markdownPreview, .markdownReader:
            return tab.kind == .visual
        case .outline:
            return false
        }
    }

    private func workspaceTab(matching area: FocusedWorkspaceArea) -> WorkspaceTab? {
        if let activeWorkspaceTab, workspaceTab(activeWorkspaceTab, matches: area) {
            return activeWorkspaceTab
        }
        // In a split layout, prefer another visible selected tab before an
        // inactive tab hidden behind a tab strip.
        for group in workspaceTabs.groups {
            guard let selected = group.selected,
                  let tab = group.tabs.first(where: { $0.id == selected }) else { continue }
            if workspaceTab(tab, matches: area) { return tab }
        }
        return workspaceTabs.allTabs.first(where: { workspaceTab($0, matches: area) })
    }
    private var activeWorkspaceEPUBContext: (url: URL, document: EPUBPackageDocument, chapter: Int)? {
        guard let url = activeWorkspaceReadingURL else { return nil }
        let key = url.path
        guard let document = workspaceEPUBDocuments[key] else { return nil }
        return (url, document, workspaceEPUBChapters[key] ?? 0)
    }
    private func navigateWorkspaceEPUB(
        _ context: (url: URL, document: EPUBPackageDocument, chapter: Int), offset: Int
    ) {
        let next = context.chapter + offset
        guard context.document.chapters.indices.contains(next) else { return }
        let key = context.url.path
        workspaceEPUBChapters[key] = next
        let revision = (workspaceEPUBNavigationTargets[key]?.revision ?? 0) + 1
        workspaceEPUBNavigationTargets[key] = WorkspaceEPUBNavigationTarget(
            chapterIndex: next, fragment: nil, revision: revision)
    }
    @State private var maximizedNotebookPane: EPUBNotebookPane?
    @State private var splitHeightSaveTask: Task<Void, Never>?

    private var pdfZoomControlIsActive: Bool {
        pdfDocument != nil && focusedWorkspaceArea == .pdf
    }

    private var webZoomControlIsActive: Bool {
        webBrowser.currentURL != nil && focusedWorkspaceArea == .web
    }

    private var officeZoomControlIsActive: Bool { officeDocumentURL != nil && focusedWorkspaceArea == .office }
    private var documentZoomControlIsActive: Bool { pdfZoomControlIsActive || webZoomControlIsActive || officeZoomControlIsActive }

    private var pdfZoomSliderBinding: Binding<Double> {
        Binding(
            get: { log(min(1000, max(25, pdfZoomPercent))) },
            set: { pdfZoomPercent = min(1000, max(25, (exp($0) / 5).rounded() * 5)) }
        )
    }

    private var visibleSidebarTabs: [SidebarOutlineTab] { SidebarOutlineTab.allCases }

    private var epubWidthControlIsActive: Bool {
        focusedWorkspaceArea == .epub && (epubDocument != nil || isEPUBNotebook)
    }

    private var readingMarkdownStyle: MarkdownDisplayStyle {
        MarkdownDisplayStyle(readerWidth: readerWidth, outlineFontScale: outlineFontScale,
                             bodySize: bodySize, bodyFamily: bodyFamily,
                             bodyColorHex: bodyColorHex, backgroundHex: readerBackgroundHex,
                             lineHeight: lineHeight, paragraphSpacing: paragraphSpacing,
                             strongColorHex: strongColorHex, strongSize: strongSize,
                             strongFamily: strongFamily, headingStylesData: headingStylesData,
                             outlineColorsData: outlineColorsData)
    }

    private var initialSourceStyle: MarkdownDisplayStyle {
        var result = readingMarkdownStyle
        result.bodyFamily = "系统默认"
        result.backgroundHex = "#FFFFFF"
        result.lineHeight = Double(MarkdownSourceTypography.lineHeightMultiple)
        result.paragraphSpacing = Double(MarkdownSourceTypography.paragraphSpacing)
        return result
    }

    private var previewStyle: MarkdownDisplayStyle {
        (try? JSONDecoder().decode(MarkdownDisplayStyle.self, from: previewStyleData)) ?? readingMarkdownStyle
    }

    private var sourceStyle: MarkdownDisplayStyle {
        (try? JSONDecoder().decode(MarkdownDisplayStyle.self, from: sourceStyleData)) ?? initialSourceStyle
    }

    private func style(for scope: WorkspaceStyleScope) -> MarkdownDisplayStyle {
        switch scope {
        case .reading: readingMarkdownStyle
        case .preview: previewStyle
        case .source: sourceStyle
        }
    }

    private func styleBinding<Value>(for scope: WorkspaceStyleScope,
                                     keyPath: WritableKeyPath<MarkdownDisplayStyle, Value>,
                                     reading: Binding<Value>) -> Binding<Value> {
        guard scope != .reading else { return reading }
        return Binding(get: { style(for: scope)[keyPath: keyPath] }, set: { value in
            var updated = style(for: scope)
            updated[keyPath: keyPath] = value
            guard let data = try? JSONEncoder().encode(updated) else { return }
            if scope == .preview { previewStyleData = data } else { sourceStyleData = data }
        })
    }

    private var activeStyleScope: WorkspaceStyleScope {
        switch focusedWorkspaceArea == .outline ? lastContentFocus : focusedWorkspaceArea {
        case .markdownEditor: .source
        case .markdownPreview, .markdownReader: .preview
        case .pdf, .epub, .web, .office: .reading
        case .outline:
            selectedFile == nil ? .reading : (displayMode == .edit ? .source : .preview)
        }
    }

    private var toolbarTargetsReading: Bool {
        switch focusedWorkspaceArea == .outline ? lastContentFocus : focusedWorkspaceArea {
        case .pdf, .epub, .web, .office:
            true
        case .markdownPreview, .markdownEditor, .markdownReader:
            false
        case .outline:
            switch sidebarOutlineTab {
            case .reading, .webBookmarks: true
            case .markdown: false
            case .files: hasReadingSource && selectedFile == nil
            }
        }
    }

    private var toolbarCloseTitle: String? {
        if toolbarTargetsReading, hasReadingSource {
            let target = focusedWorkspaceArea == .outline ? lastContentFocus : focusedWorkspaceArea
            return target == .web ? "关闭网页" : "关闭原文"
        }
        if !toolbarTargetsReading, selectedFile != nil { return "关闭笔记" }
        return nil
    }

    private func closeToolbarDocument() {
        if toolbarTargetsReading { closeReadingSource() }
        else { closeNote() }
    }

    private var activeBodySizeBinding: Binding<Double> {
        styleBinding(for: activeStyleScope, keyPath: \.bodySize, reading: $bodySize)
    }

    private var markdownOutlineScaleBinding: Binding<Double> {
        styleBinding(for: .preview, keyPath: \.outlineFontScale, reading: $outlineFontScale)
    }

    private var activeContentWidthBinding: Binding<Double> {
        epubWidthControlIsActive ? $epubReaderWidth :
            styleBinding(for: activeStyleScope, keyPath: \.readerWidth, reading: $readerWidth)
    }

    private var activeContentWidthInput: Binding<String> {
        Binding(get: {
            if epubWidthControlIsActive { return epubReaderWidthInput }
            switch activeStyleScope {
            case .reading: return readerWidthInput
            case .preview: return previewWidthInput
            case .source: return sourceWidthInput
            }
        }, set: { value in
            if epubWidthControlIsActive { epubReaderWidthInput = value; return }
            switch activeStyleScope {
            case .reading: readerWidthInput = value
            case .preview: previewWidthInput = value
            case .source: sourceWidthInput = value
            }
        })
    }

    private var activeContentWidth: Double { activeContentWidthBinding.wrappedValue }

    private var pdfNotesLayout: PDFNotesLayout {
        switch maximizedNotebookPane {
        case .rightEditor: .source
        default: .visual
        }
    }

    private var headingStyles: [HeadingStyle] {
        (try? JSONDecoder().decode([HeadingStyle].self, from: headingStylesData)) ?? HeadingStyle.defaults
    }

    private var readingStyleSettings: ReadingStyleSettings {
        var value = ReadingStyleSettings()
        value.readerWidth = readerWidth
        value.epubReaderWidth = epubReaderWidth
        value.bodySize = bodySize
        value.outlineFontScale = outlineFontScale
        value.bodyFamily = bodyFamily
        value.bodyColorHex = bodyColorHex
        value.readerBackgroundHex = readerBackgroundHex
        value.lineHeight = lineHeight
        value.paragraphSpacing = paragraphSpacing
        value.strongColorHex = strongColorHex
        value.strongSize = strongSize
        value.strongFamily = strongFamily
        value.annotationFontSize = annotationFontSize
        value.annotationFontFamily = annotationFontFamily
        value.annotationTextColorHex = annotationTextColorHex
        value.headingStylesJSON = String(data: headingStylesData, encoding: .utf8) ?? ""
        value.outlineColorsJSON = String(data: outlineColorsData, encoding: .utf8) ?? ""
        value.pdfZoomPercent = pdfZoomPercent
        return value
    }
    private var outlineColors: [String] {
        guard let saved = try? JSONDecoder().decode([String].self, from: outlineColorsData), saved.count == 6 else {
            return Array(repeating: "#222222", count: 6)
        }
        return saved
    }

    var body: some View {
        HStack(spacing: 0) {
        navigationRail
        WorkspaceSidebarSplitView(sidebar: AnyView(sidebar), content: AnyView(
            VStack(spacing: 0) {
                toolbar
                Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
                documentPane
            }), sidebarWidth: CGFloat(sidebarWidth), showsSidebar: showSidebar,
            onSidebarWidthChange: { sidebarWidth = Double($0) })
        }
        .background(WindowCloseGuard(onCloseRequest: requestWindowClose))
        .background {
            EPUBArrowKeyMonitor(isEnabled: epubDocument != nil && focusedWorkspaceArea == .epub
                                && (isEPUBNotebook || displayMode == .read)) { offset in
                navigateEPUBChapter(by: offset)
            }
            .frame(width: 0, height: 0)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: displayMode) { _, mode in
            guard selectedFile != nil,
                  (officeDocumentURL == nil && pdfDocument == nil && epubDocument == nil && webBrowser.currentURL == nil
                   || epubNotebookLayout == .notes) else { return }
            activateWorkspaceArea(mode == .edit ? .markdownEditor : .markdownReader)
        }
        .overlay {
            if isConvertingKindle || isImportingReadingResource {
                ProgressView(isConvertingKindle ? "正在转换电子书为 EPUB…" : "正在复制并校验阅读资料…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .coordinateSpace(name: "mainWindow")
        .preferredColorScheme(.light)
        .sheet(item: $activeSheet, onDismiss: {
            if focusEditorAfterTableInsert {
                editorFocusRequest += 1
                focusEditorAfterTableInsert = false
            }
        }) {
            switch $0 {
            case .settings:
                overallSettingsView
            case .tableInsertion:
                TableInsertionSheet { cells, formatted in insertTable(cells: cells, formatted: formatted) }
            case .webAddress:
                WebAddressSheet(initialAddress: webBrowser.currentURL?.absoluteString ?? "") { url in open(url) }
            case .webBookmark(let bookmark):
                WebBookmarkEditorSheet(bookmark: bookmark, onSave: saveWebBookmark)
            case .epubAnnotationComposer:
                if let anchor = epubEditingAnnotation?.anchor ?? epubSelection {
                    EPUBAnnotationComposer(anchor: anchor, existing: epubEditingAnnotation) { note, colorHex, markStyle in
                        saveEPUBAnnotation(note: note, colorHex: colorHex, markStyle: markStyle)
                    }
                } else {
                    EmptyView()
                }
            case .epubAnnotationList:
                EPUBAnnotationListSheet(annotations: epubAnnotations, onSelect: jumpToEPUBAnnotation,
                                        onEdit: { annotation in
                                            epubEditingAnnotation = annotation
                                            activeSheet = nil
                                            DispatchQueue.main.async { activeSheet = .epubAnnotationComposer }
                                        },
                                        onDelete: deleteEPUBAnnotation)
            }
        }
        .alert("文档有未保存的修改", isPresented: $showUnsavedAlert) {
            Button("保存") {
                if savePendingDocumentOperation() {
                    continuePendingDocumentOperation()
                } else {
                    cancelPendingTermination()
                }
            }
            Button("不保存", role: .destructive) { continuePendingDocumentOperation(discardingChanges: true) }
            Button("取消", role: .cancel) { cancelPendingTermination() }
        } message: {
            Text("继续此操作前，要先保存当前修改吗？")
        }
        .alert("操作失败", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("好", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }
        .alert("将文件移到废纸篓？", isPresented: $showWorkspaceFileDeletionConfirmation) {
            Button("移到废纸篓", role: .destructive) {
                if let url = pendingWorkspaceFileDeletion { deleteWorkspaceFile(url) }
                pendingWorkspaceFileDeletion = nil
            }
            Button("取消", role: .cancel) { pendingWorkspaceFileDeletion = nil }
        } message: {
            Text(workspaceFileDeletionMessage)
        }
        .alert("需要安装 calibre", isPresented: $showCalibreInstallAlert) {
            Button("下载 calibre") {
                NSWorkspace.shared.open(URL(string: "https://calibre-ebook.com/download_osx")!)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("MOBI、AZW 和 AZW3 需先转换为 EPUB。安装 calibre 后重新打开文件；原书不会被修改。")
        }
        .confirmationDialog("打开电子书的方式", isPresented: $showEPUBModeChoice, titleVisibility: .visible) {
            Button("阅读原文") { openEPUBOriginal(editable: false) }
            Button("编辑并另存 EPUB") { openEPUBOriginal(editable: true) }
            Button("写配套 Markdown 笔记") { openEPUBCompanionNote() }
            Button("取消", role: .cancel) { pendingEPUBURL = nil; pendingConvertedEPUBURL = nil }
        } message: {
            Text(pendingConvertedEPUBURL == nil
                 ? "原文编辑会另存为新的 EPUB；工程内的配套笔记保存在“笔记/书籍笔记”。"
                 : "已转换为 EPUB 并检查章节，原书未修改。编辑后只能另存 EPUB；工程内的配套笔记保存在“笔记/书籍笔记”。")
        }
        .alert("PDF 需要密码", isPresented: $showPDFPasswordPrompt) {
            SecureField("输入密码", text: $pdfPassword)
            Button("取消", role: .cancel) { pendingPDFURL = nil; pendingRecentWorkspace = nil; pdfPassword = "" }
            Button("解锁") { unlockPendingPDF() }
        } message: {
            Text("此 PDF 受密码保护。")
        }
        .onAppear { handleReaderAppear(openWindow: openWindow) }
        .onDisappear {
            kindleConversionTask?.cancel()
            readingImportTask?.cancel()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled else { break }
                reloadWebBookmarks()
            }
        }
        .onChange(of: source) { _, newSource in
            if let url = activeWorkspaceMarkdownURL,
               let session = documentSessions.session(for: url), session.text != newSource {
                session.text = newSource
                session.selection = editorSelection
            }
            scheduleParse(for: newSource)
        }
        .onChange(of: workspaceTabs) { _, _ in persistWorkspaceGrid() }
        .onChange(of: workspaceResourcesKey) { _, _ in persistWorkspaceGrid() }
        .onChange(of: workspaceFolders) { _, _ in persistWorkspaceGrid() }
        .onChange(of: workspaceFiles) { _, _ in persistWorkspaceGrid() }
        .onChange(of: workspaceReadingNotes) { _, _ in persistWorkspaceGrid() }
        .onChange(of: readerWidth) { _, value in readerWidthInput = "\(Int(value))" }
        .onChange(of: previewStyleData) { _, _ in previewWidthInput = "\(Int(previewStyle.readerWidth))" }
        .onChange(of: sourceStyleData) { _, _ in sourceWidthInput = "\(Int(sourceStyle.readerWidth))" }
        .onChange(of: epubReaderWidth) { _, value in epubReaderWidthInput = "\(Int(value))" }
        .onChange(of: pdfZoomPercent) { _, value in pdfZoomInput = "\(Int(value))" }
        .onChange(of: officeZoomPercent) { _, value in officeZoomInput = "\(Int(value))" }
        .onChange(of: webZoomPercent) { _, value in webZoomInput = "\(Int(value))" }
        .onChange(of: pdfCurrentPage) { _, value in pdfPageInput = "\(value + 1)" }
        .onChange(of: readingStyleSettings) { _, style in persistReadingProfile(style: style) }
        .onChange(of: pdfReadingPosition) { _, position in
            guard let position, !pdfProfileLoading else { return }
            let saved = SavedReadingPosition(location: .pdf(pageIndex: position.pageIndex,
                                                            x: Double(position.x), y: Double(position.y)))
            persistReadingProfile(position: saved)
        }
        .onChange(of: savedEPUBPosition) { _, position in
            if let position { persistReadingProfile(position: position) }
        }
        .onChange(of: epubNotebookLayout) { _, layout in
            if layout != .stacked { maximizedNotebookPane = nil }
            if usesSwitchDisplay {
                if layout == .stacked { usesSwitchDisplay = false }
                else { showsNotesTab = layout == .notes }
            }
        }
    }

    private func settingsView(for scope: WorkspaceStyleScope) -> some View {
        SettingsView(scopeTitle: scope.title, isReadingScope: scope == .reading,
                     isSourceScope: scope == .source,
                     readerWidth: styleBinding(for: scope, keyPath: \.readerWidth, reading: $readerWidth),
                     bodyColorHex: styleBinding(for: scope, keyPath: \.bodyColorHex, reading: $bodyColorHex),
                     readerBackgroundHex: styleBinding(for: scope, keyPath: \.backgroundHex, reading: $readerBackgroundHex),
                     strongColorHex: styleBinding(for: scope, keyPath: \.strongColorHex, reading: $strongColorHex),
                     strongSize: styleBinding(for: scope, keyPath: \.strongSize, reading: $strongSize),
                     strongFamily: styleBinding(for: scope, keyPath: \.strongFamily, reading: $strongFamily),
                     headingStylesData: styleBinding(for: scope, keyPath: \.headingStylesData, reading: $headingStylesData),
                     bodySize: styleBinding(for: scope, keyPath: \.bodySize, reading: $bodySize),
                     bodyFamily: styleBinding(for: scope, keyPath: \.bodyFamily, reading: $bodyFamily),
                     lineHeight: styleBinding(for: scope, keyPath: \.lineHeight, reading: $lineHeight),
                     paragraphSpacing: styleBinding(for: scope, keyPath: \.paragraphSpacing, reading: $paragraphSpacing),
                     outlineColorsData: styleBinding(for: scope, keyPath: \.outlineColorsData, reading: $outlineColorsData),
                     annotationFontSize: $annotationFontSize, annotationFontFamily: $annotationFontFamily,
                     annotationTextColorHex: $annotationTextColorHex,
                     readingDataLocation: readingLibrary.locationDescription,
                     embedded: true,
                     onDone: { activeSheet = nil })
    }

    private var overallSettingsView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("整体设置").font(.system(size: 18, weight: .semibold))
                Spacer()
                Button("完成") { activeSheet = nil }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Picker("设置范围", selection: $settingsScope) {
                ForEach(WorkspaceStyleScope.allCases, id: \.self) { scope in
                    Label(scope.shortTitle, systemImage: scope.symbol).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 22)
            .help("分别设置阅读、Markdown 可视化和 Markdown 源码；三套设置互不覆盖")

            settingsView(for: settingsScope)
                .id(settingsScope.title)
        }
        .frame(width: 680, height: 820)
    }

    private func openOverallSettings() {
        settingsScope = activeStyleScope
        activeSheet = .settings
    }

    private var navigationRail: some View {
        VStack(spacing: 8) {
            ForEach(visibleSidebarTabs, id: \.self) { tab in
                Button {
                    sidebarOutlineTab = tab
                    showSidebar = true
                    ReaderActions.sidebarVisible = true
                    activateWorkspaceArea(.outline)
                } label: {
                    Image(systemName: tab.symbol)
                    .font(.system(size: 16, weight: .regular))
                    .frame(width: 38, height: 38)
                    .background(sidebarOutlineTab == tab && showSidebar ? Color.primary.opacity(0.08) : .clear,
                                in: RoundedRectangle(cornerRadius: 9))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(tab.title)
                .accessibilityLabel(tab.title)
            }
            Spacer()
            Button(action: openOverallSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .regular))
                    .frame(width: 38, height: 38)
                    .background(Color.clear, in: RoundedRectangle(cornerRadius: 9))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("整体设置（⌘,）")
            .accessibilityLabel("整体设置")
        }
        .padding(.top, 54)
        .padding(.bottom, 12)
        .frame(width: 50)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .trailing) { Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1) }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("工程工作区").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Button(action: createWorkspace) {
                    Image(systemName: "plus.square.on.square").frame(width: 28, height: 26).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("新建 Workspace 工程")
                .toolbarHint("新建 Workspace 工程（⇧⌘N）")
                Button(action: chooseWorkspaceFile) {
                    Image(systemName: "square.stack.3d.up").frame(width: 28, height: 26).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("打开 Workspace 工程")
                .toolbarHint("打开 Workspace 工程（.mdworkspace）")
                Button(action: chooseFolder) { Image(systemName: "folder.badge.plus").frame(width: 28, height: 26).contentShape(Rectangle()) }
                    .buttonStyle(.plain).help("打开工程文件夹").toolbarHint("打开工程文件夹")
                Button(action: chooseFile) { Image(systemName: "doc.badge.plus").frame(width: 28, height: 26).contentShape(Rectangle()) }
                    .buttonStyle(.plain).help("打开文件；阅读资料会复制到当前工程").toolbarHint("打开文件；阅读资料会复制到当前工程")
                Button(action: closeSidebarSelection) {
                    Image(systemName: "xmark.circle").frame(width: 28, height: 26).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canCloseSidebarSelection)
                .help(sidebarCloseTitle)
                .toolbarHint("\(sidebarCloseTitle)；未保存内容会先询问")
                .accessibilityLabel(sidebarCloseTitle)
            }.padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 12)

            HStack(spacing: 4) {
                Text(sidebarOutlineTab.title).font(.system(size: 12, weight: .medium))
                Spacer(minLength: 0)
                if sidebarOutlineTab == .markdown && !headings.isEmpty {
                    Button { expandedHeadings = Set(headings.map(\.id)) } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left").font(.system(size: 10))
                    }.buttonStyle(.plain).help("展开全部目录").toolbarHint("展开全部目录")
                    Button { expandedHeadings.removeAll() } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 10))
                    }.buttonStyle(.plain).help("收起子目录").toolbarHint("收起子目录")
                }
            }
            .padding(.horizontal, 12).padding(.top, 13).padding(.bottom, 7)

            Group {
                if sidebarOutlineTab == .files {
                    fileBrowser
                } else if sidebarOutlineTab == .webBookmarks {
                    webBookmarkOutline
                } else if sidebarOutlineTab == .reading {
                    readingOutline
                } else {
                    markdownOutline
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.outline) } }
            Spacer(minLength: 0)
            HStack(spacing: 7) {
                Image(systemName: "text.alignleft").font(.system(size: 11))
                Text(sidebarOutlineTab == .files ? (folderURL?.lastPathComponent ?? "文件浏览") : sidebarOutlineTab == .webBookmarks ? "网页收藏" : sidebarOutlineTab == .reading
                     ? (webBrowser.currentURL != nil ? "网页" : pdfDocument != nil ? "PDF" : epubDocument != nil ? "EPUB" : "阅读")
                     : (displayMode == .read ? "可视化编辑" : displayMode == .edit ? "Markdown 源码" : "源码 + 可视化"))
                    .font(.system(size: 11))
                Spacer()
            }.foregroundStyle(.tertiary).padding(.horizontal, 18).padding(.vertical, 14)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        .overlay { workspaceFocusRing(focusedWorkspaceArea == .outline) }
        .shadow(color: focusedWorkspaceArea == .outline ? Color.gray.opacity(0.08) : .clear, radius: 5)
        .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.outline) } }
    }

    @ViewBuilder
    private var fileBrowser: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(workspaceDisplayName)
                    .font(.system(size: 11, weight: .semibold)).lineLimit(1)
                Spacer()
                Menu {
                    Button("新建 Workspace…") { createWorkspace() }
                    Divider()
                    Button("打开文件…") { chooseFile() }
                    Button("添加文件夹到工作区…") { chooseAdditionalWorkspaceFolder() }
                    Button("添加外部文件引用…") { chooseAdditionalWorkspaceFiles() }
                    Button("打开工作区…") { chooseWorkspaceFile() }
                    Button("保存工作区…") { saveWorkspaceFile() }
                } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton).fixedSize().help("管理工作区和文件夹")
            }.padding(.horizontal, 12).padding(.vertical, 6)
            if !recentWorkspaces.isEmpty {
                DisclosureGroup("最近使用", isExpanded: $showRecentWorkspaces) {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(recentWorkspaces) { workspace in
                                Button { openRecentWorkspace(workspace) } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(workspace.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                        Text(workspace.subtitle).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5)
                                }
                                .buttonStyle(.plain)
                                .help([workspace.readingPath, workspace.notePath].compactMap { $0 }.joined(separator: "\n"))
                            }
                        }
                    }.frame(maxHeight: folderURL == nil && workspaceFiles.isEmpty ? .infinity : 180)
                }.font(.system(size: 11, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 6)
            }
            if folderURL != nil || !workspaceFiles.isEmpty {
                ScrollView {
                  LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(workspaceFolders.isEmpty ? (folderURL.map { [$0] } ?? []) : workspaceFolders, id: \.self) { folder in
                        WorkspaceFileTree(folder: folder, selected: selectedWorkspaceFile,
                                          initiallyExpanded: true, remove: { removeWorkspaceFolder(folder) },
                                          delete: requestWorkspaceFileDeletion,
                                          importFiles: importFilesIntoWorkspaceFolder, open: { open($0) })
                            .id("\(folder.standardizedFileURL.path)#\(workspaceFileTreeRevision)")
                    }
                    ForEach(workspaceFiles, id: \.self) { file in
                        Button { open(file) } label: { Label(file.lastPathComponent, systemImage: "doc.text").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading) }
                            .buttonStyle(.plain).help(file.path)
                            .draggable(file)
                            .contextMenu { Button("从工作区移除文件") { workspaceFiles.removeAll { $0 == file } } }
                    }
                  }.padding(.horizontal, 12).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("选择文件夹以浏览文件")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                    .padding(.horizontal, 18).padding(.top, 8)
            }
        }
    }

    /// Automatic manifests live in Application Support and contain a stable
    /// hash. That implementation detail must not become the project name shown
    /// in the Explorer: a one-folder project is named after its root folder,
    /// just like VS Code. Explicit multi-root workspace files keep their name.
    private var workspaceDisplayName: String {
        if workspaceFolders.count == 1, let folder = workspaceFolders.first {
            return folder.lastPathComponent
        }
        if let workspaceFileURL {
            return workspaceFileURL.deletingPathExtension().lastPathComponent
        }
        if workspaceFiles.count == 1, let file = workspaceFiles.first {
            return file.deletingPathExtension().lastPathComponent
        }
        return "工作区"
    }

    private var selectedWorkspaceFile: URL? {
        switch focusedWorkspaceArea == .outline ? lastContentFocus : focusedWorkspaceArea {
        case .pdf: return pdfSourceURL
        case .epub: return epubDocument?.sourceURL
        case .office: return officeDocumentURL
        case .markdownEditor, .markdownPreview, .markdownReader: return selectedFile
        case .web, .outline: return nil
        }
    }

    @ViewBuilder
    private var readingOutline: some View {
        if let officeDocumentURL, lastReadingFocus != .web || webBrowser.currentURL == nil {
            VStack(alignment: .leading, spacing: 10) {
                Label(officeDocumentURL.lastPathComponent, systemImage: "doc.richtext")
                Text("使用 macOS 原格式预览，只供阅读。")
                    .foregroundStyle(.secondary)
                Button("阅读原文") {
                    if usesSwitchDisplay { switchWorkspaceTab(toNotes: false) }
                    else { epubNotebookLayout = .epub; activateReadingArea() }
                }
            }.font(.system(size: 12)).padding(16)
            Spacer()
        } else if webBrowser.currentURL != nil && (lastReadingFocus == .web || !hasBookSource) {
            if webBrowser.headings.isEmpty {
                Text("网页中的标题会显示在这里")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                    .padding(.horizontal, 18).padding(.top, 8)
                Spacer()
            } else {
                List(webBrowser.headings) { heading in
                    Button {
                        activateWorkspaceArea(.outline)
                        webBrowser.navigate(to: heading)
                    } label: {
                        Text(heading.title).lineLimit(2)
                            .font(.system(size: max(11, 12 * outlineFontScale), weight: heading.level == 1 ? .medium : .regular))
                            .padding(.leading, CGFloat(min(heading.level - 1, 5) * 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 8))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        } else if let pdfDocument {
            let bookmarks = pdfDocument.markdownStudioBookmarks
            if !bookmarks.isEmpty {
                List {
                    OutlineGroup(bookmarks, children: \.children) { item in
                        Button {
                            activateWorkspaceArea(.outline)
                            if let pageIndex = item.pageIndex { navigatePDF(to: pageIndex) }
                        } label: {
                            HStack(spacing: 6) {
                                Text(item.title).lineLimit(2)
                                Spacer(minLength: 2)
                                if let pageIndex = item.pageIndex {
                                    Text("\(pageIndex + 1)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                                }
                            }
                            .font(.system(size: max(11, 12 * outlineFontScale)))
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(item.pageIndex == pdfCurrentPage ? Color.accentColor.opacity(0.11) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 8))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.outline) } }
            } else {
                List {
                    ForEach(0..<pdfDocument.pageCount, id: \.self) { pageIndex in
                        Button {
                            activateWorkspaceArea(.outline)
                            navigatePDF(to: pageIndex)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.image").font(.system(size: 11)).foregroundStyle(.secondary)
                                Text("第 \(pageIndex + 1) 页").font(.system(size: max(11, 12 * outlineFontScale)))
                                Spacer()
                            }
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(pageIndex == pdfCurrentPage ? Color.accentColor.opacity(0.11) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 8))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.outline) } }
            }
        } else if let context = activeWorkspaceEPUBContext {
            epubTableOfContents(context.document, currentChapter: context.chapter) { target in
                let key = context.url.path
                workspaceEPUBChapters[key] = target.chapterIndex
                let revision = (workspaceEPUBNavigationTargets[key]?.revision ?? 0) + 1
                workspaceEPUBNavigationTargets[key] = WorkspaceEPUBNavigationTarget(
                    chapterIndex: target.chapterIndex, fragment: target.fragment, revision: revision)
            }
        } else if let epubDocument {
            epubTableOfContents(epubDocument, currentChapter: epubCurrentChapter) { target in
                epubCurrentChapter = target.chapterIndex
                epubTargetFragment = target.fragment
                epubSelection = nil
                epubAnnotationJumpID = nil
                epubNavigationRequest += 1
            }
        } else {
            markdownOutline
        }
    }

    @ViewBuilder private func epubTableOfContents(
        _ document: EPUBPackageDocument,
        currentChapter: Int,
        onSelect: @escaping ((chapterIndex: Int, fragment: String?)) -> Void
    ) -> some View {
        if document.tableOfContents.isEmpty {
            Text("此 EPUB 没有可识别的目录")
                .font(.system(size: 11)).foregroundStyle(.tertiary)
                .padding(.horizontal, 18).padding(.top, 8)
            Spacer()
        } else {
            List {
                ForEach(Array(document.tableOfContents.enumerated()), id: \.element.id) { _, item in
                    Button {
                        activateWorkspaceArea(.outline)
                        if let target = document.navigationTarget(for: item) { onSelect(target) }
                    } label: {
                        Text(item.title).lineLimit(2)
                            .font(.system(size: max(11, 12 * outlineFontScale), weight: item.level == 0 ? .medium : .regular))
                            .padding(.leading, CGFloat(min(item.level, 6) * 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 7)
                            .background(document.navigationTarget(for: item)?.chapterIndex == currentChapter ? Color.accentColor.opacity(0.11) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 8))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.outline) } }
        }
    }

    private var webBookmarkOutline: some View {
        Group {
            if webBookmarks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("还没有网页收藏").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Text("打开网页后点星形按钮，可以保存网页、编辑名称和备注。")
                        .font(.system(size: 11)).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
                }.padding(.horizontal, 16).padding(.top, 12)
                Spacer()
            } else {
                List(webBookmarks) { bookmark in
                    Button {
                        guard let url = URL(string: bookmark.urlString) else { return }
                        open(url)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(bookmark.title).font(.system(size: 12, weight: .medium)).lineLimit(2)
                            Text(bookmark.note.isEmpty ? (URL(string: bookmark.urlString)?.host ?? bookmark.urlString) : bookmark.note)
                                .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .help("点击打开网页；右击可编辑名称和备注或删除收藏")
                    .contextMenu {
                        Button("编辑名称与备注") { beginEditBookmark(bookmark) }
                        Button("删除收藏", role: .destructive) { deleteWebBookmark(bookmark) }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var markdownOutline: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let selectedFile {
                Text("笔记层级").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 18).padding(.top, 8)
                ScrollView {
                    MarkdownNoteTree(node: MarkdownNoteNode(MarkdownNoteHierarchy.root(of: selectedFile)),
                                     selected: selectedFile, open: { open($0) }, delete: deleteChildFromTree)
                        .id(noteTreeRevision).padding(.horizontal, 12)
                }.frame(maxHeight: 220)
                Divider().padding(.vertical, 6)
            }
            markdownHeadingOutline
        }
    }

    @ViewBuilder
    private var markdownHeadingOutline: some View {
        if headings.isEmpty {
            Text("文档中的标题会显示在这里")
                .font(.system(size: 11)).foregroundStyle(.tertiary)
                .padding(.horizontal, 18).padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.outline) } }
            Spacer()
        } else {
            List {
                ForEach(topHeadings) { heading in
                    HeadingRow(heading: heading, allHeadings: headings, expanded: $expandedHeadings,
                               styles: (try? JSONDecoder().decode([HeadingStyle].self, from: previewStyle.headingStylesData)) ?? HeadingStyle.defaults,
                               outlineColors: (try? JSONDecoder().decode([String].self, from: previewStyle.outlineColorsData)) ?? Array(repeating: "#222222", count: 6),
                               fontScale: previewStyle.outlineFontScale, onSelect: jumpTo)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 8))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.outline) } }
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

    @ViewBuilder
    private var workspaceModeControls: some View {
        if hasNotebookReadingSource {
            if !usesSwitchDisplay {
                HStack(spacing: 1) {
                    toolbarModeSegment(pdfDocument != nil ? "doc.text.image" : webBrowser.currentURL != nil ? "globe" : "book",
                                       selected: epubNotebookLayout == .epub,
                                       hint: "只看\(pdfDocument != nil ? "PDF" : webBrowser.currentURL != nil ? "网页" : "EPUB 原书") · ⌃⌘1") { epubNotebookLayout = .epub }
                    toolbarModeSegment("doc.text", selected: epubNotebookLayout == .notes,
                                       hint: "只看 Markdown 笔记 · ⌃⌘2") { epubNotebookLayout = .notes }
                    toolbarModeSegment("rectangle.split.3x1", selected: epubNotebookLayout == .stacked,
                                       hint: "阅读 + Markdown 笔记 · ⌃⌘3") { epubNotebookLayout = .stacked }
                }
                .padding(2)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                .frame(width: 86)
                .help("切换阅读内容、Markdown 笔记或并排工作区")
            }
            if (officeDocumentURL != nil || pdfDocument != nil || webBrowser.currentURL != nil
                || (epubDocument != nil && isEPUBNotebook)) && epubNotebookLayout == .stacked {
                Picker("Markdown 工作区布局", selection: Binding(
                    get: { pdfNotesLayout },
                    set: { layout in
                        epubNotebookLayout = .stacked
                        switch layout {
                        case .visual: showVisualMarkdown()
                        case .source: showMarkdownSource()
                        }
                    }
                )) {
                    ForEach(PDFNotesLayout.allCases, id: \.self) { layout in
                        Text(layout.title).tag(layout)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
                .fixedSize(horizontal: true, vertical: false)
                .help("选择右侧显示可视化笔记或 Markdown 源码")
                .accessibilityLabel("Markdown 工作区布局")
            } else if epubNotebookLayout == .notes {
                markdownModeSegments
            }
        } else if epubDocument != nil {
            HStack(spacing: 1) {
                toolbarModeSegment("eye", selected: displayMode == .read,
                                   hint: "阅读 EPUB 原书 · ⌘R") { displayMode = .read }
                toolbarModeSegment("pencil.line", selected: displayMode == .edit,
                                   hint: "所见即所得编辑 EPUB · ⌘R") { displayMode = .edit }
            }
            .padding(2)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
            .frame(width: 58)
            .help("阅读或编辑 EPUB 原文 · ⌘R")
        } else {
            markdownModeSegments
        }
    }

    private var markdownModeSegments: some View {
        HStack(spacing: 1) {
            toolbarModeSegment("text.cursor", selected: displayMode == .read,
                               hint: "所见即所得编辑 Markdown · ⇧⌘V") { showVisualMarkdown() }
            toolbarModeSegment("pencil.line", selected: displayMode == .edit,
                               hint: "Markdown 源码 · ⌘R") { showMarkdownSource() }
            toolbarModeSegment("rectangle.split.2x1", selected: displayMode == .split,
                               hint: "可视化与源码并排") { usesSwitchDisplay = false; displayMode = .split }
        }
        .padding(2)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
        .frame(width: 86)
        .help("切换 Markdown 可视化、源码与分栏")
    }

    private var workspaceLayoutBar: some View {
        HStack(spacing: 12) {
            Menu {
                Button("新建网页标签") { createWorkspaceWebTab() }
                if selectedFile != nil {
                    Button("打开可视化笔记") { showWorkspaceNoteTab(.visual) }
                    Button("打开 Markdown 源码") { showWorkspaceNoteTab(.source) }
                }
            } label: {
                Label("添加标签", systemImage: "plus")
            }
            .help("打开网页或添加 Markdown 视图")
            Spacer(minLength: 0)
            Text("拖动标签切换分组，右键可拆分").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12).frame(height: 34)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func createWorkspaceWebTab() {
        MarkdownVisualCommandHub.commitActiveEdits {
            let id = webSessions.create()
            workspaceTabs.add(WorkspaceTab(.web, id: id))
            activateWorkspaceArea(.web)
        }
    }

    private func showWorkspaceNoteTab(_ kind: WorkspaceTab.Kind) {
        guard let selectedFile else { return }
        if let existing = workspaceTabs.allTabs.first(where: {
            $0.kind == kind && $0.location?.standardizedFileURL == selectedFile.standardizedFileURL
        }) {
            selectWorkspaceTab(existing)
            return
        }
        let tab = WorkspaceTab(kind, location: selectedFile)
        MarkdownVisualCommandHub.commitActiveEdits {
            workspaceTabs.add(tab)
            selectWorkspaceTab(tab)
        }
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
            Menu {
                Button("新建网页标签") { createWorkspaceWebTab() }
                if selectedFile != nil {
                    Button("打开可视化笔记") { showWorkspaceNoteTab(.visual) }
                    Button("打开 Markdown 源码") { showWorkspaceNoteTab(.source) }
                }
            } label: { Image(systemName: "plus.square.on.square").frame(width: 22, height: 22) }
                .menuStyle(.borderlessButton).fixedSize().help("添加网页或笔记标签")
            Button { arrangeWorkspace(.right) } label: { Image(systemName: "rectangle.split.2x1").frame(width: 22, height: 22) }
                .buttonStyle(.plain).disabled(workspaceTabs.allTabs.count < 2).help("左右并排工作区")
            Button { arrangeWorkspace(.bottom) } label: { Image(systemName: "rectangle.split.1x2").frame(width: 22, height: 22) }
                .buttonStyle(.plain).disabled(workspaceTabs.allTabs.count < 2).help("上下并排工作区")
            Menu {
                Button("全部合并为标签") { arrangeWorkspace(.center) }
                Button("左右并排") { arrangeWorkspace(.right) }.disabled(workspaceTabs.allTabs.count < 2)
                Button("上下并排") { arrangeWorkspace(.bottom) }.disabled(workspaceTabs.allTabs.count < 2)
            } label: { Image(systemName: "rectangle.split.2x1").frame(width: 22, height: 22) }
                .menuStyle(.borderlessButton).fixedSize().help("快捷排布工作区")
            if selectedFile != nil && [.markdownEditor, .markdownReader, .markdownPreview].contains(focusedWorkspaceArea) {
                noteNavigationButtons
            }
            Text(workspaceTitle)
                .font(.system(size: 13, weight: .medium)).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let closeTitle = toolbarCloseTitle {
                Button(action: closeToolbarDocument) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 12))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(closeTitle == "关闭笔记" && source != savedSource
                      ? "关闭 Markdown 笔记；先确认是否保存修改"
                      : epubHasChanges && toolbarTargetsReading
                      ? "关闭阅读文件；先确认是否保存修改"
                      : "\(closeTitle)；未保存内容会先询问")
                .toolbarHint("\(closeTitle)；未保存内容会先询问")
                .accessibilityLabel(closeTitle)
            }
            if toolbarTargetsReading, (focusedWorkspaceArea == .outline ? lastContentFocus : focusedWorkspaceArea) == .pdf, let pdfDocument {
                Button { navigatePDF(to: pdfCurrentPage - 1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.plain).disabled(pdfCurrentPage <= 0)
                    .help("上一页").toolbarHint("上一页 PDF · ←")
                TextField("1", text: $pdfPageInput)
                    .frame(width: 35).textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .onSubmit(commitPDFPageInput)
                    .help("输入页码并按回车跳转")
                Text("/ \(pdfDocument.pageCount)")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                Button { navigatePDF(to: pdfCurrentPage + 1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.plain).disabled(pdfCurrentPage + 1 >= pdfDocument.pageCount)
                    .help("下一页").toolbarHint("下一页 PDF · →")
            } else if toolbarTargetsReading,
                      (focusedWorkspaceArea == .outline ? lastContentFocus : focusedWorkspaceArea) == .epub,
                      let context = activeWorkspaceEPUBContext, !context.document.chapters.isEmpty {
                Button { navigateWorkspaceEPUB(context, offset: -1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.plain).disabled(context.chapter == 0)
                    .help("上一章 / 上一页（←）")
                    .toolbarHint("上一章 / 上一页 · ←")
                Text("\(context.chapter + 1) / \(context.document.chapters.count)")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    .help("EPUB 阅读顺序中的章节位置")
                Button { navigateWorkspaceEPUB(context, offset: 1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.plain).disabled(context.chapter >= context.document.chapters.count - 1)
                    .help("下一章 / 下一页（→）")
                    .toolbarHint("下一章 / 下一页 · →")
            } else if toolbarTargetsReading, (focusedWorkspaceArea == .outline ? lastContentFocus : focusedWorkspaceArea) == .epub, let epubDocument, !epubDocument.chapters.isEmpty {
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
                Button { epubEditingAnnotation = nil; activeSheet = .epubAnnotationComposer } label: {
                    Image(systemName: "highlighter").font(.system(size: 13)).frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .disabled(epubSelection == nil)
                .help(epubSelection == nil ? "先在原书中选中文字，再添加注释（⇧⌘M）" : "为所选文字添加注释（⇧⌘M）")
                .toolbarHint("选择原书文字后添加注释 · ⇧⌘M")
                Button { activeSheet = .epubAnnotationList } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "text.book.closed").font(.system(size: 12))
                        if !epubAnnotations.isEmpty { Text("\(epubAnnotations.count)").font(.system(size: 10, design: .rounded)) }
                    }.frame(height: 22)
                }
                .buttonStyle(.plain)
                .help("查看 EPUB 注释（⌥⌘M）")
                .toolbarHint("查看、修改或删除注释 · ⌥⌘M")
            }
            if hasOpenWorkspace {
                HStack(spacing: 6) {
                if documentZoomControlIsActive {
                    Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(.secondary)
                        .help(pdfZoomControlIsActive ? "PDF 缩放" : officeZoomControlIsActive ? "文档缩放" : "网页缩放")
                    if pdfZoomControlIsActive {
                        Button {
                            requestPDFDisplayPreset(.fitWidth)
                        } label: {
                            Image(systemName: "arrow.left.and.right")
                                .font(.system(size: 11))
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .help("适合页宽：按当前 PDF 阅读区重新计算")
                        .toolbarHint("适合页宽 · 按当前阅读区重新计算")
                        Button {
                            requestPDFDisplayPreset(.fitHeight)
                        } label: {
                            Image(systemName: "arrow.up.and.down")
                                .font(.system(size: 11))
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .help("适合页高：按当前 PDF 阅读区重新计算")
                        .toolbarHint("适合页高 · 按当前阅读区重新计算")
                        Button {
                            requestPDFDisplayPreset(.best)
                        } label: {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11))
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .help("最佳显示：扫描页按原图像素计算；其他页面完整显示")
                        .toolbarHint("最佳显示 · 扫描页原图像素 1:1；其他页面完整显示")
                        Slider(value: pdfZoomSliderBinding, in: log(25)...log(1000))
                            .frame(width: 86).help("PDF 缩放：\(Int(pdfZoomPercent))%")
                            .toolbarHint("调整 PDF 页面缩放：\(Int(pdfZoomPercent))%")
                        TextField("100", text: $pdfZoomInput)
                            .frame(width: 42).textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                            .onSubmit(commitPDFZoomInput)
                            .help("输入 PDF 缩放百分比并按回车")
                    } else if officeZoomControlIsActive {
                        Slider(value: $officeZoomPercent, in: 25...500, step: 5)
                            .frame(width: 86).help("文档缩放：\(Int(officeZoomPercent))%")
                        TextField("100", text: $officeZoomInput)
                            .frame(width: 42).textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                            .onSubmit(commitOfficeZoomInput)
                            .help("输入文档缩放百分比并按回车，范围 25–500%")
                    } else {
                        Slider(value: $webZoomPercent, in: 50...200, step: 5)
                            .frame(width: 86).help("网页缩放：\(Int(webZoomPercent))%")
                            .toolbarHint("调整网页缩放：\(Int(webZoomPercent))%")
                        TextField("100", text: $webZoomInput)
                            .frame(width: 42).textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                            .onSubmit(commitWebZoomInput)
                            .help("输入网页缩放百分比并按回车")
                    }
                    Text("%").font(.system(size: 11)).foregroundStyle(.secondary)
                } else {
                    Image(systemName: "arrow.left.and.right").font(.system(size: 11)).foregroundStyle(.secondary)
                        .help(epubWidthControlIsActive ? "调整 EPUB 原书排版宽度" : activeStyleScope == .source ? "调整 Markdown 源码编辑宽度" : "调整 Markdown 预览宽度")
                    Slider(value: activeContentWidthBinding, in: 520...1040, step: 20)
                        .frame(width: 86).help("排版宽度：\(Int(activeContentWidth)) 像素")
                        .toolbarHint(epubWidthControlIsActive ? "调整 EPUB 原书排版宽度" : activeStyleScope == .source ? "调整 Markdown 源码编辑宽度" : "调整 Markdown 预览宽度")
                    TextField("720", text: activeContentWidthInput)
                        .frame(width: 46).textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .onSubmit(commitActiveContentWidthInput)
                        .help(epubWidthControlIsActive ? "输入 EPUB 排版宽度（像素）并按回车" : activeStyleScope == .source ? "输入 Markdown 源码编辑宽度（像素）并按回车" : "输入 Markdown 预览宽度（像素）并按回车")
                    Text("px").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Button {
                    if pdfZoomControlIsActive { pdfZoomPercent = max(25, pdfZoomPercent - 10) }
                    else if webZoomControlIsActive { webZoomPercent = max(50, webZoomPercent - 10) }
                    else if officeZoomControlIsActive { officeZoomPercent = max(25, officeZoomPercent - 10) }
                    else { ReaderActions.adjustTypographySize(-1) }
                } label: {
                    Text(documentZoomControlIsActive ? "−" : "A−").font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .help(documentZoomControlIsActive ? "缩小\(pdfZoomControlIsActive ? "PDF" : officeZoomControlIsActive ? "文档" : "网页")（⌘−）" : "缩小当前区域字体（⌘−）")
                .toolbarHint(documentZoomControlIsActive ? "缩小\(pdfZoomControlIsActive ? "PDF" : officeZoomControlIsActive ? "文档" : "网页") · ⌘−" : "缩小当前区域字体 · ⌘−")
                Button {
                    if pdfZoomControlIsActive { pdfZoomPercent = min(1000, pdfZoomPercent + 10) }
                    else if webZoomControlIsActive { webZoomPercent = min(200, webZoomPercent + 10) }
                    else if officeZoomControlIsActive { officeZoomPercent = min(500, officeZoomPercent + 10) }
                    else { ReaderActions.adjustTypographySize(1) }
                } label: {
                    Text(documentZoomControlIsActive ? "+" : "A+").font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .help(documentZoomControlIsActive ? "放大\(pdfZoomControlIsActive ? "PDF" : officeZoomControlIsActive ? "文档" : "网页")（⌘+）" : "放大当前区域字体（⌘+）")
                .toolbarHint(documentZoomControlIsActive ? "放大\(pdfZoomControlIsActive ? "PDF" : officeZoomControlIsActive ? "文档" : "网页") · ⌘+" : "放大当前区域字体 · ⌘+")
                Button { openOverallSettings() } label: { Label("样式", systemImage: "textformat.size").font(.system(size: 12)) }
                    .disabled(focusedWorkspaceArea == .office)
                    .buttonStyle(.plain).help("\(activeStyleScope.title)：字体与行距（⌘,）")
                    .toolbarHint("\(activeStyleScope.title) · ⌘,")
                if !toolbarTargetsReading, selectedFile != nil {
                    if isShowingSourceOnly {
                        Button("MD 预览") { returnToVisualMarkdown() }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .help("返回 Markdown 可视化预览与编辑 · ⌘R")
                            .toolbarHint("返回 MD 预览 · ⌘R")
                    }
                    syntaxToolbarMenu
                    if isMarkdownSourceVisible {
                        Menu("源码显示") {
                            Toggle("语法着色", isOn: $sourceSyntaxHighlighting)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .help("关闭语法着色可减少长文档编辑时的排版开销")
                    }
                }
                if !toolbarTargetsReading, isDirty {
                    Button("保存") { MarkdownVisualCommandHub.commitActiveEdits { _ = saveDocument() } }.buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium)).help("保存修改（⌘S）")
                        .toolbarHint("保存修改 · ⌘S")
                }
                }.fixedSize()
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 74)
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .zIndex(10)
    }

    private var workspaceTitle: String {
        switch focusedWorkspaceArea == .outline ? lastContentFocus : focusedWorkspaceArea {
        case .web: return webBrowser.title
        case .pdf: return pdfSourceURL?.deletingPathExtension().lastPathComponent ?? "PDF 阅读"
        case .epub: return epubDocument?.title ?? "电子书"
        case .office: return officeDocumentURL?.deletingPathExtension().lastPathComponent ?? "文档"
        case .markdownEditor, .markdownPreview, .markdownReader:
            return selectedFile?.deletingPathExtension().lastPathComponent ?? documentTitle
        case .outline: return documentTitle
        }
    }

    private var syntaxToolbarMenu: some View {
        Menu {
            ForEach(1...6, id: \.self) { level in
                Button("标题 \(level)  ⌘\(level)") { applyHeadingLevel(level) }
            }
            Button("段落") { clearLinePrefix() }
            Divider()
            Button("加粗  ⌘B") { applyInlineSyntax("**", "**") }
            Button("斜体  ⌘I") { applyInlineSyntax("*", "*") }
            Button("下划线  ⌘U") { applyInlineSyntax("<u>", "</u>") }
            Button("删除线  ⇧⌘E") { applyInlineSyntax("~~", "~~") }
            Button("链接  ⌃⌘L") { applyInlineSyntax("[", "](链接地址)") }
            Button("行内代码  ⌘K") { applyInlineSyntax("`", "`") }
            Divider()
            Button("无序列表  ⌃U") { applyLinePrefix("- ") }
            Button("有序列表  ⇧⌃O") { applyLinePrefix("1. ") }
            Button("任务列表  ⇧⌘T") { applyLinePrefix("- [ ] ") }
            Button("引用  ⇧⌘B") { applyLinePrefix("> ") }
            Button("分隔线  ⌥⌘S") { insertHorizontalRule() }
            Divider()
            Button("在当前位置新建子笔记…") { createInlineChildNote() }
            Button("插入已有笔记链接…") { insertChildNoteLink() }
            Button("插入可折叠子笔记…") { insertChildNoteLink(embedded: true) }
            Button("插入图片文件…  ⌥⌘I") { insertImageFile() }
            Button("插入表格…  ⌘T") { activeSheet = .tableInsertion }
            Divider()
            if isShowingSourceOnly {
                Button("切换到可视化编辑") { showVisualMarkdown() }
            } else {
                Button("切换到 Markdown 源码") { showMarkdownSource() }
            }
        } label: {
            HStack(spacing: 3) {
                Text("语法")
                Image(systemName: "chevron.down").font(.system(size: 9))
            }
            .font(.system(size: 11))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("选中文字后应用 Markdown 格式")
        .toolbarHint("Markdown 语法菜单")
    }

    private var isVisualMarkdownFocused: Bool {
        guard focusedWorkspaceArea != .markdownEditor else { return false }
        guard selectedFile != nil, let view = MarkdownVisualCommandHub.activeWebView else { return false }
        if let responder = view.window?.firstResponder as? NSView,
           responder === view || responder.isDescendant(of: view) { return true }
        return focusedWorkspaceArea == .markdownReader || focusedWorkspaceArea == .markdownPreview
    }

    private var isMarkdownSourceVisible: Bool {
        workspaceTabs.groups.contains { group in group.tabs.contains { $0.kind == .source && $0.id == group.selected } }
    }

    private var canEditMarkdownSource: Bool {
        guard isMarkdownSourceVisible else { return false }
        if isShowingSourceOnly { return true }
        if NSApp.keyWindow?.firstResponder is MarkdownSourceTextView { return true }
        return focusedWorkspaceArea == .markdownEditor
    }

    private var isShowingSourceOnly: Bool {
        focusedWorkspaceArea == .markdownEditor
    }

    private func showVisualMarkdown() {
        if let window = NSApp.keyWindow { _ = window.makeFirstResponder(nil) }
        MarkdownSourcePositionHub.flushPendingChanges()
        MarkdownSourcePositionHub.capture()
        guard saveMarkdownBeforeModeSwitch() else { return }
        visualRestoreRequest += 1
        visualScrollState.activeMode = .visual
        if selectedFile != nil { showWorkspaceNoteTab(.visual); return }
        let hasReadingDocument = hasNotebookReadingSource
        if hasReadingDocument && epubNotebookLayout == .stacked && !usesSwitchDisplay {
            maximizedNotebookPane = maximizedNotebookPane == .editor ? .preview : .rightPreview
            activateWorkspaceArea(.markdownPreview)
        } else {
            displayMode = .read
            if usesSwitchDisplay && hasReadingSource { showsNotesTab = true; epubNotebookLayout = .notes }
            activateWorkspaceArea(.markdownReader)
        }
    }

    private func showMarkdownSource() {
        MarkdownVisualCommandHub.commitActiveEdits {
            guard saveMarkdownBeforeModeSwitch() else { return }
            enterMarkdownSourceMode()
        }
    }

    private func saveMarkdownBeforeModeSwitch() -> Bool {
        // Resigning the text view commits any marked IME composition before
        // reading the binding and writing the Markdown document to disk.
        if let window = NSApp.keyWindow { _ = window.makeFirstResponder(nil) }
        MarkdownSourcePositionHub.flushPendingChanges()
        guard source == savedSource || saveDocument() else { return false }
        return true
    }

    private func enterMarkdownSourceMode() {
        visualScrollState.activeMode = .source
        if let selection = visualScrollState.selection {
            editorSelection = selection
        } else if let viewport = visualScrollState.viewport {
            editorSelection = NSRange(location: viewport.sourceOffset, length: 0)
        }
        sourcePositionRestoreRequest += 1
        editorFocusRequest += 1
        if selectedFile != nil { showWorkspaceNoteTab(.source); return }
        let hasReadingDocument = hasNotebookReadingSource
        if hasReadingDocument && epubNotebookLayout == .stacked && !usesSwitchDisplay {
            maximizedNotebookPane = maximizedNotebookPane == .preview ? .editor : .rightEditor
            activateWorkspaceArea(.markdownEditor)
        } else {
            displayMode = .edit
            if usesSwitchDisplay && hasReadingSource { showsNotesTab = true; epubNotebookLayout = .notes }
            activateWorkspaceArea(.markdownEditor)
        }
    }

    private func toggleVisualMarkdownSource() {
        if selectedFile != nil {
            if focusedWorkspaceArea == .markdownEditor { showVisualMarkdown() }
            else { showMarkdownSource() }
            return
        }
        let hasReadingDocument = hasNotebookReadingSource
        if hasReadingDocument && epubNotebookLayout == .epub {
            epubNotebookLayout = .notes
            displayMode = .read
        } else if isShowingSourceOnly {
            showVisualMarkdown()
        } else {
            showMarkdownSource()
        }
    }

    private func returnToVisualMarkdown() { showVisualMarkdown() }

    @discardableResult
    private func applyVisualCommand(_ name: String, value: String = "") -> Bool {
        guard isVisualMarkdownFocused else { return false }
        return MarkdownVisualCommandHub.perform(name, value: value)
    }

    private func readingPane(backgroundHex: String? = nil,
                             focusArea: FocusedWorkspaceArea = .markdownReader) -> some View {
        let appearance = previewStyle
        let paneBackgroundHex = backgroundHex ?? appearance.backgroundHex
        return Group {
            if blocks.isEmpty && selectedFile == nil {
                VStack(spacing: 14) {
                    Image(systemName: "book.closed").font(.system(size: 36, weight: .ultraLight)).foregroundStyle(.tertiary)
                    Text("让 Markdown 回到阅读的样子").font(.system(size: 17, weight: .medium)).foregroundStyle(.secondary)
                    Text("打开一个文件，或选择文件夹浏览文档").font(.system(size: 12)).foregroundStyle(.tertiary)
                    HStack(spacing: 10) {
                        Button("打开文件") { chooseFile() }.buttonStyle(.bordered)
                        Button("浏览网页") { activeSheet = .webAddress }.buttonStyle(.bordered)
                        Button("打开文件夹") { chooseFolder() }.buttonStyle(.bordered)
                        Button("新建 Markdown 笔记") { createMarkdownNote() }.buttonStyle(.borderedProminent)
                    }.padding(.top, 4)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MarkdownVisualEditor(source: $source, blocks: blocks, parsedSource: parsedSource, readerWidth: appearance.readerWidth,
                                     headingStyles: (try? JSONDecoder().decode([HeadingStyle].self, from: appearance.headingStylesData)) ?? HeadingStyle.defaults,
                                     bodyColorHex: appearance.bodyColorHex,
                                     readerBackgroundHex: paneBackgroundHex, strongColorHex: appearance.strongColorHex,
                                     strongSize: appearance.strongSize, strongFamily: appearance.strongFamily,
                                     bodySize: appearance.bodySize, bodyFamily: appearance.bodyFamily, lineHeight: appearance.lineHeight,
                                     paragraphSpacing: appearance.paragraphSpacing,
                                     baseURL: selectedFile?.deletingLastPathComponent(), scrollTarget: scrollTarget,
                                     scrollRequest: scrollRequest,
                                     sourceLineTarget: synchronizedSourceLine, sourceLineRequest: visualSourceLineRequest,
                                     restoreRequest: visualRestoreRequest,
                                     scrollState: visualScrollState, onSourceLineChange: synchronizeSourceLineFromVisual,
                                     onActivate: { activateWorkspaceArea(focusArea) },
                                     onImagePaste: importVisualClipboardImage, onMarkdownLink: { open($0) },
                                     onSlashCommand: applySlashCommand, onDeleteManagedNote: deleteManagedChild)
            }
        }
        .background(Color(hex: paneBackgroundHex))
        .overlay { workspaceFocusRing(focusedWorkspaceArea == focusArea) }
        .overlay(alignment: .trailing) {
            if selectedFile != nil {
                WorkspacePositionMarkers(markers: markdownPositionMarkers(visual: true)) { id in
                    jumpTo(id)
                    activateWorkspaceArea(focusArea)
                }
            }
        }
        .shadow(color: focusedWorkspaceArea == focusArea ? Color.gray.opacity(0.045) : .clear, radius: 2)
        .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(focusArea) } }
    }

    @ViewBuilder
    private var originalReadingPane: some View {
        if let url = officeDocumentURL { officeReadingPane(url) }
        else if let document = pdfDocument { pdfReaderPane(document) }
        else if let url = webBrowser.currentURL { webReaderPane(url) }
        else if let document = epubDocument, document.chapters.indices.contains(epubCurrentChapter) {
            epubChapterPane(document, editable: false)
        }
    }

    private func officeReadingPane(_ url: URL) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(url.pathExtension.uppercased()) · 只读预览").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button(usesSwitchDisplay ? "笔记" : (maximizedNotebookPane == .epub || epubNotebookLayout == .epub ? "还原" : "满屏")) {
                    if usesSwitchDisplay { switchWorkspaceTab(toNotes: true) }
                    else if epubNotebookLayout == .epub { epubNotebookLayout = .stacked; maximizedNotebookPane = nil }
                    else { cycleNotebookExpansion(for: .epub) }
                }
                .buttonStyle(.borderless)
                .help(usesSwitchDisplay ? "切换到 Markdown 笔记 · ⇧⌘R" : "最大化或还原文档阅读区")
                .toolbarHint(usesSwitchDisplay ? "切换到 Markdown 笔记 · ⇧⌘R" : "最大化或还原文档阅读区")
            }.padding(.horizontal, 10).frame(height: 28)
            OfficeDocumentReader(url: url, state: officePreviewState, zoomPercent: $officeZoomPercent,
                                 onActivate: { activateWorkspaceArea(.office) })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .simultaneousGesture(TapGesture().onEnded { activateWorkspaceArea(.office) })
        }
        .overlay { workspaceFocusRing(focusedWorkspaceArea == .office) }
    }

    private func openOfficeDocument(_ url: URL) {
        guard OfficeReadingFormat.supports(url), FileManager.default.isReadableFile(atPath: url.path) else {
            saveError = "无法读取文档：\(url.lastPathComponent)"
            return
        }
        clearReadingSource()
        officePreviewState.reset(for: url)
        officeDocumentURL = url
        documentTitle = url.deletingPathExtension().lastPathComponent
        epubNotebookLayout = usesSwitchDisplay ? .epub : .stacked
        showsNotesTab = false
        if displayMode == .split { displayMode = .read }
        activateWorkspaceArea(.office)
        activateCompanionNote(for: url, selectNote: false)
        recordRecentWorkspace()
    }

    private func toggleSwitchDisplay() {
        MarkdownVisualCommandHub.commitActiveEdits {
            MarkdownSourcePositionHub.capture()
            guard saveMarkdownBeforeModeSwitch() else { return }
            if usesSwitchDisplay {
                usesSwitchDisplay = false
                if hasReadingSource { epubNotebookLayout = .stacked }
                else { displayMode = .split }
            } else {
                if epubDocument != nil { isEPUBNotebook = true }
                let notesFocused = [.markdownPreview, .markdownReader, .markdownEditor].contains(focusedWorkspaceArea)
                if displayMode == .split { displayMode = focusedWorkspaceArea == .markdownEditor ? .edit : .read }
                showsNotesTab = hasReadingSource && notesFocused
                epubNotebookLayout = showsNotesTab ? .notes : .epub
                maximizedNotebookPane = nil
                usesSwitchDisplay = true
            }
        }
    }

    private func switchWorkspaceTab(toNotes: Bool) {
        guard hasReadingSource else {
            if toNotes { showMarkdownSource() } else { showVisualMarkdown() }
            return
        }
        MarkdownVisualCommandHub.commitActiveEdits {
            MarkdownSourcePositionHub.capture()
            guard saveMarkdownBeforeModeSwitch() else { return }
            showsNotesTab = toNotes
            epubNotebookLayout = toNotes ? .notes : .epub
            if toNotes {
                if displayMode == .split { displayMode = .read }
                activateWorkspaceArea(displayMode == .edit ? .markdownEditor : .markdownPreview)
                DispatchQueue.main.async { focusMarkdownEditor() }
            } else {
                activateReadingArea()
                DispatchQueue.main.async { focusReadingAfterLayout() }
            }
        }
    }

    private func activateReadingArea() {
        if officeDocumentURL != nil { activateWorkspaceArea(.office) }
        else if pdfDocument != nil { activateWorkspaceArea(.pdf) }
        else if epubDocument != nil { activateWorkspaceArea(.epub) }
        else if webBrowser.currentURL != nil { activateWorkspaceArea(.web) }
    }

    private func focusReadingAfterLayout(attempt: Int = 0) {
        guard [.pdf, .epub, .web, .office].contains(focusedWorkspaceArea) else { return }
        guard !WorkspaceKeyboardFocus.focusReading(), attempt < 20 else { return }
        // A maximized pane recreates its native reader during the next layout.
        // Do not try to focus the detached view from the preceding layout.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) {
            focusReadingAfterLayout(attempt: attempt + 1)
        }
    }

    private func focusMarkdownEditor() {
        if isShowingSourceOnly {
            if let view = MarkdownSourcePositionHub.coordinator?.textView { view.window?.makeFirstResponder(view) }
            else { editorFocusRequest += 1 }
            visualScrollState.activeMode = .source
            activateWorkspaceArea(.markdownEditor)
        } else {
            MarkdownVisualCommandHub.focusActiveEditor()
            visualScrollState.activeMode = .visual
            activateWorkspaceArea(.markdownPreview)
        }
    }

    private func toggleReadingEditingFocus() {
        let notesFocused = [.markdownEditor, .markdownReader, .markdownPreview].contains(focusedWorkspaceArea)
        if notesFocused {
            if let target = workspaceTabs.allTabs.first(where: { $0.kind == .reading })
                ?? workspaceTabs.allTabs.first(where: { $0.kind == .web }) { selectWorkspaceTab(target) }
        } else if let target = workspaceTabs.allTabs.first(where: { $0.kind == .visual })
                    ?? workspaceTabs.allTabs.first(where: { $0.kind == .source }) {
            selectWorkspaceTab(target)
        }
    }

    private var documentPane: some View {
        Group {
            if hasOpenWorkspace {
                tabbedWorkspace
            } else {
                markdownWorkspacePane
            }
        }
        .task(id: workspaceResourcesKey) { synchronizeWorkspaceTabs() }
    }

    private var workspaceResourcesKey: String {
        let websites = webSessions.tabIDs.map { "\($0.uuidString):\(webSessions.session(for: $0)?.currentURL?.absoluteString ?? "")" }.joined(separator: ",")
        return "\(selectedFile?.standardizedFileURL.path ?? "")|\(pdfSourceURL?.standardizedFileURL.path ?? "")|\(epubDocument?.sourceURL.standardizedFileURL.path ?? "")|\(officeDocumentURL?.standardizedFileURL.path ?? "")|\(isConvertingKindle)|\(pendingPDFURL?.path ?? "")|\(websites)"
    }

    private func persistWorkspaceGrid() {
        guard workspaceRestorationComplete else { return }
        var snapshot = workspaceTabs
        snapshot.root = snapshot.root.mappingTabs { tab in
            var value = tab
            if tab.kind == .web { value.location = webSessions.session(for: tab.id)?.currentURL }
            return value
        }
        if let data = try? JSONEncoder().encode(snapshot) { workspaceGridData = data }
        if let workspaceFileURL, workspaceFileCanBeUpdated(workspaceFileURL) {
            do { try writeWorkspaceDocument(workspaceDocumentSnapshot(), to: workspaceFileURL) }
            catch { saveError = "无法更新工作区：\(error.localizedDescription)" }
        }
    }

    private func restoreWorkspaceGridIfNeeded() {
        guard !workspaceRestorationComplete else { return }
        defer { workspaceRestorationComplete = true }
        guard !ReaderActions.didRestoreWorkspace else { return }
        ReaderActions.didRestoreWorkspace = true
        guard selectedFile == nil, pdfDocument == nil, epubDocument == nil, officeDocumentURL == nil,
              let snapshot = try? JSONDecoder().decode(WorkspaceGridLayout.self, from: workspaceGridData), snapshot.isValid else { return }
        restoreWorkspaceGrid(snapshot)
    }

    private func restoreWorkspaceGrid(_ snapshot: WorkspaceGridLayout) {
        var restored = snapshot
        for tab in snapshot.allTabs {
            switch tab.kind {
            case .web:
                if let url = tab.location, !WebBrowserSession.isWebURL(url) { restored.remove(tab.id); continue }
                webSessions.create(url: tab.location, id: tab.id)
            case .reading, .source, .visual:
                guard let url = tab.location, FileManager.default.fileExists(atPath: url.path) else { restored.remove(tab.id); continue }
                if tab.kind == .source || tab.kind == .visual {
                    do {
                        _ = try documentSessions.openMarkdown(url) { try String(contentsOf: $0, encoding: .utf8) }
                    } catch { restored.remove(tab.id) }
                }
            }
        }
        let readingURL = restored.allTabs.first(where: { $0.kind == .reading })?.location
        let noteURL = restored.allTabs.first(where: { $0.kind == .source || $0.kind == .visual })?.location
        if let url = readingURL {
            workspaceReadingIdentity = url.standardizedFileURL
            if KindleBookConverter.isSupported(url) {
                beginKindleConversion(url)
            } else if url.pathExtension.lowercased() == "pdf" { openPDF(url) }
            else if url.pathExtension.lowercased() == "epub" || isUnpackedEPUBDirectory(url) {
                pendingEPUBURL = url; pendingConvertedEPUBURL = nil; openEPUBOriginal(editable: false)
            } else if OfficeReadingFormat.supports(url) { openOfficeDocument(url) }
            else if let tab = restored.allTabs.first(where: { $0.kind == .reading }) { restored.remove(tab.id) }
            if pdfSourceURL == nil && epubDocument == nil && officeDocumentURL == nil && !isConvertingKindle && pendingPDFURL == nil {
                for tab in restored.allTabs where tab.kind == .reading { restored.remove(tab.id) }
            }
        }
        if let url = noteURL {
            loadDocument(url, preservingEPUB: epubDocument != nil, preservingPDF: pdfDocument != nil,
                         preservingWeb: webSessions.tabIDs.contains { webSessions.session(for: $0)?.currentURL != nil },
                         preservingOffice: officeDocumentURL != nil)
            if selectedFile?.standardizedFileURL != url.standardizedFileURL {
                for tab in restored.allTabs where tab.kind == .source || tab.kind == .visual { restored.remove(tab.id) }
            }
        }
        workspaceTabs = restored
        workspaceNoteIdentity = selectedFile?.standardizedFileURL
        if !isConvertingKindle && pendingPDFURL == nil {
            workspaceReadingIdentity = (officeDocumentURL ?? pdfSourceURL ?? epubDocument?.sourceURL)?.standardizedFileURL
        }
        if let activeGroup = restored.activeGroup,
           let active = restored.groups.first(where: { $0.id == activeGroup })?.selected,
           let tab = restored.allTabs.first(where: { $0.id == active }) {
            if tab.kind == .web { webSessions.activate(tab.id) }
            selectWorkspaceTab(tab)
        }
    }

    private func performOpenWorkspace(_ url: URL) {
        do {
            let document = try JSONDecoder().decode(WorkspaceDocument.self, from: Data(contentsOf: url))
            guard document.isValid else { throw CocoaError(.fileReadCorruptFile) }
            let missing = document.missingFiles
            if !missing.isEmpty {
                let alert = NSAlert()
                alert.messageText = "部分工作区文件找不到"
                alert.informativeText = "以下位置不可用，本次会跳过；原工作区文件中的引用会保留。若要保存当前状态，请另存为新文件。\n" + missing.map(\.path).joined(separator: "\n")
                alert.addButton(withTitle: "继续打开")
                alert.addButton(withTitle: "取消")
                guard alert.runModal() == .alertFirstButtonReturn else { return }
            }
            workspaceRestorationComplete = false
            detachedWindows.closeAllSilently()
            _ = documentSessions.removeAll(discardingChanges: true)
            clearNoteDocument()
            clearReadingSource()
            for id in webSessions.tabIDs { webSessions.close(id) }
            workspaceTabs = WorkspaceGridLayout()
            workspaceNoteIdentity = nil; workspaceReadingIdentity = nil
            workspaceFolders = document.folders.filter { FileManager.default.fileExists(atPath: $0.path) }
            workspaceFiles = document.files.filter { FileManager.default.fileExists(atPath: $0.path) }
            workspaceReadingNotes = document.readingNotes
            folderURL = workspaceFolders.first
            lastFolderPath = folderURL?.path ?? ""
            workspaceFileURL = url
            currentWorkspacePath = url.path
            workspaceHasMissingReferences = !missing.isEmpty
            sidebarOutlineTab = .files
            restoreWorkspaceGrid(document.layout)
            workspaceRestorationComplete = true
            persistWorkspaceGrid()
        } catch { saveError = "无法打开工作区：\(error.localizedDescription)" }
    }

    private func synchronizeWorkspaceTabs() {
        let note = selectedFile?.standardizedFileURL
        if workspaceNoteIdentity != note {
            workspaceNoteIdentity = note
            if let note {
                _ = documentSessions.adoptMarkdown(note, text: source)
                let existing = workspaceTabs.allTabs.filter { $0.location?.standardizedFileURL == note }
                if let preferred = existing.first(where: { $0.kind == .visual })
                    ?? existing.first(where: { $0.kind == .source }) {
                    workspaceTabs.select(preferred.id)
                } else {
                    let visual = WorkspaceTab(.visual, location: note)
                    workspaceTabs.add(visual)
                    workspaceTabs.select(visual.id)
                }
            }
        }
        let reading = (officeDocumentURL ?? pdfSourceURL ?? epubDocument?.sourceURL)?.standardizedFileURL
        if !isConvertingKindle && pendingPDFURL == nil && workspaceReadingIdentity != reading {
            workspaceReadingIdentity = reading
            if let reading, !workspaceTabs.allTabs.contains(where: { $0.kind == .reading && $0.location?.standardizedFileURL == reading }) {
                workspaceTabs.add(WorkspaceTab(.reading, location: reading))
            }
        }
        for id in webSessions.tabIDs {
            guard let session = webSessions.session(for: id), session.currentURL != nil,
                  !workspaceTabs.allTabs.contains(where: { $0.id == id }) else { continue }
            workspaceTabs.add(WorkspaceTab(.web, id: id))
        }
        if let pending = pendingWorkspaceFileDrop,
           let tab = workspaceTabs.allTabs.first(where: {
               $0.location?.standardizedFileURL == pending.url.standardizedFileURL && ($0.kind == .visual || $0.kind == .reading)
           }) {
            pendingWorkspaceFileDrop = nil
            let target = workspaceTabs.groups.contains(where: { $0.id == pending.group }) ? pending.group : (workspaceTabs.activeGroup ?? workspaceTabs.groups[0].id)
            workspaceTabs.move(tab.id, to: target, edge: pending.edge)
            selectWorkspaceTab(tab)
        }
    }

    private var tabbedWorkspace: some View {
        workspaceNode(workspaceTabs.root).overlay { WorkspaceDragGhost() }
    }

    private func arrangeWorkspace(_ edge: WorkspaceDropEdge) {
        MarkdownVisualCommandHub.commitActiveEdits {
            MarkdownSourcePositionHub.capture()
            let tabs = workspaceTabs.allTabs
            guard !tabs.isEmpty else { return }
            let layout = workspaceTabs.arranged(edge)
            workspaceTabs = layout
            if let selected = layout.groups.first(where: { $0.id == layout.activeGroup })?.selected,
               let tab = tabs.first(where: { $0.id == selected }) { selectWorkspaceTab(tab) }
        }
    }

    private func workspaceNode(_ node: WorkspaceGridLayout.Node) -> AnyView {
        switch node {
        case .group(let group): return AnyView(workspaceGroup(group))
        case .split(let horizontal, let first, let second):
            if horizontal {
                return AnyView(HSplitView { workspaceNode(first).frame(minWidth: 180); workspaceNode(second).frame(minWidth: 180) })
            }
            return AnyView(VSplitView { workspaceNode(first).frame(minHeight: 150); workspaceNode(second).frame(minHeight: 150) })
        }
    }

    private func workspaceGroup(_ group: WorkspaceGridLayout.Group) -> some View {
        WorkspaceTabGroup(group: group, groups: workspaceTabs.groups, allTabs: workspaceTabs.allTabs, title: workspaceTabTitle,
            isDirty: { tab in
                guard (tab.kind == .source || tab.kind == .visual), let url = tab.location else { return false }
                return documentSessions.session(for: url)?.isDirty == true
            },
            select: selectWorkspaceTab, move: moveWorkspaceTab, close: closeWorkspaceTab,
            detach: detachWorkspaceTab,
            addWeb: { groupID in
                MarkdownVisualCommandHub.commitActiveEdits {
                    let id = webSessions.create()
                    workspaceTabs.add(WorkspaceTab(.web, id: id), group: groupID)
                    activateWorkspaceArea(.web)
                }
            }, openFile: { url, groupID, edge in
                if let existing = workspaceTabs.allTabs.first(where: {
                    $0.location?.standardizedFileURL == url.standardizedFileURL && ($0.kind == .visual || $0.kind == .reading)
                }) {
                    moveWorkspaceTab(existing, groupID, edge, nil)
                } else {
                    pendingWorkspaceFileDrop = (url, groupID, edge)
                    workspaceTabs.activeGroup = groupID
                    open(url)
                }
            }) { tab in
                workspaceTabPane(tab)
            }
    }

    private func workspaceTabTitle(_ tab: WorkspaceTab) -> String {
        switch tab.kind {
        case .reading: return "\(tab.location?.deletingPathExtension().lastPathComponent ?? "阅读") · 原文"
        case .web: return webSessions.session(for: tab.id)?.title ?? "网页"
        case .source: return "\(tab.location?.deletingPathExtension().lastPathComponent ?? "Markdown") · 源码"
        case .visual:
            let name = tab.location?.deletingPathExtension().lastPathComponent ?? "可视化笔记"
            let isCompanion = tab.location.map { note in
                workspaceReadingNotes.contains { $0.noteURL.standardizedFileURL == note.standardizedFileURL }
            } ?? false
            return isCompanion ? "\(name) · 笔记" : name
        }
    }

    @ViewBuilder private func workspaceTabPane(_ tab: WorkspaceTab, forceActive: Bool = false) -> some View {
        switch tab.kind {
        case .reading:
            if let url = tab.location {
                let epubKey = url.standardizedFileURL.path
                WorkspaceReadingPane(url: url,
                    isActive: forceActive || workspaceTabs.groups.contains(where: {
                        $0.id == workspaceTabs.activeGroup && $0.selected == tab.id
                    }),
                    width: epubReaderWidth, bodySize: bodySize,
                    bodyFamily: bodyFamily, bodyColorHex: bodyColorHex,
                    annotationFontSize: annotationFontSize, annotationFontFamily: annotationFontFamily,
                    annotationTextColorHex: annotationTextColorHex, backgroundHex: readerBackgroundHex,
                    lineHeight: lineHeight, onActivate: {
                        workspaceTabs.select(tab.id)
                        activateWorkspaceReading(url)
                        activateWorkspaceArea(readingArea(for: url))
                    },
                    onError: { saveError = $0 },
                    epubNavigationTarget: workspaceEPUBNavigationTargets[epubKey],
                    onEPUBLoaded: { document in
                        workspaceEPUBDocuments[epubKey] = document
                        if activeWorkspaceReadingURL?.path == epubKey { epubDocument = document }
                    },
                    onEPUBChapterChanged: { chapter in workspaceEPUBChapters[epubKey] = chapter },
                    chapter: workspaceEPUBChapterBinding(for: url),
                    pdfZoomPercent: $pdfZoomPercent,
                    officeZoomPercent: $officeZoomPercent, currentPDFPage: $pdfCurrentPage,
                    pdfDisplayPresetRequest: pdfDisplayPresetRequest)
            } else { ContentUnavailableView("阅读文件不可用", systemImage: "book.closed") }
        case .web:
            if let session = webSessions.session(for: tab.id) { browserWorkspacePane(session, id: tab.id) }
        case .source, .visual:
            if let url = tab.location, let session = documentSessions.session(for: url) {
                WorkspaceMarkdownPane(session: session,
                    mode: tab.kind == .source ? .source : .visual,
                    isActive: forceActive || workspaceTabs.groups.contains(where: {
                        $0.id == workspaceTabs.activeGroup && $0.selected == tab.id
                    }),
                    appearance: tab.kind == .source ? sourceStyle : previewStyle,
                    syntaxHighlighting: sourceSyntaxHighlighting,
                    onActivate: { session, mode in
                        workspaceTabs.select(tab.id)
                        activateWorkspaceMarkdownSession(session, mode: mode)
                    },
                    onTextChange: synchronizeActiveWorkspaceSession,
                    onOpenLink: openMarkdownReference,
                    onNativeSlashCommand: applyWorkspaceSlashCommand,
                    onDeleteManagedNote: deleteWorkspaceManagedChild,
                    onError: { saveError = $0 })
            } else {
                ContentUnavailableView("文件不可用", systemImage: "doc.questionmark")
            }
        }
    }

    private func workspaceEPUBChapterBinding(for url: URL) -> Binding<Int> {
        let key = url.standardizedFileURL.path
        return Binding(
            get: { workspaceEPUBChapters[key] ?? 0 },
            set: { workspaceEPUBChapters[key] = $0 }
        )
    }

    private func activateWorkspaceMarkdownSession(_ session: WorkspaceMarkdownSession, mode: WorkspaceMarkdownPane.Mode) {
        let needsOutlineRefresh = activeWorkspaceMarkdownURL?.standardizedFileURL != session.url.standardizedFileURL
            || parsedSource != session.text
        activeWorkspaceMarkdownURL = session.url
        selectedFile = session.url
        source = session.text
        savedSource = session.savedText
        editorSelection = session.selection
        visualScrollState = session.position
        sidebarOutlineTab = .markdown
        if needsOutlineRefresh { refreshOutlineImmediately(for: session) }
        activateWorkspaceArea(mode == .source ? .markdownEditor : .markdownPreview)
    }

    private func refreshOutlineImmediately(for session: WorkspaceMarkdownSession) {
        let url = session.url.standardizedFileURL
        let text = session.text
        Task { @MainActor in
            let parsed = await Task.detached(priority: .userInitiated) { MarkdownBlock.parse(text) }.value
            guard activeWorkspaceMarkdownURL?.standardizedFileURL == url,
                  documentSessions.session(for: url)?.text == text else { return }
            blocks = parsed
            parsedSource = text
            headings = parsed.filter { $0.headingLevel != nil }
            expandedHeadings.formIntersection(Set(headings.map(\.id)))
        }
    }

    private func activateWorkspaceReading(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            if pdfSourceURL?.standardizedFileURL != url.standardizedFileURL {
                pdfDocument = PDFDocument(url: url)
                pdfSourceURL = url
            }
            officeDocumentURL = nil
        } else if OfficeReadingFormat.supports(url) {
            officeDocumentURL = url
            pdfDocument = nil
            pdfSourceURL = nil
        } else if ext == "epub" || isUnpackedEPUBDirectory(url) {
            if epubDocument?.sourceURL.standardizedFileURL != url.standardizedFileURL {
                // WorkspaceReadingPane opens EPUBs off the main thread. Reuse
                // that immutable result for the outline instead of parsing the
                // book synchronously whenever focus moves between reading tabs.
                epubDocument = workspaceEPUBDocuments[url.standardizedFileURL.path]
            }
            officeDocumentURL = nil
            pdfDocument = nil
            pdfSourceURL = nil
        }
    }

    private func synchronizeActiveWorkspaceSession(_ session: WorkspaceMarkdownSession) {
        guard activeWorkspaceMarkdownURL?.standardizedFileURL == session.url.standardizedFileURL else { return }
        if source != session.text { source = session.text }
        savedSource = session.savedText
        editorSelection = session.selection
    }

    private func applyWorkspaceSlashCommand(_ session: WorkspaceMarkdownSession, _ command: String, _ token: String?) {
        activateWorkspaceMarkdownSession(session, mode: .visual)
        if command == "table" { pendingTableSessionURL = session.url }
        applySlashCommand(command, anchorToken: token)
        if command == "page" || command == "table" { return }
        session.text = source
        session.selection = editorSelection
    }

    private func deleteWorkspaceManagedChild(_ session: WorkspaceMarkdownSession, _ child: URL) {
        activateWorkspaceMarkdownSession(session, mode: .visual)
        deleteManagedChild(child)
        session.text = source
        session.selection = editorSelection
    }

    private func selectWorkspaceTab(_ tab: WorkspaceTab) {
        MarkdownVisualCommandHub.commitActiveEdits {
            MarkdownSourcePositionHub.capture()
            let wasVisible = workspaceTabs.groups.contains { $0.selected == tab.id }
            let previousArea = focusedWorkspaceArea
            workspaceTabs.select(tab.id)
            switch tab.kind {
            case .web: webSessions.activate(tab.id); activateWorkspaceArea(.web)
            case .source:
                if let url = tab.location, let session = documentSessions.session(for: url) {
                    activateWorkspaceMarkdownSession(session, mode: .source)
                }
                if !wasVisible && [.markdownPreview, .markdownReader].contains(previousArea) {
                    if let selection = visualScrollState.selection { editorSelection = selection }
                    else if let viewport = visualScrollState.viewport { editorSelection = NSRange(location: viewport.sourceOffset, length: 0) }
                    sourcePositionRestoreRequest += 1
                }
                visualScrollState.activeMode = .source; activateWorkspaceArea(.markdownEditor)
            case .visual:
                if let url = tab.location, let session = documentSessions.session(for: url) {
                    activateWorkspaceMarkdownSession(session, mode: .visual)
                }
                if !wasVisible && previousArea == .markdownEditor { visualRestoreRequest += 1 }
                visualScrollState.activeMode = .visual; activateWorkspaceArea(.markdownPreview)
            case .reading:
                if let url = tab.location { activateWorkspaceReading(url) }
                if officeDocumentURL != nil { activateWorkspaceArea(.office) }
                else if pdfDocument != nil { activateWorkspaceArea(.pdf) }
                else { activateWorkspaceArea(.epub) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                guard workspaceTabs.groups.contains(where: { $0.id == workspaceTabs.activeGroup && $0.selected == tab.id }) else { return }
                switch tab.kind {
                case .source:
                    if let view = MarkdownSourcePositionHub.coordinator?.textView { view.window?.makeFirstResponder(view) }
                case .visual: MarkdownVisualCommandHub.focusActiveEditor()
                case .web:
                    if let view = webSessions.session(for: tab.id)?.webView { view.window?.makeFirstResponder(view) }
                case .reading: focusReadingAfterLayout()
                }
            }
        }
    }

    private func moveWorkspaceTab(_ tab: WorkspaceTab, _ group: UUID, _ edge: WorkspaceDropEdge, _ index: Int?) {
        MarkdownVisualCommandHub.commitActiveEdits {
            MarkdownSourcePositionHub.capture()
            if !workspaceTabs.allTabs.contains(where: { $0.id == tab.id }), let detached = detachedWindows.take(tab.id) {
                workspaceTabs.add(detached, group: group, index: index)
                if edge != .center { workspaceTabs.move(detached.id, to: group, edge: edge) }
            } else {
                workspaceTabs.move(tab.id, to: group, edge: edge, index: index)
            }
            selectWorkspaceTab(tab)
        }
    }

    private func detachWorkspaceTab(_ tab: WorkspaceTab, _ point: CGPoint) {
        guard workspaceTabs.allTabs.contains(where: { $0.id == tab.id }) else { return }
        let content = AnyView(workspaceTabPane(tab, forceActive: true))
        workspaceTabs.remove(tab.id)
        let screenPoint = NSEvent.mouseLocation
        detachedWindows.open(tab: tab, title: workspaceTabTitle(tab), content: content, near: screenPoint,
            onDock: { restored in
                workspaceTabs.add(restored)
                selectWorkspaceTab(restored)
            }, onClose: { closing in
                workspaceTabs.add(closing)
                closeWorkspaceTab(closing)
            })
    }

    private func closeWorkspaceTab(_ tab: WorkspaceTab) {
        MarkdownVisualCommandHub.commitActiveEdits {
            MarkdownSourcePositionHub.capture()
            switch tab.kind {
            case .web:
                webSessions.close(tab.id)
                workspaceTabs.remove(tab.id)
            case .reading:
                workspaceTabs.remove(tab.id)
                if tab.location?.standardizedFileURL == (officeDocumentURL ?? pdfSourceURL ?? epubDocument?.sourceURL)?.standardizedFileURL {
                    clearReadingSource()
                }
            case .source, .visual:
                guard let url = tab.location else { workspaceTabs.remove(tab.id); return }
                let siblingViews = workspaceTabs.allTabs.filter {
                    ($0.kind == .source || $0.kind == .visual) && $0.id != tab.id &&
                    $0.location?.standardizedFileURL == url.standardizedFileURL
                }
                if !siblingViews.isEmpty { workspaceTabs.remove(tab.id); return }
                guard let session = documentSessions.session(for: url) else { workspaceTabs.remove(tab.id); return }
                activateWorkspaceMarkdownSession(session, mode: tab.kind == .source ? .source : .visual)
                if session.isDirty {
                    pendingDocumentOperation = .closeWorkspaceTab(tab.id)
                    showUnsavedAlert = true
                } else {
                    finishClosingWorkspaceTab(tab.id, discard: false)
                }
            }
        }
    }

    private func finishClosingWorkspaceTab(_ id: UUID, discard: Bool) {
        guard let tab = workspaceTabs.allTabs.first(where: { $0.id == id }) else { return }
        workspaceTabs.remove(id)
        if let url = tab.location,
           !workspaceTabs.allTabs.contains(where: { ($0.kind == .source || $0.kind == .visual) && $0.location?.standardizedFileURL == url.standardizedFileURL }) {
            _ = documentSessions.removeMarkdown(url, discardingChanges: discard)
            if activeWorkspaceMarkdownURL?.standardizedFileURL == url.standardizedFileURL {
                if let next = workspaceTabs.allTabs.first(where: { $0.kind == .source || $0.kind == .visual }) { selectWorkspaceTab(next) }
                else { clearNoteDocument(); activeWorkspaceMarkdownURL = nil }
            }
        }
    }

    private func browserWorkspacePane(_ session: WebBrowserSession, id: UUID) -> some View {
        WebBrowserPane(session: session, zoomPercent: webZoomPercent,
            isBookmarked: webBookmarks.contains(where: { $0.urlString == session.currentURL?.absoluteString }),
            onBookmark: { webSessions.activate(id); beginBookmarkCurrentPage() },
            onClip: { clip in webSessions.activate(id); appendWebClip(clip) },
            onActivate: {
                workspaceTabs.select(id)
                webSessions.activate(id)
                activateWorkspaceArea(.web)
            })
    }

    private var parallelDocumentPane: some View {
        Group {
            if let officeDocumentURL {
                switch epubNotebookLayout {
                case .epub: officeReadingPane(officeDocumentURL)
                case .notes: markdownWorkspacePane
                case .stacked:
                    officeNotebookWorkspace(officeDocumentURL)
                }
            } else
            if let webURL = webBrowser.currentURL {
                switch epubNotebookLayout {
                case .epub:
                    webReaderPane(webURL)
                case .notes:
                    markdownWorkspacePane
                case .stacked:
                    webNotebookWorkspace(webURL)
                }
            } else if let pdfDocument {
                switch epubNotebookLayout {
                case .epub:
                    pdfReaderPane(pdfDocument)
                case .notes:
                    markdownWorkspacePane
                case .stacked:
                    pdfNotebookWorkspace(pdfDocument)
                }
            } else if let epubDocument, epubDocument.chapters.indices.contains(epubCurrentChapter), isEPUBNotebook {
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
    }

    private func pdfReaderPane(_ document: PDFDocument) -> some View {
        PDFReaderView(document: document, zoomPercent: $pdfZoomPercent,
                      currentPageIndex: $pdfCurrentPage,
                      readingPosition: $pdfReadingPosition,
                      documentID: pdfSourceURL?.standardizedFileURL.path ?? document.documentURL?.standardizedFileURL.path ?? "",
                      navigationRequest: pdfNavigationRequest,
                      displayPresetRequest: pdfDisplayPresetRequest,
                      isReadingProfileLoading: pdfProfileLoading,
                      backgroundColor: Color(hex: readerBackgroundHex),
                      onActivate: { activateWorkspaceArea(.pdf) })
            .background(Color(hex: readerBackgroundHex))
            .overlay { workspaceFocusRing(focusedWorkspaceArea == .pdf) }
            .overlay(alignment: .trailing) { pdfPositionMarkers(document) }
            .shadow(color: focusedWorkspaceArea == .pdf ? Color.gray.opacity(0.045) : .clear, radius: 2)
            .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.pdf) } }
    }

    private func webReaderPane(_ url: URL) -> some View {
        WebBrowserPane(session: webBrowser, zoomPercent: webZoomPercent,
                       isBookmarked: webBookmarks.contains(where: { $0.urlString == url.absoluteString }),
                       onBookmark: beginBookmarkCurrentPage, onClip: appendWebClip,
                       onActivate: { activateWorkspaceArea(.web) })
            .overlay { workspaceFocusRing(focusedWorkspaceArea == .web).padding(.top, 35) }
            .shadow(color: focusedWorkspaceArea == .web ? Color.gray.opacity(0.045) : .clear, radius: 2)
            .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.web) } }
    }

    @ViewBuilder
    private func officeNotebookWorkspace(_ url: URL) -> some View {
        switch maximizedNotebookPane {
        case .epub: officeReadingPane(url)
        case .preview: notebookPreviewPane
        case .editor: notebookEditorPane
        case nil, .rightPreview, .rightEditor:
            notebookSplitWorkspace(primary: { AnyView(officeReadingPane(url)) },
                                   notes: { AnyView(pdfNotebookNotesPane) })
        }
    }

    @ViewBuilder
    private func webNotebookWorkspace(_ url: URL) -> some View {
        switch maximizedNotebookPane {
        case .epub:
            webReaderPane(url)
        case .preview:
            notebookPreviewPane
        case .editor:
            notebookEditorPane
        case nil, .rightPreview, .rightEditor:
            notebookSplitWorkspace(primary: { AnyView(webReaderPane(url)) }, notes: { AnyView(pdfNotebookNotesPane) })
        }
    }

    @ViewBuilder
    private func pdfNotebookWorkspace(_ document: PDFDocument) -> some View {
        switch maximizedNotebookPane {
        case .epub:
            notebookPDFPane(document)
        case .preview:
            notebookPreviewPane
        case .editor:
            notebookEditorPane
        case nil, .rightPreview, .rightEditor:
            // Keep the PDF view in this stable split while only the right notes pane changes.
            notebookSplitWorkspace(primary: { AnyView(notebookPDFPane(document)) }, notes: { AnyView(pdfNotebookNotesPane) })
        }
    }

    @ViewBuilder
    private var pdfNotebookNotesPane: some View {
        switch maximizedNotebookPane {
        case .rightPreview:
            notebookPreviewPane
        case .rightEditor:
            notebookEditorPane
        default:
            notebookPreviewPane
        }
    }

    private func notebookSplitWorkspace(
        primary: @escaping () -> AnyView,
        notes: @escaping () -> AnyView
    ) -> some View {
        GeometryReader { geometry in
            NotebookSplitView(
                primary: primary(),
                notes: notes(),
                rightPaneWidth: CGFloat(notebookRightPaneWidth),
                minimumPrimaryWidth: 260,
                minimumNotesWidth: 320,
                onRightPaneWidthChange: scheduleWorkspaceWidthSave
            )
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var notebookVerticalSplitPane: some View {
        GeometryReader { geometry in
            let availableHeight = max(0, geometry.size.height - 6)
            VSplitView {
                notebookPreviewPane
                    .frame(minHeight: 160, idealHeight: max(160, availableHeight * notebookVerticalRatio))
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: WorkspacePaneHeightPreferenceKey.self, value: proxy.size.height)
                    })
                notebookEditorPane
                    .frame(minHeight: 160)
            }
            .onPreferenceChange(WorkspacePaneHeightPreferenceKey.self) { topHeight in
                scheduleWorkspaceHeightSave(topHeight, availableHeight: availableHeight)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func notebookPDFPane(_ document: PDFDocument) -> some View {
        VStack(spacing: 0) {
            notebookPaneHeader(.epub, titleOverride: "PDF 阅读")
            pdfReaderPane(document)
        }
    }

    @ViewBuilder
    private func epubNotebookWorkspace(_ document: EPUBPackageDocument) -> some View {
        switch maximizedNotebookPane {
            case .epub:
                notebookEPUBPane(document)
            case .preview:
                notebookPreviewPane
            case .editor:
                notebookEditorPane
            case nil, .rightPreview, .rightEditor:
                notebookSplitWorkspace(primary: { AnyView(notebookEPUBPane(document)) }, notes: { AnyView(pdfNotebookNotesPane) })
        }
    }

    private func notebookEPUBPane(_ document: EPUBPackageDocument) -> some View {
        VStack(spacing: 0) {
            notebookPaneHeader(.epub)
            epubChapterPane(document, editable: false)
        }
        .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.epub) } }
    }

    private var notebookPreviewPane: some View {
        VStack(spacing: 0) {
            notebookPaneHeader(.preview)
            readingPane(focusArea: .markdownPreview)
        }
        .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.markdownPreview) } }
    }

    private var notebookEditorPane: some View {
        VStack(spacing: 0) {
            notebookPaneHeader(.editor)
            editorPane
        }
        .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.markdownEditor) } }
    }

    private func notebookPaneHeader(_ pane: EPUBNotebookPane, titleOverride: String? = nil) -> some View {
        HStack(spacing: 6) {
            if pane != .epub { noteNavigationButtons }
            Text(titleOverride ?? pane.title).font(.system(size: 11, weight: .medium))
            Spacer()
            Button {
                cycleNotebookExpansion(for: pane)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: maximizedNotebookPane == pane ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .medium))
                    Text(notebookExpansionTitle(for: pane))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 7)
                .frame(height: 21)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
                .overlay { RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.12)) }
            }
            .buttonStyle(.plain)
            .help(notebookExpansionHelp(for: pane))
            .toolbarHint(notebookExpansionHelp(for: pane))
            .accessibilityLabel(notebookExpansionHelp(for: pane))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.78))
        .overlay(alignment: .bottom) { Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1) }
    }

    private func cycleNotebookExpansion(for pane: EPUBNotebookPane) {
        MarkdownVisualCommandHub.commitActiveEdits {
            MarkdownSourcePositionHub.capture()
            guard saveMarkdownBeforeModeSwitch() else { return }
            applyNotebookExpansion(for: pane)
            switch pane {
            case .epub: activateReadingArea()
            case .preview, .rightPreview: activateWorkspaceArea(.markdownPreview)
            case .editor, .rightEditor: activateWorkspaceArea(.markdownEditor)
            }
            visualRestoreRequest += 1
            sourcePositionRestoreRequest += 1
        }
    }

    private func applyNotebookExpansion(for pane: EPUBNotebookPane) {
        switch pane {
        case .epub:
            maximizedNotebookPane = maximizedNotebookPane == .epub ? nil : .epub
        case .preview:
            switch maximizedNotebookPane {
            case nil: maximizedNotebookPane = .preview
            case .rightPreview: maximizedNotebookPane = .preview
            case .preview: maximizedNotebookPane = nil
            default: maximizedNotebookPane = .preview
            }
        case .editor:
            switch maximizedNotebookPane {
            case nil: maximizedNotebookPane = .editor
            case .rightEditor: maximizedNotebookPane = .editor
            case .editor: maximizedNotebookPane = .rightEditor
            default: maximizedNotebookPane = .editor
            }
        case .rightPreview, .rightEditor:
            break
        }
    }

    private func notebookExpansionHelp(for pane: EPUBNotebookPane) -> String {
        switch (pane, maximizedNotebookPane) {
        case (.epub, .epub): "恢复三栏布局"
        case (.epub, _) where pdfDocument != nil: "最大化 PDF 阅读区"
        case (.epub, _): "最大化 EPUB 原书"
        case (.preview, .preview): "恢复三栏布局"
        case (.preview, _): "将可视化笔记最大化到整个工作区"
        case (.editor, .editor): "恢复三栏布局"
        case (.editor, _): "将笔记编辑最大化到整个工作区"
        case (.rightPreview, _): "让笔记预览占满右侧"
        case (.rightEditor, _): "让笔记编辑占满右侧"
        }
    }

    private func notebookExpansionTitle(for pane: EPUBNotebookPane) -> String {
        switch (pane, maximizedNotebookPane) {
        case (.epub, .epub), (.preview, .preview), (.editor, .editor): "还原"
        case (.preview, .rightPreview), (.editor, .rightEditor): "满屏"
        case (.epub, _): "满屏"
        case (.preview, _), (.editor, _): "满屏"
        case (.rightPreview, _), (.rightEditor, _): "占满右侧"
        }
    }

    private var markdownWorkspacePane: some View {
        Group {
            switch displayMode {
            case .read:
                VStack(spacing: 0) { notebookPaneHeader(.preview); readingPane() }
            case .edit:
                editorPane
            case .split:
                NotebookSplitView(primary: AnyView(VStack(spacing: 0) { notebookPaneHeader(.preview); readingPane() }), notes: AnyView(editorPane),
                    rightPaneWidth: CGFloat(markdownPreviewPaneWidth), minimumPrimaryWidth: 260,
                    minimumNotesWidth: 300, onRightPaneWidthChange: { markdownPreviewPaneWidth = Double($0) })
            }
        }
    }

    private func epubChapterPane(_ document: EPUBPackageDocument, editable: Bool) -> some View {
        EPUBChapterView(chapter: document.chapters[epubCurrentChapter], resourceRoot: document.workingDirectory,
                        editable: editable, width: epubReaderWidth,
                        bodySize: bodySize, bodyFamily: bodyFamily, bodyColorHex: bodyColorHex,
                        annotationFontSize: annotationFontSize, annotationFontFamily: annotationFontFamily,
                        annotationTextColorHex: annotationTextColorHex,
                        backgroundColorHex: readerBackgroundHex,
                        lineHeight: lineHeight,
                        scrollFragment: epubTargetFragment, scrollRequest: epubNavigationRequest,
                        annotations: epubAnnotations, annotationJumpID: epubAnnotationJumpID,
                        annotationJumpRequest: epubAnnotationJumpRequest,
                        savedPosition: savedEPUBPosition,
                        positionRestoreRequest: epubPositionRestoreRequest,
                        onActivate: { activateWorkspaceArea(.epub) },
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
            activeSheet = .epubAnnotationComposer
        }, onDeleteAnnotation: { id in
            guard let annotation = epubAnnotations.first(where: { $0.id == id }) else { return }
            deleteEPUBAnnotation(annotation)
        }, onReadPosition: { href, fraction in
            savedEPUBPosition = SavedReadingPosition(location: .epub(chapterHref: href, fraction: fraction))
        }) { body in
            do {
                try document.replaceChapterBody(at: epubCurrentChapter, with: body)
                epubHasChanges = true
            } catch {
                saveError = error.localizedDescription
            }
        }
        .background(Color(hex: readerBackgroundHex))
        .overlay { workspaceFocusRing(focusedWorkspaceArea == .epub) }
        .overlay(alignment: .trailing) { epubPositionMarkers(document) }
        .shadow(color: focusedWorkspaceArea == .epub ? Color.gray.opacity(0.045) : .clear, radius: 2)
        .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.epub) } }
    }

    private var activeBookURL: URL? { pdfSourceURL ?? epubDocument?.sourceURL }

    private func beginLoadingReadingProfile(for url: URL, sourceKind: ReadingSourceKind, title: String) {
        identityLoadTask?.cancel()
        readingProfileLoadRevision += 1
        let loadRevision = readingProfileLoadRevision
        currentBookID = nil
        currentBookProfile = nil
        savedEPUBPosition = nil
        epubAnnotations = []
        let initialStyle = readingStyleSettings
        let initialPDFNavigationRequest = pdfNavigationRequest
        if sourceKind == .pdf { pdfProfileLoading = true }
        let initialEPUBNavigationRequest = epubNavigationRequest
        let initialEPUBChapter = epubCurrentChapter
        let initialEPUBPosition = savedEPUBPosition
        identityLoadTask = Task { @MainActor in
            defer {
                if sourceKind == .pdf, readingProfileLoadRevision == loadRevision,
                   activeBookURL?.standardizedFileURL == url.standardizedFileURL {
                    pdfProfileLoading = false
                }
            }
            do {
                let identity = try await Task.detached(priority: .utility) {
                    try ReadingDocumentIdentity.make(for: url)
                }.value
                guard !Task.isCancelled, readingProfileLoadRevision == loadRevision,
                      activeBookURL?.standardizedFileURL == url.standardizedFileURL else { return }
                let profile = try readingLibrary.loadProfile(documentID: identity)
                    ?? BookReadingProfile(documentID: identity, title: title, sourceKind: sourceKind)
                currentBookID = identity
                currentBookProfile = profile

                if let style = profile.style {
                    if readingStyleSettings == initialStyle { applyReadingStyle(style) }
                    else { persistReadingProfile(style: readingStyleSettings) }
                }
                if let position = profile.position {
                    switch (sourceKind, position.location) {
                    case (.pdf, .pdf(let pageIndex, let x, let y)):
                        // PDFKit reports page 1 while its view is being laid out. That is not
                        // a user navigation and must not suppress the saved location.
                        guard pdfNavigationRequest == initialPDFNavigationRequest else { break }
                        let safeIndex = min(max(0, pageIndex), max(0, (pdfDocument?.pageCount ?? 1) - 1))
                        pdfCurrentPage = safeIndex
                        pdfReadingPosition = PDFReadingPosition(
                            documentID: pdfSourceURL?.standardizedFileURL.path ?? url.standardizedFileURL.path,
                            pageIndex: safeIndex, x: CGFloat(x), y: CGFloat(y))
                    case (.epub, .epub(let chapterHref, _)):
                        guard epubNavigationRequest == initialEPUBNavigationRequest,
                              epubCurrentChapter == initialEPUBChapter, savedEPUBPosition == initialEPUBPosition else { break }
                        if let index = epubDocument?.chapters.firstIndex(where: { $0.href == chapterHref }) {
                            savedEPUBPosition = position
                            epubCurrentChapter = index
                            epubNavigationRequest += 1
                            epubPositionRestoreRequest += 1
                        }
                    default: break
                    }
                }

                if sourceKind == .epub {
                    let annotations = try readingLibrary.loadAnnotations(
                        documentID: identity, migratingLegacySidecarAt: url)
                    epubAnnotations = annotations
                    epubSelection = nil
                    epubAnnotationJumpID = nil
                    epubAnnotationJumpRequest += 1
                }
            } catch {
                if activeBookURL?.standardizedFileURL == url.standardizedFileURL {
                    saveError = "无法加载此书的阅读资料：\(error.localizedDescription)"
                }
            }
        }
    }

    private func applyReadingStyle(_ style: ReadingStyleSettings) {
        readerWidth = style.readerWidth
        epubReaderWidth = style.epubReaderWidth
        bodySize = style.bodySize
        outlineFontScale = style.outlineFontScale
        bodyFamily = style.bodyFamily
        bodyColorHex = style.bodyColorHex
        readerBackgroundHex = style.readerBackgroundHex
        lineHeight = style.lineHeight
        paragraphSpacing = style.paragraphSpacing
        strongColorHex = style.strongColorHex
        strongSize = style.strongSize
        strongFamily = style.strongFamily
        annotationFontSize = style.annotationFontSize
        annotationFontFamily = style.annotationFontFamily
        annotationTextColorHex = style.annotationTextColorHex
        if !style.headingStylesJSON.isEmpty { headingStylesData = Data(style.headingStylesJSON.utf8) }
        if !style.outlineColorsJSON.isEmpty { outlineColorsData = Data(style.outlineColorsJSON.utf8) }
        pdfZoomPercent = style.pdfZoomPercent
    }

    private func persistReadingProfile(style: ReadingStyleSettings? = nil, position: SavedReadingPosition? = nil) {
        guard let id = currentBookID, var profile = currentBookProfile, profile.documentID == id else { return }
        do {
            if let style {
                profile.style = style
                profile.styleUpdatedAt = Date()
                try readingLibrary.saveStyle(style, in: profile)
            }
            if let position {
                profile.position = position
                try readingLibrary.savePosition(position, in: profile)
            }
            currentBookProfile = profile
        } catch {
            saveError = "无法保存阅读资料：\(error.localizedDescription)"
        }
    }

    private func clearReadingProfileSelection() {
        flushCurrentReadingProfile()
        identityLoadTask?.cancel()
        readingProfileLoadRevision += 1
        identityLoadTask = nil
        currentBookID = nil
        currentBookProfile = nil
        pdfProfileLoading = false
        savedEPUBPosition = nil
        epubAnnotations = []
    }

    private var currentSavedPosition: SavedReadingPosition? {
        if !pdfProfileLoading, let position = pdfReadingPosition {
            return SavedReadingPosition(location: .pdf(pageIndex: position.pageIndex,
                                                       x: Double(position.x), y: Double(position.y)))
        }
        return savedEPUBPosition
    }

    private func flushCurrentReadingProfile() {
        guard activeBookURL != nil else { return }
        if let id = currentBookID, let profile = currentBookProfile, id == profile.documentID {
            do {
                try readingLibrary.saveStyle(readingStyleSettings, in: profile)
                if let position = currentSavedPosition { try readingLibrary.savePosition(position, in: profile) }
            } catch { saveError = "无法保存阅读资料：\(error.localizedDescription)" }
        } else {
            Task { @MainActor in await flushCurrentReadingProfileAsync() }
        }
    }

    private func flushCurrentReadingProfileAsync() async {
        guard let url = activeBookURL else { return }
        let kind: ReadingSourceKind = pdfDocument == nil ? .epub : .pdf
        let title = documentTitle
        let style = readingStyleSettings
        let position = currentSavedPosition
        do {
            let id = try await Task.detached(priority: .utility) {
                try ReadingDocumentIdentity.make(for: url)
            }.value
            let profile = try readingLibrary.loadProfile(documentID: id)
                ?? BookReadingProfile(documentID: id, title: title, sourceKind: kind)
            try readingLibrary.saveStyle(style, in: profile)
            if let position { try readingLibrary.savePosition(position, in: profile) }
        } catch {
            saveError = "无法保存阅读资料：\(error.localizedDescription)"
        }
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
            guard let currentBookID else { throw ReadingLibraryError.invalidData }
            try readingLibrary.saveAnnotations(updated, documentID: currentBookID)
            epubAnnotations = updated
            epubSelection = nil
            epubEditingAnnotation = nil
        } catch {
            saveError = "无法保存注释：\(error.localizedDescription)"
        }
    }

    private func deleteEPUBAnnotation(_ annotation: EPUBAnnotation) {
        guard epubDocument != nil else { return }
        let updated = epubAnnotations.filter { $0.id != annotation.id }
        do {
            guard let currentBookID else { throw ReadingLibraryError.invalidData }
            try readingLibrary.saveAnnotations(updated, documentID: currentBookID)
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
        let appearance = sourceStyle
        return VStack(spacing: 0) {
            if workspaceTabs.allTabs.isEmpty && !((hasNotebookReadingSource) && epubNotebookLayout == .stacked) {
            HStack(spacing: 7) {
                noteNavigationButtons
                Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 11))
                Text((hasNotebookReadingSource) ? "Markdown 笔记" : "Markdown 源码")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                if isDirty { Text("未保存").font(.system(size: 10)).foregroundStyle(.secondary) }
            }
            .foregroundStyle(.secondary).padding(.horizontal, 16).frame(height: 34)
            Divider()
            }
            MarkdownSourceEditor(text: $source,
                                 selection: Binding(get: { editorSelectionStorage.range },
                                                    set: { editorSelectionStorage.range = $0 }),
                                 fontSize: CGFloat(max(12, appearance.bodySize)),
                                 fontFamily: appearance.bodyFamily,
                                 lineHeight: CGFloat(appearance.lineHeight),
                                 paragraphSpacing: CGFloat(appearance.paragraphSpacing),
                                 backgroundHex: appearance.backgroundHex,
                                 headingStyles: (try? JSONDecoder().decode([HeadingStyle].self, from: appearance.headingStylesData)) ?? HeadingStyle.defaults,
                                 bodyColorHex: appearance.bodyColorHex,
                                 strongColorHex: appearance.strongColorHex,
                                 syntaxHighlightingEnabled: sourceSyntaxHighlighting,
                                 sourceLineTarget: synchronizedSourceLine,
                                 sourceLineRequest: sourceLineRequest,
                                 focusRequest: editorFocusRequest,
                                 onSourceLineChange: synchronizeSourceLineFromSource,
                                 onActivate: { activateWorkspaceArea(.markdownEditor) },
                                 onImagePaste: pasteImage,
                                 positionState: visualScrollState,
                                 positionRestoreRequest: sourcePositionRestoreRequest)
                .background(Color(hex: appearance.backgroundHex))
                .disabled(selectedFile == nil)
                .overlay {
                    if selectedFile == nil {
                        VStack(spacing: 10) {
                            Text("打开或新建 Markdown 笔记")
                                .font(.system(size: 13)).foregroundStyle(.tertiary)
                            Button("新建 Markdown 笔记") { createMarkdownNote() }
                                .buttonStyle(.bordered)
                        }
                    }
                }
        }
        .background(Color(hex: appearance.backgroundHex))
        .frame(maxWidth: appearance.readerWidth + 76)
        .frame(maxWidth: .infinity)
        .overlay {
            workspaceFocusRing(focusedWorkspaceArea == .markdownEditor)
                .padding(.top, ((hasNotebookReadingSource)
                                && epubNotebookLayout == .stacked) ? 0 : 35)
        }
        .overlay(alignment: .trailing) {
            if selectedFile != nil {
                WorkspacePositionMarkers(markers: markdownPositionMarkers(visual: false)) { id in
                    jumpTo(id)
                    activateWorkspaceArea(.markdownEditor)
                }
            }
        }
        .shadow(color: focusedWorkspaceArea == .markdownEditor ? Color.gray.opacity(0.045) : .clear, radius: 2)
        .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.markdownEditor) } }
    }

    private var isDirty: Bool { source != savedSource || !documentSessions.dirtySessions.isEmpty || epubHasChanges }

    private var topHeadings: [MarkdownBlock] { headings.filter { $0.parentID == nil } }

    private func markdownPositionMarkers(visual: Bool) -> [WorkspacePositionMarker] {
        guard !headings.isEmpty else { return [] }
        let lineCount = max(1, source.reduce(1) { $1 == "\n" ? $0 + 1 : $0 })
        let currentID = headings.last(where: { $0.sourceLine <= synchronizedSourceLine })?.id
        return headings.compactMap { heading in
            guard let index = blocks.firstIndex(where: { $0.id == heading.id }) else { return nil }
            let fraction = visual ? Double(index) / Double(max(1, blocks.count - 1))
                : Double(max(0, heading.sourceLine - 1)) / Double(max(1, lineCount - 1))
            return WorkspacePositionMarker(id: heading.id, fraction: fraction,
                                           title: heading.title ?? "标题", current: heading.id == currentID)
        }
    }

    private func pdfPositionMarkers(_ document: PDFDocument) -> some View {
        func flatten(_ items: [PDFBookmarkItem]) -> [PDFBookmarkItem] {
            items.flatMap { [$0] + flatten($0.children ?? []) }
        }
        let items = flatten(document.markdownStudioBookmarks).filter { $0.pageIndex != nil }
        let markers = items.map { item in
            let page = item.pageIndex ?? 0
            return WorkspacePositionMarker(id: String(page),
                fraction: Double(page) / Double(max(1, document.pageCount - 1)),
                title: "\(item.title) · 第 \(page + 1) 页", current: page == pdfCurrentPage)
        }
        return WorkspacePositionMarkers(markers: markers) { page in
            if let value = Int(page) { navigatePDF(to: value); activateWorkspaceArea(.pdf) }
        }
    }

    private func epubPositionMarkers(_ document: EPUBPackageDocument) -> some View {
        var seen = Set<Int>()
        let markers = document.tableOfContents.compactMap { item -> WorkspacePositionMarker? in
            guard let target = document.navigationTarget(for: item), seen.insert(target.chapterIndex).inserted else { return nil }
            return WorkspacePositionMarker(id: String(target.chapterIndex),
                fraction: Double(target.chapterIndex) / Double(max(1, document.chapters.count - 1)),
                title: item.title, current: target.chapterIndex == epubCurrentChapter)
        }
        return WorkspacePositionMarkers(markers: markers) { chapter in
            guard let value = Int(chapter), document.chapters.indices.contains(value) else { return }
            epubCurrentChapter = value
            epubTargetFragment = nil
            epubNavigationRequest += 1
            activateWorkspaceArea(.epub)
        }
    }

    private func jumpTo(_ id: String) {
        activateWorkspaceArea(.outline)
        scrollTarget = id
        scrollRequest += 1
        if let heading = headings.first(where: { $0.id == id }) {
            synchronizedSourceLine = heading.sourceLine
            sourceLineRequest += 1
            visualSourceLineRequest += 1
        }
    }
    private func synchronizeSourceLineFromVisual(_ line: Int) {
        guard line > 0, line != synchronizedSourceLine else { return }
        synchronizedSourceLine = line
        sourceLineRequest += 1
    }

    private func synchronizeSourceLineFromSource(_ line: Int) {
        guard line > 0, line != synchronizedSourceLine else { return }
        synchronizedSourceLine = line
        visualSourceLineRequest += 1
    }

    private func insertTable(cells: [[String]], formatted: Bool) {
        if let url = pendingTableSessionURL, let session = documentSessions.session(for: url) {
            activateWorkspaceMarkdownSession(session, mode: .visual)
            pendingTableSessionURL = nil
        }
        if let data = try? JSONSerialization.data(withJSONObject: cells),
           let json = String(data: data, encoding: .utf8),
           applyVisualCommand("table", value: json) { return }
        guard selectedFile != nil, canEditMarkdownSource else { return }
        MarkdownSourcePositionHub.flushPendingChanges()
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
        visualSourceLineRequest += 1
        focusEditorAfterTableInsert = true
        if let url = activeWorkspaceMarkdownURL, let session = documentSessions.session(for: url) {
            session.text = source
            session.selection = editorSelection
        }
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

    private var recentWorkspaces: [RecentWorkspace] {
        RecentWorkspaceHistory.decode(recentWorkspacesData)
    }

    private func recordRecentWorkspace() {
        guard !suppressRecentRecording else { return }
        let workspace = RecentWorkspace(readingURL: activeReadingURL, noteURL: selectedFile)
        guard workspace.readingPath != nil || workspace.notePath != nil else { return }
        let updated = RecentWorkspaceHistory.record(workspace, in: recentWorkspaces)
        if let data = try? JSONEncoder().encode(updated) { recentWorkspacesData = data }
    }

    private func openRecentWorkspace(_ workspace: RecentWorkspace) {
        MarkdownVisualCommandHub.commitActiveEdits {
            for url in [workspace.readingURL, workspace.noteURL].compactMap({ $0 }) {
                guard FileManager.default.fileExists(atPath: url.path) else {
                    saveError = "最近使用的文件已不存在：\(url.lastPathComponent)"
                    return
                }
            }
            if let noteURL = workspace.noteURL {
                do { _ = try documentStore.openDocument(at: noteURL) }
                catch {
                    saveError = "无法读取最近使用的笔记：\(noteURL.lastPathComponent)（\(error.localizedDescription)）"
                    return
                }
            }
            if isDirty {
                pendingDocumentOperation = .openRecentWorkspace(workspace)
                showUnsavedAlert = true
            } else {
                performOpenRecentWorkspace(workspace)
            }
        }
    }

    private func performOpenRecentWorkspace(_ workspace: RecentWorkspace) {
        kindleConversionTask?.cancel()
        kindleConversionTask = nil
        kindleConversionRevision += 1
        isConvertingKindle = false
        pendingRecentWorkspace = nil
        guard let readingURL = workspace.readingURL else {
            suppressRecentRecording = true
            clearReadingSource()
            restoreRecentNote(workspace.noteURL)
            suppressRecentRecording = false
            recordRecentWorkspace()
            return
        }
        if OfficeReadingFormat.supports(readingURL) {
            suppressRecentRecording = true
            openOfficeDocument(readingURL)
            if officeDocumentURL?.standardizedFileURL == readingURL.standardizedFileURL {
                restoreRecentNote(workspace.noteURL)
            }
            suppressRecentRecording = false
            recordRecentWorkspace()
            return
        }
        if KindleBookConverter.isSupported(readingURL) {
            pendingRecentWorkspace = workspace
            beginKindleConversion(readingURL)
            return
        }
        if readingURL.pathExtension.lowercased() == "pdf" {
            pendingRecentWorkspace = workspace
            suppressRecentRecording = true
            openPDF(readingURL)
            suppressRecentRecording = false
            if pendingPDFURL == nil {
                if pdfSourceURL?.standardizedFileURL == readingURL.standardizedFileURL {
                    finishPendingRecentWorkspace()
                } else { pendingRecentWorkspace = nil }
            }
            return
        }
        if readingURL.pathExtension.lowercased() == "epub" || isUnpackedEPUBDirectory(readingURL) {
            suppressRecentRecording = true
            pendingEPUBURL = readingURL
            pendingConvertedEPUBURL = nil
            openEPUBOriginal(editable: false)
            if epubDocument?.sourceURL.standardizedFileURL == readingURL.standardizedFileURL {
                restoreRecentNote(workspace.noteURL)
                suppressRecentRecording = false
                recordRecentWorkspace()
            } else {
                suppressRecentRecording = false
            }
            return
        }
        saveError = "最近使用记录中的阅读文件格式不受支持：\(readingURL.lastPathComponent)"
    }

    private func finishPendingRecentWorkspace() {
        guard let workspace = pendingRecentWorkspace else { return }
        pendingRecentWorkspace = nil
        guard activeReadingURL?.standardizedFileURL == workspace.readingURL?.standardizedFileURL else { return }
        suppressRecentRecording = true
        restoreRecentNote(workspace.noteURL)
        suppressRecentRecording = false
        recordRecentWorkspace()
    }

    private func restoreRecentNote(_ noteURL: URL?) {
        guard let noteURL else { clearNoteDocument(); return }
        loadDocument(noteURL, preservingEPUB: epubDocument != nil,
                     preservingPDF: pdfDocument != nil, preservingWeb: webBrowser.currentURL != nil, preservingOffice: officeDocumentURL != nil)
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        // The system Markdown type varies with installed apps. Filtering the
        // panel by UTType can leave a visible .md row impossible to open.
        // Validate the selected URL in performOpen instead.
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }

    private func chooseTemporaryFile() {
        let panel = NSOpenPanel()
        panel.title = "临时打开文件"
        panel.message = "只在当前窗口查看，不复制到 Workspace，也不创建新工程。"
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            open(url, importIntoWorkspace: false)
        }
    }
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            if isUnpackedEPUBDirectory(url) { open(url) }
            else if isDirty {
                pendingDocumentOperation = .openProjectFolder(url)
                showUnsavedAlert = true
            } else { performOpenProjectFolder(url) }
        }
    }

    private func performOpenProjectFolder(_ url: URL) {
        detachedWindows.closeAllSilently()
        _ = documentSessions.removeAll(discardingChanges: true)
        workspaceTabs = WorkspaceGridLayout()
        workspaceNoteIdentity = nil
        workspaceReadingIdentity = nil
        activeWorkspaceMarkdownURL = nil
        clearNoteDocument()
        clearReadingSource()
        workspaceFolders = []
        workspaceFiles = []
        workspaceReadingNotes = []
        workspaceFileURL = nil
        workspaceHasMissingReferences = false
        currentWorkspacePath = ""
        openFolderContents(url)
    }
    private func loadFolder(_ url: URL) {
        openFolderContents(url)
    }
    private func openFolderContents(_ url: URL) {
        guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
            saveError = "无法读取文件夹：\(url.lastPathComponent)"
            return
        }
        ensureAutomaticProject(for: url, isFolder: true)
        folderURL = url
        if !workspaceFolders.contains(url.standardizedFileURL) { workspaceFolders.append(url.standardizedFileURL) }
        lastFolderPath = url.path
        markdownFiles = []
        sidebarOutlineTab = .files
        showFolderContents = true
    }

    private func ensureAutomaticProject(for resource: URL, isFolder: Bool) {
        guard workspaceFileURL == nil else { return }
        do {
            let (manifest, project) = try projectStore.ensureProject(for: resource, isFolder: isFolder, layout: workspaceTabs)
            workspaceFileURL = manifest
            currentWorkspacePath = manifest.path
            workspaceFolders = project.folders.filter { FileManager.default.fileExists(atPath: $0.path) }
            workspaceFiles = project.files.filter { FileManager.default.fileExists(atPath: $0.path) }
            workspaceReadingNotes = project.readingNotes
            folderURL = workspaceFolders.first
            workspaceHasMissingReferences = !project.missingFiles.isEmpty
        } catch { saveError = "无法建立工程工作区：\(error.localizedDescription)" }
    }

    private func registerWorkspaceResource(_ url: URL) {
        guard url.isFileURL else { return }
        let canonical = url.standardizedFileURL
        let belongsToFolder = workspaceFolders.contains { canonical.path.hasPrefix($0.standardizedFileURL.path + "/") }
        guard !belongsToFolder, !workspaceFiles.contains(where: { $0.standardizedFileURL == canonical }) else { return }
        workspaceFiles.append(canonical)
    }

    private func chooseAdditionalWorkspaceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls.map(\.standardizedFileURL) where !workspaceFolders.contains(url) {
            workspaceFolders.append(url)
        }
        folderURL = workspaceFolders.first
        lastFolderPath = folderURL?.path ?? ""
        sidebarOutlineTab = .files
    }

    private func chooseAdditionalWorkspaceFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls.map(\.standardizedFileURL) where !workspaceFiles.contains(url) {
            workspaceFiles.append(url)
        }
        sidebarOutlineTab = .files
    }

    private func removeWorkspaceFolder(_ url: URL) {
        workspaceFolders.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
        folderURL = workspaceFolders.first
        lastFolderPath = folderURL?.path ?? ""
    }

    private func importFilesIntoWorkspaceFolder(_ directory: URL) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.directoryURL = directory
        guard panel.runModal() == .OK else { return }
        do {
            for source in panel.urls {
                guard WorkspaceResourceImporter.isSupportedWorkspaceItem(source) else {
                    throw CocoaError(.fileReadUnsupportedScheme, userInfo: [NSLocalizedDescriptionKey:
                        "“\(source.lastPathComponent)”不是支持的文档，也不是包含 META-INF/container.xml 的 EPUB 文件夹。"])
                }
                _ = try WorkspaceResourceImporter.copyVerified(source, into: directory)
            }
            workspaceFileTreeRevision += 1
        } catch {
            saveError = "导入文件失败：\(error.localizedDescription)"
        }
    }

    private func requestWorkspaceFileDeletion(_ url: URL) {
        let canonical = url.standardizedFileURL
        if workspaceFileURL?.standardizedFileURL == canonical {
            saveError = "当前工程的 .mdworkspace 文件不能在工程打开期间删除。请先关闭工程。"
            return
        }
        pendingWorkspaceFileDeletion = canonical
        showWorkspaceFileDeletionConfirmation = true
    }

    private var workspaceFileDeletionMessage: String {
        guard let url = pendingWorkspaceFileDeletion else { return "文件会移到废纸篓。" }
        var details = ["“\(url.lastPathComponent)”会移到废纸篓。"]
        if documentSessions.session(for: url)?.isDirty == true {
            details.append("此文件有未保存的修改，删除后这些修改会丢失。")
        }
        if url.lastPathComponent == "主笔记.md" {
            details.append("这是工程主页，删除后工程将失去主笔记入口。")
        }
        return details.joined(separator: "\n")
    }

    private func deleteWorkspaceFile(_ url: URL) {
        let canonical = url.standardizedFileURL
        do {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: canonical, resultingItemURL: &resultingURL)
        } catch {
            saveError = "无法将文件移到废纸篓：\(error.localizedDescription)"
            return
        }

        for tab in workspaceTabs.allTabs where tab.location?.standardizedFileURL == canonical {
            workspaceTabs.remove(tab.id)
        }
        for tab in detachedWindows.allTabs where tab.location?.standardizedFileURL == canonical {
            _ = detachedWindows.take(tab.id)
        }
        _ = documentSessions.removeMarkdown(canonical, discardingChanges: true)
        workspaceFiles.removeAll { $0.standardizedFileURL == canonical }
        workspaceReadingNotes.removeAll {
            $0.readingURL.standardizedFileURL == canonical || $0.noteURL.standardizedFileURL == canonical
        }
        noteHistory.removeAll { $0.standardizedFileURL == canonical }
        if selectedFile?.standardizedFileURL == canonical {
            clearNoteDocument()
            activeWorkspaceMarkdownURL = nil
        }
        let activeReading = (officeDocumentURL ?? pdfSourceURL ?? epubDocument?.sourceURL)?.standardizedFileURL
        if activeReading == canonical { clearReadingSource() }
        workspaceEPUBDocuments.removeValue(forKey: canonical.path)
        workspaceEPUBChapters.removeValue(forKey: canonical.path)
        workspaceEPUBNavigationTargets.removeValue(forKey: canonical.path)
        workspaceFileTreeRevision += 1
    }

    private func workspaceDocumentSnapshot() -> WorkspaceDocument {
        var layout = workspaceTabs
        for tab in detachedWindows.allTabs where !layout.allTabs.contains(where: { $0.id == tab.id }) {
            layout.add(tab)
        }
        layout.root = layout.root.mappingTabs { tab in
            var value = tab
            if tab.kind == .web { value.location = webSessions.session(for: tab.id)?.currentURL }
            return value
        }
        return WorkspaceDocument(folders: workspaceFolders, files: workspaceFiles, layout: layout,
                                 readingNotes: workspaceReadingNotes)
    }

    private func restoreWorkspaceMetadata() {
        guard !currentWorkspacePath.isEmpty else { return }
        let url = URL(fileURLWithPath: currentWorkspacePath)
        guard let data = try? Data(contentsOf: url),
              let document = try? JSONDecoder().decode(WorkspaceDocument.self, from: data), document.isValid else {
            saveError = "无法恢复工作区：\(url.path)。原文件没有被修改。"
            return
        }
        let missing = document.missingFiles
        workspaceFolders = document.folders.filter { FileManager.default.fileExists(atPath: $0.path) }
        workspaceFiles = document.files.filter { FileManager.default.fileExists(atPath: $0.path) }
        workspaceReadingNotes = document.readingNotes
        folderURL = workspaceFolders.first
        workspaceFileURL = url
        workspaceHasMissingReferences = !missing.isEmpty
        if !missing.isEmpty {
            saveError = "工作区中的以下文件或文件夹未找到，原引用会保留：\n" + missing.map(\.path).joined(separator: "\n")
        }
    }

    private func saveWorkspaceFile() {
        MarkdownVisualCommandHub.commitActiveEdits {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [UTType(filenameExtension: "mdworkspace") ?? .data]
            panel.nameFieldStringValue = workspaceFileURL?.lastPathComponent ?? "我的工作区.mdworkspace"
            panel.directoryURL = workspaceFileURL?.deletingLastPathComponent() ?? folderURL
            guard panel.runModal() == .OK, let url = panel.url else { return }
            if url.standardizedFileURL == workspaceFileURL?.standardizedFileURL,
               !workspaceFileCanBeUpdated(url) {
                if saveError == nil { saveError = "此工作区暂不能覆盖，请另存为新工作区，以保留原来的引用。" }
                return
            }
            do {
                try writeWorkspaceDocument(workspaceDocumentSnapshot(), to: url)
                workspaceFileURL = url
                currentWorkspacePath = url.path
                workspaceHasMissingReferences = false
            } catch { saveError = "无法保存工作区：\(error.localizedDescription)" }
        }
    }

    /// Recheck the saved references: a volume or file can disappear after the
    /// workspace was opened, before a layout change triggers autosave.
    private func workspaceFileCanBeUpdated(_ url: URL) -> Bool {
        guard !workspaceHasMissingReferences else { return false }
        guard let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode(WorkspaceDocument.self, from: data),
              saved.isValid else {
            workspaceHasMissingReferences = true
            saveError = "无法读取原工作区，已停止自动覆盖。请另存为新工作区。"
            return false
        }
        let missing = saved.missingFiles
        guard missing.isEmpty else {
            workspaceHasMissingReferences = true
            saveError = "工作区中的文件或文件夹已不可用，已停止自动覆盖原引用：\n" + missing.map(\.path).joined(separator: "\n")
            return false
        }
        return true
    }

    private func writeWorkspaceDocument(_ document: WorkspaceDocument, to url: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(document).write(to: url, options: .atomic)
    }

    private func createWorkspace() {
        MarkdownVisualCommandHub.commitActiveEdits {
            MarkdownSourcePositionHub.flushPendingChanges()
            if isDirty {
                pendingDocumentOperation = .createWorkspace
                showUnsavedAlert = true
            } else {
                presentCreateWorkspacePanel()
            }
        }
    }

    private func presentCreateWorkspacePanel() {
        let panel = NSSavePanel()
        panel.title = "新建 Workspace 工程"
        panel.message = "一个学习主题使用一个独立工程文件夹，可以包含多本书、多份笔记和附件。"
        panel.prompt = "创建工程"
        panel.nameFieldLabel = "工程名称："
        panel.nameFieldStringValue = "未命名学习工程"
        panel.allowedContentTypes = [.folder]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let root = panel.url?.standardizedFileURL else { return }
        do {
            try createWorkspaceDirectory(at: root)
        } catch {
            saveError = "无法创建 Workspace：\(error.localizedDescription)"
        }
    }

    private func createWorkspaceDirectory(at root: URL) throws {
        let (manifest, _) = try createWorkspaceScaffold(at: root)

        let alert = NSAlert()
        alert.messageText = "Workspace 已创建"
        alert.informativeText = "可以一次加入多本 EPUB、PDF、Word 或 Pages；它们都是这个主题工程中的资料。"
        alert.addButton(withTitle: "添加主题资料…")
        alert.addButton(withTitle: "稍后添加")
        if alert.runModal() == .alertFirstButtonReturn {
            importWorkspaceResources(into: root, manifest: manifest)
        } else {
            performOpenWorkspace(manifest)
        }
    }

    private func createWorkspaceScaffold(at root: URL) throws -> (manifest: URL, mainNote: URL) {
        let manager = FileManager.default
        if manager.fileExists(atPath: root.path) {
            let contents = try manager.contentsOfDirectory(atPath: root.path)
            guard contents.isEmpty else {
                throw CocoaError(.fileWriteFileExists, userInfo: [NSLocalizedDescriptionKey: "目标文件夹已经存在且不为空，请使用新的工程名称。"])
            }
        } else {
            try manager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        let readingDirectory = root.appendingPathComponent("阅读资料", isDirectory: true)
        let notesDirectory = root.appendingPathComponent("笔记", isDirectory: true)
        let attachmentsDirectory = root.appendingPathComponent("附件", isDirectory: true)
        for directory in [readingDirectory, notesDirectory, attachmentsDirectory] {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let projectName = root.lastPathComponent
        let mainNote = notesDirectory.appendingPathComponent("主笔记.md")
        if !manager.fileExists(atPath: mainNote.path) {
            let template = """
            # \(projectName)

            ## 学习目标

            说明这个主题要解决的问题、范围和预期成果。

            ## 资料与笔记

            每本电子书会在“笔记/书籍笔记”中建立自己的配套笔记；跨资料内容可以整理为专题笔记。

            ## 综合结论

            汇总不同资料之间的联系、分歧和最终认识。

            """
            try template.write(to: mainNote, atomically: true, encoding: .utf8)
        }
        var layout = WorkspaceGridLayout()
        layout.add(WorkspaceTab(.visual, location: mainNote))
        let manifest = root.appendingPathComponent("\(projectName).mdworkspace")
        try writeWorkspaceDocument(WorkspaceDocument(folders: [root], layout: layout), to: manifest)
        return (manifest, mainNote)
    }

    private func importWorkspaceResources(into root: URL, manifest: URL) {
        let panel = NSOpenPanel()
        panel.title = "选择主题资料"
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK, !panel.urls.isEmpty else {
            performOpenWorkspace(manifest)
            return
        }
        let sources = panel.urls.map(\.standardizedFileURL)
        guard let unsupported = sources.first(where: { !WorkspaceResourceImporter.isSupportedWorkspaceItem($0) }) else {
            return importValidatedWorkspaceResources(sources, into: root, manifest: manifest)
        }
        saveError = "“\(unsupported.lastPathComponent)”不是支持的文档，也不是完整的 EPUB 文件夹。"
        performOpenWorkspace(manifest)
    }

    private func importValidatedWorkspaceResources(_ sources: [URL], into root: URL, manifest: URL) {

        let choice = NSAlert()
        choice.messageText = "如何加入阅读资料？"
        choice.informativeText = "此选择会应用于本次选中的全部资料。复制最安全；仅引用不会占用额外空间；移动会改变原文件位置。"
        choice.addButton(withTitle: "复制到工程（推荐）")
        choice.addButton(withTitle: "仅引用原文件")
        choice.addButton(withTitle: "移动到工程")
        choice.addButton(withTitle: "取消")
        let response = choice.runModal()
        do {
            var document = try JSONDecoder().decode(WorkspaceDocument.self, from: Data(contentsOf: manifest))
            var resources: [URL] = []
            switch response {
            case .alertFirstButtonReturn, .alertThirdButtonReturn:
                let directory = root.appendingPathComponent("阅读资料", isDirectory: true)
                for source in sources {
                    let destination = try WorkspaceResourceImporter.copyVerified(source, into: directory)
                    resources.append(destination)
                    if response == .alertThirdButtonReturn,
                       source.standardizedFileURL != destination.standardizedFileURL {
                        try FileManager.default.removeItem(at: source)
                    }
                }
            case .alertSecondButtonReturn:
                resources = sources
                for source in sources where !document.files.contains(where: { $0.standardizedFileURL == source }) {
                    document.files.append(source)
                }
            default:
                performOpenWorkspace(manifest)
                return
            }
            for resource in resources {
                document.layout.add(WorkspaceTab(.reading, location: resource))
            }
            document.layout = document.layout.arranged(.right)
            try writeWorkspaceDocument(document, to: manifest)
            performOpenWorkspace(manifest)
        } catch {
            saveError = "阅读资料没有导入：\(error.localizedDescription)"
            performOpenWorkspace(manifest)
        }
    }

    private func chooseWorkspaceFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openWorkspaceFile(url)
    }

    private func openWorkspaceFile(_ url: URL) {
        MarkdownVisualCommandHub.commitActiveEdits {
            MarkdownSourcePositionHub.flushPendingChanges()
            if isDirty {
                pendingDocumentOperation = .openWorkspace(url)
                showUnsavedAlert = true
            } else { performOpenWorkspace(url) }
        }
    }
    private func handleReaderAppear(openWindow: OpenWindowAction) {
        migrateDefaultHeadingColors()
        migrateSystemFontDefaults()
        readerWidthInput = "\(Int(readerWidth))"
        epubReaderWidthInput = "\(Int(epubReaderWidth))"
        // Preserve the existing appearance as the starting point, then let
        // the three view scopes evolve independently.
        if previewStyleData.isEmpty || (try? JSONDecoder().decode(MarkdownDisplayStyle.self, from: previewStyleData)) == nil {
            let previousPreview = ["local.markdownreader.visual.v0728", "local.markdownreader.visual.v0727"]
                .compactMap { UserDefaults(suiteName: $0)?.data(forKey: "markdown.previewStyle.v1") }
                .first { (try? JSONDecoder().decode(MarkdownDisplayStyle.self, from: $0)) != nil }
            if let previousPreview {
                previewStyleData = previousPreview
            } else {
                previewStyleData = (try? JSONEncoder().encode(readingMarkdownStyle)) ?? Data()
            }
        }
        if !previewTypographyDefaultsApplied,
           var preview = try? JSONDecoder().decode(MarkdownDisplayStyle.self, from: previewStyleData) {
            preview.applyPreviewTypographyDefaults()
            previewStyleData = (try? JSONEncoder().encode(preview)) ?? previewStyleData
            previewTypographyDefaultsApplied = true
        }
        if sourceStyleData.isEmpty || (try? JSONDecoder().decode(MarkdownDisplayStyle.self, from: sourceStyleData)) == nil {
            sourceStyleData = (try? JSONEncoder().encode(initialSourceStyle)) ?? Data()
        }
        previewWidthInput = "\(Int(previewStyle.readerWidth))"
        sourceWidthInput = "\(Int(sourceStyle.readerWidth))"
        officeZoomInput = "\(Int(officeZoomPercent))"
        pdfZoomInput = "\(Int(pdfZoomPercent))"
        configureReaderActions(openWindow: openWindow)
        if !lastFolderPath.isEmpty {
            let url = URL(fileURLWithPath: lastFolderPath)
            if FileManager.default.fileExists(atPath: url.path) { loadFolder(url) }
        }
        restoreWorkspaceMetadata()
        reloadWebBookmarks(reportError: true)
        ReaderActions.setOpenDocumentHandler { open($0) }
        restoreWorkspaceGridIfNeeded()
    }

    private func configureReaderActions(openWindow: OpenWindowAction) {
        ReaderActions.reopenWindowHandler = { openWindow(id: "main") }
        ReaderActions.terminationHandler = {
            MarkdownVisualCommandHub.commitActiveEdits {
                if isDirty {
                    pendingDocumentOperation = .terminate
                    showUnsavedAlert = true
                } else {
                    awaitReadingProfileBeforeTermination()
                }
            }
            return .terminateLater
        }
        ReaderActions.openFileHandler = chooseFile
        ReaderActions.openTemporaryFileHandler = chooseTemporaryFile
        ReaderActions.openFolderHandler = chooseFolder
        ReaderActions.newWorkspaceHandler = createWorkspace
        ReaderActions.openWorkspaceHandler = chooseWorkspaceFile
        ReaderActions.saveWorkspaceHandler = saveWorkspaceFile
        ReaderActions.openWebPageHandler = { activeSheet = .webAddress }
        ReaderActions.bookmarkCurrentPageHandler = beginBookmarkCurrentPage
        ReaderActions.clipWebSelectionHandler = clipWebSelection
        ReaderActions.webBackHandler = { webBrowser.goBack() }
        ReaderActions.webForwardHandler = { webBrowser.goForward() }
        ReaderActions.openSettingsHandler = { openOverallSettings() }
        ReaderActions.adjustBodySizeHandler = { activeBodySizeBinding.wrappedValue = min(24, max(12, activeBodySizeBinding.wrappedValue + $0)) }
        ReaderActions.resetBodySizeHandler = { activeBodySizeBinding.wrappedValue = 15 }
        ReaderActions.adjustTypographySizeHandler = { amount in
            switch fontSizeTarget {
            case .body: activeBodySizeBinding.wrappedValue = min(24, max(12, activeBodySizeBinding.wrappedValue + amount))
            case .outline:
                let adjustsMarkdownOutline = selectedFile != nil && sidebarOutlineTab == .markdown
                if adjustsMarkdownOutline {
                    let current = markdownOutlineScaleBinding.wrappedValue
                    let adjusted = min(1.6, max(0.75, current + amount * 0.1))
                    markdownOutlineScaleBinding.wrappedValue = adjusted
                } else {
                    outlineFontScale = min(1.6, max(0.75, outlineFontScale + amount * 0.1))
                }
            case .pdf: pdfZoomPercent = min(1000, max(25, pdfZoomPercent + amount * 10))
            case .web: webZoomPercent = min(200, max(50, webZoomPercent + amount * 10))
            case .office: officeZoomPercent = min(500, max(25, officeZoomPercent + amount * 10))
            }
        }
        ReaderActions.resetTypographySizeHandler = {
            switch fontSizeTarget {
            case .body: activeBodySizeBinding.wrappedValue = 15
            case .outline:
                if selectedFile != nil && sidebarOutlineTab == .markdown { markdownOutlineScaleBinding.wrappedValue = 1 }
                else { outlineFontScale = 1 }
            case .pdf: pdfZoomPercent = 100
            case .web: webZoomPercent = 100
            case .office: officeZoomPercent = 100
            }
        }
        ReaderActions.sidebarVisible = showSidebar
        ReaderActions.toggleSidebarHandler = {
            showSidebar.toggle()
            ReaderActions.sidebarVisible = showSidebar
        }
        ReaderActions.setDisplayModeHandler = { mode in
            if (hasNotebookReadingSource), epubNotebookLayout == .stacked {
                switch mode {
                case .read: showVisualMarkdown()
                case .edit: showMarkdownSource()
                case .split: maximizedNotebookPane = nil
                }
            } else if epubDocument != nil && !isEPUBNotebook {
                displayMode = mode
            } else {
                switch mode {
                case .read: showVisualMarkdown()
                case .edit: showMarkdownSource()
                case .split: displayMode = .split
                }
            }
        }
        ReaderActions.applyHeadingLevelHandler = applyHeadingLevel
        ReaderActions.applyInlineSyntaxHandler = applyInlineSyntax
        ReaderActions.applyLinePrefixHandler = applyLinePrefix
        ReaderActions.wrapSelectionHandler = wrapSelection
        ReaderActions.clearLinePrefixHandler = clearLinePrefix
        ReaderActions.insertTemplateHandler = insertTemplate
        ReaderActions.insertImageFileHandler = insertImageFile
        ReaderActions.toggleEditPreviewHandler = toggleVisualMarkdownSource
        ReaderActions.toggleReadingEditingFocusHandler = toggleReadingEditingFocus
        ReaderActions.toggleSplitModeHandler = {
            if hasNotebookReadingSource {
                epubNotebookLayout = epubNotebookLayout == .stacked ? .notes : .stacked
            } else if epubDocument != nil {
                displayMode = displayMode == .edit ? .read : .edit
            } else {
                displayMode = displayMode == .split ? .edit : .split
            }
        }
        ReaderActions.openPreviewToSideHandler = {
            if hasNotebookReadingSource {
                if epubNotebookLayout == .epub { epubNotebookLayout = usesSwitchDisplay ? .notes : .stacked; showsNotesTab = usesSwitchDisplay }
                displayMode = .split
            } else if epubDocument != nil {
                displayMode = .edit
            } else {
                displayMode = .split
            }
        }
        ReaderActions.setEPUBNotebookLayoutHandler = {
            guard hasNotebookReadingSource else { return }
            epubNotebookLayout = $0
        }
        ReaderActions.maximizeEPUBNotebookPaneHandler = { pane in
            guard hasNotebookReadingSource else { return }
            epubNotebookLayout = .stacked
            maximizedNotebookPane = pane
        }
        ReaderActions.restoreEPUBNotebookLayoutHandler = { maximizedNotebookPane = nil }
        ReaderActions.addEPUBAnnotationHandler = {
            guard epubDocument != nil, epubSelection != nil else { return }
            epubEditingAnnotation = nil
            activeSheet = .epubAnnotationComposer
        }
        ReaderActions.showEPUBAnnotationsHandler = {
            guard epubDocument != nil else { return }
            activeSheet = .epubAnnotationList
        }
        ReaderActions.saveHandler = { MarkdownVisualCommandHub.commitActiveEdits { _ = saveDocument() } }
        ReaderActions.closeFileHandler = closeFile
        ReaderActions.closeReadingSourceHandler = closeReadingSource
        ReaderActions.closeNoteHandler = closeNote
        ReaderActions.closeFolderHandler = closeFolder
        ReaderActions.insertHorizontalRuleHandler = insertHorizontalRule
        ReaderActions.insertTableHandler = {
            guard selectedFile != nil else { return }
            activeSheet = .tableInsertion
        }
    }

    private var noteNavigationButtons: some View {
        HStack(spacing: 3) {
            Button { navigateNoteHistory(-1) } label: { Image(systemName: "chevron.left") }
                .disabled(noteHistoryIndex <= 0).help("后退到上一条笔记记录")
            Button { navigateNoteHistory(1) } label: { Image(systemName: "chevron.right") }
                .disabled(noteHistoryIndex < 0 || noteHistoryIndex + 1 >= noteHistory.count).help("前进到下一条笔记记录")
            Button { if let selectedFile, let parent = MarkdownNoteHierarchy.parent(of: selectedFile) { open(parent) } } label: { Image(systemName: "arrow.up") }
                .disabled(selectedFile.flatMap { MarkdownNoteHierarchy.parent(of: $0) } == nil).help("打开上一级笔记")
            Button { createInlineChildNote() } label: { Image(systemName: "doc.badge.plus") }
                .disabled(selectedFile == nil).help("在当前位置新建子笔记；选中文字可作为正文链接")
            Menu {
                if let selectedFile {
                    Button("在当前位置新建子笔记…") { createInlineChildNote() }
                    Button("在目录中新建子笔记…") { createChildNote(selectedFile) }
                    Button("插入笔记链接…") { insertChildNoteLink() }
                    Divider()
                    ForEach(MarkdownNoteHierarchy.children(of: selectedFile), id: \.path) { child in
                        Button(child.deletingPathExtension().lastPathComponent) { open(child) }
                    }
                }
            } label: { Image(systemName: "list.bullet.indent") }
            .disabled(selectedFile == nil).help("子笔记")
        }.buttonStyle(.borderless)
    }

    private func navigateNoteHistory(_ offset: Int) {
        let index = noteHistoryIndex + offset
        guard noteHistory.indices.contains(index) else { return }
        let url = noteHistory[index]
        MarkdownVisualCommandHub.commitActiveEdits {
            if source != savedSource {
                pendingDocumentOperation = .navigateNote(url, index)
                showUnsavedAlert = true
            } else {
                requestedHistoryIndex = index
                performOpen(url)
            }
        }
    }

    private func deleteManagedChild(_ child: URL) {
        guard let selectedFile, let parent = MarkdownNoteHierarchy.parent(of: child),
              selectedFile.standardizedFileURL.resolvingSymlinksInPath() == parent.standardizedFileURL.resolvingSymlinksInPath() else {
            saveError = "只能通过正文区块删除当前笔记的直属子笔记。"
            return
        }
        deleteChild(child, requireManaged: false)
    }
    private func deleteChildFromTree(_ child: URL) {
        let alert = NSAlert()
        alert.messageText = "删除子笔记？"
        alert.informativeText = "“\(child.deletingPathExtension().lastPathComponent)”及其下级笔记将移到废纸篓，并移除父笔记中的链接。"
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        deleteChild(child, requireManaged: false)
    }

    private func deleteChild(_ child: URL, requireManaged: Bool) {
        MarkdownVisualCommandHub.commitActiveEdits {
            guard let parent = MarkdownNoteHierarchy.parent(of: child) else {
                saveError = "无法找到子笔记对应的父笔记。"; return
            }
            let selected = selectedFile?.standardizedFileURL.resolvingSymlinksInPath()
            let childPath = child.standardizedFileURL.resolvingSymlinksInPath()
            let subtreePath = MarkdownNoteHierarchy.childrenDirectory(of: child).standardizedFileURL.resolvingSymlinksInPath().path + "/"
            let deletingCurrent = selected == childPath || (selected?.path.hasPrefix(subtreePath) ?? false)
            if deletingCurrent && source != savedSource {
                let alert = NSAlert()
                alert.messageText = "子笔记有未保存的修改"
                alert.informativeText = "保存后删除会将最新内容放入废纸篓。"
                alert.addButton(withTitle: "保存并删除")
                alert.addButton(withTitle: "取消")
                guard alert.runModal() == .alertFirstButtonReturn else { return }
                guard let selectedFile,
                      (try? String(contentsOf: selectedFile, encoding: .utf8)) == savedSource else {
                    saveError = "当前笔记已被其他程序修改，请先处理外部修改。"; return
                }
                guard saveNote() else { return }
            }
            do {
                let parentIsCurrent = selected == parent.standardizedFileURL.resolvingSymlinksInPath()
                let disk = try String(contentsOf: parent, encoding: .utf8)
                let result = try MarkdownNoteDeletion.perform(parent: parent, child: child,
                    parentSource: parentIsCurrent ? source : disk,
                    expectedDisk: parentIsCurrent ? savedSource : disk,
                    requireManaged: requireManaged)
                if parentIsCurrent {
                    source = result.parentSource
                    savedSource = result.parentSource
                    editorSelection = NSRange(location: min(editorSelection.location, (source as NSString).length), length: 0)
                } else if deletingCurrent {
                    selectedFile = nil
                    loadDocument(parent, preservingEPUB: epubDocument != nil, preservingPDF: pdfDocument != nil,
                                 preservingWeb: webBrowser.currentURL != nil, preservingOffice: officeDocumentURL != nil)
                }
                let oldIndex = noteHistoryIndex
                let kept = noteHistory.enumerated().filter { entry in
                    let path = entry.element.standardizedFileURL.resolvingSymlinksInPath()
                    return path != childPath && !path.path.hasPrefix(subtreePath)
                }
                noteHistory = kept.map(\.element)
                if let currentIndex = kept.firstIndex(where: { $0.offset == oldIndex }) {
                    noteHistoryIndex = currentIndex
                } else if let current = selectedFile?.standardizedFileURL {
                    if let index = noteHistory.lastIndex(of: current) { noteHistoryIndex = index }
                    else { noteHistory.append(current); noteHistoryIndex = noteHistory.count - 1 }
                } else { noteHistoryIndex = -1 }
                noteTreeRevision += 1
            } catch {
                saveError = "无法删除子笔记：\(error.localizedDescription)"
            }
        }
    }

    private func createChildNote(_ parent: URL) {
        let directory = MarkdownNoteHierarchy.childrenDirectory(of: parent)
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { saveError = "无法创建子笔记文件夹：\(error.localizedDescription)"; return }
        let panel = NSSavePanel()
        panel.directoryURL = directory
        panel.nameFieldStringValue = "新建子笔记.md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL else {
            saveError = "子笔记需要保存在父笔记的子笔记文件夹中。"; return
        }
        if FileManager.default.fileExists(atPath: url.path) { open(url); return }
        MarkdownVisualCommandHub.commitActiveEdits {
            if source != savedSource {
                pendingDocumentOperation = .createNote(url)
                showUnsavedAlert = true
            } else { performCreateMarkdownNote(at: url) }
        }
    }

    private func createInlineChildNote(anchorToken: String? = nil) {
        guard let parent = selectedFile else { return }
        MarkdownVisualCommandHub.commitActiveEdits {
            guard selectedFile?.standardizedFileURL == parent.standardizedFileURL else { return }
            MarkdownSourcePositionHub.capture()
            var raw = source as NSString
            var position = visualScrollState.activeMode == .visual
                ? (visualScrollState.selection ?? editorSelection) : editorSelection
            if let anchorToken {
                let tokenRange = raw.range(of: anchorToken)
                guard tokenRange.location != NSNotFound else {
                    saveError = "无法确定子笔记的插入位置，请重试。"; return
                }
                source = raw.replacingCharacters(in: tokenRange, with: "")
                raw = source as NSString
                position = NSRange(location: tokenRange.location, length: 0)
            }
            let start = max(0, min(position.location, raw.length))
            let length = max(0, min(position.length, raw.length - start))
            let range = NSRange(location: start, length: length)
            let selected = raw.substring(with: range)
            guard !selected.contains("\n"), !selected.contains("\r") else {
                saveError = MarkdownNoteHierarchy.CreationError.invalidSelection.localizedDescription
                return
            }

            let alert = NSAlert()
            alert.messageText = "新建子笔记"
            alert.informativeText = selected.isEmpty ? "输入名称，子笔记链接会插入光标位置。" : "所选文字会成为正文中的子笔记链接。"
            alert.addButton(withTitle: "创建并打开")
            alert.addButton(withTitle: "取消")
            let field = NSTextField(string: selected)
            field.placeholderString = "子笔记名称"
            field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
            alert.accessoryView = field
            alert.window.initialFirstResponder = field
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = selected.isEmpty ? name : selected
            do {
                let (child, link) = try MarkdownNoteHierarchy.inlineLink(parent: parent, title: name, label: label)
                // Do not replace an external edit with the copy in the editor.
                let disk = try String(contentsOf: parent, encoding: .utf8)
                guard disk == savedSource else {
                    saveError = "父笔记已被其他程序修改，请先处理外部修改，再创建子笔记。"
                    return
                }
                try FileManager.default.createDirectory(at: child.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data().write(to: child, options: .withoutOverwriting)
                let oldSource = source
                source = raw.replacingCharacters(in: range, with: link)
                let caret = NSRange(location: start + (link as NSString).length, length: 0)
                editorSelection = caret
                visualScrollState.selection = caret
                guard saveNote() else {
                    source = oldSource
                    editorSelection = range
                    visualScrollState.selection = range
                    saveError = "父笔记保存失败；原编辑内容仍在，已创建的空子笔记保留在 \(child.path)。"
                    return
                }
                let parentViewport = visualScrollState.viewport
                loadDocument(child, preservingEPUB: epubDocument != nil, preservingPDF: pdfDocument != nil,
                             preservingWeb: webBrowser.currentURL != nil, preservingOffice: officeDocumentURL != nil)
                if selectedFile?.standardizedFileURL == child.standardizedFileURL {
                    notePositions[parent.standardizedFileURL.path] = (caret, parentViewport)
                }
                DispatchQueue.main.async { focusMarkdownEditor() }
            } catch {
                saveError = "无法新建子笔记：\(error.localizedDescription)"
            }
        }
    }

    private func applySlashCommand(_ command: String, anchorToken: String?) {
        switch command {
        case "page": createInlineChildNote(anchorToken: anchorToken)
        case "text": clearLinePrefix()
        case "h1", "h2", "h3", "h4", "h5", "h6":
            if let level = Int(command.dropFirst()) { applyHeadingLevel(level) }
        case "bullet": applyLinePrefix("- ")
        case "num": applyLinePrefix("1. ")
        case "todo": applyLinePrefix("- [ ] ")
        case "quote": applyLinePrefix("> ")
        case "div": insertHorizontalRule()
        case "table": activeSheet = .tableInsertion
        case "image": insertImageFile()
        case "link": insertChildNoteLink()
        case "bold": applyInlineSyntax("**", "**")
        case "italic": applyInlineSyntax("*", "*")
        case "underline": applyInlineSyntax("<u>", "</u>")
        case "strike": applyInlineSyntax("~~", "~~")
        case "code": applyInlineSyntax("`", "`")
        default: break
        }
    }

    private func insertChildNoteLink(embedded: Bool = false) {
        guard let current = selectedFile else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = workspaceRoot(containing: current)?.appendingPathComponent("笔记", isDirectory: true)
            ?? current.deletingLastPathComponent()
        guard panel.runModal() == .OK, let selectedTarget = panel.url,
              ["md", "markdown"].contains(selectedTarget.pathExtension.lowercased()) else { return }
        let target: URL
        do { target = try importedMarkdownReferenceIfNeeded(selectedTarget, from: current) }
        catch {
            saveError = "无法引用 Markdown 文件：\(error.localizedDescription)"
            return
        }
        let base = current.deletingLastPathComponent().standardizedFileURL.pathComponents
        let destination = target.standardizedFileURL.pathComponents
        let common = zip(base, destination).prefix { $0 == $1 }.count
        let relative = (Array(repeating: "..", count: base.count - common) + destination.dropFirst(common)).joined(separator: "/")
        var pathCharacters = CharacterSet.urlPathAllowed
        pathCharacters.remove(charactersIn: "#?()")
        let encoded = relative.addingPercentEncoding(withAllowedCharacters: pathCharacters) ?? relative
        MarkdownVisualCommandHub.commitActiveEdits {
            MarkdownSourcePositionHub.flushPendingChanges()
            let text = source as NSString
            let selection = visualScrollState.activeMode == .visual ? (visualScrollState.selection ?? editorSelection) : editorSelection
            let location = min(max(0, selection.location), text.length)
            let availableLength = min(max(0, selection.length), text.length - location)
            let selectedText = text.substring(with: NSRange(location: location, length: availableLength))
            let fallbackTitle = target.deletingPathExtension().lastPathComponent
            let labelSource = !selectedText.isEmpty && !selectedText.contains("\n") ? selectedText : fallbackTitle
            let title = labelSource.replacingOccurrences(of: "]", with: "\\]")
            let markdown = embedded ? "\n\n[\(title)](\(encoded) \"mdstudio-embed\")\n\n" : "[\(title)](\(encoded))"
            source = text.replacingCharacters(in: NSRange(location: location, length: availableLength), with: markdown)
            editorSelection = NSRange(location: location + (markdown as NSString).length, length: 0)
            visualRestoreRequest += 1
            sourcePositionRestoreRequest += 1
        }
    }

    private func workspaceRoot(containing url: URL) -> URL? {
        let path = url.standardizedFileURL.path
        return workspaceFolders.first(where: {
            let root = $0.standardizedFileURL.path
            return path == root || path.hasPrefix(root + "/")
        })
    }

    /// References must remain portable with the Workspace. If the selected
    /// note lives elsewhere, import a verified copy before inserting the
    /// relative Markdown link. Ordinary reference links never own/delete the
    /// target note.
    private func importedMarkdownReferenceIfNeeded(_ target: URL, from current: URL) throws -> URL {
        let canonical = target.standardizedFileURL
        guard let root = workspaceRoot(containing: current), workspaceRoot(containing: canonical) == nil else {
            return canonical
        }
        let references = root.appendingPathComponent("笔记/引用笔记", isDirectory: true)
        return try WorkspaceResourceImporter.copyVerified(canonical, into: references)
    }

    private func openMarkdownReference(_ target: URL) {
        guard ["md", "markdown"].contains(target.pathExtension.lowercased()) else {
            saveError = "链接目标不是 Markdown 文件：\(target.lastPathComponent)"
            return
        }
        guard FileManager.default.fileExists(atPath: target.path) else {
            saveError = "引用的笔记已经移动或删除：\n\(target.path)"
            return
        }
        open(target, importIntoWorkspace: false)
    }

    private func isReadingResource(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "epub" || ext == "pdf" || KindleBookConverter.isSupported(url)
            || OfficeReadingFormat.supports(url) || isUnpackedEPUBDirectory(url)
    }

    /// Reading sources are immutable project inputs.  Import them before a
    /// reader is created so recents, tabs and annotations all point at the
    /// verified project copy rather than at a removable external file.
    private func prepareReadingResourceForWorkspace(_ source: URL) throws -> URL {
        let canonical = source.standardizedFileURL
        if let root = workspaceFolders.first?.standardizedFileURL,
           canonical.path == root.path || canonical.path.hasPrefix(root.path + "/") {
            return canonical
        }

        let root: URL
        if let activeRoot = workspaceFolders.first?.standardizedFileURL {
            root = activeRoot
        } else {
            root = try createAutomaticThemeWorkspace(for: canonical)
        }

        let readingDirectory = root.appendingPathComponent("阅读资料", isDirectory: true)
        try FileManager.default.createDirectory(at: readingDirectory, withIntermediateDirectories: true)
        return try copyReadingResource(canonical, into: readingDirectory)
    }

    private func createAutomaticThemeWorkspace(for source: URL) throws -> URL {
        let manager = FileManager.default
        let documents = manager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? manager.homeDirectoryForCurrentUser.appendingPathComponent("Documents", isDirectory: true)
        let base = documents.appendingPathComponent("Markdown Studio Workspaces", isDirectory: true)
        try manager.createDirectory(at: base, withIntermediateDirectories: true)

        let safeName = WorkspaceResourceImporter.sanitizedWorkspaceName(source.deletingPathExtension().lastPathComponent)
        if let root = WorkspaceResourceImporter.reusableWorkspaceRoot(for: source, in: base) {
            let existingManifest = root.appendingPathComponent("\(safeName).mdworkspace")
            performOpenWorkspace(existingManifest)
            return root
        }
        let root = WorkspaceResourceImporter.nextWorkspaceRoot(named: safeName, in: base)
        let (manifest, _) = try createWorkspaceScaffold(at: root)
        performOpenWorkspace(manifest)
        return root
    }

    private func copyReadingResource(_ source: URL, into directory: URL) throws -> URL {
        try WorkspaceResourceImporter.copyVerified(source, into: directory)
    }

    private func ensureCompanionNote(for readingURL: URL) throws -> URL? {
        guard isReadingResource(readingURL), let root = workspaceFolders.first?.standardizedFileURL else { return nil }
        let canonicalReading = readingURL.standardizedFileURL
        let manager = FileManager.default

        let noteURL: URL
        if let existing = workspaceReadingNotes.first(where: {
            $0.readingURL.standardizedFileURL == canonicalReading
        }) {
            noteURL = existing.noteURL.standardizedFileURL
        } else {
            let directory = root.appendingPathComponent("笔记/书籍笔记", isDirectory: true)
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            let base = WorkspaceResourceImporter.sanitizedWorkspaceName(
                canonicalReading.deletingPathExtension().lastPathComponent)
            var candidate = directory.appendingPathComponent("\(base).md")
            var suffix = 2
            let used = Set(workspaceReadingNotes.map { $0.noteURL.standardizedFileURL.path })
            while used.contains(candidate.standardizedFileURL.path) {
                candidate = directory.appendingPathComponent("\(base)-\(suffix).md")
                suffix += 1
            }
            noteURL = candidate
            workspaceReadingNotes.append(WorkspaceReadingNoteLink(readingURL: canonicalReading, noteURL: noteURL))
        }

        try manager.createDirectory(at: noteURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !manager.fileExists(atPath: noteURL.path) {
            let title = canonicalReading.deletingPathExtension().lastPathComponent
            try "# \(title)\n\n".write(to: noteURL, atomically: true, encoding: .utf8)
        }
        let document = try documentStore.openDocument(at: noteURL)
        _ = documentSessions.adoptMarkdown(noteURL, text: document.source)
        if !workspaceTabs.allTabs.contains(where: {
            $0.kind == .visual && $0.location?.standardizedFileURL == noteURL.standardizedFileURL
        }) {
            workspaceTabs.add(WorkspaceTab(.visual, location: noteURL))
        }
        return noteURL
    }

    private func companionNoteURL(for readingURL: URL) -> URL? {
        let reading = readingURL.standardizedFileURL
        return workspaceReadingNotes.first(where: {
            $0.readingURL.standardizedFileURL == reading
        })?.noteURL.standardizedFileURL
    }

    private func activateCompanionNote(for readingURL: URL, selectNote: Bool) {
        guard let noteURL = companionNoteURL(for: readingURL),
              FileManager.default.fileExists(atPath: noteURL.path) else { return }
        let kind: WorkspaceTab.Kind = selectNote ? .visual : .reading
        let location = selectNote ? noteURL : readingURL.standardizedFileURL
        if selectNote {
            loadDocument(noteURL, preservingEPUB: epubDocument != nil, preservingPDF: pdfDocument != nil,
                         preservingWeb: webBrowser.currentURL != nil, preservingOffice: officeDocumentURL != nil)
        }
        if let tab = workspaceTabs.allTabs.first(where: {
            $0.kind == kind && $0.location?.standardizedFileURL == location
        }) {
            selectWorkspaceTab(tab)
        } else if kind == .reading {
            let tab = WorkspaceTab(.reading, location: location)
            workspaceTabs.add(tab)
            selectWorkspaceTab(tab)
        }
    }

    private func open(_ url: URL, importIntoWorkspace: Bool = true) {
        if url.isFileURL && url.pathExtension.lowercased() == "mdworkspace" {
            openWorkspaceFile(url)
            return
        }
        MarkdownVisualCommandHub.commitActiveEdits {
            if let existing = workspaceTabs.allTabs.first(where: {
                ($0.kind == .source || $0.kind == .visual) && $0.location?.standardizedFileURL == url.standardizedFileURL
            }) {
                selectWorkspaceTab(existing)
                return
            }
            if url == selectedFile { return }
            let isMarkdown = ["md", "markdown"].contains(url.pathExtension.lowercased())
            let replacesNote = !WebBrowserSession.isWebURL(url)
                && !OfficeReadingFormat.supports(url)
                && !["epub", "pdf", "mobi", "azw", "azw3"].contains(url.pathExtension.lowercased())
                && !isUnpackedEPUBDirectory(url)
            if (!isMarkdown && replacesNote && source != savedSource) || (!replacesNote && !WebBrowserSession.isWebURL(url) && epubHasChanges) {
                pendingDocumentOperation = .open(url, importIntoWorkspace: importIntoWorkspace)
                showUnsavedAlert = true
            } else {
                performOpen(url, importIntoWorkspace: importIntoWorkspace)
            }
        }
    }

    private func performOpen(_ url: URL, importIntoWorkspace: Bool = true) {
        kindleConversionTask?.cancel()
        kindleConversionTask = nil
        kindleConversionRevision += 1
        isConvertingKindle = false
        if importIntoWorkspace, isReadingResource(url), workspaceRoot(containing: url) == nil {
            beginReadingResourceImport(url)
            return
        }
        pendingRecentWorkspace = nil
        if WebBrowserSession.isWebURL(url) {
            openWeb(url)
            return
        }
        let openingURL: URL
        do {
            openingURL = importIntoWorkspace && isReadingResource(url)
                ? try prepareReadingResourceForWorkspace(url)
                : url.standardizedFileURL
        } catch {
            saveError = "无法把阅读资料加入 Workspace：\(error.localizedDescription)"
            return
        }
        if let existing = workspaceTabs.allTabs.first(where: {
            $0.kind == .reading && $0.location?.standardizedFileURL == openingURL.standardizedFileURL
        }) {
            selectWorkspaceTab(existing)
            return
        }
        if importIntoWorkspace {
            ensureAutomaticProject(for: openingURL, isFolder: false)
            registerWorkspaceResource(openingURL)
            if isReadingResource(openingURL) {
                do { _ = try ensureCompanionNote(for: openingURL) }
                catch {
                    saveError = "无法建立配套 Markdown 笔记：\(error.localizedDescription)"
                    return
                }
            }
        }
        if (openingURL.pathExtension.lowercased() == "epub" || openingURL.pathExtension.lowercased() == "pdf"
            || KindleBookConverter.isSupported(openingURL) || isUnpackedEPUBDirectory(openingURL)),
           activeBookURL?.standardizedFileURL != openingURL.standardizedFileURL {
            flushCurrentReadingProfile()
        }
        if OfficeReadingFormat.supports(openingURL) {
            openOfficeDocument(openingURL)
        } else if KindleBookConverter.isSupported(openingURL) {
            beginKindleConversion(openingURL)
        } else if openingURL.pathExtension.lowercased() == "epub" || isUnpackedEPUBDirectory(openingURL) {
            pendingEPUBURL = openingURL
            pendingConvertedEPUBURL = nil
            showEPUBModeChoice = true
        } else if openingURL.pathExtension.lowercased() == "pdf" {
            openPDF(openingURL)
        } else if openingURL.pathExtension.lowercased() == "wps" {
            saveError = "暂不支持 WPS 专有的 .wps 格式。请使用 .doc 或 .docx 文件。"
        } else if ["azw4", "kfx"].contains(openingURL.pathExtension.lowercased()) {
            saveError = KindleBookConversionError.unsupportedFormat.localizedDescription
        } else if (try? openingURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            saveError = "所选文件夹不是已解压的 EPUB：找不到 META-INF/container.xml。"
        } else {
            // When a reading source is open, Markdown documents belong to its notes pane.
            loadDocument(openingURL, preservingEPUB: epubDocument != nil,
                         preservingPDF: pdfDocument != nil, preservingWeb: webBrowser.currentURL != nil, preservingOffice: officeDocumentURL != nil)
        }
    }

    /// Large EPUBs must never be copied and hashed on the AppKit event loop.
    /// Keep the verified project-copy rule, but prepare the Workspace and run
    /// the expensive recursive copy on a detached task before opening it.
    private func beginReadingResourceImport(_ source: URL) {
        readingImportTask?.cancel()
        let canonical = source.standardizedFileURL
        isImportingReadingResource = true
        readingImportTask = Task { @MainActor in
            do {
                let root: URL
                if let activeRoot = workspaceFolders.first?.standardizedFileURL {
                    root = activeRoot
                } else {
                    let manager = FileManager.default
                    let documents = manager.urls(for: .documentDirectory, in: .userDomainMask).first
                        ?? manager.homeDirectoryForCurrentUser.appendingPathComponent("Documents", isDirectory: true)
                    let base = documents.appendingPathComponent("Markdown Studio Workspaces", isDirectory: true)
                    let safeName = WorkspaceResourceImporter.sanitizedWorkspaceName(
                        canonical.deletingPathExtension().lastPathComponent)
                    let plan = try await Task.detached(priority: .userInitiated) { () -> (URL, Bool) in
                        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
                        if let reusable = WorkspaceResourceImporter.reusableWorkspaceRoot(for: canonical, in: base) {
                            return (reusable, true)
                        }
                        return (WorkspaceResourceImporter.nextWorkspaceRoot(named: safeName, in: base), false)
                    }.value
                    try Task.checkCancellation()
                    root = plan.0
                    let manifest = root.appendingPathComponent("\(root.lastPathComponent).mdworkspace")
                    if plan.1 {
                        performOpenWorkspace(manifest)
                    } else {
                        let created = try createWorkspaceScaffold(at: root)
                        performOpenWorkspace(created.manifest)
                    }
                }

                let readingDirectory = root.appendingPathComponent("阅读资料", isDirectory: true)
                let imported = try await Task.detached(priority: .userInitiated) {
                    try WorkspaceResourceImporter.copyVerified(canonical, into: readingDirectory)
                }.value
                try Task.checkCancellation()
                isImportingReadingResource = false
                readingImportTask = nil
                performOpen(imported, importIntoWorkspace: true)
            } catch is CancellationError {
                isImportingReadingResource = false
                readingImportTask = nil
            } catch {
                isImportingReadingResource = false
                readingImportTask = nil
                saveError = "无法把阅读资料加入 Workspace：\(error.localizedDescription)"
            }
        }
    }

    private func beginKindleConversion(_ url: URL) {
        let revision = kindleConversionRevision
        isConvertingKindle = true
        let conversion = Task.detached(priority: .userInitiated) {
            try KindleBookConverter().convert(url)
        }
        kindleConversionTask = conversion
        Task { @MainActor in
            do {
                let converted = try await conversion.value
                guard revision == kindleConversionRevision else { return }
                kindleConversionTask = nil
                isConvertingKindle = false
                pendingEPUBURL = url
                pendingConvertedEPUBURL = converted
                if pendingRecentWorkspace?.readingURL?.standardizedFileURL == url.standardizedFileURL {
                    suppressRecentRecording = true
                    openEPUBOriginal(editable: false)
                    suppressRecentRecording = false
                    finishPendingRecentWorkspace()
                } else {
                    showEPUBModeChoice = true
                }
            } catch {
                guard revision == kindleConversionRevision else { return }
                kindleConversionTask = nil
                isConvertingKindle = false
                pendingRecentWorkspace = nil
                if case KindleBookConversionError.converterUnavailable = error {
                    showCalibreInstallAlert = true
                } else {
                    saveError = error.localizedDescription
                }
            }
        }
    }

    private func openWeb(_ url: URL) {
        guard WebBrowserSession.isWebURL(url) else { return }
        let keepBookmarksVisible = sidebarOutlineTab == .webBookmarks
        let id: UUID
        if webBrowser.currentURL == nil, let active = webSessions.activeID { id = active }
        else { id = webSessions.create() }
        webSessions.session(for: id)?.open(url)
        if !workspaceTabs.allTabs.contains(where: { $0.id == id }) {
            workspaceTabs.add(WorkspaceTab(.web, id: id))
        } else { workspaceTabs.select(id) }
        activateWorkspaceArea(.web)
        if keepBookmarksVisible { sidebarOutlineTab = .webBookmarks }
    }

    private func isUnpackedEPUBDirectory(_ url: URL) -> Bool {
        guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return false }
        return FileManager.default.fileExists(atPath: url.appendingPathComponent("META-INF/container.xml").path)
    }

    private func openEPUBOriginal(editable: Bool) {
        guard let url = pendingEPUBURL else { return }
        let convertedURL = pendingConvertedEPUBURL
        pendingEPUBURL = nil
        pendingConvertedEPUBURL = nil
        if activeBookURL?.standardizedFileURL != url.standardizedFileURL { flushCurrentReadingProfile() }
        do {
            let document = try EPUBPackageDocument.open(url, bookURL: convertedURL)
            officeDocumentURL = nil
            pdfDocument = nil
            pdfSourceURL = nil
            epubDocument = document
            isEPUBNotebook = selectedFile != nil && !editable
            if isEPUBNotebook || usesSwitchDisplay { epubNotebookLayout = usesSwitchDisplay ? .epub : .stacked; showsNotesTab = false }
            activateWorkspaceArea(.epub)
            maximizedNotebookPane = nil
            epubCurrentChapter = 0
            beginLoadingReadingProfile(for: url, sourceKind: .epub, title: document.title)
            epubHasChanges = false
            documentTitle = epubDocument?.title ?? url.deletingPathExtension().lastPathComponent
            displayMode = editable ? .edit : .read
            activateCompanionNote(for: url, selectNote: false)
            recordRecentWorkspace()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func openEPUBNote() {
        guard let url = pendingEPUBURL else { return }
        let convertedURL = pendingConvertedEPUBURL
        pendingEPUBURL = nil
        pendingConvertedEPUBURL = nil
        MarkdownVisualCommandHub.commitActiveEdits {
            let noteURL = url.deletingPathExtension().appendingPathExtension("md")
            if selectedFile != noteURL && source != savedSource {
                pendingDocumentOperation = .openEPUBNote(url, convertedURL)
                showUnsavedAlert = true
            } else {
                performOpenEPUBNote(url, convertedURL: convertedURL)
            }
        }
    }

    private func openEPUBCompanionNote() {
        guard let url = pendingEPUBURL else { return }
        if companionNoteURL(for: url) == nil {
            openEPUBNote()
            return
        }
        openEPUBOriginal(editable: false)
        activateCompanionNote(for: url, selectNote: true)
    }

    private func performOpenEPUBNote(_ url: URL, convertedURL: URL?) {
        if activeBookURL?.standardizedFileURL != url.standardizedFileURL { flushCurrentReadingProfile() }
        let noteURL = url.deletingPathExtension().appendingPathExtension("md")
        var createdNote = false
        do {
            let document = try EPUBPackageDocument.open(url, bookURL: convertedURL)
            officeDocumentURL = nil
            if !FileManager.default.fileExists(atPath: noteURL.path) {
                guard FileManager.default.createFile(atPath: noteURL.path, contents: Data()) else {
                    saveError = "无法在 EPUB 所在文件夹中创建 Markdown 笔记。"
                    return
                }
                createdNote = true
            }
            let note = try documentStore.openDocument(at: noteURL)
            pdfDocument = nil
            pdfSourceURL = nil
            epubDocument = document
            isEPUBNotebook = true
            activateWorkspaceArea(.markdownEditor)
            epubNotebookLayout = .stacked
            maximizedNotebookPane = nil
            epubCurrentChapter = 0
            beginLoadingReadingProfile(for: url, sourceKind: .epub, title: document.title)
            loadOpenedMarkdown(note)
            displayMode = .edit
        } catch {
            if createdNote { try? FileManager.default.removeItem(at: noteURL) }
            saveError = error.localizedDescription
        }
    }

    private func loadDocument(_ url: URL, preservingEPUB: Bool = false, preservingPDF: Bool = false,
                              preservingWeb: Bool = false, preservingOffice: Bool = false) {
        do {
            let document = try documentStore.openDocument(at: url)
            if !preservingEPUB && !preservingPDF && !preservingWeb && !preservingOffice {
                officeDocumentURL = nil
                clearReadingProfileSelection()
                epubDocument = nil
                pdfDocument = nil
                pdfSourceURL = nil
                isEPUBNotebook = false
                webBrowser.close()
            }
            if preservingEPUB { isEPUBNotebook = true; if !usesSwitchDisplay { epubNotebookLayout = .stacked } }
            loadOpenedMarkdown(document)
            if usesSwitchDisplay && hasReadingSource {
                showsNotesTab = true
                epubNotebookLayout = .notes
                displayMode = .read
                activateWorkspaceArea(.markdownPreview)
            }
        } catch {
            requestedHistoryIndex = nil
            saveError = "无法读取文件：\(url.lastPathComponent)（\(error.localizedDescription)）"
        }
    }

    private func loadOpenedMarkdown(_ document: MarkdownDocument) {
        if let previous = selectedFile, previous.standardizedFileURL != document.url.standardizedFileURL {
            MarkdownSourcePositionHub.capture()
            notePositions[previous.standardizedFileURL.path] = (visualScrollState.selection ?? editorSelection, visualScrollState.viewport)
        }
        let target = document.url.standardizedFileURL
        if let index = requestedHistoryIndex, noteHistory.indices.contains(index), noteHistory[index] == target {
            noteHistoryIndex = index
        } else if noteHistoryIndex < 0 || !noteHistory.indices.contains(noteHistoryIndex) || noteHistory[noteHistoryIndex] != target {
            if noteHistoryIndex + 1 < noteHistory.count { noteHistory.removeSubrange((noteHistoryIndex + 1)..<noteHistory.count) }
            noteHistory.append(target)
            noteHistoryIndex = noteHistory.count - 1
        }
        requestedHistoryIndex = nil
        let session = documentSessions.adoptMarkdown(document.url, text: document.source)
        source = session.text
        savedSource = session.savedText
        selectedFile = document.url
        activeWorkspaceMarkdownURL = session.url
        sidebarOutlineTab = .markdown
        visualScrollState.reset(for: document.url)
        visualScrollState.activeMode = isShowingSourceOnly ? .source : .visual
        if let position = notePositions[target.path] {
            editorSelection = position.0
            visualScrollState.selection = position.0
            visualScrollState.viewport = position.1
            visualRestoreRequest += 1
            sourcePositionRestoreRequest += 1
        } else { editorSelection = NSRange(location: 0, length: 0) }
        noteTreeRevision += 1
        if !hasReadingSource {
            documentTitle = document.title
            displayMode = usesSwitchDisplay ? .read : .split
        }
        scrollTarget = nil
        synchronizedSourceLine = 1
        sourceLineRequest += 1
        visualSourceLineRequest += 1
        // Long notes must not block the open-file event on the main thread.
        // The debounced parser publishes headings after the first frame.
        blocks = []
        parsedSource = ""
        headings = []
        expandedHeadings = []
        refreshOutlineImmediately(for: session)
        recordRecentWorkspace()
    }

    private func openPDF(_ url: URL) {
        guard let document = PDFDocument(url: url) else {
            saveError = "无法读取 PDF 文件：\(url.lastPathComponent)"
            return
        }
        if document.isLocked {
            pendingPDFURL = url
            pdfPassword = ""
            showPDFPasswordPrompt = true
            return
        }
        installPDF(document, from: url)
    }

    private func unlockPendingPDF() {
        guard let url = pendingPDFURL, let document = PDFDocument(url: url) else {
            pendingPDFURL = nil
            saveError = "无法读取 PDF 文件。"
            return
        }
        guard !document.isLocked || document.unlock(withPassword: pdfPassword) else {
            pdfPassword = ""
            saveError = "密码不正确，请重试。"
            DispatchQueue.main.async { showPDFPasswordPrompt = true }
            return
        }
        pdfPassword = ""
        pendingPDFURL = nil
        suppressRecentRecording = pendingRecentWorkspace != nil
        installPDF(document, from: url)
        suppressRecentRecording = false
        finishPendingRecentWorkspace()
    }

    private func installPDF(_ document: PDFDocument, from url: URL) {
        officeDocumentURL = nil
        guard document.pageCount > 0 else {
            saveError = "这个 PDF 没有可显示的页面。"
            return
        }
        if activeBookURL?.standardizedFileURL != url.standardizedFileURL { flushCurrentReadingProfile() }
        pdfDocument = document
        pdfSourceURL = url
        pdfCurrentPage = 0
        pdfReadingPosition = nil
        pdfPageInput = "1"
        pdfNavigationRequest += 1
        pdfZoomPercent = 100
        activateWorkspaceArea(.pdf)
        epubDocument = nil
        isEPUBNotebook = false
        epubHasChanges = false
        epubCurrentChapter = 0
        maximizedNotebookPane = nil
        epubNotebookLayout = usesSwitchDisplay ? .epub : .stacked
        showsNotesTab = false
        documentTitle = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
            ?? url.deletingPathExtension().lastPathComponent
        beginLoadingReadingProfile(for: url, sourceKind: .pdf, title: documentTitle)
        displayMode = .edit
        activateCompanionNote(for: url, selectNote: false)
        recordRecentWorkspace()
    }

    private func navigatePDF(to pageIndex: Int) {
        guard let pdfDocument, pdfDocument.pageCount > 0 else { return }
        pdfCurrentPage = min(pdfDocument.pageCount - 1, max(0, pageIndex))
        pdfNavigationRequest += 1
    }

    private func navigateEPUBChapter(by offset: Int) {
        guard let epubDocument else { return }
        let target = epubCurrentChapter + offset
        guard epubDocument.chapters.indices.contains(target) else { return }
        epubCurrentChapter = target
        epubTargetFragment = nil
        epubSelection = nil
        epubAnnotationJumpID = nil
        epubNavigationRequest += 1
    }

    private func commitReaderWidthInput() {
        let parsed = Double(readerWidthInput) ?? readerWidth
        let bounded = parsed.isFinite ? min(1040, max(520, parsed)) : readerWidth
        readerWidth = (bounded / 20).rounded() * 20
        readerWidthInput = "\(Int(readerWidth))"
    }

    private func commitActiveContentWidthInput() {
        let parsed = Double(activeContentWidthInput.wrappedValue) ?? activeContentWidth
        let bounded = parsed.isFinite ? min(1040, max(520, parsed)) : activeContentWidth
        activeContentWidthBinding.wrappedValue = (bounded / 20).rounded() * 20
        activeContentWidthInput.wrappedValue = "\(Int(activeContentWidth))"
    }

    private func scheduleWorkspaceWidthSave(_ width: CGFloat) {
        guard width.isFinite, width > 0 else { return }
        notebookRightPaneWidth = max(320, Double(width))
    }

    private func scheduleWorkspaceHeightSave(_ topHeight: CGFloat, availableHeight: CGFloat) {
        guard topHeight.isFinite, availableHeight.isFinite, availableHeight > 0 else { return }
        splitHeightSaveTask?.cancel()
        splitHeightSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            notebookVerticalRatio = min(0.85, max(0.15, Double(topHeight / availableHeight)))
        }
    }

    private func commitOfficeZoomInput() {
        let parsed = Double(officeZoomInput.replacingOccurrences(of: "%", with: "")) ?? officeZoomPercent
        officeZoomPercent = parsed.isFinite ? min(500, max(25, parsed)) : officeZoomPercent
        officeZoomInput = "\(Int(officeZoomPercent))"
    }

    private func commitWebZoomInput() {
        let parsed = Double(webZoomInput.replacingOccurrences(of: "%", with: "")) ?? webZoomPercent
        let bounded = parsed.isFinite ? min(200, max(50, parsed)) : webZoomPercent
        webZoomPercent = bounded.rounded()
        webZoomInput = "\(Int(webZoomPercent))"
    }

    private func reloadWebBookmarks(reportError: Bool = false) {
        webBookmarkReloadGeneration += 1
        guard !webBookmarkReloadInFlight else { return }
        webBookmarkReloadInFlight = true
        let generation = webBookmarkReloadGeneration
        let root = readingLibrary.rootURL
        let cloud = readingLibrary.isUsingICloudDrive
        let device = readingLibrary.deviceID
        Task {
            let result = await Task.detached(priority: .utility) {
                Result { try ReadingLibraryStore(rootURL: root, isUsingICloudDrive: cloud, deviceID: device).loadWebBookmarks() }
            }.value
            webBookmarkReloadInFlight = false
            guard generation == webBookmarkReloadGeneration else {
                reloadWebBookmarks(reportError: reportError)
                return
            }
            switch result {
            case .success(let bookmarks): webBookmarks = bookmarks
            case .failure(let error):
                if reportError { saveError = "无法读取 iCloud 网页收藏：\(error.localizedDescription)" }
            }
        }
    }

    private func beginBookmarkCurrentPage() {
        guard let url = webBrowser.currentURL else { return }
        let bookmark = webBookmarks.first(where: { $0.urlString == url.absoluteString })
            ?? WebBookmark(title: webBrowser.title, urlString: url.absoluteString)
        activeSheet = .webBookmark(bookmark)
    }

    private func beginEditBookmark(_ bookmark: WebBookmark) {
        activeSheet = .webBookmark(bookmark)
    }

    private func saveWebBookmark(_ bookmark: WebBookmark) {
        do {
            try readingLibrary.saveWebBookmarks([bookmark])
            reloadWebBookmarks()
        } catch { saveError = "无法保存网页收藏：\(error.localizedDescription)" }
    }

    private func deleteWebBookmark(_ bookmark: WebBookmark) {
        var deleted = bookmark
        deleted.isDeleted = true
        deleted.updatedAt = Date()
        do {
            try readingLibrary.saveWebBookmarks([deleted])
            reloadWebBookmarks()
        } catch { saveError = "无法删除网页收藏：\(error.localizedDescription)" }
    }

    private func clipWebSelection() {
        webBrowser.captureSelection { clip in
            guard let clip else {
                Task { @MainActor in saveError = "请先在网页上选择要剪藏的文字。" }
                return
            }
            Task { @MainActor in appendWebClip(clip) }
        }
    }

    private func appendWebClip(_ clip: WebPageClip) {
        guard let url = webBrowser.currentURL else { return }
        if selectedFile == nil {
            guard createMarkdownNote() else {
                saveError = "请先新建或打开一个 Markdown 笔记，再剪藏网页文字。"
                return
            }
        }
        guard selectedFile != nil else { return }
        MarkdownSourcePositionHub.flushPendingChanges()
        source = WebClipFormatter.append(clip, title: webBrowser.title, url: url, to: source)
        let end = (source as NSString).length
        editorSelection = NSRange(location: end, length: 0)
        synchronizedSourceLine = source.components(separatedBy: "\n").count
        sourceLineRequest += 1
        visualSourceLineRequest += 1
        editorFocusRequest += 1
        if epubNotebookLayout == .epub { epubNotebookLayout = usesSwitchDisplay ? .notes : .stacked; showsNotesTab = usesSwitchDisplay }
        activateWorkspaceArea(.markdownEditor)
    }

    private func requestPDFDisplayPreset(_ preset: PDFDisplayPreset) {
        pdfDisplayPresetRequest = PDFDisplayPresetRequest(
            sequence: pdfDisplayPresetRequest.sequence &+ 1, preset: preset)
    }

    private func commitPDFZoomInput() {
        let parsed = Double(pdfZoomInput.replacingOccurrences(of: "%", with: "")) ?? pdfZoomPercent
        let bounded = parsed.isFinite ? min(1000, max(25, parsed)) : pdfZoomPercent
        pdfZoomPercent = bounded.rounded()
        pdfZoomInput = "\(Int(pdfZoomPercent))"
    }

    private func commitPDFPageInput() {
        let oneBasedPage = Int(pdfPageInput) ?? (pdfCurrentPage + 1)
        navigatePDF(to: oneBasedPage - 1)
        pdfPageInput = "\(pdfCurrentPage + 1)"
    }

    @discardableResult
    private func createMarkdownNote() -> Bool {
        let referenceURL = pdfSourceURL ?? epubDocument?.sourceURL
        let pageTitle = webBrowser.currentURL == nil ? nil : webBrowser.title
        let defaultName = referenceURL.map { $0.deletingPathExtension().lastPathComponent + ".md" }
            ?? pageTitle.map { $0.replacingOccurrences(of: "/", with: "-") + ".md" }
            ?? "新建笔记.md"
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = defaultName
        panel.canCreateDirectories = true
        if let referenceURL { panel.directoryURL = referenceURL.deletingLastPathComponent() }
        else if let selectedFile { panel.directoryURL = selectedFile.deletingLastPathComponent() }
        else if let folderURL { panel.directoryURL = folderURL }
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        if FileManager.default.fileExists(atPath: url.path) {
            open(url)
        } else {
            MarkdownVisualCommandHub.commitActiveEdits {
                if source != savedSource {
                    pendingDocumentOperation = .createNote(url)
                    showUnsavedAlert = true
                } else {
                    performCreateMarkdownNote(at: url)
                }
            }
        }
        return selectedFile == url
    }

    private func performCreateMarkdownNote(at url: URL) {
        guard !FileManager.default.fileExists(atPath: url.path) else {
            performOpen(url)
            return
        }
        guard FileManager.default.createFile(atPath: url.path, contents: Data()) else {
            saveError = "无法创建 Markdown 笔记：\(url.lastPathComponent)"
            return
        }
        loadDocument(url, preservingEPUB: epubDocument != nil,
                     preservingPDF: pdfDocument != nil, preservingWeb: webBrowser.currentURL != nil, preservingOffice: officeDocumentURL != nil)
        if selectedFile != url { try? FileManager.default.removeItem(at: url) }
    }

    private func activateWorkspaceArea(_ area: FocusedWorkspaceArea) {
        focusedWorkspaceArea = area
        if area != .outline { lastContentFocus = area }
        if [.pdf, .epub, .office, .web].contains(area) { lastReadingFocus = area }
        if area != .outline {
            sidebarOutlineTab = [.pdf, .epub, .office, .web].contains(area) ? .reading : .markdown
        }
        if let tab = workspaceTab(matching: area),
           workspaceTabs.groups.contains(where: { $0.selected == tab.id && $0.id != workspaceTabs.activeGroup }) {
            workspaceTabs.select(tab.id)
        }
        switch area {
        case .pdf:
            fontSizeTarget = .pdf
        case .office:
            fontSizeTarget = .office
        case .epub:
            fontSizeTarget = .body
        case .web:
            fontSizeTarget = .web
        case .markdownPreview, .markdownEditor, .markdownReader:
            fontSizeTarget = .body
        case .outline:
            fontSizeTarget = .outline
        }
    }

    private func workspaceFocusRing(_ focused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(focused ? Color.gray.opacity(0.38) : Color.clear, lineWidth: focused ? 1 : 0)
            .padding(2)
            .allowsHitTesting(false)
    }

    private func saveNote() -> Bool {
        MarkdownSourcePositionHub.flushPendingChanges()
        if let url = activeWorkspaceMarkdownURL, let session = documentSessions.session(for: url) {
            if source != session.text { session.text = source }
            session.selection = editorSelection
        }
        guard let selectedFile else { return true }
        let session = documentSessions.session(for: selectedFile) ?? documentSessions.adoptMarkdown(selectedFile, text: source)
        guard saveMarkdownSession(session) else { return false }
        savedSource = session.savedText
        return true
    }

    private func saveMarkdownSession(_ session: WorkspaceMarkdownSession) -> Bool {
        guard session.isDirty else { return true }
        do {
                let removed = MarkdownNoteDeletion.removedChildren(parent: session.url, before: session.savedText, after: session.text)
                if removed.isEmpty {
                    try session.save(using: documentStore)
                } else {
                    let alert = NSAlert()
                    alert.messageText = "删除关联的子笔记？"
                    alert.informativeText = "源码中已移除以下子笔记的最后一个链接：\n\(removed.map { $0.deletingPathExtension().lastPathComponent }.joined(separator: "、"))\n保存时，这些笔记及其下级笔记会移到废纸篓。"
                    alert.addButton(withTitle: "删除并保存")
                    alert.addButton(withTitle: "取消")
                    guard alert.runModal() == .alertFirstButtonReturn else { return false }
                    try MarkdownNoteDeletion.saveRemovingChildren(parent: session.url, before: session.savedText, after: session.text, children: removed)
                    let deletedPaths = removed.map { $0.standardizedFileURL.resolvingSymlinksInPath().path }
                    noteHistory.removeAll { item in
                        let path = item.standardizedFileURL.resolvingSymlinksInPath().path
                        return deletedPaths.contains { path == $0 || path.hasPrefix($0 + ".notes/") }
                    }
                    noteHistoryIndex = noteHistory.lastIndex(of: session.url.standardizedFileURL) ?? max(-1, noteHistory.count - 1)
                    noteTreeRevision += 1
                }
                session.markSaved(session.text)
                if activeWorkspaceMarkdownURL?.standardizedFileURL == session.url.standardizedFileURL { savedSource = session.savedText }
            } catch {
                if error as? WorkspaceMarkdownSession.SaveError == .changedOnDisk {
                    saveError = "文件已被其他程序修改。为避免覆盖外部内容，本次没有保存。"
                } else { saveError = error.localizedDescription }
                return false
            }
        return true
    }

    private func saveAllMarkdownSessions() -> Bool {
        for session in documentSessions.dirtySessions.sorted(by: { $0.url.path < $1.url.path }) {
            guard saveMarkdownSession(session) else { return false }
        }
        return true
    }

    private func saveReadingSource() -> Bool {
        if epubHasChanges, let epubDocument {
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
        return true
    }

    private func saveDocument() -> Bool {
        guard saveNote(), saveAllMarkdownSessions(), saveReadingSource() else { return false }
        return selectedFile != nil || !workspaceTabs.allTabs.isEmpty || epubDocument != nil
    }

    private func savePendingDocumentOperation() -> Bool {
        switch pendingDocumentOperation {
        case .closeNote: saveNote()
        case .closeWorkspaceTab: saveNote()
        case .closeReadingSource: saveReadingSource()
        default: saveDocument()
        }
    }

    private func continuePendingDocumentOperation(discardingChanges: Bool = false) {
        let operation = pendingDocumentOperation
        pendingDocumentOperation = nil
        switch operation {
        case .open(let url, let importIntoWorkspace): performOpen(url, importIntoWorkspace: importIntoWorkspace)
        case .openWorkspace(let url): performOpenWorkspace(url)
        case .openProjectFolder(let url): performOpenProjectFolder(url)
        case .createWorkspace: presentCreateWorkspacePanel()
        case .navigateNote(let url, let index): requestedHistoryIndex = index; performOpen(url)
        case .openRecentWorkspace(let workspace): performOpenRecentWorkspace(workspace)
        case .createNote(let url): performCreateMarkdownNote(at: url)
        case .openEPUBNote(let url, let convertedURL): performOpenEPUBNote(url, convertedURL: convertedURL)
        case .closeNote: clearNoteDocument()
        case .closeWorkspaceTab(let id): finishClosingWorkspaceTab(id, discard: discardingChanges)
        case .closeReadingSource: clearReadingSource()
        case .closeWindow:
            if let window = pendingWindowToClose { finishWindowClose(window) }
            pendingWindowToClose = nil
        case .terminate: awaitReadingProfileBeforeTermination()
        case nil: break
        }
    }

    private func awaitReadingProfileBeforeTermination() {
        Task { @MainActor in
            if activeBookURL != nil { await flushCurrentReadingProfileAsync() }
            NSApp.reply(toApplicationShouldTerminate: true)
        }
    }

    private func cancelPendingTermination() {
        let shouldReply = if case .terminate = pendingDocumentOperation { true } else { false }
        pendingDocumentOperation = nil
        pendingWorkspaceFileDrop = nil
        pendingWindowToClose = nil
        if shouldReply { NSApp.reply(toApplicationShouldTerminate: false) }
    }

    private func requestWindowClose(_ window: NSWindow) {
        MarkdownVisualCommandHub.commitActiveEdits {
            if isDirty {
                pendingWindowToClose = window
                pendingDocumentOperation = .closeWindow
                showUnsavedAlert = true
            } else {
                finishWindowClose(window)
            }
        }
    }

    private func finishWindowClose(_ window: NSWindow) {
        Task { @MainActor in
            if activeBookURL != nil { await flushCurrentReadingProfileAsync() }
            window.close()
        }
    }

    private func closeFile() {
        if focusedWorkspaceArea == .outline {
            switch sidebarOutlineTab {
            case .files: closeFolder()
            case .reading: closeReadingSource()
            case .markdown: closeNote()
            case .webBookmarks: closeCurrentWebTab()
            }
        } else if [.pdf, .epub, .web, .office].contains(focusedWorkspaceArea) {
            closeReadingSource()
        } else if selectedFile != nil {
            closeNote()
        } else {
            closeReadingSource()
        }
    }

    private var canCloseSidebarSelection: Bool {
        switch sidebarOutlineTab {
        case .files: folderURL != nil || !workspaceFiles.isEmpty
        case .reading: hasReadingSource
        case .markdown: selectedFile != nil
        case .webBookmarks: webBrowser.currentURL != nil
        }
    }

    private var sidebarCloseTitle: String {
        switch sidebarOutlineTab {
        case .files: "关闭文件夹"
        case .reading: "关闭阅读源"
        case .markdown: "关闭 Markdown 笔记"
        case .webBookmarks: "关闭当前网页"
        }
    }

    private func closeSidebarSelection() {
        switch sidebarOutlineTab {
        case .files: closeFolder()
        case .reading: closeReadingSource()
        case .webBookmarks: closeCurrentWebTab()
        case .markdown: closeNote()
        }
    }

    private func closeReadingSource() {
        if focusedWorkspaceArea == .web || (focusedWorkspaceArea == .outline && lastReadingFocus == .web) {
            closeCurrentWebTab(); return
        }
        closeBookSource()
    }

    private func closeCurrentWebTab() {
        guard let id = webSessions.activeID else { return }
        webSessions.close(id)
        workspaceTabs.remove(id)
    }

    private func closeBookSource() {
        if isConvertingKindle {
            kindleConversionTask?.cancel()
            kindleConversionTask = nil
            kindleConversionRevision += 1
            isConvertingKindle = false
            pendingRecentWorkspace = nil
            return
        }
        guard hasBookSource else { return }
        if epubHasChanges {
            pendingDocumentOperation = .closeReadingSource
            showUnsavedAlert = true
        } else {
            clearReadingSource()
        }
    }

    private func closeNote() {
        MarkdownVisualCommandHub.commitActiveEdits {
            guard selectedFile != nil else { return }
            if source != savedSource {
                pendingDocumentOperation = .closeNote
                showUnsavedAlert = true
            } else {
                clearNoteDocument()
            }
        }
    }

    private func clearNoteDocument() {
        selectedFile = nil
        source = ""
        savedSource = ""
        blocks = []
        headings = []
        parsedSource = ""
        expandedHeadings = []
        scrollTarget = nil
        synchronizedSourceLine = 1
        sourceLineRequest += 1
        visualSourceLineRequest += 1
        editorSelection = NSRange(location: 0, length: 0)
        if epubDocument != nil { isEPUBNotebook = false }
        if let officeDocumentURL {
            documentTitle = officeDocumentURL.deletingPathExtension().lastPathComponent
        } else if let pdfDocument {
            documentTitle = pdfDocument.documentURL?.deletingPathExtension().lastPathComponent ?? "PDF 阅读"
        } else if let epubDocument {
            documentTitle = epubDocument.title
        } else if webBrowser.currentURL != nil {
            documentTitle = webBrowser.title
        } else {
            documentTitle = "选择一个 Markdown 文件开始阅读"
        }
    }

    private func clearReadingSource() {
        officeDocumentURL = nil
        officePreviewState.clear()
        clearReadingProfileSelection()
        pdfDocument = nil
        pdfSourceURL = nil
        epubDocument = nil
        epubHasChanges = false
        isEPUBNotebook = false
        pdfCurrentPage = 0
        pdfReadingPosition = nil
        pdfNavigationRequest += 1
        maximizedNotebookPane = nil
        activateWorkspaceArea(selectedFile == nil ? .markdownReader : .markdownPreview)
        if let selectedFile {
            documentTitle = selectedFile.deletingPathExtension().lastPathComponent
            displayMode = usesSwitchDisplay ? .read : .split
        } else {
            documentTitle = "选择一个 Markdown 文件开始阅读"
        }
    }

    private func closeFolder() {
        guard folderURL != nil || !workspaceFiles.isEmpty || !markdownFiles.isEmpty else { return }
        folderURL = nil
        workspaceFolders = []
        workspaceFiles = []
        workspaceReadingNotes = []
        workspaceFileURL = nil
        currentWorkspacePath = ""
        workspaceHasMissingReferences = false
        markdownFiles = []
        showFolderContents = true
        lastFolderPath = ""
        if selectedFile == nil {
            documentTitle = "选择一个 Markdown 文件开始阅读"
        }
    }

    private func insertHorizontalRule() {
        if applyVisualCommand("rule") { return }
        guard selectedFile != nil, canEditMarkdownSource else { return }
        MarkdownSourcePositionHub.flushPendingChanges()
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
        visualSourceLineRequest += 1
        editorFocusRequest += 1
    }

    private func applyHeadingLevel(_ level: Int) {
        if applyVisualCommand("heading", value: String(level)) { return }
        guard (1...6).contains(level), selectedFile != nil, canEditMarkdownSource else { return }
        MarkdownSourcePositionHub.flushPendingChanges()
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
        let visualName: String? = switch opening {
        case "**": "bold"
        case "*": "italic"
        case "<u>": "underline"
        case "~~": "strikeThrough"
        case "`": "code"
        case "[": "link"
        default: nil
        }
        if let visualName, applyVisualCommand(visualName) { return }
        guard selectedFile != nil, canEditMarkdownSource else { return }
        MarkdownSourcePositionHub.flushPendingChanges()
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
        let visualName: String? = switch prefix {
        case "- ": "unordered"
        case "1. ": "ordered"
        case "- [ ] ": "task"
        case "> ": "quote"
        default: nil
        }
        if let visualName, applyVisualCommand(visualName) { return }
        guard selectedFile != nil, canEditMarkdownSource else { return }
        MarkdownSourcePositionHub.flushPendingChanges()
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
        guard selectedFile != nil, canEditMarkdownSource else { return }
        MarkdownSourcePositionHub.flushPendingChanges()
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
        if applyVisualCommand("paragraph") { return }
        guard selectedFile != nil, canEditMarkdownSource else { return }
        MarkdownSourcePositionHub.flushPendingChanges()
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
        guard selectedFile != nil, canEditMarkdownSource else { return }
        MarkdownSourcePositionHub.flushPendingChanges()
        let original = source as NSString
        let location = min(editorSelection.location, original.length)
        let length = min(editorSelection.length, original.length - location)
        source = original.replacingCharacters(in: NSRange(location: location, length: length), with: template)
        editorSelection = NSRange(location: location + (template as NSString).length, length: 0)
        editorFocusRequest += 1
    }

    private func pasteImage(_ pasteboard: NSPasteboard, into textView: NSTextView) -> Bool {
        guard let selectedFile else { return false }
        do {
            guard let markdown = try MarkdownImageAssets.importClipboard(pasteboard, beside: selectedFile) else { return false }
            let range = textView.selectedRange()
            let insertion = MarkdownImageAssets.blockInsertion(markdown, in: textView.string, replacing: range)
            textView.insertText(insertion, replacementRange: range)
            return true
        } catch {
            saveError = "无法粘贴图片：\(error.localizedDescription)"
            return true
        }
    }

    private func insertImageFile() {
        guard let selectedFile else {
            saveError = "请先打开或新建 Markdown 笔记，再插入图片。"
            return
        }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif]
        panel.allowsMultipleSelection = false
        panel.directoryURL = selectedFile.deletingLastPathComponent()
        guard panel.runModal() == .OK, let imageURL = panel.url else { return }
        do {
            let markdown = try MarkdownImageAssets.importFile(imageURL, beside: selectedFile)
            if applyVisualCommand("imageMarkdown", value: markdown) { return }
            MarkdownSourcePositionHub.flushPendingChanges()
            let original = source as NSString
            let location = min(editorSelection.location, original.length)
            let length = min(editorSelection.length, original.length - location)
            let range = NSRange(location: location, length: length)
            let insertion = MarkdownImageAssets.blockInsertion(markdown, in: source, replacing: range)
            source = original.replacingCharacters(in: range, with: insertion)
            editorSelection = NSRange(location: location + (insertion as NSString).length, length: 0)
            if displayMode == .read { displayMode = .edit }
            if epubNotebookLayout == .epub { epubNotebookLayout = usesSwitchDisplay ? .notes : .stacked; showsNotesTab = usesSwitchDisplay }
            editorFocusRequest += 1
        } catch {
            saveError = "无法插入图片：\(error.localizedDescription)"
        }
    }

    private func importVisualClipboardImage(_ pasteboard: NSPasteboard) -> String? {
        guard let selectedFile else { return nil }
        do {
            return try MarkdownImageAssets.importClipboard(pasteboard, beside: selectedFile)
        } catch {
            saveError = "无法粘贴图片：\(error.localizedDescription)"
            return nil
        }
    }

    private func scheduleParse(for text: String) {
        parseTask?.cancel()
        parseTask = Task { @MainActor in
            // Parsing a long document while source typing resumes competes with
            // the input method and layout work. Wait for a genuine pause.
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            let parsed = await Task.detached(priority: .userInitiated) { MarkdownBlock.parse(text) }.value
            guard !Task.isCancelled, source == text else { return }
            blocks = parsed
            parsedSource = text
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
                    Image(systemName: expanded.contains(heading.id) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold)).frame(width: 22, height: 26)
                        .foregroundStyle(.tertiary)
                } else { Spacer().frame(width: 22, height: 26) }
                    Text(heading.title ?? "").lineLimit(2).multilineTextAlignment(.leading)
                        .font(tocFont)
                        .lineSpacing(levelIndex < 2 ? 2 : 1)
                        .foregroundStyle(Color(hex: outlineColors[levelIndex]))
                        .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
                        .padding(.vertical, 2)
            }
            .padding(.leading, CGFloat(levelIndex * 14))
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { toggleExpansion() }
            .onTapGesture(count: 1) { onSelect(heading.id) }
            if expanded.contains(heading.id) {
                ForEach(children) { child in
                    HeadingRow(heading: child, allHeadings: allHeadings, expanded: $expanded,
                               styles: styles, outlineColors: outlineColors, fontScale: fontScale, onSelect: onSelect)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .listRowBackground(Color.clear)
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
    let scopeTitle: String
    let isReadingScope: Bool
    let isSourceScope: Bool
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
    let readingDataLocation: String
    let embedded: Bool
    let onDone: () -> Void
    @State private var styles: [HeadingStyle]
    @State private var outlineColors: [String]
    private let families = ["系统默认", "PingFang SC", "Songti SC", "Heiti SC", "SF Pro Text", "Avenir Next", "Georgia", "Menlo"]

    init(scopeTitle: String, isReadingScope: Bool, isSourceScope: Bool,
         readerWidth: Binding<Double>, bodyColorHex: Binding<String>, readerBackgroundHex: Binding<String>, strongColorHex: Binding<String>, strongSize: Binding<Double>, strongFamily: Binding<String>, headingStylesData: Binding<Data>, bodySize: Binding<Double>, bodyFamily: Binding<String>, lineHeight: Binding<Double>, paragraphSpacing: Binding<Double>, outlineColorsData: Binding<Data>, annotationFontSize: Binding<Double>, annotationFontFamily: Binding<String>, annotationTextColorHex: Binding<String>, readingDataLocation: String, onDone: @escaping () -> Void) {
        self.scopeTitle = scopeTitle
        self.isReadingScope = isReadingScope
        self.isSourceScope = isSourceScope
        _readerWidth = readerWidth; _strongColorHex = strongColorHex; _strongSize = strongSize
        _bodyColorHex = bodyColorHex
        _readerBackgroundHex = readerBackgroundHex
        _strongFamily = strongFamily; _headingStylesData = headingStylesData
        _bodySize = bodySize; _bodyFamily = bodyFamily; _lineHeight = lineHeight; _paragraphSpacing = paragraphSpacing
        _outlineColorsData = outlineColorsData
        _annotationFontSize = annotationFontSize
        _annotationFontFamily = annotationFontFamily
        _annotationTextColorHex = annotationTextColorHex
        self.readingDataLocation = readingDataLocation
        self.embedded = false
        self.onDone = onDone
        _styles = State(initialValue: (try? JSONDecoder().decode([HeadingStyle].self, from: headingStylesData.wrappedValue)) ?? HeadingStyle.defaults)
        _outlineColors = State(initialValue: (try? JSONDecoder().decode([String].self, from: outlineColorsData.wrappedValue)) ?? Array(repeating: "#222222", count: 6))
    }

    init(scopeTitle: String, isReadingScope: Bool, isSourceScope: Bool,
         readerWidth: Binding<Double>, bodyColorHex: Binding<String>, readerBackgroundHex: Binding<String>, strongColorHex: Binding<String>, strongSize: Binding<Double>, strongFamily: Binding<String>, headingStylesData: Binding<Data>, bodySize: Binding<Double>, bodyFamily: Binding<String>, lineHeight: Binding<Double>, paragraphSpacing: Binding<Double>, outlineColorsData: Binding<Data>, annotationFontSize: Binding<Double>, annotationFontFamily: Binding<String>, annotationTextColorHex: Binding<String>, readingDataLocation: String, embedded: Bool, onDone: @escaping () -> Void) {
        self.scopeTitle = scopeTitle
        self.isReadingScope = isReadingScope
        self.isSourceScope = isSourceScope
        _readerWidth = readerWidth; _strongColorHex = strongColorHex; _strongSize = strongSize
        _bodyColorHex = bodyColorHex
        _readerBackgroundHex = readerBackgroundHex
        _strongFamily = strongFamily; _headingStylesData = headingStylesData
        _bodySize = bodySize; _bodyFamily = bodyFamily; _lineHeight = lineHeight; _paragraphSpacing = paragraphSpacing
        _outlineColorsData = outlineColorsData
        _annotationFontSize = annotationFontSize
        _annotationFontFamily = annotationFontFamily
        _annotationTextColorHex = annotationTextColorHex
        self.readingDataLocation = readingDataLocation
        self.embedded = embedded
        self.onDone = onDone
        _styles = State(initialValue: (try? JSONDecoder().decode([HeadingStyle].self, from: headingStylesData.wrappedValue)) ?? HeadingStyle.defaults)
        _outlineColors = State(initialValue: (try? JSONDecoder().decode([String].self, from: outlineColorsData.wrappedValue)) ?? Array(repeating: "#222222", count: 6))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !embedded {
                HStack { Text(scopeTitle).font(.system(size: 18, weight: .semibold)); Spacer(); Button("完成") { save(); onDone() }.keyboardShortcut(.defaultAction) }
            } else {
                Text(scopeTitle).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            }
            Form {
                Section("正文") {
                    LabeledContent(isSourceScope ? "编辑宽度" : "阅读宽度", value: "\(Int(readerWidth)) px")
                    Slider(value: $readerWidth, in: 520...1040, step: 20)
                    HStack {
                        Text(isSourceScope ? "编辑背景颜色" : "阅读背景颜色"); Spacer()
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
                    if !isSourceScope {
                        Picker("加粗文字字体", selection: $strongFamily) {
                            ForEach(families, id: \.self) { Text($0).font(.custom($0, size: 12)).tag($0) }
                        }
                        LabeledContent("加粗文字字号", value: "\(Int(strongSize)) pt")
                        Slider(value: $strongSize, in: 13...22, step: 1)
                    }
                }
                if isReadingScope { Section("EPUB 注释文字") {
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
                } }
                if isReadingScope { Section("跨设备阅读资料") {
                    LabeledContent("保存位置", value: readingDataLocation)
                    Text("此处保存书籍标识、阅读位置、阅读样式、EPUB 批注和网页收藏。原书与 Markdown 笔记文件保留在原位置。使用 iCloud Drive 时，这些阅读资料会随 iCloud 同步。")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } }
                Section("标题样式") {
                    ForEach($styles) { $style in
                        HStack(spacing: 10) {
                            Text("H\(style.id)").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.secondary).frame(width: 25)
                            ColorPicker("", selection: Binding(get: { Color(hex: style.colorHex) }, set: { style.colorHex = $0.hexString }), supportsOpacity: false).labelsHidden()
                            if !isSourceScope {
                                Picker("字体", selection: $style.fontFamily) {
                                    ForEach(families, id: \.self) { Text($0).font($0 == "系统默认" ? .system(size: 12) : .custom($0, size: 12)).tag($0) }
                                }.labelsHidden().frame(width: 130)
                                Slider(value: $style.size, in: 13...(isReadingScope ? 40 : 60), step: 1).frame(width: 95)
                                Text("\(Int(style.size))").font(.system(size: 10, design: .rounded).monospacedDigit()).foregroundStyle(.tertiary).frame(width: 22)
                                Toggle("粗体", isOn: $style.bold).labelsHidden().toggleStyle(.switch).scaleEffect(0.75)
                            }
                        }
                    }
                }
                if !isSourceScope { Section("目录文字颜色") {
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
                } }
            }.formStyle(.grouped)
            HStack {
                Spacer()
                Button(isReadingScope ? "恢复阅读默认设置" : "恢复此视图默认设置") { restoreDefaults() }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, embedded ? 12 : 22)
        .padding(.bottom, 22)
        .frame(width: 640, height: embedded ? 740 : 760)
        .onDisappear(perform: save)
    }
    private func restoreDefaults() {
        styles = HeadingStyle.defaults
        strongColorHex = "#A5563A"
        bodyColorHex = "#282725"
        readerBackgroundHex = "#FFFFFF"
        strongSize = 15
        if !isReadingScope && !isSourceScope {
            for index in styles.indices {
                if let size = MarkdownDisplayStyle.previewHeadingSizes[styles[index].id] {
                    styles[index].size = size
                }
            }
            strongSize = 18
        }
        strongFamily = "系统默认"
        if isReadingScope {
            annotationFontSize = 11
            annotationFontFamily = "系统默认"
            annotationTextColorHex = "#777777"
        }
        bodySize = 15
        bodyFamily = "系统默认"
        lineHeight = isSourceScope ? 1.4 : 1.85
        paragraphSpacing = isSourceScope ? 8 : 13
        readerWidth = 720
        outlineColors = Array(repeating: "#222222", count: 6)
        save()
    }
    private func save() {
        headingStylesData = (try? JSONEncoder().encode(styles)) ?? Data()
        outlineColorsData = (try? JSONEncoder().encode(outlineColors)) ?? Data()
    }
}



private struct WorkspacePaneHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
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

extension View {
    func toolbarHint(_ text: String) -> some View {
        help(text)
    }
}
