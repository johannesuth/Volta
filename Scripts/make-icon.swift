import AppKit

// Renders Volta's app icon (1024 pt): graphite squircle, one thin arc, a plain bolt.
let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
let space = CGColorSpaceCreateDeviceRGB()

func gray(_ v: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(gray: v, alpha: a) }

let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = CGPath(roundedRect: plate, cornerWidth: 186, cornerHeight: 186, transform: nil)

// Soft drop shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 36, color: gray(0, 0.4))
ctx.addPath(squircle); ctx.setFillColor(gray(0.1)); ctx.fillPath()
ctx.restoreGState()

// Graphite body with a barely visible vertical falloff
ctx.saveGState()
ctx.addPath(squircle); ctx.clip()
let body = CGGradient(colorsSpace: space, colors: [gray(0.19), gray(0.09)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(body, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
ctx.restoreGState()

// Track + arc
let center = CGPoint(x: 512, y: 512)
let radius: CGFloat = 268
ctx.setLineWidth(26)
ctx.setStrokeColor(gray(1, 0.08))
ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.strokePath()
ctx.setLineCap(.round)
ctx.setStrokeColor(gray(1, 0.92))
let top = CGFloat.pi / 2
ctx.addArc(center: center, radius: radius, startAngle: top, endAngle: top - .pi * 2 * 0.72, clockwise: true)
ctx.strokePath()

// Bolt
let bolt = CGMutablePath()
bolt.addLines(between: [
    CGPoint(x: 548, y: 712), CGPoint(x: 404, y: 498), CGPoint(x: 500, y: 498),
    CGPoint(x: 470, y: 312), CGPoint(x: 622, y: 540), CGPoint(x: 524, y: 540),
])
bolt.closeSubpath()
ctx.addPath(bolt); ctx.setFillColor(gray(1)); ctx.fillPath()

// Hairline edge
ctx.addPath(squircle)
ctx.setStrokeColor(gray(1, 0.1))
ctx.setLineWidth(2)
ctx.strokePath()

image.unlockFocus()
let png = NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("wrote", CommandLine.arguments[1])
