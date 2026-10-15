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
    let annotationFontSize: Double
    let annotationFontFamily: String
    let annotationTextColorHex: String
    let backgroundColorHex: String
    let lineHeight: Double
    let scrollFragment: String?
    let scrollRequest: Int
    let annotations: [EPUBAnnotation]
    let annotationJumpID: String?
    let annotationJumpRequest: Int
    let savedPosition: SavedReadingPosition?
    let positionRestoreRequest: Int
    let onActivate: () -> Void
    let onNavigateChapter: (Int) -> Void
    let onTextSelection: (EPUBTextAnchor?) -> Void
    let onEditAnnotation: (String) -> Void
    let onDeleteAnnotation: (String) -> Void
    let onReadPosition: (String, Double) -> Void
    let onBodyChange: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onBodyChange: onBodyChange) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: "epubBodyChanged")
        configuration.userContentController.add(context.coordinator, name: "epubSelectionChanged")
        configuration.userContentController.add(context.coordinator, name: "epubAnnotationEdit")
        configuration.userContentController.add(context.coordinator, name: "epubAnnotationDelete")
        configuration.userContentController.add(context.coordinator, name: "epubReadingPosition")
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
        webView.onActivate = onActivate
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
        context.coordinator.onEditAnnotation = onEditAnnotation
        context.coordinator.onDeleteAnnotation = onDeleteAnnotation
        context.coordinator.onReadPosition = onReadPosition
        context.coordinator.editable = editable
        (webView as? EPUBReaderWebView)?.onNavigateChapter = onNavigateChapter
        (webView as? EPUBReaderWebView)?.onActivate = onActivate
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
        context.coordinator.restorePosition(savedPosition, request: positionRestoreRequest, chapterHref: chapter.href)
        webView.evaluateJavaScript("document.body?.style.setProperty('max-width','\(Int(width))px')")
        webView.evaluateJavaScript(Self.typographyUpdateScript(bodySize: bodySize, bodyFamily: bodyFamily,
                                                                bodyColorHex: bodyColorHex,
                                                                backgroundColorHex: backgroundColorHex, lineHeight: lineHeight,
                                                                annotationFontSize: annotationFontSize,
                                                                annotationFontFamily: annotationFontFamily,
                                                                annotationTextColorHex: annotationTextColorHex))
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
            return node.parentElement?.closest('script,style,head,[data-mdstudio-annotation-id],[data-mdstudio-annotation-ui]')
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
        body *:not([data-mdstudio-annotation-ui]):not(.mdstudio-annotation-tip){font-family:inherit!important;color:inherit!important;line-height:inherit!important}
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
                                               backgroundColorHex: String, lineHeight: Double,
                                               annotationFontSize: Double, annotationFontFamily: String,
                                               annotationTextColorHex: String) -> String {
        let family = cssFontFamily(bodyFamily)
        let color = validHexColor(bodyColorHex) ? bodyColorHex : "#282725"
        let background = validHexColor(backgroundColorHex) ? backgroundColorHex : "#FFFFFF"
        let annotationColor = validHexColor(annotationTextColorHex) ? annotationTextColorHex : "#777777"
        let values = [family, color, background, cssFontFamily(annotationFontFamily), annotationColor]
        guard let data = try? JSONSerialization.data(withJSONObject: values, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else { return "" }
        return "(() => { const v=\(json); const b=document.body; if(!b)return; b.style.setProperty('--mdstudio-font-family',v[0]); b.style.setProperty('--mdstudio-font-size','\(bodySize)px'); b.style.setProperty('--mdstudio-line-height','\(lineHeight)'); b.style.setProperty('--mdstudio-text-color',v[1]); b.style.setProperty('--mdstudio-reader-background',v[2]); b.style.setProperty('--mdstudio-annotation-font-family',v[3]); b.style.setProperty('--mdstudio-annotation-font-size','\(annotationFontSize)px'); b.style.setProperty('--mdstudio-annotation-text-color',v[4]); document.documentElement.style.backgroundColor=v[2]; })()"
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
        var onEditAnnotation: (String) -> Void = { _ in }
        var onDeleteAnnotation: (String) -> Void = { _ in }
        var onReadPosition: (String, Double) -> Void = { _, _ in }
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
        var savedPosition: SavedReadingPosition?
        var positionRestoreRequest = -1
        var lastRestoredPositionRequest = -1
        weak var webView: WKWebView?
        init(onBodyChange: @escaping (String) -> Void) { self.onBodyChange = onBodyChange }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "epubAnnotationEdit", let id = message.body as? String {
                onEditAnnotation(id)
            } else if message.name == "epubAnnotationDelete", let id = message.body as? String {
                onDeleteAnnotation(id)
            } else if message.name == "epubBodyChanged" {
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
            } else if message.name == "epubReadingPosition",
                      let value = message.body as? [String: Any],
                      let href = value["href"] as? String,
                      let fraction = value["fraction"] as? Double {
                onReadPosition(href, min(1, max(0, fraction)))
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
            installReadingPositionTracking()
            restorePendingPosition()
            scrollToPendingFragment()
        }

        func restorePosition(_ position: SavedReadingPosition?, request: Int, chapterHref: String) {
            savedPosition = position
            positionRestoreRequest = request
            self.chapterHref = chapterHref
            restorePendingPosition()
        }

        private func restorePendingPosition() {
            guard hasLoadedPage, positionRestoreRequest != lastRestoredPositionRequest,
                  case .epub(let href, let fraction)? = savedPosition?.location, href == chapterHref,
                  fraction.isFinite else { return }
            lastRestoredPositionRequest = positionRestoreRequest
            let value = min(1, max(0, fraction))
            webView?.evaluateJavaScript("(() => { const h=Math.max(document.documentElement.scrollHeight,document.body?.scrollHeight||0)-window.innerHeight; window.scrollTo(0,Math.max(0,h)*\(value)); })()")
        }

        private func installReadingPositionTracking() {
            guard let data = try? JSONSerialization.data(withJSONObject: [chapterHref]),
                  let hrefJSON = String(data: data, encoding: .utf8) else { return }
            webView?.evaluateJavaScript("""
            (() => {
              const href=\(hrefJSON)[0]; let timer;
              const send=()=>{ clearTimeout(timer); timer=setTimeout(()=>{
                const h=Math.max(document.documentElement.scrollHeight,document.body?.scrollHeight||0)-window.innerHeight;
                window.webkit.messageHandlers.epubReadingPosition.postMessage({href,fraction:h>0?window.scrollY/h:0});
              },250); };
              window.removeEventListener('scroll',window.__mdstudioReadPosition);
              window.__mdstudioReadPosition=send;
              window.addEventListener('scroll',send,{passive:true}); send();
            })()
            """)
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
                webView?.evaluateJavaScript("document.querySelectorAll('[data-mdstudio-annotation-id]').forEach(mark=>{const parent=mark.parentNode;while(mark.firstChild)parent.insertBefore(mark.firstChild,mark);parent.removeChild(mark)});document.querySelectorAll('[data-mdstudio-annotation-ui]').forEach(node=>node.remove())")
                lastAnnotations = annotations
                lastAppliedEditable = true
                return
            }
            guard
                  let data = try? JSONSerialization.data(withJSONObject: annotations.map { item in
                      ["id": item.id, "href": item.chapterHref, "quote": item.anchor.quote,
                       "prefix": item.anchor.prefix, "suffix": item.anchor.suffix,
                       "note": item.note, "color": item.colorHex, "style": item.markStyle.rawValue]
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
              document.querySelectorAll('[data-mdstudio-annotation-ui]').forEach(node => node.remove());
              const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
                acceptNode(node) {
                  return node.parentElement?.closest('script,style,head,[data-mdstudio-annotation-id],[data-mdstudio-annotation-ui]')
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
                  mark.dataset.mdstudioAnnotationNote = candidate.item.note || candidate.item.quote;
                  mark.addEventListener('dblclick', event => {
                    event.preventDefault(); event.stopPropagation();
                    window.webkit.messageHandlers.epubAnnotationEdit.postMessage(candidate.item.id);
                  });
                  mark.style.cssText = candidate.item.style === 'underline'
                    ? 'background:transparent;border-radius:0;padding:0;color:inherit;text-decoration:underline;text-decoration-color:'+candidate.item.color+';text-decoration-thickness:2px;text-underline-offset:2px'
                    : 'background:'+candidate.item.color+';border-radius:2px;padding:0 1px;color:inherit';
                  mark.appendChild(range.extractContents()); range.insertNode(mark);
                  if (segment === segments[0]) {
                    const info = document.createElement('button');
                    info.type = 'button'; info.dataset.mdstudioAnnotationUi = 'true';
                    info.dataset.note = candidate.item.note || candidate.item.quote;
                    info.textContent = 'ⓘ'; info.setAttribute('aria-label','查看注释');
                    info.addEventListener('dblclick', event => {
                      event.preventDefault(); event.stopPropagation();
                      window.webkit.messageHandlers.epubAnnotationEdit.postMessage(candidate.item.id);
                    });
                    info.style.cssText = 'border:0;background:transparent;color:var(--mdstudio-annotation-text-color,#777);font:10px -apple-system,BlinkMacSystemFont,sans-serif;padding:0 2px;cursor:pointer;vertical-align:super';
                    mark.after(info);
                    if (candidate.item.note) {
                      const preview = document.createElement('span');
                      preview.dataset.mdstudioAnnotationUi = 'true';
                      preview.textContent = ' '+candidate.item.note;
                      preview.title = candidate.item.note;
                      preview.style.cssText = 'display:inline-block;max-width:220px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:var(--mdstudio-annotation-font-size,11px);font-family:var(--mdstudio-annotation-font-family,-apple-system),sans-serif;color:var(--mdstudio-annotation-text-color,#777);vertical-align:bottom';
                      info.after(preview);
                    }
                  }
                }
              }
              const openAnnotationPopup = (id, note, x, y) => {
                document.querySelectorAll('.mdstudio-annotation-tip').forEach(tip => tip.remove());
                const tip = document.createElement('div'); tip.className = 'mdstudio-annotation-tip';
                tip.dataset.mdstudioAnnotationUi = 'true';
                tip.style.cssText = 'position:absolute;z-index:99999;min-width:190px;max-width:300px;padding:10px;border:1px solid #bbb;border-radius:7px;background:#fff;color:var(--mdstudio-annotation-text-color,#222);box-shadow:0 3px 12px #0003;font-size:var(--mdstudio-annotation-font-size,11px);font-family:var(--mdstudio-annotation-font-family,-apple-system),sans-serif;white-space:normal';
                const text = document.createElement('div'); text.textContent = note || '（没有批注文字）';
                text.style.cssText = 'white-space:pre-wrap;overflow-wrap:anywhere;margin-bottom:9px;color:inherit;font:inherit';
                tip.appendChild(text);
                const actions = document.createElement('div'); actions.style.cssText = 'display:flex;justify-content:flex-end;gap:7px';
                for (const [label, action] of [['编辑','edit'],['删除','delete']]) {
                  const button = document.createElement('button'); button.type='button'; button.textContent=label;
                  button.dataset.annotationAction=action; button.dataset.annotationId=id; button.dataset.mdstudioAnnotationUi='true';
                  button.style.cssText = action==='delete' ? 'border:0;border-radius:4px;padding:4px 8px;background:#c43b32;color:white;cursor:pointer;font:inherit' : 'border:0;border-radius:4px;padding:4px 8px;background:#e8e8e8;color:#222;cursor:pointer;font:inherit';
                  actions.appendChild(button);
                }
                tip.appendChild(actions); document.body.appendChild(tip);
                tip.style.left=Math.max(8,Math.min(x+window.scrollX,window.innerWidth-tip.offsetWidth-8))+'px';
                tip.style.top=(y+window.scrollY+6)+'px';
              };
              document.onclick = event => {
                const target = event.target instanceof Element ? event.target : event.target?.parentElement;
                const actionButton = target?.closest('button[data-annotation-action]');
                if (actionButton) {
                  event.preventDefault(); event.stopPropagation();
                  const handler = actionButton.dataset.annotationAction === 'delete' ? 'epubAnnotationDelete' : 'epubAnnotationEdit';
                  window.webkit.messageHandlers[handler].postMessage(actionButton.dataset.annotationId);
                  actionButton.closest('.mdstudio-annotation-tip')?.remove();
                  return;
                }
                const info = target?.closest('button[data-mdstudio-annotation-ui]');
                document.querySelectorAll('.mdstudio-annotation-tip').forEach(tip => tip.remove());
                if (!info) return;
                event.preventDefault(); event.stopPropagation();
                const mark = info.previousElementSibling;
                const rect=info.getBoundingClientRect();
                openAnnotationPopup(mark?.dataset.mdstudioAnnotationId, info.dataset.note, rect.left, rect.bottom);
              };
              document.oncontextmenu = event => {
                const target = event.target instanceof Element ? event.target : event.target?.parentElement;
                const mark = target?.closest('mark[data-mdstudio-annotation-id]');
                if (!mark) return;
                event.preventDefault();
                openAnnotationPopup(mark.dataset.mdstudioAnnotationId, mark.dataset.mdstudioAnnotationNote,
                                    event.pageX-window.scrollX, event.pageY-window.scrollY);
              };
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
    var onActivate: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onActivate?()
        super.mouseDown(with: event)
    }

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

struct EPUBArrowKeyMonitor: NSViewRepresentable {
    let isEnabled: Bool
    let onNavigateChapter: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.installIfNeeded()
        context.coordinator.update(isEnabled: isEnabled, onNavigateChapter: onNavigateChapter)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.installIfNeeded()
        context.coordinator.update(isEnabled: isEnabled, onNavigateChapter: onNavigateChapter)
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    @MainActor
    final class Coordinator {
        private var monitor: Any?
        private var isEnabled = false
        private var onNavigateChapter: (Int) -> Void = { _ in }

        func update(isEnabled: Bool, onNavigateChapter: @escaping (Int) -> Void) {
            self.isEnabled = isEnabled
            self.onNavigateChapter = onNavigateChapter
        }

        func installIfNeeded() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isEnabled, NSApp.isActive,
                      event.window != nil, event.window === NSApp.keyWindow,
                      event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty else {
                    return event
                }
                switch event.keyCode {
                case 123:
                    self.onNavigateChapter(-1)
                    return nil
                case 124:
                    self.onNavigateChapter(1)
                    return nil
                default:
                    return event
                }
            }
        }

        func removeMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
