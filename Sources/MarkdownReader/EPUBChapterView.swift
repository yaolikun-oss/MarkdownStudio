import EPUBCore
import AppKit
import SwiftUI
import WebKit

struct EPUBChapterView: NSViewRepresentable {
    let chapter: EPUBChapter
    let resourceRoot: URL
    let editable: Bool
    let width: Double
    let bodySize: Double
    let bodyFamily: String
    let bodyColorHex: String
    let backgroundColorHex: String
    let lineHeight: Double
    let scrollFragment: String?
    let scrollRequest: Int
    let onNavigateChapter: (Int) -> Void
    let onBodyChange: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onBodyChange: onBodyChange) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: "epubBodyChanged")
        let editorScript = WKUserScript(source: """
        (() => {
          const enable = () => {
            if (!document.body) return;
            document.body.contentEditable = 'false';
            document.body.addEventListener('input', () => {
              window.webkit.messageHandlers.epubBodyChanged.postMessage(document.body.innerHTML);
            });
          };
          if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', enable, {once:true});
          else enable();
        })();
        """, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(editorScript)
        let webView = EPUBReaderWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        webView.onNavigateChapter = onNavigateChapter
        webView.underPageBackgroundColor = NSColor.textBackgroundColor
        if let scroll = Self.findScrollView(in: webView) {
            scroll.hasVerticalScroller = true
            scroll.autohidesScrollers = false
            scroll.hasHorizontalScroller = false
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onBodyChange = onBodyChange
        context.coordinator.editable = editable
        (webView as? EPUBReaderWebView)?.onNavigateChapter = onNavigateChapter
        (webView as? EPUBReaderWebView)?.allowsChapterNavigation = !editable
        webView.underPageBackgroundColor = NSColor(Color(hex: backgroundColorHex))
        let html = Self.readerHTML(chapter: chapter, width: width, bodySize: bodySize,
                                   bodyFamily: bodyFamily, bodyColorHex: bodyColorHex,
                                   backgroundColorHex: backgroundColorHex, lineHeight: lineHeight)
        let renderKey = chapter.fileURL.path
        if context.coordinator.renderKey != renderKey {
            context.coordinator.renderKey = renderKey
            context.coordinator.hasLoadedPage = false
            let previewURL = chapter.fileURL.deletingLastPathComponent()
                .appendingPathComponent(".mdstudio-preview-\(UUID().uuidString).html")
            do {
                try Data(html.utf8).write(to: previewURL, options: .atomic)
                context.coordinator.pendingPreviewURL = previewURL
                webView.loadFileURL(previewURL, allowingReadAccessTo: resourceRoot)
            } catch {
                webView.loadHTMLString(html, baseURL: chapter.fileURL.deletingLastPathComponent())
            }
        }
        context.coordinator.editable = editable
        webView.evaluateJavaScript("document.body?.style.setProperty('max-width','\(Int(width))px')")
        webView.evaluateJavaScript(Self.typographyUpdateScript(bodySize: bodySize, bodyFamily: bodyFamily,
                                                                bodyColorHex: bodyColorHex,
                                                                backgroundColorHex: backgroundColorHex, lineHeight: lineHeight))
        webView.evaluateJavaScript("if(document.body) document.body.contentEditable = '\(editable ? "true" : "false")'")
        if context.coordinator.lastScrollRequest != scrollRequest {
            context.coordinator.lastScrollRequest = scrollRequest
            context.coordinator.pendingFragment = scrollFragment
            context.coordinator.scrollToPendingFragment()
        }
    }

    private static func readerHTML(chapter: EPUBChapter, width: Double, bodySize: Double,
                                   bodyFamily: String, bodyColorHex: String,
                                   backgroundColorHex: String, lineHeight: Double) -> String {
        let source = (try? String(contentsOf: chapter.fileURL, encoding: .utf8)) ?? "<html><body></body></html>"
        let safe = sanitize(source)
        let csp = "<meta charset=\"utf-8\"><meta http-equiv=\"Content-Security-Policy\" content=\"default-src file: data:; img-src file: data:; style-src file: 'unsafe-inline'; font-src file: data:; media-src file: data:; connect-src 'none'; frame-src 'none'; object-src 'none'; script-src 'none'\">"
        let family = cssFontFamily(bodyFamily)
        let color = validHexColor(bodyColorHex) ? bodyColorHex : "#282725"
        let background = validHexColor(backgroundColorHex) ? backgroundColorHex : "#FFFFFF"
        let css = """
        <style id="mdstudio-reader-style">
        html{scroll-behavior:smooth;background:var(--mdstudio-reader-background,\(background))!important}body{max-width:\(Int(width))px;margin:0 auto!important;padding:40px 38px 100px!important;box-sizing:border-box;overflow-wrap:anywhere;background:var(--mdstudio-reader-background,\(background))!important;font-family:var(--mdstudio-font-family,\(family))!important;font-size:var(--mdstudio-font-size,\(bodySize)px)!important;line-height:var(--mdstudio-line-height,\(lineHeight))!important;color:var(--mdstudio-text-color,\(color))!important}
        body *{font-family:inherit!important;color:inherit!important;line-height:inherit!important}
        body h1{font-size:1.8em!important}body h2{font-size:1.6em!important}body h3{font-size:1.4em!important}body h4{font-size:1.2em!important}body h5{font-size:1.1em!important}body h6{font-size:1em!important}
        img,svg,video{max-width:100%;height:auto}table{max-width:100%}body[contenteditable=true]{outline:none;caret-color:#118AB2}
        </style>
        """
        if let range = safe.range(of: "</head>", options: .caseInsensitive) {
            var html = safe
            html.replaceSubrange(range, with: csp + css + "</head>")
            return html
        }
        return "<!doctype html><html><head><meta charset=\"utf-8\">\(csp)\(css)</head><body>\(safe)</body></html>"
    }

    private static func typographyUpdateScript(bodySize: Double, bodyFamily: String, bodyColorHex: String,
                                               backgroundColorHex: String, lineHeight: Double) -> String {
        let family = cssFontFamily(bodyFamily)
        let color = validHexColor(bodyColorHex) ? bodyColorHex : "#282725"
        let background = validHexColor(backgroundColorHex) ? backgroundColorHex : "#FFFFFF"
        let values = [family, color, background]
        guard let data = try? JSONSerialization.data(withJSONObject: values, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else { return "" }
        return "(() => { const v=\(json); const b=document.body; if(!b)return; b.style.setProperty('--mdstudio-font-family',v[0]); b.style.setProperty('--mdstudio-font-size','\(bodySize)px'); b.style.setProperty('--mdstudio-line-height','\(lineHeight)'); b.style.setProperty('--mdstudio-text-color',v[1]); b.style.setProperty('--mdstudio-reader-background',v[2]); document.documentElement.style.backgroundColor=v[2]; })()"
    }

    private static func cssFontFamily(_ value: String) -> String {
        if value == "系统默认" { return "-apple-system, BlinkMacSystemFont, sans-serif" }
        let safe = value.replacingOccurrences(of: "\\", with: "").replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "'", with: "")
        return "'\(safe)', -apple-system, sans-serif"
    }

    private static func validHexColor(_ value: String) -> Bool {
        value.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil
    }

    private static func sanitize(_ html: String) -> String {
        var result = html
        let removals = [
            "(?is)<script\\b[^>]*>.*?</script\\s*>",
            "(?is)<iframe\\b[^>]*>.*?</iframe\\s*>",
            "(?is)<object\\b[^>]*>.*?</object\\s*>",
            "(?is)<embed\\b[^>]*/?>"
        ]
        for pattern in removals {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
            }
        }
        if let events = try? NSRegularExpression(pattern: "(?is)\\s+on[a-z]+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)") {
            result = events.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        if let javascript = try? NSRegularExpression(pattern: "(?i)javascript:") {
            result = javascript.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "about:blank#blocked:")
        }
        return result
    }

    private static func findScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView { return scrollView }
        for child in view.subviews { if let found = findScrollView(in: child) { return found } }
        return nil
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var onBodyChange: (String) -> Void
        var renderKey: String?
        var editable = false
        var pendingFragment: String?
        var lastScrollRequest = -1
        var hasLoadedPage = false
        var pendingPreviewURL: URL?
        var activePreviewURL: URL?
        weak var webView: WKWebView?
        init(onBodyChange: @escaping (String) -> Void) { self.onBodyChange = onBodyChange }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard editable, let body = message.body as? String else { return }
            onBodyChange(body)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            hasLoadedPage = true
            if let oldPreview = activePreviewURL, oldPreview != pendingPreviewURL {
                try? FileManager.default.removeItem(at: oldPreview)
            }
            activePreviewURL = pendingPreviewURL
            pendingPreviewURL = nil
            webView.evaluateJavaScript("if(document.body) document.body.contentEditable = '\(editable ? "true" : "false")'")
            scrollToPendingFragment()
        }

        func scrollToPendingFragment() {
            guard hasLoadedPage, let fragment = pendingFragment,
                  let data = try? JSONSerialization.data(withJSONObject: [fragment], options: [.fragmentsAllowed]),
                  let json = String(data: data, encoding: .utf8) else { return }
            pendingFragment = nil
            webView?.evaluateJavaScript("(()=>{const id=(\(json))[0];document.getElementById(id)?.scrollIntoView({block:'start',behavior:'smooth'})})()")
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url else {
                decisionHandler(.allow); return
            }
            if ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") { NSWorkspace.shared.open(url) }
            decisionHandler(.cancel)
        }
    }
}

private final class EPUBReaderWebView: WKWebView {
    var allowsChapterNavigation = false
    var onNavigateChapter: ((Int) -> Void)?

    override func keyDown(with event: NSEvent) {
        let navigationModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        guard allowsChapterNavigation, event.modifierFlags.intersection(navigationModifiers).isEmpty else {
            super.keyDown(with: event)
            return
        }
        switch event.keyCode {
        case 123:
            onNavigateChapter?(-1)
        case 124:
            onNavigateChapter?(1)
        default:
            super.keyDown(with: event)
        }
    }
}
