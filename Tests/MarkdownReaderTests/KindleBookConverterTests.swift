import EPUBCore
import Foundation
import Testing
import ZIPFoundation
@testable import MarkdownReader

@Suite struct KindleBookConverterTests {
    private func fixture(in directory: URL) throws -> URL {
        let root = directory.appendingPathComponent("epub-source", isDirectory: true)
        let ops = root.appendingPathComponent("OPS", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("META-INF"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: ops.appendingPathComponent("Images"), withIntermediateDirectories: true)
        try Data("application/epub+zip".utf8).write(to: root.appendingPathComponent("mimetype"))
        try "<?xml version=\"1.0\"?><container xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\" version=\"1.0\"><rootfiles><rootfile full-path=\"OPS/book.opf\" media-type=\"application/oebps-package+xml\"/></rootfiles></container>"
            .write(to: root.appendingPathComponent("META-INF/container.xml"), atomically: true, encoding: .utf8)
        try "<?xml version=\"1.0\"?><package xmlns=\"http://www.idpf.org/2007/opf\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" version=\"3.0\"><metadata><dc:title>格式验证样书</dc:title><dc:language>zh</dc:language></metadata><manifest><item id=\"nav\" href=\"nav.xhtml\" media-type=\"application/xhtml+xml\" properties=\"nav\"/><item id=\"one\" href=\"one.xhtml\" media-type=\"application/xhtml+xml\"/><item id=\"two\" href=\"two.xhtml\" media-type=\"application/xhtml+xml\"/><item id=\"image\" href=\"Images/pixel.png\" media-type=\"image/png\"/></manifest><spine><itemref idref=\"one\"/><itemref idref=\"two\"/></spine></package>"
            .write(to: ops.appendingPathComponent("book.opf"), atomically: true, encoding: .utf8)
        try "<html xmlns=\"http://www.w3.org/1999/xhtml\" xmlns:epub=\"http://www.idpf.org/2007/ops\"><body><nav epub:type=\"toc\"><ol><li><a href=\"one.xhtml\">第一章</a></li><li><a href=\"two.xhtml\">第二章</a></li></ol></nav></body></html>"
            .write(to: ops.appendingPathComponent("nav.xhtml"), atomically: true, encoding: .utf8)
        try "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body><h1>第一章</h1><p>章节甲专有词语完整保留。</p><img src=\"Images/pixel.png\" alt=\"示例图片\"/></body></html>"
            .write(to: ops.appendingPathComponent("one.xhtml"), atomically: true, encoding: .utf8)
        try "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body><h1>第二章</h1><p>章节乙专有词语完整保留。</p></body></html>"
            .write(to: ops.appendingPathComponent("two.xhtml"), atomically: true, encoding: .utf8)
        let tinyPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9zcXcAAAAASUVORK5CYII=")!
        try tinyPNG.write(to: ops.appendingPathComponent("Images/pixel.png"))

        let output = directory.appendingPathComponent("fixture.epub")
        let archive = try Archive(url: output, accessMode: .create)
        try archive.addEntry(with: "mimetype", relativeTo: root, compressionMethod: .none)
        let files = (FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])?.allObjects as? [URL] ?? [])
            .filter { $0.lastPathComponent != "mimetype" && ((try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true) }
        for file in files.sorted(by: { $0.path < $1.path }) {
            let realRoot = root.resolvingSymlinksInPath().standardizedFileURL.path
            let realFile = file.resolvingSymlinksInPath().standardizedFileURL.path
            let relative = String(realFile.dropFirst(realRoot.count + 1))
            try archive.addEntry(with: relative, fileURL: file, compressionMethod: .deflate)
        }
        return output
    }

