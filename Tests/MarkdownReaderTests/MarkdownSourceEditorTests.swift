import AppKit
import SwiftUI
import Testing
@testable import MarkdownReader

@Suite struct MarkdownSourceEditorTests {
    @Test @MainActor func sourceUndoHistoryBelongsToItsEditorAndIsDiscardedOnDocumentReplacement() throws {
        let first = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let second = MarkdownSourceTextView(frame: .zero)
        first.allowsUndo = true
        first.string = "first"
        let undo = try #require(first.undoManager)
        #expect(undo !== second.undoManager)
        undo.groupsByEvent = false
        undo.beginUndoGrouping()
        first.insertText(" edit", replacementRange: NSRange(location: 5, length: 0))
        undo.endUndoGrouping()
        #expect(first.string == "first edit")
        undo.undo()
        #expect(first.string == "first")
        undo.redo()
        #expect(first.string == "first edit")
        var source = "replacement"
        var selection = NSRange(location: 0, length: 0)
        let coordinator = MarkdownSourceEditor.Coordinator(
            text: Binding(get: { source }, set: { source = $0 }),
            selection: Binding(get: { selection }, set: { selection = $0 }),
            headingStyles: HeadingStyle.defaults, bodyColorHex: "#333333", strongColorHex: "#333333",
            onSourceLineChange: { _ in })
        coordinator.synchronizeText(source, in: first)
        #expect(first.string == source)
        #expect(!undo.canUndo && !undo.canRedo)
    }

    @Test @MainActor func refreshingSourceCanvasPreservesSyntaxColors() throws {
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        editor.string = "正文 **加粗**"
        let host = MarkdownSourceEditorContainer(frame: editor.frame)
        host.scrollView.documentView = editor
        let strongRange = (editor.string as NSString).range(of: "加粗")
        editor.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: strongRange)

        MarkdownSourceCanvas.updateBackground(.lightGray, textView: editor,
                                              scrollView: host.scrollView, gutter: host.gutter)

