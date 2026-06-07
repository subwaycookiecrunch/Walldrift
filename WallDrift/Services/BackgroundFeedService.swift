import Foundation
import Network
import UserNotifications
import IOKit.ps
import SwiftUI

class BackgroundFeedService: ObservableObject {
    static let shared = BackgroundFeedService()
    
    @Published var timelineFeed: [Wallpaper] = [] {
        didSet { saveTimeline() }
    }
    @Published var isPolling: Bool = false
    @Published var lastUpdated: Date? = nil {
        didSet { UserDefaults.standard.set(lastUpdated, forKey: "feedLastUpdated") }
    }
    @Published var newItemCount: Int = 0 {
        didSet { UserDefaults.standard.set(newItemCount, forKey: "feedNewItemCount") }
    }
    
    @Published var pollInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(pollInterval, forKey: "feedPollInterval")
            startPolling()
        }
    }
    
    @Published var notifyOnNew: Bool {
        didSet {
            UserDefaults.standard.set(notifyOnNew, forKey: "feedNotifyOnNew")
            if notifyOnNew { requestNotificationPermission() }
        }
    }
    
    @Published var autoSetOnNew: Bool {
        didSet { UserDefaults.standard.set(autoSetOnNew, forKey: "feedAutoSetOnNew") }
    }
    
    private var seenPostIds: Set<String> = []
    
    private var timelineURL: URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("WallDrift")
        return appSupport.appendingPathComponent("timeline.json")
    }
    
    private var sourcesURL: URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("WallDrift")
        return appSupport.appendingPathComponent("sources.json")
    }
    
    private var activityScheduler: NSBackgroundActivityScheduler?
    
    private init() {
        let interval = UserDefaults.standard.double(forKey: "feedPollInterval")
        self.pollInterval = interval > 0 ? interval : 900
        
        self.notifyOnNew = UserDefaults.standard.object(forKey: "feedNotifyOnNew") as? Bool ?? true
        self.autoSetOnNew = UserDefaults.standard.bool(forKey: "feedAutoSetOnNew")
        self.lastUpdated = UserDefaults.standard.object(forKey: "feedLastUpdated") as? Date
        self.newItemCount = UserDefaults.standard.integer(forKey: "feedNewItemCount")
        
        loadTimeline()
        self.seenPostIds = loadSeenIds()
        
        if notifyOnNew {
            requestNotificationPermission()
        }
    }
    
    func startPolling() {
        activityScheduler?.invalidate()
        
        let scheduler = NSBackgroundActivityScheduler(identifier: "com.walldrift.backgroundpoll")
        scheduler.repeats = true
        scheduler.interval = pollInterval
        scheduler.tolerance = pollInterval * 0.1
        
        scheduler.schedule { [weak self] completion in
            guard let self = self else {
                completion(.finished)
                return
            }
            Task {
                await self.performPoll()
                completion(.finished)
            }
        }
        self.activityScheduler = scheduler
        self.isPolling = true
        print("Background Feed Service: Polling started on a \(pollInterval / 60) minute interval.")
    }
    
    func stopPolling() {
        activityScheduler?.invalidate()
        activityScheduler = nil
        self.isPolling = false
        print("Background Feed Service: Polling stopped.")
    }
    
    func performPoll() async {
        // don't run this if battery is low, nobody wants their laptop dying because of a wallpaper app
        if shouldSkipPollingDueToBattery() {
            print("Background Feed Service: Poll skipped - battery is low (< 20%)")
            return
        }
        
        // only query if we're actually connected
        if !NetworkMonitor.shared.isConnected {
            print("Background Feed Service: Poll skipped - no internet network")
            return
        }
        
        let sources = loadSources()
        let activeSources = sources.filter { $0.isActive }
        guard !activeSources.isEmpty else {
            print("Background Feed Service: No active subreddit sources found. Skipping poll.")
            await MainActor.run {
                self.lastUpdated = Date()
            }
            return
        }
        
        do {
            print("Background Feed Service: Starting poll tick...")
            let fetched = try await RedditService.shared.fetchWallpapers(from: activeSources, limitPerSource: 20)
            
            let currentSeen = self.seenPostIds
            let newWallpapers = fetched.filter { !currentSeen.contains($0.id) }
            
            if !newWallpapers.isEmpty {
                print("Background Feed Service: Found \(newWallpapers.count) new wallpapers!")
                
                // Add timestamps to new wallpapers
                let now = Date()
                let newWithTimestamps = newWallpapers.map { wp -> Wallpaper in
                    var copy = wp
                    copy.dateFetched = now
                    return copy
                }
                
                await MainActor.run {
                    withAnimation(.default) {
                        self.timelineFeed.insert(contentsOf: newWithTimestamps, at: 0)
                        self.newItemCount += newWithTimestamps.count
                    }
                    
                    for wp in newWithTimestamps {
                        self.seenPostIds.insert(wp.id)
                    }
                    saveSeenIds(self.seenPostIds)
                }
                
                postNotification(count: newWithTimestamps.count)
                
                // set it immediately if the user wants auto-rotate on new arrivals
                if autoSetOnNew, let newest = newWithTimestamps.first {
                    do {
                        try await WallpaperService.shared.setWallpaper(newest)
                        print("Background Feed Service: Automatically set desktop wallpaper to \(newest.title)")
                    } catch {
                        print("Background Feed Service: Failed to auto-set wallpaper: \(error)")
                    }
                }
            } else {
                print("Background Feed Service: No new wallpapers found in this tick.")
            }
            
            // Update lastFetched timestamp on each active source
            let now = Date()
            var updatedSources = sources
            for i in 0..<updatedSources.count {
                if updatedSources[i].isActive {
                    updatedSources[i].lastFetched = now
                }
            }
            saveSources(updatedSources)
            
            await MainActor.run {
                self.lastUpdated = now
            }
            
        } catch {
            print("Background Feed Service: Poll failed with error: \(error.localizedDescription)")
        }
    }
    
    func clearFeedHistory() {
        self.timelineFeed.removeAll()
        self.seenPostIds.removeAll()
        self.newItemCount = 0
        saveSeenIds([])
        
        Task {
            await performPoll()
        }
    }
    
    // Helpers
    private func shouldSkipPollingDueToBattery() -> Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        
        for ps in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, ps).takeUnretainedValue() as? [String: AnyObject] else { continue }
            
            if let current = info[kIOPSCurrentCapacityKey] as? Int,
               let max = info[kIOPSMaxCapacityKey] as? Int,
               let powerSourceState = info[kIOPSPowerSourceStateKey] as? String {
                
                let isBattery = powerSourceState == "Battery Power"
                let percentage = (Double(current) / Double(max)) * 100.0
                
                if isBattery && percentage < 20.0 {
                    return true
                }
            }
        }
        return false
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    private func postNotification(count: Int) {
        guard notifyOnNew else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "New Wallpapers Arrived"
        content.body = "\(count) new wallpaper\(count == 1 ? "" : "s") added to your feed."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func loadSources() -> [SubredditSource] {
        guard let data = try? Data(contentsOf: sourcesURL) else { return [] }
        return (try? JSONDecoder().decode([SubredditSource].self, from: data)) ?? []
    }
    
    private func saveSources(_ sources: [SubredditSource]) {
        if let data = try? JSONEncoder().encode(sources) {
            try? data.write(to: sourcesURL)
            NotificationCenter.default.post(name: NSNotification.Name("SubredditSourcesDidChange"), object: nil)
        }
    }
    
    private func loadTimeline() {
        guard let data = try? Data(contentsOf: timelineURL) else { return }
        if let decoded = try? JSONDecoder().decode([Wallpaper].self, from: data) {
            self.timelineFeed = decoded
        }
    }
    
    private func saveTimeline() {
        if let data = try? JSONEncoder().encode(timelineFeed) {
            try? data.write(to: timelineURL)
        }
    }
    
    private func loadSeenIds() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: "seenPostIds") ?? []
        return Set(array)
    }
    
    private func saveSeenIds(_ set: Set<String>) {
        UserDefaults.standard.set(Array(set), forKey: "seenPostIds")
    }
}

// Simple NWPathMonitor wrapper to check network state
class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private var isNetworkConnected = true
    
    private init() {
        monitor.pathUpdateHandler = { path in
            self.isNetworkConnected = path.status == .satisfied
        }
        let queue = DispatchQueue(label: "com.walldrift.networkmonitor")
        monitor.start(queue: queue)
    }
    
    var isConnected: Bool {
        isNetworkConnected
    }
}
