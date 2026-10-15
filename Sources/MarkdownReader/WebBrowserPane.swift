import AppKit
import EPUBCore
import SwiftUI
import WebKit

struct WebPageHeading: Identifiable, Equatable {
    let id: String
    let title: String
    let level: Int
    let index: Int
}

struct WebPageClip: Equatable {
    let markdown: String
    let headingPath: [String]
}

enum WebClipFormatter {
    static func append(_ clip: WebPageClip, title: String, url: URL, to source: String) -> String {
        let label = escapeLinkLabel(title.replacingOccurrences(of: "\n", with: " "))
        let destination = url.absoluteString.replacingOccurrences(of: ">", with: "%3E")
        let sourceLine = "> 来源：[\(label)](<\(destination)>)"
        let path = clip.headingPath.map { $0.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: ">", with: "\\>") }
        let locationLine = path.isEmpty ? nil : "> 页面位置：\(path.joined(separator: " / "))"
        let citation = ([sourceLine] + (locationLine.map { [$0] } ?? [])).joined(separator: "\n")
        let prefix = source.isEmpty || source.hasSuffix("\n\n") ? "" : source.hasSuffix("\n") ? "\n" : "\n\n"
        let content = clip.markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        return source + prefix + citation + "\n\n" + content + "\n"
    }

    private static func escapeLinkLabel(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
    }
}

@MainActor
final class WebBrowserSession: ObservableObject {
    @Published var currentURL: URL?
    @Published var title = "网页阅读"
    @Published var headings: [WebPageHeading] = []
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var pageError: String?

    // Keep one browser view across SwiftUI layout swaps so history and scroll
    // position survive changes to the Markdown notebook panes.
    var webView: WKWebView?

    func open(_ url: URL) {
        guard Self.isWebURL(url) else { return }
        if currentURL == url, webView != nil { webView?.reload(); return }
        pageError = nil
        currentURL = url
    }

    func close() {
        webView?.stopLoading()
        webView = nil
        currentURL = nil
        title = "网页阅读"
        headings = []
        canGoBack = false
        canGoForward = false
        pageError = nil
    }

    func attach(_ webView: WKWebView) {
        self.webView = webView
    }

    func navigate(address: String) -> URL? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        if let url = URL(string: candidate), Self.isWebURL(url),
           let host = url.host, (trimmed.contains("://") || host.contains(".") || host == "localhost") { return url }
        var components = URLComponents(string: "https://duckduckgo.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: trimmed)]
        return components?.url
    }

    static func isWebURL(_ url: URL) -> Bool {
        ["http", "https"].contains(url.scheme?.lowercased() ?? "") && url.host != nil
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
    func stop() { webView?.stopLoading() }

    func navigate(to heading: WebPageHeading) {
        guard let webView else { return }
        func json(_ value: Any) -> String {
            let data = (try? JSONSerialization.data(withJSONObject: [value])) ?? Data("[null]".utf8)
            return String(data: data, encoding: .utf8).map { String($0.dropFirst().dropLast()) } ?? "null"
        }
        let script = """
        (()=>{
          const id=\(json(heading.id)), title=\(json(heading.title)), index=\(heading.index);
          const heads=[...document.querySelectorAll('h1,h2,h3,h4,h5,h6,[role="heading"][aria-level]')];
          const label=h=>(h?.innerText||h?.textContent||'').trim();
          let target=document.getElementById(id);
          if(!target || label(target)!==title) target=heads[index];
          if(!target || label(target)!==title) target=heads.find(h=>label(h)===title);
          if(!target) return false;
          const root=document.scrollingElement;
          const previous=root?.style.scrollBehavior;
          if(root) root.style.scrollBehavior='auto';
          target.scrollIntoView({behavior:'instant',block:'start'});
          if(root) requestAnimationFrame(()=>{root.style.scrollBehavior=previous});
          return true;
        })()
        """
        webView.evaluateJavaScript(script) { [weak self, weak webView] result, _ in
            guard result as? Bool != true, let self, let webView else { return }
            self.refreshPageState(in: webView)
        }
    }

    func captureSelection(completion: @escaping (WebPageClip?) -> Void) {
        guard let webView else { completion(nil); return }
        webView.evaluateJavaScript(Self.selectionScript) { result, _ in
            guard let value = result as? [String: Any],
                  let markdown = value["markdown"] as? String,
                  !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                completion(nil)
                return
            }
            completion(WebPageClip(markdown: markdown,
                                   headingPath: value["headingPath"] as? [String] ?? []))
        }
    }

