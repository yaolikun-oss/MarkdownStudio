import Foundation
import Testing
@testable import MarkdownReader

@Suite struct WorkspaceChapterLinksTests {
    private let book = URL(fileURLWithPath: "/tmp/关联测试/长书.epub")
    private let note = URL(fileURLWithPath: "/tmp/关联测试/长笔记.md")

    @Test func addingManyLinksPreservesEveryEarlierLink() throws {
        var source = longDocument(sectionCount: 1_200)
        var links: [WorkspaceChapterLink] = []
        let specifications: [(Int, String, String?)] = [
            (7, "Text/chapter-007.xhtml", nil),
            (199, "Text/shared.xhtml", "section-199"),
            (603, "Text/shared.xhtml", "section-603"),
            (877, "Text/chapter-877.xhtml", nil),
            (1_199, "Text/chapter-1199.xhtml", "ending")
        ]

        for (section, href, fragment) in specifications {
            let blocks = MarkdownBlock.parse(source)
            let heading = try #require(blocks.first(where: { $0.title == "长文档标题 \(section)" }))
            let marker = UUID()
            source = WorkspaceChapterMarker.inserting(marker, after: heading, in: source)
            let link = makeLink(section: section, href: href, fragment: fragment, marker: marker)
            links = WorkspaceChapterLinks.upserting(link, into: links)

            #expect(links.count == specifications.prefix(while: { $0.0 != section }).count + 1)
            for earlier in links {
                #expect(WorkspaceChapterLinks.link(for: earlier.readingURL,
                    chapterHref: earlier.chapterHref, fragment: earlier.fragment, in: links)?.id == earlier.id)
                #expect(WorkspaceChapterLinks.link(for: earlier.noteURL,
                    markerID: earlier.markerID, in: links)?.id == earlier.id)
            }
        }

        #expect(links.count == 5)
        #expect(WorkspaceChapterLinks.link(for: book, chapterHref: "Text/shared.xhtml",
                                          fragment: "section-199", in: links)?.headingTitle == "长文档标题 199")
        #expect(WorkspaceChapterLinks.link(for: book, chapterHref: "Text/shared.xhtml",
                                          fragment: "section-603", in: links)?.headingTitle == "长文档标题 603")
        #expect(WorkspaceChapterLinks.link(for: book, chapterHref: "Text/shared.xhtml",
                                          fragment: nil, in: links) == nil)

        let reparsed = MarkdownBlock.parse(source)
        for link in links {
            let forward = try #require(WorkspaceChapterLinks.link(for: book,
                chapterHref: link.chapterHref, fragment: link.fragment, in: links))
            let forwardHeading = try #require(WorkspaceChapterMarker.heading(
                for: forward.markerID, blocks: reparsed, source: source))
            #expect(forwardHeading.title == link.headingTitle)

            let reverse = try #require(WorkspaceChapterLinks.link(for: note,
                markerID: link.markerID, in: links))
            #expect(reverse.chapterHref == link.chapterHref)
            #expect(reverse.fragment == link.fragment)
        }
    }

    @Test func citingTheSameReadingTargetFromAnotherHeadingKeepsBothAssociations() {
        let first = makeLink(section: 10, href: "Text/one.xhtml", fragment: nil, marker: UUID())
        let second = makeLink(section: 20, href: "Text/two.xhtml", fragment: nil, marker: UUID())
        let replacement = makeLink(section: 30, href: "Text/two.xhtml", fragment: nil, marker: UUID())
        var links = WorkspaceChapterLinks.upserting(first, into: [])
        links = WorkspaceChapterLinks.upserting(second, into: links)
        links = WorkspaceChapterLinks.upserting(replacement, into: links)

        #expect(links.count == 3)
        #expect(links.contains(where: { $0.id == first.id }))
        #expect(links.contains(where: { $0.id == second.id }))
        #expect(links.contains(where: { $0.id == replacement.id }))
        #expect(WorkspaceChapterLinks.link(for: book, chapterHref: "Text/two.xhtml",
                                          fragment: nil, in: links)?.id == replacement.id)
        #expect(WorkspaceChapterLinks.link(for: note, markerID: second.markerID,
                                          in: links)?.id == second.id)
    }

    @Test func movingOneNoteMarkerToAnotherChapterOnlyReplacesThatMarker() {
        let marker = UUID()
        let first = makeLink(section: 10, href: "Text/one.xhtml", fragment: nil, marker: marker)
        let unrelated = makeLink(section: 20, href: "Text/two.xhtml", fragment: nil, marker: UUID())
        let moved = makeLink(section: 10, href: "Text/three.xhtml", fragment: "new", marker: marker)
        var links = WorkspaceChapterLinks.upserting(first, into: [])
        links = WorkspaceChapterLinks.upserting(unrelated, into: links)
        links = WorkspaceChapterLinks.upserting(moved, into: links)

        #expect(links.count == 3)
        #expect(links.contains(where: { $0.id == first.id }))
        #expect(links.contains(where: { $0.id == unrelated.id }))
        #expect(links.contains(where: { $0.id == moved.id }))
    }

    @Test func severalOriginalChaptersCanPointToTheSameNoteHeading() {
        let marker = UUID()
        let chapterEight = makeLink(section: 8, href: "Text/eight.xhtml", fragment: nil, marker: marker)
        let chapterSeven = makeLink(section: 7, href: "Text/seven.xhtml", fragment: nil, marker: marker)
        var links = WorkspaceChapterLinks.upserting(chapterEight, into: [])
        links = WorkspaceChapterLinks.upserting(chapterSeven, into: links)

        #expect(links.count == 2)
        #expect(WorkspaceChapterLinks.link(for: book, chapterHref: "Text/eight.xhtml",
                                          fragment: nil, in: links)?.id == chapterEight.id)
        #expect(WorkspaceChapterLinks.link(for: book, chapterHref: "Text/seven.xhtml",
                                          fragment: nil, in: links)?.id == chapterSeven.id)
        #expect(WorkspaceChapterLinks.link(for: note, markerID: marker,
                                          in: links)?.id == chapterSeven.id)
    }

    @Test func trailingSlashDoesNotCreateAnotherBookIdentity() {
        let directoryStyleBook = URL(fileURLWithPath: book.path, isDirectory: true)
        let marker = UUID()
        let first = makeLink(section: 8, href: "Text/eight.xhtml", fragment: nil, marker: marker)
        let repeated = WorkspaceChapterLink(readingURL: directoryStyleBook, readingFingerprint: "new",
            chapterHref: first.chapterHref, fragment: first.fragment, chapterTitle: first.chapterTitle,
            noteURL: note, markerID: marker, headingTitle: first.headingTitle, headingLevel: first.headingLevel)
        var links = WorkspaceChapterLinks.upserting(first, into: [])
        links = WorkspaceChapterLinks.upserting(repeated, into: links)

        #expect(links.count == 1)
        #expect(WorkspaceChapterLinks.link(for: book, chapterHref: first.chapterHref,
                                          fragment: nil, in: links)?.id == repeated.id)
    }

    @Test func tocRowsSharingOneXHTMLRemainIndependentAndOneRowCanBeReconnected() {
        let firstMarker = UUID()
        let secondMarker = UUID()
        let correctedMarker = UUID()
        let rowSeven = WorkspaceEPUBTOCIdentity.make(index: 7, level: 0,
            href: "Text/shared.xhtml", title: "七 万湖会议")
        let rowEight = WorkspaceEPUBTOCIdentity.make(index: 8, level: 0,
            href: "Text/shared.xhtml", title: "八 守法公民的责任")
        let sevenWrong = makeLink(section: 7, href: "Text/shared.xhtml", fragment: nil,
                                  marker: firstMarker, readingAnchorID: rowSeven)
        let eight = makeLink(section: 8, href: "Text/shared.xhtml", fragment: nil,
                             marker: secondMarker, readingAnchorID: rowEight)
        let sevenCorrected = makeLink(section: 70, href: "Text/shared.xhtml", fragment: nil,
                                      marker: correctedMarker, readingAnchorID: rowSeven)
        var links = WorkspaceChapterLinks.upserting(sevenWrong, into: [])
        links = WorkspaceChapterLinks.upserting(eight, into: links)
        links = WorkspaceChapterLinks.upserting(sevenCorrected, into: links)

        #expect(links.count == 2)
        #expect(!links.contains(where: { $0.id == sevenWrong.id }))
        #expect(links.contains(where: { $0.id == eight.id }))
        #expect(links.contains(where: { $0.id == sevenCorrected.id }))
        #expect(WorkspaceChapterLinks.link(for: book, chapterHref: "Text/shared.xhtml", fragment: nil,
                                          readingAnchorID: rowEight, in: links)?.id == eight.id)
        #expect(WorkspaceChapterLinks.link(for: book, chapterHref: "Text/shared.xhtml", fragment: nil,
                                          readingAnchorID: rowSeven, in: links)?.id == sevenCorrected.id)
        #expect(WorkspaceChapterLinks.isMarkerReferenced(noteURL: note, markerID: secondMarker,
                                                         in: links))
        #expect(!WorkspaceChapterLinks.isMarkerReferenced(noteURL: note, markerID: firstMarker,
                                                          in: links))
    }

    @Test func olderSavedLinkWithoutTOCIdentityStillDecodes() throws {
        let link = makeLink(section: 8, href: "Text/eight.xhtml", fragment: nil, marker: UUID())
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(link)) as? [String: Any])
        object.removeValue(forKey: "readingAnchorID")
        let restored = try JSONDecoder().decode(
            WorkspaceChapterLink.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        #expect(restored.readingAnchorID == nil)
        #expect(restored.chapterHref == link.chapterHref)
    }

    @Test func explicitOutlineHeadingOverridesAStaleEditorCaret() throws {
        let source = "# 第一章\n\n正文\n\n## 第二章\n\n正文\n\n### 第三章\n"
        let blocks = MarkdownBlock.parse(source)
        let third = try #require(blocks.first(where: { $0.title == "第三章" }))
        let staleCaretHeading = WorkspaceMarkdownHeadingResolver.heading(
            in: blocks, source: source, selection: NSRange(location: 0, length: 0), fallbackSourceLine: 1)
        let explicitReference = try #require(WorkspaceMarkdownHeadingReference(heading: third, in: blocks))
        #expect(staleCaretHeading?.title == "第一章")
        #expect(explicitReference.resolve(in: blocks)?.title == "第三章")
    }

    @Test func headingReferenceSurvivesMarkersInsertedEarlierInTheLongDocument() throws {
        var source = longDocument(sectionCount: 900)
        let original = MarkdownBlock.parse(source)
        let target = try #require(original.first(where: { $0.title == "长文档标题 700" }))
        let reference = try #require(WorkspaceMarkdownHeadingReference(heading: target, in: original))
        let earlier = try #require(original.first(where: { $0.title == "长文档标题 20" }))
        source = WorkspaceChapterMarker.inserting(UUID(), after: earlier, in: source)
        let shifted = try #require(reference.resolve(in: MarkdownBlock.parse(source)))

        #expect(shifted.title == "长文档标题 700")
        #expect(shifted.sourceLine == target.sourceLine + 1)
    }

    @Test func workspaceSaveAndReopenRetainsAllLongDocumentLinks() throws {
        let links = (0..<80).map { index in
            makeLink(section: index, href: "Text/volume-\(index / 10).xhtml",
                     fragment: "section-\(index)", marker: UUID())
        }
        let workspace = WorkspaceDocument(folders: [], files: [book, note],
            layout: WorkspaceGridLayout(), chapterLinks: links)
        let data = try JSONEncoder().encode(workspace)
        let restored = try JSONDecoder().decode(WorkspaceDocument.self, from: data)

        #expect(restored.chapterLinks.count == 80)
        for link in links {
            #expect(WorkspaceChapterLinks.link(for: book, chapterHref: link.chapterHref,
                                              fragment: link.fragment, in: restored.chapterLinks)?.markerID == link.markerID)
        }
    }

    @Test func removedOrChangedAnchorsFailClosedInsteadOfJumpingElsewhere() throws {
        let source = "# 第一章\n\n正文\n\n# 第二章\n"
        let blocks = MarkdownBlock.parse(source)
        let link = makeLink(section: 1, href: "Text/shared.xhtml", fragment: "second", marker: UUID())
        #expect(WorkspaceChapterMarker.heading(for: link.markerID, blocks: blocks, source: source) == nil)
        #expect(WorkspaceChapterLinks.link(for: book, chapterHref: "Text/shared.xhtml",
                                          fragment: "first", in: [link]) == nil)
    }

    private func makeLink(section: Int, href: String, fragment: String?, marker: UUID,
                          readingAnchorID: String? = nil) -> WorkspaceChapterLink {
        WorkspaceChapterLink(readingURL: book, readingFingerprint: "fingerprint",
            chapterHref: href, fragment: fragment, readingAnchorID: readingAnchorID,
            chapterTitle: "原文章节 \(section)",
            noteURL: note, markerID: marker, headingTitle: "长文档标题 \(section)", headingLevel: 2)
    }

    private func longDocument(sectionCount: Int) -> String {
        (0..<sectionCount).map { index in
            "## 长文档标题 \(index)\n\n第 \(index) 节正文。这里包含足够的中文内容，用于模拟长篇学习笔记中的段落、滚动和锚点变化。\n"
        }.joined(separator: "\n")
    }
}
