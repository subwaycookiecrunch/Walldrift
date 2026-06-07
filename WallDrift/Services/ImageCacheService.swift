import Foundation
import AppKit
import CryptoKit

actor ImageCacheService {
    static let shared = ImageCacheService()
    
    private let memoryCache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    // 500MB max disk cache
    private let maxDiskCacheSize: Int = 500 * 1024 * 1024
    
    private init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("WallDrift", isDirectory: true)
        
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        memoryCache.countLimit = 100 // max 100 images in memory
    }
    
    private func cacheKey(for url: URL) -> String {
        let data = Data(url.absoluteString.utf8)
        let hash = Insecure.MD5.hash(data: data)
        let md5 = hash.map { String(format: "%02hhx", $0) }.joined()
        
        let pathExtension = url.pathExtension.lowercased()
        let cleanExt = pathExtension.components(separatedBy: "?").first ?? ""
        let fileExtension = cleanExt.isEmpty ? "jpg" : cleanExt
        return "\(md5).\(fileExtension)"
    }
    
    func image(for url: URL) async throws -> NSImage? {
        let key = cacheKey(for: url)
        
        if let image = memoryCache.object(forKey: key as NSString) {
            return image
        }
        
        let fileURL = cacheDirectory.appendingPathComponent(key)
        if fileManager.fileExists(atPath: fileURL.path) {
            if let image = NSImage(contentsOf: fileURL) {
                memoryCache.setObject(image, forKey: key as NSString)
                return image
            }
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = NSImage(data: data) else {
            return nil
        }
        
        memoryCache.setObject(image, forKey: key as NSString)
        try? data.write(to: fileURL)
        
        // clean up old cache files in the background if we went over the limit
        Task.detached {
            await self.enforceCacheLimit()
        }
        
        return image
    }
    
    private func enforceCacheLimit() async {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { return }
        
        var totalSize = 0
        var fileAttributes: [(url: URL, size: Int, date: Date)] = []
        
        for file in files {
            if let attrs = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
               let size = attrs.fileSize,
               let date = attrs.contentModificationDate {
                totalSize += size
                fileAttributes.append((file, size, date))
            }
        }
        
        if totalSize <= maxDiskCacheSize { return }
        
        // remove the oldest files first
        fileAttributes.sort { $0.date < $1.date }
        
        for file in fileAttributes {
            try? fileManager.removeItem(at: file.url)
            totalSize -= file.size
            if totalSize <= maxDiskCacheSize {
                break
            }
        }
    }
    
    func clearCache() async {
        memoryCache.removeAllObjects()
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? fileManager.removeItem(at: file)
        }
    }
    
    func getCacheSize() async -> Int {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var totalSize = 0
        for file in files {
            if let attrs = try? file.resourceValues(forKeys: [.fileSizeKey]), let size = attrs.fileSize {
                totalSize += size
            }
        }
        return totalSize
    }
}
