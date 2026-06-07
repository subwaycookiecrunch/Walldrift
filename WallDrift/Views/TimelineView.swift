import SwiftUI

struct TimelineView: View {
    @Binding var selectedWallpaper: Wallpaper?
    @ObservedObject var feedService = BackgroundFeedService.shared
    
    @State private var visibleLimit = 30
    @State private var initialNewCount = BackgroundFeedService.shared.newItemCount
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Refresh Now button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Timeline")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let lastUpdated = feedService.lastUpdated {
                        Text("Last updated: \(formatTime(lastUpdated))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        await feedService.performPoll()
                        initialNewCount = feedService.newItemCount
                    }
                }) {
                    HStack {
                        if feedService.isPolling {
                            ProgressView().controlSize(.small)
                                .padding(.trailing, 2)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Refresh Now")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(feedService.isPolling)
            }
            .padding()
            .background(Material.bar)
            
            Divider()
            
            if feedService.timelineFeed.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "livephoto.badge.a")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("Your timeline is empty")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Curate your Custom Sources in the sidebar, and polling will automatically load new wallpapers chronologically.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // items feed container
                ScrollView {
                    LazyVStack(spacing: 12) {
                        let itemsToShow = Array(feedService.timelineFeed.prefix(visibleLimit))
                        
                        ForEach(Array(itemsToShow.enumerated()), id: \.element.id) { index, wallpaper in
                            TimelineRow(
                                wallpaper: wallpaper,
                                isNew: index < initialNewCount
                            )
                            .onTapGesture {
                                selectedWallpaper = wallpaper
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                        
                        if visibleLimit < feedService.timelineFeed.count {
                            ProgressView()
                                .padding()
                                .onAppear {
                                    // infinite scroll load next batch
                                    visibleLimit += 30
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            // clean badge count since we saw the new ones
            BackgroundFeedService.shared.newItemCount = 0
            initialNewCount = feedService.newItemCount
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct TimelineRow: View {
    let wallpaper: Wallpaper
    let isNew: Bool
    
    @State private var isHovered = false
    @State private var isSetting = false
    @State private var setSuccess = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Thumbnail (80x60pt rounded)
            if let thumbURL = wallpaper.thumbnailURL {
                CachedAsyncImage(url: thumbURL, contentMode: .fill)
                    .frame(width: 80, height: 60)
                    .cornerRadius(8)
                    .clipped()
            } else {
                Color.gray.opacity(0.1)
                    .frame(width: 80, height: 60)
                    .cornerRadius(8)
            }
            
            // Middle: Details
            VStack(alignment: .leading, spacing: 6) {
                Text(wallpaper.title)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack(spacing: 10) {
                    Text("r/\(wallpaper.subreddit)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                    
                    if let date = wallpaper.dateFetched {
                        Text(timeAgo(from: date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption2)
                        Text("\(wallpaper.score)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Right: Interactive Actions
            ZStack {
                if isHovered {
                    Button(action: setWallpaper) {
                        HStack(spacing: 6) {
                            if isSetting {
                                ProgressView().controlSize(.small)
                            } else if setSuccess {
                                Image(systemName: "checkmark")
                            } else {
                                Image(systemName: "desktopcomputer")
                            }
                            Text(setSuccess ? "Done" : "Set Now")
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(setSuccess ? Color.green : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSetting)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if isNew {
                    Text("NEW")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.green)
                        .cornerRadius(4)
                }
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(10)
        .background(isHovered ? Color.secondary.opacity(0.1) : Color.secondary.opacity(0.04))
        .cornerRadius(12)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
    
    private func setWallpaper() {
        isSetting = true
        setSuccess = false
        Task {
            do {
                try await WallpaperService.shared.setWallpaper(wallpaper)
                await MainActor.run {
                    isSetting = false
                    setSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        setSuccess = false
                    }
                }
            } catch {
                await MainActor.run {
                    isSetting = false
                }
            }
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.string(for: date) ?? ""
    }
}
