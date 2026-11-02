import AppKit
import SwiftUI
import WebKit

@MainActor
final class MarkdownVisualScrollState {
    enum Mode { case visual, source }
    var documentPath = ""
    var selection: NSRange?
    var viewport: MarkdownViewportAnchor?
    var activeMode: Mode = .visual

    func reset(for url: URL?) {
        documentPath = url?.standardizedFileURL.path ?? ""
        selection = nil
        viewport = nil
        activeMode = .visual
    }
}

/// Keeps untouched Markdown blocks byte-for-byte intact. Only the block that
/// receives an actual visual edit is converted back from its DOM representation.
struct MarkdownVisualDocument {
    let prefix: String
    var segments: [String]
    let editable: [Bool]

    init(source: String, blocks: [MarkdownBlock]) {
        guard !blocks.isEmpty else {
            prefix = ""
            segments = [source]
            editable = [true]
            return
        }
        let text = source as NSString
        var lineOffsets = [0]
        var position = 0
        while position < text.length {
            let line = text.lineRange(for: NSRange(location: position, length: 0))
            guard NSMaxRange(line) > position else { break }
            position = NSMaxRange(line)
            lineOffsets.append(position)
        }
        let starts = blocks.map { block -> Int in
            lineOffsets[min(max(0, block.sourceLine - 1), lineOffsets.count - 1)]
        }
        prefix = text.substring(to: starts[0])
        segments = blocks.indices.map { index in
            let end = index + 1 < starts.count ? starts[index + 1] : text.length
            return text.substring(with: NSRange(location: starts[index], length: max(0, end - starts[index])))
        }
        editable = segments.map { segment in
            let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            // Raw HTML and unsupported extensions cannot be safely round-tripped.
            // Users can still edit them in the Markdown source pane.
            let containsFootnote = trimmed.range(of: #"\[\^[^\]]+\]"#, options: .regularExpression) != nil
            return (!trimmed.hasPrefix("<") || trimmed.hasPrefix("<u>"))
                && !containsFootnote && !trimmed.contains("<!--")
        }
    }

    var source: String { prefix + segments.joined() }

    func sourceOffset(for anchor: MarkdownVisualAnchor) -> Int {
        guard segments.indices.contains(anchor.index) else { return (source as NSString).length }
        let start = prefix.utf16.count + segments.prefix(anchor.index).reduce(0) { $0 + $1.utf16.count }
        return start + MarkdownTextPositionMap(source: segments[anchor.index]).sourceOffset(forTextOffset: anchor.offset)
    }

    func visualAnchor(forSourceOffset offset: Int) -> MarkdownVisualAnchor {
        var start = prefix.utf16.count
        for (index, segment) in segments.enumerated() {
            let end = start + segment.utf16.count
            if offset < end || index == segments.count - 1 {
                return MarkdownVisualAnchor(index: index,
                    offset: MarkdownTextPositionMap(source: segment).textOffset(forSourceOffset: max(0, offset - start)))
            }
            start = end
        }
        return MarkdownVisualAnchor(index: 0, offset: 0)
    }

    mutating func replaceBlock(at index: Int, with markdown: String) -> String? {
        guard segments.indices.contains(index), editable[index] else { return nil }
        let old = segments[index]
        let trailing = String(old.reversed().prefix(while: { $0 == "\n" || $0 == "\r" }).reversed())
        let separator = !trailing.isEmpty ? trailing : (index < segments.count - 1 ? "\n\n" : "")
        let replacement = markdown.trimmingCharacters(in: .newlines) + separator
        guard replacement != old else { return nil }
        segments[index] = replacement
        return source
    }
}

@MainActor
enum MarkdownVisualCommandHub {
    static func focusActiveEditor() {
        guard let view = activeWebView else { return }
        view.window?.makeFirstResponder(view)
        view.evaluateJavaScript("""
            (() => {
              const selection = getSelection();
              const range = selection?.rangeCount ? selection.getRangeAt(0).cloneRange() : null;
              const element = selection?.anchorNode?.parentElement?.closest('[contenteditable=true]')
                || document.querySelector('[contenteditable=true]');
              element?.focus({preventScroll:true});
              if (range) { selection.removeAllRanges(); selection.addRange(range); }
            })()
            """, in: nil, in: MarkdownVisualEditor.contentWorld, completionHandler: nil)
    }

    static weak var activeWebView: WKWebView?
    static var flushActiveEdits: ((@escaping @MainActor () -> Void) -> Void)?

    static func commitActiveEdits(completion: @escaping @MainActor () -> Void) {
        if let view = MarkdownSourcePositionHub.coordinator?.textView, view.hasMarkedText() {
            // Resigning commits the input method before the source view can be
            // moved or removed; otherwise its provisional text is not in the binding.
            view.window?.makeFirstResponder(nil)
        }
        let finish: @MainActor () -> Void = {
            MarkdownSourcePositionHub.flushPendingChanges()
            completion()
        }
        guard let flushActiveEdits else { finish(); return }
        flushActiveEdits(finish)
    }

    static func perform(_ name: String, value: String = "") -> Bool {
        guard let activeWebView else { return false }
        let arguments = [name, value]
        guard let data = try? JSONSerialization.data(withJSONObject: arguments),
              let json = String(data: data, encoding: .utf8) else { return false }
        activeWebView.evaluateJavaScript("window.markdownStudioCommand(...\(json))", in: nil,
                                         in: MarkdownVisualEditor.contentWorld, completionHandler: nil)
        return true
    }
}

struct MarkdownVisualEditor: NSViewRepresentable {
    @Binding var source: String
    let blocks: [MarkdownBlock]
    let parsedSource: String
    let readerWidth: Double
    let headingStyles: [HeadingStyle]
    let bodyColorHex: String
    let readerBackgroundHex: String
    let strongColorHex: String
    let strongSize: Double
    let strongFamily: String
    let bodySize: Double
    let bodyFamily: String
    let lineHeight: Double
    let paragraphSpacing: Double
    let baseURL: URL?
    let scrollTarget: String?
    let scrollRequest: Int
    let sourceLineTarget: Int
    let sourceLineRequest: Int
    let restoreRequest: Int
    let scrollState: MarkdownVisualScrollState
    var isActive: Bool = true
    let onSourceLineChange: (Int) -> Void
    let onActivate: () -> Void
    let onImagePaste: (NSPasteboard) -> String?
    var onMarkdownLink: (URL) -> Void = { _ in }
    var onSlashCommand: (String, String?) -> Void = { _, _ in }
    var onDeleteManagedNote: (URL) -> Void = { _ in }

