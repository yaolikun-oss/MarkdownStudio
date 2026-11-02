import Foundation

struct WorkspaceReadingNoteLink: Codable, Equatable, Identifiable {
    var readingURL: URL
    var noteURL: URL
    var id: String { readingURL.workspaceIdentityPath }

    init(readingURL: URL, noteURL: URL) {
        self.readingURL = readingURL.workspaceIdentityURL
        self.noteURL = noteURL.workspaceIdentityURL
    }
}

enum WorkspaceReadingNoteLinks {
    /// A reading source owns one companion note. Older builds could encode the
    /// same unpacked EPUB twice because Foundation distinguished directory and
    /// file-style URLs with the same path. Prefer an existing note and remove
    /// the stale duplicate that otherwise blocks workspace autosave.
    static func normalized(_ links: [WorkspaceReadingNoteLink],
                           fileManager: FileManager = .default) -> [WorkspaceReadingNoteLink] {
        var order: [String] = []
        var groups: [String: [WorkspaceReadingNoteLink]] = [:]
        for link in links {
            let key = link.readingURL.workspaceIdentityPath
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(WorkspaceReadingNoteLink(
                readingURL: link.readingURL, noteURL: link.noteURL))
        }
        return order.compactMap { key in
            guard let candidates = groups[key], !candidates.isEmpty else { return nil }
            return candidates.first(where: { fileManager.fileExists(atPath: $0.noteURL.path) })
                ?? candidates.first
        }
    }
}

/// A workspace stores references and layout only; document contents remain in
/// their original files and keep their existing save and close behavior.
struct WorkspaceDocument: Codable, Equatable {
    static let currentVersion = 1
    var version = currentVersion
    var folders: [URL]
    var files: [URL] = []
    var layout: WorkspaceGridLayout
    var readingNotes: [WorkspaceReadingNoteLink] = []
    var chapterLinks: [WorkspaceChapterLink] = []

    init(version: Int = Self.currentVersion, folders: [URL], files: [URL] = [],
         layout: WorkspaceGridLayout, readingNotes: [WorkspaceReadingNoteLink] = [],
         chapterLinks: [WorkspaceChapterLink] = []) {
        self.version = version
        self.folders = folders
        self.files = files
        self.layout = layout
        self.readingNotes = readingNotes
        self.chapterLinks = chapterLinks
    }

    private enum CodingKeys: String, CodingKey { case version, folders, files, layout, readingNotes, chapterLinks }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        folders = try container.decodeIfPresent([URL].self, forKey: .folders) ?? []
        files = try container.decodeIfPresent([URL].self, forKey: .files) ?? []
        layout = try container.decode(WorkspaceGridLayout.self, forKey: .layout)
        let decodedNotes = try container.decodeIfPresent([WorkspaceReadingNoteLink].self, forKey: .readingNotes) ?? []
        readingNotes = WorkspaceReadingNoteLinks.normalized(decodedNotes)
        chapterLinks = (try container.decodeIfPresent([WorkspaceChapterLink].self, forKey: .chapterLinks) ?? [])
            .map { link in
                var normalized = link
                normalized.readingURL = link.readingURL.workspaceIdentityURL
                normalized.noteURL = link.noteURL.workspaceIdentityURL
                return normalized
            }
    }

    var isValid: Bool {
        version == Self.currentVersion && layout.isValid && folders.allSatisfy(\.isFileURL) && files.allSatisfy(\.isFileURL)
    }

    var missingFiles: [URL] {
        let resources = folders + files + readingNotes.flatMap { [$0.readingURL, $0.noteURL] }
            + chapterLinks.flatMap { [$0.readingURL, $0.noteURL] } + layout.allTabs.compactMap { tab in
            tab.kind == .web ? nil : tab.location
        }
        var seen = Set<String>()
        return resources.filter { url in
            let path = url.workspaceIdentityPath
            guard seen.insert(path).inserted else { return false }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return true }
            return folders.contains(where: { $0.standardizedFileURL.path == path }) && !isDirectory.boolValue
        }
    }
}
