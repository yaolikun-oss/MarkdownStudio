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
    let annotations: [EPUBAnnotation]
    let annotationJumpID: String?
    let annotationJumpRequest: Int
    let onNavigateChapter: (Int) -> Void
    let onTextSelection: (EPUBTextAnchor?) -> Void
    let onBodyChange: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onBodyChange: onBodyChange) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: "epubBodyChanged")
        configuration.userContentController.add(context.coordinator, name: "epubSelectionChanged")
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
        let selectionScript = WKUserScript(source: Self.selectionScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(selectionScript)
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
        context.coordinator.onTextSelection = onTextSelection
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
            context.coordinator.lastAnnotations = nil
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
        context.coordinator.setAnnotations(annotations, jumpID: annotationJumpID,
                                          jumpRequest: annotationJumpRequest, chapterHref: chapter.href)
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

    private static let selectionScript = """
    (() => {
      const collect = () => {
        const selection = window.getSelection();
        if (!selection || selection.isCollapsed || !selection.rangeCount) {
          window.webkit.messageHandlers.epubSelectionChanged.postMessage(null);
          return;
        }
        const range = selection.getRangeAt(0);
        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
          acceptNode(node) {
            return node.parentElement?.closest('script,style,head,[data-mdstudio-annotation-id]')
              ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
          }
        });
        const nodes = []; let text = ''; let node;
        while ((node = walker.nextNode())) { nodes.push({node, start:text.length}); text += node.nodeValue || ''; }
        const offsetOf = (target, offset) => {
          const item = nodes.find(entry => entry.node === target);
          return item ? item.start + offset : -1;
        };
        let start = offsetOf(range.startContainer, range.startOffset);
        let end = offsetOf(range.endContainer, range.endOffset);
        if (start < 0 || end <= start) {
          window.webkit.messageHandlers.epubSelectionChanged.postMessage(null); return;
        }
        let quote = text.slice(start, end);
        const leading = quote.length - quote.trimStart().length;
        quote = quote.trim(); start += leading;
        if (!quote) { window.webkit.messageHandlers.epubSelectionChanged.postMessage(null); return; }
        window.webkit.messageHandlers.epubSelectionChanged.postMessage({
          quote,
          prefix: text.slice(Math.max(0, start - 48), start),
          suffix: text.slice(start + quote.length, start + quote.length + 48)
        });
      };
      let timer;
      const schedule = () => { clearTimeout(timer); timer = setTimeout(collect, 90); };
      document.addEventListener('mouseup', schedule);
      document.addEventListener('keyup', schedule);
      document.addEventListener('selectionchange', schedule);
    })();
    """

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
        var onTextSelection: (EPUBTextAnchor?) -> Void = { _ in }
        var renderKey: String?
        var editable = false
        var pendingFragment: String?
        var lastScrollRequest = -1
        var hasLoadedPage = false
        var pendingPreviewURL: URL?
        var activePreviewURL: URL?
        var annotations: [EPUBAnnotation] = []
        var lastAnnotations: [EPUBAnnotation]?
        var lastAppliedEditable: Bool?
        var annotationJumpID: String?
        var annotationJumpRequest = -1
        var chapterHref = ""
        weak var webView: WKWebView?
        init(onBodyChange: @escaping (String) -> Void) { self.onBodyChange = onBodyChange }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "epubBodyChanged" {
                guard editable, let body = message.body as? String else { return }
                onBodyChange(body)
            } else if message.name == "epubSelectionChanged" {
                guard !editable else { onTextSelection(nil); return }
                guard let value = message.body as? [String: String],
                      let quote = value["quote"], !quote.isEmpty else {
                    onTextSelection(nil)
                    return
                }
                onTextSelection(EPUBTextAnchor(quote: quote, prefix: value["prefix"] ?? "",
                                               suffix: value["suffix"] ?? ""))
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            hasLoadedPage = true
            if let oldPreview = activePreviewURL, oldPreview != pendingPreviewURL {
                try? FileManager.default.removeItem(at: oldPreview)
            }
            activePreviewURL = pendingPreviewURL
            pendingPreviewURL = nil
            webView.evaluateJavaScript("if(document.body) document.body.contentEditable = '\(editable ? "true" : "false")'")
            lastAnnotations = nil
            applyAnnotations()
            scrollToPendingFragment()
        }

        func setAnnotations(_ value: [EPUBAnnotation], jumpID: String?, jumpRequest: Int, chapterHref: String) {
            let changed = lastAnnotations != value || annotationJumpRequest != jumpRequest ||
                self.chapterHref != chapterHref || lastAppliedEditable != editable
            annotations = value
            annotationJumpID = jumpID
            annotationJumpRequest = jumpRequest
            self.chapterHref = chapterHref
            if changed { applyAnnotations() }
        }

        func applyAnnotations() {
            guard hasLoadedPage else { return }
            if editable {
                webView?.evaluateJavaScript("document.querySelectorAll('[data-mdstudio-annotation-id]').forEach(mark=>{const parent=mark.parentNode;while(mark.firstChild)parent.insertBefore(mark.firstChild,mark);parent.removeChild(mark)})")
                lastAnnotations = annotations
                lastAppliedEditable = true
                return
            }
            guard
                  let data = try? JSONSerialization.data(withJSONObject: annotations.map { item in
                      ["id": item.id, "href": item.chapterHref, "quote": item.anchor.quote,
                       "prefix": item.anchor.prefix, "suffix": item.anchor.suffix,
                       "note": item.note, "color": item.colorHex]
                  }, options: [.fragmentsAllowed]),
                  let json = String(data: data, encoding: .utf8),
                  let jumpData = try? JSONSerialization.data(withJSONObject: annotationJumpID ?? NSNull(), options: [.fragmentsAllowed]),
                  let jumpJSON = String(data: jumpData, encoding: .utf8) else { return }
            lastAnnotations = annotations
            lastAppliedEditable = false
            let currentHref = (try? JSONSerialization.data(withJSONObject: [chapterHref], options: [.fragmentsAllowed]))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
            webView?.evaluateJavaScript("""
            (() => {
              const items = \(json), href = (\(currentHref))[0], jumpID = \(jumpJSON);
              document.querySelectorAll('[data-mdstudio-annotation-id]').forEach(mark => {
                const parent = mark.parentNode;
                while (mark.firstChild) parent.insertBefore(mark.firstChild, mark);
                parent.removeChild(mark);
              });
              const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
                acceptNode(node) {
                  return node.parentElement?.closest('script,style,head,[data-mdstudio-annotation-id]')
                    ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
                }
              });
              const nodes = []; let full = ''; let node;
              while ((node = walker.nextNode())) { nodes.push({node, start:full.length}); full += node.nodeValue || ''; }
              const candidates = [];
              for (const item of items.filter(a => a.href === href && a.quote)) {
                let best = -1, bestScore = -1;
                for (let at = full.indexOf(item.quote); at >= 0; at = full.indexOf(item.quote, at + 1)) {
                  const before = full.slice(Math.max(0, at - item.prefix.length), at);
                  const after = full.slice(at + item.quote.length, at + item.quote.length + item.suffix.length);
                  let score = 0;
                  for (let i=1; i<=Math.min(before.length,item.prefix.length); i++) {
                    if (before.slice(-i) === item.prefix.slice(-i)) score = i; else break;
                  }
                  for (let i=1; i<=Math.min(after.length,item.suffix.length); i++) {
                    if (after.slice(0,i) === item.suffix.slice(0,i)) score += i; else break;
                  }
                  if (score > bestScore) { best=at; bestScore=score; }
                }
                if (best >= 0) candidates.push({item,start:best,end:best+item.quote.length});
              }
              candidates.sort((a,b) => b.start-a.start);
              for (const candidate of candidates) {
                const segments = nodes.map(entry => {
                  const from = Math.max(candidate.start, entry.start);
                  const to = Math.min(candidate.end, entry.start + entry.node.length);
                  return to > from ? {node:entry.node, from:from-entry.start, to:to-entry.start} : null;
                }).filter(Boolean).reverse();
                for (const segment of segments) {
                  const range = document.createRange();
                  range.setStart(segment.node,segment.from); range.setEnd(segment.node,segment.to);
                  const mark = document.createElement('mark');
                  mark.dataset.mdstudioAnnotationId = candidate.item.id;
                  mark.title = candidate.item.note || candidate.item.quote;
                  mark.style.cssText = 'background:'+candidate.item.color+';border-radius:2px;padding:0 1px;color:inherit';
                  mark.appendChild(range.extractContents()); range.insertNode(mark);
                }
              }
              if (jumpID) document.querySelector('[data-mdstudio-annotation-id="'+jumpID+'"]')?.scrollIntoView({block:'center',behavior:'smooth'});
            })()
            """)
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
