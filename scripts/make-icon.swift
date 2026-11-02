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

    // A single high-contrast Markdown mark remains identifiable in the Dock,
    // Spotlight and 16 px file lists. Avoid pale paper details that disappear
    // after macOS downsamples the icon.
    let backgroundRect = NSRect(x: 20, y: 20, width: 984, height: 984)
    let background = NSBezierPath(roundedRect: backgroundRect, xRadius: 220, yRadius: 220)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.055, green: 0.063, blue: 0.075, alpha: 1),
        NSColor(calibratedRed: 0.12, green: 0.135, blue: 0.16, alpha: 1)
    ])!
    gradient.draw(in: background, angle: -55)

    NSColor.white.withAlphaComponent(0.14).setStroke()
    background.lineWidth = 14
    background.stroke()

    // Geometric M: custom paths stay crisp and do not depend on a font being
    // available on the build machine.
    let mark = NSBezierPath()
    mark.move(to: NSPoint(x: 210, y: 300))
    mark.line(to: NSPoint(x: 210, y: 710))
    mark.line(to: NSPoint(x: 410, y: 485))
    mark.line(to: NSPoint(x: 610, y: 710))
    mark.line(to: NSPoint(x: 610, y: 300))
    mark.lineWidth = 96
    mark.lineCapStyle = .round
    mark.lineJoinStyle = .round
    NSColor.white.setStroke()
    mark.stroke()

    // The down arrow is the familiar Markdown cue. The cyan accent separates
    // it from the M even at the smallest generated size.
    let arrowColor = NSColor(calibratedRed: 0.20, green: 0.82, blue: 0.75, alpha: 1)
    let shaft = NSBezierPath(roundedRect: NSRect(x: 750, y: 405, width: 82, height: 315), xRadius: 41, yRadius: 41)
    arrowColor.setFill()
    shaft.fill()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 682, y: 445))
    head.line(to: NSPoint(x: 791, y: 292))
    head.line(to: NSPoint(x: 900, y: 445))
    head.close()
    head.fill()

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
