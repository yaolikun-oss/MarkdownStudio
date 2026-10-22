import Foundation
import Testing
import WebKit
import SwiftUI
@testable import MarkdownReader

@MainActor
private final class VisualEditMessageProbe: NSObject, WKScriptMessageHandler {
    private var pending: CheckedContinuation<Void, Never>?
    private var receivedMarkdown: String?
    private var pendingFlush: CheckedContinuation<String, Never>?
    private var receivedFlush: String?
    private(set) var receivedFlushLine: Int?

    func waitForMarkdown() async -> String {
        if let receivedMarkdown { return receivedMarkdown }
        await withCheckedContinuation { pending = $0 }
        return receivedMarkdown ?? ""
    }

    func waitForFlush() async -> String {
        if let receivedFlush { return receivedFlush }
        return await withCheckedContinuation { pendingFlush = $0 }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let payload = message.body as? [String: Any],
              let markdown = payload["markdown"] as? String else {
            if let payload = message.body as? [String: Any], payload["kind"] as? String == "flush",
               let edits = payload["edits"], JSONSerialization.isValidJSONObject(edits),
               let data = try? JSONSerialization.data(withJSONObject: edits), let json = String(data: data, encoding: .utf8) {
                receivedFlush = json
                receivedFlushLine = payload["visibleLine"] as? Int
                pendingFlush?.resume(returning: json)
                pendingFlush = nil
            }
            return
        }
        receivedMarkdown = markdown
        pending?.resume()
        pending = nil
    }
}

@MainActor
private final class VisualEditLoadProbe: NSObject, WKNavigationDelegate {
    var continuation: CheckedContinuation<Void, Never>?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }
}

@Suite(.serialized) struct MarkdownVisualEditorTests {
    @Test @MainActor func pastedRichTextUsesPlainTextWithoutExternalStyling() async throws {
        let (view, probe) = await loadedEditorHTML("<div data-visual-index=\"0\" contenteditable=\"true\"><p>笔记：</p></div>")
        let html = try await evaluateInEditorWorld("""
            (() => {
              const block = document.querySelector('[data-visual-index]');
              const p = block.querySelector('p');
              const range = document.createRange(); range.selectNodeContents(p); range.collapse(false);
              getSelection().removeAllRanges(); getSelection().addRange(range); block.focus();
              const clipboard = new DataTransfer();
              clipboard.setData('text/plain', '外部文字\\n第二行');
              clipboard.setData('text/html', '<p style="color:red;font-size:40px;font-family:serif">外部文字</p><p>第二行</p>');
              block.dispatchEvent(new ClipboardEvent('paste', {bubbles:true,cancelable:true,clipboardData:clipboard}));
              return block.innerHTML;
            })()
            """, in: view)
        let markdown = await probe.waitForMarkdown()
        #expect(html.contains("外部文字"))
        #expect(!html.contains("color:red"))
        #expect(!html.contains("font-size:40px"))
        #expect(markdown.contains("笔记：外部文字"))
        #expect(markdown.contains("\n第二行"))
    }

    @Test func closingParenthesisBeforeChinesePreventsCommonMarkBold() {
        for closing in ["）", ")"] {
            let adjacent = "采用**影响者营销（influencermarketing\(closing)**模式"
            let separated = "采用**影响者营销（influencermarketing\(closing)** 模式"
            #expect(!MarkdownBlock.parse(adjacent)[0].html.contains("<strong>"))
            #expect(MarkdownBlock.parse(separated)[0].html.contains("<strong>"))
            #expect(MarkdownBlock.parse("采用<strong>影响者营销（influencermarketing\(closing)</strong>模式")[0].html.contains("<strong>"))
        }
    }

    @Test @MainActor func visualBoldUsesConfiguredColorForWebKitBoldElements() async throws {
        let editor = visualEditor(source: "普通正文", state: MarkdownVisualScrollState())
        let (view, _) = await loadedEditorHTML(editor.pageHTML(using: MarkdownBlock.parse("普通正文")), fullPage: true)
        let colors = try await evaluateInEditorWorld("""
            (() => {
              const p=document.querySelector('[data-visual-index] p');
              p.innerHTML='<strong>原有加粗</strong><b>WebKit 加粗</b><span style="font-weight: bold; color: black">样式加粗</span><span style="font-weight: normal">普通文字</span>';
              return [...p.children].map(node=>getComputedStyle(node).color).join('|');
            })()
            """, in: view)
        #expect(colors == "rgb(0, 119, 102)|rgb(0, 119, 102)|rgb(0, 119, 102)|rgb(51, 51, 51)")
    }

