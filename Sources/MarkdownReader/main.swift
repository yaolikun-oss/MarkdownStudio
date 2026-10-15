import EPUBCore
import AppKit
import PDFKit
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
                    .keyboardShortcut("0", modifiers: [.command, .option])
            }
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("打开文件…") { ReaderActions.openFile() }
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
            CommandMenu("阅读工作区") {
                Button("只看原文") { ReaderActions.setEPUBNotebookLayout(.epub) }
                    .keyboardShortcut("1", modifiers: [.command, .control])
                Button("只看 Markdown 笔记") { ReaderActions.setEPUBNotebookLayout(.notes) }
                    .keyboardShortcut("2", modifiers: [.command, .control])
                Button("阅读 + 笔记预览 + 编辑") { ReaderActions.setEPUBNotebookLayout(.stacked) }
                    .keyboardShortcut("3", modifiers: [.command, .control])
                Divider()
                Button("最大化原文面板") { ReaderActions.maximizeEPUBNotebookPane(.epub) }
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
    static var closeFolderHandler: (() -> Void)?
    static var terminationHandler: (() -> NSApplication.TerminateReply)?
    static var sidebarVisible = true
    static func reopenWindow() { reopenWindowHandler?() }
    static func openFile() { openFileHandler?() }
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
    static func closeFolder() { closeFolderHandler?() }
    static func requestTermination() -> NSApplication.TerminateReply {
        terminationHandler?() ?? .terminateNow
    }
}

private enum PendingDocumentOperation {
    case open(URL)
    case openFolder(URL)
    case closeFile
    case closePDF
    case closeWeb
    case terminate
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

private enum PDFNotesLayout: String, CaseIterable {
    case split, preview, editor

    var title: String {
        switch self {
        case .split: "分屏"
        case .preview: "预览占右侧"
        case .editor: "编辑占右侧"
        }
    }
}

private enum FocusedWorkspaceArea {
    case pdf, epub, web, markdownPreview, markdownEditor, markdownReader, outline
}

private enum SidebarOutlineTab: String, CaseIterable {
    case reading, markdown, webBookmarks

    var title: String {
        switch self {
        case .reading: "阅读"
        case .markdown: "Markdown"
        case .webBookmarks: "网页收藏"
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
    case pdf, web
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
        ReaderActions.openDocument(url)
    }
}

struct ReaderView: View {
    @Environment(\.openWindow) private var openWindow
    private let documentStore = LocalMarkdownDocumentStore()
    @AppStorage("reader.width") private var readerWidth = 720.0
    @AppStorage("epub.readerWidth") private var epubReaderWidth = 720.0
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
    @AppStorage("pdf.zoomPercent") private var pdfZoomPercent = 100.0
    @AppStorage("web.zoomPercent") private var webZoomPercent = 100.0
    @AppStorage("pdf.notesPaneWidth") private var notebookRightPaneWidth = 720.0
    @AppStorage("pdf.notesVerticalRatio") private var notebookVerticalRatio = 0.5

    @State private var readingLibrary = ReadingLibraryStore.makeDefault()
    @StateObject private var webBrowser = WebBrowserSession()
    @State private var webBookmarks: [WebBookmark] = []
    @State private var activeSheet: ReaderSheetRoute?
    @State private var currentBookID: String?
    @State private var currentBookProfile: BookReadingProfile?
    @State private var savedEPUBPosition: SavedReadingPosition?
    @State private var epubPositionRestoreRequest = 0
    @State private var identityLoadTask: Task<Void, Never>?

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
    @State private var showSidebar = true
    @State private var fontSizeTarget: FontSizeTarget = .body
    @State private var focusedWorkspaceArea: FocusedWorkspaceArea = .markdownReader
    @State private var sidebarOutlineTab: SidebarOutlineTab = .markdown
    @State private var showFolderContents = true
    @State private var scrollTarget: String?
    @State private var scrollRequest = 0
    @State private var synchronizedSourceLine = 1
    @State private var sourceLineRequest = 0
    @State private var editorFocusRequest = 0
    @State private var readerWidthInput = "720"
    @State private var epubReaderWidthInput = "720"
    @State private var pdfZoomInput = "100"
    @State private var webZoomInput = "100"
    @State private var pdfPageInput = "1"
    @State private var focusEditorAfterTableInsert = false
    @State private var displayMode: ReaderDisplayMode = .read
    @State private var parseTask: Task<Void, Never>?
    @State private var pendingDocumentOperation: PendingDocumentOperation?
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
    @State private var showEPUBModeChoice = false
    @State private var isEPUBNotebook = false
    @State private var epubNotebookLayout: EPUBNotebookLayout = .stacked
    @State private var maximizedNotebookPane: EPUBNotebookPane?
    @State private var splitWidthSaveTask: Task<Void, Never>?
    @State private var splitHeightSaveTask: Task<Void, Never>?
    @State private var sidebarWidthSaveTask: Task<Void, Never>?

    private var pdfZoomControlIsActive: Bool {
        pdfDocument != nil && focusedWorkspaceArea == .pdf
    }

    private var webZoomControlIsActive: Bool {
        webBrowser.currentURL != nil && focusedWorkspaceArea == .web
    }

    private var documentZoomControlIsActive: Bool { pdfZoomControlIsActive || webZoomControlIsActive }

