import Foundation

/// Keeps first-run navigation separate from the document implementation.
/// The UI should only reveal sections that currently have something useful to
/// show, while web bookmarks remain reachable without opening a project.
struct WorkspaceEntryFlow: Equatable {
    let hasProject: Bool
    let hasReadingDocument: Bool
    let hasMarkdownDocument: Bool
    let hasOpenWebPage: Bool

    var isEmpty: Bool {
        !hasProject && !hasReadingDocument && !hasMarkdownDocument && !hasOpenWebPage
    }

    var showsProjectControls: Bool { !isEmpty }
    var showsReadingNavigation: Bool { hasReadingDocument }
    var showsMarkdownNavigation: Bool { hasMarkdownDocument || hasReadingDocument }

    static func resolve(hasProject: Bool, hasReadingDocument: Bool,
                        hasMarkdownDocument: Bool, hasOpenWebPage: Bool) -> WorkspaceEntryFlow {
        WorkspaceEntryFlow(hasProject: hasProject, hasReadingDocument: hasReadingDocument,
                           hasMarkdownDocument: hasMarkdownDocument, hasOpenWebPage: hasOpenWebPage)
    }
}