    @Test func conversionUsesOriginalIdentityAndReusesVerifiedCache() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let epub = try fixture(in: directory)
        _ = try EPUBPackageDocument.open(epub)
        let original = directory.appendingPathComponent("原书.mobi")
        try FileManager.default.copyItem(at: epub, to: original)
        let originalBytes = try Data(contentsOf: original)
        let converter = KindleBookConverter(executableURL: URL(fileURLWithPath: "/bin/cp"),
                                            cacheDirectory: directory.appendingPathComponent("cache"))
        let converted = try converter.convert(original)
        let book = try EPUBPackageDocument.open(original, bookURL: converted)
        #expect(book.sourceURL == original)
        #expect(book.chapters.count == 2)
        #expect(book.tableOfContents.count >= 2)
        #expect(try converter.convert(original) == converted)
        let cachedReader = KindleBookConverter(executableURL: URL(fileURLWithPath: "/missing/converter"),
                                               cacheDirectory: directory.appendingPathComponent("cache"))
        #expect(try cachedReader.convert(original) == converted)
        #expect(try Data(contentsOf: original) == originalBytes)
    }

    @Test func invalidConversionIsRejectedWithoutPublishingCache() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = directory.appendingPathComponent("broken.azw3")
        try Data("invalid Kindle content".utf8).write(to: original)
        let cache = directory.appendingPathComponent("cache")
        let converter = KindleBookConverter(executableURL: URL(fileURLWithPath: "/bin/cp"), cacheDirectory: cache)
        #expect(throws: KindleBookConversionError.self) { _ = try converter.convert(original) }
        let files = try FileManager.default.contentsOfDirectory(at: cache, includingPropertiesForKeys: nil)
        #expect(files.isEmpty)
    }

    @Test func missingConverterAndUnsupportedFormatGiveSpecificErrors() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let mobi = directory.appendingPathComponent("book.mobi")
        try Data("sample".utf8).write(to: mobi)
        let converter = KindleBookConverter(executableURL: directory.appendingPathComponent("missing-tool"),
                                            cacheDirectory: directory.appendingPathComponent("cache"))
        do {
            _ = try converter.convert(mobi)
            Issue.record("A missing converter must be reported")
        } catch KindleBookConversionError.converterUnavailable {
            // Expected.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        let kfx = directory.appendingPathComponent("book.kfx")
        try Data("sample".utf8).write(to: kfx)
        do {
            _ = try converter.convert(kfx)
            Issue.record("KFX must be rejected explicitly")
        } catch KindleBookConversionError.unsupportedFormat {
            // Expected.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func cancellingConversionStopsItsProcess() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = directory.appendingPathComponent("slow.mobi")
        try Data("unprotected sample".utf8).write(to: original)
        let script = directory.appendingPathComponent("slow-converter")
        try "#!/bin/sh\nwhile :; do :; done\n".write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let converter = KindleBookConverter(executableURL: script,
                                            cacheDirectory: directory.appendingPathComponent("cache"))
        let task = Task.detached { try converter.convert(original) }
        try? await Task.sleep(for: .milliseconds(150))
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Conversion should have been cancelled")
        } catch is CancellationError {
            // Expected: the converter process was terminated.
        }
    }

    @Test func realCalibreRoundTripRetainsBothChaptersAndImage() throws {
        guard let path = ProcessInfo.processInfo.environment["MARKDOWN_STUDIO_CALIBRE_TEST"],
              FileManager.default.isExecutableFile(atPath: path) else { return }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let epub = try fixture(in: directory)
        for fileExtension in ["mobi", "azw3"] {
            let original = directory.appendingPathComponent("source.\(fileExtension)")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = [epub.path, original.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            #expect(process.terminationStatus == 0)
            let converter = KindleBookConverter(executableURL: URL(fileURLWithPath: path),
                                                cacheDirectory: directory.appendingPathComponent("cache"))
            let converted = try converter.convert(original)
            let book = try EPUBPackageDocument.open(original, bookURL: converted)
            #expect(book.tableOfContents.count >= 2)
            #expect(book.tableOfContents.allSatisfy { book.navigationTarget(for: $0) != nil })
            let body = try book.chapters.map { try String(contentsOf: $0.fileURL, encoding: .utf8) }.joined()
            #expect(body.contains("章节甲专有词语"))
            #expect(body.contains("章节乙专有词语"))
            let imageFiles = (FileManager.default.enumerator(at: book.workingDirectory,
                                    includingPropertiesForKeys: [.isRegularFileKey])?.allObjects as? [URL] ?? [])
                .filter { ["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) }
            #expect(!imageFiles.isEmpty)
            if fileExtension == "mobi" {
                // Legacy AZW commonly carries the same MOBI payload.
                let azw = directory.appendingPathComponent("source.azw")
                try FileManager.default.copyItem(at: original, to: azw)
                let azwConverter = KindleBookConverter(executableURL: URL(fileURLWithPath: path),
                                                       cacheDirectory: directory.appendingPathComponent("azw-cache"))
                let azwEPUB = try azwConverter.convert(azw)
                let azwBook = try EPUBPackageDocument.open(azw, bookURL: azwEPUB)
                let azwBody = try azwBook.chapters.map { try String(contentsOf: $0.fileURL, encoding: .utf8) }.joined()
                #expect(azwBody.contains("章节甲专有词语"))
                #expect(azwBody.contains("章节乙专有词语"))
            }
        }
    }
}
