import AppKit
import SwiftUI

enum MarkdownSourceTypography {
    static let lineHeightMultiple: CGFloat = 1.4
    static let paragraphSpacing: CGFloat = 8
    static let lineNumberFontSize: CGFloat = 12
    static let lineNumberOpticalOffset: CGFloat = -3

    static func paragraphStyle(lineHeightMultiple: CGFloat = MarkdownSourceTypography.lineHeightMultiple,
                               paragraphSpacing: CGFloat = MarkdownSourceTypography.paragraphSpacing) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = lineHeightMultiple
        style.paragraphSpacing = paragraphSpacing
        return style
    }
}

@MainActor
enum MarkdownSourceCanvas {
    static func updateBackground(_ color: NSColor, textView: NSTextView,
                                 scrollView: NSScrollView, gutter: MarkdownSourceLineGutter) {
        // Changing NSTextView.textColor here would replace every syntax color.
        textView.backgroundColor = color
        scrollView.backgroundColor = color
        gutter.backgroundColor = color
    }
}

@MainActor
enum WorkspaceMouseDownHandling {
    static func perform(nativeMouseDown: () -> Void, activateWorkspace: @escaping @MainActor () -> Void) {
        nativeMouseDown()
        DispatchQueue.main.async(execute: activateWorkspace)
    }
}

@MainActor
enum MarkdownSourcePositionHub {
    static weak var coordinator: MarkdownSourceEditor.Coordinator?
    static func capture() { coordinator?.capturePosition() }
    static func flushPendingChanges() { coordinator?.flushPendingChanges() }
}

