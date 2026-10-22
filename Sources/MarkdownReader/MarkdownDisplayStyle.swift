import Foundation

/// Preferences for one Markdown view. These values affect presentation only;
/// the Markdown file remains the shared source of truth for both editors.
struct MarkdownDisplayStyle: Codable, Equatable {
    var readerWidth: Double
    var outlineFontScale: Double
    var bodySize: Double
    var bodyFamily: String
    var bodyColorHex: String
    var backgroundHex: String
    var lineHeight: Double
    var paragraphSpacing: Double
    var strongColorHex: String
    var strongSize: Double
    var strongFamily: String
    var headingStylesData: Data
    var outlineColorsData: Data
}

extension MarkdownDisplayStyle {
    static let previewHeadingSizes: [Int: Double] = [
        1: 52, 2: 40, 3: 36, 4: 28, 5: 24, 6: 20
    ]

    /// Update only values that still match the previous defaults so personal
    /// adjustments in an existing preview remain intact.
    mutating func applyPreviewTypographyDefaults() {
        let previousDefaults = Dictionary(uniqueKeysWithValues: HeadingStyle.defaults.map { ($0.id, $0.size) })
        var styles = (try? JSONDecoder().decode([HeadingStyle].self, from: headingStylesData)) ?? HeadingStyle.defaults
        for index in styles.indices {
            let level = styles[index].id
            guard styles[index].size == previousDefaults[level],
                  let newSize = Self.previewHeadingSizes[level] else { continue }
            styles[index].size = newSize
        }
        headingStylesData = (try? JSONEncoder().encode(styles)) ?? headingStylesData
        if strongSize == 15 { strongSize = 18 }
    }
}
