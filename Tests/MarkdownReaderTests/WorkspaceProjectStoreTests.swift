import Foundation
import Testing
@testable import MarkdownReader

struct WorkspaceProjectStoreTests {
    @Test func fileAndFolderProjectsAreStableAndDoNotModifyTheStudyFolder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let study = root.appendingPathComponent("学习主题", isDirectory: true)
        let storage = root.appendingPathComponent("manifests", isDirectory: true)
        try FileManager.default.createDirectory(at: study, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let note = study.appendingPathComponent("笔记.md")
        try Data("# 内容".utf8).write(to: note)
        let store = WorkspaceProjectStore(directory: storage)
        let first = try store.ensureProject(for: note, isFolder: false, layout: WorkspaceGridLayout())
        let again = try store.ensureProject(for: note, isFolder: false, layout: WorkspaceGridLayout())
        #expect(first.0 == again.0)
        #expect(first.1.files == [note.standardizedFileURL])
        let studyItems = try FileManager.default.contentsOfDirectory(at: study, includingPropertiesForKeys: nil)
        #expect(studyItems.map(\.lastPathComponent) == ["笔记.md"])
        let folder = try store.ensureProject(for: study, isFolder: true, layout: WorkspaceGridLayout())
        #expect(folder.1.folders == [study.standardizedFileURL])
        #expect(folder.0 != first.0)
    }
}
