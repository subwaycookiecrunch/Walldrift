import AppKit

let url = URL(fileURLWithPath: "./WallDrift/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png")
guard let image = NSImage(contentsOf: url),
      let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData) else {
    print("Failed to load image")
    exit(1)
}

print("Size: \(bitmap.pixelsWide)x\(bitmap.pixelsHigh)")
let colorAtOrigin = bitmap.colorAt(x: 0, y: 0)
let colorAtCenter = bitmap.colorAt(x: bitmap.pixelsWide/2, y: bitmap.pixelsHigh/2)
print("Top-Left: \(colorAtOrigin?.description ?? "nil")")
print("Center: \(colorAtCenter?.description ?? "nil")")

// Find bounding box of non-background pixels
let bg = bitmap.colorAt(x: 0, y: 0)!
var minX = bitmap.pixelsWide, minY = bitmap.pixelsHigh, maxX = 0, maxY = 0

for y in 0..<bitmap.pixelsHigh {
    for x in 0..<bitmap.pixelsWide {
        let color = bitmap.colorAt(x: x, y: y)!
        // check if color is significantly different from bg
        let diff = abs(color.redComponent - bg.redComponent) + abs(color.greenComponent - bg.greenComponent) + abs(color.blueComponent - bg.blueComponent) + abs(color.alphaComponent - bg.alphaComponent)
        if diff > 0.1 {
            if x < minX { minX = x }
            if x > maxX { maxX = x }
            if y < minY { minY = y }
            if y > maxY { maxY = y }
        }
    }
}

print("Bounding box: \(minX), \(minY) to \(maxX), \(maxY)")

// Crop the image to this bounding box
let width = maxX - minX
let height = maxY - minY
let cropRect = NSRect(x: minX, y: minY, width: width, height: height)

if let cgImage = bitmap.cgImage?.cropping(to: cropRect) {
    let croppedBitmap = NSBitmapImageRep(cgImage: cgImage)
    if let pngData = croppedBitmap.representation(using: .png, properties: [:]) {
        let outURL = URL(fileURLWithPath: "./WallDrift/Assets.xcassets/AppIcon.appiconset/icon_cropped.png")
        try? pngData.write(to: outURL)
        print("Cropped image saved to \(outURL.path)")
    }
}
