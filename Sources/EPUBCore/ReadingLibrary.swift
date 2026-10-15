import CryptoKit
import Foundation

/// Portable identity for a local PDF, EPUB archive, or unpacked EPUB directory.
/// The digest covers every byte and each relative path for directory packages.
public enum ReadingDocumentIdentity {
    public static func make(for url: URL) throws -> String {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else { throw ReadingLibraryError.unsupportedDocument }
        var hasher = SHA256()
        if values.isDirectory == true {
            hasher.update(data: Data("directory\0".utf8))
            let files = try regularFiles(in: url)
            guard !files.isEmpty else { throw ReadingLibraryError.unsupportedDocument }
            let resolvedRoot = url.resolvingSymlinksInPath().standardizedFileURL.path
            for file in files {
                let resolvedFile = file.resolvingSymlinksInPath().standardizedFileURL.path
                guard resolvedFile.hasPrefix(resolvedRoot + "/") else { throw ReadingLibraryError.unsupportedDocument }
                let relative = String(resolvedFile.dropFirst(resolvedRoot.count + 1))
                hasher.update(data: Data(relative.utf8)); hasher.update(data: Data([0]))
                try updateHasher(&hasher, from: file)
                hasher.update(data: Data([0]))
            }
        } else if values.isRegularFile == true {
            hasher.update(data: Data("file\0".utf8))
            try updateHasher(&hasher, from: url)
        } else {
            throw ReadingLibraryError.unsupportedDocument
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func regularFiles(in directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [], errorHandler: { _, _ in true }) else { return [] }
        var result: [URL] = []
        for case let item as URL in enumerator {
            let values = try item.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true { throw ReadingLibraryError.unsupportedDocument }
            if item.lastPathComponent == "__MACOSX" {
                enumerator.skipDescendants()
                continue
            }
            if item.lastPathComponent == ".DS_Store" || item.lastPathComponent.hasPrefix("._") { continue }
            if values.isRegularFile == true { result.append(item) }
        }
        return result.sorted { $0.path < $1.path }
    }

    private static func updateHasher(_ hasher: inout SHA256, from url: URL) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var readError: Error?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: coordinatedURL.path)
                var size = UInt64((attributes[.size] as? NSNumber)?.uint64Value ?? 0).bigEndian
                withUnsafeBytes(of: &size) { hasher.update(data: Data($0)) }
                guard let stream = InputStream(url: coordinatedURL) else { throw ReadingLibraryError.unreadableDocument }
                stream.open()
                defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 1024 * 1024)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count < 0 { throw stream.streamError ?? ReadingLibraryError.unreadableDocument }
                    if count == 0 { break }
                    hasher.update(data: Data(buffer[0..<count]))
                }
            } catch { readError = error }
        }
        if let coordinationError { throw coordinationError }
        if let readError { throw readError }
    }
}

public enum ReadingLibraryError: LocalizedError {
    case unsupportedDocument
    case unreadableDocument
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .unsupportedDocument: "无法为此文件生成稳定的书籍标识。"
        case .unreadableDocument: "无法读取书籍文件。"
        case .invalidData: "阅读资料格式无效。"
        }
    }
}

public enum ReadingSourceKind: String, Codable { case epub, pdf }

/// A web bookmark is independent of Markdown notes. Tombstones are retained so
/// deletes converge when another Mac reconnects to iCloud later.
public struct WebBookmark: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var urlString: String
    public var note: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isDeleted: Bool

    public init(id: String = UUID().uuidString, title: String, urlString: String, note: String = "",
                createdAt: Date = Date(), updatedAt: Date = Date(), isDeleted: Bool = false) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
}

public struct SavedReadingPosition: Codable, Equatable {
    public enum Location: Codable, Equatable {
        case epub(chapterHref: String, fraction: Double)
        case pdf(pageIndex: Int, x: Double, y: Double)

        private enum CodingKeys: String, CodingKey { case type, chapterHref, fraction, pageIndex, x, y }
        private enum Kind: String, Codable { case epub, pdf }
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            switch try values.decode(Kind.self, forKey: .type) {
            case .epub:
                self = .epub(chapterHref: try values.decode(String.self, forKey: .chapterHref),
                             fraction: try values.decode(Double.self, forKey: .fraction))
            case .pdf:
                self = .pdf(pageIndex: try values.decode(Int.self, forKey: .pageIndex),
                            x: try values.decode(Double.self, forKey: .x),
                            y: try values.decode(Double.self, forKey: .y))
            }
        }
        public func encode(to encoder: Encoder) throws {
            var values = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .epub(let href, let fraction):
                try values.encode(Kind.epub, forKey: .type)
                try values.encode(href, forKey: .chapterHref)
                try values.encode(min(1, max(0, fraction)), forKey: .fraction)
            case .pdf(let page, let x, let y):
                try values.encode(Kind.pdf, forKey: .type)
                try values.encode(max(0, page), forKey: .pageIndex)
                try values.encode(x.isFinite ? x : 0, forKey: .x)
                try values.encode(y.isFinite ? y : 0, forKey: .y)
            }
        }
    }

    public var location: Location
    public var updatedAt: Date
    public init(location: Location, updatedAt: Date = Date()) {
        self.location = location
        self.updatedAt = updatedAt
    }
}

