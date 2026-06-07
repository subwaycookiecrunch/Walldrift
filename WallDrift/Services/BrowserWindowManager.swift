import AppKit
import SwiftUI

class BrowserWindowManager {
    static let shared = BrowserWindowManager()
    var window: NSWindow?
    
    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // keeps track of the main browser window so we don't open duplicate ones
        let browserView = MainBrowserView().frame(minWidth: 800, minHeight: 600)
        let hostingController = NSHostingController(rootView: browserView)
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "WallDrift Browser"
        newWindow.contentViewController = hostingController
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        self.window = newWindow
        
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
