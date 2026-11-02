import AppKit
import EPUBCore
import PDFKit
import SwiftUI

struct WorkspaceEPUBNavigationTarget: Equatable {
    let chapterIndex: Int
    let fragment: String?
    let revision: Int
}

/// A reading tab loads and owns its own document state. Changing the active
/// reading tab therefore cannot replace the content or position of another tab.
struct WorkspaceReadingPane: View {
    let url: URL
    let isActive: Bool
    let width: Double
    let bodySize: Double
    let bodyFamily: String
    let bodyColorHex: String
    let annotationFontSize: Double
    let annotationFontFamily: String
    let annotationTextColorHex: String
    let backgroundHex: String
    let lineHeight: Double
    let onActivate: () -> Void
    let onError: (String) -> Void
    let epubNavigationTarget: WorkspaceEPUBNavigationTarget?
    let onEPUBLoaded: (EPUBPackageDocument) -> Void
    let onEPUBChapterChanged: (Int) -> Void
    @Binding var chapter: Int
    @Binding var pdfZoomPercent: Double
    @Binding var officeZoomPercent: Double
    @Binding var currentPDFPage: Int
    let pdfDisplayPresetRequest: PDFDisplayPresetRequest

    @State private var pdfDocument: PDFDocument?
    @State private var epubDocument: EPUBPackageDocument?
    @State private var officeState = OfficePreviewState()
    @State private var scrollFragment: String?
    @State private var pdfPosition: PDFReadingPosition?
    @State private var navigationRequest = 0
    @State private var epubFocusRequest = 0
    @State private var loading = true
    @State private var didLoad = false

    var body: some View {
        Group {
            if let pdfDocument {
                PDFReaderView(document: pdfDocument, zoomPercent: $pdfZoomPercent, currentPageIndex: $currentPDFPage,
                    readingPosition: $pdfPosition, documentID: url.standardizedFileURL.path,
                    navigationRequest: navigationRequest, displayPresetRequest: pdfDisplayPresetRequest,
                    isReadingProfileLoading: false, backgroundColor: Color(hex: backgroundHex),
                    onActivate: onActivate)
            } else if let epubDocument, epubDocument.chapters.indices.contains(chapter) {
                EPUBChapterView(chapter: epubDocument.chapters[chapter], resourceRoot: epubDocument.workingDirectory,
                    editable: false, width: width, bodySize: bodySize, bodyFamily: bodyFamily,
                    bodyColorHex: bodyColorHex, annotationFontSize: annotationFontSize,
                    annotationFontFamily: annotationFontFamily, annotationTextColorHex: annotationTextColorHex,
                    backgroundColorHex: backgroundHex, lineHeight: lineHeight,
                    scrollFragment: scrollFragment, scrollRequest: navigationRequest, annotations: [],
                    annotationJumpID: nil, annotationJumpRequest: 0, savedPosition: nil,
                    positionRestoreRequest: 0, isActive: isActive,
                    focusRequest: epubFocusRequest, onActivate: onActivate,
                    onNavigateChapter: navigateChapter, onTextSelection: { _ in },
                    onEditAnnotation: { _ in }, onDeleteAnnotation: { _ in },
                    onReadPosition: { _, _ in }, onBodyChange: { _ in })
            } else if OfficeReadingFormat.supports(url) {
                OfficeDocumentReader(url: url, state: officeState, zoomPercent: $officeZoomPercent, onActivate: onActivate)
            } else if loading {
                ProgressView("正在打开 \(url.lastPathComponent)…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("无法显示文档", systemImage: "doc.questionmark", description: Text(url.lastPathComponent))
            }
        }
        .background(Color(hex: backgroundHex))
        .task(id: url.standardizedFileURL) { if isActive { await load() } }
        .task(id: epubNavigationTarget?.revision) {
            applyEPUBNavigationTarget()
            requestEPUBFocus()
        }
        .onChange(of: isActive) { _, active in
            guard active else { return }
            if !didLoad { Task { await load() } }
            requestEPUBFocus()
        }
        .background {
            EPUBArrowKeyMonitor(isEnabled: isActive && epubDocument != nil, onNavigateChapter: navigateChapter)
                .frame(width: 0, height: 0)
        }
    }

    @MainActor private func load() async {
        guard !didLoad else { return }
        didLoad = true
        loading = true
        defer { loading = false }
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            pdfDocument = PDFDocument(url: url)
            if pdfDocument == nil { onError("无法读取 PDF 文件：\(url.lastPathComponent)") }
            return
        }
        if ext == "epub" || FileManager.default.fileExists(atPath: url.appendingPathComponent("META-INF/container.xml").path) {
            do {
                let source = url
                let document = try await Task.detached(priority: .userInitiated) {
                    try EPUBPackageDocument.open(source)
                }.value
                guard !Task.isCancelled else { return }
                epubDocument = document
                onEPUBLoaded(document)
                onEPUBChapterChanged(chapter)
                applyEPUBNavigationTarget()
                requestEPUBFocus()
            }
            catch { onError("无法读取 EPUB：\(error.localizedDescription)") }
            return
        }
        if !OfficeReadingFormat.supports(url) { onError("不支持的阅读格式：\(url.lastPathComponent)") }
    }

    private func navigateChapter(_ offset: Int) {
        guard let epubDocument else { return }
        let next = chapter + offset
        guard epubDocument.chapters.indices.contains(next) else { return }
        chapter = next
        scrollFragment = nil
        navigationRequest += 1
        onEPUBChapterChanged(chapter)
        requestEPUBFocus()
    }

    private func applyEPUBNavigationTarget() {
        guard let target = epubNavigationTarget, let epubDocument,
              epubDocument.chapters.indices.contains(target.chapterIndex) else { return }
        chapter = target.chapterIndex
        scrollFragment = target.fragment
        navigationRequest += 1
        onEPUBChapterChanged(chapter)
        requestEPUBFocus()
    }

    private func requestEPUBFocus() {
        guard isActive, epubDocument != nil else { return }
        DispatchQueue.main.async { epubFocusRequest += 1 }
    }
}
