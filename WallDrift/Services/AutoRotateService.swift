import Foundation
import Combine
import AppKit

class AutoRotateService: ObservableObject {
    static let shared = AutoRotateService()
    
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "autoRotateEnabled"); updateTimer() }
    }
    
    @Published var interval: TimeInterval {
        didSet { UserDefaults.standard.set(interval, forKey: "autoRotateInterval"); updateTimer() }
    }
    
    @Published var subreddits: [String] {
        didSet { UserDefaults.standard.set(subreddits, forKey: "autoRotateSubreddits") }
    }
    
    @Published var rotateFromFeed: Bool {
        didSet { UserDefaults.standard.set(rotateFromFeed, forKey: "rotateFromFeed") }
    }
    
    private var timer: AnyCancellable?
    
    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "autoRotateEnabled")
        let savedInterval = UserDefaults.standard.double(forKey: "autoRotateInterval")
        self.interval = savedInterval > 0 ? savedInterval : 3600
        let savedSubreddits = UserDefaults.standard.stringArray(forKey: "autoRotateSubreddits") ?? ["wallpapers", "EarthPorn", "spaceporn", "WidescreenWallpaper"]
        self.subreddits = savedSubreddits
        self.rotateFromFeed = UserDefaults.standard.bool(forKey: "rotateFromFeed")
        
        updateTimer()
    }
    
    private func updateTimer() {
        timer?.cancel()
        if isEnabled {
            timer = Timer.publish(every: interval, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    Task {
                        await self?.rotateNow()
                    }
                }
        }
    }
    
    func rotateNow() async {
        if rotateFromFeed {
            let feed = BackgroundFeedService.shared.timelineFeed
            if let newest = feed.first {
                do {
                    try await WallpaperService.shared.setWallpaper(newest)
                    print("Auto-rotation (feed mode): set wallpaper to: \(newest.title)")
                } catch {
                    print("Auto-rotation (feed mode) failed: \(error)")
                }
                return
            } else {
                print("Auto-rotation (feed mode) warning: timeline feed is empty, falling back to subreddit search")
            }
        }
        
        guard !subreddits.isEmpty else { return }
        let randomSub = subreddits.randomElement()!
        
        do {
            let (wallpapers, _) = try await RedditService.shared.fetchWallpapers(subreddit: randomSub, sort: .hot, limit: 50)
            if let randomWallpaper = wallpapers.randomElement() {
                try await WallpaperService.shared.setWallpaper(randomWallpaper)
            }
        } catch {
            print("Auto-rotate failed: \(error)")
        }
    }
}
