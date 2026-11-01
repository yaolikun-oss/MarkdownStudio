import Foundation
import Testing
@testable import MarkdownReader

@Suite struct WorkspaceResourceImporterTests {
    @Test func verifiedCopiesReuseIdenticalInputAndNeverOverwriteDifferentContent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sources = root.appendingPathComponent("sources", isDirectory: true)
        let reading = root.appendingPathComponent("project/阅读资料", isDirectory: true)
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let first = sources.appendingPathComponent("book.pdf")
        try Data("first".utf8).write(to: first)
        let imported = try WorkspaceResourceImporter.copyVerified(first, into: reading)
        #expect(FileManager.default.contentsEqual(atPath: first.path, andPath: imported.path))
        #expect(try WorkspaceResourceImporter.copyVerified(first, into: reading) == imported)

        let secondSourceFolder = root.appendingPathComponent("other", isDirectory: true)
        try FileManager.default.createDirectory(at: secondSourceFolder, withIntermediateDirectories: true)
        let second = secondSourceFolder.appendingPathComponent("book.pdf")
        try Data("second".utf8).write(to: second)
        let importedSecond = try WorkspaceResourceImporter.copyVerified(second, into: reading)
        #expect(importedSecond.lastPathComponent == "book-2.pdf")
        #expect(String(data: try Data(contentsOf: imported), encoding: .utf8) == "first")
        #expect(String(data: try Data(contentsOf: importedSecond), encoding: .utf8) == "second")
    }

    @Test func reusableWorkspaceRequiresManifestAndByteIdenticalProjectCopy() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = base.appendingPathComponent("outside/主题:资料.pdf")
        try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("content".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: base) }

        let name = WorkspaceResourceImporter.sanitizedWorkspaceName("主题:资料")
        #expect(name == "主题-资料")
        let root = base.appendingPathComponent(name, isDirectory: true)
        let reading = root.appendingPathComponent("阅读资料", isDirectory: true)
        try FileManager.default.createDirectory(at: reading, withIntermediateDirectories: true)
        try Data().write(to: root.appendingPathComponent("\(name).mdworkspace"))
        try FileManager.default.copyItem(at: source, to: reading.appendingPathComponent(source.lastPathComponent))

        #expect(WorkspaceResourceImporter.reusableWorkspaceRoot(for: source, in: base) == root)
        let next = WorkspaceResourceImporter.nextWorkspaceRoot(named: name, in: base)
        #expect(next.lastPathComponent == "\(name) 2")
    }
}
