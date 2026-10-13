import Foundation

/// A stable document boundary shared by the read-only view and a future editor.
/// The current reader uses `LocalMarkdownDocumentStore`; editing operations are
/// intentionally not implemented in this release.
protocol MarkdownDocumentStore {
    func openDocument(at url: URL) throws -> MarkdownDocument
    func listMarkdownDocuments(in folder: URL) throws -> [URL]
}

/// Optional capability for a future editing mode. Keeping writes out of the
/// reader store prevents view code from accidentally changing source files.
protocol MarkdownDocumentEditing: MarkdownDocumentStore {
    func save(_ document: MarkdownDocument, to url: URL) throws
}

struct MarkdownDocument: Identifiable {
    let url: URL
    let source: String
    var id: String { url.standardizedFileURL.path }
    var title: String { url.deletingPathExtension().lastPathComponent }
}

struct LocalMarkdownDocumentStore: MarkdownDocumentEditing {
    func openDocument(at url: URL) throws -> MarkdownDocument {
        MarkdownDocument(url: url, source: try String(contentsOf: url, encoding: .utf8))
    }

    func listMarkdownDocuments(in folder: URL) throws -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        let found = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])?.allObjects as? [URL] ?? []
        return found.filter { ["md", "markdown"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    func save(_ document: MarkdownDocument, to url: URL) throws {
        try document.source.write(to: url, atomically: true, encoding: .utf8)
    }
}
