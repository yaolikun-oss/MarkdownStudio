import Foundation
import Testing
@testable import MarkdownReader

@Suite struct RecentWorkspaceTests {
    @Test func pairUsesExactPathsAndDeduplicates() throws {
        let reading = URL(fileURLWithPath: "/tmp/book.pdf")
        let note = URL(fileURLWithPath: "/tmp/other-notes.md")
        let pair = RecentWorkspace(readingURL: reading, noteURL: note)
        #expect(pair.readingPath == reading.path)
        #expect(pair.notePath == note.path)
        #expect(pair.subtitle.contains("book.pdf"))
        #expect(pair.subtitle.contains("other-notes.md"))
        let history = RecentWorkspaceHistory.record(pair, in: [pair])
        #expect(history.count == 1)
        let data = try JSONEncoder().encode(history)
        #expect(RecentWorkspaceHistory.decode(data) == history)
    }

    @Test func historyKeepsMostRecentTwenty() {
        var history: [RecentWorkspace] = []
        for number in 0..<25 {
            history = RecentWorkspaceHistory.record(
                RecentWorkspace(readingURL: nil, noteURL: URL(fileURLWithPath: "/tmp/note-\(number).md")),
                in: history)
        }
        #expect(history.count == 20)
        #expect(history.first?.noteURL?.lastPathComponent == "note-24.md")
        #expect(history.last?.noteURL?.lastPathComponent == "note-5.md")
    }
}
