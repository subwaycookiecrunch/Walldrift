import Foundation
import Combine

@MainActor
class BrowserViewModel: ObservableObject {
    @Published var wallpapers: [Wallpaper] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var currentSubreddit: String = "wallpapers" {
        didSet {
            if oldValue != currentSubreddit {
                viewFavoritesOnly = false
                viewCustomFeed = false
                selectedSourceId = nil
                viewTimeline = false
                Task { await fetchWallpapers(reset: true) }
            }
        }
    }
    @Published var currentSort: RedditSort = .hot {
        didSet { if oldValue != currentSort { Task { await fetchWallpapers(reset: true) } } }
    }
    @Published var currentTimeFilter: RedditTimeFilter = .week {
        didSet { if oldValue != currentTimeFilter { Task { await fetchWallpapers(reset: true) } } }
    }
    
    @Published var favorites: [Wallpaper] = []
    @Published var viewFavoritesOnly: Bool = false {
        didSet {
            if viewFavoritesOnly {
                viewCustomFeed = false
                selectedSourceId = nil
                viewTimeline = false
            }
        }
    }
    
    @Published var customSources: [SubredditSource] = [] {
        didSet {
            saveCustomSources()
        }
    }
    
    @Published var selectedSourceId: UUID? = nil {
        didSet {
            if oldValue != selectedSourceId && selectedSourceId != nil {
                viewFavoritesOnly = false
                viewCustomFeed = false
                viewTimeline = false
                Task { await fetchWallpapers(reset: true) }
            }
        }
    }
    
    @Published var viewCustomFeed: Bool = false {
        didSet {
            if viewCustomFeed {
                viewFavoritesOnly = false
                selectedSourceId = nil
                viewTimeline = false
                Task { await fetchWallpapers(reset: true) }
            }
        }
    }
    
    @Published var viewTimeline: Bool = false {
        didSet {
            if viewTimeline {
                viewFavoritesOnly = false
                viewCustomFeed = false
                selectedSourceId = nil
            }
        }
    }
    
    private var afterToken: String? = nil
    private var canLoadMore = true
    
    private let favoritesURL: URL
    private let sourcesURL: URL
    
    init() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("WallDrift")
        if !fileManager.fileExists(atPath: appSupport.path) {
            try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
        favoritesURL = appSupport.appendingPathComponent("favorites.json")
        sourcesURL = appSupport.appendingPathComponent("sources.json")
        
        loadFavorites()
        loadCustomSources()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleSourcesChanged), name: NSNotification.Name("SubredditSourcesDidChange"), object: nil)
    }
    
    @objc private func handleSourcesChanged() {
        Task { @MainActor in
            self.loadCustomSources()
        }
    }
    
    func fetchWallpapers(reset: Bool = false) async {
        if viewFavoritesOnly || viewTimeline { return }
        
        if reset {
            wallpapers.removeAll()
            afterToken = nil
            canLoadMore = true
        }
        
        guard canLoadMore, !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if viewCustomFeed {
                // pull everything merged together
                let activeSources = customSources.filter { $0.isActive }
                if activeSources.isEmpty {
                    wallpapers = []
                } else {
                    let merged = try await RedditService.shared.fetchWallpapers(from: activeSources)
                    wallpapers = merged
                }
                canLoadMore = false
            } else if let sourceId = selectedSourceId, let source = customSources.first(where: { $0.id == sourceId }) {
                // pull just one custom sub
                let result = try await RedditService.shared.fetchWallpapers(
                    subreddit: source.name,
                    sort: source.sortMode,
                    timeFilter: source.topTimeframe,
                    after: afterToken
                )
                wallpapers.append(contentsOf: result.wallpapers)
                afterToken = result.after
                canLoadMore = result.after != nil
                
                // save when we last fetched
                if let idx = customSources.firstIndex(where: { $0.id == sourceId }) {
                    customSources[idx].lastFetched = Date()
                }
            } else {
                // normal subreddit search from the text input
                let result = try await RedditService.shared.fetchWallpapers(
                    subreddit: currentSubreddit,
                    sort: currentSort,
                    timeFilter: currentTimeFilter,
                    after: afterToken
                )
                wallpapers.append(contentsOf: result.wallpapers)
                afterToken = result.after
                canLoadMore = result.after != nil
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func toggleFavorite(_ wallpaper: Wallpaper) {
        if favorites.contains(where: { $0.id == wallpaper.id }) {
            favorites.removeAll(where: { $0.id == wallpaper.id })
        } else {
            favorites.append(wallpaper)
        }
        saveFavorites()
    }
    
    func isFavorite(_ wallpaper: Wallpaper) -> Bool {
        favorites.contains(where: { $0.id == wallpaper.id })
    }
    
    // Custom Subreddit Management
    func addCustomSubreddit(name: String) async throws {
        let metadata = try await RedditService.shared.validateSubreddit(name: name)
        
        if customSources.contains(where: { $0.name.lowercased() == metadata.displayName.lowercased() }) {
            throw NSError(domain: "BrowserViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Subreddit r/\(metadata.displayName) is already added."])
        }
        
        let newSource = SubredditSource(
            id: UUID(),
            name: metadata.displayName,
            displayName: metadata.title,
            iconURL: metadata.cleanIconURL,
            subscriberCount: metadata.subscribers ?? 0,
            isActive: true,
            sortMode: .hot,
            topTimeframe: .week,
            dateAdded: Date(),
            lastFetched: nil
        )
        
        customSources.append(newSource)
    }
    
    func deleteCustomSource(at offsets: IndexSet) {
        let deletedIds = offsets.map { customSources[$0].id }
        if let selectedId = selectedSourceId, deletedIds.contains(selectedId) {
            selectedSourceId = nil
            currentSubreddit = "wallpapers"
        }
        customSources.remove(atOffsets: offsets)
    }
    
    func moveCustomSources(from source: IndexSet, to destination: Int) {
        customSources.move(fromOffsets: source, toOffset: destination)
    }
    
    func toggleSourceActive(id: UUID) {
        if let idx = customSources.firstIndex(where: { $0.id == id }) {
            customSources[idx].isActive.toggle()
            if viewCustomFeed {
                Task { await fetchWallpapers(reset: true) }
            }
        }
    }
    
    func updateSourceSettings(id: UUID, sortMode: RedditSort, topTimeframe: RedditTimeFilter) {
        if let idx = customSources.firstIndex(where: { $0.id == id }) {
            customSources[idx].sortMode = sortMode
            customSources[idx].topTimeframe = topTimeframe
            if selectedSourceId == id {
                Task { await fetchWallpapers(reset: true) }
            }
        }
    }
    
    private func loadFavorites() {
        guard let data = try? Data(contentsOf: favoritesURL) else { return }
        if let decoded = try? JSONDecoder().decode([Wallpaper].self, from: data) {
            favorites = decoded
        }
    }
    
    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            try? data.write(to: favoritesURL)
        }
    }
    
    private func loadCustomSources() {
        guard let data = try? Data(contentsOf: sourcesURL) else { return }
        if let decoded = try? JSONDecoder().decode([SubredditSource].self, from: data) {
            if decoded != customSources {
                customSources = decoded
            }
        }
    }
    
    private func saveCustomSources() {
        if let data = try? JSONEncoder().encode(customSources) {
            try? data.write(to: sourcesURL)
        }
    }
}