    private var visibleSidebarTabs: [SidebarOutlineTab] {
        [.reading, .markdown, .webBookmarks]
    }

    private var epubWidthControlIsActive: Bool {
        focusedWorkspaceArea == .epub && (epubDocument != nil || isEPUBNotebook)
    }

    private var activeContentWidthBinding: Binding<Double> {
        epubWidthControlIsActive ? $epubReaderWidth : $readerWidth
    }

    private var activeContentWidthInput: Binding<String> {
        Binding(get: { epubWidthControlIsActive ? epubReaderWidthInput : readerWidthInput },
                set: { if epubWidthControlIsActive { epubReaderWidthInput = $0 } else { readerWidthInput = $0 } })
    }

    private var activeContentWidth: Double { epubWidthControlIsActive ? epubReaderWidth : readerWidth }

    private var pdfNotesLayout: PDFNotesLayout {
        switch maximizedNotebookPane {
        case .rightPreview: .preview
        case .rightEditor: .editor
        default: .split
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
        HSplitView {
            if showSidebar {
                sidebar
                    .frame(minWidth: 190, idealWidth: sidebarWidth, maxWidth: 480)
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: SidebarWidthPreferenceKey.self, value: proxy.size.width)
                    })
            }
            VStack(spacing: 0) {
                toolbar
                Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
                documentPane
            }
        }
        .onPreferenceChange(SidebarWidthPreferenceKey.self, perform: scheduleSidebarWidthSave)
        .background {
            EPUBArrowKeyMonitor(isEnabled: epubDocument != nil && focusedWorkspaceArea == .epub
                                && (isEPUBNotebook || displayMode == .read)) { offset in
                navigateEPUBChapter(by: offset)
            }
            .frame(width: 0, height: 0)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
                SettingsView(readerWidth: $readerWidth, bodyColorHex: $bodyColorHex, readerBackgroundHex: $readerBackgroundHex,
                             strongColorHex: $strongColorHex, strongSize: $strongSize, strongFamily: $strongFamily,
                             headingStylesData: $headingStylesData, bodySize: $bodySize, bodyFamily: $bodyFamily,
                             lineHeight: $lineHeight, paragraphSpacing: $paragraphSpacing,
                             outlineColorsData: $outlineColorsData, annotationFontSize: $annotationFontSize,
                             annotationFontFamily: $annotationFontFamily, annotationTextColorHex: $annotationTextColorHex,
                             readingDataLocation: readingLibrary.locationDescription,
                             onDone: { activeSheet = nil })
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
                if saveDocument() {
                    continuePendingDocumentOperation()
                } else {
                    cancelPendingTermination()
                }
            }
            Button("不保存", role: .destructive) { continuePendingDocumentOperation() }
            Button("取消", role: .cancel) { cancelPendingTermination() }
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
        .alert("PDF 需要密码", isPresented: $showPDFPasswordPrompt) {
            SecureField("输入密码", text: $pdfPassword)
            Button("取消", role: .cancel) { pendingPDFURL = nil; pdfPassword = "" }
            Button("解锁") { unlockPendingPDF() }
        } message: {
            Text("此 PDF 受密码保护。")
        }
        .onAppear {
            readerWidthInput = "\(Int(readerWidth))"
            epubReaderWidthInput = "\(Int(epubReaderWidth))"
            pdfZoomInput = "\(Int(pdfZoomPercent))"
            ReaderActions.reopenWindowHandler = { openWindow(id: "main") }
            ReaderActions.terminationHandler = {
                if isDirty {
                    pendingDocumentOperation = .terminate
                    showUnsavedAlert = true
                    return .terminateLater
                }
                if activeBookURL != nil && currentBookID == nil {
                    Task { @MainActor in
                        await flushCurrentReadingProfileAsync()
                        NSApp.reply(toApplicationShouldTerminate: true)
                    }
                    return .terminateLater
                }
                flushCurrentReadingProfile()
                return .terminateNow
            }
            ReaderActions.openFileHandler = chooseFile
            ReaderActions.openFolderHandler = chooseFolder
            ReaderActions.openWebPageHandler = { activeSheet = .webAddress }
            ReaderActions.bookmarkCurrentPageHandler = beginBookmarkCurrentPage
            ReaderActions.clipWebSelectionHandler = clipWebSelection
            ReaderActions.webBackHandler = { webBrowser.goBack() }
            ReaderActions.webForwardHandler = { webBrowser.goForward() }
            ReaderActions.openSettingsHandler = { activeSheet = .settings }
            ReaderActions.adjustBodySizeHandler = { bodySize = min(24, max(12, bodySize + $0)) }
            ReaderActions.resetBodySizeHandler = { bodySize = 15 }
            ReaderActions.adjustTypographySizeHandler = { amount in
                switch fontSizeTarget {
                case .body: bodySize = min(24, max(12, bodySize + amount))
                case .outline: outlineFontScale = min(1.6, max(0.75, outlineFontScale + amount * 0.1))
                case .pdf: pdfZoomPercent = min(300, max(25, pdfZoomPercent + amount * 10))
                case .web: webZoomPercent = min(200, max(50, webZoomPercent + amount * 10))
                }
            }
            ReaderActions.resetTypographySizeHandler = {
                switch fontSizeTarget {
                case .body: bodySize = 15
                case .outline: outlineFontScale = 1
                case .pdf: pdfZoomPercent = 100
                case .web: webZoomPercent = 100
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
            ReaderActions.insertImageFileHandler = insertImageFile
            ReaderActions.toggleEditPreviewHandler = {
                if (isEPUBNotebook || pdfDocument != nil || webBrowser.currentURL != nil), epubNotebookLayout == .epub {
                    epubNotebookLayout = .notes
                    displayMode = .edit
                } else {
                    displayMode = displayMode == .read ? .edit : .read
                }
            }
            ReaderActions.toggleSplitModeHandler = {
                if isEPUBNotebook || pdfDocument != nil || webBrowser.currentURL != nil {
                    epubNotebookLayout = epubNotebookLayout == .stacked ? .notes : .stacked
                } else if epubDocument != nil {
                    displayMode = displayMode == .edit ? .read : .edit
                } else {
                    displayMode = displayMode == .split ? .edit : .split
                }
            }
            ReaderActions.openPreviewToSideHandler = {
                if isEPUBNotebook || pdfDocument != nil || webBrowser.currentURL != nil {
                    if epubNotebookLayout == .epub { epubNotebookLayout = .stacked }
                    displayMode = .split
                } else if epubDocument != nil {
                    displayMode = .edit
                } else {
                    displayMode = .split
                }
            }
            ReaderActions.setEPUBNotebookLayoutHandler = {
                guard isEPUBNotebook || pdfDocument != nil || webBrowser.currentURL != nil else { return }
                epubNotebookLayout = $0
            }
            ReaderActions.maximizeEPUBNotebookPaneHandler = { pane in
                guard isEPUBNotebook || pdfDocument != nil || webBrowser.currentURL != nil else { return }
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
            ReaderActions.saveHandler = { _ = saveDocument() }
            ReaderActions.closeFileHandler = closeFile
            ReaderActions.closeFolderHandler = closeFolder
            ReaderActions.insertHorizontalRuleHandler = insertHorizontalRule
            ReaderActions.insertTableHandler = {
                guard selectedFile != nil, displayMode != .read else { return }
                activeSheet = .tableInsertion
            }
            migrateDefaultHeadingColors()
            migrateSystemFontDefaults()
            if !lastFolderPath.isEmpty {
                let url = URL(fileURLWithPath: lastFolderPath)
                if FileManager.default.fileExists(atPath: url.path) { loadFolder(url) }
            }
            reloadWebBookmarks(reportError: true)
            ReaderActions.setOpenDocumentHandler(open)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled else { break }
                reloadWebBookmarks()
            }
        }
        .onChange(of: source) { _, newSource in
            scheduleParse(for: newSource)
        }
        .onChange(of: readerWidth) { _, value in readerWidthInput = "\(Int(value))" }
        .onChange(of: epubReaderWidth) { _, value in epubReaderWidthInput = "\(Int(value))" }
        .onChange(of: pdfZoomPercent) { _, value in pdfZoomInput = "\(Int(value))" }
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
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("阅读空间").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Button(action: chooseFolder) { Image(systemName: "folder.badge.plus").frame(width: 28, height: 26).contentShape(Rectangle()) }
                    .buttonStyle(.plain).help("打开文件夹").toolbarHint("打开文件夹")
                Button(action: chooseFile) { Image(systemName: "doc.badge.plus").frame(width: 28, height: 26).contentShape(Rectangle()) }
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

            HStack(spacing: 4) {
                ForEach(visibleSidebarTabs, id: \.self) { tab in
                    Button {
                        sidebarOutlineTab = tab
                        activateWorkspaceArea(.outline)
                    } label: {
                        Text(tab.title)
                            .font(.system(size: 11, weight: sidebarOutlineTab == tab ? .medium : .regular))
                            .foregroundStyle(sidebarOutlineTab == tab ? Color.primary : Color.secondary)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(sidebarOutlineTab == tab ? Color.primary.opacity(0.07) : .clear,
                                        in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
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
                if sidebarOutlineTab == .webBookmarks {
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
                Text(sidebarOutlineTab == .webBookmarks ? "网页收藏" : sidebarOutlineTab == .reading
                     ? (webBrowser.currentURL != nil ? "网页" : pdfDocument != nil ? "PDF" : epubDocument != nil ? "EPUB" : "阅读")
                     : (displayMode == .read ? "预览" : displayMode == .edit ? "编辑器" : "编辑 + 预览"))
                    .font(.system(size: 11))
                Spacer()
            }.foregroundStyle(.tertiary).padding(.horizontal, 18).padding(.vertical, 14)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        .overlay { workspaceFocusRing(focusedWorkspaceArea == .outline) }
        .shadow(color: focusedWorkspaceArea == .outline ? Color.accentColor.opacity(0.14) : .clear, radius: 5)
        .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.outline) } }
    }

    @ViewBuilder
    private var readingOutline: some View {
        if webBrowser.currentURL != nil {
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
        } else if let epubDocument {
            if epubDocument.tableOfContents.isEmpty {
                Text("此 EPUB 没有可识别的目录")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                    .padding(.horizontal, 18).padding(.top, 8)
                Spacer()
            } else {
                List {
                    ForEach(Array(epubDocument.tableOfContents.enumerated()), id: \.element.id) { _, item in
                        Button {
                            activateWorkspaceArea(.outline)
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
                                .padding(.vertical, 7)
                                .background(epubDocument.navigationTarget(for: item)?.chapterIndex == epubCurrentChapter ? Color.accentColor.opacity(0.11) : .clear)
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
        } else {
            markdownOutline
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

    @ViewBuilder
    private var markdownOutline: some View {
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
                               styles: headingStyles, outlineColors: outlineColors,
                               fontScale: outlineFontScale, onSelect: jumpTo)
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
            Text(webBrowser.currentURL != nil ? webBrowser.title :
                 (pdfDocument?.documentURL?.deletingPathExtension().lastPathComponent
                  ?? selectedFile?.deletingPathExtension().lastPathComponent
                  ?? documentTitle))
                .font(.system(size: 13, weight: .medium)).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let pdfDocument {
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
            } else if let epubDocument, !epubDocument.chapters.isEmpty {
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
            HStack(spacing: 6) {
                if documentZoomControlIsActive {
                    Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(.secondary)
                        .help(pdfZoomControlIsActive ? "PDF 缩放" : "网页缩放")
                    if pdfZoomControlIsActive {
                        Slider(value: $pdfZoomPercent, in: 25...300, step: 5)
                            .frame(width: 86).help("PDF 缩放：\(Int(pdfZoomPercent))%")
                            .toolbarHint("调整 PDF 页面缩放：\(Int(pdfZoomPercent))%")
                        TextField("100", text: $pdfZoomInput)
                            .frame(width: 42).textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                            .onSubmit(commitPDFZoomInput)
                            .help("输入 PDF 缩放百分比并按回车")
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
                        .help(epubWidthControlIsActive ? "调整 EPUB 原书排版宽度" : "调整 Markdown 正文排版宽度")
                    Slider(value: activeContentWidthBinding, in: 520...1040, step: 20)
                        .frame(width: 86).help("排版宽度：\(Int(activeContentWidth)) 像素")
                        .toolbarHint(epubWidthControlIsActive ? "调整 EPUB 原书排版宽度" : "调整 Markdown 正文排版宽度")
                    TextField("720", text: activeContentWidthInput)
                        .frame(width: 46).textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .onSubmit(commitActiveContentWidthInput)
                        .help(epubWidthControlIsActive ? "输入 EPUB 排版宽度（像素）并按回车" : "输入 Markdown 正文排版宽度（像素）并按回车")
                    Text("px").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Button {
                    if pdfZoomControlIsActive { pdfZoomPercent = max(25, pdfZoomPercent - 10) }
                    else if webZoomControlIsActive { webZoomPercent = max(50, webZoomPercent - 10) }
                    else { ReaderActions.adjustTypographySize(-1) }
                } label: {
                    Text(documentZoomControlIsActive ? "−" : "A−").font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .help(documentZoomControlIsActive ? "缩小\(pdfZoomControlIsActive ? "PDF" : "网页")（⌘−）" : "缩小当前区域字体（⌘−）")
                .toolbarHint(documentZoomControlIsActive ? "缩小\(pdfZoomControlIsActive ? "PDF" : "网页") · ⌘−" : "缩小当前区域字体 · ⌘−")
                Button {
                    if pdfZoomControlIsActive { pdfZoomPercent = min(300, pdfZoomPercent + 10) }
                    else if webZoomControlIsActive { webZoomPercent = min(200, webZoomPercent + 10) }
                    else { ReaderActions.adjustTypographySize(1) }
                } label: {
                    Text(documentZoomControlIsActive ? "+" : "A+").font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .help(documentZoomControlIsActive ? "放大\(pdfZoomControlIsActive ? "PDF" : "网页")（⌘+）" : "放大当前区域字体（⌘+）")
                .toolbarHint(documentZoomControlIsActive ? "放大\(pdfZoomControlIsActive ? "PDF" : "网页") · ⌘+" : "放大当前区域字体 · ⌘+")
                Button { activeSheet = .settings } label: { Label("样式", systemImage: "textformat.size").font(.system(size: 12)) }
                    .buttonStyle(.plain).help("字体与行距（⌘,）")
                    .toolbarHint("字体、行距与注释文字样式 · ⌘,")
                if isEPUBNotebook || pdfDocument != nil || webBrowser.currentURL != nil {
                    HStack(spacing: 1) {
                        toolbarModeSegment(pdfDocument != nil ? "doc.text.image" : webBrowser.currentURL != nil ? "globe" : "book",
                                           selected: epubNotebookLayout == .epub,
                                           hint: "只看\(pdfDocument != nil ? "PDF" : webBrowser.currentURL != nil ? "网页" : "EPUB 原书") · ⌃⌘1") { epubNotebookLayout = .epub }
                        toolbarModeSegment("doc.text", selected: epubNotebookLayout == .notes,
                                           hint: "只看 Markdown 笔记 · ⌃⌘2") { epubNotebookLayout = .notes }
                        toolbarModeSegment("rectangle.split.3x1", selected: epubNotebookLayout == .stacked,
                                           hint: "阅读 + 笔记预览 + 编辑 · ⌃⌘3") { epubNotebookLayout = .stacked }
                    }
                    .padding(2).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                    .frame(width: 86).help("切换阅读内容、笔记或三栏工作区")
                    if (pdfDocument != nil || webBrowser.currentURL != nil || (epubDocument != nil && isEPUBNotebook)) && epubNotebookLayout == .stacked {
                        Picker("Markdown 工作区布局", selection: Binding(
                            get: { pdfNotesLayout },
                            set: { layout in
                                epubNotebookLayout = .stacked
                                switch layout {
                                case .split: maximizedNotebookPane = nil
                                case .preview: maximizedNotebookPane = .rightPreview
                                case .editor: maximizedNotebookPane = .rightEditor
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
                        .help("设置右侧 Markdown 工作区：上下分屏，或让预览/编辑占满右侧")
                        .accessibilityLabel("Markdown 工作区布局")
                    }
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

    private func readingPane(backgroundHex: String? = nil,
                             focusArea: FocusedWorkspaceArea = .markdownReader) -> some View {
        let paneBackgroundHex = backgroundHex ?? readerBackgroundHex
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
                ReaderWebView(blocks: blocks, readerWidth: readerWidth, headingStyles: headingStyles,
                              bodyColorHex: bodyColorHex, readerBackgroundHex: paneBackgroundHex,
                              strongColorHex: strongColorHex, strongSize: strongSize, strongFamily: strongFamily,
                              bodySize: bodySize, bodyFamily: bodyFamily, lineHeight: lineHeight,
                              paragraphSpacing: paragraphSpacing,
                              baseURL: selectedFile?.deletingLastPathComponent(), scrollTarget: scrollTarget,
                              scrollRequest: scrollRequest, sourceLineTarget: synchronizedSourceLine,
                              sourceLineRequest: sourceLineRequest, onSourceLineChange: synchronizeSourceLine,
                              onActivate: { activateWorkspaceArea(focusArea) })
            }
        }
        .background(Color(hex: paneBackgroundHex))
        .overlay { workspaceFocusRing(focusedWorkspaceArea == focusArea) }
        .shadow(color: focusedWorkspaceArea == focusArea ? Color.accentColor.opacity(0.045) : .clear, radius: 2)
        .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(focusArea) } }
    }

    private var documentPane: some View {
        Group {
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
                      isReadingProfileLoading: pdfProfileLoading,
                      backgroundColor: Color(hex: readerBackgroundHex),
                      onActivate: { activateWorkspaceArea(.pdf) })
            .background(Color(hex: readerBackgroundHex))
            .overlay { workspaceFocusRing(focusedWorkspaceArea == .pdf) }
            .shadow(color: focusedWorkspaceArea == .pdf ? Color.accentColor.opacity(0.045) : .clear, radius: 2)
            .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.pdf) } }
    }

    private func webReaderPane(_ url: URL) -> some View {
        WebBrowserPane(session: webBrowser, zoomPercent: webZoomPercent,
                       isBookmarked: webBookmarks.contains(where: { $0.urlString == url.absoluteString }),
                       onBookmark: beginBookmarkCurrentPage, onClip: appendWebClip,
                       onActivate: { activateWorkspaceArea(.web) })
            .overlay { workspaceFocusRing(focusedWorkspaceArea == .web) }
            .shadow(color: focusedWorkspaceArea == .web ? Color.accentColor.opacity(0.045) : .clear, radius: 2)
            .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.web) } }
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
        case .rightPreview:
            notebookSplitWorkspace(primary: { webReaderPane(url) }, notes: { notebookPreviewPane })
        case .rightEditor:
            notebookSplitWorkspace(primary: { webReaderPane(url) }, notes: { notebookEditorPane })
        case nil:
            notebookSplitWorkspace(primary: { webReaderPane(url) }, notes: { notebookVerticalSplitPane })
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
            notebookSplitWorkspace(primary: { notebookPDFPane(document) }, notes: { pdfNotebookNotesPane })
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
            notebookVerticalSplitPane
        }
    }

    private func notebookSplitWorkspace<Primary: View, Notes: View>(
        @ViewBuilder primary: @escaping () -> Primary,
        @ViewBuilder notes: @escaping () -> Notes
    ) -> some View {
        GeometryReader { geometry in
            HSplitView {
                primary()
                notes()
                    .frame(minWidth: 320, idealWidth: min(max(CGFloat(notebookRightPaneWidth), 320), max(320, geometry.size.width - 260)))
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: WorkspacePaneWidthPreferenceKey.self, value: proxy.size.width)
                    })
            }
            .onPreferenceChange(WorkspacePaneWidthPreferenceKey.self, perform: scheduleWorkspaceWidthSave)
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
        if let maximizedNotebookPane {
            switch maximizedNotebookPane {
            case .epub:
                notebookEPUBPane(document)
            case .preview:
                notebookPreviewPane
            case .editor:
                notebookEditorPane
            case .rightPreview:
                notebookSplitWorkspace(primary: { notebookEPUBPane(document) }, notes: { notebookPreviewPane })
            case .rightEditor:
                notebookSplitWorkspace(primary: { notebookEPUBPane(document) }, notes: { notebookEditorPane })
            }
        } else {
            notebookSplitWorkspace(primary: { notebookEPUBPane(document) }, notes: { notebookVerticalSplitPane })
        }
    }

    private func notebookEPUBPane(_ document: EPUBPackageDocument) -> some View {
        VStack(spacing: 0) {
            notebookPaneHeader(.epub)
            epubChapterPane(document, editable: false)
        }
        .overlay { workspaceFocusRing(focusedWorkspaceArea == .epub) }
        .shadow(color: focusedWorkspaceArea == .epub ? Color.accentColor.opacity(0.045) : .clear, radius: 2)
        .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.epub) } }
    }

    private var notebookPreviewPane: some View {
        VStack(spacing: 0) {
            notebookPaneHeader(.preview)
            readingPane(backgroundHex: notebookPreviewBackgroundHex, focusArea: .markdownPreview)
        }
        .overlay { workspaceFocusRing(focusedWorkspaceArea == .markdownPreview) }
        .shadow(color: focusedWorkspaceArea == .markdownPreview ? Color.accentColor.opacity(0.045) : .clear, radius: 2)
        .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.markdownPreview) } }
    }

