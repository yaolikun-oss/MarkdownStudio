import Foundation

enum WorkspaceResourceImporter {
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
              FileManager.default.contentsEqual(atPath: source.path, andPath: copy.path) else { return nil }
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
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        var destination = directory.appendingPathComponent(source.lastPathComponent, isDirectory: false)
        if source.standardizedFileURL == destination.standardizedFileURL { return source }

        if manager.fileExists(atPath: destination.path) {
            if manager.contentsEqual(atPath: source.path, andPath: destination.path) { return destination }
            let stem = source.deletingPathExtension().lastPathComponent
            let ext = source.pathExtension
            var suffix = 2
            repeat {
                let name = ext.isEmpty ? "\(stem)-\(suffix)" : "\(stem)-\(suffix).\(ext)"
                destination = directory.appendingPathComponent(name, isDirectory: false)
                suffix += 1
            } while manager.fileExists(atPath: destination.path)
        }

        do {
            try manager.copyItem(at: source, to: destination)
            guard manager.contentsEqual(atPath: source.path, andPath: destination.path) else {
                try? manager.removeItem(at: destination)
                throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: "复制后的资料校验失败，未保留不完整副本。"])
            }
            return destination
        } catch {
            if manager.fileExists(atPath: destination.path),
               !manager.contentsEqual(atPath: source.path, andPath: destination.path) {
                try? manager.removeItem(at: destination)
            }
            throw error
        }
    }
}
