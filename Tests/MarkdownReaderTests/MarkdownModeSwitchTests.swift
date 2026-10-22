import AppKit
import SwiftUI
import WebKit
import Testing
@testable import MarkdownReader

@MainActor
private final class ModeSwitchFixture: ObservableObject {
    @Published var source: String
    @Published var selection = NSRange(location: 0, length: 0)
    @Published var sourceMode = false
    @Published var sourceRequest = 0
    @Published var visualRequest = 0
    let position = MarkdownVisualScrollState()

    init(source: String) { self.source = source }

    func showSource() async {
        await withCheckedContinuation { continuation in
            MarkdownVisualCommandHub.commitActiveEdits { continuation.resume() }
        }
        position.activeMode = .source
        selection = position.selection ?? NSRange(location: 0, length: 0)
        sourceRequest += 1
        sourceMode = true
    }

    func showVisual() {
        MarkdownSourcePositionHub.capture()
        position.activeMode = .visual
        visualRequest += 1
        sourceMode = false
    }
}

private struct ModeSwitchFixtureView: View {
    @ObservedObject var model: ModeSwitchFixture
    var body: some View {
        NotebookSplitView(primary: AnyView(Color.gray), notes: AnyView(notes), rightPaneWidth: 720,
                          minimumPrimaryWidth: 260, minimumNotesWidth: 320, onRightPaneWidthChange: { _ in })
    }
    @ViewBuilder private var notes: some View {
        if model.sourceMode {
            MarkdownSourceEditor(text: $model.source, selection: $model.selection, fontSize: 18,
                headingStyles: HeadingStyle.defaults, bodyColorHex: "#333333", strongColorHex: "#007766",
                sourceLineTarget: 1, sourceLineRequest: 0, focusRequest: model.sourceRequest,
                onSourceLineChange: { _ in }, onActivate: {}, onImagePaste: { _, _ in false },
                positionState: model.position, positionRestoreRequest: model.sourceRequest)
        } else {
            MarkdownVisualEditor(source: $model.source, blocks: MarkdownBlock.parse(model.source), parsedSource: model.source,
                readerWidth: 720, headingStyles: HeadingStyle.defaults, bodyColorHex: "#333333",
                readerBackgroundHex: "#FFFFFF", strongColorHex: "#007766", strongSize: 18,
                strongFamily: "系统默认", bodySize: 18, bodyFamily: "系统默认", lineHeight: 1.85,
                paragraphSpacing: 13, baseURL: nil, scrollTarget: nil, scrollRequest: 0,
                sourceLineTarget: 1, sourceLineRequest: 0, restoreRequest: model.visualRequest,
                scrollState: model.position, onSourceLineChange: { _ in }, onActivate: {}, onImagePaste: { _ in nil })
        }
    }
}

