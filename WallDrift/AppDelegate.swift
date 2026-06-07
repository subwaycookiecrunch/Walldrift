import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) var shared: AppDelegate?
    
    override init() {
        super.init()
        Self.shared = self
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = AutoRotateService.shared
        BackgroundFeedService.shared.startPolling()
        
        var isInitialLaunch = true
        var willUpdateObserver: NSObjectProtocol?
        willUpdateObserver = NotificationCenter.default.addObserver(forName: NSApplication.willUpdateNotification, object: nil, queue: .main) { _ in
            if isInitialLaunch {
                isInitialLaunch = false
                if let window = NSApp.windows.first(where: { $0.title == "WallDrift Browser" || $0.title == "WallDrift" }) {
                    window.close()
                }
                if let observer = willUpdateObserver {
                    NotificationCenter.default.removeObserver(observer)
                }
            }
        }
    }
}
