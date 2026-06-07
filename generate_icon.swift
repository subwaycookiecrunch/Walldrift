import AppKit

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

// Draw black background
NSColor.black.set()
NSRect(origin: .zero, size: size).fill()

// Draw an icon (e.g. a minimalist white mountain/photo)
NSColor.white.set()

let path = NSBezierPath()
path.lineWidth = 40
path.lineJoinStyle = .round
path.lineCapStyle = .round

// Mountain 1
path.move(to: NSPoint(x: 200, y: 200))
path.line(to: NSPoint(x: 512, y: 700))
path.line(to: NSPoint(x: 824, y: 200))
path.stroke()

// Mountain 2
let path2 = NSBezierPath()
path2.lineWidth = 40
path2.lineJoinStyle = .round
path2.lineCapStyle = .round
path2.move(to: NSPoint(x: 500, y: 200))
path2.line(to: NSPoint(x: 700, y: 500))
path2.line(to: NSPoint(x: 900, y: 200))
path2.stroke()

// Sun / Moon
let circle = NSBezierPath(ovalIn: NSRect(x: 700, y: 600, width: 150, height: 150))
circle.fill()

image.unlockFocus()

if let tiffData = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData) {
    if let pngData = bitmap.representation(using: .png, properties: [:]) {
        let outURL = URL(fileURLWithPath: "./WallDrift/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png")
        try? pngData.write(to: outURL)
        print("Generated new AppIcon at \(outURL.path)")
    }
}