struct MarkdownSourceEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    let fontSize: CGFloat
    var fontFamily = "系统默认"
    var lineHeight: CGFloat = MarkdownSourceTypography.lineHeightMultiple
    var paragraphSpacing: CGFloat = MarkdownSourceTypography.paragraphSpacing
    var backgroundHex = "#FFFFFF"
    let headingStyles: [HeadingStyle]
    let bodyColorHex: String
    let strongColorHex: String
    var syntaxHighlightingEnabled = true
    let sourceLineTarget: Int
    let sourceLineRequest: Int
    let focusRequest: Int
    let onSourceLineChange: (Int) -> Void
    let onActivate: () -> Void
    let onImagePaste: (NSPasteboard, NSTextView) -> Bool
    var positionState: MarkdownVisualScrollState? = nil
    var positionRestoreRequest = 0

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selection: $selection, headingStyles: headingStyles, bodyColorHex: bodyColorHex, strongColorHex: strongColorHex, onSourceLineChange: onSourceLineChange)
    }

    func makeNSView(context: Context) -> MarkdownSourceEditorContainer {
        context.coordinator.isRestoringPosition = true
        let container = MarkdownSourceEditorContainer()
        let textView = MarkdownSourceTextView(frame: .zero)
        textView.onActivate = { [weak coordinator = context.coordinator] in
            if let coordinator { MarkdownSourcePositionHub.coordinator = coordinator }
            positionState?.activeMode = .source
            onActivate()
        }
        textView.onTablePaste = { [weak coordinator = context.coordinator] table, textView in
            coordinator?.pasteTable(table, into: textView)
        }
        textView.onImagePaste = onImagePaste
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.insertionPointColor = NSColor(calibratedWhite: 0.34, alpha: 0.82)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 18, height: 12)
        textView.font = sourceFont
        textView.textColor = NSColor(Color(hex: bodyColorHex))
        textView.backgroundColor = NSColor(Color(hex: backgroundHex))
        textView.drawsBackground = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.usesFindBar = true

        textView.defaultParagraphStyle = MarkdownSourceTypography.paragraphStyle(lineHeightMultiple: lineHeight, paragraphSpacing: paragraphSpacing)
        textView.string = text
        context.coordinator.lastKnownText = text
        context.coordinator.syntaxHighlightingEnabled = syntaxHighlightingEnabled
        if syntaxHighlightingEnabled { context.coordinator.applySyntaxHighlighting(to: textView) }

        let scrollView = container.scrollView
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(Color(hex: backgroundHex))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.documentView = textView
        container.gutter.textView = textView
        container.gutter.scrollView = scrollView
        container.gutter.backgroundColor = NSColor(Color(hex: backgroundHex))
        container.gutter.updateSource(text)
        scrollView.contentView.postsBoundsChangedNotifications = true
        context.coordinator.scrollView = scrollView
        context.coordinator.gutter = container.gutter
        context.coordinator.observeScrollView(scrollView)
        context.coordinator.textView = textView
        context.coordinator.positionState = positionState
        MarkdownSourcePositionHub.coordinator = context.coordinator
        return container
    }

    func updateNSView(_ container: MarkdownSourceEditorContainer, context: Context) {
        let scrollView = container.scrollView
        guard let textView = context.coordinator.textView else { return }
        textView.insertionPointColor = NSColor(calibratedWhite: 0.34, alpha: 0.82)
        (textView as? MarkdownSourceTextView)?.onActivate = { [weak coordinator = context.coordinator] in
            if let coordinator { MarkdownSourcePositionHub.coordinator = coordinator }
            positionState?.activeMode = .source
            onActivate()
        }
        (textView as? MarkdownSourceTextView)?.onImagePaste = onImagePaste
        // SwiftUI can redraw the representable while an input method is composing.
        // Replacing NSTextView's string or selection here discards the marked text,
        // which makes Chinese pinyin appear to require choosing a numbered candidate.
        guard !textView.hasMarkedText() else { return }
        let desiredFont = sourceFont
        let typographyChanged = textView.font?.fontName != desiredFont.fontName || textView.font?.pointSize != desiredFont.pointSize
            || (textView.defaultParagraphStyle?.lineHeightMultiple ?? 0) != lineHeight
            || (textView.defaultParagraphStyle?.paragraphSpacing ?? 0) != paragraphSpacing
        if typographyChanged {
            textView.font = desiredFont
            textView.defaultParagraphStyle = MarkdownSourceTypography.paragraphStyle(lineHeightMultiple: lineHeight, paragraphSpacing: paragraphSpacing)
            container.gutter.needsDisplay = true
        }
        let background = NSColor(Color(hex: backgroundHex))
        MarkdownSourceCanvas.updateBackground(background, textView: textView,
                                              scrollView: scrollView, gutter: container.gutter)
        context.coordinator.synchronizeText(text, in: textView)
        context.coordinator.updateSyntaxHighlighting(enabled: syntaxHighlightingEnabled, textView: textView)
        context.coordinator.updateAppearance(headingStyles: headingStyles, bodyColorHex: bodyColorHex,
                                             strongColorHex: strongColorHex, typographyChanged: typographyChanged,
                                             textView: textView)
        context.coordinator.onSourceLineChange = onSourceLineChange
        context.coordinator.positionState = positionState
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        }
        let textLength = textView.textStorage?.length ?? 0
        let coordinator = context.coordinator
        let shouldRestorePosition = coordinator.lastPositionRestoreRequest != positionRestoreRequest && positionState?.viewport != nil
        if shouldRestorePosition { coordinator.isRestoringPosition = true }
        let safeLocation = min(selection.location, textLength)
        let safeLength = min(selection.length, textLength - safeLocation)
        let safeSelection = NSRange(location: safeLocation, length: safeLength)
        if !coordinator.hasPendingLocalChanges && textView.selectedRange() != safeSelection {
            textView.setSelectedRange(safeSelection)
        }
        if shouldRestorePosition {
            coordinator.lastPositionRestoreRequest = positionRestoreRequest
            coordinator.lastSourceLineRequest = sourceLineRequest
            coordinator.restorePosition()
        } else if coordinator.lastSourceLineRequest != sourceLineRequest {
            coordinator.lastSourceLineRequest = sourceLineRequest
            coordinator.scrollToSourceLine(sourceLineTarget, in: textView, scrollView: scrollView)
        }
        if !shouldRestorePosition, coordinator.lastPositionRestoreRequest == -1 {
            coordinator.isRestoringPosition = false
        }
    }

    private var sourceFont: NSFont {
        if fontFamily != "系统默认", let font = NSFont(name: fontFamily, size: fontSize) { return font }
        return .monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    static func dismantleNSView(_ container: MarkdownSourceEditorContainer, coordinator: Coordinator) {
        coordinator.flushPendingChanges()
        if MarkdownSourcePositionHub.coordinator === coordinator { MarkdownSourcePositionHub.coordinator = nil }
        coordinator.stopObserving()
        coordinator.textView?.undoManager?.removeAllActions()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        @Binding private var selection: NSRange
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        weak var gutter: MarkdownSourceLineGutter?
        var onSourceLineChange: ((Int) -> Void)?
        var lastSourceLineRequest = -1
        var lastFocusRequest = 0
        var lastPositionRestoreRequest = -1
        var positionState: MarkdownVisualScrollState?
        var isRestoringPosition = false
        private var positionGeneration = 0
        private var restoredViewport: MarkdownViewportAnchor?
        private var restoredScrollY: CGFloat?
        private var restoredSource = ""
        private var lastReportedLine = 0
        private var scrollObserver: NSObjectProtocol?
        private var headingStyles: [HeadingStyle]
        private var bodyColorHex: String
        private var strongColorHex: String
        private var regexCache: [String: NSRegularExpression] = [:]
        var lastKnownText = ""
        private static let fenceStateKey = NSAttributedString.Key("MarkdownStudioFenceStateAfterLine")
        private var pendingHighlight: DispatchWorkItem?
        private var pendingHighlightRange: NSRange?
        private var pendingPublication: DispatchWorkItem?
        private var pendingLineReport: DispatchWorkItem?
        private(set) var hasPendingLocalChanges = false
        var syntaxHighlightingEnabled = true

        init(text: Binding<String>, selection: Binding<NSRange>, headingStyles: [HeadingStyle], bodyColorHex: String, strongColorHex: String,
             onSourceLineChange: @escaping (Int) -> Void) {
            _text = text
            _selection = selection
            self.headingStyles = headingStyles
            self.bodyColorHex = bodyColorHex
            self.strongColorHex = strongColorHex
            self.onSourceLineChange = onSourceLineChange
        }

        func observeScrollView(_ scrollView: NSScrollView) {
            if let scrollObserver { NotificationCenter.default.removeObserver(scrollObserver) }
            scrollObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.contentView, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.gutter?.needsDisplay = true
                    self.pendingLineReport?.cancel()
                    let work = DispatchWorkItem { [weak self] in self?.reportVisibleLine() }
                    self.pendingLineReport = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(120), execute: work)
                }
            }
        }

        func stopObserving() {
            positionGeneration += 1
            if let scrollObserver { NotificationCenter.default.removeObserver(scrollObserver) }
            scrollObserver = nil
            pendingHighlight?.cancel()
            pendingPublication?.cancel()
            pendingLineReport?.cancel()
        }

        func scrollToSourceLine(_ line: Int, in textView: NSTextView, scrollView: NSScrollView) {
            let source = textView.string as NSString
            guard source.length > 0, let layout = textView.layoutManager,
                  let container = textView.textContainer else { return }
            var location = 0
            var currentLine = 1
            while currentLine < line && location < source.length {
                let range = source.lineRange(for: NSRange(location: location, length: 0))
                if NSMaxRange(range) <= location { break }
                location = NSMaxRange(range)
                currentLine += 1
            }
            let lineRange = source.lineRange(for: NSRange(location: min(location, source.length), length: 0))
            let glyphRange = layout.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            let lineRect = layout.boundingRect(forGlyphRange: glyphRange, in: container)
            let clipView = scrollView.contentView
            let documentView = scrollView.documentView ?? textView
            let desiredY = textView.textContainerOrigin.y + lineRect.minY - 12
            let maxY = max(0, documentView.bounds.height - clipView.bounds.height + scrollView.contentInsets.bottom)
            clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: min(max(0, desiredY), maxY)))
            scrollView.reflectScrolledClipView(clipView)
            lastReportedLine = line
        }

        private func reportVisibleLine() {
            guard !isRestoringPosition, !hasPendingLocalChanges, positionState?.activeMode != .visual else { return }
            capturePosition()
            guard let textView, let scrollView, let layout = textView.layoutManager,
                  let container = textView.textContainer else { return }
            let visibleRect = textView.convert(scrollView.contentView.bounds, from: scrollView.contentView)
            let containerRect = visibleRect.offsetBy(dx: -textView.textContainerOrigin.x, dy: -textView.textContainerOrigin.y)
            let glyphIndex = layout.glyphIndex(for: NSPoint(x: 1, y: max(0, containerRect.minY + 1)), in: container)
            let characterIndex = layout.characterIndexForGlyph(at: glyphIndex)
            let source = textView.string as NSString
            let offset = min(characterIndex, source.length)
            let prefix = source.substring(to: offset) as NSString
            let line = prefix.components(separatedBy: "\n").count
            guard line != lastReportedLine else { return }
            lastReportedLine = line
            onSourceLineChange?(line)
        }

        func capturePosition() {
            guard !isRestoringPosition, let positionState, positionState.activeMode == .source,
                  let textView, let scrollView, let layout = textView.layoutManager,
                  let container = textView.textContainer else { return }
            positionState.selection = textView.selectedRange()
            if let restoredViewport, let restoredScrollY,
               abs(scrollView.contentView.bounds.minY - restoredScrollY) < 0.5,
               lastKnownText == restoredSource {
                positionState.viewport = restoredViewport
                return
            }
            let visibleRect = textView.convert(scrollView.contentView.bounds, from: scrollView.contentView)
            let containerRect = visibleRect.offsetBy(dx: -textView.textContainerOrigin.x, dy: -textView.textContainerOrigin.y)
            layout.ensureLayout(forBoundingRect: containerRect, in: container)
            guard layout.numberOfGlyphs > 0 else {
                positionState.viewport = MarkdownViewportAnchor(sourceOffset: 0, screenY: 0)
                return
            }
            let point = NSPoint(x: 1, y: max(0, visibleRect.minY - textView.textContainerOrigin.y + 1))
            let glyph = min(layout.glyphIndex(for: point, in: container), layout.numberOfGlyphs - 1)
            let character = layout.characterIndexForGlyph(at: glyph)
            let rect = layout.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
            positionState.viewport = MarkdownViewportAnchor(sourceOffset: character,
                screenY: Double(rect.minY + textView.textContainerOrigin.y - visibleRect.minY))
        }

        func restorePosition() {
            guard let viewport = positionState?.viewport else { return }
            isRestoringPosition = true
            positionGeneration += 1
            let generation = positionGeneration
            DispatchQueue.main.async { [weak self] in
                guard let self, generation == self.positionGeneration,
                      let textView = self.textView, let scrollView = self.scrollView,
                      let layout = textView.layoutManager, let container = textView.textContainer else { return }
                scrollView.layoutSubtreeIfNeeded()
                layout.ensureLayout(for: container)
                let length = (textView.string as NSString).length
                let offset = min(max(0, viewport.sourceOffset), max(0, length - 1))
                let glyphs = layout.glyphRange(forCharacterRange: NSRange(location: offset, length: length > 0 ? 1 : 0), actualCharacterRange: nil)
                let rect = layout.boundingRect(forGlyphRange: glyphs, in: container)
                let clip = scrollView.contentView
                let maxY = max(0, textView.bounds.height - clip.bounds.height + scrollView.contentInsets.bottom)
                let target = rect.minY + textView.textContainerOrigin.y - CGFloat(viewport.screenY)
                clip.scroll(to: NSPoint(x: clip.bounds.minX, y: min(max(0, target), maxY)))
                scrollView.reflectScrolledClipView(clip)
                self.restoredViewport = viewport
                self.restoredScrollY = clip.bounds.minY
                self.restoredSource = self.lastKnownText
                self.isRestoringPosition = false
            }
        }

        func updateAppearance(headingStyles: [HeadingStyle], bodyColorHex: String, strongColorHex: String,
                              typographyChanged: Bool = false, textView: NSTextView) {
            guard self.headingStyles != headingStyles || self.bodyColorHex != bodyColorHex
                || self.strongColorHex != strongColorHex || typographyChanged else { return }
            self.headingStyles = headingStyles
            self.bodyColorHex = bodyColorHex
            self.strongColorHex = strongColorHex
            if syntaxHighlightingEnabled { applySyntaxHighlighting(to: textView) }
            else if let storage = textView.textStorage, storage.length > 0 {
                storage.addAttributes([.font: textView.font ?? NSFont.monospacedSystemFont(ofSize: 15, weight: .regular),
                                       .foregroundColor: NSColor(Color(hex: bodyColorHex)),
                                       .paragraphStyle: textView.defaultParagraphStyle ?? NSParagraphStyle.default],
                                      range: NSRange(location: 0, length: storage.length))
            }
        }

        func updateSyntaxHighlighting(enabled: Bool, textView: NSTextView) {
            guard syntaxHighlightingEnabled != enabled else { return }
            syntaxHighlightingEnabled = enabled
            pendingHighlight?.cancel()
            pendingHighlight = nil
            pendingHighlightRange = nil
            if enabled {
                applySyntaxHighlighting(to: textView)
            } else if let storage = textView.textStorage, storage.length > 0 {
                textView.undoManager?.disableUndoRegistration()
                storage.setAttributes([.font: textView.font ?? NSFont.monospacedSystemFont(ofSize: 15, weight: .regular),
                                       .foregroundColor: NSColor(Color(hex: bodyColorHex)),
                                       .paragraphStyle: textView.defaultParagraphStyle ?? NSParagraphStyle.default],
                                      range: NSRange(location: 0, length: storage.length))
                textView.undoManager?.enableUndoRegistration()
            }
        }

        func synchronizeText(_ value: String, in textView: NSTextView) {
            // Most SwiftUI updates follow local typing or a caret move. The
            // editor already knows that text, so avoid fetching and comparing
            // the entire NSTextView contents on every such update.
            guard lastKnownText != value else { return }
            // A SwiftUI redraw can arrive while local typing is still being
            // debounced. The binding then contains our last published version.
            // It must not replace the newer text or move the insertion point.
            if hasPendingLocalChanges {
                let lastPublished = lastKnownText
                flushPendingChanges()
                if value == lastPublished { return }
            }
            if textView.string != value {
                textView.undoManager?.removeAllActions()
                textView.string = value
                gutter?.updateSource(value)
                if syntaxHighlightingEnabled { applySyntaxHighlighting(to: textView) }
            }
            lastKnownText = value
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Keep the IME's provisional composition inside NSTextView. Commit it to
            // the SwiftUI binding, and apply Markdown coloring, after composition ends.
            guard !textView.hasMarkedText() else { return }
            // NSTextView can report the committed text before it reports the new
            // caret position. Publish both together so updateNSView cannot restore
            // the stale pre-composition selection over the IME's committed word.
            let selectionRange = textView.selectedRange()
            if syntaxHighlightingEnabled { scheduleSyntaxHighlighting(in: textView, around: selectionRange) }
            selection = selectionRange
            hasPendingLocalChanges = true
            pendingPublication?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.flushPendingChanges() }
            pendingPublication = work
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(450), execute: work)
        }

        func flushPendingChanges() {
            guard hasPendingLocalChanges, let textView, !textView.hasMarkedText() else { return }
            pendingPublication?.cancel()
            pendingPublication = nil
            hasPendingLocalChanges = false
            let currentText = textView.string
            lastKnownText = currentText
            gutter?.updateSource(currentText)
            selection = textView.selectedRange()
            text = currentText
            reportVisibleLine()
        }

        private func scheduleSyntaxHighlighting(in textView: NSTextView, around editedRange: NSRange) {
            pendingHighlightRange = pendingHighlightRange.map { NSUnionRange($0, editedRange) } ?? editedRange
            pendingHighlight?.cancel()
            let work = DispatchWorkItem { [weak self, weak textView] in
                guard let self, let textView, !textView.hasMarkedText() else { return }
                let range = self.pendingHighlightRange
                self.pendingHighlightRange = nil
                self.applySyntaxHighlighting(to: textView, around: range)
            }
            pendingHighlight = work
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(700), execute: work)
        }

        func pasteTable(_ table: String, into textView: NSTextView) {
            let range = textView.selectedRange()
            let source = textView.string as NSString
            let before = source.substring(to: min(range.location, source.length))
            let afterStart = min(range.location + range.length, source.length)
            let after = source.substring(from: afterStart)
            let prefix = before.isEmpty || before.hasSuffix("\n\n") ? "" : before.hasSuffix("\n") ? "\n" : "\n\n"
            let suffix = after.isEmpty || after.hasPrefix("\n\n") ? "" : after.hasPrefix("\n") ? "\n" : "\n\n"
            textView.insertText(prefix + table + suffix, replacementRange: range)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isRestoringPosition, !textView.hasMarkedText() else { return }
            selection = textView.selectedRange()
        }

        func applySyntaxHighlighting(to textView: NSTextView, around editedRange: NSRange? = nil) {
            pendingHighlight?.cancel()
            pendingHighlight = nil
            pendingHighlightRange = nil
            guard let storage = textView.textStorage else { return }
            let source = textView.string as NSString
            guard source.length > 0 else { return }

            var targetRange: NSRange
            if let editedRange {
                // Refresh the current paragraph and its neighbors. This covers
                // edits that add/remove a newline while keeping normal typing local.
                let location = min(max(editedRange.location, 0), source.length)
                let firstLine = source.lineRange(for: NSRange(location: location, length: 0))
                let start = firstLine.location > 0
                    ? source.lineRange(for: NSRange(location: firstLine.location - 1, length: 0)).location
                    : firstLine.location
                let endProbe = min(max(location + editedRange.length, location), source.length)
                let lastLine = source.lineRange(for: NSRange(location: endProbe, length: 0))
                var end = NSMaxRange(lastLine)
                if end < source.length {
                    end = NSMaxRange(source.lineRange(for: NSRange(location: end, length: 0)))
                }
                targetRange = NSRange(location: start, length: max(0, end - start))
                // Changing a fence can alter the style of every following line.
                // This is rare; normal typing keeps the local highlight range.
                let currentLineText = source.substring(with: firstLine)
                if currentLineText.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    targetRange.length = source.length - targetRange.location
                }
            } else {
                targetRange = NSRange(location: 0, length: source.length)
            }
            guard targetRange.length > 0 else { return }
            let previousFenceState: Bool
            if targetRange.location > 0,
               let cached = storage.attribute(Self.fenceStateKey, at: targetRange.location - 1, effectiveRange: nil) as? NSNumber {
                previousFenceState = cached.boolValue
            } else {
                previousFenceState = fenceStateBefore(targetRange.location, in: source)
            }
            let localString = source.substring(with: targetRange)
            let localSource = localString as NSString

            func global(_ range: NSRange) -> NSRange {
                guard range.location != NSNotFound else { return range }
                return NSRange(location: targetRange.location + range.location, length: range.length)
            }

            let baseFont = textView.font ?? NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
            let baseColor = NSColor(Color(hex: bodyColorHex))
            let markerColor = NSColor.secondaryLabelColor
            let strongColor = NSColor(Color(hex: strongColorHex))
            let paragraph = textView.defaultParagraphStyle ?? MarkdownSourceTypography.paragraphStyle()

            textView.undoManager?.disableUndoRegistration()
            storage.beginEditing()
            storage.setAttributes([
                .font: baseFont,
                .foregroundColor: baseColor,
                .paragraphStyle: paragraph
            ], range: targetRange)

            // Headings get a blue title cue while the Markdown markers stay muted.
            forEachMatch(#"(?m)^(#{1,6})[ \t]+([^\r\n]*)$"#, in: localSource) { _, match in
                let titleRange = global(match.range(at: 2))
                let level = localSource.substring(with: match.range(at: 1)).count
                let titleColor = headingStyles.first(where: { $0.id == level }).map { NSColor(Color(hex: $0.colorHex)) } ?? NSColor.systemBlue
                storage.addAttribute(.foregroundColor, value: titleColor, range: titleRange)
                self.addFontTrait(.boldFontMask, to: titleRange, in: storage, fallback: baseFont)
                storage.addAttribute(.foregroundColor, value: markerColor, range: global(match.range(at: 1)))
            }

            // Inline code is local to the edited paragraphs. Fenced code is handled
            // below with fence state carried in from earlier lines.
            forEachMatch(#"(?<!`)`[^`\n]+`(?!`)"#, in: localSource) { range, _ in
                let range = global(range)
                storage.addAttribute(.foregroundColor, value: NSColor.systemBrown, range: range)
                storage.addAttribute(.backgroundColor, value: NSColor.systemBrown.withAlphaComponent(0.10), range: range)
            }

            // Emphasis is shown on the text itself; delimiters remain visible but subdued.
            forEachMatch(#"(?<!\*)\*\*(?!\*)(.+?)(?<!\*)\*\*(?!\*)|(?<!_)__(?!_)(.+?)(?<!_)__(?!_)"#, in: localSource) { range, match in
                let content = localSource.substring(with: range)
                let nextIndex = NSMaxRange(match.range)
                if (content.hasSuffix("）") || content.hasSuffix(")")), nextIndex < localSource.length,
                   localSource.substring(with: NSRange(location: nextIndex, length: 1))
                    .rangeOfCharacter(from: .letters) != nil { return }
                let range = global(range)
                self.addFontTrait(.boldFontMask, to: range, in: storage, fallback: baseFont)
                storage.addAttribute(.foregroundColor, value: strongColor, range: range)
                self.muteDelimiters([global(match.range(at: 0))], in: storage, source: source, color: markerColor, delimiterLength: 2)
            }
            forEachMatch(#"(?i)<strong>(.*?)</strong>|<b>(.*?)</b>"#, in: localSource) { range, _ in
                let range = global(range)
                self.addFontTrait(.boldFontMask, to: range, in: storage, fallback: baseFont)
                storage.addAttribute(.foregroundColor, value: strongColor, range: range)
            }
            forEachMatch(#"(?<!\*)\*(?!\*)(?!\s)(.+?)(?<!\s)\*(?!\*)|(?<!_)_(?!_)(?!\s)(.+?)(?<!\s)_(?!_)"#, in: localSource) { range, match in
                let range = global(range)
                // Some macOS monospaced system font faces do not provide an
                // italic face to NSFontManager. Obliqueness keeps Markdown italics
                // visible even when that font-family conversion silently fails.
                storage.addAttribute(.obliqueness, value: 0.22, range: range)
                self.muteDelimiters([global(match.range(at: 0))], in: storage, source: source, color: markerColor, delimiterLength: 1)
            }
            forEachMatch(#"(?i)<u>(.+?)</u>"#, in: localSource) { _, match in
                let contentRange = global(match.range(at: 1))
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
                self.muteDelimiters([global(match.range(at: 0))], in: storage, source: source, color: markerColor, onlyTags: true)
            }
            forEachMatch(#"~~(.+?)~~"#, in: localSource) { range, match in
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: global(match.range(at: 1)))
                self.muteDelimiters([global(range)], in: storage, source: source, color: markerColor, delimiterLength: 2)
            }

            // Links and list/quote markers use color cues similar to a source editor.
            forEachMatch(#"\[([^\]\n]+)\]\(([^)\n]+)\)"#, in: localSource) { range, match in
                let range = global(range)
                storage.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: range)
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: global(match.range(at: 1)))
            }
            forEachMatch(#"(?m)^\s*(?:[-+*]|\d+[.)])(?=\s)"#, in: localSource) { range, _ in
                let range = global(range)
                storage.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: range)
                self.addFontTrait(.boldFontMask, to: range, in: storage, fallback: baseFont)
            }
            forEachMatch(#"(?m)^\s*>+"#, in: localSource) { range, _ in
                let range = global(range)
                storage.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: range)
            }

            self.applyFencedCodeStyle(to: storage, localSource: localSource,
                                      range: targetRange, startsInsideFence: previousFenceState,
                                      color: NSColor.systemBrown)

            storage.endEditing()
            textView.undoManager?.enableUndoRegistration()
        }

        private func forEachMatch(_ pattern: String, in source: NSString, body: (NSRange, NSTextCheckingResult) -> Void) {
            let regex: NSRegularExpression
            if let cached = regexCache[pattern] {
                regex = cached
            } else {
                guard let compiled = try? NSRegularExpression(pattern: pattern) else { return }
                regexCache[pattern] = compiled
                regex = compiled
            }
            regex.enumerateMatches(in: source as String, range: NSRange(location: 0, length: source.length)) { match, _, _ in
                guard let match else { return }
                let contentRange = (1..<match.numberOfRanges)
                    .map { match.range(at: $0) }
                    .first { $0.location != NSNotFound } ?? match.range
                body(contentRange, match)
            }
        }

        private func fenceStateBefore(_ location: Int, in source: NSString) -> Bool {
            guard location > 0 else { return false }
            let fenceRegex = try? NSRegularExpression(pattern: #"^\s*```"#)
            var insideFence = false
            var lineStart = 0
            while lineStart < location {
                let lineRange = source.lineRange(for: NSRange(location: lineStart, length: 0))
                let line = source.substring(with: lineRange) as NSString
                if fenceRegex?.firstMatch(in: line as String, range: NSRange(location: 0, length: line.length)) != nil {
                    insideFence.toggle()
                }
                lineStart = NSMaxRange(lineRange)
            }
            return insideFence
        }

        private func applyFencedCodeStyle(to storage: NSTextStorage, localSource: NSString,
                                          range: NSRange, startsInsideFence: Bool, color: NSColor) {
            let fenceRegex = try? NSRegularExpression(pattern: #"^\s*```"#)
            var insideFence = startsInsideFence
            var lineStart = 0
            while lineStart < localSource.length {
                let localLineRange = localSource.lineRange(for: NSRange(location: lineStart, length: 0))
                let line = localSource.substring(with: localLineRange) as NSString
                let isFence = fenceRegex?.firstMatch(in: line as String, range: NSRange(location: 0, length: line.length)) != nil
                if insideFence || isFence {
                    let globalRange = NSRange(location: range.location + localLineRange.location, length: localLineRange.length)
                    storage.addAttribute(.foregroundColor, value: color, range: globalRange)
                    storage.addAttribute(.backgroundColor, value: color.withAlphaComponent(0.10), range: globalRange)
                }
                if isFence { insideFence.toggle() }
                let globalRange = NSRange(location: range.location + localLineRange.location, length: localLineRange.length)
                storage.addAttribute(Self.fenceStateKey, value: NSNumber(value: insideFence), range: globalRange)
                lineStart = NSMaxRange(localLineRange)
            }
        }

        private func addFontTrait(_ trait: NSFontTraitMask, to range: NSRange, in storage: NSTextStorage, fallback: NSFont) {
            guard range.location != NSNotFound, range.length > 0 else { return }
            let font = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont ?? fallback
            storage.addAttribute(.font, value: NSFontManager.shared.convert(font, toHaveTrait: trait), range: range)
        }

        private func muteDelimiters(_ ranges: [NSRange], in storage: NSTextStorage, source: NSString,
                                    color: NSColor, onlyTags: Bool = false, delimiterLength: Int = 2) {
            for range in ranges where range.location != NSNotFound && range.length > 0 {
                if onlyTags {
                    let token = source.substring(with: range) as NSString
                    let opening = token.range(of: "<u>", options: .caseInsensitive)
                    let closing = token.range(of: "</u>", options: .caseInsensitive)
                    if opening.location != NSNotFound {
                        storage.addAttribute(.foregroundColor, value: color,
                                             range: NSRange(location: range.location + opening.location, length: opening.length))
                    }
                    if closing.location != NSNotFound {
                        storage.addAttribute(.foregroundColor, value: color,
                                             range: NSRange(location: range.location + closing.location, length: closing.length))
                    }
                } else {
                    let length = min(delimiterLength, range.length)
                    storage.addAttribute(.foregroundColor, value: color,
                                         range: NSRange(location: range.location, length: length))
                    if range.length >= 2 {
                        storage.addAttribute(.foregroundColor, value: color,
                                             range: NSRange(location: range.location + range.length - length, length: length))
                    }
                }
            }
        }
    }
}

