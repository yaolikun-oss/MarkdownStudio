import AppKit
import SwiftUI

struct NotebookSplitView: NSViewRepresentable {
    let primary: AnyView
    let notes: AnyView
    let rightPaneWidth: CGFloat
    let minimumPrimaryWidth: CGFloat
    let minimumNotesWidth: CGFloat
    let onRightPaneWidthChange: (CGFloat) -> Void

    func makeNSView(context: Context) -> NotebookNativeSplitView {
        NotebookNativeSplitView(primary: primary, notes: notes, rightPaneWidth: rightPaneWidth,
            minimumPrimaryWidth: minimumPrimaryWidth, minimumNotesWidth: minimumNotesWidth,
            onRightPaneWidthChange: onRightPaneWidthChange)
    }

    func updateNSView(_ splitView: NotebookNativeSplitView, context: Context) {
        splitView.update(primary: primary, notes: notes, requestedRightWidth: rightPaneWidth,
            onRightPaneWidthChange: onRightPaneWidthChange)
    }
}

struct WorkspaceSidebarSplitView: NSViewRepresentable {
    let sidebar: AnyView
    let content: AnyView
    let sidebarWidth: CGFloat
    let showsSidebar: Bool
    let onSidebarWidthChange: (CGFloat) -> Void

    func makeNSView(context: Context) -> NotebookNativeSplitView {
        NotebookNativeSplitView(primary: sidebar, notes: content, rightPaneWidth: 720,
            minimumPrimaryWidth: 190, minimumNotesWidth: 320,
            onRightPaneWidthChange: onSidebarWidthChange,
            primaryPaneWidth: sidebarWidth, maximumPrimaryWidth: 480, showsPrimary: showsSidebar)
    }

    func updateNSView(_ view: NotebookNativeSplitView, context: Context) {
        view.updateSidebar(primary: sidebar, notes: content, width: sidebarWidth,
                           visible: showsSidebar, onWidthChange: onSidebarWidthChange)
    }
}

/// The split owns its geometry. Hosted SwiftUI contents supply neither intrinsic
/// width constraints nor preferred sizes for the divider to negotiate against.
/// A separate delegate avoids NSSplitView's optional-selector forwarding
/// recursively asking itself whether it responds during menu validation.
private final class NotebookSplitDelegate: NSObject, NSSplitViewDelegate {
    weak var owner: NotebookNativeSplitView?
    init(owner: NotebookNativeSplitView) { self.owner = owner }
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposed: CGFloat, ofSubviewAt index: Int) -> CGFloat {
        owner?.splitView(splitView, constrainMinCoordinate: proposed, ofSubviewAt: index) ?? proposed
    }
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposed: CGFloat, ofSubviewAt index: Int) -> CGFloat {
        owner?.splitView(splitView, constrainMaxCoordinate: proposed, ofSubviewAt: index) ?? proposed
    }
    func splitView(_ splitView: NSSplitView, effectiveRect proposed: NSRect, forDrawnRect drawn: NSRect, ofDividerAt index: Int) -> NSRect {
        owner?.splitView(splitView, effectiveRect: proposed, forDrawnRect: drawn, ofDividerAt: index) ?? proposed
    }
}

final class NotebookNativeSplitView: NSSplitView {
    private lazy var splitDelegate = NotebookSplitDelegate(owner: self)
    private let primaryHost: NSHostingView<AnyView>
    private let notesHost: NSHostingView<AnyView>
    private let minimumPrimaryWidth: CGFloat
    private let minimumNotesWidth: CGFloat
    private var requestedRightWidth: CGFloat
    private var rightFraction: CGFloat?
    private var isDraggingDivider = false
    private var applyingFrames = false
    private var onRightPaneWidthChange: (CGFloat) -> Void
    private var preferredPrimaryWidth: CGFloat?
    private let maximumPrimaryWidth: CGFloat?
    private var showsPrimary: Bool
    private var dividerTrackingArea: NSTrackingArea?
    private var dividerHovered = false