    @Test @MainActor func boldEndingInParenthesisBeforeChineseSurvivesVisualRoundTrip() async throws {
        for closing in ["）", ")"] {
            let value = "影响者营销（influencermarketing \(closing)"
            let html = "<div data-visual-index=\"0\" contenteditable=\"true\"><p>采用<b>\(value)</b>模式</p></div>"
            let (view, probe) = await loadedEditorHTML(html)
            _ = try await evaluate("document.querySelector('[data-visual-index]').dispatchEvent(new Event('input',{bubbles:true})); 'edited'", in: view)
            let markdown = await probe.waitForMarkdown()
            #expect(markdown == "采用<strong>\(value)</strong>模式")
            #expect(MarkdownBlock.parse(markdown).first?.html.contains("<strong>\(value)</strong>") == true)
        }
    }

    @Test @MainActor func typedAsterisksRemainLiteralAcrossModeSwitch() async throws {
        let (view, probe) = await loadedEditorHTML("<div data-visual-index=\"0\" contenteditable=\"true\"><p>采用模式</p></div>")
        _ = try await evaluateInEditorWorld("""
            (() => {
              const block=document.querySelector('[data-visual-index]');
              const text=block.querySelector('p').firstChild;
              const range=document.createRange(); range.setStart(text,2); range.collapse(true);
              getSelection().removeAllRanges(); getSelection().addRange(range);
              block.focus();
              document.execCommand('insertText',false,'**影响者营销**');
              block.dispatchEvent(new Event('input',{bubbles:true}));
              return block.innerHTML;
            })()
            """, in: view)
        let markdown = await probe.waitForMarkdown()
        #expect(markdown == "采用\\*\\*影响者营销\\*\\*模式")
        #expect(MarkdownBlock.parse(markdown).first?.html.contains("<strong>") == false)
    }

    @Test @MainActor func headingAfterUnorderedListBecomesTopLevelHeading() async throws {
        let (view, probe) = await loadedEditorHTML("<div data-visual-index=\"0\" contenteditable=\"true\"><ul><li>第一项</li></ul></div>")
        let dom = try await evaluateInEditorWorld("""
            (() => {
              const block=document.querySelector('[data-visual-index]');
              const li=block.querySelector('li');
              const range=document.createRange(); range.selectNodeContents(li); range.collapse(false);
              const selection=getSelection(); selection.removeAllRanges(); selection.addRange(range);
              li.closest('[contenteditable]').focus();
              document.execCommand('insertParagraph');
              window.markdownStudioCommand('heading','5');
              document.execCommand('insertText',false,'五级标题');
              block.dispatchEvent(new Event('input',{bubbles:true}));
              return document.querySelector('main').innerHTML;
            })()
            """, in: view)
        let markdown = await probe.waitForMarkdown()
        #expect(dom.contains("<ul><li>第一项</li></ul><h5>五级标题</h5>"))
        #expect(!dom.contains("<h5><ul>"))
        #expect(markdown.contains("- 第一项\n\n##### 五级标题"))
        let parsed = MarkdownBlock.parse(markdown)
        #expect(parsed.last?.headingLevel == 5)
    }

    @Test @MainActor func headingInMiddleOfRenderedListKeepsItemsOnBothSides() async throws {
        let html = "<div data-visual-index=\"0\" contenteditable=\"true\"><ul><li><p>第一项</p></li><li><p>第二项</p></li><li><p>第三项</p></li></ul></div>"
        let (view, probe) = await loadedEditorHTML(html)
        let dom = try await evaluateInEditorWorld("""
            (() => {
              const block=document.querySelector('[data-visual-index]');
              const li=block.querySelectorAll('li')[1];
              const range=document.createRange();range.selectNodeContents(li);range.collapse(false);
              getSelection().removeAllRanges();getSelection().addRange(range);
              block.focus();document.execCommand('insertParagraph');
              window.markdownStudioCommand('heading','5');
              document.execCommand('insertText',false,'中间标题');
              block.dispatchEvent(new Event('input',{bubbles:true}));
              return block.innerHTML;
            })()
            """, in: view)
        let markdown = await probe.waitForMarkdown()
        #expect(dom.contains("<h5>中间标题</h5>"))
        #expect(markdown.contains("- 第一项\n- 第二项\n\n##### 中间标题\n\n- 第三项"))
        #expect(MarkdownBlock.parse(markdown).contains { $0.headingLevel == 5 })
    }

    @Test @MainActor func inlineFormattingInDivAndRootDoesNotManufactureLines() async throws {
        let inline = "前面的文字<strong>加粗重点</strong>中间的文字<u>下划线重点</u>后面的文字。"
        for content in ["<p>\(inline)</p>", "<div>\(inline)</div>", inline,
                        "<div><div>\(inline)</div></div>"] {
            let (view, probe) = await loadedEditorHTML("<div data-visual-index=\"0\" contenteditable=\"true\">\(content)</div>")
            _ = try await evaluate("document.querySelector('[data-visual-index]').dispatchEvent(new Event('input',{bubbles:true})); 'edited'", in: view)
            let markdown = await probe.waitForMarkdown()
            #expect(markdown == "前面的文字**加粗重点**中间的文字<u>下划线重点</u>后面的文字。")
        }
    }

