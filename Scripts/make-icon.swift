import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()

let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 196, yRadius: 196)
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 1.00, green: 0.43, blue: 0.38, alpha: 1),
    NSColor(srgbRed: 0.53, green: 0.32, blue: 0.91, alpha: 1),
    NSColor(srgbRed: 0.10, green: 0.76, blue: 0.72, alpha: 1),
])!
gradient.draw(in: tile, angle: -38)

NSColor.white.withAlphaComponent(0.10).setFill()
NSBezierPath(ovalIn: NSRect(x: 118, y: 518, width: 650, height: 340)).fill()

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.shadowBlurRadius = 20
shadow.set()

let mark = NSBezierPath()
mark.appendArc(withCenter: NSPoint(x: 486, y: 502), radius: 222, startAngle: 40, endAngle: 320, clockwise: false)
mark.lineWidth = 126
mark.lineCapStyle = .round
NSColor.white.withAlphaComponent(0.97).setStroke()
mark.stroke()
NSGraphicsContext.restoreGraphicsState()

let star = NSBezierPath()
let starCenter = NSPoint(x: 728, y: 302)
for index in 0..<8 {
    let angle = CGFloat(index) * .pi / 4
    let radius: CGFloat = index.isMultiple(of: 2) ? 72 : 25
    let point = NSPoint(x: starCenter.x + cos(angle) * radius, y: starCenter.y + sin(angle) * radius)
    if index == 0 { star.move(to: point) } else { star.line(to: point) }
}
star.close()
NSColor(srgbRed: 1.00, green: 0.90, blue: 0.35, alpha: 1).setFill()
star.fill()

image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("Resources/AppIcon.png"))
print("Rendered charl icon")
