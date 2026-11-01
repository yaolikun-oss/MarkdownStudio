import Foundation
import SwiftUI
import Testing
@testable import MarkdownReader

struct MarkdownNoteHierarchyTests {
    @Test func savingDeletedSourceLinksMovesAllChildrenAndRollsBackOnFailure() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let trash = dir.appendingPathComponent("trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let parent = dir.appendingPathComponent("parent.md")
        let (first, link1) = try MarkdownNoteHierarchy.inlineLink(parent: parent, title: "甲", label: "甲")
        let (second, link2) = try MarkdownNoteHierarchy.inlineLink(parent: parent, title: "乙", label: "乙")
        try FileManager.default.createDirectory(at: first.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "一".write(to: first, atomically: true, encoding: .utf8)
        try "二".write(to: second, atomically: true, encoding: .utf8)
        let before = "\(link1)\n\n\(link2)\n\n[外部](other.md)"
        let after = "[外部](other.md)"
        try before.write(to: parent, atomically: true, encoding: .utf8)
        let removed = MarkdownNoteDeletion.removedChildren(parent: parent, before: before, after: after)
        #expect(removed.count == 2)
        #expect(MarkdownNoteDeletion.removedChildren(parent: parent, before: before, after: link1).count == 1)
        #expect(throws: (any Error).self) {
            try MarkdownNoteDeletion.saveRemovingChildren(parent: parent, before: before, after: after, children: removed) { item in
                if item.lastPathComponent == "乙.md" { throw CocoaError(.fileWriteNoPermission) }
                let target = trash.appendingPathComponent(item.lastPathComponent)
                try FileManager.default.moveItem(at: item, to: target); return target
            }
        }
        #expect(FileManager.default.fileExists(atPath: first.path))
        #expect(try String(contentsOf: parent, encoding: .utf8) == before)
        try MarkdownNoteDeletion.saveRemovingChildren(parent: parent, before: before, after: after, children: removed) { item in
            let target = trash.appendingPathComponent(item.lastPathComponent)
            try FileManager.default.moveItem(at: item, to: target); return target
        }
        #expect(!FileManager.default.fileExists(atPath: first.path))
        #expect(!FileManager.default.fileExists(atPath: second.path))
        #expect(try String(contentsOf: parent, encoding: .utf8) == after)
    }
    @Test func deletingOwnedBlockMovesNoteAndDescendantsAndKeepsSurroundingText() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let trash = dir.appendingPathComponent("trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let parent = dir.appendingPathComponent("父.md")
        let (child, link) = try MarkdownNoteHierarchy.inlineLink(parent: parent, title: "解释", label: "概念")
        try FileManager.default.createDirectory(at: child.deletingLastPathComponent(), withIntermediateDirectories: true)
        let subtree = MarkdownNoteHierarchy.childrenDirectory(of: child)
        try FileManager.default.createDirectory(at: subtree, withIntermediateDirectories: true)
        try "下级内容".write(to: subtree.appendingPathComponent("下级.md"), atomically: true, encoding: .utf8)
        try "解释内容".write(to: child, atomically: true, encoding: .utf8)
        let source = "句首\(link)句尾。"
        try source.write(to: parent, atomically: true, encoding: .utf8)
        let result = try MarkdownNoteDeletion.perform(parent: parent, child: child, parentSource: source, expectedDisk: source, requireManaged: true) { item in
            let target = trash.appendingPathComponent(item.lastPathComponent)
            try FileManager.default.moveItem(at: item, to: target)
            return target
        }
        #expect(result.parentSource == "句首句尾。")
        #expect(try String(contentsOf: parent, encoding: .utf8) == "句首句尾。")
        #expect(!FileManager.default.fileExists(atPath: child.path))
        #expect(FileManager.default.fileExists(atPath: trash.appendingPathComponent("解释.md").path))
        #expect(FileManager.default.fileExists(atPath: trash.appendingPathComponent("解释.md.notes/下级.md").path))
    }

