import Foundation
import ZIPFoundation

public struct EPUBTOCItem: Identifiable, Hashable {
    public let title: String
    public let href: String
    public let level: Int
    public var id: String { "\(level):\(href):\(title)" }
}

public struct EPUBChapter: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let href: String
    public let fileURL: URL
}

public enum EPUBPackageError: LocalizedError {
    case invalidContainer
    case invalidPackage
    case noReadableChapters
    case encryptedContent
    case invalidResourcePath(String)

    public var errorDescription: String? {
        switch self {
        case .invalidContainer: "这不是有效的 EPUB 文件：缺少 package 定义。"
        case .invalidPackage: "无法解析 EPUB 的 package 文档。"
        case .noReadableChapters: "EPUB 中没有可读取的章节。"
        case .encryptedContent: "此 EPUB 的正文经过加密，当前版本无法编辑或阅读。"
        case .invalidResourcePath(let path): "EPUB 中包含无效的资源路径：\(path)"
        }
    }
}

public final class EPUBPackageDocument {
    public let sourceURL: URL
    public let workingDirectory: URL
    public let title: String
    public let chapters: [EPUBChapter]
    public let tableOfContents: [EPUBTOCItem]
    public let navigationBaseDirectory: URL

    private init(sourceURL: URL, workingDirectory: URL, title: String,
                 chapters: [EPUBChapter], tableOfContents: [EPUBTOCItem], navigationBaseDirectory: URL) {
        self.sourceURL = sourceURL
        self.workingDirectory = workingDirectory
        self.title = title
        self.chapters = chapters
        self.tableOfContents = tableOfContents
        self.navigationBaseDirectory = navigationBaseDirectory
    }

    deinit {
        try? FileManager.default.removeItem(at: workingDirectory)
    }

    public static func open(_ sourceURL: URL) throws -> EPUBPackageDocument {
        let fileManager = FileManager.default
        let support = try fileManager.url(for: .cachesDirectory, in: .userDomainMask,
                                          appropriateFor: nil, create: true)
            .appendingPathComponent("MarkdownStudio/EPUB", isDirectory: true)
        try fileManager.createDirectory(at: support, withIntermediateDirectories: true)
        let work = support.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: work, withIntermediateDirectories: true)
        do {
            let sourceIsDirectory = (try? sourceURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            if sourceIsDirectory {
                let container = sourceURL.appendingPathComponent("META-INF/container.xml")
                guard fileManager.fileExists(atPath: container.path) else {
                    throw EPUBPackageError.invalidContainer
                }
                try copyUnpackedPackage(from: sourceURL, to: work)
            } else {
                // ZIPFoundation rejects paths that escape the destination by default.
                try fileManager.unzipItem(at: sourceURL, to: work)
            }
            let containerURL = work.appendingPathComponent("META-INF/container.xml")
            guard let packagePath = try ContainerRootfileParser.parse(Data(contentsOf: containerURL)) else {
                throw EPUBPackageError.invalidContainer
            }
            let packageURL = try resourceURL(packagePath, relativeTo: work, within: work)
            let packageData = try Data(contentsOf: packageURL)
            guard let package = try OPFPackageParser.parse(packageData) else {
                throw EPUBPackageError.invalidPackage
            }

            let encryptedURL = work.appendingPathComponent("META-INF/encryption.xml")
            if let data = try? Data(contentsOf: encryptedURL),
               EPUBEncryptionParser.hasUnsupportedContentEncryption(data) {
                throw EPUBPackageError.encryptedContent
            }

            let chapters = try package.spine.compactMap { id -> EPUBChapter? in
                guard let item = package.items[id],
                      item.mediaType == "application/xhtml+xml" || item.mediaType == "text/html" else { return nil }
                let fileURL = try resourceURL(item.href, relativeTo: packageURL.deletingLastPathComponent(), within: work)
                guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
                let fallback = fileURL.deletingPathExtension().lastPathComponent
                return EPUBChapter(id: id, title: fallback, href: item.href, fileURL: fileURL)
            }
            guard !chapters.isEmpty else { throw EPUBPackageError.noReadableChapters }

            var toc: [EPUBTOCItem] = []
            var navigationBaseDirectory = packageURL.deletingLastPathComponent()
            if let navItem = package.items.values.first(where: { $0.properties.contains("nav") }) {
                let navURL = try resourceURL(navItem.href, relativeTo: packageURL.deletingLastPathComponent(), within: work)
                navigationBaseDirectory = navURL.deletingLastPathComponent()
                if let data = try? Data(contentsOf: navURL) {
                    toc = EPUBNavigationParser.parse(data)
                }
            }
            if toc.isEmpty, let ncxItem = package.items.values.first(where: { $0.mediaType == "application/x-dtbncx+xml" }) {
                let ncxURL = try resourceURL(ncxItem.href, relativeTo: packageURL.deletingLastPathComponent(), within: work)
                navigationBaseDirectory = ncxURL.deletingLastPathComponent()
                if let data = try? Data(contentsOf: ncxURL) { toc = EPUBNCXNavigationParser.parse(data) }
            }
            if toc.isEmpty {
                toc = chapters.enumerated().map { index, chapter in
                    EPUBTOCItem(title: chapter.title, href: chapter.href, level: 0)
                }
            }
            toc = supplementNavigation(toc, chapters: chapters, baseDirectory: navigationBaseDirectory,
                                       workingDirectory: work)

            return EPUBPackageDocument(sourceURL: sourceURL, workingDirectory: work,
                                       title: package.title ?? sourceURL.deletingPathExtension().lastPathComponent,
                                       chapters: chapters, tableOfContents: toc,
                                       navigationBaseDirectory: navigationBaseDirectory)
        } catch {
            try? fileManager.removeItem(at: work)
            throw error
        }
    }

