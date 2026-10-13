import Foundation

public struct EPUBTextAnchor: Codable, Hashable {
    public var quote: String
    public var prefix: String
    public var suffix: String

    public init(quote: String, prefix: String, suffix: String) {
        self.quote = quote
        self.prefix = prefix
        self.suffix = suffix
    }
}

public struct EPUBAnnotation: Codable, Identifiable, Hashable {
    public var id: String
    public var chapterHref: String
    public var anchor: EPUBTextAnchor
    public var note: String
    public var colorHex: String
    public var createdAt: Date

    public init(chapterHref: String, anchor: EPUBTextAnchor, note: String, colorHex: String) {
        id = UUID().uuidString
        self.chapterHref = chapterHref
        self.anchor = anchor
        self.note = note
        self.colorHex = colorHex
        createdAt = Date()
    }
}

public enum EPUBAnnotationStore {
    public static func fileURL(for sourceURL: URL) -> URL {
        let base = sourceURL.deletingPathExtension().lastPathComponent
        return sourceURL.deletingLastPathComponent()
            .appendingPathComponent("\(base).annotations.json")
    }

    public static func load(for sourceURL: URL) throws -> [EPUBAnnotation] {
        let url = fileURL(for: sourceURL)
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([EPUBAnnotation].self, from: Data(contentsOf: url))
    }

    public static func save(_ annotations: [EPUBAnnotation], for sourceURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(annotations)
        try data.write(to: fileURL(for: sourceURL), options: .atomic)
    }
}
