import Foundation

enum WorkspaceResourceImporter {
    static func isUnpackedEPUBDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { return false }
        return FileManager.default.fileExists(atPath: url.appendingPathComponent("META-INF/container.xml").path)
    }

    static func isSupportedWorkspaceItem(_ url: URL) -> Bool {
        if isUnpackedEPUBDirectory(url) { return true }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else { return false }
        return WorkspaceFileEntry.supported.contains(url.pathExtension.lowercased())
    }

    static func sanitizedWorkspaceName(_ value: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\0")
        let components = value.components(separatedBy: forbidden).filter { !$0.isEmpty }
        let joined = components.joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = joined.isEmpty ? "未命名学习主题" : joined
        return String(fallback.prefix(80))
    }

    static func reusableWorkspaceRoot(for source: URL, in base: URL) -> URL? {
        let name = sanitizedWorkspaceName(source.deletingPathExtension().lastPathComponent)
        let root = base.appendingPathComponent(name, isDirectory: true)
        let manifest = root.appendingPathComponent("\(name).mdworkspace")
        let copy = root.appendingPathComponent("阅读资料", isDirectory: true)
            .appendingPathComponent(source.lastPathComponent)
        guard FileManager.default.fileExists(atPath: manifest.path),
              FileManager.default.fileExists(atPath: copy.path),
              itemsEqual(source, copy) else { return nil }
        return root
    }

    static func nextWorkspaceRoot(named name: String, in base: URL) -> URL {
        let manager = FileManager.default
        var root = base.appendingPathComponent(name, isDirectory: true)
        var suffix = 2
        while manager.fileExists(atPath: root.path) {
            root = base.appendingPathComponent("\(name) \(suffix)", isDirectory: true)
            suffix += 1
        }
        return root
    }

    static func copyVerified(_ source: URL, into directory: URL) throws -> URL {
        let manager = FileManager.default
        let sourceValues = try source.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard sourceValues.isSymbolicLink != true else {
            throw CocoaError(.fileReadUnsupportedScheme, userInfo: [NSLocalizedDescriptionKey: "不能导入符号链接。"])
        }
        let sourceIsDirectory = sourceValues.isDirectory == true
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        var destination = directory.appendingPathComponent(source.lastPathComponent, isDirectory: sourceIsDirectory)
        if source.standardizedFileURL == destination.standardizedFileURL { return source }

        if manager.fileExists(atPath: destination.path) {
            if itemsEqual(source, destination) { return destination }
            let stem = source.deletingPathExtension().lastPathComponent
            let ext = source.pathExtension
            var suffix = 2
            repeat {
                let name = ext.isEmpty ? "\(stem)-\(suffix)" : "\(stem)-\(suffix).\(ext)"
                destination = directory.appendingPathComponent(name, isDirectory: sourceIsDirectory)
                suffix += 1
            } while manager.fileExists(atPath: destination.path)
        }

        do {
            try manager.copyItem(at: source, to: destination)
            guard itemsEqual(source, destination) else {
                try? manager.removeItem(at: destination)
                throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: "复制后的资料校验失败，未保留不完整副本。"])
            }
            return destination
        } catch {
            if manager.fileExists(atPath: destination.path),
               !itemsEqual(source, destination) {
                try? manager.removeItem(at: destination)
            }
            throw error
        }
    }

    /// Compare complete directory trees, not just their top-level directory
    /// metadata. EPUB folders normally contain nested XHTML, images and font
    /// files, all of which must survive an import before the source is used.
    static func itemsEqual(_ lhs: URL, _ rhs: URL) -> Bool {
        guard let left = try? lhs.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]),
              let right = try? rhs.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]),
              left.isSymbolicLink != true, right.isSymbolicLink != true,
              left.isDirectory == right.isDirectory else { return false }
        if left.isDirectory != true {
            guard left.fileSize == right.fileSize else { return false }
            return FileManager.default.contentsEqual(atPath: lhs.path, andPath: rhs.path)
        }
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]
        guard let leftChildren = try? FileManager.default.contentsOfDirectory(at: lhs, includingPropertiesForKeys: keys),
              let rightChildren = try? FileManager.default.contentsOfDirectory(at: rhs, includingPropertiesForKeys: keys) else { return false }
        let leftNames = Set(leftChildren.map(\.lastPathComponent))
        guard leftNames == Set(rightChildren.map(\.lastPathComponent)) else { return false }
        return leftChildren.allSatisfy { child in
            itemsEqual(child, rhs.appendingPathComponent(child.lastPathComponent))
        }
    }
}