    @Test @MainActor func formattingWithRealReaderCSSKeepsParagraphAndHeadingStructure() async throws {
        let source = "##### 联系强度\n\n前文与联系强度都要保留，下划线后面仍然是同一段。\n\n最后一段。"
        let state = MarkdownVisualScrollState()
        let editor = visualEditor(source: source, state: state)
        let html = editor.pageHTML(using: MarkdownBlock.parse(source))
        let (view, probe) = await loadedEditorHTML(html, fullPage: true)
        _ = try await evaluate("""
            (()=>{
              const block=document.querySelector('[data-visual-index="1"]'); block.focus();
              const text=block.querySelector('p').firstChild;
              const range=document.createRange(); range.setStart(text,3); range.setEnd(text,7);
              getSelection().removeAllRanges(); getSelection().addRange(range);
              document.execCommand('bold');
              block.dispatchEvent(new Event('input',{bubbles:true})); return block.innerHTML;
            })()
            """, in: view)
        let markdown = await probe.waitForMarkdown()
        #expect(!markdown.contains("\n"))
        #expect(markdown.contains("**联系强度**"))
        _ = try await evaluateInEditorWorld("window.markdownStudioCommand('underline');window.markdownStudioFlush('test');'done'", in: view)
        let data = try #require((await probe.waitForFlush()).data(using: .utf8))
        let edits = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let final = try #require(edits.last?["markdown"] as? String)
        #expect(final.contains("**<u>联系强度</u>**") || final.contains("<u>**联系强度**</u>"))
        #expect(!final.contains("\n"))
        var document = MarkdownVisualDocument(source: source, blocks: MarkdownBlock.parse(source))
        _ = document.replaceBlock(at: 1, with: final)
        #expect(document.source.hasPrefix("##### 联系强度\n\n"))
        #expect(MarkdownBlock.parse(document.source).count == 3)
    }

    @Test @MainActor func renderedSoftLineBreakDoesNotBecomeAnExtraParagraphDuringVisualEditing() async throws {
        let source = "第一行**重点**\n第二行<u>下划线</u>仍然连续。"
        let editor = visualEditor(source: source, state: MarkdownVisualScrollState())
        let (view, probe) = await loadedEditorHTML(editor.pageHTML(using: MarkdownBlock.parse(source)), fullPage: true)
        _ = try await evaluate("document.querySelector('[data-visual-index]').dispatchEvent(new Event('input',{bubbles:true})); 'edited'", in: view)
        let markdown = await probe.waitForMarkdown()
        #expect(markdown == source)
    }

    @MainActor private func visualEditor(source: String, state: MarkdownVisualScrollState) -> MarkdownVisualEditor {
        MarkdownVisualEditor(source: .constant(source), blocks: MarkdownBlock.parse(source), parsedSource: source,
            readerWidth: 720, headingStyles: HeadingStyle.defaults, bodyColorHex: "#333333",
            readerBackgroundHex: "#FFFFFF", strongColorHex: "#007766", strongSize: 18,
            strongFamily: "系统默认", bodySize: 18, bodyFamily: "系统默认", lineHeight: 1.85,
            paragraphSpacing: 13, baseURL: nil, scrollTarget: nil, scrollRequest: 0,
            sourceLineTarget: 1, sourceLineRequest: 0, restoreRequest: 0,
            scrollState: state, onSourceLineChange: { _ in }, onActivate: {}, onImagePaste: { _ in nil })
    }