    public func chapter(matching href: String) -> Int? {
        let path = href.components(separatedBy: "#").first ?? href
        guard let target = try? Self.resourceURL(path, relativeTo: navigationBaseDirectory, within: workingDirectory) else { return nil }
        return chapters.firstIndex { $0.fileURL.standardizedFileURL == target.standardizedFileURL }
    }

    public func navigationTarget(for item: EPUBTOCItem) -> (chapterIndex: Int, fragment: String?)? {
        let parts = item.href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        guard let index = chapter(matching: String(parts[0])) else { return nil }
        return (index, parts.count > 1 ? String(parts[1]) : nil)
    }

    public func writeEPUBCopy(to destinationURL: URL) throws {
        let fileManager = FileManager.default
        let files = (fileManager.enumerator(at: workingDirectory, includingPropertiesForKeys: [.isRegularFileKey],
                                            options: [.skipsHiddenFiles])?.allObjects as? [URL] ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted { $0.path < $1.path }
        let mimetypeURL = workingDirectory.appendingPathComponent("mimetype")
        guard fileManager.fileExists(atPath: mimetypeURL.path) else { throw EPUBPackageError.invalidContainer }

        let temporaryURL = destinationURL.deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString).epub")
        defer { try? fileManager.removeItem(at: temporaryURL) }
        let archive = try Archive(url: temporaryURL, accessMode: .create)
        try archive.addEntry(with: "mimetype", relativeTo: workingDirectory, compressionMethod: .none)
        for fileURL in files where fileURL.lastPathComponent != "mimetype" {
            let path = String(fileURL.path.dropFirst(workingDirectory.path.count + 1))
            try archive.addEntry(with: path, relativeTo: workingDirectory, compressionMethod: .deflate)
        }
        if fileManager.fileExists(atPath: destinationURL.path) {
            _ = try fileManager.replaceItemAt(destinationURL, withItemAt: temporaryURL)
        } else {
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        }
    }

    private static func supplementNavigation(_ toc: [EPUBTOCItem], chapters: [EPUBChapter],
                                             baseDirectory: URL, workingDirectory: URL) -> [EPUBTOCItem] {
        var itemsByChapter: [Int: [EPUBTOCItem]] = [:]
        for item in toc {
            guard let target = try? resourceURL(item.href, relativeTo: baseDirectory, within: workingDirectory),
                  let index = chapters.firstIndex(where: { $0.fileURL.standardizedFileURL == target.standardizedFileURL }) else {
                continue
            }
            itemsByChapter[index, default: []].append(item)
        }

        var result: [EPUBTOCItem] = []
        var previousLevel = 0
        for (index, chapter) in chapters.enumerated() {
            if let items = itemsByChapter[index], !items.isEmpty {
                result.append(contentsOf: items)
                previousLevel = items.last?.level ?? previousLevel
                continue
            }
            guard let data = try? Data(contentsOf: chapter.fileURL),
                  let heading = EPUBHeadingParser.parse(data) else { continue }
            let level = min(previousLevel + 1, 6)
            result.append(EPUBTOCItem(title: heading.title, href: chapter.href, level: level))
            previousLevel = level
        }
        return result.isEmpty ? toc : result
    }

