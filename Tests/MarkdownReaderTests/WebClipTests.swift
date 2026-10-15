import Testing
import WebKit
@testable import MarkdownReader

@MainActor
private final class WebViewLoadProbe: NSObject, WKNavigationDelegate {
    var continuation: CheckedContinuation<Void, Never>?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }
}

@Suite struct WebClipTests {
    @Test @MainActor func selectionClipKeepsHeadingAndListStructure() async throws {
        let view = WKWebView()
        let probe = WebViewLoadProbe()
        view.navigationDelegate = probe
        await withCheckedContinuation { continuation in
            probe.continuation = continuation
            view.loadHTMLString("""
                <!doctype html><html><head><title>演示文章</title></head><body>
                <h1>文章</h1><h2>重点内容</h2>
                <p>这是<strong>加粗内容</strong>、<em>斜体</em>、<u>下划线</u>和<del>删除线</del>。</p>
                <p><a href="https://example.com/ref">参考链接</a>与<code>inline()</code>。</p>
                <ul><li>第一点</li><li>第二点</li></ul>
                <ol><li>顺序一</li><li>顺序二</li></ol>
                <blockquote><p>引用内容</p></blockquote><pre><code>let value = 1</code></pre>
                <hr><table><thead><tr><th>名称</th><th>数量</th></tr></thead><tbody><tr><td>书</td><td>2</td></tr></tbody></table>
                </body></html>
                """, baseURL: URL(string: "https://example.com"))
        }
        let selection = try await evaluate("""
            (()=>{const r=document.createRange();r.setStartBefore(document.querySelector('h2'));r.setEndAfter(document.querySelector('table'));const s=window.getSelection();s.removeAllRanges();s.addRange(r);return JSON.stringify(true)})()
            """, in: view)
        #expect(selection == "true")
        let json = try await evaluate("JSON.stringify((\(WebBrowserSession.selectionScript)))", in: view)
        let result = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        let markdown = try #require(result?["markdown"] as? String)
        let path = try #require(result?["headingPath"] as? [String])
        #expect(markdown.contains("## 重点内容"))
        #expect(markdown.contains("这是**加粗内容**"))
        #expect(markdown.contains("*斜体*"))
        #expect(markdown.contains("<u>下划线</u>"))
        #expect(markdown.contains("~~删除线~~"))
        #expect(markdown.contains("[参考链接](https://example.com/ref)"))
        #expect(markdown.contains("`inline()`"))
        #expect(markdown.contains("- 第一点"))
        #expect(markdown.contains("- 第二点"))
        #expect(markdown.contains("1. 顺序一"))
        #expect(markdown.contains("2. 顺序二"))
        #expect(markdown.contains("> 引用内容"))
        #expect(markdown.contains("```\nlet value = 1\n```"))
        #expect(markdown.contains("---"))
        #expect(markdown.contains("| 名称 | 数量 |"))
        #expect(markdown.contains("| 书 | 2 |"))
        #expect(path == ["文章"])
    }

    @Test @MainActor func addressEntrySupportsSitesAndSearchTerms() throws {
        let session = WebBrowserSession()
        let site = try #require(session.navigate(address: "example.com/notes"))
        #expect(site.absoluteString == "https://example.com/notes")
        let search = try #require(session.navigate(address: "系统科学"))
        #expect(search.host == "duckduckgo.com")
        #expect(URLComponents(url: search, resolvingAgainstBaseURL: false)?.queryItems?.first?.value == "系统科学")
    }

    @Test func clipFormatterAddsSourceAndPageLocation() throws {
        let url = try #require(URL(string: "https://example.com/a(b)?q=1"))
        let clip = WebPageClip(markdown: "## 重点内容\n\n正文。", headingPath: ["文章", "章节 > 小节"])
        let formatted = WebClipFormatter.append(clip, title: "标题 [演示]", url: url, to: "# 笔记\n")

        #expect(formatted.contains("> 来源：[标题 \\[演示\\]](<https://example.com/a(b)?q=1>)"))
        #expect(formatted.contains("> 页面位置：文章 / 章节 \\> 小节"))
        #expect(formatted.contains("## 重点内容\n\n正文。"))
        #expect(formatted.hasPrefix("# 笔记\n\n"))
    }

    @MainActor
    private func evaluate(_ script: String, in view: WKWebView) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            view.evaluateJavaScript(script) { value, error in
                if let error { continuation.resume(throwing: error) }
                else if let value = value as? String { continuation.resume(returning: value) }
                else { continuation.resume(throwing: NSError(domain: "WebClipTests", code: 1)) }
            }
        }
    }
}
