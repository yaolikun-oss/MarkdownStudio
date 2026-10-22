import EPUBCore
import Foundation

enum KindleBookConversionError: LocalizedError {
    case converterUnavailable
    case unsupportedFormat
    case conversionFailed(String)
    case invalidEPUB

    var errorDescription: String? {
        switch self {
        case .converterUnavailable:
            "打开 MOBI、AZW 或 AZW3 需要先安装 calibre。安装后重试，原书不会被修改。"
        case .unsupportedFormat:
            "目前支持未加密的 MOBI、AZW 和 AZW3；AZW4、KFX 尚未支持。"
        case .conversionFailed(let detail):
            "无法将电子书转换为 EPUB。文件可能受 DRM 保护或格式损坏。\n\(detail)"
        case .invalidEPUB:
            "转换生成的 EPUB 缺少可读章节，已停止打开以免遗漏内容。"
        }
    }
}

struct KindleBookConverter: Sendable {
    static let supportedExtensions: Set<String> = ["mobi", "azw", "azw3"]
    private static let cacheVersion = "kindle-to-epub-v1"

    let executableURL: URL?
    let cacheDirectory: URL?

    init(executableURL: URL? = nil, cacheDirectory: URL? = nil) {
        self.executableURL = executableURL
        self.cacheDirectory = cacheDirectory
    }

    static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    static func locateExecutable() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let injected = ProcessInfo.processInfo.environment["MARKDOWN_STUDIO_EBOOK_CONVERT"].map { URL(fileURLWithPath: $0) }
        let fixed = (injected.map { [$0] } ?? []) + [
            URL(fileURLWithPath: "/Applications/calibre.app/Contents/MacOS/ebook-convert"),
            home.appendingPathComponent("Applications/calibre.app/Contents/MacOS/ebook-convert"),
            URL(fileURLWithPath: "/opt/homebrew/bin/ebook-convert"),
            URL(fileURLWithPath: "/usr/local/bin/ebook-convert")
        ]
        let fromPath = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0)).appendingPathComponent("ebook-convert") }
        return (fixed + fromPath).first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// Converts to a private cache and verifies the result before publishing it.
    /// Runs on a background task because calibre may need several seconds.
    func convert(_ sourceURL: URL) throws -> URL {
        if withUnsafeCurrentTask(body: { $0?.isCancelled ?? false }) { throw CancellationError() }
        guard Self.isSupported(sourceURL) else { throw KindleBookConversionError.unsupportedFormat }
        let fileManager = FileManager.default
        let cache = try cacheDirectory ?? fileManager.url(for: .cachesDirectory, in: .userDomainMask,
                                                           appropriateFor: nil, create: true)
            .appendingPathComponent("MarkdownStudio/ConvertedBooks", isDirectory: true)
        try fileManager.createDirectory(at: cache, withIntermediateDirectories: true)
        let identity = try ReadingDocumentIdentity.make(for: sourceURL)
        let result = cache.appendingPathComponent("\(Self.cacheVersion)-\(identity).epub")
        if fileManager.fileExists(atPath: result.path) {
            if (try? EPUBPackageDocument.open(sourceURL, bookURL: result)) != nil { return result }
            try fileManager.removeItem(at: result)
        }
        guard let executable = executableURL ?? Self.locateExecutable(),
              fileManager.isExecutableFile(atPath: executable.path) else {
            throw KindleBookConversionError.converterUnavailable
        }

        let temporary = cache.appendingPathComponent(".\(UUID().uuidString).epub")
        let logURL = cache.appendingPathComponent(".\(UUID().uuidString).log")
        defer {
            try? fileManager.removeItem(at: temporary)
            try? fileManager.removeItem(at: logURL)
        }
        fileManager.createFile(atPath: logURL.path, contents: nil)
        let log = try FileHandle(forWritingTo: logURL)
        defer { try? log.close() }
        let process = Process()
        process.executableURL = executable
        process.arguments = [sourceURL.path, temporary.path]
        process.standardOutput = log
        process.standardError = log
        try process.run()
        while process.isRunning {
            if withUnsafeCurrentTask(body: { $0?.isCancelled ?? false }) {
                process.terminate()
                process.waitUntilExit()
                throw CancellationError()
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        process.waitUntilExit()
        if withUnsafeCurrentTask(body: { $0?.isCancelled ?? false }) { throw CancellationError() }
        guard process.terminationReason == .exit, process.terminationStatus == 0,
              fileManager.fileExists(atPath: temporary.path) else {
            let output = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
            let detail = String(output.suffix(1_000)).trimmingCharacters(in: .whitespacesAndNewlines)
            throw KindleBookConversionError.conversionFailed(detail)
        }
        guard (try? EPUBPackageDocument.open(sourceURL, bookURL: temporary)) != nil else {
            throw KindleBookConversionError.invalidEPUB
        }
        try fileManager.moveItem(at: temporary, to: result)
        return result
    }
}
