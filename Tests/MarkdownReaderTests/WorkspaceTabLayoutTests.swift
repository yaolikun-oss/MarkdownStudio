import Foundation
import Testing
@testable import MarkdownReader

struct WorkspaceTabLayoutTests {
    @Test @MainActor func repeatedDockingIgnoresRemovedGroupsAndTargetsHeaderOrNearestSide() throws {
        let frames = WorkspaceGroupFrames()
        var layout = WorkspaceGridLayout()
        let visual = WorkspaceTab(.visual), source = WorkspaceTab(.source)
        layout.add(visual); layout.add(source)
        let first = try #require(layout.groups.first?.id)
        frames.frames[first] = CGRect(x: 0, y: 0, width: 800, height: 600)
        frames.tabFrames[first] = [visual.id: CGRect(x: 0, y: 0, width: 100, height: 32), source.id: CGRect(x: 100, y: 0, width: 100, height: 32)]
        #expect(frames.destination(at: CGPoint(x: 20, y: 10), groups: layout.groups)?.1 == .center)
        #expect(frames.destination(at: CGPoint(x: 700, y: 300), groups: layout.groups)?.1 == .right)
        layout.move(source.id, to: first, edge: .right)
        let second = try #require(layout.groups.first(where: { $0.id != first })?.id)
        frames.frames[first] = CGRect(x: 0, y: 0, width: 400, height: 600)
        frames.frames[second] = CGRect(x: 400, y: 0, width: 400, height: 600)
        #expect(frames.destination(at: CGPoint(x: 600, y: 40), groups: layout.groups)?.1 == .top)
        layout.move(source.id, to: first, edge: .center)
        frames.frames[first] = CGRect(x: 0, y: 0, width: 800, height: 600)
        #expect(frames.destination(at: CGPoint(x: 600, y: 300), groups: layout.groups)?.0 == first)
        layout.move(source.id, to: first, edge: .bottom)
        #expect(layout.groups.count == 2)
        #expect(layout.isValid)
        for index in 0..<40 {
            let anchor = try #require(layout.groups.first(where: { $0.tabs.contains(visual) })?.id)
            layout.move(source.id, to: anchor, edge: .center)
            #expect(layout.groups.count == 1)
            frames.frames[anchor] = CGRect(x: 0, y: 0, width: 800, height: 600)
            let target = try #require(frames.destination(at: CGPoint(x: 700, y: 300), groups: layout.groups))
            #expect(target.0 == anchor)
            layout.move(source.id, to: target.0, edge: index.isMultiple(of: 2) ? .right : .bottom)
            #expect(layout.groups.count == 2)
            #expect(layout.isValid)
        }
    }
    @Test func workspaceDocumentStoresReferencesAndReportsMissingFiles() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let note = folder.appendingPathComponent("note.md")
        let missing = folder.appendingPathComponent("missing.pdf")
        try Data("# 测试".utf8).write(to: note)
        var layout = WorkspaceGridLayout()
        layout.add(WorkspaceTab(.visual, location: note))
        layout.add(WorkspaceTab(.reading, location: missing))
        let document = WorkspaceDocument(folders: [folder], files: [note, missing], layout: layout)
        let decoded = try JSONDecoder().decode(WorkspaceDocument.self, from: JSONEncoder().encode(document))
        #expect(decoded == document)
        #expect(decoded.isValid)
        #expect(decoded.missingFiles == [missing])
        #expect(try String(contentsOf: note, encoding: .utf8) == "# 测试")
    }
    @Test func workspaceDocumentKeepsReadingNoteLinksAndOpensOlderFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let book = root.appendingPathComponent("阅读资料/书.epub")
        let note = root.appendingPathComponent("笔记/书籍笔记/书.md")
        try FileManager.default.createDirectory(at: book.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: note.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("epub".utf8).write(to: book)
        try Data("# 书".utf8).write(to: note)
        let link = WorkspaceReadingNoteLink(readingURL: book, noteURL: note)
        let document = WorkspaceDocument(folders: [root], layout: WorkspaceGridLayout(), readingNotes: [link])
        let decoded = try JSONDecoder().decode(WorkspaceDocument.self, from: JSONEncoder().encode(document))
        #expect(decoded.readingNotes == [link])
        #expect(decoded.missingFiles.isEmpty)

        var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(document)) as? [String: Any])
        legacy.removeValue(forKey: "readingNotes")
        let legacyData = try JSONSerialization.data(withJSONObject: legacy)
        #expect(try JSONDecoder().decode(WorkspaceDocument.self, from: legacyData).readingNotes.isEmpty)
    }
    @Test func savedWorkspaceDetectsReferencesLostAfterOpening() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let note = root.appendingPathComponent("note.md")
        try Data("# 笔记".utf8).write(to: note)
        let workspace = root.appendingPathComponent("project.mdworkspace")
        let document = WorkspaceDocument(folders: [folder], files: [note], layout: WorkspaceGridLayout())
        let original = try JSONEncoder().encode(document)
        try original.write(to: workspace)
        #expect(document.missingFiles.isEmpty)
        try FileManager.default.removeItem(at: note)
        let saved = try JSONDecoder().decode(WorkspaceDocument.self, from: Data(contentsOf: workspace))
        #expect(saved.missingFiles == [note])
        #expect(try Data(contentsOf: workspace) == original)
    }
    @Test func contentDropChoosesNearestEdge() {
        #expect(WorkspaceDropEdge.nearest(x: 0.1, y: 0.5) == .left)
        #expect(WorkspaceDropEdge.nearest(x: 0.9, y: 0.5) == .right)
        #expect(WorkspaceDropEdge.nearest(x: 0.5, y: 0.1) == .top)
        #expect(WorkspaceDropEdge.nearest(x: 0.5, y: 0.9) == .bottom)
        #expect(WorkspaceDropEdge.nearest(x: 0.35, y: 0.48) == .left)
        #expect(WorkspaceDropEdge.nearest(x: 0.55, y: 0.7) == .bottom)
    }
    @Test func presetsRetainEveryTabAndSelectTheReadingAndEditingViews() throws {
        let book = WorkspaceTab(.reading), web = WorkspaceTab(.web), source = WorkspaceTab(.source), visual = WorkspaceTab(.visual)
        var original = WorkspaceGridLayout()
        for tab in [book, web, source, visual] { original.add(tab) }
        for edge in [WorkspaceDropEdge.right, .bottom] {
            let arranged = original.arranged(edge)
            #expect(arranged.isValid)
            #expect(arranged.groups.count == 2)
            #expect(arranged.groups[0].selected == book.id)
            #expect(arranged.groups[1].selected == source.id)
            #expect(Set(arranged.allTabs.map(\.id)) == Set(original.allTabs.map(\.id)))
            let merged = arranged.arranged(.center)
            #expect(merged.groups.count == 1)
            #expect(Set(merged.allTabs.map(\.id)) == Set(original.allTabs.map(\.id)))
        }
        #expect(WorkspaceGridLayout().arranged(.center).isValid)
    }
    @Test func eachEdgeCreatesAndCollapsesAGroup() throws {
        for edge in [WorkspaceDropEdge.left, .right, .top, .bottom] {
            var layout = WorkspaceGridLayout()
            let first = WorkspaceTab(.visual), second = WorkspaceTab(.web)
            layout.add(first); layout.add(second)
            let original = try #require(layout.groups.first?.id)
            layout.move(second.id, to: original, edge: edge)
            #expect(layout.groups.count == 2)
            #expect(layout.isValid)
            let firstIsNew = edge == .left || edge == .top
            #expect(layout.groups.first?.tabs.first?.id == (firstIsNew ? second.id : first.id))
            let target = try #require(layout.groups.first(where: { $0.tabs.contains(first) })?.id)
            layout.move(second.id, to: target)
            #expect(layout.groups.count == 1)
            #expect(Set(layout.allTabs.map(\.id)) == Set([first.id, second.id]))
            #expect(layout.isValid)
        }
    }
    @Test func editorGroupsSplitInFourDirectionsReorderAndCollapse() throws {
        let book = WorkspaceTab(.reading), web = WorkspaceTab(.web), source = WorkspaceTab(.source), visual = WorkspaceTab(.visual)
        var layout = WorkspaceGridLayout()
        for tab in [book, web, source, visual] { layout.add(tab) }
        let original = try #require(layout.groups.first?.id)
        layout.move(visual.id, to: original, edge: .right)
        #expect(layout.groups.count == 2)
        let right = try #require(layout.groups.first(where: { $0.tabs.contains(visual) })?.id)
        layout.move(web.id, to: right, edge: .bottom)
        #expect(layout.groups.count == 3)
        let webGroup = try #require(layout.groups.first(where: { $0.tabs.contains(web) })?.id)
        layout.move(source.id, to: webGroup, edge: .center, index: 0)
        #expect(layout.groups.first(where: { $0.id == webGroup })?.tabs == [source, web])
        layout.move(web.id, to: webGroup, edge: .center, index: 0)
        #expect(layout.groups.first(where: { $0.id == webGroup })?.tabs == [web, source])
        layout.remove(visual.id)
        #expect(layout.groups.count == 2)
        #expect(Set(layout.allTabs.map(\.id)) == Set([book.id, web.id, source.id]))
        let restored = try JSONDecoder().decode(WorkspaceGridLayout.self, from: JSONEncoder().encode(layout))
        #expect(restored == layout)
    }
    @Test func movingAndClosingTabsPreservesRemainingGroups() throws {
        let book = WorkspaceTab(.reading), web = WorkspaceTab(.web), source = WorkspaceTab(.source), visual = WorkspaceTab(.visual)
        var layout = WorkspaceTabLayout()
        for tab in [book, web, source, visual] { layout.add(tab) }
        layout.move(web.id, toRight: true)
        layout.move(source.id, toRight: true, at: 0)
        #expect(layout.left.tabs == [book, visual])
        #expect(layout.right?.tabs == [source, web])
        layout.remove(source.id)
        #expect(layout.right?.selected == web.id)
        layout.remove(web.id)
        #expect(layout.right == nil)
        #expect(Set(layout.allTabs.map(\.id)) == Set([book.id, visual.id]))
        let restored = try JSONDecoder().decode(WorkspaceTabLayout.self, from: JSONEncoder().encode(layout))
        #expect(restored == layout)
    }

    @Test func browserShortcutsAreIndependentAndAllowEmptyList() {
        #expect(QuickSite.decode("").map(\.title) == ["ChatGPT", "Gemini"])
        #expect(QuickSite.decode(QuickSite.encode([])).isEmpty)
        let values = [QuickSite(title: "测试网站", address: "https://example.com")]
        #expect(QuickSite.decode(QuickSite.encode(values)) == values)
    }

    @Test @MainActor func browserTabsKeepIndependentSessions() throws {
        let sessions = WebBrowserSessions()
        let first = sessions.create(url: try #require(URL(string: "https://example.com/first")))
        let second = sessions.create(url: try #require(URL(string: "https://example.org/second")))
        #expect(sessions.session(for: first)?.currentURL?.host == "example.com")
        #expect(sessions.session(for: second)?.currentURL?.host == "example.org")
        sessions.activate(first)
        #expect(sessions.activeID == first)
        sessions.close(first)
        #expect(sessions.activeID == second)
        #expect(sessions.session(for: second)?.currentURL?.host == "example.org")
    }

    @Test func fileTreeListsFoldersAndSupportedDocumentsWithoutTraversingSymlinks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("子目录"), withIntermediateDirectories: true)
        for name in ["notes.md", "book.pdf", "book.epub", "document.docx", "ignored.bin", ".hidden.md"] {
            try Data().write(to: root.appendingPathComponent(name))
        }
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("链接"), withDestinationURL: root)
        let entries = try WorkspaceFileEntry.children(of: root)
        #expect(entries.first?.isDirectory == true)
        #expect(Set(entries.map { $0.url.lastPathComponent }) == Set(["子目录", "notes.md", "book.pdf", "book.epub", "document.docx"]))
    }

    @Test func fileTreeTreatsAnUnpackedEPUBAsAnOpenableDocument() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let unpacked = root.appendingPathComponent("图文书", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: unpacked.appendingPathComponent("META-INF"), withIntermediateDirectories: true)
        try Data().write(to: unpacked.appendingPathComponent("META-INF/container.xml"))

        let entry = try #require(WorkspaceFileEntry.children(of: root).first)
        #expect(entry.url.standardizedFileURL.resolvingSymlinksInPath() == unpacked.standardizedFileURL.resolvingSymlinksInPath())
        #expect(entry.isDirectory == false)
    }
}
