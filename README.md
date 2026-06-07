# WallDrift 🌊

Hey! Welcome to WallDrift. This is a native macOS app I built to keep my desktop fresh. It grabs high-res wallpapers straight from your favorite subreddits (like `r/wallpapers` or `r/EarthPorn`) and auto-rotates them in the background.

It lives right in your menu bar so it stays out of your way, but you can pop open the main window whenever you want to browse, download, or "favorite" specific images.

## What it does

* **Auto-rotating wallpapers:** Set an interval and let the app cycle through top Reddit posts on all your monitors.
* **Menu bar quick access:** Skip a wallpaper, clear the cache, or jump to settings right from the menu bar.
* **Add your own subreddits:** You aren't stuck with the defaults. Toss in any image-heavy subreddit you like.
* **Native & fast:** Built 100% in Swift and SwiftUI. It's super lightweight.
* **Caching:** It caches images so it doesn't nuke your bandwidth or Reddit's API every time you open it. It also cleans up after itself (keeps the cache under 500MB).

## How to build it

I used [XcodeGen](https://github.com/yonaskolb/XcodeGen) to keep the repo clean without checking in a messy `.xcodeproj` file. 

To run this on your own machine:

1. Grab XcodeGen (if you don't have it):
   ```bash
   brew install xcodegen
   ```
2. Generate the project:
   ```bash
   xcodegen generate
   ```
3. Open the newly created `WallDrift.xcodeproj` in Xcode and hit Build (or `Cmd + R`)!

## Tech details
It's built for macOS 13.0+ using Swift 5.9, SwiftUI, and standard AppKit under the hood. Everything is sandboxed properly, and your wallpapers save locally to `~/Library/Application Support/WallDrift`.

Feel free to poke around the code, submit issues, or fork it!
