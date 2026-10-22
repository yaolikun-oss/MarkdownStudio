import Foundation
import Testing
import AppKit
import SwiftUI
@testable import MarkdownReader

struct NotebookSplitViewTests {
    @Test @MainActor func optionalMenuSelectorsDoNotRecurseThroughTheSplitDelegate() {
        let split = NotebookNativeSplitView(primary: AnyView(Color.gray), notes: AnyView(Color.white),
            rightPaneWidth: 600, minimumPrimaryWidth: 260, minimumNotesWidth: 320,
            onRightPaneWidthChange: { _ in })
        #expect(split.delegate !== split)
        for _ in 0..<100 {
            #expect(!split.responds(to: Selector(("markdownStudioUnknownAction:"))))
            #expect(!split.responds(to: Selector(("undo:"))))
            #expect(!split.responds(to: Selector(("openDocument:"))))
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["MARKDOWN_STUDIO_NATIVE_DRAG_TEST"] == "1",
                   "Native mouse tracking must run in its own test process"))
    @MainActor func nativeDragStartsBesideTheThinLineAndSavesOnlyAfterRelease() throws {
        var savedWidths: [CGFloat] = []
        let split = NotebookNativeSplitView(primary: AnyView(Color.gray), notes: AnyView(Color.white),
            rightPaneWidth: 600, minimumPrimaryWidth: 260, minimumNotesWidth: 320,
            onRightPaneWidthChange: { savedWidths.append($0) })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1400, height: 700),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = split
        split.frame = NSRect(x: 0, y: 0, width: 1400, height: 700)
        split.layoutSubtreeIfNeeded()
        defer { window.close() }
        let before = split.subviews[0].frame.maxX
        let start = NSPoint(x: split.dividerHitRect.midX + 3, y: 300)
        let end = NSPoint(x: start.x + 90, y: start.y)
        func event(_ type: NSEvent.EventType, point: NSPoint, number: Int) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: type, location: split.convert(point, to: nil), modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                context: nil, eventNumber: number, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1))
        }
        let down = try event(.leftMouseDown, point: start, number: 1)
        NSApp.postEvent(try event(.leftMouseDragged, point: end, number: 2), atStart: false)
        NSApp.postEvent(try event(.leftMouseUp, point: end, number: 3), atStart: false)
        split.mouseDown(with: down)
        #expect(abs(split.subviews[0].frame.maxX - before - 90) < 2)
        #expect(savedWidths.count == 1)
        #expect(abs((savedWidths.last ?? 0) - split.subviews[1].frame.width) < 1)
    }
    @Test @MainActor
    func nativeDividerKeepsItsPositionAcrossContentSwitchesAndResize() {
        var savedWidths: [CGFloat] = []
        let split = NotebookNativeSplitView(primary: AnyView(Text("PDF")), notes: AnyView(Text("可视化笔记")),
            rightPaneWidth: 720, minimumPrimaryWidth: 260, minimumNotesWidth: 320,
            onRightPaneWidthChange: { savedWidths.append($0) })
        split.frame = NSRect(x: 0, y: 0, width: 1800, height: 900)
        split.layoutSubtreeIfNeeded()
        #expect(abs(split.subviews[1].frame.width - 720) < 1)
        split.setPosition(630, ofDividerAt: 0)
        split.recordUserDividerPosition()
        let divider = split.subviews[0].frame.maxX
        let width = split.subviews[1].frame.width
        #expect(savedWidths.count == 1)
        for index in 0..<12 {
            let content = index.isMultiple(of: 2)
                ? AnyView(Text(String(repeating: "Markdown 源码 **加粗** <u>下划线</u> ", count: 200)).fixedSize())
                : AnyView(Color.white.frame(maxWidth: .infinity, maxHeight: .infinity))
            split.update(primary: AnyView(Text("PDF")), notes: content, requestedRightWidth: width,
                         onRightPaneWidthChange: { savedWidths.append($0) })
            split.layoutSubtreeIfNeeded()
            #expect(abs(split.subviews[0].frame.maxX - divider) < 1)
            #expect(abs(split.subviews[1].frame.width - width) < 1)
        }
        #expect(savedWidths.count == 1)
        let fraction = width / (split.bounds.width - split.dividerThickness)
        split.frame.size.width = 2100
        split.layoutSubtreeIfNeeded()
        #expect(abs(split.subviews[1].frame.width / (2100 - split.dividerThickness) - fraction) < 0.001)
        #expect(savedWidths.count == 1)
    }

    @Test @MainActor func dividerHasAGrabAreaOnBothSidesAndSidebarKeepsItsWidth() {
        let split = NotebookNativeSplitView(primary: AnyView(Text("目录")), notes: AnyView(Color.white),
            rightPaneWidth: 720, minimumPrimaryWidth: 190, minimumNotesWidth: 320,
            onRightPaneWidthChange: { _ in }, primaryPaneWidth: 280, maximumPrimaryWidth: 480)
        let parent = NSView(frame: NSRect(x: 0, y: 0, width: 1800, height: 900))
        split.frame = NSRect(x: 120, y: 40, width: 1600, height: 800)
        parent.addSubview(split)
        split.layoutSubtreeIfNeeded()
        let dividerX = split.subviews[0].frame.maxX + split.dividerThickness / 2
        #expect(split.dividerHitRect.width == 8)
        #expect(split.dividerCursorRect.width == 6)
        for distance in [-3.5, 0, 3.5] {
            #expect(split.hitTest(NSPoint(x: dividerX + distance, y: 300)) === split)
        }
        for distance in [-6.0, 6.0, 20.0, 120.0, 500.0] {
            #expect(!split.dividerHitRect.contains(NSPoint(x: dividerX + distance, y: 300)))
            #expect(!split.dividerCursorRect.contains(NSPoint(x: dividerX + distance, y: 300)))
        }
        split.frame.size.width = 1200
        split.layoutSubtreeIfNeeded()
        #expect(abs(split.subviews[0].frame.width - 280) < 1)
        split.updateSidebar(primary: AnyView(Text("目录")), notes: AnyView(Color.white), width: 280,
                            visible: false, onWidthChange: { _ in })
        #expect(split.subviews[1].frame == split.bounds)
        #expect(split.dividerThickness == 0)
        split.updateSidebar(primary: AnyView(Text("目录")), notes: AnyView(Color.white), width: 280,
                            visible: true, onWidthChange: { _ in })
        #expect(abs(split.subviews[0].frame.width - 280) < 1)
    }
    @Test
    func keepsRequestedNotesWidthIndependentOfPaneContentAndAvailableWidth() {
        let widths: [CGFloat] = [2048, 1700, 1280]
        for totalWidth in widths {
            let rightWidth = WorkspaceSplitSizing.clampedRightPaneWidth(
                requested: 720,
                totalWidth: totalWidth,
                dividerWidth: 1,
                minimumPrimaryWidth: 260,
                minimumNotesWidth: 320
            )
            #expect(rightWidth == 720)
        }
    }

    @Test
    func clampsRightPaneOnlyWhenMinimumPaneWidthsRequireIt() {
        let narrow = WorkspaceSplitSizing.clampedRightPaneWidth(
            requested: 900,
            totalWidth: 800,
            dividerWidth: 1,
            minimumPrimaryWidth: 260,
            minimumNotesWidth: 320
        )
        let wide = WorkspaceSplitSizing.clampedRightPaneWidth(
            requested: 900,
            totalWidth: 1800,
            dividerWidth: 1,
            minimumPrimaryWidth: 260,
            minimumNotesWidth: 320
        )
        #expect(narrow == 539)
        #expect(wide == 900)
    }
}