    static let contentWorld = WKContentWorld.world(name: "MarkdownStudioVisualEditor")

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(source: $source, onActivate: onActivate, onImagePaste: onImagePaste)
        // A newly created visual pane must not replay an older outline click.
        // Its initial position comes from the source line or saved visual offset.
        coordinator.lastScrollRequest = scrollRequest
        return coordinator
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, contentWorld: Self.contentWorld, name: "visualEdit")
        configuration.userContentController.addUserScript(WKUserScript(source: Self.editorScript,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: Self.contentWorld))
        let webView = VisualEditorWebView(frame: .zero, configuration: configuration)
        webView.onActivate = { [weak coordinator = context.coordinator, weak webView] in
            if let coordinator, let webView {
                MarkdownVisualCommandHub.activeWebView = webView
                MarkdownVisualCommandHub.flushActiveEdits = { [weak coordinator, weak webView] completion in
                    guard let coordinator, let webView else { completion(); return }
                    coordinator.flushPendingEdits(in: webView, completion: completion)
                }
            }
            scrollState.activeMode = .visual
            onActivate()
        }
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        if isActive { Self.registerCommandHub(webView, coordinator: context.coordinator) }
        context.coordinator.onSourceLineChange = onSourceLineChange
        context.coordinator.scrollState = scrollState
        if let scrollView = Self.findScrollView(in: webView) {
            scrollView.contentView.postsBoundsChangedNotifications = true
            context.coordinator.observe(scrollView)
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        (webView as? VisualEditorWebView)?.onActivate = { [weak coordinator = context.coordinator, weak webView] in
            if let coordinator, let webView {
                MarkdownVisualCommandHub.activeWebView = webView
                MarkdownVisualCommandHub.flushActiveEdits = { [weak coordinator, weak webView] completion in
                    guard let coordinator, let webView else { completion(); return }
                    coordinator.flushPendingEdits(in: webView, completion: completion)
                }
            }
            scrollState.activeMode = .visual
            onActivate()
        }
        let coordinator = context.coordinator
        coordinator.onActivate = onActivate
        coordinator.onImagePaste = onImagePaste
        coordinator.onMarkdownLink = onMarkdownLink
        coordinator.onSlashCommand = onSlashCommand
        coordinator.onDeleteManagedNote = onDeleteManagedNote
        coordinator.onSourceLineChange = onSourceLineChange
        coordinator.scrollState = scrollState
        if isActive {
            Self.registerCommandHub(webView, coordinator: coordinator)
        } else if MarkdownVisualCommandHub.activeWebView === webView {
            MarkdownVisualCommandHub.activeWebView = nil
            MarkdownVisualCommandHub.flushActiveEdits = nil
        }
        let path = baseURL?.standardizedFileURL.path ?? ""
        let styleKey = "\(readerWidth)|\(headingStyles)|\(bodyColorHex)|\(readerBackgroundHex)|\(strongColorHex)|\(strongSize)|\(strongFamily)|\(bodySize)|\(bodyFamily)|\(lineHeight)|\(paragraphSpacing)|\(path)"
        let ownChange = source == coordinator.lastEmittedSource
        if coordinator.lastLoadedSource != source && !ownChange || coordinator.styleKey != styleKey {
            let currentBlocks = parsedSource == source ? blocks : MarkdownBlock.parse(source)
            coordinator.document = MarkdownVisualDocument(source: source, blocks: currentBlocks)
            coordinator.lastLoadedSource = source
            coordinator.lastEmittedSource = nil
            coordinator.styleKey = styleKey
            coordinator.hasLoadedPage = false
            coordinator.pendingSourceLine = sourceLineTarget
            webView.undoManager?.removeAllActions()
            coordinator.load(pageHTML(using: currentBlocks), baseURL: baseURL, in: webView)
        }
        if coordinator.lastWidth != readerWidth {
            coordinator.lastWidth = readerWidth
            webView.evaluateJavaScript("document.querySelector('main')?.style.setProperty('max-width', '\(Int(readerWidth + 76))px')",
                                       in: nil, in: Self.contentWorld, completionHandler: nil)
        }
        if coordinator.lastRestoreRequest != restoreRequest {
            coordinator.lastRestoreRequest = restoreRequest
            coordinator.needsPositionRestore = true
        }
        if coordinator.needsPositionRestore, scrollState.viewport != nil {
            coordinator.lastSourceLineRequest = sourceLineRequest
            coordinator.restoreEditingPositionIfReady(in: webView)
            return
        }
        if coordinator.lastScrollRequest != scrollRequest {
            coordinator.lastScrollRequest = scrollRequest
            if let scrollTarget {
                coordinator.pendingScrollID = scrollTarget
                coordinator.scrollIfReady(in: webView)
            }
        }
        if coordinator.lastSourceLineRequest != sourceLineRequest {
            coordinator.lastSourceLineRequest = sourceLineRequest
            coordinator.pendingSourceLine = sourceLineTarget
            coordinator.scrollToSourceLineIfReady(in: webView)
        }
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        if MarkdownVisualCommandHub.activeWebView === webView {
            MarkdownVisualCommandHub.activeWebView = nil
            MarkdownVisualCommandHub.flushActiveEdits = nil
        }
        webView.undoManager?.removeAllActions()
        coordinator.stopObserving()
        coordinator.cleanup()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "visualEdit", contentWorld: contentWorld)
    }

    private static func registerCommandHub(_ webView: WKWebView, coordinator: Coordinator) {
        MarkdownVisualCommandHub.activeWebView = webView
        MarkdownVisualCommandHub.flushActiveEdits = { [weak coordinator, weak webView] completion in
            guard let coordinator, let webView else { completion(); return }
            coordinator.flushPendingEdits(in: webView, completion: completion)
        }
    }

    private static func findScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView { return scrollView }
        for child in view.subviews {
            if let scrollView = findScrollView(in: child) { return scrollView }
        }
        return nil
    }

    func pageHTML(using renderedBlocks: [MarkdownBlock]) -> String {
        let preview = ReaderWebView(blocks: renderedBlocks, readerWidth: readerWidth, headingStyles: headingStyles,
            bodyColorHex: bodyColorHex, readerBackgroundHex: readerBackgroundHex,
            strongColorHex: strongColorHex, strongSize: strongSize, strongFamily: strongFamily,
            bodySize: bodySize, bodyFamily: bodyFamily, lineHeight: lineHeight,
            paragraphSpacing: paragraphSpacing, baseURL: baseURL, scrollTarget: nil,
            scrollRequest: 0, sourceLineTarget: 1, sourceLineRequest: 0,
            onSourceLineChange: { _ in }, onActivate: {})
        let document = MarkdownVisualDocument(source: source, blocks: renderedBlocks)
        let content: String
        if renderedBlocks.isEmpty {
            content = "<div data-visual-index=\"0\" contenteditable=\"true\"><p><br></p></div>"
        } else {
            content = renderedBlocks.enumerated().map { index, block in
                if let embedded = embeddedNoteHTML(document.segments[index]) {
                    return "<div data-visual-index=\"\(index)\" contenteditable=\"false\" data-source-line=\"\(block.sourceLine)\">\(embedded)</div>"
                }
                let editable = document.editable[index] ? "true" : "false"
                let title = document.editable[index] ? "" : " title=\"此区块请在 Markdown 源码模式编辑\""
                return block.html.replacingOccurrences(of: "<div data-source-line=",
                    with: "<div data-visual-index=\"\(index)\" contenteditable=\"\(editable)\"\(title) data-source-line=",
                    range: block.html.range(of: "<div data-source-line="))
            }.joined(separator: "\n")
        }
        let originalContent = renderedBlocks.map(\.html).joined(separator: "\n")
        let parentPath = scrollState.documentPath
        let childURL = MarkdownNoteHierarchy.childrenDirectory(of: URL(fileURLWithPath: parentPath))
        // WebKit resolves file links through filesystem symlinks (for example,
        // /tmp becomes /private/tmp). Compare against the same physical path.
        let directory: String
        if parentPath.isEmpty {
            directory = ""
        } else if let resolved = realpath(childURL.path, nil) {
            defer { free(resolved) }
            directory = URL(fileURLWithPath: String(cString: resolved), isDirectory: true).absoluteString
        } else {
            directory = childURL.absoluteString
        }
        let originalDirectory = parentPath.isEmpty ? "" : childURL.absoluteString
        let safeDirectory = originalDirectory.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;")
        let safeRealDirectory = directory.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;")
        return preview.pageHTML
            .replacingOccurrences(of: "<main>\(originalContent)</main>", with: "<main data-note-children=\"\(safeDirectory)\" data-note-children-real=\"\(safeRealDirectory)\">\(content)</main>")
            .replacingOccurrences(of: "</style>", with: """
                html{scroll-behavior:auto}
                [data-visual-index][contenteditable=true]{min-height:1.2em;outline:none;cursor:text;caret-color:rgba(55,65,75,.78)}
                [data-visual-index][contenteditable=true] :is(h1,h2,h3,h4,h5,h6):empty{min-height:1em}
                [data-visual-index][contenteditable=true]:focus{background:rgba(80,125,170,.045);border-radius:4px}
                [data-visual-index][contenteditable=false]{cursor:default}
                a[href$=".md"]::before,a[href$=".markdown"]::before{content:"📄 ";font-size:.9em;text-decoration:none}
                .embedded-note{border:1px solid #ddd;border-radius:6px;padding:10px 14px;margin:8px 0}.embedded-note summary{cursor:pointer;font-weight:600}.embedded-note > a{font-size:.85em}
                #mdstudio-slash{position:fixed;z-index:10000;min-width:210px;max-height:260px;overflow:auto;background:white;border:1px solid #ddd;border-radius:8px;box-shadow:0 4px 18px #0002;padding:5px;font:13px -apple-system,sans-serif}
                #mdstudio-slash button{display:block;width:100%;text-align:left;border:0;background:transparent;border-radius:4px;padding:6px 9px;color:#333}
                #mdstudio-slash button.selected{background:#eef1f4}
                ::selection{background:rgba(65,130,200,.25)}
                </style>
                """)
    }

    private func embeddedNoteHTML(_ segment: String) -> String? {
        let expression = #"^\[([^\]\n]+)\]\(([^\s]+) [\"']mdstudio-embed[\"']\)$"#
        let text = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let regex = try? NSRegularExpression(pattern: expression),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let titleRange = Range(match.range(at: 1), in: text),
              let pathRange = Range(match.range(at: 2), in: text),
              let baseURL else { return nil }
        let relative = String(text[pathRange]).removingPercentEncoding ?? String(text[pathRange])
        guard !relative.hasPrefix("/"), !relative.contains(":") else { return nil }
        let file = baseURL.appendingPathComponent(relative).standardizedFileURL
        guard ["md", "markdown"].contains(file.pathExtension.lowercased()),
              let data = try? Data(contentsOf: file), data.count <= 2_000_000,
              let content = String(data: data, encoding: .utf8) else { return nil }
        func escape(_ value: String) -> String {
            value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
        }
        let rendered = MarkdownBlock.parse(content).map(\.html).joined(separator: "\n")
            .replacingOccurrences(of: #" data-source-line="[0-9]+""#, with: "", options: .regularExpression)
        return "<details class=\"embedded-note\"><summary>📄 \(escape(String(text[titleRange])))</summary><a href=\"\(escape(String(text[pathRange])))\">打开子笔记编辑</a><div>\(rendered)</div></details>"
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var source: String
        var onActivate: () -> Void
        var onImagePaste: (NSPasteboard) -> String?
        var onMarkdownLink: (URL) -> Void = { _ in }
        var onSlashCommand: (String, String?) -> Void = { _, _ in }
        var onDeleteManagedNote: (URL) -> Void = { _ in }
        weak var webView: WKWebView?
        var document = MarkdownVisualDocument(source: "", blocks: [])
        var lastLoadedSource: String?
        var lastEmittedSource: String?
        var styleKey: String?
        var lastWidth = -1.0
        var lastScrollRequest = -1
        var lastSourceLineRequest = -1
        var lastRestoreRequest = -1
        var needsPositionRestore = false
        var pendingSourceLine: Int?
        var pendingScrollID: String?
        var hasLoadedPage = false
        var onSourceLineChange: ((Int) -> Void)?
        var scrollState: MarkdownVisualScrollState?
        private var scrollObserver: NSObjectProtocol?
        private var scrollSampleSequence = 0
        private var lastReportedLine = 0
        private var suppressScrollReport = false
        private var pendingURL: URL?
        private var lastAppliedRevision: [Int: Int] = [:]
        private var pendingFlushCompletions: [String: @MainActor () -> Void] = [:]
        private var restoredViewport: MarkdownViewportAnchor?
        private var restoredScrollY: Double?
        private var restoredSource = ""

        init(source: Binding<String>, onActivate: @escaping () -> Void,
             onImagePaste: @escaping (NSPasteboard) -> String?) {
            _source = source
            self.onActivate = onActivate
            self.onImagePaste = onImagePaste
        }

        func load(_ html: String, baseURL: URL?, in webView: WKWebView) {
            scrollSampleSequence += 1
            cleanup()
            if let baseURL, baseURL.isFileURL {
                let file = baseURL.appendingPathComponent(".mdstudio-visual-\(UUID().uuidString).html")
                do {
                    try Data(html.utf8).write(to: file, options: .atomic)
                    pendingURL = file
                    webView.loadFileURL(file, allowingReadAccessTo: baseURL)
                    return
                } catch { try? FileManager.default.removeItem(at: file) }
            }
            webView.loadHTMLString(html, baseURL: baseURL)
        }

        func cleanup() {
            if let pendingURL { try? FileManager.default.removeItem(at: pendingURL) }
            pendingURL = nil
        }

        func observe(_ scrollView: NSScrollView) {
            if let scrollObserver { NotificationCenter.default.removeObserver(scrollObserver) }
            scrollObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.reportVisiblePosition() }
            }
        }

        func stopObserving() {
            scrollSampleSequence += 1
            if let scrollObserver { NotificationCenter.default.removeObserver(scrollObserver) }
            scrollObserver = nil
            onSourceLineChange = nil
        }

        private func reportVisiblePosition() {
            guard hasLoadedPage, !suppressScrollReport, scrollState?.activeMode != .source, let webView else { return }
            scrollSampleSequence += 1
            let sample = scrollSampleSequence
            webView.evaluateJavaScript("(()=>{const a=[...document.querySelectorAll('[data-source-line]')];let e=a[0];for(const x of a){if(x.getBoundingClientRect().top<=40)e=x;else break}return Number(e?.dataset.sourceLine||1)})()",
                                       in: nil, in: MarkdownVisualEditor.contentWorld) { [weak self] result in
                guard let self, sample == self.scrollSampleSequence,
                      case .success(let value) = result,
                      let line = value as? Int, line > 0, line != self.lastReportedLine else { return }
                self.lastReportedLine = line
                self.onSourceLineChange?(line)
            }
        }

        func scrollIfReady(in webView: WKWebView) {
            guard hasLoadedPage, let id = pendingScrollID else { return }
            pendingScrollID = nil
            let safeID = id.replacingOccurrences(of: "'", with: "")
            webView.evaluateJavaScript("document.getElementById('\(safeID)')?.scrollIntoView({behavior:'auto',block:'start'})",
                                       in: nil, in: MarkdownVisualEditor.contentWorld, completionHandler: nil)
        }

        func scrollToSourceLineIfReady(in webView: WKWebView) {
            guard hasLoadedPage, pendingScrollID == nil,
                  let line = pendingSourceLine else { return }
            pendingSourceLine = nil
            suppressScrollReport = true
            webView.evaluateJavaScript("(()=>{const a=[...document.querySelectorAll('[data-source-line]')];let e=a[0];for(const x of a){if(Number(x.dataset.sourceLine)>\(line))break;e=x}e?.scrollIntoView({behavior:'auto',block:'start'})})()",
                                       in: nil, in: MarkdownVisualEditor.contentWorld) { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self?.suppressScrollReport = false }
            }
        }

        func restoreEditingPositionIfReady(in webView: WKWebView) {
            guard hasLoadedPage, let scrollState, let viewport = scrollState.viewport else { return }
            needsPositionRestore = false
            pendingSourceLine = nil
            suppressScrollReport = true
            var position: [String: Any] = [:]
            if let selection = scrollState.selection {
                let anchor = document.visualAnchor(forSourceOffset: selection.location)
                let focus = document.visualAnchor(forSourceOffset: NSMaxRange(selection))
                position["anchor"] = ["index": anchor.index, "offset": anchor.offset]
                position["focus"] = ["index": focus.index, "offset": focus.offset]
            }
            let visible = document.visualAnchor(forSourceOffset: viewport.sourceOffset)
            position["viewport"] = ["index": visible.index, "offset": visible.offset, "screenY": viewport.screenY]
            let restoredSource = document.source
            webView.callAsyncJavaScript("""
                await new Promise(resolve => setTimeout(resolve, 0));
                window.markdownStudioRestorePosition(position);
                return window.scrollY;
                """, arguments: ["position": position], in: nil, in: MarkdownVisualEditor.contentWorld) { [weak self] result in
                    if case .success(let y) = result, let y = y as? Double {
                        self?.restoredViewport = viewport
                        self?.restoredScrollY = y
                        self?.restoredSource = restoredSource
                    }
                    self?.suppressScrollReport = false
                }
        }

        private func captureEditingPosition(_ payload: [String: Any]) {
            func anchor(_ value: Any?) -> MarkdownVisualAnchor? {
                guard let value = value as? [String: Any], let index = value["index"] as? Int,
                      let offset = value["offset"] as? Int else { return nil }
                return MarkdownVisualAnchor(index: index, offset: offset)
            }
            if let start = anchor(payload["anchor"]), let end = anchor(payload["focus"]) {
                let a = document.sourceOffset(for: start), b = document.sourceOffset(for: end)
                scrollState?.selection = NSRange(location: min(a, b), length: abs(a - b))
            }
            if let restoredViewport, let restoredScrollY, let currentY = payload["scrollY"] as? Double,
               abs(currentY - restoredScrollY) < 0.5, document.source == restoredSource {
                scrollState?.viewport = restoredViewport
            } else if let visible = anchor(payload["viewport"]), let details = payload["viewport"] as? [String: Any] {
                scrollState?.viewport = MarkdownViewportAnchor(sourceOffset: document.sourceOffset(for: visible),
                                                               screenY: details["screenY"] as? Double ?? 0)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            cleanup()
            if scrollObserver == nil, let scrollView = MarkdownVisualEditor.findScrollView(in: webView) {
                scrollView.contentView.postsBoundsChangedNotifications = true
                observe(scrollView)
            }
            hasLoadedPage = true
            webView.evaluateJavaScript("document.querySelector('main')?.style.setProperty('max-width', '\(Int(lastWidth + 76))px')",
                                       in: nil, in: MarkdownVisualEditor.contentWorld, completionHandler: nil)
            let hasOutlineTarget = pendingScrollID != nil
            scrollIfReady(in: webView)
            if !hasOutlineTarget, scrollState?.viewport != nil {
                restoreEditingPositionIfReady(in: webView)
            } else {
                scrollToSourceLineIfReady(in: webView)
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "visualEdit", let payload = message.body as? [String: Any] else { return }
            if payload["kind"] as? String == "activate" {
                scrollState?.activeMode = .visual
                MarkdownVisualCommandHub.activeWebView = webView
                onActivate()
                return
            }
            if payload["kind"] as? String == "flush" {
                if let edits = payload["edits"] as? [[String: Any]] {
                    for edit in edits {
                        guard let index = edit["index"] as? Int,
                              let markdown = edit["markdown"] as? String else { continue }
                        applyVisualEdit(index: index, markdown: markdown, revision: edit["revision"] as? Int)
                    }
                }
                if let position = payload["position"] as? [String: Any] { captureEditingPosition(position) }
                if let line = payload["visibleLine"] as? Int, line > 0 {
                    onSourceLineChange?(line)
                }
                if let id = payload["id"] as? String, let completion = pendingFlushCompletions.removeValue(forKey: id) { completion() }
                return
            }
            if payload["kind"] as? String == "openMarkdownLink",
               let href = payload["href"] as? String, let url = URL(string: href), url.isFileURL,
               ["md", "markdown"].contains(url.pathExtension.lowercased()) {
                onMarkdownLink(url)
                return
            }
            if payload["kind"] as? String == "slashCommand", let command = payload["command"] as? String {
                onSlashCommand(command, payload["token"] as? String)
                return
            }
            if payload["kind"] as? String == "deleteManagedNote", let href = payload["href"] as? String,
               let url = URL(string: href), url.isFileURL {
                onDeleteManagedNote(url)
                return
            }
            if payload["kind"] as? String == "pasteImage" {
                if let markdown = onImagePaste(.general) {
                    MarkdownVisualCommandHub.activeWebView = webView
                    _ = MarkdownVisualCommandHub.perform("imageMarkdown", value: markdown)
                }
                return
            }
            guard let index = payload["index"] as? Int,
                  let markdown = payload["markdown"] as? String else { return }
            applyVisualEdit(index: index, markdown: markdown, revision: payload["revision"] as? Int)
            onActivate()
            MarkdownVisualCommandHub.activeWebView = webView
        }

        func flushPendingEdits(in webView: WKWebView, completion: @escaping @MainActor () -> Void) {
            let id = UUID().uuidString
            pendingFlushCompletions[id] = completion
            let quotedID = (try? JSONSerialization.data(withJSONObject: [id])).flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
            webView.evaluateJavaScript("window.markdownStudioFlush ? window.markdownStudioFlush(...\(quotedID)) : 'missing'",
                                       in: nil, in: MarkdownVisualEditor.contentWorld) { [weak self] result in
                guard let self else { return }
                if case .success(let value) = result, value as? String == "composing" {
                    _ = webView.window?.makeFirstResponder(nil)
                }
                if case .success(let value) = result, value as? String == "missing",
                   let callback = self.pendingFlushCompletions.removeValue(forKey: id) { callback() }
                if case .failure = result,
                   let callback = self.pendingFlushCompletions.removeValue(forKey: id) { callback() }
            }
        }

        private func applyVisualEdit(index: Int, markdown: String, revision: Int?) {
            if let revision {
                guard revision >= lastAppliedRevision[index, default: -1] else { return }
                lastAppliedRevision[index] = revision
            }
            if let updated = document.replaceBlock(at: index, with: markdown) {
                lastEmittedSource = updated
                source = updated
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else { decisionHandler(.allow); return }
            if url.isFileURL && ["md", "markdown"].contains(url.pathExtension.lowercased()) {
                onMarkdownLink(url)
            } else if ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
        }
    }

    static let editorScript = #"""
    (() => {
      const bridge = window.webkit.messageHandlers.visualEdit;
      const root = document.querySelector('main');
      if (!root) return;
      let composing = false;
      const dirty = new Set();
      const pending = new Map();
      const revisions = new Map();
      const childDirectory = root.dataset.noteChildren || '';
      const childRealDirectory = root.dataset.noteChildrenReal || childDirectory;
      for (const link of root.querySelectorAll('a[href]')) {
        let directChild = false;
        try {
          const target = new URL(link.href), directory = new URL('.', target);
          directChild = target.protocol === 'file:' && (directory.href === childDirectory || directory.href === childRealDirectory) && /\.(md|markdown)$/i.test(target.pathname);
        } catch (_) {}
        if (directChild || (!childDirectory && link.getAttribute('title') === 'mdstudio-page')) {
          link.contentEditable = 'false'; link.classList.add('managed-note');
        }
      }
      const managedSnapshots = new Map();
      for (const element of root.querySelectorAll('[data-visual-index]')) {
        const links = [...element.querySelectorAll('a.managed-note')];
        if (links.length) managedSnapshots.set(Number(element.dataset.visualIndex), {
          html:element.innerHTML, links:links.map(link => ({href:link.href, text:link.textContent, title:link.getAttribute('title')}))
        });
      }
      const escapeText = text => text.replace(/\\/g, '\\\\').replace(/([*_\[\]`])/g, '\\$1');
      function textValue(node, end) {
        let value = (node.nodeValue || '').slice(0, end);
        if (node.parentElement?.closest('pre')) return value;
        if (node.previousSibling?.nodeName === 'BR') value = value.replace(/^[\r\n\t ]+/, '');
        return value.replace(/[\r\n\t]+/g, ' ');
      }
      function inline(node, inherited = {}) {
        if (node.nodeType === Node.TEXT_NODE) return escapeText(textValue(node));
        if (node.nodeType !== Node.ELEMENT_NODE) return '';
        const tag = node.tagName.toLowerCase();
        if (tag === 'br') return '\n';
        if (tag === 'img') return '![' + escapeText(node.getAttribute('alt') || '') + '](' + (node.getAttribute('src') || '') + ')';
        // WebKit may wrap formatted text in nested tags or styled spans while a
        // contenteditable block is being edited. Track inherited marks so the
        // Markdown output contains one pair of delimiters, not ****text****.
        const marks = {...inherited};
        if (tag === 'strong' || tag === 'b') marks.bold = true;
        if (tag === 'em' || tag === 'i') marks.italic = true;
        if (tag === 'u') marks.underline = true;
        if (tag === 's' || tag === 'del' || tag === 'strike') marks.strike = true;
        if (tag === 'span') {
          const style = node.style;
          if (style.fontWeight === 'bold' || Number.parseInt(style.fontWeight, 10) >= 600) marks.bold = true;
          if (style.fontStyle === 'italic' || style.fontStyle === 'oblique') marks.italic = true;
          if (style.textDecorationLine.includes('underline')) marks.underline = true;
          if (style.textDecorationLine.includes('line-through')) marks.strike = true;
        }
        let inner = [...node.childNodes].map(child => inline(child, marks)).join('');
        const wrap = (text, start, end = start) => {
          const match = /^(\s*)([\s\S]*?)(\s*)$/.exec(text);
          return match && match[2] ? match[1] + start + match[2] + end + match[3] : text;
        };
        if (marks.strike && !inherited.strike) inner = wrap(inner, '~~');
        if (marks.underline && !inherited.underline) inner = wrap(inner, '<u>', '</u>');
        if (marks.italic && !inherited.italic) inner = wrap(inner, '*');
        if (marks.bold && !inherited.bold) {
          const nextText = node.nextSibling?.textContent || '';
          const boldText = node.textContent || '';
          if (/[）)]$/.test(boldText) && /^\p{Script=Han}/u.test(nextText)
              && [...node.childNodes].every(child => child.nodeType === Node.TEXT_NODE)) {
            // CommonMark does not close ** after punctuation when the next
            // character is a letter. Use safe inline HTML to keep the bold
            // mark without inserting a visible space into the user's prose.
            const escaped = boldText.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
            inner = '<strong>' + escaped + '</strong>';
          } else inner = wrap(inner, '**');
        }
        if (tag === 'code') return '`' + (node.textContent || '').replace(/`/g, '\\`') + '`';
        if (tag === 'a') return '[' + inner + '](' + (node.getAttribute('href') || '') + (node.getAttribute('title') === 'mdstudio-page' ? ' "mdstudio-page"' : '') + ')';
        return inner;
      }
      function list(node, depth) {
        const ordered = node.tagName.toLowerCase() === 'ol';
        let number = Number(node.getAttribute('start') || 1);
        return [...node.children].filter(x => x.tagName?.toLowerCase() === 'li').map(li => {
          const nested = [...li.children].filter(x => /^(ul|ol)$/i.test(x.tagName));
          const text = [...li.childNodes].filter(x => !nested.includes(x)).map(x => inline(x)).join('').trim();
          const checkbox = li.querySelector(':scope > input[type=checkbox]');
          const prefix = ordered ? (number++) + '. ' : '- ';
          const task = checkbox ? (checkbox.checked ? '[x] ' : '[ ] ') : '';
          return '  '.repeat(depth) + prefix + task + text + (nested.length ? '\n' + nested.map(x => list(x, depth + 1)).join('\n') : '');
        }).join('\n');
      }
      function table(node) {
        const rows = [...node.querySelectorAll('tr')].map(tr => [...tr.children].filter(c => /^(td|th)$/i.test(c.tagName))
          .map(c => inline(c).replace(/\|/g, '\\|').replace(/\n/g, '<br>')));
        if (!rows.length) return '';
        const width = Math.max(...rows.map(r => r.length));
        const row = cells => '| ' + Array.from({length:width}, (_, i) => cells[i] || '').join(' | ') + ' |';
        return [row(rows[0]), row(Array(width).fill('---')), ...rows.slice(1).map(row)].join('\n');
      }
      function block(node) {
        if (node.nodeType === Node.TEXT_NODE) return escapeText(node.nodeValue || '');
        if (node.nodeType !== Node.ELEMENT_NODE) return '';
        const tag = node.tagName.toLowerCase();
        if (/^h[1-6]$/.test(tag)) return '#'.repeat(Number(tag[1])) + ' ' + [...node.childNodes].map(x => inline(x)).join('').trim();
        if (tag === 'ul' || tag === 'ol') return list(node, 0);
        if (tag === 'blockquote') return flow(node.childNodes).split('\n').map(x => '> ' + x).join('\n');
        if (tag === 'pre') return '```' + (node.querySelector('code')?.className?.replace(/^language-/, '') || '') + '\n' + (node.textContent || '').replace(/\n$/, '') + '\n```';
        if (tag === 'table') return table(node);
        if (tag === 'hr') return '---';
        return flow(node.childNodes).trimEnd();
      }
      // Inline siblings belong to the same line, regardless of whether WebKit
      // puts them in P, DIV, or directly in the contenteditable root. Only an
      // actual block element may introduce a line/paragraph separator.
      function flow(nodes) {
        const parts = [];
        let inlineNodes = [];
        const flushInline = () => {
          if (!inlineNodes.length) return;
          const markdown = inlineNodes.map(x => inline(x)).join('');
          if (markdown.trim()) parts.push({tag:'inline', markdown});
          inlineNodes = [];
        };
        for (const node of nodes) {
          const tag = node.nodeType === Node.ELEMENT_NODE ? node.tagName.toLowerCase() : '';
          if (/^(div|p|h[1-6]|ul|ol|blockquote|pre|table|hr)$/.test(tag)) {
            flushInline();
            const markdown = block(node);
            // Keep an empty DIV: it represents an intentional empty editor line.
            if (markdown.trim() || tag === 'div') parts.push({tag, markdown});
          } else {
            inlineNodes.push(node);
          }
        }
        flushInline();
        return parts.reduce((result, item, index) => {
          if (!index) return item.markdown;
          const previous = parts[index-1];
          const isEditorLine = (item.tag === 'div' && /^(div|inline)$/.test(previous.tag))
            || (previous.tag === 'div' && item.tag === 'inline');
          return result + (isEditorLine ? '\n' : '\n\n') + item.markdown;
        }, '');
      }
      function publish(element) {
        if (!element || composing || element.contentEditable !== 'true') return;
        const index = Number(element.dataset.visualIndex);
        if (!dirty.has(index)) return;
        const snapshot = managedSnapshots.get(index);
        if (snapshot) {
          const current = [...element.querySelectorAll('a[href]')];
          const matched = new Set();
          const missing = snapshot.links.find(saved => {
            const index = current.findIndex((link, i) => !matched.has(i) && link.href === saved.href && link.textContent === saved.text);
            if (index < 0) return true;
            matched.add(index); return false;
          });
          if (missing) {
            element.innerHTML = snapshot.html;
            element.querySelectorAll('a.managed-note').forEach(link => { link.contentEditable = 'false'; });
            dirty.delete(index);
            bridge.postMessage({kind:'deleteManagedNote', href:missing.href});
            return;
          }
          for (const saved of snapshot.links) {
            const link = current.find(item => item.href === saved.href && item.textContent === saved.text);
            if (link) { link.classList.add('managed-note'); link.contentEditable = 'false'; if (saved.title === 'mdstudio-page') link.title = saved.title; }
          }
          snapshot.html = element.innerHTML;
        }
        const markdown = flow(element.childNodes);
        dirty.delete(index);
        const revision = (revisions.get(index) || 0) + 1;
        revisions.set(index, revision);
        const edit = {index, markdown, revision};
        pending.set(index, edit);
        bridge.postMessage(edit);
      }
      function managedLinkForSelection(backwards) {
        const selection = getSelection(); if (!selection?.rangeCount) return null;
        const range = selection.getRangeAt(0), links = [...root.querySelectorAll('a.managed-note')];
        const parent = range.startContainer.nodeType === Node.ELEMENT_NODE ? range.startContainer : range.startContainer.parentElement;
        let hit = parent?.closest?.('a.managed-note');
        if (!hit && !range.collapsed) hit = links.find(link => range.intersectsNode(link));
        if (!hit && range.collapsed) {
          const node = range.startContainer, offset = range.startOffset; let adjacent = null;
          if (node.nodeType === Node.TEXT_NODE) {
            if (backwards && offset === 0) adjacent = node.previousSibling;
            if (!backwards && offset === node.length) adjacent = node.nextSibling;
          } else if (node.nodeType === Node.ELEMENT_NODE) adjacent = node.childNodes[backwards ? offset - 1 : offset];
          if (adjacent?.nodeType === Node.ELEMENT_NODE) hit = adjacent.matches('a.managed-note') ? adjacent : adjacent.querySelector?.('a.managed-note');
        }
        return hit || null;
      }
      root.addEventListener('keydown', event => {
        if (composing || event.isComposing || !['Backspace','Delete'].includes(event.key)) return;
        const hit = managedLinkForSelection(event.key === 'Backspace');
        if (!hit) return;
        event.preventDefault(); event.stopImmediatePropagation();
        bridge.postMessage({kind:'deleteManagedNote', href:hit.href});
      });
      root.addEventListener('beforeinput', event => {
        if (!event.inputType?.startsWith('delete') && !event.inputType?.startsWith('insert')) return;
        const hit = managedLinkForSelection(event.inputType.includes('Backward'));
        if (!hit) return;
        event.preventDefault();
        bridge.postMessage({kind:'deleteManagedNote', href:hit.href});
      });
      root.addEventListener('click', event => {
        const link = event.target.closest?.('a[href]');
        if (!link) return;
        try {
          const url = new URL(link.href);
          if (url.protocol === 'file:' && /\.(md|markdown)$/i.test(url.pathname)) {
            event.preventDefault();
            bridge.postMessage({kind:'openMarkdownLink', href:url.href});
          }
        } catch (_) {}
      });
      root.addEventListener('compositionstart', () => { composing = true; });
      root.addEventListener('focusin', () => bridge.postMessage({kind:'activate'}));
      const slashCommands = [
        ['page','新建子笔记','page 子笔记 页面'], ['text','段落','text plain 段落'],
        ['chapter','关联当前原文章节','chapter epub 章节 关联'],
        ['h1','一级标题','h1 标题1'], ['h2','二级标题','h2 标题2'], ['h3','三级标题','h3 标题3'],
        ['h4','四级标题','h4 标题4'], ['h5','五级标题','h5 标题5'], ['h6','六级标题','h6 标题6'],
        ['bullet','无序列表','bullet list 无序'], ['num','有序列表','num numbered 有序'],
        ['todo','任务列表','todo task 任务'], ['quote','引用','quote 引用'], ['div','分隔线','div divider 分隔线'],
        ['table','表格','table 表格'], ['image','图片','image 图片'], ['link','插入已有笔记链接','link 链接'],
        ['bold','加粗','bold 加粗'], ['italic','斜体','italic 斜体'], ['underline','下划线','underline 下划线'],
        ['strike','删除线','strike 删除线'], ['code','行内代码','code 代码']
      ];
      let slashMenu = null, slashRange = null, slashItems = [], slashIndex = 0;
      function closeSlash() { slashMenu?.remove(); slashMenu = null; slashRange = null; slashItems = []; slashIndex = 0; }
      function chooseSlash(index) {
        const item = slashItems[index]; const range = slashRange;
        if (!item || !range || !range.startContainer.isConnected) { closeSlash(); return; }
        const block = range.startContainer.parentElement?.closest('[data-visual-index][contenteditable=true]');
        range.deleteContents();
        let token = null;
        if (item[0] === 'page' || item[0] === 'chapter') {
          token = '\uE000mdstudio-' + item[0] + '-' + Date.now() + '-' + Math.random().toString(36).slice(2) + '\uE001';
          const marker = document.createTextNode(token); range.insertNode(marker); range.setStartAfter(marker); range.collapse(true);
        }
        const selection = getSelection(); selection.removeAllRanges(); selection.addRange(range);
        closeSlash();
        const direct = {text:'paragraph', bullet:'unordered', num:'ordered', todo:'task', quote:'quote',
          div:'rule', bold:'bold', italic:'italic', underline:'underline', strike:'strikeThrough', code:'code'};
        if (/^h[1-6]$/.test(item[0])) {
          window.markdownStudioCommand('heading', item[0].slice(1));
          return;
        }
        if (direct[item[0]]) {
          window.markdownStudioCommand(direct[item[0]], '');
          return;
        }
        if (block) { dirty.add(Number(block.dataset.visualIndex)); publish(block); }
        bridge.postMessage({kind:'slashCommand', command:item[0], token});
      }
      function updateSlash() {
        if (composing) { closeSlash(); return; }
        const selection = getSelection(), node = selection?.anchorNode;
        if (!selection?.isCollapsed || node?.nodeType !== Node.TEXT_NODE || !node.parentElement?.closest('[contenteditable=true]') || node.parentElement?.closest('pre,code,a')) { closeSlash(); return; }
        const offset = selection.anchorOffset, text = (node.nodeValue || '').slice(0, offset);
        const match = /(?:^|\s)\/([a-z0-9#\u4e00-\u9fff]*)$/i.exec(text);
        if (!match) { closeSlash(); return; }
        const query = match[1].toLowerCase();
        slashItems = slashCommands.filter(item => item[2].toLowerCase().includes(query));
        if (!slashItems.length) { closeSlash(); return; }
        slashIndex = Math.min(slashIndex, slashItems.length - 1);
        slashRange = document.createRange(); slashRange.setStart(node, offset - query.length - 1); slashRange.setEnd(node, offset);
        if (!slashMenu) { slashMenu = document.createElement('div'); slashMenu.id = 'mdstudio-slash'; document.body.appendChild(slashMenu); }
        slashMenu.replaceChildren();
        slashItems.forEach((item, index) => {
          const button = document.createElement('button'); button.type = 'button'; button.textContent = item[1] + '  /' + item[0];
          if (index === slashIndex) button.className = 'selected';
          button.addEventListener('mousedown', event => { event.preventDefault(); chooseSlash(index); });
          slashMenu.appendChild(button);
        });
        const rect = slashRange.getBoundingClientRect();
        slashMenu.style.left = Math.max(8, Math.min(rect.left, window.innerWidth - 230)) + 'px';
        slashMenu.style.top = Math.max(8, Math.min(rect.bottom + 4, window.innerHeight - 280)) + 'px';
      }
      root.addEventListener('keydown', event => {
        if (!slashMenu || composing || event.isComposing) return;
        if (event.key === 'Escape') { event.preventDefault(); closeSlash(); }
        else if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
          event.preventDefault(); slashIndex = (slashIndex + (event.key === 'ArrowDown' ? 1 : -1) + slashItems.length) % slashItems.length; updateSlash();
        } else if (event.key === 'Enter') { event.preventDefault(); chooseSlash(slashIndex); }
      });
      root.addEventListener('compositionend', event => {
        composing = false; const block = event.target.closest('[data-visual-index]');
        if (block) dirty.add(Number(block.dataset.visualIndex));
        publish(block);
        updateSlash();
      });
      root.addEventListener('input', event => {
        if (composing) return;
        const block = event.target.closest('[data-visual-index]');
        if (block) dirty.add(Number(block.dataset.visualIndex));
        publish(block);
        updateSlash();
      });
      root.addEventListener('paste', event => {
        if ([...(event.clipboardData?.items || [])].some(item => item.type.startsWith('image/'))) {
          event.preventDefault();
          bridge.postMessage({kind:'pasteImage'});
          return;
        }
        // A contenteditable WebView normally imports text/html, including the
        // source app's fonts, colors and paragraph styles. Paste its plain-text
        // representation so the notebook controls the appearance consistently.
        const clipboard = event.clipboardData;
        if (!clipboard) return;
        const plain = clipboard.getData('text/plain');
        const html = clipboard.getData('text/html');
        if (!plain && !html) return;
        event.preventDefault();
        const text = (plain || new DOMParser().parseFromString(html, 'text/html').body.textContent || '')
          .replace(/\r\n?/g, '\n');
        document.execCommand('insertText', false, text);
        const block = event.target.closest('[data-visual-index]');
        if (block) { dirty.add(Number(block.dataset.visualIndex)); publish(block); }
      });
      root.addEventListener('focusout', event => {
        const block = event.target.closest('[data-visual-index]');
        publish(block);
      });
      const ignoredText = node => node.nodeType === Node.TEXT_NODE
        && /^[\t\r\n ]*$/.test(node.nodeValue || '') && /[\r\n]/.test(node.nodeValue || '')
        && !node.parentElement?.closest('pre,code');
      function textLength(node) {
        if (ignoredText(node)) return 0;
        if (node.nodeType === Node.TEXT_NODE) return textValue(node).length;
        if (node.nodeType !== Node.ELEMENT_NODE) return 0;
        if (node.tagName === 'BR') return 1;
        return [...node.childNodes].reduce((sum, child) => sum + textLength(child), 0);
      }
      function textAnchor(node, offset) {
        const element = node?.nodeType === Node.ELEMENT_NODE ? node : node?.parentElement;
        const block = element?.closest('[data-visual-index]');
        if (!block) return null;
        let count = 0, found = false;
        function visit(current) {
          if (found) return;
          if (current === node) {
            count += current.nodeType === Node.TEXT_NODE ? (ignoredText(current) ? 0 : textValue(current,offset).length)
              : [...current.childNodes].slice(0, offset).reduce((sum, child) => sum + textLength(child), 0);
            found = true; return;
          }
          if (current.nodeType === Node.TEXT_NODE || current.nodeName === 'BR') { count += textLength(current); return; }
          for (const child of current.childNodes) { visit(child); if (found) break; }
        }
        visit(block);
        return {index:Number(block.dataset.visualIndex), offset:count};
      }
      function resolveAnchor(anchor) {
        if (!anchor) return null;
        const block = root.querySelector('[data-visual-index="' + anchor.index + '"]');
        if (!block) return null;
        let remaining = Math.max(0, anchor.offset), result = null, last = null;
        function visit(node) {
          if (result || ignoredText(node)) return;
          if (node.nodeType === Node.TEXT_NODE) {
            last = {node, offset:(node.nodeValue || '').length};
            const length = textValue(node).length;
            if (remaining <= length) {
              let low=0,high=last.offset;
              while(low<high) { const middle=Math.floor((low+high)/2); if(textValue(node,middle).length<remaining)low=middle+1;else high=middle; }
              result={node,offset:low};
            } else remaining -= length;
            return;
          }
          if (node.nodeName === 'BR') { remaining = Math.max(0, remaining - 1); return; }
          for (const child of node.childNodes) { visit(child); if (result) break; }
        }
        visit(block);
        return result || last || {node:block, offset:0};
      }
      function pointRect(point) {
        if (!point) return null;
        const range = document.createRange(); range.setStart(point.node, point.offset); range.collapse(true);
        let rect = range.getBoundingClientRect();
        if (!rect.height && point.node.nodeType === Node.TEXT_NODE && point.node.length) {
          const at = Math.min(point.offset, point.node.length-1);
          range.setStart(point.node, at); range.setEnd(point.node, at+1); rect = range.getBoundingClientRect();
        }
        return rect.height ? rect : (point.node.nodeType === Node.ELEMENT_NODE ? point.node : point.node.parentElement).getBoundingClientRect();
      }
      window.markdownStudioPosition = () => {
        const selection = getSelection();
        const anchor = textAnchor(selection?.anchorNode, selection?.anchorOffset || 0);
        const focus = textAnchor(selection?.focusNode, selection?.focusOffset || 0);
        const blocks = [...root.querySelectorAll('[data-visual-index]')];
        const visible = blocks.find(x => x.getBoundingClientRect().bottom > 1) || blocks[blocks.length-1];
        const bounds = visible?.getBoundingClientRect();
        const range = bounds ? document.caretRangeFromPoint(Math.max(1,bounds.left+2), Math.max(1,bounds.top+2)) : null;
        let viewport = range ? textAnchor(range.startContainer, range.startOffset) : null;
        const point = viewport ? {node:range.startContainer, offset:range.startOffset} : resolveAnchor({index:Number(visible?.dataset.visualIndex||0),offset:0});
        if (!viewport && point) viewport = textAnchor(point.node, point.offset);
        return {anchor, focus, viewport:viewport ? {...viewport, screenY:pointRect(point)?.top || 0} : null, scrollY:window.scrollY};
      };
      window.markdownStudioRestorePosition = position => {
        const anchor = resolveAnchor(position.anchor), focus = resolveAnchor(position.focus);
        if (anchor && focus) {
          const element = anchor.node.nodeType === Node.ELEMENT_NODE ? anchor.node : anchor.node.parentElement;
          element.closest('[contenteditable]')?.focus({preventScroll:true});
          getSelection().setBaseAndExtent(anchor.node,anchor.offset,focus.node,focus.offset);
        }
        const viewport = resolveAnchor(position.viewport);
        const rect = pointRect(viewport);
        if (rect) window.scrollBy({top:rect.top - position.viewport.screenY,behavior:'instant'});
        return true;
      };
      // Mode switches can dismantle this WebView before its asynchronous
      // message reaches SwiftUI. Return every pending edit and keep the IME
      // composition boundary intact before the host switches panes.
      window.markdownStudioFlush = id => {
        const snapshot = () => {
          for (const index of [...dirty]) publish(root.querySelector('[data-visual-index="' + index + '"]'));
          const anchors=[...document.querySelectorAll('[data-source-line]')];
          let visible=anchors[0];
          for (const item of anchors) { if (item.getBoundingClientRect().top<=40) visible=item; else break; }
          bridge.postMessage({kind:'flush', id, edits:[...pending.values()], visibleLine:Number(visible?.dataset.sourceLine||1), position:window.markdownStudioPosition()});
        };
        if (!composing) { snapshot(); return 'requested'; }
        root.addEventListener('compositionend', () => setTimeout(snapshot, 0), {once:true});
        return 'composing';
      };
      window.markdownStudioCommand = (name, value) => {
        const selection = window.getSelection();
        const node = selection?.anchorNode;
        const target = node?.nodeType === Node.ELEMENT_NODE ? node : node?.parentElement;
        const blockElement = target?.closest('[data-visual-index][contenteditable=true]') || root.querySelector('[data-visual-index][contenteditable=true]');
        if (!blockElement) return false;
        blockElement.focus();
        if (name === 'heading') {
          const level = Number(value);
          if (!Number.isInteger(level) || level < 1 || level > 6) return false;
          const li = target?.closest('li');
          const listElement = li?.parentElement;
          if (li && /^(ul|ol)$/i.test(listElement?.tagName || '')
              && listElement.parentElement === blockElement && !li.querySelector('ul,ol')) {
            // formatBlock inside a list can create <h5><ul><li>...</li></ul></h5>.
            // That still looks indented and can later serialize as a list item
            // or bold text. Lift the current item out of the list explicitly.
            const heading = document.createElement('h' + level);
            let current = node;
            while (current && current.parentNode !== li) current = current.parentNode;
            if (!current) current = li.firstChild;
            const trailingBlocks = current ? [...li.childNodes]
              .slice([...li.childNodes].indexOf(current) + 1)
              .filter(item => item.nodeType !== Node.TEXT_NODE || item.textContent.trim()) : [];
            // Markdown-rendered lists contain <li><p>text</p></li>, while a
            // freshly typed list can contain text directly in the <li>.
            // After Return, only the current paragraph becomes the heading.
            if (current?.nodeType === Node.ELEMENT_NODE && /^(p|div)$/i.test(current.tagName)) {
              while (current.firstChild) heading.appendChild(current.firstChild);
              current.remove();
            } else if (current) {
              heading.appendChild(current);
            }
            if (!heading.textContent?.trim()) heading.replaceChildren(document.createElement('br'));
            const following = [...li.parentElement.children].slice([...li.parentElement.children].indexOf(li) + 1);
            const followingList = (trailingBlocks.length || following.length) ? listElement.cloneNode(false) : null;
            listElement.insertAdjacentElement('afterend', heading);
            if (followingList) {
              heading.insertAdjacentElement('afterend', followingList);
              if (trailingBlocks.length) {
                const trailingItem = document.createElement('li');
                for (const item of trailingBlocks) trailingItem.appendChild(item);
                followingList.appendChild(trailingItem);
              }
              for (const item of following) followingList.appendChild(item);
            }
            if (!li.textContent?.trim()) li.remove();
            if (!listElement.children.length) listElement.remove();
            const range = document.createRange(); range.selectNodeContents(heading); range.collapse(false);
            selection.removeAllRanges(); selection.addRange(range);
            dirty.add(Number(blockElement.dataset.visualIndex)); publish(blockElement);
            return true;
          }
          document.execCommand('formatBlock', false, 'h' + level);
        }
        else if (name === 'paragraph') document.execCommand('formatBlock', false, 'p');
        else if (name === 'unordered') document.execCommand('insertUnorderedList');
        else if (name === 'ordered') document.execCommand('insertOrderedList');
        else if (name === 'undo' || name === 'redo') document.execCommand(name);
        else if (name === 'bold' || name === 'italic' || name === 'underline' || name === 'strikeThrough') document.execCommand(name);
        else if (name === 'link') document.execCommand('createLink', false, value || 'https://');
        else if (name === 'code') document.execCommand('insertHTML', false, '<code>' + (selection?.toString() || '代码') + '</code>');
        else if (name === 'quote') document.execCommand('formatBlock', false, 'blockquote');
        else if (name === 'rule') document.execCommand('insertHorizontalRule');
        else if (name === 'image') document.execCommand('insertHTML', false, '<img src="' + value.replace(/"/g, '&quot;') + '" alt="图片">');
        else if (name === 'imageMarkdown') {
          const match = /^!\[([^\]]*)\]\((.*)\)$/.exec(value);
          if (!match) return false;
          const escaped = s => s.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
          document.execCommand('insertHTML', false, '<img src="' + escaped(match[2]) + '" alt="' + escaped(match[1]) + '">');
        }
        else if (name === 'table') {
          const cells = JSON.parse(value);
          const escaped = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
          const html = '<table><thead><tr>' + (cells[0] || []).map(x => '<th>' + escaped(x) + '</th>').join('') +
            '</tr></thead><tbody>' + cells.slice(1).map(row => '<tr>' + row.map(x => '<td>' + escaped(x) + '</td>').join('') +
            '</tr>').join('') + '</tbody></table>';
          document.execCommand('insertHTML', false, html);
        }
        else if (name === 'task') {
          document.execCommand('insertUnorderedList');
          const li = window.getSelection()?.anchorNode?.parentElement?.closest('li');
          if (li && !li.querySelector('input[type=checkbox]')) li.insertAdjacentHTML('afterbegin', '<input type="checkbox"> ');
        }
        else return false;
        if (['unordered','ordered','task'].includes(name)) {
          const point = selection?.anchorNode;
          const parent = point?.nodeType === Node.ELEMENT_NODE ? point : point?.parentElement;
          const item = parent?.closest?.('li') || blockElement.querySelector('li:last-child');
          if (item && !item.textContent.trim()) {
            const caret = document.createRange();
            const placeholder = item.querySelector('br');
            if (placeholder) caret.setStartBefore(placeholder); else { caret.selectNodeContents(item); caret.collapse(false); }
            caret.collapse(true);
            selection.removeAllRanges(); selection.addRange(caret);
          }
        }
        const affected = [...root.querySelectorAll('[data-visual-index][contenteditable=true]')]
          .filter(element => element === blockElement || selection?.containsNode(element, true));
        for (const element of affected) {
          dirty.add(Number(element.dataset.visualIndex));
          const anchor = selection?.anchorNode;
          const anchorElement = anchor?.nodeType === Node.ELEMENT_NODE ? anchor : anchor?.parentElement;
          const heading = anchorElement?.closest?.('h1,h2,h3,h4,h5,h6');
          // Keep an empty heading in WebKit until the first keystroke: rebuilding
          // an empty Markdown heading can otherwise remove the insertion caret.
          if (name === 'heading' && heading && !heading.textContent.trim()) continue;
          const item = anchorElement?.closest?.('li');
          if (['unordered','ordered','task'].includes(name) && item && !item.textContent.trim()) continue;
          publish(element);
        }
        return true;
      };
    })();
    """#
}

@MainActor
private final class VisualEditorWebView: WKWebView {
    private let visualUndoManager = UndoManager()
    override var undoManager: UndoManager? { visualUndoManager }
    var onActivate: (() -> Void)?
    override func mouseDown(with event: NSEvent) {
        MarkdownVisualCommandHub.activeWebView = self
        // Preserve WebKit's native caret hit-testing before workspace activation
        // can cause SwiftUI to update the surrounding pane hierarchy.
        WorkspaceMouseDownHandling.perform(
            nativeMouseDown: { super.mouseDown(with: event) },
            activateWorkspace: { [weak self] in self?.onActivate?() }
        )
    }

}
