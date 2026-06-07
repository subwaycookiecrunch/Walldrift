import SwiftUI

struct MainBrowserView: View {
    @StateObject private var viewModel = BrowserViewModel()
    @State private var selectedWallpaper: Wallpaper?
    
    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            ZStack {
                if viewModel.viewTimeline {
                    TimelineView(selectedWallpaper: $selectedWallpaper)
                } else {
                    WallpaperGridView(viewModel: viewModel, selectedWallpaper: $selectedWallpaper)
                }
                
                if let wallpaper = selectedWallpaper {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            selectedWallpaper = nil
                        }
                    
                    WallpaperDetailView(wallpaper: wallpaper, viewModel: viewModel, isPresented: Binding(
                        get: { selectedWallpaper != nil },
                        set: { if !$0 { selectedWallpaper = nil } }
                    ))
                    .background(Material.regular)
                    .cornerRadius(16)
                    .shadow(radius: 20)
                    .padding(40)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("WallDrift Browser")
        .animation(.spring(), value: selectedWallpaper != nil)
    }
}