    @Test func deletionFailureRestoresMovedDescendantsAndPreservesParent() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let trash = dir.appendingPathComponent("trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        let parent = dir.appendingPathComponent("父.md")
        let (child, link) = try MarkdownNoteHierarchy.inlineLink(parent: parent, title: "解释", label: "概念")
        let subtree = MarkdownNoteHierarchy.childrenDirectory(of: child)
        try FileManager.default.createDirectory(at: subtree, withIntermediateDirectories: true)
        try "下级".write(to: subtree.appendingPathComponent("下级.md"), atomically: true, encoding: .utf8)
        try "正文".write(to: child, atomically: true, encoding: .utf8)
        try link.write(to: parent, atomically: true, encoding: .utf8)
        #expect(throws: (any Error).self) {
            try MarkdownNoteDeletion.perform(parent: parent, child: child, parentSource: link, expectedDisk: link, requireManaged: true) { item in
                if item == child { throw CocoaError(.fileWriteNoPermission) }
                let target = trash.appendingPathComponent(item.lastPathComponent)
                try FileManager.default.moveItem(at: item, to: target)
                return target
            }
        }
        #expect(FileManager.default.fileExists(atPath: subtree.appendingPathComponent("下级.md").path))
        #expect(FileManager.default.fileExists(atPath: child.path))
        #expect(try String(contentsOf: parent, encoding: .utf8) == link)
    }

    @Test func deletionRejectsDuplicateReferencesAndExternalChanges() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let parent = dir.appendingPathComponent("父.md")
        let (child, link) = try MarkdownNoteHierarchy.inlineLink(parent: parent, title: "解释", label: "概念")
        try FileManager.default.createDirectory(at: child.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "正文".write(to: child, atomically: true, encoding: .utf8)
        let duplicate = "\(link) 和 \(link)"
        try duplicate.write(to: parent, atomically: true, encoding: .utf8)
        #expect(throws: MarkdownNoteDeletion.Failure.self) {
            try MarkdownNoteDeletion.perform(parent: parent, child: child, parentSource: duplicate, expectedDisk: duplicate, requireManaged: true)
        }
        #expect(throws: MarkdownNoteDeletion.Failure.self) {
            try MarkdownNoteDeletion.perform(parent: parent, child: child, parentSource: link, expectedDisk: "过期", requireManaged: true)
        }
        #expect(FileManager.default.fileExists(atPath: child.path))
        #expect(try String(contentsOf: parent, encoding: .utf8) == duplicate)
    }

    @Test func deletionDoesNotTreatAnOrdinaryMarkdownLinkAsOwnedBlock() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let parent = dir.appendingPathComponent("parent.md")
        let child = MarkdownNoteHierarchy.childrenDirectory(of: parent).appendingPathComponent("child.md")
        try FileManager.default.createDirectory(at: child.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "不应被删除".write(to: child, atomically: true, encoding: .utf8)
        let source = "普通引用 [链接](parent.md.notes/child.md)"
        try source.write(to: parent, atomically: true, encoding: .utf8)
        #expect(throws: MarkdownNoteDeletion.Failure.self) {
            try MarkdownNoteDeletion.perform(parent: parent, child: child, parentSource: source, expectedDisk: source, requireManaged: true)
        }
        #expect(FileManager.default.fileExists(atPath: child.path))
        #expect(try String(contentsOf: parent, encoding: .utf8) == source)
    }
    @Test func inlineLinkPreservesLabelEncodesPathsAndAvoidsOverwriting() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let parent = dir.appendingPathComponent("父 (1).md")
        let directory = MarkdownNoteHierarchy.childrenDirectory(of: parent)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "已有内容".write(to: directory.appendingPathComponent("术语.md"), atomically: true, encoding: .utf8)
        let (child, link) = try MarkdownNoteHierarchy.inlineLink(parent: parent, title: "术语", label: "概念 [A]")
        #expect(child.lastPathComponent == "术语 2.md")
        #expect(link.hasPrefix("[概念 \\[A\\]]("))
        #expect(link.contains("%28"))
        #expect(link.contains("%20"))
        #expect(try String(contentsOf: directory.appendingPathComponent("术语.md"), encoding: .utf8) == "已有内容")
        #expect(throws: MarkdownNoteHierarchy.CreationError.self) {
            try MarkdownNoteHierarchy.inlineLink(parent: parent, title: "../不安全", label: "概念")
        }
    }
    @Test func childrenAndParentSurviveMovingWholeTree() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        let root = temporary.appendingPathComponent("书 (一).md")
        try "父笔记".write(to: root, atomically: true, encoding: .utf8)
        let children = MarkdownNoteHierarchy.childrenDirectory(of: root)
        try FileManager.default.createDirectory(at: children, withIntermediateDirectories: false)
        let child = children.appendingPathComponent("第一节.md")
        try "子笔记".write(to: child, atomically: true, encoding: .utf8)
        #expect(MarkdownNoteHierarchy.parent(of: child) == root)
        #expect(MarkdownNoteHierarchy.children(of: root).map { $0.resolvingSymlinksInPath() } == [child.resolvingSymlinksInPath()])
        #expect(MarkdownNoteHierarchy.root(of: child) == root)
        let moved = temporary.deletingLastPathComponent().appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: moved) }
        try FileManager.default.moveItem(at: temporary, to: moved)
        let movedChild = moved.appendingPathComponent("书 (一).md.notes/第一节.md")
        #expect(MarkdownNoteHierarchy.parent(of: movedChild) == moved.appendingPathComponent("书 (一).md"))
    }
    @Test @MainActor func embeddedNoteIsReadOnlyAndKeepsSourceLink() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "# 子标题\n\n子笔记正文".write(to: dir.appendingPathComponent("子.md"), atomically: true, encoding: .utf8)
        let source = "[子](%E5%AD%90.md \"mdstudio-embed\")"
        let editor = MarkdownVisualEditor(source: .constant(source), blocks: MarkdownBlock.parse(source), parsedSource: source,
            readerWidth: 720, headingStyles: HeadingStyle.defaults, bodyColorHex: "#333333",
            readerBackgroundHex: "#FFFFFF", strongColorHex: "#007766", strongSize: 18,
            strongFamily: "系统默认", bodySize: 18, bodyFamily: "系统默认", lineHeight: 1.85,
            paragraphSpacing: 13, baseURL: dir, scrollTarget: nil, scrollRequest: 0,
            sourceLineTarget: 1, sourceLineRequest: 0, restoreRequest: 0,
            scrollState: MarkdownVisualScrollState(), onSourceLineChange: { _ in }, onActivate: {}, onImagePaste: { _ in nil })
        let html = editor.pageHTML(using: MarkdownBlock.parse(source))
        #expect(html.contains("class=\"embedded-note\""))
        #expect(html.contains("contenteditable=\"false\""))
        #expect(html.contains("子笔记正文"))
        #expect(html.contains("打开子笔记编辑"))
    }

}
