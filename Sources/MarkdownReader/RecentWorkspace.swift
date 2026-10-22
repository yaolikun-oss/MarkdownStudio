import Foundation

/// A pair of files the user actually had open together. Paths are stored as
/// opened; a matching basename alone is never used to infer a notebook.
struct RecentWorkspace: Codable, Equatable, Identifiable {
    let readingPath: String?
    let notePath: String?
    var openedAt: Date

    var id: String { "\(readingPath ?? "")\u{0}\(notePath ?? "")" }
    var readingURL: URL? { readingPath.map { URL(fileURLWithPath: $0) } }
    var noteURL: URL? { notePath.map { URL(fileURLWithPath: $0) } }
    var title: String {
        if let readingURL { return readingURL.deletingPathExtension().lastPathComponent }
        return noteURL?.deletingPathExtension().lastPathComponent ?? "未命名文件"
    }
    var subtitle: String {
        switch (readingURL, noteURL) {
        case let (reading?, note?): "\(reading.lastPathComponent)  +  \(note.lastPathComponent)"
        case let (reading?, nil): reading.lastPathComponent
        case let (nil, note?): note.lastPathComponent
        case (nil, nil): ""
        }
    }

    init(readingURL: URL?, noteURL: URL?, openedAt: Date = .now) {
        readingPath = readingURL?.standardizedFileURL.path
        notePath = noteURL?.standardizedFileURL.path
        self.openedAt = openedAt
    }
}

enum RecentWorkspaceHistory {
    static let limit = 20

    static func decode(_ data: Data) -> [RecentWorkspace] {
        (try? JSONDecoder().decode([RecentWorkspace].self, from: data)) ?? []
    }

    static func record(_ workspace: RecentWorkspace, in history: [RecentWorkspace]) -> [RecentWorkspace] {
        guard workspace.readingPath != nil || workspace.notePath != nil else { return history }
        return ([workspace] + history.filter { $0.id != workspace.id }).prefix(limit).map { $0 }
    }
}
