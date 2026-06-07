# WallDrift

WallDrift is a production-ready macOS wallpaper engine app built completely natively using Swift and SwiftUI. It fetches beautiful, high-resolution wallpapers from Reddit's public API (such as `r/wallpapers`, `r/EarthPorn`, etc.), and allows you to seamlessly browse, download, set, and auto-rotate them as your desktop background.

## Features Overview

- **Native SwiftUI:** Built natively for macOS 13.0+ using cutting edge SwiftUI layout features like `NavigationSplitView` and `LazyVGrid`.
- **Menu Bar Access:** Runs as a menu bar app for quick access to auto-rotate toggles and "Next Wallpaper" functionality, while allowing you to open the full browser window on demand.
- **Reddit Integration:** Directly fetches images via Reddit's JSON API from top, hot, and new sorts across different subreddits. Custom subreddits can be added on the fly.
- **Auto-Rotation Engine:** A built-in background timer periodically updates your desktop wallpaper from your selected subreddit sources automatically.
- **Robust Caching:** Utilizes a two-tier in-memory and disk cache mechanism to preserve bandwidth and quickly load thumbnails. Limits disk cache size to 500MB and automatically evicts oldest cached images.
- **Favorite & Download:** Seamlessly "Favorite" your top wallpapers to keep them stored in your local library, or download them natively as desktop backgrounds across multiple connected displays.

## Build Instructions

Because generating an `.xcodeproj` file with its complex UUID structure is notoriously tricky to do automatically, this project leverages [XcodeGen](https://github.com/yonaskolb/XcodeGen) to construct a fresh and clean Xcode project file.

1. **Install XcodeGen** (if you haven't already):
   ```bash
   brew install xcodegen
   ```

2. **Generate the Xcode Project:**
   In your terminal, navigate to the `WallDrift` project directory and run:
   ```bash
   xcodegen generate
   ```

3. **Open and Build:**
   This command will produce `WallDrift.xcodeproj`. Open it using Xcode:
   ```bash
   open WallDrift.xcodeproj
   ```
   Alternatively, you can build from the command line using:
   ```bash
   xcodebuild -project WallDrift.xcodeproj -scheme WallDrift build
   ```

## Keyboard Shortcuts & Navigation

- **Command (⌘) + W:** Close the main browser window.
- **Click:** Select a wallpaper thumbnail to view it in full resolution.
- **Menu Bar Icon:** Click the `photo.on.rectangle` icon in your macOS status bar to reveal the compact quick-settings popover.

## Developer Info
- **Tech Stack:** Swift 5.9, SwiftUI, Combine, URLSession, AppKit.
- **Permissions:** App Sandbox enabled, outbound network access allowed, and read/write file access enabled for saving to `~/Library/Application Support/WallDrift`.