extension MarkdownVisualEditorTests {
    @Test @MainActor func headingAfterListKeepsLevelAcrossModeSwitch() async throws {
        let model = ModeSwitchFixture(source: "- 第一项\n")
        let host = NSHostingView(rootView: ModeSwitchFixtureView(model: model))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1600, height: 760),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.frame = NSRect(x: 0, y: 0, width: 1600, height: 760)
        host.layoutSubtreeIfNeeded()
        defer { window.close() }
        let web = try await waitForWebView(in: host)
        let split = try #require(find(NotebookNativeSplitView.self, in: host))
        let divider = split.subviews[0].frame.maxX
        let dom = try await web.callAsyncJavaScript("""
            const block=document.querySelector('[data-visual-index]');
            const li=block.querySelector('li');
            const range=document.createRange();range.selectNodeContents(li);range.collapse(false);
            const selection=getSelection();selection.removeAllRanges();selection.addRange(range);
            block.focus();document.execCommand('insertParagraph');
            window.markdownStudioCommand('heading','5');
            document.execCommand('insertText',false,'五级标题');
            block.dispatchEvent(new Event('input',{bubbles:true}));
            return block.innerHTML;
            """, arguments: [:], in: nil, contentWorld: MarkdownVisualEditor.contentWorld)
        #expect((dom as? String)?.contains("</ul><h5>五级标题</h5>") == true)
        await model.showSource()
        host.layoutSubtreeIfNeeded()
        #expect(model.source.contains("##### 五级标题"))
        #expect(MarkdownBlock.parse(model.source).last?.headingLevel == 5)
        #expect(abs(split.subviews[0].frame.maxX - divider) < 1)
        model.showVisual()
        let restored = try await waitForWebView(in: host)
        let hasHeading = try await restored.callAsyncJavaScript("return !!document.querySelector('h5');",
            arguments: [:], in: nil, contentWorld: MarkdownVisualEditor.contentWorld) as? Bool
        #expect(hasHeading == true)
        #expect(abs(split.subviews[0].frame.maxX - divider) < 1)
    }

    @Test @MainActor func editingAtTheEndPreservesFormattingCaretViewportAndDividerAcrossModes() async throws {
        let original = (0..<75).map { "## 章节\($0)\n\n正文\($0)测试文字，保持段落和编辑位置。\n\n" }.joined()
            + "##### 联系强度\n\n文末包含加粗重点和下划线重点，继续写完最后一句。\n"
        let model = ModeSwitchFixture(source: original)
        let host = NSHostingView(rootView: ModeSwitchFixtureView(model: model))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1600, height: 760),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.frame = NSRect(x: 0, y: 0, width: 1600, height: 760)
        host.layoutSubtreeIfNeeded()
        defer { window.close() }
        let web = try await waitForWebView(in: host)
        let split = try #require(find(NotebookNativeSplitView.self, in: host))
        let divider = split.subviews[0].frame.maxX
        _ = try await web.callAsyncJavaScript("""
            const root=document.querySelector('main');
            const block=[...root.querySelectorAll('[data-visual-index]')].at(-1); block.focus();
            const walker=document.createTreeWalker(block,NodeFilter.SHOW_TEXT); const text=walker.nextNode();
            const selection=getSelection();
            for(const [word,command] of [['加粗重点','bold'],['下划线重点','underline']]) {
              const walk=document.createTreeWalker(block,NodeFilter.SHOW_TEXT); let node;
              while(node=walk.nextNode()) { const at=node.nodeValue.indexOf(word); if(at<0)continue;
                const range=document.createRange();range.setStart(node,at);range.setEnd(node,at+word.length);
                selection.removeAllRanges();selection.addRange(range); window.markdownStudioCommand(command);break;
              }
            }
            const range=document.createRange();range.selectNodeContents(block);range.collapse(false);
            selection.removeAllRanges();selection.addRange(range);
            block.scrollIntoView({block:'center',behavior:'instant'});
            return window.markdownStudioPosition();
            """, arguments: [:], in: nil, contentWorld: MarkdownVisualEditor.contentWorld)
        var originalViewport: MarkdownViewportAnchor?
        for _ in 0..<4 {
            await model.showSource()
            if originalViewport == nil { originalViewport = model.position.viewport }
            #expect(model.position.viewport == originalViewport)
            try await Task.sleep(for: .milliseconds(180))
            host.layoutSubtreeIfNeeded()
            let native = try #require(find(MarkdownSourceTextView.self, in: host))
            let scroll = try #require(native.enclosingScrollView)
            #expect(model.source.contains("文末包含**加粗重点**和<u>下划线重点</u>，继续写完最后一句。"))
            #expect(model.source.hasPrefix(original.components(separatedBy: "##### 联系强度")[0]))
            #expect(native.selectedRange().location >= (model.source as NSString).length - 4)
            #expect(window.firstResponder === native)
            #expect(scroll.contentView.bounds.minY > 1000)
            #expect(abs(split.subviews[0].frame.maxX - divider) < 1)
            model.showVisual()
            #expect(model.position.viewport == originalViewport)
            let restored = try await waitForWebView(in: host)
            try await Task.sleep(for: .milliseconds(120))
            let result = try await restored.callAsyncJavaScript("return window.markdownStudioPosition();",
                arguments: [:], in: nil, contentWorld: MarkdownVisualEditor.contentWorld) as? [String: Any]
            let caret = result?["anchor"] as? [String: Any]
            #expect(caret?["index"] as? Int == MarkdownBlock.parse(model.source).count - 1)
            let y = try await restored.callAsyncJavaScript("return window.scrollY;", arguments: [:], in: nil,
                                                          contentWorld: MarkdownVisualEditor.contentWorld) as? Double ?? 0
            #expect(y > 1000)
            #expect(abs(split.subviews[0].frame.maxX - divider) < 1)
        }
    }

    @MainActor private func waitForWebView(in root: NSView) async throws -> WKWebView {
        for _ in 0..<100 {
            root.layoutSubtreeIfNeeded()
            if let view = find(WKWebView.self, in: root),
               let ready = try? await view.callAsyncJavaScript("return typeof window.markdownStudioPosition === 'function';",
                    arguments: [:], in: nil, contentWorld: MarkdownVisualEditor.contentWorld) as? Bool,
               ready { return view }
            try await Task.sleep(for: .milliseconds(30))
        }
        throw NSError(domain: "ModeSwitchTests", code: 1, userInfo: [NSLocalizedDescriptionKey:"Visual editor did not load"])
    }

    @MainActor private func find<T: NSView>(_ type: T.Type, in root: NSView) -> T? {
        if let found = root as? T { return found }
        for child in root.subviews { if let found = find(type, in: child) { return found } }
        return nil
    }
}
