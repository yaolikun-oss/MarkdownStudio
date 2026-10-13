import Foundation

enum MarkdownTableFormatter {
    static func markdown(_ input: [[String]], formatted: Bool = true) -> String {
        let columns = max(1, input.map(\.count).max() ?? 1)
        var rows = input.map { row in
            (0..<columns).map { index in index < row.count ? escape(row[index]) : "" }
        }
        if rows.isEmpty { rows = [Array(repeating: "", count: columns)] }
        let separator = Array(repeating: "---", count: columns)
        if formatted {
            let widths = (0..<columns).map { column in
                max(3, ([rows[0][column]] + rows.dropFirst().map { $0[column] }).map { $0.count }.max() ?? 3)
            }
            rows = rows.map { row in zip(row, widths).map { $0.padding(toLength: $1, withPad: " ", startingAt: 0) } }
            let paddedSeparator = widths.map { String(repeating: "-", count: $0) }
            return (rows.prefix(1).map(pipeRow) + [pipeRow(paddedSeparator)] + rows.dropFirst().map(pipeRow)).joined(separator: "\n")
        }
        return (rows.prefix(1).map(pipeRow) + [pipeRow(separator)] + rows.dropFirst().map(pipeRow)).joined(separator: "\n")
    }

    static func parseClipboard(plain: String, html: String?) -> [[String]]? {
        if plain.contains("\t") {
            var rows = plain.replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .components(separatedBy: "\n")
                .map { $0.components(separatedBy: "\t") }
            while rows.last?.allSatisfy({ $0.isEmpty }) == true { rows.removeLast() }
            return rows.count > 1 || (rows.first?.count ?? 0) > 1 ? rows : nil
        }
        guard let html, html.range(of: #"<table\b"#, options: .caseInsensitive) != nil else { return nil }
        let rowRegex = try? NSRegularExpression(pattern: #"(?is)<tr\b[^>]*>(.*?)</tr\s*>"#)
        let cellRegex = try? NSRegularExpression(pattern: #"(?is)<t[dh]\b[^>]*>(.*?)</t[dh]\s*>"#)
        let htmlNS = html as NSString
        let fullRange = NSRange(location: 0, length: htmlNS.length)
        let rowMatches = rowRegex?.matches(in: html, range: fullRange) ?? []
        let rows = rowMatches.map { rowMatch -> [String] in
            let rowContent = htmlNS.substring(with: rowMatch.range(at: 1))
            let rowNS = rowContent as NSString
            let matches = cellRegex?.matches(in: rowContent, range: NSRange(location: 0, length: rowNS.length)) ?? []
            return matches.map { match in
                let raw = rowNS.substring(with: match.range(at: 1))
                    .replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
                    .replacingOccurrences(of: #"(?s)<[^>]+>"#, with: "", options: .regularExpression)
                return decodeEntities(raw).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }.filter { !$0.isEmpty }
        return rows.count > 1 || (rows.first?.count ?? 0) > 1 ? rows : nil
    }

    private static func pipeRow(_ row: [String]) -> String { "| " + row.joined(separator: " | ") + " |" }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    private static func decodeEntities(_ value: String) -> String {
        value.replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}

private extension String {
    func padding(toLength length: Int, withPad pad: String, startingAt index: Int) -> String {
        guard count < length else { return self }
        return self + String(repeating: pad, count: length - count)
    }
}
