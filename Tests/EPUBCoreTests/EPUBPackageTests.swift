import Foundation
import Testing
import ZIPFoundation
@testable import EPUBCore

struct EPUBPackageTests {
    private func makeEPUB(in directory: URL, includeNav: Bool = true, includeNCX: Bool = false,
                          includeSecondChapterInNav: Bool = true,
                          chapterPath: String = "Text/chapter1.xhtml") throws -> URL {
        let root = directory.appendingPathComponent("fixture", isDirectory: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("META-INF", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("OPS/Text", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("OPS/Images", isDirectory: true), withIntermediateDirectories: true)
        try Data("application/epub+zip".utf8).write(to: root.appendingPathComponent("mimetype"))
        try "<?xml version=\"1.0\"?><container version=\"1.0\" xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\"><rootfiles><rootfile full-path=\"OPS/book.opf\" media-type=\"application/oebps-package+xml\"/></rootfiles></container>"
            .write(to: root.appendingPathComponent("META-INF/container.xml"), atomically: true, encoding: .utf8)
        let navItem = includeNav ? "<item id=\"nav\" href=\"nav.xhtml\" media-type=\"application/xhtml+xml\" properties=\"nav\"/>" : ""
        let secondNavItem = includeSecondChapterInNav ? "<ol><li><a href=\"Text/chapter2.xhtml\">小节</a></li></ol>" : ""
        let navSpine = includeNav ? "<nav epub:type=\"toc\"><ol><li><a href=\"Text/chapter1.xhtml#start\">第一章</a>\(secondNavItem)</li></ol></nav>" : ""
        let ncxItem = includeNCX ? "<item id=\"ncx\" href=\"toc.ncx\" media-type=\"application/x-dtbncx+xml\"/>" : ""
        let ncxSpine = includeNCX ? " toc=\"ncx\"" : ""
        let opf = "<?xml version=\"1.0\"?><package xmlns=\"http://www.idpf.org/2007/opf\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" version=\"3.0\"><metadata><dc:title>测试书</dc:title></metadata><manifest><item id=\"c1\" href=\"\(chapterPath)\" media-type=\"application/xhtml+xml\"/><item id=\"c2\" href=\"Text/chapter2.xhtml\" media-type=\"application/xhtml+xml\"/>\(navItem)\(ncxItem)</manifest><spine\(ncxSpine)><itemref idref=\"c1\"/><itemref idref=\"c2\"/></spine></package>"
        try opf.write(to: root.appendingPathComponent("OPS/book.opf"), atomically: true, encoding: .utf8)
        if includeNav {
            try "<html xmlns=\"http://www.w3.org/1999/xhtml\" xmlns:epub=\"http://www.idpf.org/2007/ops\"><body>\(navSpine)</body></html>"
                .write(to: root.appendingPathComponent("OPS/nav.xhtml"), atomically: true, encoding: .utf8)
        }
        if includeNCX {
            let ncx = "<ncx xmlns=\"http://www.daisy.org/z3986/2005/ncx/\"><navMap><navPoint id=\"n1\"><navLabel><text>第一章</text></navLabel><content src=\"Text/chapter1.xhtml#start\"/><navPoint id=\"n2\"><navLabel><text>小节</text></navLabel><content src=\"Text/chapter2.xhtml\"/></navPoint></navPoint></navMap></ncx>"
            try ncx.write(to: root.appendingPathComponent("OPS/toc.ncx"), atomically: true, encoding: .utf8)
        }
        try "<html xmlns=\"http://www.w3.org/1999/xhtml\"><head><title>章一</title></head><body id=\"start\"><p>第一章正文</p></body></html>"
            .write(to: root.appendingPathComponent("OPS/Text/chapter1.xhtml"), atomically: true, encoding: .utf8)
        try "<html xmlns=\"http://www.w3.org/1999/xhtml\"><body><h2>中国古代的博物学</h2><p>第二章正文</p></body></html>"
            .write(to: root.appendingPathComponent("OPS/Text/chapter2.xhtml"), atomically: true, encoding: .utf8)
        try "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"10\"><rect width=\"20\" height=\"10\" fill=\"red\"/></svg>"
            .write(to: root.appendingPathComponent("OPS/Images/pixel.svg"), atomically: true, encoding: .utf8)
        let archiveURL = directory.appendingPathComponent("fixture.epub")
        let archive = try Archive(url: archiveURL, accessMode: .create)
        try archive.addEntry(with: "mimetype", relativeTo: root, compressionMethod: .none)
        let files = (FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])?.allObjects as? [URL] ?? [])
            .filter { $0.lastPathComponent != "mimetype" && ((try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true) }
        for file in files.sorted(by: { $0.path < $1.path }) {
            let realRoot = root.resolvingSymlinksInPath().standardizedFileURL.path
            let realFile = file.resolvingSymlinksInPath().standardizedFileURL.path
            let relativePath = String(realFile.dropFirst(realRoot.count + 1))
            try archive.addEntry(with: relativePath, fileURL: file, compressionMethod: .deflate)
        }
        return archiveURL
    }

    @Test func opensAllSpineChaptersAndResolvesNestedNavigation() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let url = try makeEPUB(in: temp)
        let book = try EPUBPackageDocument.open(url)
        #expect(book.title == "测试书")
        #expect(book.chapters.count == 2)
        #expect(book.tableOfContents.map(\.level) == [0, 1])
        #expect(book.navigationTarget(for: book.tableOfContents[0])?.chapterIndex == 0)
        #expect(book.navigationTarget(for: book.tableOfContents[0])?.fragment == "start")
        #expect(book.navigationTarget(for: book.tableOfContents[1])?.chapterIndex == 1)
    }