        let color = try #require(editor.textStorage?.attribute(.foregroundColor,
            at: strongRange.location, effectiveRange: nil) as? NSColor)
        #expect(color.isEqual(NSColor.systemGreen))
    }

    @Test @MainActor func sourceLineNumbersUseLogicalLinesAndUTF16Offsets() {
        let source = "首行😀很长\n第二行\n第三行\n"
        let index = MarkdownSourceLineIndex(source)
        #expect(index.starts.count == 4)
        #expect(index.lineNumber(atUTF16Offset: 0) == 1)
        #expect(index.lineNumber(atUTF16Offset: (source as NSString).range(of: "第二行").location) == 2)
        #expect(index.lineNumber(atUTF16Offset: (source as NSString).range(of: "第三行").location) == 3)
        #expect(index.lineNumber(atUTF16Offset: (source as NSString).length) == 4)
    }

    @Test @MainActor func sourceLineGutterTracksLongDocumentWithoutChangingText() {
        let source = (1...1_200).map { "第\($0)行，较长的正文会自动折行，但不能获得额外行号。" }.joined(separator: "\n")
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 350, height: 300))
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.string = source
        let host = MarkdownSourceEditorContainer(frame: NSRect(x: 0, y: 0, width: 350, height: 300))
        let scroll = host.scrollView
        scroll.documentView = editor
        host.gutter.textView = editor
        host.gutter.scrollView = scroll
        host.gutter.updateSource(source)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 350, height: 300),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        window.layoutIfNeeded()
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 10_000))
        scroll.reflectScrolledClipView(scroll.contentView)
        editor.displayIfNeeded()

        #expect(!scroll.rulersVisible)
        #expect(host.gutter.frame.width >= 42)
        #expect(editor.string == source)
    }

    @Test @MainActor func ordinaryArrowKeysStayNearCaretInLongDocument() throws {
        let source = (1...2_200).map { "第 \($0) 行：方向键应逐行移动。" }.joined(separator: "\n")
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        editor.font = .monospacedSystemFont(ofSize: 18, weight: .regular)
        editor.string = source
        let window = NSWindow(contentRect: editor.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = editor
        window.makeFirstResponder(editor)
        let middle = (source as NSString).range(of: "第 1100 行").location + 5
        editor.setSelectedRange(NSRange(location: middle, length: 0))

        func press(_ keyCode: UInt16, _ character: unichar) throws -> Int {
            let event = try #require(NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [.function], timestamp: 0,
                windowNumber: window.windowNumber, context: nil,
                characters: String(UnicodeScalar(character)!),
                charactersIgnoringModifiers: String(UnicodeScalar(character)!),
                isARepeat: false, keyCode: keyCode
            ))
            editor.keyDown(with: event)
            return editor.selectedRange().location
        }

        let up = try press(126, 0xF700)
        #expect(up > (source as NSString).range(of: "第 1098 行").location)
        #expect(up < middle)
        let down = try press(125, 0xF701)
        #expect(down > up)
        #expect(down < (source as NSString).range(of: "第 1102 行").location)

        editor.setSelectedRange(NSRange(location: middle, length: 0))
        let left = try press(123, 0xF702)
        #expect(left == middle - 1)
        let right = try press(124, 0xF703)
        #expect(right == middle)

        let lineStart = (source as NSString).range(of: "第 1100 行").location
        editor.setSelectedRange(NSRange(location: lineStart, length: 0))
        #expect(try press(123, 0xF702) == lineStart - 1)
        #expect(try press(124, 0xF703) == lineStart)
    }

    @Test @MainActor func sourceLineGutterDoesNotCoverDocumentText() throws {
        let source = "# 第一章\n\n源码正文必须可见。\n\n**加粗** 文字"
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainerInset = NSSize(width: 18, height: 12)
        editor.font = .monospacedSystemFont(ofSize: 18, weight: .regular)
        editor.backgroundColor = .white
        editor.string = source
        var bindingText = source
        var selection = NSRange(location: 0, length: 0)
        let coordinator = MarkdownSourceEditor.Coordinator(
            text: Binding(get: { bindingText }, set: { bindingText = $0 }),
            selection: Binding(get: { selection }, set: { selection = $0 }),
            headingStyles: HeadingStyle.defaults,
            bodyColorHex: "#333333", strongColorHex: "#007766",
            onSourceLineChange: { _ in }
        )
        coordinator.applySyntaxHighlighting(to: editor)
        let host = MarkdownSourceEditorContainer(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let scroll = host.scrollView
        scroll.documentView = editor
        host.gutter.textView = editor
        host.gutter.scrollView = scroll
        host.gutter.updateSource(source)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        window.layoutIfNeeded()
        host.displayIfNeeded()
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        let hasVisibleText = stride(from: 80, to: 400, by: 3).contains { x in
            stride(from: 10, to: 180, by: 3).contains { y in
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return false }
                return color.redComponent < 0.55 && color.greenComponent < 0.55 && color.blueComponent < 0.55
            }
        }
        let hasLineNumbers = stride(from: 5, to: 38, by: 2).contains { x in
            stride(from: 8, to: 180, by: 2).contains { y in
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return false }
                return color.redComponent < 0.75 && color.greenComponent < 0.75 && color.blueComponent < 0.75
            }
        }
        #expect(hasVisibleText)
        #expect(hasLineNumbers)
        #expect(editor.string == source)
    }

    @Test @MainActor func sourceLineNumberIsVerticallyAlignedWithText() throws {
        let source = (1...2_050).map { "源码正文\($0)" }.joined(separator: "\n")
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 200))
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainerInset = NSSize(width: 18, height: 12)
        editor.font = .monospacedSystemFont(ofSize: 18, weight: .regular)
        editor.defaultParagraphStyle = MarkdownSourceTypography.paragraphStyle()
        editor.string = source
        let host = MarkdownSourceEditorContainer(frame: NSRect(x: 0, y: 0, width: 500, height: 200))
        host.scrollView.documentView = editor
        host.gutter.textView = editor
        host.gutter.scrollView = host.scrollView
        host.gutter.updateSource(source)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 200),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        window.layoutIfNeeded()
        let layout = try #require(editor.layoutManager)
        let container = try #require(editor.textContainer)
        layout.ensureLayout(for: container)
        let target = (source as NSString).range(of: "源码正文2039")
        let glyphs = layout.glyphRange(forCharacterRange: target, actualCharacterRange: nil)
        let line = layout.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil)
        host.scrollView.contentView.scroll(to: NSPoint(x: 0, y: line.minY + editor.textContainerOrigin.y - 12))
        host.scrollView.reflectScrolledClipView(host.scrollView.contentView)
        host.displayIfNeeded()
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        func inkRows(_ columns: Range<Int>) -> [Int] {
            (5..<50).filter { y in
                columns.contains { x in
                    guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return false }
                    return color.redComponent < 0.78 && color.greenComponent < 0.78 && color.blueComponent < 0.78
                }
            }
        }
        let numberRows = inkRows(20..<40)
        let textRows = inkRows(62..<145)
        #expect(!numberRows.isEmpty)
        #expect(!textRows.isEmpty)
        if let numberFirst = numberRows.first, let numberLast = numberRows.last,
           let textFirst = textRows.first, let textLast = textRows.last {
            #expect(abs(Double(numberFirst + numberLast - textFirst - textLast) / 2) < 1)
        }
    }

    @Test @MainActor func wrappedSourceLinesUseTheConfiguredReadingSpacing() throws {
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 230, height: 240))
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.textContainer?.widthTracksTextView = true
        editor.textContainerInset = NSSize(width: 18, height: 12)
        editor.font = .monospacedSystemFont(ofSize: 18, weight: .regular)
        editor.defaultParagraphStyle = MarkdownSourceTypography.paragraphStyle()
        editor.string = String(repeating: "这里是同一个段落中的连续文字。", count: 10)
        let layout = try #require(editor.layoutManager)
        let container = try #require(editor.textContainer)
        layout.ensureLayout(for: container)
        var lineTops: [CGFloat] = []
        layout.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs)) {
            rect, _, _, _, stop in
            lineTops.append(rect.minY)
            if lineTops.count == 3 { stop.pointee = true }
        }
        #expect(lineTops.count == 3)
        if lineTops.count == 3 {
            let firstStep = lineTops[1] - lineTops[0]
            let secondStep = lineTops[2] - lineTops[1]
            #expect(firstStep >= 28 && firstStep <= 33)
            #expect(abs(firstStep - secondStep) < 1)
        }
    }

    @Test @MainActor func workspaceActivationRunsAfterNativeCaretPlacement() async throws {
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        editor.string = "第一行\n第二行\n第三行"
        var selectionSeenAtActivation: NSRange?
        editor.onActivate = { selectionSeenAtActivation = editor.selectedRange() }
        let target = NSRange(location: (editor.string as NSString).range(of: "第二行").location + 2, length: 0)

        WorkspaceMouseDownHandling.perform(
            nativeMouseDown: { editor.setSelectedRange(target) },
            activateWorkspace: { [weak editor] in editor?.onActivate?() }
        )

        #expect(selectionSeenAtActivation == nil)
        try await Task.sleep(for: .milliseconds(10))
        #expect(selectionSeenAtActivation == target)
    }

    @Test @MainActor func insertionPointTracksRenderedLineInLongSource() throws {
        let source = (1...120).map { "段落 \($0)：这是一段用于验证源码编辑器命中位置的文字。" }.joined(separator: "\n\n")
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainerInset = NSSize(width: 18, height: 12)
        editor.defaultParagraphStyle = MarkdownSourceTypography.paragraphStyle()
        editor.string = source

        let scroll = MarkdownSourceScrollView(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        scroll.documentView = editor
        scroll.layoutSubtreeIfNeeded()
        let target = (source as NSString).range(of: "段落 84：")
        let layout = try #require(editor.layoutManager)
        let container = try #require(editor.textContainer)
        layout.ensureLayout(for: container)
        let glyphRange = layout.glyphRange(forCharacterRange: target, actualCharacterRange: nil)
        let lineRect = layout.boundingRect(forGlyphRange: glyphRange, in: container)
        let point = NSPoint(x: lineRect.midX + editor.textContainerOrigin.x,
                            y: lineRect.midY + editor.textContainerOrigin.y)

        let actual = editor.characterIndexForInsertion(at: point)

        #expect(actual >= target.location)
        #expect(actual <= NSMaxRange(target))
    }

    @Test @MainActor func visibleLowerLinesRemainHitTestableAfterScrolling() throws {
        let source = (1...180).map { "第\($0)段 社交优惠券 与后续内容。" }.joined(separator: "\n\n")
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainerInset = NSSize(width: 18, height: 12)
        editor.defaultParagraphStyle = MarkdownSourceTypography.paragraphStyle()
        editor.string = source
        let scroll = MarkdownSourceScrollView(frame: NSRect(x: 27, y: 33, width: 640, height: 420))
        scroll.documentView = editor
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 490),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 490))
        host.addSubview(scroll)
        window.contentView = host
        window.layoutIfNeeded()
        scroll.layoutSubtreeIfNeeded()
        let layout = try #require(editor.layoutManager)
        let container = try #require(editor.textContainer)
        layout.ensureLayout(for: container)
        let usedHeight = layout.usedRect(for: container).maxY + editor.textContainerOrigin.y
        #expect(scroll.contentInsets.bottom == 0)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: usedHeight * 0.65))
        scroll.reflectScrolledClipView(scroll.contentView)
        for fraction in [0.1, 0.25, 0.55, 0.85] {
            let visible = scroll.contentView.bounds
            let pointInEditor = NSPoint(x: 250, y: visible.minY + visible.height * fraction)
            let pointInParent = editor.convert(pointInEditor, to: host)
            let hit = scroll.hitTest(pointInParent)
            #expect(hit === editor)
        }
    }

    @Test @MainActor func lastLineHasNoExtraBottomScrollInset() {
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.string = String(repeating: "one paragraph\n", count: 40)
        let scrollView = MarkdownSourceScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        scrollView.documentView = editor
        scrollView.layoutSubtreeIfNeeded()
        #expect(scrollView.contentInsets.bottom == 0)
        let bottom = scrollView.contentView.constrainBoundsRect(
            NSRect(x: 0, y: 10_000, width: 400, height: 300)).minY
        #expect(bottom <= editor.frame.height - 300 + 2)
    }

    @Test @MainActor func typingAtLowVisibleCaretKeepsViewportUntilCaretLeavesIt() async throws {
        let source = (1...220).map { "第\($0)段测试文字。" }.joined(separator: "\n\n")
        let host = MarkdownSourceEditorContainer(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 590, height: 420))
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainerInset = NSSize(width: 18, height: 12)
        editor.font = .monospacedSystemFont(ofSize: 18, weight: .regular)
        editor.defaultParagraphStyle = MarkdownSourceTypography.paragraphStyle()
        editor.string = source
        host.scrollView.documentView = editor
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 420), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        window.layoutIfNeeded()
        var bindingText = source
        var bindingSelection = NSRange(location: 0, length: 0)
        let coordinator = MarkdownSourceEditor.Coordinator(
            text: Binding(get: { bindingText }, set: { bindingText = $0 }),
            selection: Binding(get: { bindingSelection }, set: { bindingSelection = $0 }),
            headingStyles: HeadingStyle.defaults,
            bodyColorHex: "#333333", strongColorHex: "#007766",
            onSourceLineChange: { _ in }
        )
        coordinator.textView = editor
        coordinator.scrollView = host.scrollView
        coordinator.lastKnownText = source
        editor.delegate = coordinator
        let layout = try #require(editor.layoutManager)
        let container = try #require(editor.textContainer)
        layout.ensureLayout(for: container)
        let target = (source as NSString).range(of: "第180段")
        let glyph = layout.glyphRange(forCharacterRange: target, actualCharacterRange: nil)
        let rect = layout.boundingRect(forGlyphRange: glyph, in: container)
        let clip = host.scrollView.contentView
        clip.scroll(to: NSPoint(x: 0, y: rect.minY + editor.textContainerOrigin.y - 300))
        host.scrollView.reflectScrolledClipView(clip)
        let before = clip.bounds.minY
        editor.setSelectedRange(NSRange(location: NSMaxRange(target), length: 0))
        editor.insertText("X", replacementRange: editor.selectedRange())
        #expect(abs(clip.bounds.minY - before) < 1)
        try await Task.sleep(for: .milliseconds(550))
        #expect(abs(clip.bounds.minY - before) < 1)
        #expect(bindingText.contains("第180段X"))

        clip.scroll(to: NSPoint(x: 0, y: rect.minY + editor.textContainerOrigin.y - 395))
        host.scrollView.reflectScrolledClipView(clip)
        let nearBottom = clip.bounds.minY
        editor.insertText("Y", replacementRange: editor.selectedRange())
        #expect(clip.bounds.minY > nearBottom)
        #expect(clip.bounds.minY - nearBottom < 60)
    }

    @Test @MainActor func selectingVisibleTextNearDocumentEndDoesNotJumpViewport() throws {
        let source = (1...2_200).map { "第\($0)行：这是一段用于测试鼠标拖选时页面是否保持位置的长文档。" }.joined(separator: "\n")
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainerInset = NSSize(width: 18, height: 12)
        editor.font = .monospacedSystemFont(ofSize: 18, weight: .regular)
        editor.defaultParagraphStyle = MarkdownSourceTypography.paragraphStyle()
        editor.string = source
        let scroll = MarkdownSourceScrollView(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        scroll.documentView = editor
        let window = NSWindow(contentRect: scroll.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = scroll
        window.layoutIfNeeded()
        scroll.layoutSubtreeIfNeeded()
        let layout = try #require(editor.layoutManager)
        let container = try #require(editor.textContainer)
        layout.ensureLayout(for: container)
        let start = (source as NSString).range(of: "第2072行").location
        let end = (source as NSString).range(of: "第2074行").location + 8
        let endGlyph = layout.glyphIndexForCharacter(at: end)
        let endRect = layout.lineFragmentRect(forGlyphAt: endGlyph, effectiveRange: nil)
        let clip = scroll.contentView
        clip.scroll(to: NSPoint(x: 0, y: endRect.maxY + editor.textContainerOrigin.y - clip.bounds.height + 90))
        scroll.reflectScrolledClipView(clip)
        let before = clip.bounds.minY

        let selected = NSRange(location: start, length: end - start)
        editor.setSelectedRange(selected)
        editor.scrollRangeToVisible(selected)

        #expect(abs(clip.bounds.minY - before) < 1)
        #expect(editor.selectedRange() == selected)

        let finalStart = (source as NSString).range(of: "第2198行").location
        let finalEnd = (source as NSString).range(of: "第2199行").location + 8
        let maximum = clip.constrainBoundsRect(NSRect(x: 0, y: 100_000,
                                                       width: clip.bounds.width, height: clip.bounds.height)).minY
        clip.scroll(to: NSPoint(x: 0, y: maximum))
        scroll.reflectScrolledClipView(clip)
        let finalBefore = clip.bounds.minY
        let finalSelection = NSRange(location: finalStart, length: finalEnd - finalStart)
        editor.setSelectedRange(finalSelection)
        editor.scrollRangeToVisible(finalSelection)
        #expect(abs(clip.bounds.minY - finalBefore) < 1)
    }

    @Test @MainActor func draggingInsideBottomPaddingDoesNotAutoscroll() throws {
        let source = (1...2_100).map { "第\($0)行：下半屏拖选时页面不能自行滚动。" }.joined(separator: "\n")
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainerInset = NSSize(width: 18, height: 12)
        editor.font = .monospacedSystemFont(ofSize: 18, weight: .regular)
        editor.defaultParagraphStyle = MarkdownSourceTypography.paragraphStyle()
        editor.string = source
        let scroll = MarkdownSourceScrollView(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        scroll.documentView = editor
        let window = NSWindow(contentRect: scroll.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = scroll
        window.layoutIfNeeded()
        scroll.layoutSubtreeIfNeeded()
        let layout = try #require(editor.layoutManager)
        let container = try #require(editor.textContainer)
        layout.ensureLayout(for: container)
        let clip = scroll.contentView
        let maximum = clip.constrainBoundsRect(NSRect(x: 0, y: 100_000,
                                                       width: clip.bounds.width, height: clip.bounds.height)).minY
        clip.scroll(to: NSPoint(x: 0, y: maximum))
        scroll.reflectScrolledClipView(clip)
        let before = clip.bounds.minY
        let pointInClip = NSPoint(x: 200, y: clip.bounds.minY + clip.bounds.height * 0.75)
        let pointInWindow = clip.convert(pointInClip, to: nil)
        let event = try #require(NSEvent.mouseEvent(with: .leftMouseDragged,
                                                   location: pointInWindow,
                                                   modifierFlags: [], timestamp: 0,
                                                   windowNumber: window.windowNumber, context: nil,
                                                   eventNumber: 1, clickCount: 1, pressure: 1))
        _ = editor.autoscroll(with: event)
        #expect(abs(clip.bounds.minY - before) < 1)
    }

    @Test @MainActor func nativeSelectionDragNearBottomKeepsViewport() throws {
        let source = (1...2_100).map { "第\($0)行：下半屏拖选时页面不能自行滚动。" }.joined(separator: "\n") + "\n\n\n\n"
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainerInset = NSSize(width: 18, height: 12)
        editor.font = .monospacedSystemFont(ofSize: 18, weight: .regular)
        editor.defaultParagraphStyle = MarkdownSourceTypography.paragraphStyle()
        editor.string = source
        let scroll = MarkdownSourceScrollView(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        scroll.documentView = editor
        let window = NSWindow(contentRect: scroll.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = scroll
        window.makeKeyAndOrderFront(nil)
        window.layoutIfNeeded()
        scroll.layoutSubtreeIfNeeded()
        let layout = try #require(editor.layoutManager)
        let container = try #require(editor.textContainer)
        layout.ensureLayout(for: container)
        let clip = scroll.contentView
        let maximum = clip.constrainBoundsRect(NSRect(x: 0, y: 100_000,
                                                       width: clip.bounds.width, height: clip.bounds.height)).minY
        clip.scroll(to: NSPoint(x: 0, y: maximum))
        scroll.reflectScrolledClipView(clip)
        let before = clip.bounds.minY
        let start = (source as NSString).range(of: "第2100行")
        let glyph = layout.glyphIndexForCharacter(at: start.location)
        let line = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let startInEditor = NSPoint(x: editor.textContainerOrigin.x + 80,
                                    y: editor.textContainerOrigin.y + line.midY)
        let startInWindow = editor.convert(startInEditor, to: nil)
        let endInClip = NSPoint(x: 250, y: clip.bounds.minY + clip.bounds.height * 0.75)
        let endInWindow = clip.convert(endInClip, to: nil)
        func mouse(_ kind: NSEvent.EventType, at point: NSPoint, number: Int) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: kind, location: point, modifierFlags: [],
                                            timestamp: Double(number), windowNumber: window.windowNumber,
                                            context: nil, eventNumber: number, clickCount: 1, pressure: 1))
        }
        let down = try mouse(.leftMouseDown, at: startInWindow, number: 1)
        let drag = try mouse(.leftMouseDragged, at: endInWindow, number: 2)
        let up = try mouse(.leftMouseUp, at: endInWindow, number: 3)
        NSApp.postEvent(up, atStart: false)
        NSApp.postEvent(drag, atStart: true)
        editor.mouseDown(with: down)
        #expect(editor.selectedRange().length > 0)
        #expect(abs(clip.bounds.minY - before) < 1)
    }

    @Test @MainActor func localHighlightKeepsFenceStateInLongDocument() throws {
        let prefix = "````\ninside code\n````\nplain text\n"
        let source = prefix + String(repeating: "normal paragraph\n", count: 8_000) + "last line\n"
        var bindingText = source
        var bindingSelection = NSRange(location: 0, length: 0)
        let coordinator = MarkdownSourceEditor.Coordinator(
            text: Binding(get: { bindingText }, set: { bindingText = $0 }),
            selection: Binding(get: { bindingSelection }, set: { bindingSelection = $0 }),
            headingStyles: HeadingStyle.defaults,
            bodyColorHex: "#333333", strongColorHex: "#333333",
            onSourceLineChange: { _ in }
        )
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        editor.string = source
        coordinator.applySyntaxHighlighting(to: editor)

        let inside = (source as NSString).range(of: "inside code").location
        let outside = (source as NSString).range(of: "plain text").location
        let storage = try #require(editor.textStorage)
        #expect(storage.attribute(.backgroundColor, at: inside, effectiveRange: nil) != nil)
        #expect(storage.attribute(.backgroundColor, at: outside, effectiveRange: nil) == nil)

        let end = (source as NSString).range(of: "last line").location
        coordinator.applySyntaxHighlighting(to: editor, around: NSRange(location: end, length: 0))
        #expect(storage.attribute(.backgroundColor, at: end, effectiveRange: nil) == nil)
        #expect(bindingText == source)
    }

    @Test @MainActor func committedEditPublishesAfterTypingPauseAndFlushesOnDemand() async {
        var bindingText = "old"
        var bindingSelection = NSRange(location: 3, length: 0)
        let coordinator = MarkdownSourceEditor.Coordinator(
            text: Binding(get: { bindingText }, set: { bindingText = $0 }),
            selection: Binding(get: { bindingSelection }, set: { bindingSelection = $0 }),
            headingStyles: HeadingStyle.defaults,
            bodyColorHex: "#333333", strongColorHex: "#333333",
            onSourceLineChange: { _ in }
        )
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        editor.string = "old new"
        coordinator.textView = editor
        coordinator.lastKnownText = bindingText
        editor.setSelectedRange(NSRange(location: 7, length: 0))
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
        #expect(bindingText == "old")
        #expect(coordinator.hasPendingLocalChanges)
        #expect(bindingSelection.location == 7)
        coordinator.synchronizeText(bindingText, in: editor)
        #expect(editor.string == "old new")
        #expect(bindingText == "old")
        coordinator.flushPendingChanges()
        #expect(bindingText == "old new")
        #expect(!coordinator.hasPendingLocalChanges)
        editor.string = "old new!"
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
        #expect(bindingText == "old new")
        try? await Task.sleep(for: .milliseconds(600))
        #expect(bindingText == "old new!")
        #expect(editor.string == "old new!")
    }

    @Test @MainActor func returnKeepsCaretFocusedAndAllowsImmediateTypingInLongDocument() async throws {
        let original = String(repeating: "长文档正文用于检查回车后的插入点。\n", count: 2_100) + "最后一行"
        var bindingText = original
        var bindingSelection = NSRange(location: (original as NSString).length, length: 0)
        let coordinator = MarkdownSourceEditor.Coordinator(
            text: Binding(get: { bindingText }, set: { bindingText = $0 }),
            selection: Binding(get: { bindingSelection }, set: { bindingSelection = $0 }),
            headingStyles: HeadingStyle.defaults,
            bodyColorHex: "#333333", strongColorHex: "#007766",
            onSourceLineChange: { _ in }
        )
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 700, height: 420))
        editor.isEditable = true
        editor.isSelectable = true
        editor.allowsUndo = true
        editor.string = original
        editor.delegate = coordinator
        coordinator.textView = editor
        coordinator.lastKnownText = original
        let window = NSWindow(contentRect: editor.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = editor
        window.makeKeyAndOrderFront(nil)
        #expect(window.makeFirstResponder(editor))
        editor.setSelectedRange(bindingSelection)

        editor.insertNewline(nil)
        await Task.yield()
        let afterReturn = (editor.string as NSString).length
        #expect(editor.string == original + "\n")
        #expect(editor.selectedRange() == NSRange(location: afterReturn, length: 0))
        #expect(bindingSelection == editor.selectedRange())
        #expect(window.firstResponder === editor)

        editor.insertText("继续输入", replacementRange: editor.selectedRange())
        try? await Task.sleep(for: .milliseconds(800))
        #expect(editor.string == original + "\n继续输入")
        #expect(editor.selectedRange().location == (editor.string as NSString).length)
        #expect(window.firstResponder === editor)
        coordinator.flushPendingChanges()
        #expect(bindingText == editor.string)
        window.orderOut(nil)
    }

    @Test @MainActor func longDocumentTypingDoesNotPublishWholeDocumentPerKeystroke() {
        let original = String(repeating: "一段较长的 Markdown 正文。\n", count: 12_000)
        var bindingText = original
        var publications = 0
        var bindingSelection = NSRange(location: (original as NSString).length, length: 0)
        let coordinator = MarkdownSourceEditor.Coordinator(
            text: Binding(get: { bindingText }, set: { bindingText = $0; publications += 1 }),
            selection: Binding(get: { bindingSelection }, set: { bindingSelection = $0 }),
            headingStyles: HeadingStyle.defaults,
            bodyColorHex: "#333333", strongColorHex: "#007766",
            onSourceLineChange: { _ in }
        )
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        editor.string = original
        coordinator.textView = editor
        coordinator.lastKnownText = original
        for character in "连续输入中文并加粗" {
            editor.string.append(character)
            coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
        }
        #expect(publications == 0)
        coordinator.flushPendingChanges()
        #expect(publications == 1)
        #expect(bindingText == original + "连续输入中文并加粗")
    }

    @Test @MainActor func plainSourceModeRemovesStylingAndDoesNotScheduleHighlightWhileTyping() throws {
        let source = "普通 **加粗** 内容"
        var bindingText = source
        var bindingSelection = NSRange(location: 0, length: 0)
        let coordinator = MarkdownSourceEditor.Coordinator(
            text: Binding(get: { bindingText }, set: { bindingText = $0 }),
            selection: Binding(get: { bindingSelection }, set: { bindingSelection = $0 }),
            headingStyles: HeadingStyle.defaults,
            bodyColorHex: "#333333", strongColorHex: "#007766",
            onSourceLineChange: { _ in }
        )
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        editor.string = source
        coordinator.textView = editor
        coordinator.lastKnownText = source
        coordinator.applySyntaxHighlighting(to: editor)
        let boldOffset = (source as NSString).range(of: "加粗").location
        let storage = try #require(editor.textStorage)
        let colored = try #require(storage.attribute(.foregroundColor, at: boldOffset, effectiveRange: nil) as? NSColor)
        coordinator.updateSyntaxHighlighting(enabled: false, textView: editor)
        let plain = try #require(storage.attribute(.foregroundColor, at: boldOffset, effectiveRange: nil) as? NSColor)
        #expect(colored != plain)
        editor.string = source + "下一字"
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
        coordinator.flushPendingChanges()
        #expect(bindingText == source + "下一字")
        coordinator.updateSyntaxHighlighting(enabled: true, textView: editor)
        let recolored = try #require(storage.attribute(.foregroundColor, at: boldOffset, effectiveRange: nil) as? NSColor)
        #expect(recolored == colored)
    }

    @Test @MainActor func markdownBoldUsesConfiguredStrongColorInSourceEditor() throws {
        let source = "普通 **加粗文字** 结尾\n<strong>括号）</strong>模式\n**括号）**模式"
        var bindingText = source
        var bindingSelection = NSRange(location: 0, length: 0)
        let coordinator = MarkdownSourceEditor.Coordinator(
            text: Binding(get: { bindingText }, set: { bindingText = $0 }),
            selection: Binding(get: { bindingSelection }, set: { bindingSelection = $0 }),
            headingStyles: HeadingStyle.defaults,
            bodyColorHex: "#333333", strongColorHex: "#007766",
            onSourceLineChange: { _ in }
        )
        let editor = MarkdownSourceTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        editor.string = source
        coordinator.applySyntaxHighlighting(to: editor)
        let storage = try #require(editor.textStorage)
        let bold = (source as NSString).range(of: "加粗文字").location
        let body = (source as NSString).range(of: "普通").location
        let htmlBold = (source as NSString).range(of: "括号）").location
        let invalidMarkdown = (source as NSString).range(of: "括号）", options: [], range: NSRange(location: htmlBold + 1, length: (source as NSString).length - htmlBold - 1)).location
        let boldColor = try #require(storage.attribute(.foregroundColor, at: bold, effectiveRange: nil) as? NSColor)
        let bodyColor = try #require(storage.attribute(.foregroundColor, at: body, effectiveRange: nil) as? NSColor)
        let htmlBoldColor = try #require(storage.attribute(.foregroundColor, at: htmlBold, effectiveRange: nil) as? NSColor)
        let invalidColor = try #require(storage.attribute(.foregroundColor, at: invalidMarkdown, effectiveRange: nil) as? NSColor)
        #expect(boldColor.usingColorSpace(.deviceRGB)?.greenComponent ?? 0 > bodyColor.usingColorSpace(.deviceRGB)?.greenComponent ?? 0)
        #expect(boldColor.usingColorSpace(.deviceRGB)?.blueComponent ?? 0 > bodyColor.usingColorSpace(.deviceRGB)?.blueComponent ?? 0)
        #expect(htmlBoldColor == boldColor)
        #expect(invalidColor == bodyColor)
    }
}
