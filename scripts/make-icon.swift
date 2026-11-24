// Draws the CurrentTask app icon and writes:
//   Resources/AppIcon.icns  (used by build.sh)
//   Resources/AppIcon.png   (1024px preview, used by the README)
//
// Run from the repo root:  swift scripts/make-icon.swift

import AppKit

// MARK: - Drawing (in a 1024 x 1024 canvas, origin bottom-left)

func star(center c: CGPoint, outer: CGFloat, inner: CGFloat) -> CGPath {
    let path = CGMutablePath()
    for i in 0..<10 {
        let r = i.isMultiple(of: 2) ? outer : inner
        let a = CGFloat.pi / 2 + CGFloat(i) * .pi / 5
        let p = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
        i == 0 ? path.move(to: p) : path.addLine(to: p)
    }
    path.closeSubpath()
    return path
}

func pill(_ ctx: CGContext, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
    let rect = CGRect(x: x, y: y - height / 2, width: width, height: height)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: height / 2, cornerHeight: height / 2, transform: nil))
    ctx.fillPath()
}

func drawIcon(_ ctx: CGContext) {
    let white = { (a: CGFloat) in CGColor(red: 1, green: 1, blue: 1, alpha: a) }

    // Rounded-square body on Apple's icon grid (824pt body inside 1024pt canvas).
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Drop shadow.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.3))
    ctx.addPath(bodyPath)
    ctx.setFillColor(CGColor(red: 0.30, green: 0.27, blue: 0.85, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()

    // Indigo → violet gradient.
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [
            CGColor(red: 0.42, green: 0.48, blue: 1.00, alpha: 1),
            CGColor(red: 0.33, green: 0.24, blue: 0.82, alpha: 1),
        ] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 100, y: 924), end: CGPoint(x: 924, y: 100),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // "Menu bar" strip across the top, showing the current task.
    ctx.setFillColor(white(0.22))
    ctx.fill(CGRect(x: 100, y: 770, width: 824, height: 154))
    ctx.setFillColor(white(1))
    ctx.addPath(star(center: CGPoint(x: 250, y: 847), outer: 44, inner: 19))
    ctx.fillPath()
    pill(ctx, x: 322, y: 847, width: 440, height: 44)

    ctx.restoreGState()

    // Task list: the first row is the current task, the rest are dimmer.
    let rows: [(y: CGFloat, width: CGFloat, alpha: CGFloat)] = [
        (595, 470, 1.0),
        (435, 380, 0.6),
        (275, 430, 0.6),
    ]
    for (index, row) in rows.enumerated() {
        let circle = CGRect(x: 212, y: row.y - 38, width: 76, height: 76)
        if index == 0 {
            ctx.setFillColor(white(1))
            ctx.fillEllipse(in: circle)
        } else {
            ctx.setStrokeColor(white(row.alpha))
            ctx.setLineWidth(14)
            ctx.strokeEllipse(in: circle.insetBy(dx: 7, dy: 7))
        }
        ctx.setFillColor(white(row.alpha))
        pill(ctx, x: 330, y: row.y, width: row.width, height: 48)
    }
}

// MARK: - Rendering

func renderPNG(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    ctx.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
    ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(ctx)
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let resources = URL(fileURLWithPath: "Resources", isDirectory: true)
let iconset = fm.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try fm.createDirectory(at: resources, withIntermediateDirectories: true)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: iconset) }

for points in [16, 32, 128, 256, 512] {
    try renderPNG(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try renderPNG(pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try renderPNG(pixels: 1024).write(to: resources.appendingPathComponent("AppIcon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }

print("Wrote Resources/AppIcon.icns and Resources/AppIcon.png")