    func refreshPageState(in webView: WKWebView) {
        currentURL = webView.url ?? currentURL
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        let script = """
        (()=>{
          const heads=[...document.querySelectorAll('h1,h2,h3,h4,h5,h6,[role="heading"][aria-level]')];
          return {title:document.title||location.hostname,headings:heads.map((h,index)=>{
            if(!h.id) h.id='markdown-studio-heading-'+index;
            const level=/^H[1-6]$/.test(h.tagName)?Number(h.tagName.slice(1)):Math.min(6,Math.max(1,Number(h.getAttribute('aria-level'))||2));
            return {id:h.id,title:(h.innerText||h.textContent||'').trim(),level,index};
          }).filter(x=>x.title)};
        })()
        """
        webView.evaluateJavaScript(script) { [weak self] result, _ in
            guard let self, let value = result as? [String: Any] else { return }
            if let pageTitle = value["title"] as? String, !pageTitle.isEmpty { self.title = pageTitle }
            if let items = value["headings"] as? [[String: Any]] {
                self.headings = items.compactMap { item in
                    guard let id = item["id"] as? String, let title = item["title"] as? String,
                          let level = item["level"] as? Int, let index = item["index"] as? Int else { return nil }
                    return WebPageHeading(id: id, title: title, level: level, index: index)
                }
            }
        }
    }

    func setZoom(_ percent: Double) { webView?.pageZoom = min(2, max(0.5, percent / 100)) }

