// Renders the 1024x1024 app icon: dark rounded field, accent arc, and a running figure glyph.
import AppKit

let size = 1024.0
// Draw into an opaque 1024x1024 RGB context: App Store icons must be exactly 1024px with no alpha.
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

// Background
let bg = CGColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1)
ctx.setFillColor(bg)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Accent progress arc (interval bar feel)
let accent = CGColor(red: 0.98, green: 0.55, blue: 0.20, alpha: 1)
let run = CGColor(red: 0.08, green: 0.60, blue: 0.32, alpha: 1)
let walk = CGColor(red: 0.13, green: 0.42, blue: 0.88, alpha: 1)
let center = CGPoint(x: size / 2, y: size / 2)
let radius = size * 0.36
ctx.setLineWidth(size * 0.075)
ctx.setLineCap(.round)
let segments: [(CGColor, Double, Double)] = [
    (walk, 0.62, 0.78), (run, 0.80, 0.90), (walk, 0.92, 1.02), (run, 1.04, 1.14), (walk, 1.16, 1.26), (accent, 1.28, 1.60)
]
for (color, a, b) in segments {
    ctx.setStrokeColor(color)
    ctx.addArc(center: center, radius: radius, startAngle: CGFloat(a * .pi), endAngle: CGFloat(b * .pi), clockwise: false)
    ctx.strokePath()
}

// Runner glyph
let config = NSImage.SymbolConfiguration(pointSize: size * 0.34, weight: .bold)
if let symbol = NSImage(systemSymbolName: "figure.run", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
    let tinted = NSImage(size: symbol.size, flipped: false) { rect in
        symbol.draw(in: rect)
        NSColor.white.set()
        rect.fill(using: .sourceAtop)
        return true
    }
    let s = tinted.size
    tinted.draw(in: NSRect(x: center.x - s.width / 2, y: center.y - s.height / 2 + size * 0.01, width: s.width, height: s.height))
}
NSGraphicsContext.restoreGraphicsState()
let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("wrote icon")
