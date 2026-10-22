import CoreGraphics
import PDFKit

/// Finds a nearly full-page image drawn by a PDF page and calculates the PDF
/// scale at which one source image pixel occupies one display backing pixel.
/// Pages with text/vector content or ambiguous image placement return nil.
enum PDFRasterScaleDetector {
    static func nativePixelScale(for page: PDFPage, backingScale: CGFloat) -> CGFloat? {
        guard backingScale.isFinite, backingScale > 0,
              let pageRef = page.pageRef,
              let table = CGPDFOperatorTableCreate() else { return nil }
        let content = CGPDFContentStreamCreateWithPage(pageRef)
        defer {
            CGPDFOperatorTableRelease(table)
            CGPDFContentStreamRelease(content)
        }

        let pageBounds = pageRef.getBoxRect(.cropBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else { return nil }
        let state = ImageScanState(pageBounds: pageBounds)
        let info = Unmanaged.passUnretained(state).toOpaque()

        CGPDFOperatorTableSetCallback(table, "q") { _, info in
            guard let info else { return }
            let state = Unmanaged<ImageScanState>.fromOpaque(info).takeUnretainedValue()
            state.stack.append(state.transform)
        }
        CGPDFOperatorTableSetCallback(table, "Q") { _, info in
            guard let info else { return }
            let state = Unmanaged<ImageScanState>.fromOpaque(info).takeUnretainedValue()
            state.transform = state.stack.popLast() ?? .identity
        }
        CGPDFOperatorTableSetCallback(table, "cm") { scanner, info in
            guard let info else { return }
            let state = Unmanaged<ImageScanState>.fromOpaque(info).takeUnretainedValue()
            var values = [CGPDFReal](repeating: 0, count: 6)
            for index in stride(from: 5, through: 0, by: -1) {
                guard CGPDFScannerPopNumber(scanner, &values[index]) else { return }
            }
            let matrix = CGAffineTransform(a: values[0], b: values[1], c: values[2],
                                           d: values[3], tx: values[4], ty: values[5])
            state.transform = matrix.concatenating(state.transform)
        }
        CGPDFOperatorTableSetCallback(table, "Do") { scanner, info in
            guard let info else { return }
            let state = Unmanaged<ImageScanState>.fromOpaque(info).takeUnretainedValue()
            var name: UnsafePointer<CChar>?
            guard CGPDFScannerPopName(scanner, &name), let name,
                  let object = CGPDFContentStreamGetResource(
                    CGPDFScannerGetContentStream(scanner), "XObject", name) else { return }
            var stream: CGPDFStreamRef?
            guard CGPDFObjectGetValue(object, .stream, &stream), let stream else { return }
            guard let dictionary = CGPDFStreamGetDictionary(stream) else { return }
            var subtype: UnsafePointer<CChar>?
            guard CGPDFDictionaryGetName(dictionary, "Subtype", &subtype),
                  let subtype, strcmp(subtype, "Image") == 0 else { return }
            var width: CGPDFInteger = 0
            var height: CGPDFInteger = 0
            guard CGPDFDictionaryGetInteger(dictionary, "Width", &width),
                  CGPDFDictionaryGetInteger(dictionary, "Height", &height),
                  width > 0, height > 0 else { return }

            let bounds = CGRect(x: 0, y: 0, width: 1, height: 1)
                .applying(state.transform).standardized
            let overlap = bounds.intersection(state.pageBounds)
            let pageArea = state.pageBounds.width * state.pageBounds.height
            let coverage = overlap.isNull ? 0 : overlap.width * overlap.height / pageArea
            guard coverage >= 0.75 else { return }

            let origin = CGPoint.zero.applying(state.transform)
            let xAxis = CGPoint(x: 1, y: 0).applying(state.transform)
            let yAxis = CGPoint(x: 0, y: 1).applying(state.transform)
            let drawnWidth = hypot(xAxis.x - origin.x, xAxis.y - origin.y)
            let drawnHeight = hypot(yAxis.x - origin.x, yAxis.y - origin.y)
            guard drawnWidth.isFinite, drawnWidth > 0,
                  drawnHeight.isFinite, drawnHeight > 0 else { return }
            let candidate = ImageScanState.Candidate(
                coverage: coverage,
                horizontalPixelsPerPoint: CGFloat(width) / drawnWidth,
                verticalPixelsPerPoint: CGFloat(height) / drawnHeight)
            if candidate.coverage > (state.best?.coverage ?? 0) { state.best = candidate }
        }

        let scanner = CGPDFScannerCreate(content, table, info)
        defer { CGPDFScannerRelease(scanner) }
        guard CGPDFScannerScan(scanner), let best = state.best else { return nil }
        let pixelsPerPoint = min(best.horizontalPixelsPerPoint, best.verticalPixelsPerPoint)
        let scale = pixelsPerPoint / backingScale
        return scale.isFinite && scale > 0 ? scale : nil
    }
}

private final class ImageScanState {
    struct Candidate {
        let coverage: CGFloat
        let horizontalPixelsPerPoint: CGFloat
        let verticalPixelsPerPoint: CGFloat
    }

    let pageBounds: CGRect
    var transform = CGAffineTransform.identity
    var stack: [CGAffineTransform] = []
    var best: Candidate?

    init(pageBounds: CGRect) { self.pageBounds = pageBounds }
}