    private static func copyUnpackedPackage(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        for item in try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey]) {
            let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey])
            guard values.isSymbolicLink != true else {
                throw EPUBPackageError.invalidResourcePath(item.lastPathComponent)
            }
            let target = destination.appendingPathComponent(item.lastPathComponent, isDirectory: values.isDirectory == true)
            if values.isDirectory == true {
                try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
                try copyUnpackedPackage(from: item, to: target)
            } else if values.isRegularFile == true {
                try fileManager.copyItem(at: item, to: target)
            }
        }
    }

    public func replaceChapterBody(at index: Int, with fragment: String) throws {
        guard chapters.indices.contains(index) else { return }
        let url = chapters[index].fileURL
        let original = try String(contentsOf: url, encoding: .utf8)
        let source = original as NSString
        let openExpression = try NSRegularExpression(pattern: "(?is)<body\\b[^>]*>")
        let closeExpression = try NSRegularExpression(pattern: "(?is)</body\\s*>")
        let fullRange = NSRange(location: 0, length: source.length)
        guard let opening = openExpression.firstMatch(in: original, range: fullRange),
              let closing = closeExpression.firstMatch(in: original, range: fullRange),
              closing.range.location >= NSMaxRange(opening.range) else {
            throw EPUBPackageError.invalidPackage
        }
        let updated = source.replacingCharacters(in: NSRange(location: NSMaxRange(opening.range),
                                                              length: closing.range.location - NSMaxRange(opening.range)),
                                                  with: Self.xhtmlFragment(fragment))
        try updated.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func xhtmlFragment(_ html: String) -> String {
        var result = html.replacingOccurrences(of: "&nbsp;", with: "&#160;")
        guard let regex = try? NSRegularExpression(pattern: "(?is)<(br|hr|img|source|input|meta|link|area|base|col|embed|param|track|wbr)\\b([^>]*)>") else {
            return result
        }
        let source = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: source.length))
        for match in matches.reversed() {
            guard match.numberOfRanges > 2,
                  let tagRange = Range(match.range(at: 1), in: result),
                  let attributesRange = Range(match.range(at: 2), in: result),
                  let fullRange = Range(match.range, in: result) else { continue }
            var attributes = String(result[attributesRange])
            if attributes.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("/") {
                attributes = String(attributes.dropLast())
            }
            result.replaceSubrange(fullRange, with: "<\(result[tagRange])\(attributes)/>")
        }
        return result
    }

    private static func resourceURL(_ path: String, relativeTo directory: URL, within rootDirectory: URL) throws -> URL {
        let noFragment = path.components(separatedBy: "#").first ?? path
        let decoded = (noFragment.removingPercentEncoding ?? noFragment).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let base = noFragment.hasPrefix("/") ? rootDirectory : directory
        let url = base.appendingPathComponent(decoded).standardizedFileURL
        let root = rootDirectory.standardizedFileURL
        let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard url.path == root.path || url.path.hasPrefix(rootPrefix) else {
            throw EPUBPackageError.invalidResourcePath(path)
        }
        return url
    }
}

private struct EPUBHeading {
    let title: String
    let level: Int
}

private final class EPUBHeadingParser: NSObject, XMLParserDelegate {
    private var activeHeading: Int?
    private var headingText = ""
    private var result: EPUBHeading?

    static func parse(_ data: Data) -> EPUBHeading? {
        let parser = XMLParser(data: data)
        let delegate = EPUBHeadingParser()
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { return nil }
        return delegate.result
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        guard activeHeading == nil, result == nil,
              let level = Int(elementName.split(separator: ":").last?.dropFirst() ?? Substring("")),
              (1...6).contains(level), elementName.lowercased().hasSuffix("h\(level)") else { return }
        activeHeading = level
        headingText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if activeHeading != nil { headingText += string }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if activeHeading != nil, let text = String(data: CDATABlock, encoding: .utf8) { headingText += text }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard let level = activeHeading,
              elementName.lowercased().hasSuffix("h\(level)") else { return }
        let title = headingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { result = EPUBHeading(title: title, level: level) }
        activeHeading = nil
    }
}

private struct EPUBManifestItem {
    let id: String
    let href: String
    let mediaType: String
    let properties: Set<String>
}

private struct EPUBPackageInfo {
    var title: String?
    var items: [String: EPUBManifestItem] = [:]
    var spine: [String] = []
}

private final class ContainerRootfileParser: NSObject, XMLParserDelegate {
    private var path: String?

    static func parse(_ data: Data) throws -> String? {
        let parser = XMLParser(data: data)
        let delegate = ContainerRootfileParser()
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { throw parser.parserError ?? EPUBPackageError.invalidContainer }
        return delegate.path
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "rootfile" { path = attributeDict["full-path"] }
    }
}

