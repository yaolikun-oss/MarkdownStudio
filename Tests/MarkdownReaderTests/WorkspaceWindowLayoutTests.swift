import Foundation
import Testing
@testable import MarkdownReader

struct WorkspaceWindowLayoutTests {
    @Test func detachedTabCanReturnWithoutChangingItsIdentity() throws {
        var workspace = WorkspaceWindowLayout()
        let first = WorkspaceTab(.visual, location: URL(fileURLWithPath: "/tmp/one.md"))
        let second = WorkspaceTab(.source, location: URL(fileURLWithPath: "/tmp/two.md"))
        workspace.windows[0].layout.add(first)
        workspace.windows[0].layout.add(second)
        let main = workspace.mainWindowID
        let group = try #require(workspace.windows[0].layout.groups.first?.id)
        let detachedResult = workspace.detach(second.id)
        let detached = try #require(detachedResult)
        #expect(workspace.windows.count == 2)
        #expect(workspace.windows.first(where: { $0.id == detached })?.layout.allTabs == [second])
        let moved = workspace.move(second.id, to: main, groupID: group, edge: .right)
        #expect(moved)
        #expect(workspace.windows.count == 1)
        #expect(workspace.windows[0].layout.groups.count == 2)
        #expect(Set(workspace.allTabs.map(\.id)) == Set([first.id, second.id]))
        #expect(workspace.isValid)
        let restored = try JSONDecoder().decode(WorkspaceWindowLayout.self, from: JSONEncoder().encode(workspace))
        #expect(restored == workspace)
    }

    @Test func invalidDestinationNeverRemovesTheSource() throws {
        var workspace = WorkspaceWindowLayout()
        let tab = WorkspaceTab(.web)
        workspace.windows[0].layout.add(tab)
        let detachedResult = workspace.detach(tab.id)
        let detached = try #require(detachedResult)
        let before = workspace
        let moved = workspace.move(tab.id, to: detached, groupID: UUID())
        #expect(!moved)
        #expect(workspace == before)
        #expect(workspace.isValid)
    }
}