    @Test func opensUnpackedEPUBDirectoryWithoutChangingTheSource() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        _ = try makeEPUB(in: temp)
        let source = temp.appendingPathComponent("fixture", isDirectory: true)
        let book = try EPUBPackageDocument.open(source)
        #expect(book.chapters.count == 2)
        #expect(book.title == "测试书")
        #expect(FileManager.default.fileExists(atPath: book.workingDirectory.appendingPathComponent("OPS/Images/pixel.svg").path))
        #expect(FileManager.default.fileExists(atPath: source.appendingPathComponent("META-INF/container.xml").path))
    }

    @Test func fallsBackToSpineWhenNavigationIsMissing() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let book = try EPUBPackageDocument.open(try makeEPUB(in: temp, includeNav: false))
        #expect(book.tableOfContents.count == 2)
        #expect(book.tableOfContents.map(\.level) == [0, 0])
    }

    @Test func usesEPUB2NCXForTheBooksActualTableOfContents() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let book = try EPUBPackageDocument.open(try makeEPUB(in: temp, includeNav: false, includeNCX: true))
        #expect(book.tableOfContents.map(\.title) == ["第一章", "小节"])
        #expect(book.tableOfContents.map(\.level) == [0, 1])
        #expect(book.navigationTarget(for: book.tableOfContents[1])?.chapterIndex == 1)
    }

    @Test func addsHeadingsFromSpineItemsMissingFromTheNavigationDocument() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let book = try EPUBPackageDocument.open(try makeEPUB(in: temp, includeSecondChapterInNav: false))
        #expect(book.tableOfContents.map(\.title) == ["第一章", "中国古代的博物学"])
        #expect(book.tableOfContents.map(\.level) == [0, 1])
        #expect(book.navigationTarget(for: book.tableOfContents[1])?.chapterIndex == 1)
    }

    @Test func bodyEditPreservesHeadAndExportsReadableEPUB() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let book = try EPUBPackageDocument.open(try makeEPUB(in: temp))
        try book.replaceChapterBody(at: 0, with: "<p>修改后&nbsp;正文<br>换行</p>")
        let edited = try String(contentsOf: book.chapters[0].fileURL, encoding: .utf8)
        #expect(edited.contains("<head><title>章一</title></head>"))
        #expect(edited.contains("&#160;"))
        #expect(edited.contains("<br/>"))
        let output = temp.appendingPathComponent("output.epub")
        try book.writeEPUBCopy(to: output)
        let reopened = try EPUBPackageDocument.open(output)
        #expect(reopened.chapters.count == 2)
        #expect(try String(contentsOf: reopened.chapters[0].fileURL, encoding: .utf8).contains("修改后"))
        #expect(FileManager.default.fileExists(atPath: reopened.workingDirectory.appendingPathComponent("OPS/Images/pixel.svg").path))
        let archive = try Archive(url: output, accessMode: .read)
        let firstEntry = archive.first(where: { _ in true })
        #expect(firstEntry?.path == "mimetype")
        #expect(firstEntry?.isCompressed == false)
    }

    @Test func rejectsResourcePathsEscapingExtractionRoot() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        do {
            _ = try EPUBPackageDocument.open(try makeEPUB(in: temp, chapterPath: "../../outside.xhtml"))
            Issue.record("Expected traversal path to be rejected")
        } catch let error as EPUBPackageError {
            guard case .invalidResourcePath = error else { Issue.record("Unexpected EPUB error: \(error)"); return }
        }
    }

    @Test func rejectsInvalidArchive() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let file = temp.appendingPathComponent("broken.epub")
        try Data("not a zip".utf8).write(to: file)
        #expect(throws: (any Error).self) { try EPUBPackageDocument.open(file) }
    }
}
