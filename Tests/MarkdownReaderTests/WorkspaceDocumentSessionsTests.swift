import Foundation
import Testing
@testable import MarkdownReader

struct WorkspaceDocumentSessionsTests {
    @Test @MainActor func documentsHaveIndependentContentAndSharedViews() throws {
        let sessions = WorkspaceDocumentSessions()
        let firstURL = URL(fileURLWithPath: "/tmp/workspace-tests/a.md")
        let secondURL = URL(fileURLWithPath: "/tmp/workspace-tests/b.md")
        let first = try sessions.openMarkdown(firstURL) { _ in "first" }
        let second = try sessions.openMarkdown(secondURL) { _ in "second" }
        let anotherView = try sessions.openMarkdown(firstURL) { _ in Issue.record("A second view must not reload the file"); return "" }
        first.text = "first edited"
        first.selection = NSRange(location: 4, length: 0)
        first.position.selection = NSRange(location: 7, length: 0)
        #expect(anotherView === first)
        #expect(anotherView.text == "first edited")
        #expect(second.text == "second")
        #expect(second.selection.location == 0)
        #expect(anotherView.position.selection?.location == 7)
        #expect(second.position.selection == nil)
        #expect(second.position.documentPath == secondURL.standardizedFileURL.resolvingSymlinksInPath().path)
        #expect(first.isDirty && !second.isDirty)
        #expect(!sessions.removeMarkdown(firstURL))
        #expect(sessions.session(for: firstURL) === first)
        #expect(sessions.removeMarkdown(firstURL, discardingChanges: true))
    }

    @Test @MainActor func savingOlderSnapshotDoesNotMarkNewTypingSaved() throws {
        let sessions = WorkspaceDocumentSessions()
        let session = try sessions.openMarkdown(URL(fileURLWithPath: "/tmp/workspace-tests/a.md")) { _ in "original" }
        session.text = "snapshot"
        let writing = session.text
        session.text = "snapshot and new typing"
        session.markSaved(writing)
        #expect(session.isDirty)
        session.markSaved(session.text)
        #expect(!session.isDirty)
    }

    @Test @MainActor func symlinkAndOriginalShareOneEditingSession() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("original.md")
        let link = root.appendingPathComponent("alias.md")
        try "hello".write(to: original, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: original)
        let sessions = WorkspaceDocumentSessions()
        let first = try sessions.openMarkdown(original) { try String(contentsOf: $0, encoding: .utf8) }
        let second = try sessions.openMarkdown(link) { _ in Issue.record("The linked file was reopened"); return "" }
        first.text = "changed"
        #expect(first === second)
        #expect(second.text == "changed")
        #expect(!sessions.removeMarkdown(link))
    }

    @Test @MainActor func externalChangesAreNotOverwrittenOnSave() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("note.md")
        try "original".write(to: file, atomically: true, encoding: .utf8)
        let sessions = WorkspaceDocumentSessions()
        let session = try sessions.openMarkdown(file) { try String(contentsOf: $0, encoding: .utf8) }
        session.text = "edited in app"
        try "edited externally".write(to: file, atomically: true, encoding: .utf8)
        #expect(throws: WorkspaceMarkdownSession.SaveError.changedOnDisk) { try session.save() }
        #expect(try String(contentsOf: file, encoding: .utf8) == "edited externally")
        #expect(session.isDirty)
    }
}