    private var notebookEditorPane: some View {
        VStack(spacing: 0) {
            notebookPaneHeader(.editor)
            editorPane
        }
        .overlay { workspaceFocusRing(focusedWorkspaceArea == .markdownEditor) }
        .shadow(color: focusedWorkspaceArea == .markdownEditor ? Color.accentColor.opacity(0.045) : .clear, radius: 2)
        .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.markdownEditor) } }
    }

    private func notebookPaneHeader(_ pane: EPUBNotebookPane, titleOverride: String? = nil) -> some View {
        HStack(spacing: 6) {
            Text(titleOverride ?? pane.title).font(.system(size: 11, weight: .medium))
            Spacer()
            if !(pdfDocument != nil && (pane == .preview || pane == .editor)) {
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
        case (.epub, _) where pdfDocument != nil: "最大化 PDF 阅读区"
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
        .shadow(color: focusedWorkspaceArea == .epub ? Color.accentColor.opacity(0.045) : .clear, radius: 2)
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
        VStack(spacing: 0) {
            if !((isEPUBNotebook || pdfDocument != nil || webBrowser.currentURL != nil) && epubNotebookLayout == .stacked) {
            HStack(spacing: 7) {
                Image(systemName: "chevron.left.forwardslash.chevron.right").font(.system(size: 11))
                Text((isEPUBNotebook || pdfDocument != nil || webBrowser.currentURL != nil) ? "Markdown 笔记" : "Markdown 源码")
                    .font(.system(size: 11, weight: .medium))
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
                                 onSourceLineChange: synchronizeSourceLine,
                                 onActivate: { activateWorkspaceArea(.markdownEditor) },
                                 onImagePaste: pasteImage)
                .background(Color(nsColor: .textBackgroundColor))
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
        .background(Color(nsColor: .textBackgroundColor))
        .frame(maxWidth: readerWidth + 76)
        .frame(maxWidth: .infinity)
        .overlay { workspaceFocusRing(focusedWorkspaceArea == .markdownEditor) }
        .shadow(color: focusedWorkspaceArea == .markdownEditor ? Color.accentColor.opacity(0.045) : .clear, radius: 2)
        .background { Color.clear.contentShape(Rectangle()).onTapGesture { activateWorkspaceArea(.markdownEditor) } }
    }

    private var isDirty: Bool { source != savedSource || epubHasChanges }

    private var topHeadings: [MarkdownBlock] { headings.filter { $0.parentID == nil } }

    private func jumpTo(_ id: String) {
        activateWorkspaceArea(.outline)
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
        panel.allowedContentTypes = [.plainText, .init(filenameExtension: "md")!,
                                     .init(filenameExtension: "epub")!, .pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        // Let an unpacked `.epub` package be selected as one book instead of
        // making a double-click descend into its internal folder structure.
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
        if WebBrowserSession.isWebURL(url) {
            openWeb(url)
            return
        }
        if (url.pathExtension.lowercased() == "epub" || url.pathExtension.lowercased() == "pdf" || isUnpackedEPUBDirectory(url)),
           activeBookURL?.standardizedFileURL != url.standardizedFileURL {
            flushCurrentReadingProfile()
        }
        if url.pathExtension.lowercased() == "epub" || isUnpackedEPUBDirectory(url) {
            pendingEPUBURL = url
            showEPUBModeChoice = true
        } else if url.pathExtension.lowercased() == "pdf" {
            openPDF(url)
        } else if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            saveError = "所选文件夹不是已解压的 EPUB：找不到 META-INF/container.xml。"
        } else {
            // When a reading source is open, Markdown documents belong to its notes pane.
            loadDocument(url, preservingEPUB: epubDocument != nil && isEPUBNotebook,
                         preservingPDF: pdfDocument != nil, preservingWeb: webBrowser.currentURL != nil)
        }
    }

    private func openWeb(_ url: URL) {
        guard WebBrowserSession.isWebURL(url) else { return }
        if activeBookURL != nil { flushCurrentReadingProfile() }
        let keepBookmarksVisible = sidebarOutlineTab == .webBookmarks
        clearReadingProfileSelection()
        pdfDocument = nil
        pdfSourceURL = nil
        epubDocument = nil
        isEPUBNotebook = false
        epubHasChanges = false
        maximizedNotebookPane = nil
        epubNotebookLayout = .stacked
        activateWorkspaceArea(.web)
        if keepBookmarksVisible { sidebarOutlineTab = .webBookmarks }
        webBrowser.open(url)
        displayMode = .edit
    }

    private func isUnpackedEPUBDirectory(_ url: URL) -> Bool {
        guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return false }
        return FileManager.default.fileExists(atPath: url.appendingPathComponent("META-INF/container.xml").path)
    }

    private func openEPUBOriginal() {
        guard let url = pendingEPUBURL else { return }
        pendingEPUBURL = nil
        if activeBookURL?.standardizedFileURL != url.standardizedFileURL { flushCurrentReadingProfile() }
        do {
            let document = try EPUBPackageDocument.open(url)
            webBrowser.close()
            pdfDocument = nil
            pdfSourceURL = nil
            epubDocument = document
            isEPUBNotebook = false
            activateWorkspaceArea(.epub)
            maximizedNotebookPane = nil
            epubCurrentChapter = 0
            beginLoadingReadingProfile(for: url, sourceKind: .epub, title: document.title)
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
        if activeBookURL?.standardizedFileURL != url.standardizedFileURL { flushCurrentReadingProfile() }
        let noteURL = url.deletingPathExtension().appendingPathExtension("md")
        do {
            let document = try EPUBPackageDocument.open(url)
            webBrowser.close()
            pdfDocument = nil
            pdfSourceURL = nil
            epubDocument = document
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
        activateWorkspaceArea(.markdownEditor)
        epubNotebookLayout = .stacked
        maximizedNotebookPane = nil
        epubCurrentChapter = 0
        beginLoadingReadingProfile(for: url, sourceKind: .epub, title: epubDocument?.title ?? url.lastPathComponent)
        loadDocument(noteURL, preservingEPUB: true)
        displayMode = .edit
    }

    private func loadDocument(_ url: URL, preservingEPUB: Bool = false, preservingPDF: Bool = false,
                              preservingWeb: Bool = false) {
        do {
            let document = try documentStore.openDocument(at: url)
            if !preservingEPUB && !preservingPDF && !preservingWeb {
                clearReadingProfileSelection()
                epubDocument = nil
                pdfDocument = nil
                pdfSourceURL = nil
                isEPUBNotebook = false
                webBrowser.close()
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
        installPDF(document, from: url)
    }

    private func installPDF(_ document: PDFDocument, from url: URL) {
        guard document.pageCount > 0 else {
            saveError = "这个 PDF 没有可显示的页面。"
            return
        }
        if activeBookURL?.standardizedFileURL != url.standardizedFileURL { flushCurrentReadingProfile() }
        pdfDocument = document
        pdfSourceURL = url
        webBrowser.close()
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
        epubNotebookLayout = .stacked
        documentTitle = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
            ?? url.deletingPathExtension().lastPathComponent
        beginLoadingReadingProfile(for: url, sourceKind: .pdf, title: documentTitle)
        displayMode = .edit
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
        splitWidthSaveTask?.cancel()
        splitWidthSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            notebookRightPaneWidth = min(1200, max(320, Double(width)))
        }
    }

    private func scheduleSidebarWidthSave(_ width: CGFloat) {
        guard width > 0, abs(width - sidebarWidth) > 1 else { return }
        sidebarWidthSaveTask?.cancel()
        sidebarWidthSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            sidebarWidth = Double(width)
        }
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

    private func commitWebZoomInput() {
        let parsed = Double(webZoomInput.replacingOccurrences(of: "%", with: "")) ?? webZoomPercent
        let bounded = parsed.isFinite ? min(200, max(50, parsed)) : webZoomPercent
        webZoomPercent = bounded.rounded()
        webZoomInput = "\(Int(webZoomPercent))"
    }

    private func reloadWebBookmarks(reportError: Bool = false) {
        do { webBookmarks = try readingLibrary.loadWebBookmarks() }
        catch {
            if reportError { saveError = "无法读取 iCloud 网页收藏：\(error.localizedDescription)" }
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
        source = WebClipFormatter.append(clip, title: webBrowser.title, url: url, to: source)
        let end = (source as NSString).length
        editorSelection = NSRange(location: end, length: 0)
        synchronizedSourceLine = source.components(separatedBy: "\n").count
        sourceLineRequest += 1
        editorFocusRequest += 1
        if epubNotebookLayout == .epub { epubNotebookLayout = .stacked }
        activateWorkspaceArea(.markdownEditor)
    }

    private func commitPDFZoomInput() {
        let parsed = Double(pdfZoomInput.replacingOccurrences(of: "%", with: "")) ?? pdfZoomPercent
        let bounded = parsed.isFinite ? min(300, max(25, parsed)) : pdfZoomPercent
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
        if !FileManager.default.fileExists(atPath: url.path),
           !FileManager.default.createFile(atPath: url.path, contents: Data()) {
            saveError = "无法创建 Markdown 笔记：\(url.lastPathComponent)"
            return false
        }
        open(url)
        return selectedFile == url
    }

    private func activateWorkspaceArea(_ area: FocusedWorkspaceArea) {
        focusedWorkspaceArea = area
        switch area {
        case .pdf:
            sidebarOutlineTab = .reading
            fontSizeTarget = .pdf
        case .epub:
            sidebarOutlineTab = .reading
            fontSizeTarget = .body
        case .web:
            sidebarOutlineTab = .reading
            fontSizeTarget = .web
        case .markdownPreview, .markdownEditor, .markdownReader:
            sidebarOutlineTab = .markdown
            fontSizeTarget = .body
        case .outline:
            fontSizeTarget = .outline
        }
    }

    private func workspaceFocusRing(_ focused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(focused ? Color.accentColor.opacity(0.34) : Color.clear, lineWidth: focused ? 1 : 0)
            .padding(2)
            .allowsHitTesting(false)
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
        case .closePDF: clearPDFDocument()
        case .closeWeb: clearWebDocument()
        case .terminate:
            Task { @MainActor in
                await flushCurrentReadingProfileAsync()
                NSApp.reply(toApplicationShouldTerminate: true)
            }
        case nil: break
        }
    }

    private func cancelPendingTermination() {
        let shouldReply = if case .terminate = pendingDocumentOperation { true } else { false }
        pendingDocumentOperation = nil
        if shouldReply { NSApp.reply(toApplicationShouldTerminate: false) }
    }

    private func closeFile() {
        if pdfDocument != nil {
            if isDirty {
                pendingDocumentOperation = .closePDF
                showUnsavedAlert = true
            } else {
                clearPDFDocument()
            }
            return
        }
        if webBrowser.currentURL != nil {
            if isDirty {
                pendingDocumentOperation = .closeWeb
                showUnsavedAlert = true
            } else {
                clearWebDocument()
            }
            return
        }
        guard selectedFile != nil || epubDocument != nil else { return }
        if isDirty {
            pendingDocumentOperation = .closeFile
            showUnsavedAlert = true
        } else {
            clearCurrentDocument()
        }
    }

    private func clearCurrentDocument() {
        clearReadingProfileSelection()
        epubDocument = nil
        pdfDocument = nil
        pdfSourceURL = nil
        webBrowser.close()
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

    private func clearPDFDocument() {
        clearReadingProfileSelection()
        pdfDocument = nil
        pdfSourceURL = nil
        pdfCurrentPage = 0
        pdfReadingPosition = nil
        pdfNavigationRequest += 1
        maximizedNotebookPane = nil
        activateWorkspaceArea(.markdownReader)
        if let selectedFile {
            documentTitle = selectedFile.deletingPathExtension().lastPathComponent
        } else {
            documentTitle = "选择一个 Markdown 文件开始阅读"
        }
    }

    private func clearWebDocument() {
        webBrowser.close()
        maximizedNotebookPane = nil
        activateWorkspaceArea(selectedFile == nil ? .markdownReader : .markdownEditor)
        sidebarOutlineTab = .markdown
        if let selectedFile {
            documentTitle = selectedFile.deletingPathExtension().lastPathComponent
            sidebarOutlineTab = .markdown
        } else {
            documentTitle = "选择一个 Markdown 文件开始阅读"
            sidebarOutlineTab = .markdown
        }
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
            let original = source as NSString
            let location = min(editorSelection.location, original.length)
            let length = min(editorSelection.length, original.length - location)
            let range = NSRange(location: location, length: length)
            let insertion = MarkdownImageAssets.blockInsertion(markdown, in: source, replacing: range)
            source = original.replacingCharacters(in: range, with: insertion)
            editorSelection = NSRange(location: location + (insertion as NSString).length, length: 0)
            if displayMode == .read { displayMode = .edit }
            if epubNotebookLayout == .epub { epubNotebookLayout = .stacked }
            editorFocusRequest += 1
        } catch {
            saveError = "无法插入图片：\(error.localizedDescription)"
        }
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
    let onDone: () -> Void
    @State private var styles: [HeadingStyle]
    @State private var outlineColors: [String]
    private let families = ["系统默认", "PingFang SC", "Songti SC", "Heiti SC", "SF Pro Text", "Avenir Next", "Georgia", "Menlo"]

    init(readerWidth: Binding<Double>, bodyColorHex: Binding<String>, readerBackgroundHex: Binding<String>, strongColorHex: Binding<String>, strongSize: Binding<Double>, strongFamily: Binding<String>, headingStylesData: Binding<Data>, bodySize: Binding<Double>, bodyFamily: Binding<String>, lineHeight: Binding<Double>, paragraphSpacing: Binding<Double>, outlineColorsData: Binding<Data>, annotationFontSize: Binding<Double>, annotationFontFamily: Binding<String>, annotationTextColorHex: Binding<String>, readingDataLocation: String, onDone: @escaping () -> Void) {
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
        self.onDone = onDone
        _styles = State(initialValue: (try? JSONDecoder().decode([HeadingStyle].self, from: headingStylesData.wrappedValue)) ?? HeadingStyle.defaults)
        _outlineColors = State(initialValue: (try? JSONDecoder().decode([String].self, from: outlineColorsData.wrappedValue)) ?? Array(repeating: "#222222", count: 6))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("阅读样式").font(.system(size: 18, weight: .semibold)); Spacer(); Button("完成") { save(); onDone() }.keyboardShortcut(.defaultAction) }
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
                Section("跨设备阅读资料") {
                    LabeledContent("保存位置", value: readingDataLocation)
                    Text("此处保存书籍标识、阅读位置、阅读样式、EPUB 批注和网页收藏。原书与 Markdown 笔记文件保留在原位置。使用 iCloud Drive 时，这些阅读资料会随 iCloud 同步。")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
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

private struct WorkspacePaneWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct WorkspacePaneHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct SidebarWidthPreferenceKey: PreferenceKey {
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
