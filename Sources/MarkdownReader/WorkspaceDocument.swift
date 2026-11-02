import Foundation

struct WorkspaceReadingNoteLink: Codable, Equatable, Identifiable {
    var readingURL: URL
    var noteURL: URL
    var id: String { readingURL.standardizedFileURL.path }
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
        readingNotes = try container.decodeIfPresent([WorkspaceReadingNoteLink].self, forKey: .readingNotes) ?? []
        chapterLinks = try container.decodeIfPresent([WorkspaceChapterLink].self, forKey: .chapterLinks) ?? []
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
            let path = url.standardizedFileURL.path
            guard seen.insert(path).inserted else { return false }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return true }
            return folders.contains(where: { $0.standardizedFileURL.path == path }) && !isDirectory.boolValue
        }
    }
}
