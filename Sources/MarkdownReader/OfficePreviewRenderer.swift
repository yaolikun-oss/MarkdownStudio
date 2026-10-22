import AppKit
import CryptoKit
import Foundation
import PDFKit
import WebKit
import ZIPFoundation

struct OfficePageLayout: Sendable {
    var width = 595.0
    var height = 842.0
    var top = 72.0
    var bottom = 72.0
    var left = 72.0
    var right = 72.0
}

private final class OfficePageLayoutParser: NSObject, XMLParserDelegate {
    var layout = OfficePageLayout()
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        let values = Dictionary(attributes.map { ($0.key.split(separator: ":").last.map(String.init) ?? $0.key, $0.value) },
                                uniquingKeysWith: { first, _ in first })
        func points(_ name: String, fallback: Double) -> Double {
            guard let text = values[name], let value = Double(text), value.isFinite, value >= 0 else { return fallback }
            return value / 20
        }
        switch name.split(separator: ":").last {
        case "pgSz":
            layout.width = points("w", fallback: layout.width)
            layout.height = points("h", fallback: layout.height)
        case "pgMar":
            layout.top = points("top", fallback: layout.top)
            layout.bottom = points("bottom", fallback: layout.bottom)
            layout.left = points("left", fallback: layout.left)
            layout.right = points("right", fallback: layout.right)
        default: break
        }
    }
}

/// Owns only the qlmanage process created for this preview, including cancellation.
private final class OfficePreviewProcess: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    func cancel() {
        lock.lock()
        cancelled = true
        if let process, process.isRunning { process.terminate() }
        lock.unlock()
    }
    func run(source: URL, directory: URL) throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
        child.arguments = ["-p", "-o", directory.path, source.path]
        child.standardOutput = FileHandle.nullDevice
        child.standardError = FileHandle.nullDevice
        lock.lock()
        guard !cancelled else { lock.unlock(); throw CancellationError() }
        process = child
        do { try child.run() } catch { lock.unlock(); throw error }
        lock.unlock()
        let timeout = DispatchWorkItem { [weak self] in self?.cancel() }
        DispatchQueue.global().asyncAfter(deadline: .now() + 60, execute: timeout)
        child.waitUntilExit()
        timeout.cancel()
        lock.lock()
        let wasCancelled = cancelled
        process = nil
        lock.unlock()
        if wasCancelled { throw CancellationError() }
        guard child.terminationStatus == 0 else { throw CocoaError(.fileReadCorruptFile) }
    }
}

private struct OfficePreviewPreparation: Sendable {
    let pdfURL: URL
    let htmlURL: URL?
    let layout: OfficePageLayout
}

