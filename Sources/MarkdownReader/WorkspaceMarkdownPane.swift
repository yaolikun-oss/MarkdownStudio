import AppKit
import SwiftUI

/// One editor tab bound to one document session. Source and visual tabs for the
/// same URL share `session`; unrelated documents never share text or position.
struct WorkspaceMarkdownPane: View {
    enum Mode: Hashable { case source, visual }

    @ObservedObject var session: WorkspaceMarkdownSession
    let mode: Mode
    let isActive: Bool
    let appearance: MarkdownDisplayStyle
    let syntaxHighlighting: Bool
    let onActivate: (WorkspaceMarkdownSession, Mode) -> Void
    let onTextChange: (WorkspaceMarkdownSession) -> Void
    let onSourceLineChange: (WorkspaceMarkdownSession, Int) -> Void
    let onOpenLink: (URL) -> Void
    let onNativeSlashCommand: (WorkspaceMarkdownSession, String, String?) -> Void
    let onDeleteManagedNote: (WorkspaceMarkdownSession, URL) -> Void
    let onError: (String) -> Void
    let navigationTarget: WorkspaceMarkdownNavigationTarget?

    @State private var blocks: [MarkdownBlock]
    @State private var parsedSource: String
    @State private var parseTask: Task<Void, Never>?
    @State private var sourceLine = 1
    @State private var sourceLineRequest = 0
    @State private var visualLineRequest = 0
    @State private var sourceRestoreRequest = 0
    @State private var visualRestoreRequest = 0
    @State private var focusRequest = 0

    init(session: WorkspaceMarkdownSession, mode: Mode, isActive: Bool, appearance: MarkdownDisplayStyle,
         syntaxHighlighting: Bool,
         onActivate: @escaping (WorkspaceMarkdownSession, Mode) -> Void,
         onTextChange: @escaping (WorkspaceMarkdownSession) -> Void,
         onSourceLineChange: @escaping (WorkspaceMarkdownSession, Int) -> Void = { _, _ in },
         onOpenLink: @escaping (URL) -> Void,
         onNativeSlashCommand: @escaping (WorkspaceMarkdownSession, String, String?) -> Void,
         onDeleteManagedNote: @escaping (WorkspaceMarkdownSession, URL) -> Void,
         onError: @escaping (String) -> Void,
         navigationTarget: WorkspaceMarkdownNavigationTarget? = nil) {
        self.session = session
        self.mode = mode
        self.isActive = isActive
        self.appearance = appearance
        self.syntaxHighlighting = syntaxHighlighting
        self.onActivate = onActivate
        self.onTextChange = onTextChange
        self.onSourceLineChange = onSourceLineChange
        self.onOpenLink = onOpenLink
        self.onNativeSlashCommand = onNativeSlashCommand
        self.onDeleteManagedNote = onDeleteManagedNote
        self.onError = onError
        self.navigationTarget = navigationTarget
        _blocks = State(initialValue: [])
        _parsedSource = State(initialValue: "")
    }

    var body: some View {
        Group {
            switch mode {
            case .source: sourcePane
            case .visual: visualPane
            }
        }
        .background(Color(hex: appearance.backgroundHex))
        .onChange(of: session.text) { _, text in
            onTextChange(session)
            if isActive { scheduleParse(text) }
        }
        .onChange(of: isActive) { _, active in
            if active {
                if parsedSource != session.text { scheduleParse(session.text, delayMilliseconds: 0) }
                if mode == .source { focusRequest += 1 }
            }
        }
        .task(id: session.url) {
            if isActive {
                scheduleParse(session.text, delayMilliseconds: 0)
                if mode == .source { focusRequest += 1 }
            }
        }
        .task(id: navigationTarget?.revision) {
            guard let target = navigationTarget else { return }
            sourceLine = target.sourceLine
            onSourceLineChange(session, target.sourceLine)
            sourceLineRequest += 1
            visualLineRequest += 1
        }
        .onDisappear { parseTask?.cancel() }
    }

