import Foundation
import AppKit
import CoreGraphics

func findExactSquircleInward() {
    let filePath = "/Users/raj/.gemini/antigravity/brain/f67685ed-c2d9-4cec-86db-b405a0d37ec9/walldrift_logo_proposal_1780843816156.png"
    guard let image = NSImage(contentsOfFile: filePath),
          let tiff = image.tiffRepresentation,
          let imageSource = CGImageSourceCreateWithData(tiff as CFData, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
        print("Failed to load image")
        return
    }
    
    let width = cgImage.width
    let height = cgImage.height
    
    guard let colorSpace = cgImage.colorSpace,
          let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
        print("Failed to create CGContext")
        return
    }
    
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let pixelData = context.data else {
        print("Failed to get pixel data")
        return
    }
    
    let data = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)
    
    let centerX = width / 2
    let centerY = height / 2
    
    // Scan inward from left (x = 0) to find left edge
    var leftEdge = 0
    for x in 0..<centerX {
        let offset = (centerY * width + x) * 4
        let r = data[offset]
        let g = data[offset+1]
        let b = data[offset+2]
        if r < 35 && g < 35 && b < 35 {
            leftEdge = x
            break
        }
    }
    
    // Scan inward from right (x = width - 1) to find right edge
    var rightEdge = width - 1
    for x in (centerX..<width).reversed() {
        let offset = (centerY * width + x) * 4
        let r = data[offset]
        let g = data[offset+1]
        let b = data[offset+2]
        if r < 35 && g < 35 && b < 35 {
            rightEdge = x
            break
        }
    }
    
    // Scan inward from top (y = 0) to find top edge
    var topEdge = 0
    for y in 0..<centerY {
        let offset = (y * width + centerX) * 4
        let r = data[offset]
        let g = data[offset+1]
        let b = data[offset+2]
        if r < 35 && g < 35 && b < 35 {
            topEdge = y
            break
        }
    }
    
    // Scan inward from bottom (y = height - 1) to find bottom edge
    var bottomEdge = height - 1
    for y in (centerY..<height).reversed() {
        let offset = (y * width + centerX) * 4
        let r = data[offset]
        let g = data[offset+1]
        let b = data[offset+2]
        if r < 35 && g < 35 && b < 35 {
            bottomEdge = y
            break
        }
    }
    
    print("Exact squircle edges (inward scan):")
    print("Left: \(leftEdge), Right: \(rightEdge) (width: \(rightEdge - leftEdge))")
    print("Top: \(topEdge), Bottom: \(bottomEdge) (height: \(bottomEdge - topEdge))")
}

findExactSquircleInward()
