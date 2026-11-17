// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

// Draws the background of Volta's disk-image window (the "drag to Applications" view).
// Usage: swift Scripts/make-dmg-background.swift <output.png> <scale> <version>
import AppKit

let arguments = CommandLine.arguments
guard arguments.count >= 4, let scale = Double(arguments[2]) else {
    FileHandle.standardError.write(Data("usage: make-dmg-background.swift <output.png> <scale> <version>\n".utf8))
    exit(2)
}
let output = URL(fileURLWithPath: arguments[1])
let version = arguments[3]

// Window content: 660 × 400 pt. Icons sit at (180, 200) and (480, 200), measured from the top left.
let width = 660.0, height = 400.0
let appCenter = CGPoint(x: 180, y: 200), folderCenter = CGPoint(x: 480, y: 200)

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { exit(1) }
rep.size = NSSize(width: width, height: height)
NSGraphicsContext.saveGraphicsState()
let context = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = context
let cg = context.cgContext
// Draw in top-left coordinates, like Finder positions icons.
cg.translateBy(x: 0, y: height)
cg.scaleBy(x: 1, y: -1)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// 1. Base: a calm blue-violet gradient. Around the icon labels it stays mid-toned, so Finder's
//    black (light mode) and white (dark mode) labels both remain readable.
let base = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                      colors: [color(0x2E3A63), color(0x4C5B8C), color(0x6878A8)] as CFArray,
                      locations: [0, 0.55, 1])!
cg.setFillColor(color(0x4C5B8C))
cg.fill(CGRect(x: 0, y: 0, width: width, height: height))
cg.drawLinearGradient(base, start: CGPoint(x: 0, y: 0), end: CGPoint(x: width * 0.35, y: height),
                      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// 2. Two soft glows for depth.
func glow(_ center: CGPoint, radius: CGFloat, _ hex: UInt32, _ alpha: CGFloat) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                       colors: [color(hex, alpha), color(hex, 0)] as CFArray, locations: [0, 1])!
    cg.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}
glow(CGPoint(x: 90, y: 40), radius: 260, 0x5FC3D6, 0.22)
glow(CGPoint(x: 600, y: 360), radius: 280, 0xC28BD9, 0.20)

// 3. Soft light pools behind the two icons.
glow(appCenter, radius: 92, 0xFFFFFF, 0.13)
glow(folderCenter, radius: 92, 0xFFFFFF, 0.13)

// 4. Text.
func draw(_ text: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, centerY: CGFloat, rounded: Bool = false) {
    var font = NSFont.systemFont(ofSize: size, weight: weight)
    if rounded, let descriptor = font.fontDescriptor.withDesign(.rounded) {
        font = NSFont(descriptor: descriptor, size: size) ?? font
    }
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: NSColor(white: 1, alpha: alpha), .paragraphStyle: paragraph,
    ]
    let string = NSAttributedString(string: text, attributes: attributes)
    let bounds = string.boundingRect(with: NSSize(width: width, height: 200), options: [.usesLineFragmentOrigin])
    // NSString drawing expects a flipped context to be marked as such.
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    string.draw(with: NSRect(x: 0, y: centerY - bounds.height / 2, width: width, height: bounds.height),
                options: [.usesLineFragmentOrigin])
    NSGraphicsContext.current = context
}

draw("Volta", size: 30, weight: .bold, alpha: 1, centerY: 46, rounded: true)
draw("Drag Volta into Applications to install", size: 13.5, weight: .medium, alpha: 0.9, centerY: 82)
draw("Zum Installieren Volta auf „Programme“ ziehen", size: 12, weight: .regular, alpha: 0.68, centerY: 102)
draw("Version \(version)  ·  © 2026 Johannes Uth", size: 10.5, weight: .medium, alpha: 0.55, centerY: 372)

// 5. Arrow between the icons: dotted shaft and a rounded head.
let shaftStart = appCenter.x + 82, shaftEnd = folderCenter.x - 92
cg.setStrokeColor(color(0xFFFFFF, 0.78))
cg.setLineCap(.round)
cg.setLineWidth(3.5)
cg.setLineDash(phase: 0, lengths: [0.1, 11])
cg.move(to: CGPoint(x: shaftStart, y: appCenter.y))
cg.addLine(to: CGPoint(x: shaftEnd - 6, y: appCenter.y))
cg.strokePath()
cg.setLineDash(phase: 0, lengths: [])
cg.setLineWidth(4)
cg.setLineJoin(.round)
cg.move(to: CGPoint(x: shaftEnd - 14, y: appCenter.y - 13))
cg.addLine(to: CGPoint(x: shaftEnd, y: appCenter.y))
cg.addLine(to: CGPoint(x: shaftEnd - 14, y: appCenter.y + 13))
cg.strokePath()

NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: output)
