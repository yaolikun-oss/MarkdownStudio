import SwiftUI

struct WorkspacePositionMarker: Identifiable {
    let id: String
    let fraction: Double
    let title: String
    let current: Bool
}

/// A compact outline map beside the native scroll bar. It never replaces the
/// scroll bar; every mark has a document location and can be clicked.
struct WorkspacePositionMarkers: View {
    let markers: [WorkspacePositionMarker]
    let onSelect: (String) -> Void

    /// A long book can contain hundreds of headings. Drawing a button for each
    /// one makes the rail look like a solid barcode and adds needless controls.
    static func visibleMarkers(_ markers: [WorkspacePositionMarker], height: CGFloat) -> [WorkspacePositionMarker] {
        guard height > 0 else { return [] }
        let bucketCount = max(1, Int(height / 24))
        var buckets: [Int: [WorkspacePositionMarker]] = [:]
        for marker in markers {
            let bucket = min(bucketCount - 1, max(0, Int(marker.fraction * Double(bucketCount))))
            buckets[bucket, default: []].append(marker)
        }
        return buckets.keys.sorted().compactMap { bucket in
            guard let group = buckets[bucket], let first = group.first else { return nil }
            let representative = group.first(where: \.current) ?? first
            return WorkspacePositionMarker(id: representative.id,
                                           fraction: representative.fraction,
                                           title: group.count == 1 ? representative.title : "\(representative.title) · 附近还有 \(group.count - 1) 处",
                                           current: group.contains(where: \.current))
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ForEach(Self.visibleMarkers(markers, height: geometry.size.height)) { marker in
                    Button { onSelect(marker.id) } label: {
                        Capsule()
                            .fill(marker.current ? Color.gray.opacity(0.8) : Color.gray.opacity(0.38))
                            .frame(width: marker.current ? 11 : 7, height: 2)
                            .frame(width: 16, height: 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(marker.title)
                    .accessibilityLabel(marker.title)
                    .position(x: 8, y: max(4, min(geometry.size.height - 4,
                                                 geometry.size.height * marker.fraction)))
                }
            }
        }
        .frame(width: 16)
        .padding(.trailing, 13)
    }
}
