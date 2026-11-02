import CryptoKit
import Foundation

struct WorkspaceChapterLink: Codable, Equatable, Identifiable {
    var id: UUID
    var readingURL: URL
    var readingFingerprint: String
    var chapterHref: String
    var fragment: String?
    var readingAnchorID: String?
    var chapterTitle: String
    var noteURL: URL
    var markerID: UUID
    var headingTitle: String
    var headingLevel: Int

    init(id: UUID = UUID(), readingURL: URL, readingFingerprint: String,
         chapterHref: String, fragment: String?, readingAnchorID: String? = nil, chapterTitle: String,
         noteURL: URL, markerID: UUID = UUID(), headingTitle: String,
         headingLevel: Int) {
        self.id = id
        self.readingURL = readingURL.workspaceIdentityURL
        self.readingFingerprint = readingFingerprint
        self.chapterHref = chapterHref
        self.fragment = fragment
        self.readingAnchorID = readingAnchorID
        self.chapterTitle = chapterTitle
        self.noteURL = noteURL.workspaceIdentityURL
        self.markerID = markerID
        self.headingTitle = headingTitle
        self.headingLevel = headingLevel
    }
}

enum WorkspaceChapterLinks {
    static func upserting(_ link: WorkspaceChapterLink, into links: [WorkspaceChapterLink]) -> [WorkspaceChapterLink] {
        links.filter { existing in
            // A concrete TOC row has one current destination, so reconnecting
            // a mistaken row updates that row. Different TOC rows remain
            // independent even when the EPUB maps them to one XHTML page.
            if link.readingAnchorID != nil { return !sameReadingAnchor(existing, link) }
            // Legacy/current-position links have no TOC identity. Only replace
            // the exact pair because identical XHTML targets may represent
            // several distinct rows in older saved workspaces.
            return !sameAssociation(existing, link)
        } + [link]
    }

    static func link(for readingURL: URL, chapterHref: String, fragment: String?,
                     readingAnchorID: String? = nil,
                     in links: [WorkspaceChapterLink]) -> WorkspaceChapterLink? {
        if let readingAnchorID,
           let anchored = links.last(where: {
               $0.readingURL.workspaceIdentityPath == readingURL.workspaceIdentityPath
                   && $0.readingAnchorID == readingAnchorID
           }) {
            return anchored
        }
        return links.last {
            $0.readingURL.workspaceIdentityPath == readingURL.workspaceIdentityPath
                && $0.chapterHref == chapterHref && $0.fragment == fragment
        }
    }

    static func link(for noteURL: URL, markerID: UUID,
                     in links: [WorkspaceChapterLink]) -> WorkspaceChapterLink? {
        links.last {
            $0.noteURL.workspaceIdentityPath == noteURL.workspaceIdentityPath && $0.markerID == markerID
        }
    }

    static func isMarkerReferenced(noteURL: URL, markerID: UUID,
                                   in links: [WorkspaceChapterLink]) -> Bool {
        links.contains {
            $0.noteURL.workspaceIdentityPath == noteURL.workspaceIdentityPath && $0.markerID == markerID
        }
    }

    private static func sameAssociation(_ lhs: WorkspaceChapterLink, _ rhs: WorkspaceChapterLink) -> Bool {
        lhs.readingURL.workspaceIdentityPath == rhs.readingURL.workspaceIdentityPath
            && lhs.chapterHref == rhs.chapterHref && lhs.fragment == rhs.fragment
            && lhs.noteURL.workspaceIdentityPath == rhs.noteURL.workspaceIdentityPath
            && lhs.markerID == rhs.markerID
    }

    private static func sameReadingAnchor(_ lhs: WorkspaceChapterLink, _ rhs: WorkspaceChapterLink) -> Bool {
        lhs.readingURL.workspaceIdentityPath == rhs.readingURL.workspaceIdentityPath
            && lhs.readingAnchorID != nil && lhs.readingAnchorID == rhs.readingAnchorID
    }
}

enum WorkspaceEPUBTOCIdentity {
    static func make(index: Int, level: Int, href: String, title: String) -> String {
        "toc:\(index):\(level):\(href):\(title)"
    }
}

extension URL {
    /// File URLs can decode to distinct Foundation values depending on whether
    /// they were created as a directory (a trailing slash) even though their
    /// paths are identical. Workspace identities intentionally ignore that
    /// representation detail.
    var workspaceIdentityPath: String {
        standardizedFileURL.resolvingSymlinksInPath().path
    }

