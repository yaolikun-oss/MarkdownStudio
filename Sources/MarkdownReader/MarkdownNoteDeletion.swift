import Foundation

/// Moves the note and its descendants to recoverable trash and commits the
/// parent's edit as one operation; failed writes restore anything moved.
enum MarkdownNoteDeletion {
    enum Failure: LocalizedError {
        case invalidChild, missingChild, externalChange, ambiguousReferences, restoreFailed(String)
        var errorDescription: String? {
            switch self {
            case .invalidChild: "此文件不是所选父笔记的直接子笔记。"
            case .missingChild: "子笔记不存在或不是普通文件。"
            case .externalChange: "父笔记已被其他程序修改，请先处理外部修改。"
            case .ambiguousReferences: "父笔记中有多个指向该子笔记的链接，请先处理重复引用。"
            case .restoreFailed(let details): "删除未完成，部分文件未能自动恢复：\(details)。请检查废纸篓。"
            }
        }
    }
    struct Result { let parentSource: String }
    typealias Trash = (URL) throws -> URL

    /// Only a formerly referenced direct child whose last reference vanished is
    /// eligible. Ordinary links outside the child directory are never affected.
    static func removedChildren(parent: URL, before: String, after: String) -> [URL] {
        MarkdownNoteHierarchy.children(of: parent).filter { child in
            !MarkdownNoteHierarchy.references(in: before, parent: parent, child: child).isEmpty &&
            MarkdownNoteHierarchy.references(in: after, parent: parent, child: child).isEmpty
        }
    }

    static func saveRemovingChildren(parent: URL, before: String, after: String,
                                     children: [URL], trash: Trash = systemTrash) throws {
        let manager = FileManager.default
        guard try String(contentsOf: parent, encoding: .utf8) == before else { throw Failure.externalChange }
        let eligible = Set(removedChildren(parent: parent, before: before, after: after).map { $0.standardizedFileURL })
        guard Set(children.map { $0.standardizedFileURL }).count == children.count,
              children.allSatisfy({ eligible.contains($0.standardizedFileURL) }) else { throw Failure.invalidChild }
        var moved: [(original: URL, trash: URL)] = []
        do {
            for child in children {
                let values = try child.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else { throw Failure.invalidChild }
                let subtree = MarkdownNoteHierarchy.childrenDirectory(of: child)
                if manager.fileExists(atPath: subtree.path) { moved.append((subtree, try trash(subtree))) }
                moved.append((child, try trash(child)))
            }
            guard try String(contentsOf: parent, encoding: .utf8) == before else { throw Failure.externalChange }
            try after.write(to: parent, atomically: true, encoding: .utf8)
        } catch {
            var failures: [String] = []
            for item in moved.reversed() {
                do { try manager.moveItem(at: item.trash, to: item.original) }
                catch { failures.append(item.original.path) }
            }
            if !failures.isEmpty { throw Failure.restoreFailed(failures.joined(separator: ", ")) }
            throw error
        }
    }

    static func perform(parent: URL, child: URL, parentSource: String, expectedDisk: String,
                        requireManaged: Bool, trash: Trash = systemTrash) throws -> Result {
        let manager = FileManager.default
        let folder = MarkdownNoteHierarchy.childrenDirectory(of: parent).standardizedFileURL
        guard child.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath() == folder.resolvingSymlinksInPath(),
              ["md", "markdown"].contains(child.pathExtension.lowercased()) else { throw Failure.invalidChild }
        let values = try child.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw Failure.missingChild }
        guard try String(contentsOf: parent, encoding: .utf8) == expectedDisk else { throw Failure.externalChange }
        let refs = MarkdownNoteHierarchy.references(in: parentSource, parent: parent, child: child)
        guard refs.count <= 1, !requireManaged || (refs.count == 1 && refs[0].1) else { throw Failure.ambiguousReferences }
        var replacement = parentSource
        if let reference = refs.first {
            replacement = (parentSource as NSString).replacingCharacters(in: reference.0, with: "")
        }
        let subtree = MarkdownNoteHierarchy.childrenDirectory(of: child)
        var moved: [(original: URL, trash: URL)] = []
        do {
            if manager.fileExists(atPath: subtree.path) { moved.append((subtree, try trash(subtree))) }
            moved.append((child, try trash(child)))
            guard try String(contentsOf: parent, encoding: .utf8) == expectedDisk else { throw Failure.externalChange }
            try replacement.write(to: parent, atomically: true, encoding: .utf8)
            return Result(parentSource: replacement)
        } catch {
            var failures: [String] = []
            for item in moved.reversed() {
                do { try manager.moveItem(at: item.trash, to: item.original) }
                catch { failures.append(item.original.path) }
            }
            if !failures.isEmpty { throw Failure.restoreFailed(failures.joined(separator: ", ")) }
            throw error
        }
    }

    static func systemTrash(_ file: URL) throws -> URL {
        var result: NSURL?
        try FileManager.default.trashItem(at: file, resultingItemURL: &result)
        guard let url = result as URL? else { throw Failure.restoreFailed(file.path) }
        return url
    }
}
