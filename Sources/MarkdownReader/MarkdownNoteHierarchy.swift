import Foundation
import Markdown

/// Each note's children live in a sibling directory named after the full file
/// name. Including the extension keeps `a.md` and `a.markdown` distinct.
enum MarkdownNoteHierarchy {
    enum CreationError: LocalizedError {
        case invalidTitle
        case invalidSelection

        var errorDescription: String? {
            switch self {
            case .invalidTitle: "请输入有效的子笔记名称，名称不能包含斜线。"
            case .invalidSelection: "请选择单行文字作为链接，或将光标放在插入位置。"
            }
        }
    }

    static func childrenDirectory(of note: URL) -> URL {
        note.deletingLastPathComponent().appendingPathComponent(note.lastPathComponent + ".notes", isDirectory: true)
    }

    static func parent(of note: URL) -> URL? {
        let directory = note.deletingLastPathComponent()
        guard directory.lastPathComponent.hasSuffix(".notes") else { return nil }
        let parentName = String(directory.lastPathComponent.dropLast(6))
        let parent = directory.deletingLastPathComponent().appendingPathComponent(parentName)
        guard ["md", "markdown"].contains(parent.pathExtension.lowercased()),
              FileManager.default.fileExists(atPath: parent.path) else { return nil }
        return parent
    }

    static func children(of note: URL) -> [URL] {
        let directory = childrenDirectory(of: note)
        return ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])) ?? [])
            .filter { ["md", "markdown"].contains($0.pathExtension.lowercased()) && ((try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    static func root(of note: URL) -> URL {
        var root = note.standardizedFileURL
        while let parent = parent(of: root) { root = parent.standardizedFileURL }
        return root
    }

    static func inlineLink(parent: URL, title: String, label: String) throws -> (URL, String) {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"),
              !name.contains("\0"), !name.contains("\n"), !name.contains("\r") else {
            throw CreationError.invalidTitle
        }
        guard !label.contains("\n"), !label.contains("\r") else { throw CreationError.invalidSelection }
        let directory = childrenDirectory(of: parent)
        var child = directory.appendingPathComponent(name + ".md")
        var suffix = 2
        while FileManager.default.fileExists(atPath: child.path) {
            child = directory.appendingPathComponent("\(name) \(suffix).md")
            suffix += 1
        }
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "%#?()")
        let relative = parent.lastPathComponent + ".notes/" + child.lastPathComponent
        let encoded = relative.addingPercentEncoding(withAllowedCharacters: allowed) ?? relative
        let escaped = label.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        return (child, "[\(escaped)](\(encoded) \"mdstudio-page\")")
    }

    static func references(in source: String, parent: URL, child: URL) -> [(NSRange, Bool)] {
        let lines = source.components(separatedBy: "\n")
        let raw = source as NSString
        var lineOffsets: [Int] = [0]
        for line in lines.dropLast() { lineOffsets.append(lineOffsets.last! + line.utf16.count + 1) }
        func offset(_ location: SourceLocation) -> Int? {
            let line = location.line - 1
            guard lines.indices.contains(line) else { return nil }
            let value = lines[line]
            let bytes = value.utf8
            guard location.column >= 1, location.column - 1 <= bytes.count else { return nil }
            let index = bytes.index(bytes.startIndex, offsetBy: location.column - 1)
            guard let end = String.Index(index, within: value) else { return nil }
            return lineOffsets[line] + value[..<end].utf16.count
        }
        var found: [(NSRange, Bool)] = []
        func walk(_ markup: Markup) {
            if let link = markup as? Link, let destination = link.destination,
               let relative = destination.removingPercentEncoding, !relative.contains(":"),
               parent.deletingLastPathComponent().appendingPathComponent(relative).standardizedFileURL == child.standardizedFileURL,
               let range = link.range, let start = offset(range.lowerBound), let end = offset(range.upperBound),
               start <= end, end <= raw.length {
                found.append((NSRange(location: start, length: end - start), link.title == "mdstudio-page"))
            }
            for item in markup.children { walk(item) }
        }
        walk(Document(parsing: source))
        return found
    }
}

struct MarkdownNoteNode: Identifiable {
    let url: URL
    let children: [MarkdownNoteNode]
    var id: String { url.standardizedFileURL.path }

    init(_ url: URL, depth: Int = 0) {
        self.url = url
        self.children = depth < 32 ? MarkdownNoteHierarchy.children(of: url).map { MarkdownNoteNode($0, depth: depth + 1) } : []
    }
}