private final class OPFPackageParser: NSObject, XMLParserDelegate {
    private var result = EPUBPackageInfo()
    private var readingTitle = false
    private var titleBuffer = ""

    static func parse(_ data: Data) throws -> EPUBPackageInfo? {
        let parser = XMLParser(data: data)
        let delegate = OPFPackageParser()
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { throw parser.parserError ?? EPUBPackageError.invalidPackage }
        return delegate.result.spine.isEmpty ? nil : delegate.result
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let localName = elementName.split(separator: ":").last.map(String.init) ?? elementName
        switch localName {
        case "title":
            readingTitle = true
            titleBuffer = ""
        case "item":
            guard let id = attributeDict["id"], let href = attributeDict["href"],
                  let mediaType = attributeDict["media-type"] else { return }
            result.items[id] = EPUBManifestItem(id: id, href: href, mediaType: mediaType,
                                                properties: Set((attributeDict["properties"] ?? "").split(separator: " ").map(String.init)))
        case "itemref":
            if let id = attributeDict["idref"] { result.spine.append(id) }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if readingTitle { titleBuffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if (elementName.split(separator: ":").last.map(String.init) ?? elementName) == "title" {
            if result.title == nil { result.title = titleBuffer.trimmingCharacters(in: .whitespacesAndNewlines) }
            readingTitle = false
        }
    }
}

private final class EPUBNavigationParser: NSObject, XMLParserDelegate {
    private var listDepth = 0
    private var activeHref: String?
    private var activeTitle = ""
    private var items: [EPUBTOCItem] = []

    static func parse(_ data: Data) -> [EPUBTOCItem] {
        let parser = XMLParser(data: data)
        let delegate = EPUBNavigationParser()
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { return [] }
        return delegate.items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "ol" { listDepth += 1 }
        if elementName == "a", let href = attributeDict["href"] {
            activeHref = href
            activeTitle = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if activeHref != nil { activeTitle += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "a", let href = activeHref {
            let title = activeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { items.append(EPUBTOCItem(title: title, href: href, level: max(0, listDepth - 1))) }
            activeHref = nil
            activeTitle = ""
        }
        if elementName == "ol" { listDepth = max(0, listDepth - 1) }
    }
}

private final class EPUBNCXNavigationParser: NSObject, XMLParserDelegate {
    private struct Node { let depth: Int; let order: Int; var title = ""; var href: String? }
    private var stack: [Node] = []
    private var order = 0
    private var readingLabel = false
    private var items: [(Int, EPUBTOCItem)] = []

    static func parse(_ data: Data) -> [EPUBTOCItem] {
        let parser = XMLParser(data: data)
        let delegate = EPUBNCXNavigationParser()
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { return [] }
        return delegate.items.sorted { $0.0 < $1.0 }.map(\.1)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if name == "navPoint" {
            order += 1
            stack.append(Node(depth: stack.count, order: order))
        } else if name == "navLabel", !stack.isEmpty {
            readingLabel = true
        } else if name == "content", !stack.isEmpty {
            stack[stack.count - 1].href = attributeDict["src"]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if readingLabel, !stack.isEmpty { stack[stack.count - 1].title += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if name == "navLabel" { readingLabel = false }
        if name == "navPoint", let node = stack.popLast() {
            if let href = node.href {
                let title = node.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty { items.append((node.order, EPUBTOCItem(title: title, href: href, level: node.depth))) }
            }
        }
    }
}

private final class EPUBEncryptionParser: NSObject, XMLParserDelegate {
    private var algorithm: String?
    private var resource: String?
    private var encryptedResources: [(String, String)] = []

    static func hasUnsupportedContentEncryption(_ data: Data) -> Bool {
        let parser = XMLParser(data: data)
        let delegate = EPUBEncryptionParser()
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse() else { return true }
        return delegate.encryptedResources.contains { algorithm, resource in
            let value = algorithm.lowercased()
            let isStandardFontObfuscation = value.contains("idpf.org/2008/embedding") || value.contains("ns.adobe.com/pdf/enc#rc")
            return !isStandardFontObfuscation && ["xhtml", "html", "htm", "css"].contains(URL(fileURLWithPath: resource).pathExtension.lowercased())
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let localName = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if localName == "EncryptedData" { algorithm = nil; resource = nil }
        if localName == "EncryptionMethod" { algorithm = attributeDict["Algorithm"] }
        if localName == "CipherReference" { resource = attributeDict["URI"] }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let localName = elementName.split(separator: ":").last.map(String.init) ?? elementName
        if localName == "EncryptedData", let algorithm, let resource {
            encryptedResources.append((algorithm, resource))
        }
    }
}