/// Builds a disposable PDF reading copy. Neither Office nor Pages sources are written.
@MainActor
final class OfficePreviewRenderer: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<URL, Error>?
    private var preparation: OfficePreviewPreparation?
    private var printWindow: NSWindow?
    private var printOperation: NSPrintOperation?
    private var printingRetention: OfficePreviewRenderer?
    private var timeoutTask: Task<Void, Never>?

    static func pageLayout(for url: URL) -> OfficePageLayout {
        guard url.pathExtension.lowercased() == "docx",
              let archive = try? Archive(url: url, accessMode: .read, pathEncoding: nil),
              let entry = archive["word/document.xml"], entry.uncompressedSize < 30_000_000 else { return OfficePageLayout() }
        var data = Data()
        guard (try? archive.extract(entry, consumer: { data.append($0) })) != nil else { return OfficePageLayout() }
        let delegate = OfficePageLayoutParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), delegate.layout.width > 100, delegate.layout.height > 100,
              delegate.layout.width > delegate.layout.left + delegate.layout.right,
              delegate.layout.height > delegate.layout.top + delegate.layout.bottom else { return OfficePageLayout() }
        return delegate.layout
    }

    private nonisolated static func prepare(_ source: URL, process: OfficePreviewProcess) throws -> OfficePreviewPreparation {
        let fm = FileManager.default
        let values = try source.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
        var identity = "office-paged-v2|\(source.standardizedFileURL.path)|\(values.fileSize ?? 0)|\(values.contentModificationDate?.timeIntervalSince1970 ?? 0)"
        if values.isDirectory == true, let entries = fm.enumerator(at: source,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) {
            let children = entries.compactMap { $0 as? URL }.sorted { $0.path < $1.path }
            for child in children {
                let info = try child.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                identity += "|\(child.path):\(info.fileSize ?? 0):\(info.contentModificationDate?.timeIntervalSince1970 ?? 0)"
            }
        }
        let digest = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
        let directory = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MarkdownStudio/OfficePreview/\(digest)", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let pdf = directory.appendingPathComponent("Reading.pdf")
        if fm.fileExists(atPath: pdf.path), let document = PDFDocument(url: pdf), document.pageCount > 0 {
            return OfficePreviewPreparation(pdfURL: pdf, htmlURL: nil, layout: OfficePageLayout())
        }
        try process.run(source: source, directory: directory)
        let generated = fm.enumerator(at: directory, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        let htmlURL = generated.first(where: { $0.lastPathComponent.lowercased() == "preview.html" })
        var html = try htmlURL.map { try String(contentsOf: $0, encoding: .utf8) } ?? ""
        // Pages emits one PDF attachment per page. Follow the HTML order, which
        // is independent of attachment numbering; selecting one loses content.
        if source.pathExtension.lowercased() == "pages", let htmlURL {
            let pattern = #"<img\b[^>]*\bsrc\s*=\s*["']([^"']+\.pdf)["']"#
            let expression = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches = expression.matches(in: html, range: NSRange(html.startIndex..., in: html))
            if !matches.isEmpty {
                let combined = PDFDocument()
                let folder = htmlURL.deletingLastPathComponent().standardizedFileURL
                for match in matches {
                    guard let range = Range(match.range(at: 1), in: html),
                          let decoded = String(html[range]).removingPercentEncoding else { throw CocoaError(.fileReadCorruptFile) }
                    let attachment = folder.appendingPathComponent(decoded).standardizedFileURL
                    guard attachment.path.hasPrefix(folder.path + "/"),
                          let document = PDFDocument(url: attachment), document.pageCount > 0 else { throw CocoaError(.fileReadCorruptFile) }
                    for index in 0..<document.pageCount {
                        guard let page = document.page(at: index) else { throw CocoaError(.fileReadCorruptFile) }
                        combined.insert(page, at: combined.pageCount)
                    }
                }
                guard let data = combined.dataRepresentation() else { throw CocoaError(.fileReadCorruptFile) }
                try data.write(to: pdf, options: .atomic)
                return OfficePreviewPreparation(pdfURL: pdf, htmlURL: nil, layout: OfficePageLayout())
            }
        }
        let nativePDFs = generated.filter { $0.pathExtension.lowercased() == "pdf" && $0 != pdf }
        if htmlURL == nil, nativePDFs.count == 1, let document = PDFDocument(url: nativePDFs[0]),
           document.pageCount > 0, let data = document.dataRepresentation() {
            try data.write(to: pdf, options: .atomic)
            return OfficePreviewPreparation(pdfURL: pdf, htmlURL: nil, layout: OfficePageLayout())
        }
        guard let htmlURL else { throw CocoaError(.fileReadUnknown) }
        // Quick Look's Word generator emits explicit page breaks as form feeds.
        html = html.replacingOccurrences(of: "\u{c}", with: "<span style=\"display:block;break-before:page;page-break-before:always\"></span>")
        let printCSS = """
        <style>@media print {html,body {margin:0!important;padding:0!important;}
        body>div:first-of-type {width:auto!important;min-height:0!important;padding:0!important;overflow:visible!important;}
        table {break-inside:auto;}tr {break-inside:avoid;}}</style>
        """
        html = html.replacingOccurrences(of: "</head>", with: printCSS + "</head>")
        let printHTML = htmlURL.deletingLastPathComponent().appendingPathComponent("Reading.html")
        try html.write(to: printHTML, atomically: true, encoding: .utf8)
        return OfficePreviewPreparation(pdfURL: pdf, htmlURL: printHTML, layout: OfficePageLayout())
    }

    func render(_ source: URL) async throws -> URL {
        let process = OfficePreviewProcess()
        let preparationTask = Task.detached(priority: .userInitiated) { try Self.prepare(source, process: process) }
        let prepared = try await withTaskCancellationHandler {
            try await preparationTask.value
        } onCancel: {
            process.cancel()
            preparationTask.cancel()
        }
        try Task.checkCancellation()
        guard let htmlURL = prepared.htmlURL else { return prepared.pdfURL }
        preparation = OfficePreviewPreparation(pdfURL: prepared.pdfURL, htmlURL: htmlURL, layout: Self.pageLayout(for: source))
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let config = WKWebViewConfiguration()
                config.websiteDataStore = .nonPersistent()
                config.defaultWebpagePreferences.allowsContentJavaScript = false
                let layout = self.preparation!.layout
                let view = WKWebView(frame: NSRect(x: 0, y: 0, width: layout.width - layout.left - layout.right,
                                                   height: layout.height - layout.top - layout.bottom), configuration: config)
                webView = view
                view.navigationDelegate = self
                view.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
                timeoutTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(60))
                    guard !Task.isCancelled else { return }
                    self?.finish(.failure(CocoaError(.fileReadUnknown)))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finish(.failure(CancellationError())) }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.async { [weak self, weak webView] in
            guard let self, let webView else { return }
            self.printPreview(webView)
        }
    }

    private func printPreview(_ webView: WKWebView) {
        guard let prepared = preparation, continuation != nil else { return }
        let info = NSPrintInfo(dictionary: [:])
        info.paperSize = NSSize(width: prepared.layout.width, height: prepared.layout.height)
        info.topMargin = prepared.layout.top
        info.bottomMargin = prepared.layout.bottom
        info.leftMargin = prepared.layout.left
        info.rightMargin = prepared.layout.right
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        info.dictionary()[NSPrintInfo.AttributeKey.allPages] = true
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = prepared.pdfURL
        let operation = webView.printOperation(with: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        // WKPrintingView needs asynchronous printing so its page-count IPC can
        // complete on the main thread. Synchronous run() reports NSIntegerMax.
        operation.canSpawnSeparateThread = true
        let window = NSWindow(contentRect: webView.bounds, styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = webView
        printWindow = window
        printOperation = operation
        printingRetention = self
        operation.runModal(for: window, delegate: self,
            didRun: #selector(printDidFinish(_:success:contextInfo:)), contextInfo: nil)
    }

    @objc nonisolated private func printDidFinish(_ operation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?) {
        Task { @MainActor [weak self] in self?.completePrint(success: success) }
    }

    private func completePrint(success: Bool) {
        printOperation = nil
        guard let prepared = preparation, continuation != nil else { cleanUpPreview(); return }
        if success, let document = PDFDocument(url: prepared.pdfURL), document.pageCount > 0, document.pageCount <= 5000 {
            finish(.success(prepared.pdfURL))
        } else { finish(.failure(CocoaError(.fileWriteUnknown))) }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }

    private func finish(_ result: Result<URL, Error>) {
        let pending = continuation
        continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        if printOperation == nil { cleanUpPreview() }
        pending?.resume(with: result)
    }

    private func cleanUpPreview() {
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
        printWindow?.close()
        printWindow = nil
        printOperation = nil
        printingRetention = nil
    }
}
