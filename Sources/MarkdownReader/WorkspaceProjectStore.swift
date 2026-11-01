import Foundation

/// Creates project manifests outside the study folder. Opening a book must not
/// scatter hidden files beside it or include every sibling by accident.
struct WorkspaceProjectStore {
    let directory: URL

    static func makeDefault(fileManager: FileManager = .default) -> WorkspaceProjectStore {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return WorkspaceProjectStore(directory: support.appendingPathComponent("Markdown Studio/Workspaces", isDirectory: true))
    }

    func manifestURL(for resource: URL) -> URL {
        let canonical = resource.standardizedFileURL.resolvingSymlinksInPath().path
        let rawName = resource.deletingPathExtension().lastPathComponent
        let name = rawName.replacingOccurrences(of: #"[^\p{L}\p{N}._-]+"#, with: "-", options: .regularExpression)
        return directory.appendingPathComponent("\(name.isEmpty ? "项目" : name)-\(stableID(canonical)).mdworkspace")
    }

    func ensureProject(for resource: URL, isFolder: Bool, layout: WorkspaceGridLayout,
                       fileManager: FileManager = .default) throws -> (URL, WorkspaceDocument) {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let manifest = manifestURL(for: resource)
        if let data = try? Data(contentsOf: manifest),
           let existing = try? JSONDecoder().decode(WorkspaceDocument.self, from: data), existing.isValid {
            return (manifest, existing)
        }
        let document = WorkspaceDocument(folders: isFolder ? [resource.standardizedFileURL] : [],
                                         files: isFolder ? [] : [resource.standardizedFileURL], layout: layout)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(document).write(to: manifest, options: .atomic)
        return (manifest, document)
    }

    private func stableID(_ value: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in value.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return String(hash, radix: 16)
    }
}
