import Foundation
import Markdown

enum MarkdownEditingTarget {
    static func sourceIsVisible(hasReadingDocument: Bool, usesReadingSplit: Bool,
                                sourceOnly: Bool, displayMode: ReaderDisplayMode) -> Bool {
        if hasReadingDocument && usesReadingSplit { return sourceOnly }
        return displayMode != .read
    }
}

struct MarkdownViewportAnchor: Equatable {
    var sourceOffset: Int
    var screenY: Double
}

struct MarkdownVisualAnchor: Codable, Equatable {
    var index: Int
    var offset: Int
}

/// Maps visible text boundaries to UTF-16 source boundaries. Markdown delimiters
/// are absent from the DOM, while NSTextView selections include those delimiters.
struct MarkdownTextPositionMap {
    private(set) var text = ""
    private(set) var sourceOffsets: [Int] = [0]

    init(source: String) {
        let bytes = Array(source.utf8)
        var byteToUTF16 = Array(repeating: 0, count: bytes.count + 1)
        var byteIndex = 0
        var utf16Index = 0
        for scalar in source.unicodeScalars {
            for index in byteIndex..<(byteIndex + scalar.utf8.count) { byteToUTF16[index] = utf16Index }
            byteIndex += scalar.utf8.count
            utf16Index += scalar.utf16.count
            byteToUTF16[byteIndex] = utf16Index
        }
        var lineStarts = [0]
        for (index, byte) in bytes.enumerated() where byte == 10 { lineStarts.append(index + 1) }
        func offset(_ location: SourceLocation) -> Int {
            let line = min(max(0, location.line - 1), lineStarts.count - 1)
            return byteToUTF16[min(bytes.count, lineStarts[line] + max(0, location.column - 1))]
        }
        let raw = source as NSString
        func append(_ value: String, range: SourceRange?) {
            guard !value.isEmpty else { return }
            let start = range.map { offset($0.lowerBound) } ?? sourceOffsets.last ?? 0
            let end = range.map { offset($0.upperBound) } ?? start
            let span = NSRange(location: min(start, raw.length), length: max(0, min(end, raw.length) - start))
            let units = Array(value.utf16)
            let found = raw.range(of: value, options: [], range: span)
            let positions: [Int]
            if found.location != NSNotFound {
                positions = (0...units.count).map { found.location + $0 }
            } else {
                // Escapes/entities can change text length. Stay within this AST
                // leaf's source span instead of matching a repeated word elsewhere.
                positions = (0...units.count).map {
                    start + Int((Double(max(0, end - start)) * Double($0) / Double(units.count)).rounded())
                }
            }
            sourceOffsets[sourceOffsets.count - 1] = positions[0]
            sourceOffsets.append(contentsOf: positions.dropFirst())
            text += value
        }
        func walk(_ node: Markup) {
            if let leaf = node as? Markdown.Text { append(leaf.string, range: leaf.range); return }
            if let code = node as? InlineCode { append(code.code, range: code.range); return }
            if let code = node as? CodeBlock { append(code.code, range: code.range); return }
            if node is SoftBreak || node is LineBreak { append("\n", range: node.range); return }
            if node is Image || node is InlineHTML || node is HTMLBlock { return }
            for child in node.children { walk(child) }
        }
        walk(Document(parsing: source))
    }

    func sourceOffset(forTextOffset offset: Int) -> Int {
        sourceOffsets[min(max(0, offset), sourceOffsets.count - 1)]
    }

    func textOffset(forSourceOffset offset: Int) -> Int {
        var low = 0
        var high = sourceOffsets.count
        while low < high {
            let middle = (low + high) / 2
            if sourceOffsets[middle] < offset { low = middle + 1 } else { high = middle }
        }
        return min(low, sourceOffsets.count - 1)
    }
}
