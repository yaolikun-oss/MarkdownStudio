import CryptoKit
import Foundation

struct WorkspaceChapterLink: Codable, Equatable, Identifiable {
    var id: UUID
    var readingURL: URL
    var readingFingerprint: String
    var chapterHref: String
    var fragment: String?
    var chapterTitle: String
    var noteURL: URL
    var markerID: UUID
    var headingTitle: String
    var headingLevel: Int

    init(id: UUID = UUID(), readingURL: URL, readingFingerprint: String,
         chapterHref: String, fragment: String?, chapterTitle: String,
         noteURL: URL, markerID: UUID = UUID(), headingTitle: String,
         headingLevel: Int) {
        self.id = id
        self.readingURL = readingURL.standardizedFileURL
        self.readingFingerprint = readingFingerprint
        self.chapterHref = chapterHref
        self.fragment = fragment
        self.chapterTitle = chapterTitle
        self.noteURL = noteURL.standardizedFileURL
        self.markerID = markerID
        self.headingTitle = headingTitle
        self.headingLevel = headingLevel
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
