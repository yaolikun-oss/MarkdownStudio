import AppKit
import Foundation

enum MarkdownImageAssetError: LocalizedError {
    case unreadableImage
    case unsupportedImage
    case invalidAssetDirectory

    var errorDescription: String? {
        switch self {
        case .unreadableImage: "无法读取图片，请重新截图或选择图片文件。"
        case .unsupportedImage: "请选择 PNG、JPEG 或 GIF 图片。"
        case .invalidAssetDirectory: "图片资源文件夹不是普通文件夹，无法写入。"
        }
    }
}

@MainActor
enum MarkdownImageAssets {
    static func canImportClipboard(_ pasteboard: NSPasteboard) -> Bool {
        if pasteboard.availableType(from: [.png, .tiff]) != nil { return true }
        guard let file = pasteboard.readObjects(forClasses: [NSURL.self],
                                               options: [.urlReadingFileURLsOnly: true])?.first as? URL else {
            return false
        }
        return ["png", "jpg", "jpeg", "gif"].contains(file.pathExtension.lowercased())
    }

    static func blockInsertion(_ markdown: String, in source: String, replacing range: NSRange) -> String {
        let text = source as NSString
        let start = min(range.location, text.length)
        let end = min(start + range.length, text.length)
        let before = text.substring(to: start)
        let after = text.substring(from: end)
        let prefix = before.isEmpty || before.hasSuffix("\n\n") ? "" : before.hasSuffix("\n") ? "\n" : "\n\n"
        let suffix = after.isEmpty || after.hasPrefix("\n\n") ? "" : after.hasPrefix("\n") ? "\n" : "\n\n"
        return prefix + markdown + suffix
    }

    static func importClipboard(_ pasteboard: NSPasteboard, beside noteURL: URL) throws -> String? {
        if let png = pasteboard.data(forType: .png) {
            guard NSBitmapImageRep(data: png) != nil else { throw MarkdownImageAssetError.unreadableImage }
            return try write(png, extension: "png", altText: "截图", beside: noteURL)
        }
        if let tiff = pasteboard.data(forType: .tiff) {
            guard let image = NSBitmapImageRep(data: tiff),
                  let png = image.representation(using: .png, properties: [:]) else {
                throw MarkdownImageAssetError.unreadableImage
            }
            return try write(png, extension: "png", altText: "截图", beside: noteURL)
        }
        if let file = pasteboard.readObjects(forClasses: [NSURL.self],
                                             options: [.urlReadingFileURLsOnly: true])?.first as? URL,
           ["png", "jpg", "jpeg", "gif"].contains(file.pathExtension.lowercased()) {
            return try importFile(file, beside: noteURL)
        }
        return nil
    }

    static func importFile(_ imageURL: URL, beside noteURL: URL) throws -> String {
        let fileExtension = imageURL.pathExtension.lowercased()
        guard ["png", "jpg", "jpeg", "gif"].contains(fileExtension) else {
            throw MarkdownImageAssetError.unsupportedImage
        }
        let data = try Data(contentsOf: imageURL)
        guard NSImage(data: data) != nil else { throw MarkdownImageAssetError.unreadableImage }
        return try write(data, extension: fileExtension,
                         altText: imageURL.deletingPathExtension().lastPathComponent, beside: noteURL)
    }

    private static func write(_ data: Data, extension fileExtension: String,
                              altText: String, beside noteURL: URL) throws -> String {
        let directory = noteURL.deletingLastPathComponent()
            .appendingPathComponent(noteURL.deletingPathExtension().lastPathComponent + ".assets", isDirectory: true)
        let manager = FileManager.default
        if manager.fileExists(atPath: directory.path) {
            let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw MarkdownImageAssetError.invalidAssetDirectory
            }
        } else {
            try manager.createDirectory(at: directory, withIntermediateDirectories: false)
        }
        let imageURL = directory.appendingPathComponent("image-\(UUID().uuidString.lowercased()).\(fileExtension)")
        try data.write(to: imageURL, options: .atomic)
        let relativePath = "\(encodedPathComponent(directory.lastPathComponent))/\(imageURL.lastPathComponent)"
        let safeAlt = altText.replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
            .replacingOccurrences(of: "\n", with: " ")
        return "![\(safeAlt)](\(relativePath))"
    }

    private static func encodedPathComponent(_ name: String) -> String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#%()<> \t\n"))
        return name.addingPercentEncoding(withAllowedCharacters: allowed) ?? name
    }
}