    private var headings: [HeadingStyle] {
        (try? JSONDecoder().decode([HeadingStyle].self, from: appearance.headingStylesData)) ?? HeadingStyle.defaults
    }

    private var sourcePane: some View {
        MarkdownSourceEditor(text: $session.text, selection: $session.selection,
            fontSize: CGFloat(max(12, appearance.bodySize)), fontFamily: appearance.bodyFamily,
            lineHeight: CGFloat(appearance.lineHeight), paragraphSpacing: CGFloat(appearance.paragraphSpacing),
            backgroundHex: appearance.backgroundHex, headingStyles: headings,
            bodyColorHex: appearance.bodyColorHex, strongColorHex: appearance.strongColorHex,
            syntaxHighlightingEnabled: syntaxHighlighting,
            sourceLineTarget: sourceLine, sourceLineRequest: sourceLineRequest,
            focusRequest: focusRequest,
            onSourceLineChange: { line in
                sourceLine = line
                onSourceLineChange(session, line)
                visualLineRequest += 1
            },
            onActivate: { onActivate(session, .source) },
            onImagePaste: importImageFromPasteboard,
            positionState: session.position, positionRestoreRequest: sourceRestoreRequest)
            .frame(maxWidth: appearance.readerWidth + 76)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var visualPane: some View {
        MarkdownVisualEditor(source: $session.text, blocks: blocks, parsedSource: parsedSource,
            readerWidth: appearance.readerWidth, headingStyles: headings,
            bodyColorHex: appearance.bodyColorHex, readerBackgroundHex: appearance.backgroundHex,
            strongColorHex: appearance.strongColorHex, strongSize: appearance.strongSize,
            strongFamily: appearance.strongFamily, bodySize: appearance.bodySize,
            bodyFamily: appearance.bodyFamily, lineHeight: appearance.lineHeight,
            paragraphSpacing: appearance.paragraphSpacing,
            baseURL: session.url.deletingLastPathComponent(), scrollTarget: nil, scrollRequest: 0,
            sourceLineTarget: sourceLine, sourceLineRequest: visualLineRequest,
            restoreRequest: visualRestoreRequest, scrollState: session.position,
            onSourceLineChange: { line in
                sourceLine = line
                onSourceLineChange(session, line)
                sourceLineRequest += 1
            },
            onActivate: { onActivate(session, .visual) },
            onImagePaste: importVisualImage,
            onMarkdownLink: onOpenLink,
            onSlashCommand: { command, token in onNativeSlashCommand(session, command, token) },
            onDeleteManagedNote: { url in onDeleteManagedNote(session, url) })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func importImageFromPasteboard(_ pasteboard: NSPasteboard, _ textView: NSTextView) -> Bool {
        do {
            guard let markdown = try MarkdownImageAssets.importClipboard(pasteboard, beside: session.url) else { return false }
            let range = textView.selectedRange()
            textView.insertText(MarkdownImageAssets.blockInsertion(markdown, in: textView.string, replacing: range), replacementRange: range)
            return true
        } catch { onError("无法粘贴图片：\(error.localizedDescription)"); return true }
    }

    private func importVisualImage(_ pasteboard: NSPasteboard) -> String? {
        do { return try MarkdownImageAssets.importClipboard(pasteboard, beside: session.url) }
        catch { onError("无法粘贴图片：\(error.localizedDescription)"); return nil }
    }

    private func scheduleParse(_ text: String, delayMilliseconds: Int = 500) {
        guard mode == .visual else { return }
        parseTask?.cancel()
        parseTask = Task { @MainActor in
            if delayMilliseconds > 0 { try? await Task.sleep(for: .milliseconds(delayMilliseconds)) }
            guard !Task.isCancelled else { return }
            let result = await Task.detached(priority: .userInitiated) { MarkdownBlock.parse(text) }.value
            guard !Task.isCancelled, session.text == text else { return }
            blocks = result
            parsedSource = text
        }
    }
}

struct WorkspaceMarkdownNavigationTarget: Equatable {
    let sourceLine: Int
    let revision: Int
}
