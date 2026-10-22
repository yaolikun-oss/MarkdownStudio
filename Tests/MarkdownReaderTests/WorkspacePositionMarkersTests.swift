import SwiftUI
import Testing
@testable import MarkdownReader

@Suite struct WorkspacePositionMarkersTests {
    @Test @MainActor func denseHeadingsAreGroupedWithoutLosingCurrentLocation() {
        let markers = (0..<450).map { index in
            WorkspacePositionMarker(id: String(index), fraction: Double(index) / 449,
                                    title: "标题 \(index)", current: index == 223)
        }
        let visible = WorkspacePositionMarkers.visibleMarkers(markers, height: 1200)
        #expect(visible.count <= 50)
        #expect(visible.contains(where: { $0.current && $0.id == "223" }))
        #expect(visible.contains(where: { $0.title.contains("附近还有") }))
    }
}
