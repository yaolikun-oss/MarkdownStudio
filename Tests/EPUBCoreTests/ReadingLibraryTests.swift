import Foundation
import Testing
@testable import EPUBCore

@Suite struct ReadingLibraryTests {
    @Test func identitiesMatchByteForByteCopiesAndDetectChanges() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("first.epub")
        let copy = root.appendingPathComponent("renamed.epub")
        try Data("same epub bytes".utf8).write(to: first)
        try Data("same epub bytes".utf8).write(to: copy)
        let identity = try ReadingDocumentIdentity.make(for: first)
        #expect(identity.count == 64)
        #expect(identity == (try ReadingDocumentIdentity.make(for: copy)))
        try Data("changed epub bytes".utf8).write(to: copy)
        #expect(identity != (try ReadingDocumentIdentity.make(for: copy)))
    }

    @Test func unpackedPackageIdentityIncludesRelativeNamesAndContent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let first = root.appendingPathComponent("one", isDirectory: true)
        let copy = root.appendingPathComponent("two", isDirectory: true)
        try FileManager.default.createDirectory(at: first.appendingPathComponent("Text", isDirectory: true), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: copy.appendingPathComponent("Text", isDirectory: true), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("chapter".utf8).write(to: first.appendingPathComponent("Text/ch1.xhtml"))
        try Data("chapter".utf8).write(to: copy.appendingPathComponent("Text/ch1.xhtml"))
        let id = try ReadingDocumentIdentity.make(for: first)
        let copiedID = try ReadingDocumentIdentity.make(for: copy)
        #expect(id == copiedID)
        try Data("different".utf8).write(to: copy.appendingPathComponent("Text/ch2.xhtml"))
        #expect(id != (try ReadingDocumentIdentity.make(for: copy)))
    }

    @Test func profileAndAnnotationsAreStoredPerDocumentAndRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ReadingLibraryStore(rootURL: root)
        let id = String(repeating: "a", count: 64)
        var profile = BookReadingProfile(documentID: id, title: "测试书", sourceKind: .epub)
        profile.style = ReadingStyleSettings()
        profile.style?.bodySize = 18
        profile.position = SavedReadingPosition(location: .epub(chapterHref: "Text/ch1.xhtml", fraction: 0.42))
        try store.saveProfile(profile)
        let loadedValue = try store.loadProfile(documentID: id)
        let loaded = try #require(loadedValue)
        #expect(loaded.style?.bodySize == 18)
        #expect(loaded.position?.location == profile.position?.location)
        #expect(try store.loadProfile(documentID: String(repeating: "b", count: 64)) == nil)

        let annotation = EPUBAnnotation(chapterHref: "Text/ch1.xhtml",
            anchor: EPUBTextAnchor(quote: "选中文本", prefix: "前文", suffix: "后文"), note: "我的批注", colorHex: "#FFE58A")
        try store.saveAnnotations([annotation], documentID: id)
        let loadedAnnotations = try store.loadAnnotations(documentID: id)
        #expect(loadedAnnotations.map(\.id) == [annotation.id])
        #expect(loadedAnnotations.first?.anchor == annotation.anchor)
        #expect(loadedAnnotations.first?.note == annotation.note)
        try store.saveAnnotations([], documentID: id)
        #expect(try store.loadAnnotations(documentID: id).isEmpty)
    }

    @Test func readingPositionJSONIsPortableAndClampsEPUBFraction() throws {
        let position = SavedReadingPosition(location: .epub(chapterHref: "Text/a.xhtml", fraction: 4))
        let data = try JSONEncoder().encode(position)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("chapterHref"))
        let decoded = try JSONDecoder().decode(SavedReadingPosition.self, from: data)
        #expect(decoded.location == .epub(chapterHref: "Text/a.xhtml", fraction: 1))
    }

    @Test func pdfReadingPositionPreservesPageAndCanvasCoordinates() throws {
        let position = SavedReadingPosition(location: .pdf(pageIndex: 37, x: 142.5, y: 806.25))
        let data = try JSONEncoder().encode(position)
        let decoded = try JSONDecoder().decode(SavedReadingPosition.self, from: data)
        #expect(decoded.location == .pdf(pageIndex: 37, x: 142.5, y: 806.25))
    }

    @Test func differentDevicesMergePositionAndIndependentAnnotationChanges() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = ReadingLibraryStore(rootURL: root, deviceID: "mac-a")
        let second = ReadingLibraryStore(rootURL: root, deviceID: "mac-b")
        let id = String(repeating: "c", count: 64)
        var profileA = BookReadingProfile(documentID: id, title: "同一本书", sourceKind: .epub)
        var style = ReadingStyleSettings(); style.bodySize = 19
        try first.saveStyle(style, in: profileA)
        profileA.style = style
        let position = SavedReadingPosition(location: .epub(chapterHref: "Text/2.xhtml", fraction: 0.67))
        try second.savePosition(position, in: profileA)
        let mergedValue = try first.loadProfile(documentID: id)
        let merged = try #require(mergedValue)
        #expect(merged.style?.bodySize == 19)
        #expect(merged.position?.location == position.location)

        let one = EPUBAnnotation(chapterHref: "Text/1.xhtml", anchor: EPUBTextAnchor(quote: "甲", prefix: "", suffix: ""), note: "A", colorHex: "#FFE58A")
        let two = EPUBAnnotation(chapterHref: "Text/2.xhtml", anchor: EPUBTextAnchor(quote: "乙", prefix: "", suffix: ""), note: "B", colorHex: "#BFE8C5")
        try first.saveAnnotations([one], documentID: id)
        try second.saveAnnotations([one, two], documentID: id)
        #expect(Set(try first.loadAnnotations(documentID: id).map(\.id)) == Set([one.id, two.id]))
        try first.saveAnnotations([one], documentID: id)
        #expect(try second.loadAnnotations(documentID: id).map(\.id) == [one.id])
    }

    @Test func markdownAnnotationNotesStayInCloudLibraryEvenWhenSourceIsUnavailable() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ReadingLibraryStore(rootURL: root, isUsingICloudDrive: true, deviceID: "mac-test")
        let id = String(repeating: "d", count: 64)
        let annotation = EPUBAnnotation(chapterHref: "Text/chapter.xhtml",
            anchor: EPUBTextAnchor(quote: "重点", prefix: "前", suffix: "后"), note: "跨设备批注", colorHex: "#FFE58A",
            markStyle: .underline)
        try store.saveAnnotations([annotation], documentID: id)
        #expect(try store.loadAnnotations(documentID: id).first?.markStyle == .underline)
        #expect(store.locationDescription.contains("iCloud Drive"))
    }

    @Test func webBookmarksMergeAcrossDevicesAndPropagateDeletes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = ReadingLibraryStore(rootURL: root, isUsingICloudDrive: true, deviceID: "mac-a")
        let second = ReadingLibraryStore(rootURL: root, isUsingICloudDrive: true, deviceID: "mac-b")
        var article = WebBookmark(title: "文章", urlString: "https://example.com/article", note: "以后看")
        let reference = WebBookmark(title: "参考", urlString: "https://example.com/reference")

        try first.saveWebBookmarks([article])
        try second.saveWebBookmarks([reference])
        #expect(Set(try first.loadWebBookmarks().map(\.id)) == Set([article.id, reference.id]))

        article.note = "已经读过"
        article.updatedAt = Date().addingTimeInterval(1)
        try first.saveWebBookmarks([article])
        var tombstone = article
        tombstone.isDeleted = true
        tombstone.updatedAt = Date().addingTimeInterval(2)
        try first.saveWebBookmarks([tombstone])

        var editedReference = reference
        editedReference.note = "另一个设备新增的备注"
        editedReference.updatedAt = Date().addingTimeInterval(3)
        try second.saveWebBookmarks([editedReference])
        let merged = try second.loadWebBookmarks()
        #expect(merged.map(\.id) == [reference.id])
        #expect(merged.first?.note == "另一个设备新增的备注")
    }

    @Test func webBookmarksRejectNonWebURLs() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ReadingLibraryStore(rootURL: root, deviceID: "mac-test")
        let invalid = WebBookmark(title: "本地文件", urlString: "file:///etc/passwd")
        #expect(throws: ReadingLibraryError.invalidData) { try store.saveWebBookmarks([invalid]) }
        let missingHost = WebBookmark(title: "无主机", urlString: "https:")
        #expect(throws: ReadingLibraryError.invalidData) { try store.saveWebBookmarks([missingHost]) }
    }

    @Test func legacyAnnotationSidecarMigratesOnceWithoutEditingTheBook() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let book = root.appendingPathComponent("book.epub")
        let original = Data("original EPUB bytes".utf8)
        try original.write(to: book)
        let annotation = EPUBAnnotation(chapterHref: "Text/1.xhtml",
            anchor: EPUBTextAnchor(quote: "摘录", prefix: "前文", suffix: "后文"), note: "旧注释", colorHex: "#FFE58A")
        try EPUBAnnotationStore.save([annotation], for: book)
        let store = ReadingLibraryStore(rootURL: root.appendingPathComponent("iCloud", isDirectory: true), deviceID: "mac-one")
        let id = try ReadingDocumentIdentity.make(for: book)
        #expect(try store.loadAnnotations(documentID: id, migratingLegacySidecarAt: book).map(\.id) == [annotation.id])
        try store.saveAnnotations([], documentID: id)
        #expect(try store.loadAnnotations(documentID: id, migratingLegacySidecarAt: book).isEmpty)
        #expect(try Data(contentsOf: book) == original)
    }
}