    init(primary: AnyView, notes: AnyView, rightPaneWidth: CGFloat,
         minimumPrimaryWidth: CGFloat, minimumNotesWidth: CGFloat,
         onRightPaneWidthChange: @escaping (CGFloat) -> Void,
         primaryPaneWidth: CGFloat? = nil, maximumPrimaryWidth: CGFloat? = nil, showsPrimary: Bool = true) {
        primaryHost = NSHostingView(rootView: primary)
        notesHost = NSHostingView(rootView: notes)
        self.requestedRightWidth = rightPaneWidth
        self.minimumPrimaryWidth = minimumPrimaryWidth
        self.minimumNotesWidth = minimumNotesWidth
        self.onRightPaneWidthChange = onRightPaneWidthChange
        self.preferredPrimaryWidth = primaryPaneWidth
        self.maximumPrimaryWidth = maximumPrimaryWidth
        self.showsPrimary = showsPrimary
        super.init(frame: .zero)
        isVertical = true
        dividerStyle = .thin
        delegate = splitDelegate
        for host in [primaryHost, notesHost] {
            host.sizingOptions = []
            host.autoresizingMask = []
            addSubview(host)
        }
        setAccessibilityIdentifier("notebook-split")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override var dividerThickness: CGFloat { showsPrimary ? 5 : 0 }

    var dividerHitRect: NSRect {
        guard showsPrimary else { return .zero }
        return NSRect(x: primaryHost.frame.maxX + dividerThickness / 2 - 4,
                      y: bounds.minY, width: 8, height: bounds.height)
    }

    var dividerCursorRect: NSRect {
        // Keep the resize cursor close to the divider. The mouse target remains
        // slightly wider than the visible line, without covering nearby controls.
        NSRect(x: dividerHitRect.midX - 3, y: bounds.minY, width: 6, height: bounds.height)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // NSView.hitTest receives a point in this view's local coordinates.
        // Converting it from superview coordinates shifts the hit region whenever
        // the split view itself is not at the window origin.
        if dividerHitRect.contains(point) { return self }
        return super.hitTest(point)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if showsPrimary { addCursorRect(dividerCursorRect, cursor: .resizeLeftRight) }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        guard showsPrimary else {
            if let dividerTrackingArea { removeTrackingArea(dividerTrackingArea) }
            dividerTrackingArea = nil
            return
        }
        let hoverRect = NSRect(x: dividerHitRect.midX - 5, y: bounds.minY,
                               width: 10, height: bounds.height)
        if dividerTrackingArea?.rect == hoverRect { return }
        if let dividerTrackingArea { removeTrackingArea(dividerTrackingArea) }
        let tracking = NSTrackingArea(rect: hoverRect,
            options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self)
        addTrackingArea(tracking)
        dividerTrackingArea = tracking
    }

    override func mouseEntered(with event: NSEvent) { dividerHovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { dividerHovered = false; needsDisplay = true }

    override func drawDivider(in rect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        rect.fill()
        NSColor(calibratedWhite: dividerHovered ? 0.78 : 0.88, alpha: 1).setFill()
        let lineWidth: CGFloat = dividerHovered ? 3 : 1
        NSRect(x: rect.midX - lineWidth / 2, y: rect.minY, width: lineWidth, height: rect.height).fill()
        NSColor(calibratedWhite: dividerHovered ? 0.61 : 0.73, alpha: 1).setFill()
        for offset in [-6.0, 0, 6.0] {
            NSBezierPath(ovalIn: NSRect(x: rect.midX - 1, y: rect.midY + offset - 1, width: 2, height: 2)).fill()
        }
    }

    func updateSidebar(primary: AnyView, notes: AnyView, width: CGFloat, visible: Bool,
                       onWidthChange: @escaping (CGFloat) -> Void) {
        preferredPrimaryWidth = width
        showsPrimary = visible
        onRightPaneWidthChange = onWidthChange
        primaryHost.rootView = primary
        notesHost.rootView = notes
        layoutPanes()
    }

    func update(primary: AnyView, notes: AnyView, requestedRightWidth: CGFloat,
                onRightPaneWidthChange: @escaping (CGFloat) -> Void) {
        self.onRightPaneWidthChange = onRightPaneWidthChange
        if abs(self.requestedRightWidth - requestedRightWidth) > 0.5 {
            self.requestedRightWidth = requestedRightWidth
            rightFraction = bounds.width > dividerThickness
                ? requestedRightWidth / (bounds.width - dividerThickness) : nil
        }
        primaryHost.rootView = primary
        notesHost.rootView = notes
        layoutPanes()
    }

    override func layout() {
        super.layout()
        layoutPanes()
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) { layoutPanes() }

    private func layoutPanes() {
        guard !isDraggingDivider, !applyingFrames, bounds.width > dividerThickness else { return }
        applyingFrames = true
        defer { applyingFrames = false }
        primaryHost.isHidden = !showsPrimary
        guard showsPrimary else {
            primaryHost.frame = .zero
            notesHost.frame = bounds
            updateTrackingAreas()
            window?.invalidateCursorRects(for: self)
            needsDisplay = true
            return
        }
        let available = bounds.width - dividerThickness
        let right = WorkspaceSplitSizing.clampedRightPaneWidth(
            requested: rightFraction.map { $0 * available } ?? requestedRightWidth,
            totalWidth: bounds.width, dividerWidth: dividerThickness,
            minimumPrimaryWidth: minimumPrimaryWidth, minimumNotesWidth: minimumNotesWidth)
        if rightFraction == nil { rightFraction = right / available }
        let left: CGFloat
        if let preferredPrimaryWidth {
            left = min(max(minimumPrimaryWidth, preferredPrimaryWidth),
                       min(maximumPrimaryWidth ?? .greatestFiniteMagnitude, max(0, available - minimumNotesWidth)))
        } else { left = max(0, available - right) }
        let primaryFrame = NSRect(x: 0, y: 0, width: left, height: bounds.height)
        let notesFrame = NSRect(x: left + dividerThickness, y: 0, width: max(0, available - left), height: bounds.height)
        if primaryHost.frame != primaryFrame { primaryHost.frame = primaryFrame }
        if notesHost.frame != notesFrame { notesHost.frame = notesFrame }
        updateTrackingAreas()
        window?.invalidateCursorRects(for: self)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard dividerHitRect.contains(point) else {
            super.mouseDown(with: event)
            return
        }
        isDraggingDivider = true
        super.mouseDown(with: event)
        isDraggingDivider = false
        recordUserDividerPosition()
    }

    // Called once at the end of native divider tracking, never for hosted-content
    // refreshes. Also provides an integration-test seam for the native geometry.
    func recordUserDividerPosition() {
        guard bounds.width > dividerThickness else { return }
        if preferredPrimaryWidth != nil {
            preferredPrimaryWidth = primaryHost.frame.width
            onRightPaneWidthChange(primaryHost.frame.width)
        } else {
            requestedRightWidth = notesHost.frame.width
            rightFraction = requestedRightWidth / (bounds.width - dividerThickness)
            onRightPaneWidthChange(requestedRightWidth)
        }
        updateTrackingAreas()
        window?.invalidateCursorRects(for: self)
    }

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat,
                   ofSubviewAt dividerIndex: Int) -> CGFloat {
        min(minimumPrimaryWidth, max(0, bounds.width - dividerThickness - minimumNotesWidth))
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat,
                   ofSubviewAt dividerIndex: Int) -> CGFloat {
        min(maximumPrimaryWidth ?? .greatestFiniteMagnitude,
            max(0, bounds.width - dividerThickness - minimumNotesWidth))
    }

    func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect,
                   forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        // AppKit uses the effective rect for native divider cursor feedback too.
        // Keep it bounded to the divider instead of extending the grab zone.
        NSRect(x: drawnRect.midX - 3, y: drawnRect.minY, width: 6, height: drawnRect.height)
    }
}

enum WorkspaceSplitSizing {
    static func clampedRightPaneWidth(requested: CGFloat,
                                     totalWidth: CGFloat,
                                     dividerWidth: CGFloat,
                                     minimumPrimaryWidth: CGFloat,
                                     minimumNotesWidth: CGFloat) -> CGFloat {
        let available = max(0, totalWidth - dividerWidth)
        let lowerBound = min(minimumNotesWidth, available)
        let upperBound = max(lowerBound, available - minimumPrimaryWidth)
        return min(max(requested, lowerBound), upperBound)
    }
}