    static let selectionScript = #"""
    (()=>{
      const sel=window.getSelection(); if(!sel||sel.isCollapsed)return {markdown:''};
      const range=sel.getRangeAt(0), fragment=range.cloneContents();
      const blocks=new Set(['P','DIV','SECTION','ARTICLE','MAIN','HEADER','FOOTER','ASIDE']);
      const escURL=s=>String(s||'').replace(/\s/g,'%20').replace(/\)/g,'%29');
      function render(n){
        if(n.nodeType===Node.TEXT_NODE)return n.nodeValue||'';
        if(n.nodeType!==Node.ELEMENT_NODE&&n.nodeType!==Node.DOCUMENT_FRAGMENT_NODE)return '';
        const tag=n.tagName||'', children=[...n.childNodes].map(render).join('');
        const headingLevel=/^H[1-6]$/.test(tag)?Number(tag[1]):(n.nodeType===Node.ELEMENT_NODE&&n.getAttribute('role')==='heading'?Math.min(6,Math.max(1,Number(n.getAttribute('aria-level'))||2)):0);
        if(headingLevel)return '\n\n'+'#'.repeat(headingLevel)+' '+children.trim()+'\n\n';
        if(tag==='BR')return '\n';
        if(tag==='STRONG'||tag==='B')return '**'+children.trim()+'**';
        if(tag==='EM'||tag==='I')return '*'+children.trim()+'*';
        if(tag==='U')return '<u>'+children.trim()+'</u>';
        if(tag==='S'||tag==='DEL'||tag==='STRIKE')return '~~'+children.trim()+'~~';
        if(tag==='CODE'&&n.parentElement?.tagName!=='PRE')return '`'+children.replace(/`/g,'\\`')+'`';
        if(tag==='PRE')return '\n\n```\n'+(n.innerText||n.textContent||'').replace(/^\n+|\n+$/g,'')+'\n```\n\n';
        if(tag==='A'){const href=escURL(n.href||n.getAttribute('href'));return '['+children.trim()+']('+href+')';}
        if(tag==='LI')return children.trim().split('\n').map((line,i)=>(i?'  ':'- ')+line).join('\n')+'\n';
        if(tag==='UL')return '\n'+children+'\n';
        if(tag==='OL'){
          let i=Number(n.getAttribute('start')||1);
          return '\n'+[...n.children].filter(x=>x.tagName==='LI').map(li=>`${i++}. ${[...li.childNodes].map(render).join('').trim().replace(/\n/g,'\n   ')}`).join('\n')+'\n\n';
        }
        if(tag==='BLOCKQUOTE')return '\n\n'+children.trim().split('\n').map(x=>'> '+x).join('\n')+'\n\n';
        if(tag==='HR')return '\n\n---\n\n';
        if(tag==='TABLE'){
          const rows=[...n.querySelectorAll('tr')].map(tr=>[...tr.querySelectorAll('th,td')].map(c=>(c.innerText||c.textContent||'').trim().replace(/\|/g,'\\|')));
          if(!rows.length)return '';
          const width=Math.max(...rows.map(r=>r.length));
          const line=row=>'| '+Array.from({length:width},(_,i)=>row[i]||'').join(' | ')+' |';
          return '\n\n'+line(rows[0])+'\n'+line(Array(width).fill('---'))+'\n'+rows.slice(1).map(line).join('\n')+'\n\n';
        }
        if(blocks.has(tag))return '\n\n'+children.trim()+'\n\n';
        return children;
      }
      const headingNodes=[...document.querySelectorAll('h1,h2,h3,h4,h5,h6,[role="heading"][aria-level]')];
      const prior=headingNodes.filter(h=>range.comparePoint(h,0)<0);
      const stack=[];
      for(const h of prior){const level=/^H[1-6]$/.test(h.tagName)?Number(h.tagName[1]):Math.min(6,Math.max(1,Number(h.getAttribute('aria-level'))||2));while(stack.length&&stack[stack.length-1].level>=level)stack.pop();stack.push({level,title:(h.innerText||h.textContent||'').trim()});}
      return {markdown:render(fragment).replace(/\n{3,}/g,'\n\n').trim(),headingPath:stack.map(x=>x.title)};
    })()
    """#
}

struct WebBrowserPane: View {
    @ObservedObject var session: WebBrowserSession
    let zoomPercent: Double
    let isBookmarked: Bool
    let onBookmark: () -> Void
    let onClip: (WebPageClip) -> Void
    let onActivate: () -> Void
    @State private var address = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Button { session.goBack() } label: { Image(systemName: "chevron.left") }
                    .frame(width: 28, height: 26).contentShape(Rectangle())
                    .disabled(!session.canGoBack).help("后退（⌘[）").toolbarHint("网页后退 · ⌘[")
                Button { session.goForward() } label: { Image(systemName: "chevron.right") }
                    .frame(width: 28, height: 26).contentShape(Rectangle())
                    .disabled(!session.canGoForward).help("前进（⌘]）").toolbarHint("网页前进 · ⌘]")
                Button { session.isLoading ? session.stop() : session.reload() } label: {
                    Image(systemName: session.isLoading ? "xmark" : "arrow.clockwise")
                }.frame(width: 28, height: 26).contentShape(Rectangle())
                    .help(session.isLoading ? "停止加载" : "重新载入")
                    .toolbarHint(session.isLoading ? "停止加载网页" : "重新载入网页")
                TextField("输入网页地址或搜索文字", text: $address)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { if let url = session.navigate(address: address) { session.open(url) } }
                    .help("输入网址或搜索词，按回车打开")
                if session.currentURL != nil {
                    Button(action: onBookmark) {
                        Image(systemName: isBookmarked ? "star.fill" : "star")
                            .foregroundStyle(isBookmarked ? Color.orange : Color.secondary)
                            .frame(width: 28, height: 26).contentShape(Rectangle())
                    }.buttonStyle(.plain).help(isBookmarked ? "编辑网页收藏" : "收藏当前网页")
                        .toolbarHint("收藏网页并编辑备注 · ⌥⌘B")
                    Button {
                        session.captureSelection { if let clip = $0 { onClip(clip) } }
                    } label: { Image(systemName: "text.badge.plus").frame(width: 28, height: 26).contentShape(Rectangle()) }
                        .buttonStyle(.plain).help("将选中文字剪藏到 Markdown 笔记")
                        .toolbarHint("剪藏选中文字到 Markdown · ⌃⌘C")
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .padding(.horizontal, 8).frame(height: 34)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.78))
            .overlay(alignment: .bottom) { Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1) }
            WebPageView(session: session, zoomPercent: zoomPercent, onActivate: onActivate)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if let pageError = session.pageError {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.secondary)
                            Text("网页无法载入").font(.system(size: 14, weight: .medium))
                            Text(pageError).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(3)
                            Button("重新载入") { session.reload() }.buttonStyle(.bordered)
                        }.padding(18).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    } else if session.currentURL == nil {
                        VStack(spacing: 10) {
                            Image(systemName: "globe").font(.system(size: 34, weight: .ultraLight)).foregroundStyle(.tertiary)
                            Text("打开网页开始阅读").font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary)
                            Text("仅提供基础网页阅读、收藏与选区剪藏").font(.system(size: 11)).foregroundStyle(.tertiary)
                        }
                    }
                }
        }
        .onChange(of: session.currentURL) { _, value in if let value { address = value.absoluteString } }
        .onAppear { if let currentURL = session.currentURL { address = currentURL.absoluteString } }
    }
}

struct WebAddressSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var address: String
    let onOpen: (URL) -> Void

    init(initialAddress: String = "", onOpen: @escaping (URL) -> Void) {
        _address = State(initialValue: initialAddress)
        self.onOpen = onOpen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("打开网页").font(.headline)
            TextField("网页地址或搜索文字", text: $address).textFieldStyle(.roundedBorder)
                .onSubmit(submit)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("打开") { submit() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 420)
    }

    private func submit() {
        let session = WebBrowserSession()
        guard let url = session.navigate(address: address) else { return }
        onOpen(url)
        dismiss()
    }
}

struct WebBookmarkEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bookmark: WebBookmark
    let onSave: (WebBookmark) -> Void

    init(bookmark: WebBookmark, onSave: @escaping (WebBookmark) -> Void) {
        _bookmark = State(initialValue: bookmark)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("网页收藏").font(.headline)
            TextField("名称", text: $bookmark.title).textFieldStyle(.roundedBorder)
            TextField("网址", text: $bookmark.urlString).textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
            Text("备注").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            TextEditor(text: $bookmark.note).font(.system(size: 13)).frame(minHeight: 90)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.12)))
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    bookmark.title = bookmark.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    bookmark.updatedAt = Date()
                    onSave(bookmark)
                    dismiss()
                }.keyboardShortcut(.defaultAction)
                    .disabled(bookmark.title.isEmpty || !WebBrowserSession.isWebURL(URL(string: bookmark.urlString) ?? URL(fileURLWithPath: "/")))
            }
        }
        .padding(20).frame(width: 460, height: 320)
    }
}

private struct WebPageView: NSViewRepresentable {
    @ObservedObject var session: WebBrowserSession
    let zoomPercent: Double
    let onActivate: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(session: session) }

    func makeNSView(context: Context) -> WKWebView {
        if let view = session.webView as? ActivatingBrowserWebView {
            view.onActivate = onActivate
            view.navigationDelegate = context.coordinator
            context.coordinator.webView = view
            context.coordinator.requestedURL = view.url
            context.coordinator.observeURL(in: view)
            return view
        }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let view = ActivatingBrowserWebView(frame: .zero, configuration: configuration)
        view.onActivate = onActivate
        view.navigationDelegate = context.coordinator
        context.coordinator.webView = view
        context.coordinator.observeURL(in: view)
        session.attach(view)
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        (view as? ActivatingBrowserWebView)?.onActivate = onActivate
        if context.coordinator.requestedURL != session.currentURL, let url = session.currentURL {
            context.coordinator.requestedURL = url
            view.load(URLRequest(url: url))
        }
        if context.coordinator.lastZoom != zoomPercent {
            context.coordinator.lastZoom = zoomPercent
            view.pageZoom = min(2, max(0.5, zoomPercent / 100))
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        let session: WebBrowserSession
        weak var webView: WKWebView?
        var requestedURL: URL?
        var lastZoom = 100.0
        private var urlObservation: NSKeyValueObservation?
        private var backObservation: NSKeyValueObservation?
        private var forwardObservation: NSKeyValueObservation?

        init(session: WebBrowserSession) { self.session = session }

        func observeURL(in webView: WKWebView) {
            urlObservation = webView.observe(\.url, options: [.new]) { [weak self] view, change in
                let observedURL = change.newValue
                // Same-document navigation (including history.pushState) may not
                // call didFinish, but the address bar must follow the real URL.
                DispatchQueue.main.async { [weak self, weak view] in
                    guard let self, let view,
                          let url = observedURL ?? view.url,
                          WebBrowserSession.isWebURL(url), view.url == url else { return }
                    self.requestedURL = url
                    self.session.currentURL = url
                    self.session.canGoBack = view.canGoBack
                    self.session.canGoForward = view.canGoForward
                }
            }
            backObservation = webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] _, change in
                let canGoBack = change.newValue ?? false
                DispatchQueue.main.async { [weak self] in self?.session.canGoBack = canGoBack }
            }
            forwardObservation = webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] _, change in
                let canGoForward = change.newValue ?? false
                DispatchQueue.main.async { [weak self] in self?.session.canGoForward = canGoForward }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // `webView.url` can still point at the previous page here. Publishing it
            // would make SwiftUI reload that page and cancel the new request.
            session.isLoading = true
            session.pageError = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            requestedURL = webView.url
            session.pageError = nil
            session.refreshPageState(in: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard (error as NSError).code != NSURLErrorCancelled else { return }
            session.pageError = error.localizedDescription
            session.isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard (error as NSError).code != NSURLErrorCancelled else { return }
            session.pageError = error.localizedDescription
            session.isLoading = false
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            if let scheme = navigationAction.request.url?.scheme?.lowercased(),
               !["http", "https", "about", "data", "blob"].contains(scheme) {
                if scheme == "mailto", let url = navigationAction.request.url { NSWorkspace.shared.open(url) }
                decisionHandler(.cancel)
            } else if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void) {
            decisionHandler(navigationResponse.canShowMIMEType ? .allow : .cancel)
        }
    }
}

@MainActor
private final class ActivatingBrowserWebView: WKWebView {
    var onActivate: (() -> Void)?
    override func mouseDown(with event: NSEvent) { onActivate?(); super.mouseDown(with: event) }
}
