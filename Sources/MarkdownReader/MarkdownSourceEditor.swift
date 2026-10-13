import AppKit
import SwiftUI

struct MarkdownSourceEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    let fontSize: CGFloat
    let headingStyles: [HeadingStyle]
    let bodyColorHex: String
    let strongColorHex: String
    let sourceLineTarget: Int
    let sourceLineRequest: Int
    let focusRequest: Int
    let onSourceLineChange: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selection: $selection, headingStyles: headingStyles, bodyColorHex: bodyColorHex, strongColorHex: strongColorHex, onSourceLineChange: onSourceLineChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = MarkdownSourceTextView(frame: .zero)
        textView.onTablePaste = { [weak coordinator = context.coordinator] table, textView in
            coordinator?.pasteTable(table, into: textView)
        }
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 10, height: 12)
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.usesFindBar = true

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 1.25
        paragraph.paragraphSpacing = 8
        textView.defaultParagraphStyle = paragraph
        textView.string = text
        context.coordinator.applySyntaxHighlighting(to: textView)

        let scrollView = NSScrollView()
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.documentView = textView
        scrollView.contentView.postsBoundsChangedNotifications = true
        context.coordinator.scrollView = scrollView
        context.coordinator.observeScrollView(scrollView)
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        // SwiftUI can redraw the representable while an input method is composing.
        // Replacing NSTextView's string or selection here discards the marked text,
        // which makes Chinese pinyin appear to require choosing a numbered candidate.
        guard !textView.hasMarkedText() else { return }
        if textView.font?.pointSize != fontSize {
            textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
            context.coordinator.applySyntaxHighlighting(to: textView)
        }
        if textView.string != text {
            textView.string = text
            context.coordinator.applySyntaxHighlighting(to: textView)
        }
        context.coordinator.updateAppearance(headingStyles: headingStyles, bodyColorHex: bodyColorHex, strongColorHex: strongColorHex, textView: textView)
        context.coordinator.onSourceLineChange = onSourceLineChange
        if context.coordinator.lastSourceLineRequest != sourceLineRequest {
            context.coordinator.lastSourceLineRequest = sourceLineRequest
            context.coordinator.scrollToSourceLine(sourceLineTarget, in: textView, scrollView: scrollView)
        }
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        }
        let safeLocation = min(selection.location, (textView.string as NSString).length)
        let safeLength = min(selection.length, (textView.string as NSString).length - safeLocation)
        let safeSelection = NSRange(location: safeLocation, length: safeLength)
        if textView.selectedRange() != safeSelection {
            textView.setSelectedRange(safeSelection)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        @Binding private var selection: NSRange
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        var onSourceLineChange: ((Int) -> Void)?
        var lastSourceLineRequest = -1
        var lastFocusRequest = 0
        private var lastReportedLine = 0
        private var scrollObserver: NSObjectProtocol?
        private var headingStyles: [HeadingStyle]
        private var bodyColorHex: String
        private var strongColorHex: String
        private var regexCache: [String: NSRegularExpression] = [:]

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
                Task { @MainActor in self?.reportVisibleLine() }
            }
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
            let maxY = max(0, documentView.bounds.height - clipView.bounds.height)
            clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: min(max(0, desiredY), maxY)))
            scrollView.reflectScrolledClipView(clipView)
            lastReportedLine = line
        }

        private func reportVisibleLine() {
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

        func updateAppearance(headingStyles: [HeadingStyle], bodyColorHex: String, strongColorHex: String, textView: NSTextView) {
            guard self.headingStyles != headingStyles || self.bodyColorHex != bodyColorHex || self.strongColorHex != strongColorHex else { return }
            self.headingStyles = headingStyles
            self.bodyColorHex = bodyColorHex
            self.strongColorHex = strongColorHex
            applySyntaxHighlighting(to: textView)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Keep the IME's provisional composition inside NSTextView. Commit it to
            // the SwiftUI binding, and apply Markdown coloring, after composition ends.
            guard !textView.hasMarkedText() else { return }
            // NSTextView can report the committed text before it reports the new
            // caret position. Publish both together so updateNSView cannot restore
            // the stale pre-composition selection over the IME's committed word.
            selection = textView.selectedRange()
            text = textView.string
            applySyntaxHighlighting(to: textView, around: textView.selectedRange())
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
            guard !textView.hasMarkedText() else { return }
            selection = textView.selectedRange()
        }

        func applySyntaxHighlighting(to textView: NSTextView, around editedRange: NSRange? = nil) {
            guard let storage = textView.textStorage else { return }
            let source = textView.string as NSString
            guard source.length > 0 else { return }

            let targetRange: NSRange
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
            } else {
                targetRange = NSRange(location: 0, length: source.length)
            }
            guard targetRange.length > 0 else { return }
            let localString = source.substring(with: targetRange)
            let localSource = localString as NSString

            func global(_ range: NSRange) -> NSRange {
                guard range.location != NSNotFound else { return range }
                return NSRange(location: targetRange.location + range.location, length: range.length)
            }

            let baseFont = NSFont.monospacedSystemFont(ofSize: textView.font?.pointSize ?? 15, weight: .regular)
            let baseColor = NSColor(Color(hex: bodyColorHex))
            let markerColor = NSColor.secondaryLabelColor
            let strongColor = NSColor(Color(hex: strongColorHex))
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineHeightMultiple = 1.25
            paragraph.paragraphSpacing = 8

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
                let range = global(range)
                self.addFontTrait(.boldFontMask, to: range, in: storage, fallback: baseFont)
                storage.addAttribute(.foregroundColor, value: strongColor, range: range)
                self.muteDelimiters([global(match.range(at: 0))], in: storage, source: source, color: markerColor, delimiterLength: 2)
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

            self.applyFencedCodeStyle(to: storage, source: source, localSource: localSource,
                                      range: targetRange, color: NSColor.systemBrown)

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

        private func applyFencedCodeStyle(to storage: NSTextStorage, source: NSString, localSource: NSString,
                                          range: NSRange, color: NSColor) {
            let fenceRegex = try? NSRegularExpression(pattern: #"^\s*```"#)
            var insideFence = false
            if range.location > 0, let fenceRegex {
                let prefix = source.substring(to: range.location) as NSString
                var lineStart = 0
                while lineStart < prefix.length {
                    let lineRange = prefix.lineRange(for: NSRange(location: lineStart, length: 0))
                    let line = prefix.substring(with: lineRange) as NSString
                    if fenceRegex.firstMatch(in: line as String, range: NSRange(location: 0, length: line.length)) != nil {
                        insideFence.toggle()
                    }
                    lineStart = NSMaxRange(lineRange)
                }
            }

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

final class MarkdownSourceTextView: NSTextView {
    var onTablePaste: ((String, NSTextView) -> Void)?

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.function) {
            // Fn+Up/Down is delivered as either the arrow or PageUp/PageDown
            // key code depending on the Mac keyboard and system settings.
            switch event.keyCode {
            case 126, 116: // Up, Page Up
                moveCaretToDocumentBoundary(atEnd: false)
                return
            case 125, 121: // Down, Page Down
                moveCaretToDocumentBoundary(atEnd: true)
                return
            default:
                break
            }
        }
        super.keyDown(with: event)
    }

    private func moveCaretToDocumentBoundary(atEnd: Bool) {
        let location = atEnd ? (string as NSString).length : 0
        setSelectedRange(NSRange(location: location, length: 0))
        scrollRangeToVisible(NSRange(location: location, length: 0))
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        let plain = pasteboard.string(forType: .string) ?? ""
        let html = pasteboard.string(forType: .html)
        if let cells = MarkdownTableFormatter.parseClipboard(plain: plain, html: html) {
            onTablePaste?(MarkdownTableFormatter.markdown(cells), self)
            return
        }
        super.paste(sender)
    }
}
