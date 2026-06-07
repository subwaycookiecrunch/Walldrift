import SwiftUI

@main
struct WallDriftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("WallDrift", systemImage: "photo.on.rectangle") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
        
        WindowGroup(id: "browser") {
            MainBrowserView()
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}
