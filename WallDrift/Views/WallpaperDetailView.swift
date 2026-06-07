import SwiftUI

struct WallpaperDetailView: View {
    let wallpaper: Wallpaper
    @ObservedObject var viewModel: BrowserViewModel
    @Binding var isPresented: Bool
    
    @State private var isSettingWallpaper = false
    @State private var wallpaperSetSuccess = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { isPresented = false }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding()
                
                Spacer()
                
                Button(action: {
                    viewModel.toggleFavorite(wallpaper)
                }) {
                    Image(systemName: viewModel.isFavorite(wallpaper) ? "heart.fill" : "heart")
                        .foregroundColor(viewModel.isFavorite(wallpaper) ? .red : .primary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .padding()
            }
            .background(Material.bar)
            
            ScrollView {
                VStack(spacing: 20) {
                    CachedAsyncImage(url: wallpaper.fullResURL, contentMode: .fit)
                        .aspectRatio(CGFloat(wallpaper.width) / CGFloat(wallpaper.height), contentMode: .fit)
                        .cornerRadius(12)
                        .shadow(radius: 10)
                        .padding()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(wallpaper.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text("By u/\(wallpaper.author)")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(wallpaper.width) × \(wallpaper.height)")
                                .foregroundColor(.secondary)
                        }
                        
                        Link("View on Reddit", destination: wallpaper.redditPostURL)
                            .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 20) {
                        Button(action: setWallpaper) {
                            HStack {
                                if isSettingWallpaper {
                                    ProgressView().controlSize(.small)
                                } else if wallpaperSetSuccess {
                                    Image(systemName: "checkmark")
                                } else {
                                    Image(systemName: "desktopcomputer")
                                }
                                Text(wallpaperSetSuccess ? "Wallpaper Set" : "Set as Wallpaper")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSettingWallpaper)
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private func setWallpaper() {
        isSettingWallpaper = true
        wallpaperSetSuccess = false
        Task {
            do {
                try await WallpaperService.shared.setWallpaper(wallpaper)
                await MainActor.run {
                    isSettingWallpaper = false
                    wallpaperSetSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        wallpaperSetSuccess = false
                    }
                }
            } catch {
                await MainActor.run {
                    isSettingWallpaper = false
                }
            }
        }
    }
}
