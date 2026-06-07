import Foundation
import AppKit
import CoreGraphics

func cropAndResizeWithTransparency() {
    let sourcePath = "/Users/raj/.gemini/antigravity/brain/f67685ed-c2d9-4cec-86db-b405a0d37ec9/walldrift_logo_proposal_1780843816156.png"
    let targetDir = "/Users/raj/.gemini/antigravity/scratch/WallDrift/WallDrift/Assets.xcassets/AppIcon.appiconset/"
    
    guard let image = NSImage(contentsOfFile: sourcePath),
          let tiff = image.tiffRepresentation,
          let imageSource = CGImageSourceCreateWithData(tiff as CFData, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
        print("Failed to load source image")
        return
    }
    
    // Bounding box for the centered squircle
    let cropRect = CGRect(x: 154, y: 154, width: 716, height: 716)
    guard let croppedCgImage = cgImage.cropping(to: cropRect) else {
        print("Failed to crop image")
        return
    }
    
    let targets: [(String, Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]
    
    for (filename, size) in targets {
        let destURL = URL(fileURLWithPath: targetDir).appendingPathComponent(filename)
        
        guard let colorSpace = cgImage.colorSpace,
              let context = CGContext(
                data: nil,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: size * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            print("Failed to create context for size \(size)")
            continue
        }
        
        // Clear context to ensure transparency outside the clip path
        context.clear(CGRect(x: 0, y: 0, width: size, height: size))
        
        // Create a rounded rect path representing the macOS squircle shape
        // macOS app icon standard corner radius is 22.3% of the icon width/height
        let cornerRadius = CGFloat(size) * 0.223
        let clipPath = CGPath(
            roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        
        // Add path and clip context
        context.addPath(clipPath)
        context.clip()
        
        // Draw the cropped image scaled to fit the clipped context
        context.interpolationQuality = .high
        context.draw(croppedCgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
        
        guard let resizedCgImage = context.makeImage() else {
            print("Failed to make image for size \(size)")
            continue
        }
        
        let newRep = NSBitmapImageRep(cgImage: resizedCgImage)
        newRep.size = NSSize(width: size, height: size)
        
        guard let pngData = newRep.representation(using: .png, properties: [:]) else {
            print("Failed to generate PNG representation for \(filename)")
            continue
        }
        
        do {
            try pngData.write(to: destURL)
            print("Successfully wrote \(filename) (\(size)x\(size)) with transparent corners")
        } catch {
            print("Failed to write \(filename): \(error.localizedDescription)")
        }
    }
}

cropAndResizeWithTransparency()