/// User-facing style values are explicit JSON fields so other clients can read the schema.
public struct ReadingStyleSettings: Codable, Equatable {
    public var readerWidth = 720.0
    public var epubReaderWidth = 720.0
    public var bodySize = 15.0
    public var outlineFontScale = 1.0
    public var bodyFamily = "系统默认"
    public var bodyColorHex = "#282725"
    public var readerBackgroundHex = "#FFFFFF"
    public var lineHeight = 1.85
    public var paragraphSpacing = 13.0
    public var strongColorHex = "#A5563A"
    public var strongSize = 15.0
    public var strongFamily = "系统默认"
    public var annotationFontSize = 11.0
    public var annotationFontFamily = "系统默认"
    public var annotationTextColorHex = "#777777"
    public var headingStylesJSON = ""
    public var outlineColorsJSON = ""
    public var pdfZoomPercent = 100.0
    public init() {}
}

public struct BookReadingProfile: Codable, Equatable {
    public var schemaVersion = 1
    public var documentID: String
    public var title: String
    public var sourceKind: ReadingSourceKind
    public var createdAt: Date
    public var updatedAt: Date
    public var style: ReadingStyleSettings?
    public var styleUpdatedAt: Date?
    public var position: SavedReadingPosition?

    public init(documentID: String, title: String, sourceKind: ReadingSourceKind) {
        self.documentID = documentID
        self.title = title
        self.sourceKind = sourceKind
        createdAt = Date()
        updatedAt = createdAt
    }
}

/// Stores one profile and independently named annotation files per document. Keeping
/// records small limits iCloud conflicts and leaves source books untouched.
public final class ReadingLibraryStore {
    public let rootURL: URL
    public let isUsingICloudDrive: Bool
    public let deviceID: String
    private let fileManager = FileManager.default

    public init(rootURL: URL, isUsingICloudDrive: Bool = false, deviceID: String = UUID().uuidString) {
        self.rootURL = rootURL
        self.isUsingICloudDrive = isUsingICloudDrive
        self.deviceID = deviceID
    }