/// Keeps line numbers outside NSTextStorage, so typing never inserts or styles
/// number glyphs in the document. The index is rebuilt with the already
/// deferred source publication, then only visible lines are drawn on scroll.
struct MarkdownSourceLineIndex {
    private(set) var starts: [Int] = [0]

    init(_ source: String) {
        let text = source as NSString
        var offset = 0
        while offset < text.length {
            let range = text.lineRange(for: NSRange(location: offset, length: 0))
            let next = NSMaxRange(range)
            guard next > offset else { break }
            if next < text.length || (next == text.length &&
                (text.character(at: text.length - 1) == 10 || text.character(at: text.length - 1) == 13)) {
                starts.append(next)
            }
            offset = next
        }
    }

    func lineNumber(atUTF16Offset offset: Int) -> Int {
        var low = 0
        var high = starts.count
        while low < high {
            let middle = (low + high) / 2
            if starts[middle] <= offset { low = middle + 1 } else { high = middle }
        }
        return max(1, low)
    }
}

final class MarkdownSourceEditorContainer: NSView {
    let scrollView = MarkdownSourceScrollView()
    let gutter = MarkdownSourceLineGutter()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        gutter.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gutter)
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            gutter.leadingAnchor.constraint(equalTo: leadingAnchor),
            gutter.topAnchor.constraint(equalTo: topAnchor),
            gutter.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: gutter.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        gutter.widthConstraint = gutter.widthAnchor.constraint(equalToConstant: 42)
        gutter.widthConstraint?.isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class MarkdownSourceLineGutter: NSView {
    weak var textView: NSTextView?
    weak var scrollView: NSScrollView?
    var widthConstraint: NSLayoutConstraint?
    var backgroundColor: NSColor = .textBackgroundColor {
        didSet { if oldValue != backgroundColor { needsDisplay = true } }
    }
    private var index = MarkdownSourceLineIndex("")

    override var isFlipped: Bool { true }

    func updateSource(_ source: String) {
        index = MarkdownSourceLineIndex(source)
        let font = NSFont.monospacedDigitSystemFont(ofSize: MarkdownSourceTypography.lineNumberFontSize, weight: .regular)
        let widestLabel = String(index.starts.count) as NSString
        widthConstraint?.constant = max(42, ceil(widestLabel.size(withAttributes: [.font: font]).width + 18))
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        backgroundColor.setFill()
        dirtyRect.fill()
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.maxX - 1, y: dirtyRect.minY, width: 1, height: dirtyRect.height).fill()
        guard let textView, let scrollView,
              let layout = textView.layoutManager,
              let container = textView.textContainer else { return }
        let visible = textView.convert(scrollView.contentView.bounds, from: scrollView.contentView)
        let containerVisible = visible.offsetBy(dx: -textView.textContainerOrigin.x,
                                               dy: -textView.textContainerOrigin.y)
        let glyphs = layout.glyphRange(forBoundingRect: containerVisible, in: container)
        guard glyphs.length > 0 else { return }
        let first = index.lineNumber(atUTF16Offset: layout.characterIndexForGlyph(at: glyphs.location))
        let last = index.lineNumber(atUTF16Offset: layout.characterIndexForGlyph(at: NSMaxRange(glyphs) - 1))
        let font = NSFont.monospacedDigitSystemFont(ofSize: MarkdownSourceTypography.lineNumberFontSize, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
        for line in first...last where line <= index.starts.count {
            let offset = index.starts[line - 1]
            guard offset < (textView.textStorage?.length ?? 0) else { continue }
            let glyph = layout.glyphIndexForCharacter(at: offset)
            guard glyph < layout.numberOfGlyphs else { continue }
            let fragment = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let baseline = fragment.minY + layout.location(forGlyphAt: glyph).y
            let origin = textView.convert(NSPoint(x: 0, y: baseline + textView.textContainerOrigin.y), to: self)
            let label = String(line) as NSString
            let labelWidth = label.size(withAttributes: attributes).width
            label.draw(at: NSPoint(x: max(2, bounds.width - labelWidth - 9),
                                   y: origin.y - font.ascender + MarkdownSourceTypography.lineNumberOpticalOffset),
                       withAttributes: attributes)
        }
    }
}

