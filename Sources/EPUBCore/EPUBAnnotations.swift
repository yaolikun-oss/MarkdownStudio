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
    public var markStyle: EPUBAnnotationMarkStyle
    public var createdAt: Date

    public init(chapterHref: String, anchor: EPUBTextAnchor, note: String, colorHex: String,
                markStyle: EPUBAnnotationMarkStyle = .highlight) {
        id = UUID().uuidString
        self.chapterHref = chapterHref
        self.anchor = anchor
        self.note = note
        self.colorHex = colorHex
        self.markStyle = markStyle
        createdAt = Date()
    }

    private enum CodingKeys: String, CodingKey { case id, chapterHref, anchor, note, colorHex, markStyle, createdAt }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        chapterHref = try values.decode(String.self, forKey: .chapterHref)
        anchor = try values.decode(EPUBTextAnchor.self, forKey: .anchor)
        note = try values.decode(String.self, forKey: .note)
        colorHex = try values.decode(String.self, forKey: .colorHex)
        markStyle = try values.decodeIfPresent(EPUBAnnotationMarkStyle.self, forKey: .markStyle) ?? .highlight
        createdAt = try values.decode(Date.self, forKey: .createdAt)
    }
}

public enum EPUBAnnotationMarkStyle: String, Codable, CaseIterable, Identifiable {
    case highlight
    case underline
    public var id: String { rawValue }
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