    public static func makeDefault(fileManager: FileManager = .default) -> ReadingLibraryStore {
        let deviceID: String
        if let stored = UserDefaults.standard.string(forKey: "readingLibrary.deviceID") {
            deviceID = stored
        } else {
            deviceID = UUID().uuidString
            UserDefaults.standard.set(deviceID, forKey: "readingLibrary.deviceID")
        }
        let cloudDocuments = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: cloudDocuments.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return ReadingLibraryStore(rootURL: cloudDocuments.appendingPathComponent("Markdown Studio/Reading Data", isDirectory: true),
                                       isUsingICloudDrive: true, deviceID: deviceID)
        }
        let local = (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                          appropriateFor: nil, create: true)) ?? URL(fileURLWithPath: NSHomeDirectory())
        return ReadingLibraryStore(rootURL: local.appendingPathComponent("Markdown Studio/Reading Data", isDirectory: true),
                                   deviceID: deviceID)
    }

    public var locationDescription: String {
        isUsingICloudDrive ? "iCloud Drive / Markdown Studio / Reading Data" : "本机 / Library / Application Support / Markdown Studio / Reading Data"
    }

    public func loadProfile(documentID: String) throws -> BookReadingProfile? {
        let directory = profilesDirectory(documentID)
        guard fileManager.fileExists(atPath: directory.path) else { return nil }
        let urls = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        let profiles = try urls.map { try JSONDecoder.readingLibrary.decode(BookReadingProfile.self, from: coordinatedRead($0)) }
        guard profiles.allSatisfy({ $0.schemaVersion == 1 && $0.documentID == documentID }) else {
            throw ReadingLibraryError.invalidData
        }
        return merge(profiles)
    }

    public func saveProfile(_ profile: BookReadingProfile) throws {
        guard profile.schemaVersion == 1, profile.documentID.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
            throw ReadingLibraryError.invalidData
        }
        var updated = profile
        let prior = try loadOwnProfile(documentID: profile.documentID)
        if profile.style != prior?.style { updated.styleUpdatedAt = Date() }
        updated.updatedAt = Date()
        try coordinatedWrite(JSONEncoder.readingLibrary.encode(updated), to: ownProfileURL(profile.documentID))
    }

    public func saveStyle(_ style: ReadingStyleSettings, in profile: BookReadingProfile) throws {
        var own = try loadOwnProfile(documentID: profile.documentID)
            ?? BookReadingProfile(documentID: profile.documentID, title: profile.title, sourceKind: profile.sourceKind)
        own.title = profile.title
        own.style = style
        own.styleUpdatedAt = Date()
        own.updatedAt = Date()
        try coordinatedWrite(JSONEncoder.readingLibrary.encode(own), to: ownProfileURL(profile.documentID))
    }

    public func savePosition(_ position: SavedReadingPosition, in profile: BookReadingProfile) throws {
        var own = try loadOwnProfile(documentID: profile.documentID)
            ?? BookReadingProfile(documentID: profile.documentID, title: profile.title, sourceKind: profile.sourceKind)
        own.title = profile.title
        own.position = position
        own.updatedAt = Date()
        try coordinatedWrite(JSONEncoder.readingLibrary.encode(own), to: ownProfileURL(profile.documentID))
    }

    public func loadAnnotations(documentID: String) throws -> [EPUBAnnotation] {
        let latest = Dictionary(grouping: try loadAnnotationRecords(documentID: documentID), by: \.id)
            .compactMapValues { $0.max(by: { $0.updatedAt < $1.updatedAt }) }
        return latest.values.compactMap { $0.isDeleted ? nil : $0.annotation }.sorted { $0.createdAt < $1.createdAt }
    }

    public func loadAnnotations(documentID: String, migratingLegacySidecarAt sourceURL: URL) throws -> [EPUBAnnotation] {
        let directory = annotationsDirectory(documentID)
        let marker = directory.appendingPathComponent(".legacy-sidecar-imported")
        let current = try loadAnnotations(documentID: documentID)
        guard !fileManager.fileExists(atPath: marker.path) else { return current }
        if current.isEmpty, let legacy = try? EPUBAnnotationStore.load(for: sourceURL), !legacy.isEmpty {
            try saveAnnotations(legacy, documentID: documentID)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("1".utf8).write(to: marker, options: .atomic)
        return try loadAnnotations(documentID: documentID)
    }

    public func saveAnnotations(_ annotations: [EPUBAnnotation], documentID: String) throws {
        let directory = annotationsDirectory(documentID)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let current = try loadAnnotationRecords(documentID: documentID)
        let now = Date()
        var own = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        let updatedIDs = Set(annotations.map(\.id))
        for annotation in annotations {
            if let existing = own[annotation.id], !existing.isDeleted, existing.annotation == annotation { continue }
            own[annotation.id] = CloudAnnotationRecord(id: annotation.id, annotation: annotation,
                                                        updatedAt: now, isDeleted: false)
        }
        for id in own.keys where !updatedIDs.contains(id) {
            if own[id]?.isDeleted == true { continue }
            own[id] = CloudAnnotationRecord(id: id, annotation: nil, updatedAt: now, isDeleted: true)
        }
        let snapshot = directory.appendingPathComponent("\(deviceID).json")
        try coordinatedWrite(JSONEncoder.readingLibrary.encode(Array(own.values)), to: snapshot)
    }

    public func loadWebBookmarks() throws -> [WebBookmark] {
        let directory = webBookmarksDirectory
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        let urls = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        let records = try urls.flatMap { try JSONDecoder.readingLibrary.decode([WebBookmark].self, from: coordinatedRead($0)) }
        let latest = Dictionary(grouping: records, by: \.id).compactMapValues { $0.max(by: webBookmarkPrecedes) }
        return latest.values.filter { !$0.isDeleted }.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    /// Writes only changed records to this device's snapshot. Per-device files
    /// let the other Mac's independent additions merge instead of being replaced.
    public func saveWebBookmarks(_ changes: [WebBookmark]) throws {
        guard changes.allSatisfy({
            !$0.id.isEmpty && URL(string: $0.urlString).map {
                ["http", "https"].contains($0.scheme?.lowercased() ?? "") && $0.host?.isEmpty == false
            } == true
        }) else { throw ReadingLibraryError.invalidData }
        let directory = webBookmarksDirectory
        let snapshotURL = directory.appendingPathComponent("\(safeDeviceID).json")
        var own: [String: WebBookmark] = [:]
        if fileManager.fileExists(atPath: snapshotURL.path) {
            let existing = try JSONDecoder.readingLibrary.decode([WebBookmark].self, from: coordinatedRead(snapshotURL))
            own = Dictionary(grouping: existing, by: \.id).compactMapValues { $0.max(by: webBookmarkPrecedes) }
        }
        for record in changes {
            if let previous = own[record.id], previous.updatedAt > record.updatedAt { continue }
            own[record.id] = record
        }
        try coordinatedWrite(JSONEncoder.readingLibrary.encode(own.values.sorted { $0.id < $1.id }), to: snapshotURL)
    }

    private func profilesDirectory(_ id: String) -> URL { rootURL.appendingPathComponent("Books/\(id)/Profiles", isDirectory: true) }
    private func ownProfileURL(_ id: String) -> URL { profilesDirectory(id).appendingPathComponent("\(deviceID).json") }
    private func annotationsDirectory(_ id: String) -> URL { rootURL.appendingPathComponent("Books/\(id)/Annotations", isDirectory: true) }
    private var webBookmarksDirectory: URL { rootURL.appendingPathComponent("Web Bookmarks", isDirectory: true) }
    private var safeDeviceID: String {
        let safe = deviceID.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
        return safe.isEmpty ? "device" : safe
    }

    private func webBookmarkPrecedes(_ lhs: WebBookmark, _ rhs: WebBookmark) -> Bool {
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
        if lhs.isDeleted != rhs.isDeleted { return !lhs.isDeleted }
        let lhsValue = "\(lhs.title)\0\(lhs.urlString)\0\(lhs.note)"
        let rhsValue = "\(rhs.title)\0\(rhs.urlString)\0\(rhs.note)"
        return lhsValue < rhsValue
    }

    private func loadOwnProfile(documentID: String) throws -> BookReadingProfile? {
        let url = ownProfileURL(documentID)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder.readingLibrary.decode(BookReadingProfile.self, from: coordinatedRead(url))
    }

    private func merge(_ profiles: [BookReadingProfile]) -> BookReadingProfile? {
        guard var result = profiles.max(by: { $0.updatedAt < $1.updatedAt }) else { return nil }
        if let styleProfile = profiles.compactMap({ profile -> (ReadingStyleSettings, Date)? in
            guard let style = profile.style, let updated = profile.styleUpdatedAt else { return nil }
            return (style, updated)
        }).max(by: { $0.1 < $1.1 }) {
            result.style = styleProfile.0
            result.styleUpdatedAt = styleProfile.1
        }
        if let positionProfile = profiles.compactMap({ profile -> SavedReadingPosition? in profile.position })
            .max(by: { $0.updatedAt < $1.updatedAt }) {
            result.position = positionProfile
        }
        return result
    }

    private func loadAnnotationRecords(documentID: String) throws -> [CloudAnnotationRecord] {
        let directory = annotationsDirectory(documentID)
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        let urls = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
        let allRecords = try urls.flatMap { url in
            try JSONDecoder.readingLibrary.decode([CloudAnnotationRecord].self, from: coordinatedRead(url))
        }
        return Dictionary(grouping: allRecords, by: \.id).compactMapValues { $0.max(by: { $0.updatedAt < $1.updatedAt }) }.map(\.value)
    }

    private func coordinatedRead(_ url: URL) throws -> Data {
        if let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]),
           values.isUbiquitousItem == true,
           values.ubiquitousItemDownloadingStatus != .current {
            try? fileManager.startDownloadingUbiquitousItem(at: url)
        }
        var result: Data?
        var coordinationError: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) {
            result = try? Data(contentsOf: $0)
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw ReadingLibraryError.unreadableDocument }
        return result
    }

    private func coordinatedWrite(_ data: Data, to url: URL) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) {
            do { try data.write(to: $0, options: .atomic) } catch { writeError = error }
        }
        if let coordinationError { throw coordinationError }
        if let writeError { throw writeError }
    }

    private func coordinatedDelete(_ url: URL) throws {
        var coordinationError: NSError?
        var deleteError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forDeleting, error: &coordinationError) {
            do { try fileManager.removeItem(at: $0) } catch { deleteError = error }
        }
        if let coordinationError { throw coordinationError }
        if let deleteError { throw deleteError }
    }
}

private struct CloudAnnotationRecord: Codable {
    let id: String
    let annotation: EPUBAnnotation?
    let updatedAt: Date
    let isDeleted: Bool
}

private extension JSONEncoder {
    static var readingLibrary: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }
}

private extension JSONDecoder {
    static var readingLibrary: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}