    var workspaceIdentityURL: URL {
        URL(fileURLWithPath: workspaceIdentityPath)
    }
}

enum WorkspaceMarkdownHeadingResolver {
    static func heading(in blocks: [MarkdownBlock], source: String, selection: NSRange?,
                        fallbackSourceLine: Int) -> MarkdownBlock? {
        let line: Int
        if let selection {
            let text = source as NSString
            let location = min(max(0, selection.location), text.length)
            line = text.substring(to: location).components(separatedBy: "\n").count
        } else {
            line = fallbackSourceLine
        }
        return blocks.last { $0.headingLevel != nil && $0.sourceLine <= line }
            ?? blocks.first(where: { $0.headingLevel != nil })
    }
}

struct WorkspaceMarkdownHeadingReference {
    let level: Int
    let title: String
    let ordinal: Int

    init?(heading: MarkdownBlock, in blocks: [MarkdownBlock]) {
        guard let level = heading.headingLevel, let title = heading.title else { return nil }
        let matches = blocks.filter { $0.headingLevel == level && $0.title == title }
        guard let ordinal = matches.firstIndex(where: { $0.sourceLine == heading.sourceLine }) else { return nil }
        self.level = level
        self.title = title
        self.ordinal = ordinal
    }

    func resolve(in blocks: [MarkdownBlock]) -> MarkdownBlock? {
        let matches = blocks.filter { $0.headingLevel == level && $0.title == title }
        guard matches.indices.contains(ordinal) else { return nil }
        return matches[ordinal]
    }
}

enum WorkspaceChapterMarker {
    static func text(_ id: UUID) -> String { "<!-- mdstudio-chapter-link:\(id.uuidString.lowercased()) -->" }

    static func markerID(after heading: MarkdownBlock, in source: String) -> UUID? {
        let lines = source.components(separatedBy: "\n")
        let first = min(lines.count, max(0, heading.sourceLine))
        for index in first..<min(lines.count, first + 2) {
            if let id = markerID(in: lines[index]) { return id }
        }
        return nil
    }

    static func inserting(_ markerID: UUID, after heading: MarkdownBlock, in source: String) -> String {
        if markerLine(markerID, in: source) != nil { return source }
        var lines = source.components(separatedBy: "\n")
        let insertion = min(lines.count, max(0, heading.sourceLine))
        lines.insert(text(markerID), at: insertion)
        return lines.joined(separator: "\n")
    }

    static func heading(for markerID: UUID, blocks: [MarkdownBlock], source: String) -> MarkdownBlock? {
        guard let markerLine = markerLine(markerID, in: source) else { return nil }
        return blocks.last { block in
            block.headingLevel != nil && block.sourceLine < markerLine
        }
    }

    static func markerLine(_ markerID: UUID, in source: String) -> Int? {
        let needle = text(markerID)
        return source.components(separatedBy: "\n").firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == needle }).map { $0 + 1 }
    }

    static func removing(_ markerID: UUID, from source: String) -> String {
        var lines = source.components(separatedBy: "\n")
        guard let index = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == text(markerID)
        }) else { return source }
        lines.remove(at: index)
        return lines.joined(separator: "\n")
    }

    private static func markerID(in line: String) -> UUID? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let prefix = "<!-- mdstudio-chapter-link:"
        let suffix = " -->"
        guard trimmed.hasPrefix(prefix), trimmed.hasSuffix(suffix) else { return nil }
        let value = String(trimmed.dropFirst(prefix.count).dropLast(suffix.count))
        return UUID(uuidString: value)
    }
}

enum WorkspaceResourceFingerprint {
    static func make(for url: URL, fileManager: FileManager = .default) throws -> String {
        var hasher = SHA256()
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw CocoaError(.fileNoSuchFile)
        }
        if isDirectory.boolValue {
            let root = url.standardizedFileURL
            let resources = (fileManager.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles])?.allObjects as? [URL] ?? [])
                .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
                .sorted { $0.path < $1.path }
            for resource in resources {
                let relative = String(resource.path.dropFirst(root.path.count))
                hasher.update(data: Data(relative.utf8))
                try update(&hasher, from: resource)
            }
        } else {
            try update(&hasher, from: url)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func update(_ hasher: inout SHA256, from url: URL) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        while true {
            let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
    }
}
