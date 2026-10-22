import Foundation

/// Versioned preview bundles share the user's settings on first launch only.
enum WorkspacePreferenceUpgrade {
    static func importPreviousDefaultsIfNeeded() {
        let target = "local.markdownreader.visual.v0731"
        guard Bundle.main.bundleIdentifier == target else { return }
        let defaults = UserDefaults.standard
        let marker = "workspace.importedPreferences0731"
        guard !defaults.bool(forKey: marker) else { return }
        let existing = defaults.persistentDomain(forName: target) ?? [:]
        let prefixes = ["reader.", "markdown.", "workspace.", "pdf.", "epub.", "web.", "epubNotebook.", "office."]
        for domain in ["local.markdownreader.visual.v0730", "local.markdownreader.visual.v0729"] {
            guard let previous = defaults.persistentDomain(forName: domain), !previous.isEmpty else { continue }
            for (key, value) in previous where existing[key] == nil && prefixes.contains(where: key.hasPrefix) {
                defaults.set(value, forKey: key)
            }
            break
        }
        defaults.set(true, forKey: marker)
    }
}