final class MarkdownSourceScrollView: NSScrollView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        automaticallyAdjustsContentInsets = false
        contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        automaticallyAdjustsContentInsets = false
        contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        guard let textView = documentView as? NSTextView,
              hit !== textView,
              hit?.isDescendant(of: contentView) != true else { return hit }

        // Keep visible text hit-testable across the scroll view's content area.
        let localPoint = convert(point, from: superview)
        guard contentView.frame.contains(localPoint),
              verticalScroller?.frame.contains(localPoint) != true,
              textView.bounds.contains(textView.convert(localPoint, from: self)) else { return hit }
        return textView
    }

}

final class MarkdownSourceTextView: NSTextView {
    // Keep undo targets in this editor's lifetime, not the shared window's stack.
    private let sourceUndoManager = UndoManager()
    override var undoManager: UndoManager? { sourceUndoManager }
    var onTablePaste: ((String, NSTextView) -> Void)?
    var onImagePaste: ((NSPasteboard, NSTextView) -> Bool)?
    var imagePasteboard: NSPasteboard = .general
    var onActivate: (() -> Void)?

    // AppKit's default scrolling treats the bottom inset as a reason
    // to move an already visible caret or selection toward the top. Keep the
    // viewport still while the selection is visible, including mouse drags.
    override func scrollRangeToVisible(_ range: NSRange) {
        guard let scrollView = enclosingScrollView,
              let layout = layoutManager, textContainer != nil,
              let source = textStorage?.mutableString,
              layout.numberOfGlyphs > 0 else {
            super.scrollRangeToVisible(range)
            return
        }
        func lineRect(at location: Int) -> NSRect {
            let safeLocation = min(max(0, location), source.length)
            let glyphRect: NSRect
            if safeLocation == source.length, source.length > 0,
               [10, 13].contains(source.character(at: source.length - 1)),
               !layout.extraLineFragmentRect.isEmpty {
                glyphRect = layout.extraLineFragmentRect
            } else {
                let glyphLocation = min(safeLocation, source.length - 1)
                let glyphs = layout.glyphRange(forCharacterRange: NSRange(location: glyphLocation, length: 1), actualCharacterRange: nil)
                glyphRect = layout.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil)
            }
            return glyphRect.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
        }
        let startRect = lineRect(at: range.location)
        let endRect = range.length > 0 ? lineRect(at: NSMaxRange(range)) : startRect
        let clip = scrollView.contentView
        let visible = convert(clip.bounds, from: clip)
        let padding: CGFloat = 8
        let top = visible.minY + padding
        let bottom = visible.maxY - padding
        let rect: NSRect
        if endRect.maxY < top {
            rect = endRect // Entire selection is above: reveal its nearest end.
        } else if startRect.minY > bottom {
            rect = startRect // Entire selection is below: reveal its nearest start.
        } else if startRect.minY < top && endRect.maxY > bottom {
            return // A long selection spans the viewport; don't jump to either end.
        } else if startRect.minY < top {
            rect = startRect
        } else if endRect.maxY > bottom {
            rect = endRect
        } else {
            return
        }
        let targetY: CGFloat
        if rect.minY < top {
            targetY = clip.bounds.minY + rect.minY - visible.minY - padding
        } else {
            targetY = clip.bounds.minY + rect.maxY - visible.maxY + padding
        }
        let constrained = clip.constrainBoundsRect(NSRect(x: clip.bounds.minX, y: targetY,
                                                         width: clip.bounds.width, height: clip.bounds.height))
        clip.scroll(to: constrained.origin)
        scrollView.reflectScrolledClipView(clip)
    }
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(paste(_:)), onImagePaste != nil,
           MarkdownImageAssets.canImportClipboard(imagePasteboard) {
            return true
        }
        return super.validateMenuItem(menuItem)
    }

    override func mouseDown(with event: NSEvent) {
        // Let NSTextView resolve the mouse position and update its selection
        // before activation changes the surrounding SwiftUI workspace state.
        // The activation can switch the sidebar tab and trigger a layout pass;
        // doing that before `super` makes AppKit hit-test against a moving view.
        WorkspaceMouseDownHandling.perform(
            nativeMouseDown: { super.mouseDown(with: event) },
            activateWorkspace: { [weak self] in self?.onActivate?() }
        )
    }

    override func paste(_ sender: Any?) {
        let pasteboard = imagePasteboard
        let plain = pasteboard.string(forType: .string) ?? ""
        let html = pasteboard.string(forType: .html)
        if let cells = MarkdownTableFormatter.parseClipboard(plain: plain, html: html) {
            onTablePaste?(MarkdownTableFormatter.markdown(cells), self)
            return
        }
        if onImagePaste?(pasteboard, self) == true { return }
        super.paste(sender)
    }
}
