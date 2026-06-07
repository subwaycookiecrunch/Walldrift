import Foundation
import AppKit

class WallpaperService {
    static let shared = WallpaperService()
    
    private let fileManager = FileManager.default
    private let wallpapersDirectory: URL
    
    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        wallpapersDirectory = appSupport.appendingPathComponent("WallDrift").appendingPathComponent("Wallpapers", isDirectory: true)
        
        if !fileManager.fileExists(atPath: wallpapersDirectory.path) {
            try? fileManager.createDirectory(at: wallpapersDirectory, withIntermediateDirectories: true)
        }
    }
    
    @MainActor
    func setWallpaper(_ wallpaper: Wallpaper, mode: NSImageScaling = .scaleProportionallyUpOrDown) async throws {
        let pathExtension = wallpaper.fullResURL.pathExtension.lowercased()
        let cleanExt = pathExtension.components(separatedBy: "?").first ?? ""
        let fileExtension = cleanExt.isEmpty ? "jpg" : cleanExt
        let fileURL = wallpapersDirectory.appendingPathComponent("\(wallpaper.id).\(fileExtension)")
        
        if !fileManager.fileExists(atPath: fileURL.path) {
            let (data, _) = try await URLSession.shared.data(from: wallpaper.fullResURL)
            // Decode and re-encode to sanitize image and prevent macOS WallpaperAgent crashes
            guard let image = NSImage(data: data),
                  let tiffData = image.tiffRepresentation,
                  let bitmapInfo = NSBitmapImageRep(data: tiffData),
                  let jpegData = bitmapInfo.representation(using: .jpeg, properties: [.compressionFactor: 0.95]) else {
                throw NSError(domain: "WallpaperService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode/encode image"])
            }
            try jpegData.write(to: fileURL, options: .atomic)
        }
        
        let metadataURL = wallpapersDirectory.appendingPathComponent("\(wallpaper.id).json")
        let metadataData = try JSONEncoder().encode(wallpaper)
        try metadataData.write(to: metadataURL, options: .atomic)
        
        let workspace = NSWorkspace.shared
        for screen in NSScreen.screens {
            var options = workspace.desktopImageOptions(for: screen) ?? [:]
            options[.imageScaling] = NSNumber(value: NSImageScaling.scaleProportionallyUpOrDown.rawValue)
            options[.allowClipping] = NSNumber(value: true)
            try workspace.setDesktopImageURL(fileURL, for: screen, options: options)
        }
    }
}
