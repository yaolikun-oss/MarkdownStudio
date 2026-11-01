import Foundation
import Combine

/// Shared state for one Markdown file, independent of its tabs and windows.
/// Source and visual tabs for the same URL must refer to the same session.
@MainActor final class WorkspaceMarkdownSession: ObservableObject {
    enum SaveError: Error, Equatable { case changedOnDisk }
    let url: URL
    @Published var text: String
    @Published private(set) var savedText: String
    @Published var selection: NSRange
    /// Each document owns its visual/source viewport; switching documents must
    /// never restore an offset or selection captured from another document.
    let position = MarkdownVisualScrollState()

    init(url: URL, text: String, selection: NSRange = NSRange(location: 0, length: 0)) {
        self.url = url.standardizedFileURL.resolvingSymlinksInPath()
        self.text = text
        self.savedText = text
        self.selection = selection
        position.reset(for: self.url)
    }

    var isDirty: Bool { text != savedText }

    /// Called only after the corresponding content has been written to disk.
    /// If the user typed while the write was in progress, the new text stays dirty.
    func markSaved(_ writtenText: String) { savedText = writtenText }

    /// Do not silently overwrite edits made by another program or window.
    func save(using store: LocalMarkdownDocumentStore = LocalMarkdownDocumentStore()) throws {
        guard try store.openDocument(at: url).source == savedText else { throw SaveError.changedOnDisk }
        let writtenText = text
        try store.save(MarkdownDocument(url: url, source: writtenText), to: url)
        markSaved(writtenText)
    }
}

@MainActor final class WorkspaceDocumentSessions: ObservableObject {
    @Published private(set) var markdown: [URL: WorkspaceMarkdownSession] = [:]

    func session(for url: URL) -> WorkspaceMarkdownSession? {
        markdown[url.standardizedFileURL.resolvingSymlinksInPath()]
    }

    func openMarkdown(_ url: URL, load: (URL) throws -> String) throws -> WorkspaceMarkdownSession {
        let key = url.standardizedFileURL.resolvingSymlinksInPath()
        if let existing = markdown[key] { return existing }
        let session = WorkspaceMarkdownSession(url: key, text: try load(key))
        markdown[key] = session
        return session
    }

    /// Adopt text which has already been loaded by the legacy document path.
    /// Existing sessions always win so selecting another tab can never replace
    /// unsaved text with an older disk snapshot.
    func adoptMarkdown(_ url: URL, text: String) -> WorkspaceMarkdownSession {
        let key = url.standardizedFileURL.resolvingSymlinksInPath()
        if let existing = markdown[key] { return existing }
        let session = WorkspaceMarkdownSession(url: key, text: text)
        markdown[key] = session
        return session
    }

    var dirtySessions: [WorkspaceMarkdownSession] { markdown.values.filter(\.isDirty) }

    func removeAll(discardingChanges: Bool = false) -> Bool {
        guard discardingChanges || dirtySessions.isEmpty else { return false }
        markdown.removeAll()
        return true
    }

    /// A dirty session cannot be discarded accidentally when its last view closes.
    @discardableResult func removeMarkdown(_ url: URL, discardingChanges: Bool = false) -> Bool {
        let key = url.standardizedFileURL.resolvingSymlinksInPath()
        guard let session = markdown[key] else { return true }
        guard !session.isDirty || discardingChanges else { return false }
        markdown.removeValue(forKey: key)
        return true
    }
}