    @MainActor private func loadedEditorHTML(_ content: String, fullPage: Bool = false) async -> (WKWebView, VisualEditMessageProbe) {
        let configuration = WKWebViewConfiguration()
        let probe = VisualEditMessageProbe()
        configuration.userContentController.add(probe, contentWorld: MarkdownVisualEditor.contentWorld, name: "visualEdit")
        configuration.userContentController.addUserScript(WKUserScript(source: MarkdownVisualEditor.editorScript,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: MarkdownVisualEditor.contentWorld))
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 620, height: 540), configuration: configuration)
        let loadProbe = VisualEditLoadProbe()
        view.navigationDelegate = loadProbe
        await withCheckedContinuation { continuation in
            loadProbe.continuation = continuation
            view.loadHTMLString(fullPage ? content : "<!doctype html><html><body><main>\(content)</main></body></html>", baseURL: nil)
        }
        return (view, probe)
    }

    @Test func untouchedBlocksKeepTheirOriginalMarkdown() {
        let original = "# 标题\n\n含有 **加粗** 与 [链接](https://example.com) 的正文。\n\n| A | B |\n|---|---|\n| 1 | 2 |\n"
        let blocks = MarkdownBlock.parse(original)
        var document = MarkdownVisualDocument(source: original, blocks: blocks)
        #expect(document.source == original)
        #expect(blocks.count == 3)
        let result = document.replaceBlock(at: 1, with: "修改后的正文。")
        #expect(result != nil)
        #expect(result?.hasPrefix("# 标题\n\n修改后的正文。\n\n") == true)
        #expect(result?.hasSuffix("| A | B |\n|---|---|\n| 1 | 2 |\n") == true)
    }

    @Test func blankDocumentBecomesEditableMarkdown() {
        var document = MarkdownVisualDocument(source: "", blocks: [])
        #expect(document.segments.count == 1)
        let result = document.replaceBlock(at: 0, with: "# 新标题")
        #expect(result == "# 新标题")
    }

    @Test func rawHTMLAndFootnotesRemainSourceOnly() {
        let source = "<custom>原始 HTML</custom>\n\n正文[^note]\n\n普通段落\n"
        let document = MarkdownVisualDocument(source: source, blocks: MarkdownBlock.parse(source))
        #expect(document.editable.first == false)
        #expect(document.editable.contains(true))
        #expect(document.source == source)
    }

    @Test func longDocumentIsSegmentedWithoutChangingSource() {
        let source = (0..<1000).map { "## 标题\($0)\n\n正文\($0)\n" }.joined(separator: "\n")
        let document = MarkdownVisualDocument(source: source, blocks: MarkdownBlock.parse(source))
        #expect(document.source == source)
    }

    @Test @MainActor func webKitDOMSerializationKeepsInlineMarksAndLineBreaks() async throws {
        let configuration = WKWebViewConfiguration()
        let probe = VisualEditMessageProbe()
        let world = MarkdownVisualEditor.contentWorld
        configuration.userContentController.add(probe, contentWorld: world, name: "visualEdit")
        configuration.userContentController.addUserScript(WKUserScript(source: MarkdownVisualEditor.editorScript,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: world))
        let view = WKWebView(frame: .zero, configuration: configuration)
        let loadProbe = VisualEditLoadProbe()
        view.navigationDelegate = loadProbe
        await withCheckedContinuation { continuation in
            loadProbe.continuation = continuation
            view.loadHTMLString("""
                <!doctype html><html><body><main><div data-visual-index="0" contenteditable="true">
                <p>保留 <strong><span style="font-weight: bold"><strong>重点</strong></span></strong>，<em>斜体</em>，<span style="font-style: italic">倾斜</span>。<br>下一行</p>
                <ul><li>第一项</li><li>第二项</li></ul>
                </div></main></body></html>
                """, baseURL: nil)
        }
        _ = try await evaluate("document.querySelector('[data-visual-index]').dispatchEvent(new Event('input', {bubbles:true})); 'ok'", in: view)
        let markdown = await probe.waitForMarkdown()
        #expect(markdown.contains("保留 **重点**，*斜体*，*倾斜*。\n下一行"))
        #expect(!markdown.contains("****"))
        #expect(markdown.contains("- 第一项\n- 第二项"))
    }

    @Test @MainActor func webKitContentEditableDivLinesDoNotBecomeMarkdownParagraphs() async throws {
        let configuration = WKWebViewConfiguration()
        let probe = VisualEditMessageProbe()
        let world = MarkdownVisualEditor.contentWorld
        configuration.userContentController.add(probe, contentWorld: world, name: "visualEdit")
        configuration.userContentController.addUserScript(WKUserScript(source: MarkdownVisualEditor.editorScript,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: world))
        let view = WKWebView(frame: .zero, configuration: configuration)
        let loadProbe = VisualEditLoadProbe()
        view.navigationDelegate = loadProbe
        await withCheckedContinuation { continuation in
            loadProbe.continuation = continuation
            view.loadHTMLString("""
                <!doctype html><html><body><main><div data-visual-index="0" contenteditable="true">
                <div>研究人员将他人对个人选择的影响程度，称为</div>
                <div><strong>人际影响易感性</strong></div>
                <div>（susceptibility to interpersonal influence）这一 个性特质。</div>
                <p>真正的第一段。</p><p>真正的第二段。</p>
                </div></main></body></html>
                """, baseURL: nil)
        }
        _ = try await evaluate("document.querySelector('[data-visual-index]').dispatchEvent(new Event('input', {bubbles:true})); 'ok'", in: view)
        let markdown = await probe.waitForMarkdown()
        #expect(markdown.contains("研究人员将他人对个人选择的影响程度，称为\n**人际影响易感性**\n（susceptibility to interpersonal influence）这一 个性特质。"))
        #expect(!markdown.contains("称为\n\n**人际影响易感性**"))
        #expect(markdown.contains("个性特质。\n\n真正的第一段。\n\n真正的第二段。"))
    }

    @Test @MainActor func visualEditRoundTripsChineseEmphasisAndSurroundingText() async throws {
        let source = "研究人员将他人对个人选择的影响程度，称为**人际影响易感性**（susceptibility to interpersonal influence）这一个性特质。"
        let block = try #require(MarkdownBlock.parse(source).first)
        let html = block.html.replacingOccurrences(of: "<div data-source-line=", with: "<div data-visual-index=\"0\" contenteditable=\"true\" data-source-line=", range: block.html.range(of: "<div data-source-line="))
        let configuration = WKWebViewConfiguration()
        let probe = VisualEditMessageProbe()
        let world = MarkdownVisualEditor.contentWorld
        configuration.userContentController.add(probe, contentWorld: world, name: "visualEdit")
        configuration.userContentController.addUserScript(WKUserScript(source: MarkdownVisualEditor.editorScript,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: world))
        let view = WKWebView(frame: .zero, configuration: configuration)
        let loadProbe = VisualEditLoadProbe()
        view.navigationDelegate = loadProbe
        await withCheckedContinuation { continuation in
            loadProbe.continuation = continuation
            view.loadHTMLString("<!doctype html><html><body><main>\(html)</main></body></html>", baseURL: nil)
        }
        _ = try await evaluate("""
            (()=>{
              const root=document.querySelector('[data-visual-index]'); root.focus();
              const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);
              let node; while(node=walker.nextNode()) { const at=node.nodeValue.indexOf('易感性'); if(at>=0) {
                const range=document.createRange(); range.setStart(node,at); range.setEnd(node,at+3);
                const selection=getSelection(); selection.removeAllRanges(); selection.addRange(range);
                document.execCommand('insertText',false,'敏感性'); break;
              }}
              root.dispatchEvent(new Event('input',{bubbles:true})); return root.innerHTML;
            })()
            """, in: view)
        let serialized = await probe.waitForMarkdown()
        let expected = "研究人员将他人对个人选择的影响程度，称为**人际影响敏感性**（susceptibility to interpersonal influence）这一个性特质。"
        #expect(serialized == expected)
        let reparsed = try #require(MarkdownBlock.parse(serialized).first)
        #expect(reparsed.html.contains("<strong>人际影响敏感性</strong>"))
        #expect(reparsed.html.contains("（susceptibility to interpersonal influence）这一个性特质。"))
    }

    @Test @MainActor func applyingBoldInVisualEditorPreservesParagraphAndInlineFormatting() async throws {
        let source = "**病毒式营销**之所以有效，是因为它能制造**热度**，而热度的产生依赖研究人员所说的回响。"
        let block = try #require(MarkdownBlock.parse(source).first)
        let html = block.html.replacingOccurrences(of: "<div data-source-line=", with: "<div data-visual-index=\"0\" contenteditable=\"true\" data-source-line=", range: block.html.range(of: "<div data-source-line="))
        let configuration = WKWebViewConfiguration()
        let probe = VisualEditMessageProbe()
        let world = MarkdownVisualEditor.contentWorld
        configuration.userContentController.add(probe, contentWorld: world, name: "visualEdit")
        configuration.userContentController.addUserScript(WKUserScript(source: MarkdownVisualEditor.editorScript,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: world))
        let view = WKWebView(frame: .zero, configuration: configuration)
        let loadProbe = VisualEditLoadProbe()
        view.navigationDelegate = loadProbe
        await withCheckedContinuation { continuation in
            loadProbe.continuation = continuation
            view.loadHTMLString("<!doctype html><html><body><main>\(html)</main></body></html>", baseURL: nil)
        }
        let selectedText = try await evaluate("""
            (()=>{
              const root=document.querySelector('[data-visual-index]'); root.focus();
              const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT); let node;
              while(node=walker.nextNode()) { const at=node.nodeValue.indexOf('因为它能'); if(at>=0) {
                const range=document.createRange(); range.setStart(node,at); range.setEnd(node,at+4);
                const selection=getSelection(); selection.removeAllRanges(); selection.addRange(range);
                return selection.toString();
              }}
              return '';
            })()
            """, in: view)
        #expect(selectedText == "因为它能")
        MarkdownVisualCommandHub.activeWebView = view
        #expect(MarkdownVisualCommandHub.perform("bold"))
        let serialized = await probe.waitForMarkdown()
        let editedDOM = try await evaluate("document.querySelector('[data-visual-index]').innerHTML", in: view)
        MarkdownVisualCommandHub.activeWebView = nil
        #expect(editedDOM.contains("<b>") || editedDOM.contains("<strong>"))
        #expect(serialized == "**病毒式营销**之所以有效，是**因为它能**制造**热度**，而热度的产生依赖研究人员所说的回响。")
        let reparsed = try #require(MarkdownBlock.parse(serialized).first)
        #expect(reparsed.html.contains("<strong>因为它能</strong>"))
        #expect(reparsed.html.contains("<strong>热度</strong>"))
    }

    @Test @MainActor func boldCommandKeepsAnH5HeadingAsAHeading() async throws {
        let source = "##### 联系强度"
        let block = try #require(MarkdownBlock.parse(source).first)
        let html = block.html.replacingOccurrences(of: "<div data-source-line=", with: "<div data-visual-index=\"0\" contenteditable=\"true\" data-source-line=", range: block.html.range(of: "<div data-source-line="))
        let configuration = WKWebViewConfiguration()
        let probe = VisualEditMessageProbe()
        let world = MarkdownVisualEditor.contentWorld
        configuration.userContentController.add(probe, contentWorld: world, name: "visualEdit")
        configuration.userContentController.addUserScript(WKUserScript(source: MarkdownVisualEditor.editorScript,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: world))
        let view = WKWebView(frame: .zero, configuration: configuration)
        let loadProbe = VisualEditLoadProbe()
        view.navigationDelegate = loadProbe
        await withCheckedContinuation { continuation in
            loadProbe.continuation = continuation
            view.loadHTMLString("<!doctype html><html><body><main>\(html)</main></body></html>", baseURL: nil)
        }
        let selected = try await evaluate("""
            (()=>{
              const root=document.querySelector('[data-visual-index]'); root.focus();
              const text=root.querySelector('h5').firstChild; const range=document.createRange();
              range.setStart(text,0); range.setEnd(text,text.length);
              const selection=getSelection(); selection.removeAllRanges(); selection.addRange(range);
              return selection.toString();
            })()
            """, in: view)
        #expect(selected == "联系强度")
        MarkdownVisualCommandHub.activeWebView = view
        #expect(MarkdownVisualCommandHub.perform("bold"))
        let serialized = await probe.waitForMarkdown()
        let dom = try await evaluate("document.querySelector('[data-visual-index]').innerHTML", in: view)
        MarkdownVisualCommandHub.activeWebView = nil
        print("H5 BOLD DOM: \(dom)")
        print("H5 BOLD MARKDOWN: \(serialized)")
        #expect(serialized.hasPrefix("##### "))
    }

    @Test @MainActor func immediateSourceSwitchFlushesEditsFromLateDocumentBlocks() async throws {
        let source = """
        开头内容保持不变。

        ##### 社交网络的结构

        社交网络研究人员早就明白，信息的传播方式会因**联系**强度而异。

        ##### 联系强度

        联系强度指的是人与人之间关系的性质。
        """
        let blocks = MarkdownBlock.parse(source)
        let content = blocks.enumerated().map { index, block in
            block.html.replacingOccurrences(of: "<div data-source-line=", with: "<div data-visual-index=\"\(index)\" contenteditable=\"true\" data-source-line=", range: block.html.range(of: "<div data-source-line="))
        }.joined(separator: "\n")
        let configuration = WKWebViewConfiguration()
        let probe = VisualEditMessageProbe()
        let world = MarkdownVisualEditor.contentWorld
        configuration.userContentController.add(probe, contentWorld: world, name: "visualEdit")
        configuration.userContentController.addUserScript(WKUserScript(source: MarkdownVisualEditor.editorScript,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: world))
        let view = WKWebView(frame: .zero, configuration: configuration)
        let loadProbe = VisualEditLoadProbe()
        view.navigationDelegate = loadProbe
        await withCheckedContinuation { continuation in
            loadProbe.continuation = continuation
            view.loadHTMLString("<!doctype html><html><body><main>\(content)</main></body></html>", baseURL: nil)
        }

        _ = try await evaluate("""
            (()=>{
              const blocks=[...document.querySelectorAll('[data-visual-index]')];
              const target=blocks[blocks.length-1]; target.focus();
              const walker=document.createTreeWalker(target,NodeFilter.SHOW_TEXT); let node;
              while(node=walker.nextNode()) { const at=node.nodeValue.indexOf('性质'); if(at>=0) {
                const range=document.createRange(); range.setStart(node,at); range.setEnd(node,at+2);
                const selection=getSelection(); selection.removeAllRanges(); selection.addRange(range);
                document.execCommand('insertText',false,'关联性质'); break;
              }}
              target.dispatchEvent(new Event('input',{bubbles:true})); return 'edited';
            })()
            """, in: view)
        _ = try await evaluateInEditorWorld("window.markdownStudioFlush('test'); 'requested'", in: view)
        let flushJSON = await probe.waitForFlush()
        let edits = try #require(JSONSerialization.jsonObject(with: Data(flushJSON.utf8)) as? [[String: Any]])
        #expect((probe.receivedFlushLine ?? 0) > 0)
        #expect(edits.count == 1)
        var document = MarkdownVisualDocument(source: source, blocks: blocks)
        for edit in edits {
            guard let index = edit["index"] as? Int, let markdown = edit["markdown"] as? String else {
                Issue.record("Flush result did not include an indexed Markdown edit")
                continue
            }
            _ = document.replaceBlock(at: index, with: markdown)
        }
        let switchedSource = document.source
        #expect(switchedSource.contains("##### 社交网络的结构"))
        #expect(switchedSource.contains("##### 联系强度"))
        #expect(switchedSource.contains("**联系**"))
        #expect(switchedSource.contains("关联性质"))
        #expect(!switchedSource.contains("**联系强度**"))
    }

    @Test @MainActor func applyingBoldAcrossExistingEmphasisDoesNotSplitParagraph() async throws {
        let source = "前面的普通字**现有加粗**后面的普通字。"
        let block = try #require(MarkdownBlock.parse(source).first)
        let html = block.html.replacingOccurrences(of: "<div data-source-line=", with: "<div data-visual-index=\"0\" contenteditable=\"true\" data-source-line=", range: block.html.range(of: "<div data-source-line="))
        let configuration = WKWebViewConfiguration()
        let probe = VisualEditMessageProbe()
        let world = MarkdownVisualEditor.contentWorld
        configuration.userContentController.add(probe, contentWorld: world, name: "visualEdit")
        configuration.userContentController.addUserScript(WKUserScript(source: MarkdownVisualEditor.editorScript,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: world))
        let view = WKWebView(frame: .zero, configuration: configuration)
        let loadProbe = VisualEditLoadProbe()
        view.navigationDelegate = loadProbe
        await withCheckedContinuation { continuation in
            loadProbe.continuation = continuation
            view.loadHTMLString("<!doctype html><html><body><main>\(html)</main></body></html>", baseURL: nil)
        }
        let selected = try await evaluate("""
            (()=>{
              const root=document.querySelector('[data-visual-index]'); root.focus();
              const first=root.firstChild.firstChild, last=root.firstChild.lastChild;
              const range=document.createRange(); range.setStart(first,0); range.setEnd(last,last.length);
              const selection=getSelection(); selection.removeAllRanges(); selection.addRange(range);
              return selection.toString();
            })()
            """, in: view)
        #expect(selected == "前面的普通字现有加粗后面的普通字。")
        MarkdownVisualCommandHub.activeWebView = view
        #expect(MarkdownVisualCommandHub.perform("bold"))
        let serialized = await probe.waitForMarkdown()
        MarkdownVisualCommandHub.activeWebView = nil
        #expect(serialized.contains("前面的普通字"))
        #expect(serialized.contains("现有加粗"))
        #expect(serialized.contains("后面的普通字。"))
        #expect(serialized.filter { $0 == "\n" }.count == 0)
    }

    @Test @MainActor func screenshotFixtureSurvivesVisualParagraphEdit() async throws {
        let source = """
        我们都认识一些似乎对他人意见毫不在意的人，也认识一些为了获得他人认可，几乎愿意做任何事情的人。人们对社会影响的易感性，会因文化背景和独特的个性而有所不同。研究人员将他人对个人选择的影响程度，称为**人际影响易感性**（susceptibility to interpersonal influence）这一个性特质。

        #### 口碑传播

        **口碑**（word of mouth, WOM），在数字时代也称为“鼠标口碑”(word of mouse)，指的是个人向他人传播的产品信息。

        #### 病毒式营销与制造热度

        **病毒式营销**之所以有效，是因为它能制造**热度**，而热度的产生是通过创造研究人员所说的回响的回声宇宙（reverberating echoverse）：品牌传播在所有品牌信息来源之间形成反馈循环（“回声”），包括企业传播、新闻媒体和**用户生成的社交媒体**（user generated social media）。
        """
        let blocks = MarkdownBlock.parse(source)
        let content = blocks.enumerated().map { index, block in
            block.html.replacingOccurrences(of: "<div data-source-line=", with: "<div data-visual-index=\"\(index)\" contenteditable=\"true\" data-source-line=", range: block.html.range(of: "<div data-source-line="))
        }.joined(separator: "\n")
        let configuration = WKWebViewConfiguration()
        let probe = VisualEditMessageProbe()
        let world = MarkdownVisualEditor.contentWorld
        configuration.userContentController.add(probe, contentWorld: world, name: "visualEdit")
        configuration.userContentController.addUserScript(WKUserScript(source: MarkdownVisualEditor.editorScript,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: world))
        let view = WKWebView(frame: .zero, configuration: configuration)
        let loadProbe = VisualEditLoadProbe()
        view.navigationDelegate = loadProbe
        await withCheckedContinuation { continuation in
            loadProbe.continuation = continuation
            view.loadHTMLString("<!doctype html><html><body><main>\(content)</main></body></html>", baseURL: nil)
        }
        let firstIndex = try #require(blocks.firstIndex { $0.html.contains("人际影响易感性") })
        let editedDOM = try await evaluate("""
            (()=>{
              const root=document.querySelector('[data-visual-index="\(firstIndex)"]'); root.focus();
              const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT); let node;
              while(node=walker.nextNode()) { const at=node.nodeValue.indexOf('称为'); if(at>=0) {
                const range=document.createRange(); range.setStart(node,at+2); range.collapse(true);
                const selection=getSelection(); selection.removeAllRanges(); selection.addRange(range);
                document.execCommand('insertParagraph'); break;
              }}
              root.dispatchEvent(new Event('input',{bubbles:true})); return root.innerHTML;
            })()
            """, in: view)
        let serialized = await probe.waitForMarkdown()
        #expect(editedDOM.contains("<p>"))
        #expect(serialized == "我们都认识一些似乎对他人意见毫不在意的人，也认识一些为了获得他人认可，几乎愿意做任何事情的人。人们对社会影响的易感性，会因文化背景和独特的个性而有所不同。研究人员将他人对个人选择的影响程度，称为\n\n**人际影响易感性**（susceptibility to interpersonal influence）这一个性特质。")
        var document = MarkdownVisualDocument(source: source, blocks: blocks)
        let updatedValue = document.replaceBlock(at: firstIndex, with: serialized)
        #expect(updatedValue != nil)
        let updated = updatedValue ?? ""
        let reparsed = MarkdownBlock.parse(updated)
        #expect(reparsed.count == blocks.count + 1)
        #expect(reparsed.contains { $0.html.contains("<strong>人际影响易感性</strong>") })
        #expect(reparsed.contains { $0.html.contains("（susceptibility to interpersonal influence）这一个性特质。") })
    }

    @Test @MainActor func fullSampleVisualEditRoundTripsThroughMarkdownDocument() async throws {
        let source = """
我们都认识一些似乎对他人意见毫不在意的人，也认识一些为了获得他人认可，几乎愿意做任何事情的人。人们对社会影响的易感性，会因文化背景和独特的个性而有所不同。研究人员将他人对个人选择的影响程度，称为**人际影响易感性**（susceptibility to interpersonal influence）这一个性特质。

#### 口碑传播

**口碑**（word of mouth, WOM），在数字时代也称为“鼠标口碑”(word of mouse)，指的是个人向他人传播的产品信息。

#### 病毒式营销与制造热度

**病毒式营销**之所以有效，是因为它能制造**热度**，而热度的产生是通过创造研究人员所说的回响的回声宇宙（reverberating echoverse）：品牌传播在所有品牌信息来源之间形成反馈循环（“回声”），包括企业传播、新闻媒体和**用户生成的社交媒体**（user generated social media）。
"""
        let blocks = MarkdownBlock.parse(source)
        let targetIndex = try #require(blocks.firstIndex { $0.html.contains("病毒式营销</strong>") })
        let target = blocks[targetIndex]
        let content = target.html.replacingOccurrences(of: "<div data-source-line=", with: "<div data-visual-index=\"0\" contenteditable=\"true\" data-source-line=", range: target.html.range(of: "<div data-source-line="))
        let configuration = WKWebViewConfiguration()
        let probe = VisualEditMessageProbe()
        let world = MarkdownVisualEditor.contentWorld
        configuration.userContentController.add(probe, contentWorld: world, name: "visualEdit")
        configuration.userContentController.addUserScript(WKUserScript(source: MarkdownVisualEditor.editorScript,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: world))
        let view = WKWebView(frame: .zero, configuration: configuration)
        let loadProbe = VisualEditLoadProbe()
        view.navigationDelegate = loadProbe
        await withCheckedContinuation { continuation in
            loadProbe.continuation = continuation
            view.loadHTMLString("<!doctype html><html><body><main>\(content)</main></body></html>", baseURL: nil)
        }
        _ = try await evaluate("""
            (()=>{
              const root=document.querySelector('[data-visual-index]'); root.focus();
              const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT); let node;
              while(node=walker.nextNode()) { const at=node.nodeValue.indexOf('病毒式营销'); if(at>=0) {
                const range=document.createRange(); range.setStart(node,at+3); range.setEnd(node,at+5);
                const selection=getSelection(); selection.removeAllRanges(); selection.addRange(range);
                document.execCommand('insertText',false,'传播'); break;
              }}
              root.dispatchEvent(new Event('input',{bubbles:true})); return root.innerHTML;
            })()
            """, in: view)
        let serialized = await probe.waitForMarkdown()
        var document = MarkdownVisualDocument(source: source, blocks: blocks)
        let updatedValue = document.replaceBlock(at: targetIndex, with: serialized)
        #expect(updatedValue != nil)
        let updated = updatedValue ?? ""
        let expected = source.replacingOccurrences(of: "**病毒式营销**", with: "**病毒式传播**")
        #expect(updated == expected)
        let renderedAgain = MarkdownBlock.parse(updated)
        #expect(renderedAgain.count == blocks.count)
        #expect(renderedAgain.map(\.title) == blocks.map(\.title))
        #expect(renderedAgain[targetIndex].html.contains("<strong>病毒式传播</strong>"))
    }

    @MainActor
    private func evaluate(_ script: String, in view: WKWebView) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            view.evaluateJavaScript(script) { value, error in
                if let error { continuation.resume(throwing: error) }
                else if let value = value as? String { continuation.resume(returning: value) }
                else { continuation.resume(throwing: NSError(domain: "MarkdownVisualEditorTests", code: 1)) }
            }
        }
    }

    @MainActor
    private func evaluateInEditorWorld(_ script: String, in view: WKWebView) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            view.evaluateJavaScript(script, in: nil, in: MarkdownVisualEditor.contentWorld) { result in
                switch result {
                case .success(let value):
                    guard let string = value as? String else {
                        continuation.resume(throwing: NSError(domain: "MarkdownVisualEditorTests", code: 2))
                        return
                    }
                    continuation.resume(returning: string)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

}
