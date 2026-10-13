import AppKit
import SwiftUI
import WebKit

struct ReaderWebView: NSViewRepresentable {
    let blocks: [MarkdownBlock]
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
    let onSourceLineChange: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.webView = webView
        webView.navigationDelegate = context.coordinator
        context.coordinator.onSourceLineChange = onSourceLineChange
        if let scrollView = Self.findScrollView(in: webView) {
            // Keep a visible native scroller as a reliable fallback when trackpad or
            // mouse-wheel events are not reaching the embedded WebKit view.
            scrollView.hasVerticalScroller = true
            scrollView.autohidesScrollers = false
            scrollView.hasHorizontalScroller = false
            scrollView.verticalScrollElasticity = .automatic
            scrollView.contentView.postsBoundsChangedNotifications = true
            context.coordinator.observe(scrollView)
        }
        webView.underPageBackgroundColor = NSColor(Color(hex: readerBackgroundHex))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = pageHTML
        webView.underPageBackgroundColor = NSColor(Color(hex: readerBackgroundHex))
        context.coordinator.onSourceLineChange = onSourceLineChange
        let renderKey = html + "\n<!-- base:\(baseURL?.standardizedFileURL.path ?? "none") -->"
        if context.coordinator.lastRenderKey != renderKey {
            context.coordinator.lastRenderKey = renderKey
            context.coordinator.hasLoadedPage = false
            context.coordinator.pendingScrollID = nil
            context.coordinator.pendingSourceLine = sourceLineTarget
            webView.loadHTMLString(html, baseURL: baseURL)
        }
        if context.coordinator.requestedReaderWidth != readerWidth {
            context.coordinator.requestedReaderWidth = readerWidth
            context.coordinator.applyReaderWidthIfReady(in: webView)
        }
        if let scrollTarget, context.coordinator.lastScrollRequest != scrollRequest {
            context.coordinator.lastScrollRequest = scrollRequest
            context.coordinator.pendingScrollID = scrollTarget
            context.coordinator.scrollIfReady(in: webView)
        }
        if context.coordinator.lastSourceLineRequest != sourceLineRequest {
            context.coordinator.lastSourceLineRequest = sourceLineRequest
            context.coordinator.pendingSourceLine = sourceLineTarget
            context.coordinator.scrollToSourceLineIfReady(in: webView)
        }
    }

    private var pageHTML: String {
        let safeStrongColor = Self.safeHex(strongColorHex, fallback: "#A5563A")
        let safeBodyColor = Self.safeHex(bodyColorHex, fallback: "#282725")
        let safeBackgroundColor = Self.safeHex(readerBackgroundHex, fallback: "#FFFFFF")
        let safeStrongFamily = Self.cssFontFamily(strongFamily)
        var headingCSS = ""
        for style in headingStyles where (1...6).contains(style.id) {
            let family = Self.cssFontFamily(style.fontFamily)
            let color = Self.safeHex(style.colorHex, fallback: "#303030")
            headingCSS += "h\(style.id){font-family:\(family);font-size:\(Int(style.size))px;font-weight:\(style.bold ? 650 : 400);color:\(color)}\n"
        }
        let safeBodyFamily = Self.cssFontFamily(bodyFamily)
        let content = blocks.map(\.html).joined(separator: "\n")
        return """
        <!doctype html><html lang="zh-CN"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src file: data:; style-src 'unsafe-inline'; font-src 'none'; media-src file:;">
        <style>
        *{box-sizing:border-box}html{scroll-behavior:smooth;background:\(safeBackgroundColor)}body{margin:0;background:\(safeBackgroundColor);color:\(safeBodyColor);font-family:\(safeBodyFamily);font-size:\(Int(bodySize))px;line-height:\(String(format: "%.2f", lineHeight))}
        main{max-width:1116px;margin:0 auto;padding:38px 38px 100px;overflow-wrap:anywhere}
        h1,h2,h3,h4,h5,h6{line-height:1.4;letter-spacing:-.02em;scroll-margin-top:24px;margin-left:0;margin-right:0}
        h1{margin-top:6px;margin-bottom:16px}h2,h3,h4,h5,h6{margin-top:27px;margin-bottom:10px}
        h1,h2{padding-bottom:.18em;border-bottom:1px solid #E7E4E0}
        p{margin:9px 0 \(Int(paragraphSpacing))px}em,i{font-style:italic}strong{color:\(safeStrongColor);font-family:\(safeStrongFamily);font-size:\(Int(strongSize))px;font-weight:650}h1 strong,h2 strong,h3 strong,h4 strong,h5 strong,h6 strong{font-size:inherit}
        a{color:#5C708A;text-decoration:none}a:hover{text-decoration:underline}
        ul,ol{padding-left:1.55em;margin:10px 0 16px}li{padding-left:.18em;margin:4px 0}li>p{margin:3px 0}
        blockquote{margin:18px 0;padding:4px 0 4px 17px;border-left:2px solid #D9D4CD;color:#69655F}
        pre{overflow:auto;padding:15px 17px;border-radius:8px;background:#F4F2EF;line-height:1.55;font-size:13px}code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.9em}p code,li code{padding:2px 5px;border-radius:4px;background:#F1EFEC}
        table{border-collapse:collapse;width:100%;margin:16px 0;font-size:14px}th,td{padding:8px 11px;border:1px solid #E3E0DC;text-align:left}th{background:#F7F6F4;font-weight:600}
        hr{border:0;border-top:1px solid #E7E4E0;margin:24px 0}img{max-width:100%;height:auto;border-radius:5px}input[type=checkbox]{accent-color:#687D72}
        \(headingCSS)
        </style></head><body><main>\(content)</main></body></html>
        """
    }

    private static func findScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView { return scrollView }
        for child in view.subviews {
            if let scrollView = findScrollView(in: child) { return scrollView }
        }
        return nil
    }

    private static func safeHex(_ input: String, fallback: String) -> String {
        let candidate = input.hasPrefix("#") ? String(input.dropFirst()) : input
        guard candidate.count == 6, candidate.allSatisfy({ $0.isHexDigit }) else { return fallback }
        return "#" + candidate
    }

    private static func cssFontFamily(_ family: String) -> String {
        if family == "系统默认" { return "system-ui,-apple-system,BlinkMacSystemFont,sans-serif" }
        let safe = family.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: ";", with: "")
        return "'\(safe)',sans-serif"
    }

    @MainActor
    final class Coordinator: NSObject {
        var lastRenderKey: String?
        var lastScrollRequest = -1
        var lastSourceLineRequest = -1
        var pendingSourceLine: Int?
        var pendingScrollID: String?
        var hasLoadedPage = false
        var requestedReaderWidth = 720.0
        var onSourceLineChange: ((Int) -> Void)?
        weak var webView: WKWebView?
        private var lastReportedLine = 0
        private var scrollSampleSequence = 0
        private var scrollObserver: NSObjectProtocol?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            hasLoadedPage = true
            applyReaderWidthIfReady(in: webView)
            scrollIfReady(in: webView)
            scrollToSourceLineIfReady(in: webView)
        }

        func applyReaderWidthIfReady(in webView: WKWebView) {
            guard hasLoadedPage else { return }
            let maxWidth = Int(requestedReaderWidth) + 76
            webView.evaluateJavaScript("document.querySelector('main')?.style.setProperty('max-width', '\(maxWidth)px')")
        }

        func scrollIfReady(in webView: WKWebView) {
            guard hasLoadedPage, let id = pendingScrollID else { return }
            pendingScrollID = nil
            webView.evaluateJavaScript("document.getElementById('\(id)')?.scrollIntoView({behavior:'smooth',block:'start'})")
        }

        func scrollToSourceLineIfReady(in webView: WKWebView) {
            guard hasLoadedPage, let line = pendingSourceLine else { return }
            pendingSourceLine = nil
            webView.evaluateJavaScript("(()=>{const a=[...document.querySelectorAll('[data-source-line]')];const e=a.find(x=>Number(x.dataset.sourceLine)>=\(line))||a.at(-1);e?.scrollIntoView({behavior:'smooth',block:'start'})})()")
        }

        func observe(_ scrollView: NSScrollView) {
            if let scrollObserver { NotificationCenter.default.removeObserver(scrollObserver) }
            scrollObserver = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.contentView, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.reportVisibleSourceLine() }
            }
        }

        private func reportVisibleSourceLine() {
            guard hasLoadedPage, let webView else { return }
            scrollSampleSequence += 1
            let sample = scrollSampleSequence
            webView.evaluateJavaScript("(()=>{const a=[...document.querySelectorAll('[data-source-line]')];let e=a[0];for(const x of a){if(x.getBoundingClientRect().top<=40)e=x;else break}return Number(e?.dataset.sourceLine||1)})()") { [weak self] value, _ in
                guard let self, sample == self.scrollSampleSequence,
                      let line = value as? Int, line > 0, line != self.lastReportedLine else { return }
                self.lastReportedLine = line
                self.onSourceLineChange?(line)
            }
        }

    }
}

@MainActor
extension ReaderWebView.Coordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard navigationAction.navigationType == .linkActivated,
              let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        if ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
            NSWorkspace.shared.open(url)
        }
        decisionHandler(.cancel)
    }
}
