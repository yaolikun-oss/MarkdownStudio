import Testing
@testable import MarkdownReader

@Suite struct WorkspaceEntryFlowTests {
    @Test func emptyLaunchOnlyNeedsTheOpenEntryAndBookmarks() {
        let flow = WorkspaceEntryFlow.resolve(hasProject: false, hasReadingDocument: false,
                                              hasMarkdownDocument: false, hasOpenWebPage: false)
        #expect(flow.isEmpty)
        #expect(!flow.showsProjectControls)
        #expect(!flow.showsReadingNavigation)
        #expect(!flow.showsMarkdownNavigation)
    }

    @Test func aReadingDocumentRevealsReadingAndMarkdownCreation() {
        let flow = WorkspaceEntryFlow.resolve(hasProject: true, hasReadingDocument: true,
                                              hasMarkdownDocument: false, hasOpenWebPage: false)
        #expect(!flow.isEmpty)
        #expect(flow.showsProjectControls)
        #expect(flow.showsReadingNavigation)
        #expect(flow.showsMarkdownNavigation)
    }

    @Test func projectWithoutOpenDocumentsStillShowsItsFileExplorer() {
        let flow = WorkspaceEntryFlow.resolve(hasProject: true, hasReadingDocument: false,
                                              hasMarkdownDocument: false, hasOpenWebPage: false)
        #expect(!flow.isEmpty)
        #expect(flow.showsProjectControls)
        #expect(!flow.showsReadingNavigation)
        #expect(!flow.showsMarkdownNavigation)
    }
}
