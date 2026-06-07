import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: BrowserViewModel
    @State private var isShowingAddSheet = false
    
    let defaultSubreddits = ["wallpapers", "EarthPorn", "spaceporn", "WidescreenWallpaper", "MinimalWallpaper", "Amoledbackgrounds"]
    
    var body: some View {
        List {
            Section(header: HStack {
                Text("My Sources")
                    .font(.headline)
                Spacer()
                Button(action: {
                    isShowingAddSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }) {
                if !viewModel.customSources.isEmpty {
                    Button(action: {
                        viewModel.viewCustomFeed = true
                    }) {
                        HStack {
                            Image(systemName: "photo.stack.fill")
                                .frame(width: 20, height: 20)
                            Text("My Feed")
                            Spacer()
                            if viewModel.viewCustomFeed {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
                
                ForEach(viewModel.customSources) { source in
                    HStack(spacing: 8) {
                        // toggle whether to include in My Feed
                        Button(action: {
                            viewModel.toggleSourceActive(id: source.id)
                        }) {
                            Image(systemName: source.isActive ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(source.isActive ? .accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            viewModel.selectedSourceId = source.id
                        }) {
                            HStack {
                                if let iconStr = source.iconURL, let iconURL = URL(string: iconStr) {
                                    CachedAsyncImage(url: iconURL)
                                        .frame(width: 20, height: 20)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "globe")
                                        .frame(width: 20, height: 20)
                                        .background(Color.secondary.opacity(0.2))
                                        .clipShape(Circle())
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("r/\(source.name)")
                                        .lineLimit(1)
                                    Text("\(formatSubscribers(source.subscriberCount)) subs")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if viewModel.selectedSourceId == source.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                    .contextMenu {
                        Button("Delete") {
                            if let idx = viewModel.customSources.firstIndex(where: { $0.id == source.id }) {
                                viewModel.deleteCustomSource(at: IndexSet(integer: idx))
                            }
                        }
                        
                        Divider()
                        
                        Menu("Sort Option") {
                            ForEach(RedditSort.allCases) { sort in
                                Button(action: {
                                    viewModel.updateSourceSettings(id: source.id, sortMode: sort, topTimeframe: source.topTimeframe)
                                }) {
                                    HStack {
                                        Text(sort.rawValue.capitalized)
                                        if source.sortMode == sort {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                        
                        if source.sortMode == .top {
                            Menu("Time Filter") {
                                ForEach(RedditTimeFilter.allCases) { filter in
                                    Button(action: {
                                        viewModel.updateSourceSettings(id: source.id, sortMode: source.sortMode, topTimeframe: filter)
                                    }) {
                                        HStack {
                                            Text(filter.rawValue.capitalized)
                                            if source.topTimeframe == filter {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    viewModel.deleteCustomSource(at: offsets)
                }
                .onMove { source, destination in
                    viewModel.moveCustomSources(from: source, to: destination)
                }
            }
            
            Section(header: Text("Live Feed").font(.headline)) {
                Button(action: {
                    viewModel.viewTimeline = true
                }) {
                    HStack {
                        Image(systemName: "livephoto")
                            .frame(width: 20, height: 20)
                        Text("Timeline")
                        
                        if BackgroundFeedService.shared.isPolling {
                            PulsingGreenDot()
                        }
                        
                        Spacer()
                        
                        if viewModel.viewTimeline {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Browse").font(.headline)) {
                ForEach(defaultSubreddits, id: \.self) { sub in
                    Button(action: {
                        viewModel.currentSubreddit = sub
                    }) {
                        HStack {
                            Image(systemName: "photo")
                                .frame(width: 20, height: 20)
                            Text("r/\(sub)")
                            Spacer()
                            if viewModel.currentSubreddit == sub && !viewModel.viewFavoritesOnly && !viewModel.viewCustomFeed && viewModel.selectedSourceId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
            }
            
            Section(header: Text("Library").font(.headline)) {
                Button(action: {
                    viewModel.viewFavoritesOnly = true
                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .frame(width: 20, height: 20)
                        Text("Favorites")
                        Spacer()
                        if viewModel.viewFavoritesOnly {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .sheet(isPresented: $isShowingAddSheet) {
            AddSubredditSheet(viewModel: viewModel)
        }
    }
    
    private func formatSubscribers(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
}

struct PulsingGreenDot: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 6, height: 6)
            .scaleEffect(isAnimating ? 1.5 : 1.0)
            .opacity(isAnimating ? 0.4 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}
