import Foundation

/// A workspace stores references and layout only; document contents remain in
/// their original files and keep their existing save and close behavior.
struct WorkspaceDocument: Codable, Equatable {
    static let currentVersion = 1
    var version = currentVersion
    var folders: [URL]
    var files: [URL] = []
    var layout: WorkspaceGridLayout

    var isValid: Bool {
        version == Self.currentVersion && layout.isValid && folders.allSatisfy(\.isFileURL) && files.allSatisfy(\.isFileURL)
    }

    var missingFiles: [URL] {
        let resources = folders + files + layout.allTabs.compactMap { tab in
            tab.kind == .web ? nil : tab.location
        }
        var seen = Set<String>()
        return resources.filter { url in
            let path = url.standardizedFileURL.path
            guard seen.insert(path).inserted else { return false }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return true }
            return folders.contains(where: { $0.standardizedFileURL.path == path }) && !isDirectory.boolValue
        }
    }
}
