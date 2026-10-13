import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconSet = root.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconSet, withIntermediateDirectories: true)

let sizes: [(String, Int, Int)] = [
    ("icon_16x16.png", 16, 1), ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1), ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1), ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1), ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1), ("icon_512x512@2x.png", 512, 2)
]

for (name, pointSize, scale) in sizes {
    let side = pointSize * scale
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB,
                                  bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.cgContext.scaleBy(x: CGFloat(side) / 1024, y: CGFloat(side) / 1024)

    let background = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 1024, height: 1024), xRadius: 220, yRadius: 220)
    NSColor(calibratedRed: 0.96, green: 0.95, blue: 0.92, alpha: 1).setFill()
    background.fill()

    let paper = NSBezierPath(roundedRect: NSRect(x: 210, y: 125, width: 604, height: 774), xRadius: 52, yRadius: 52)
    NSColor(calibratedRed: 1, green: 0.995, blue: 0.98, alpha: 1).setFill()
    paper.fill()
    NSColor(calibratedRed: 0.86, green: 0.84, blue: 0.79, alpha: 1).setStroke()
    paper.lineWidth = 12
    paper.stroke()

    let hash = NSAttributedString(string: "#", attributes: [
        .font: NSFont.systemFont(ofSize: 300, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.65, green: 0.34, blue: 0.23, alpha: 1)
    ])
    hash.draw(at: NSPoint(x: 348, y: 520))

    for (y, width) in [(420, 380), (345, 430), (270, 285)] {
        let line = NSBezierPath(roundedRect: NSRect(x: 316, y: y, width: width, height: 20), xRadius: 10, yRadius: 10)
        NSColor(calibratedRed: 0.79, green: 0.78, blue: 0.75, alpha: 1).setFill()
        line.fill()
    }

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    let output = iconSet.appendingPathComponent(name)
    try bitmap.representation(using: .png, properties: [:])!.write(to: output)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["--convert", "icns", "--output", root.appendingPathComponent("AppIcon.icns").path, iconSet.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { fatalError("iconutil failed") }
