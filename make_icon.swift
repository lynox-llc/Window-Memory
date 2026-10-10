import Cocoa

// Renders the Window Memory app icon at a given pixel size.
func renderIcon(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    let s = size

    // --- Rounded-square background (macOS-style continuous corner) ---
    let margin = s * 0.06
    let rect = NSRect(x: margin, y: margin, width: s - margin * 2, height: s - margin * 2)
    let radius = rect.width * 0.2237
    let bg = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    bg.addClip()

    // Indigo → violet gradient.
    let grad = NSGradient(colors: [
        NSColor(calibratedRed: 0.40, green: 0.47, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.35, green: 0.24, blue: 0.78, alpha: 1),
    ])!
    grad.draw(in: rect, angle: -90)

    // Soft top highlight.
    let hi = NSGradient(colors: [
        NSColor(white: 1, alpha: 0.18),
        NSColor(white: 1, alpha: 0.0),
    ])!
    hi.draw(in: NSRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2), angle: -90)

    // --- Overlapping "window" cards to convey saved layout ---
    func card(_ r: NSRect, fill: NSColor, bar: NSColor, shadow: Bool) {
        ctx.saveGState()
        if shadow {
            ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012),
                          blur: s * 0.03,
                          color: NSColor(white: 0, alpha: 0.28).cgColor)
        }
        let rad = r.width * 0.13
        let path = NSBezierPath(roundedRect: r, xRadius: rad, yRadius: rad)
        fill.setFill(); path.fill()
        ctx.restoreGState()

        // Title bar.
        let barH = r.height * 0.22
        let barRect = NSRect(x: r.minX, y: r.maxY - barH, width: r.width, height: barH)
        let barPath = NSBezierPath(roundedRect: barRect, xRadius: r.width * 0.13, yRadius: r.width * 0.13)
        // Clip bottom corners square by overlaying a rect.
        bar.setFill(); barPath.fill()
        NSBezierPath(rect: NSRect(x: r.minX, y: r.maxY - barH, width: r.width, height: barH * 0.5)).fill()

        // Traffic-light dots (only when large enough to read).
        if r.width > s * 0.18 {
            let d = barH * 0.32
            let cy = r.maxY - barH / 2 - d / 2
            let colors = [NSColor(red: 1, green: 0.37, blue: 0.34, alpha: 1),
                          NSColor(red: 1, green: 0.74, blue: 0.18, alpha: 1),
                          NSColor(red: 0.24, green: 0.80, blue: 0.32, alpha: 1)]
            for (i, c) in colors.enumerated() {
                let x = r.minX + barH * 0.5 + CGFloat(i) * d * 1.7
                c.setFill()
                NSBezierPath(ovalIn: NSRect(x: x, y: cy, width: d, height: d)).fill()
            }
        }
    }

    // Back card (offset, translucent).
    let cw = s * 0.42, ch = s * 0.34
    card(NSRect(x: s * 0.30, y: s * 0.40, width: cw, height: ch),
         fill: NSColor(white: 1, alpha: 0.45),
         bar: NSColor(white: 1, alpha: 0.55), shadow: false)

    // Front card (solid white).
    card(NSRect(x: s * 0.24, y: s * 0.26, width: cw, height: ch),
         fill: NSColor(white: 1, alpha: 0.98),
         bar: NSColor(calibratedRed: 0.90, green: 0.92, blue: 0.98, alpha: 1), shadow: true)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// --- Emit the iconset ---
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let specs: [(px: Int, name: String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]

for spec in specs {
    let rep = renderIcon(size: CGFloat(spec.px))
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(spec.name)"))
}
print("wrote \(specs.count) images to \(outDir)")
