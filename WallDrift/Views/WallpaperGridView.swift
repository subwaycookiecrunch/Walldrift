import SwiftUI

struct CachedAsyncImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    @State private var image: NSImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.1))
            } else {
                Color.gray.opacity(0.1)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url, image == nil else { return }
        isLoading = true
        Task {
            if let img = try? await ImageCacheService.shared.image(for: url) {
                await MainActor.run {
                    self.image = img
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct WallpaperGridView: View {
    @ObservedObject var viewModel: BrowserViewModel
    @Binding var selectedWallpaper: Wallpaper?
    
    let columns = [
        GridItem(.adaptive(minimum: 250, maximum: 350), spacing: 16)
    ]
    
    var body: some View {
        let items = viewModel.viewFavoritesOnly ? viewModel.favorites : viewModel.wallpapers
        
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { wallpaper in
                    WallpaperCardView(wallpaper: wallpaper)
                        .onTapGesture {
                            selectedWallpaper = wallpaper
                        }
                        .onAppear {
                            if !viewModel.viewFavoritesOnly && wallpaper == viewModel.wallpapers.last {
                                Task {
                                    await viewModel.fetchWallpapers()
                                }
                            }
                        }
                }
            }
            .padding()
            
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .padding()
            }
            
            if items.isEmpty && !viewModel.isLoading {
                if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 64))
                            .foregroundColor(.orange)
                        Text("Error Fetching Wallpapers")
                            .font(.title2)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 100)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        Text(viewModel.viewFavoritesOnly ? "No favorites yet." : "No wallpapers found.")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 100)
                }
            }
        }
        .task {
            if viewModel.wallpapers.isEmpty {
                await viewModel.fetchWallpapers()
            }
        }
    }
}

struct WallpaperCardView: View {
    let wallpaper: Wallpaper
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(url: wallpaper.thumbnailURL, contentMode: .fill)
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(wallpaper.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack {
                    Text("r/\(wallpaper.subreddit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up")
                        .font(.caption2)
                    Text("\(wallpaper.score)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
