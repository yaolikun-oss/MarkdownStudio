import Foundation
import Markdown

struct MarkdownBlock: Identifiable, Sendable {
    let id: String
    let html: String
    let title: String?
    let headingLevel: Int?
    let parentID: String?
    let sourceLine: Int

    static func parse(_ source: String) -> [MarkdownBlock] {
        let parsedDocument = Document(parsing: source)
        var softBreaks = SoftBreakToLineBreak()
        let document = (softBreaks.visit(parsedDocument) as? Document) ?? parsedDocument
        var blocks: [MarkdownBlock] = []
        var headingIDs: [Int: String] = [:]

        for markup in document.children {
            guard let heading = markup as? Heading else {
                blocks.append(MarkdownBlock(id: "block-\(blocks.count)", html: "<div data-source-line=\"\(markup.range?.lowerBound.line ?? 1)\">\(safeHTML(markup))</div>", title: nil, headingLevel: nil, parentID: nil, sourceLine: markup.range?.lowerBound.line ?? 1))
                continue
            }

            let level = heading.level
            guard (1...6).contains(level) else { continue }
            if level < 6 {
                for deeperLevel in (level + 1)...6 { headingIDs.removeValue(forKey: deeperLevel) }
            }
            let id = "heading-\(blocks.count)"
            let parentID = (1..<level).reversed().compactMap { headingIDs[$0] }.first
            headingIDs[level] = id
            let title = heading.plainText
            let inlineParagraph = Paragraph(heading.children.compactMap { $0 as? InlineMarkup })
            let rendered = safeHTML(inlineParagraph)
                .replacingOccurrences(of: "<p>", with: "<h\(level) id=\"\(id)\">")
                .replacingOccurrences(of: "</p>", with: "</h\(level)>")
            blocks.append(MarkdownBlock(
                id: id,
                html: "<div data-source-line=\"\(markup.range?.lowerBound.line ?? 1)\">\(rendered)</div>",
                title: title,
                headingLevel: level,
                parentID: parentID,
                sourceLine: markup.range?.lowerBound.line ?? 1
            ))
        }
        return blocks
    }

    private static func safeHTML(_ markup: Markup) -> String {
        if let code = markup as? CodeBlock {
            let classAttribute = code.language.map { " class=\"language-\(escapeHTMLAttribute($0))\"" } ?? ""
            return "<pre><code\(classAttribute)>\(escapeHTML(code.code))</code></pre>"
        }
        var html = HTMLFormatter.format(markup)
        // Markdown image URLs can otherwise make the reader contact remote servers
        // automatically. Local relative images continue to work from the document folder.
        html = replacing(pattern: #"(?i)\bsrc\s*=\s*([\"'])https?://[^\"']*\1"#, in: html, with: "data-reader-remote-image=\"blocked\"")
        return html
    }

    private static func replacing(pattern: String, in input: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        let range = NSRange(input.startIndex..., in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: replacement)
    }

    private static func escapeHTML(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func escapeHTMLAttribute(_ value: String) -> String { escapeHTML(value) }
}

/// In this reader, a single Return in source should remain a visible line break.
/// CommonMark treats it as a soft break (usually collapsed to a space in HTML),
/// so convert soft breaks to hard breaks for preview rendering.
private struct SoftBreakToLineBreak: MarkupRewriter {
    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> Markup? {
        LineBreak()
    }
}
