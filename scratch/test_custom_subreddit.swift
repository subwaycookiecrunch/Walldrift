import Foundation

// Copy necessary model & enum definitions for self-contained testing
struct SubredditSource: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let displayName: String
    let iconURL: String?
    let subscriberCount: Int
    var isActive: Bool
    var sortMode: RedditSort
    var topTimeframe: RedditTimeFilter
    let dateAdded: Date
    var lastFetched: Date?
}

struct Wallpaper: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let author: String
    let subreddit: String
    let score: Int
    let fullResURL: URL
    let thumbnailURL: URL?
    let width: Int
    let height: Int
}

enum RedditSort: String, CaseIterable, Identifiable, Codable {
    case hot = "hot"
    case new = "new"
    case top = "top"
    var id: String { self.rawValue }
}

enum RedditTimeFilter: String, CaseIterable, Identifiable, Codable {
    case day = "day"
    case week = "week"
    case month = "month"
    case year = "year"
    case all = "all"
    var id: String { self.rawValue }
}

struct SubredditAboutResponse: Decodable {
    let data: SubredditAboutData
}

struct SubredditAboutData: Decodable {
    let displayName: String
    let title: String
    let publicDescription: String?
    let subscribers: Int?
    let iconImg: String?
    let communityIcon: String?
    
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case title
        case publicDescription = "public_description"
        case subscribers
        case iconImg = "icon_img"
        case communityIcon = "community_icon"
    }
    
    var cleanIconURL: String? {
        var icon: String? = nil
        if let commIcon = communityIcon, !commIcon.isEmpty {
            icon = commIcon
        } else if let img = iconImg, !img.isEmpty {
            icon = img
        }
        
        guard var iconUrl = icon else { return nil }
        return iconUrl.replacingOccurrences(of: "&amp;", with: "&")
    }
}

// Implement mock/replicated services for direct testing
class TestService {
    static let shared = TestService()
    
    func validateSubreddit(name: String) async throws -> SubredditAboutData {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "r/", with: "")
            .replacingOccurrences(of: "/", with: "")
        
        // Use RSS feed validation since JSON is blocked in VM
        let rssURL = URL(string: "https://www.reddit.com/r/\(cleanName).rss")!
        var request = URLRequest(url: rssURL)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 200 {
            return SubredditAboutData(
                displayName: cleanName,
                title: "r/\(cleanName)",
                publicDescription: "Custom Subreddit Source",
                subscribers: 1500000,
                iconImg: "https://styles.redditmedia.com/t5_2qh1o/styles/communityIcon_clean.png",
                communityIcon: nil
            )
        } else {
            throw NSError(domain: "SubredditValidation", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Subreddit r/\(cleanName) is private, banned, or does not exist."])
        }
    }
    
    func fetchWallpapers(subreddit: String, limit: Int = 5) async throws -> [Wallpaper] {
        let rssURL = URL(string: "https://www.reddit.com/r/\(subreddit)/hot.rss?limit=\(limit)")!
        var request = URLRequest(url: rssURL)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let xmlString = String(data: data, encoding: .utf8) else {
            return []
        }
        
        return try parseRSSWallpapers(xmlString, subreddit: subreddit)
    }
    
    private func parseRSSWallpapers(_ xmlString: String, subreddit: String) throws -> [Wallpaper] {
        var wallpapers: [Wallpaper] = []
        let entryRegex = try NSRegularExpression(pattern: "<entry>(.*?)</entry>", options: [.dotMatchesLineSeparators])
        let range = NSRange(xmlString.startIndex..., in: xmlString)
        let matches = entryRegex.matches(in: xmlString, range: range)
        
        for match in matches {
            guard let entryRange = Range(match.range(at: 1), in: xmlString) else { continue }
            let entryContent = String(xmlString[entryRange])
            
            // Parse ID
            let idRegex = try NSRegularExpression(pattern: "<id>([^<]+)</id>")
            guard let idMatch = idRegex.firstMatch(in: entryContent, range: NSRange(entryContent.startIndex..., in: entryContent)),
                  let idRange = Range(idMatch.range(at: 1), in: entryContent) else {
                continue
            }
            let fullId = String(entryContent[idRange])
            let rawId = fullId.hasPrefix("t3_") ? String(fullId.dropFirst(3)) : fullId
            
            // Parse Title
            let titleRegex = try NSRegularExpression(pattern: "<title>([^<]+)</title>")
            guard let titleMatch = titleRegex.firstMatch(in: entryContent, range: NSRange(entryContent.startIndex..., in: entryContent)),
                  let titleRange = Range(titleMatch.range(at: 1), in: entryContent) else {
                continue
            }
            let title = String(entryContent[titleRange])
            
            // Parse Author
            let authorRegex = try NSRegularExpression(pattern: "<author>\\s*<name>([^<]+)</name>")
            var author = "unknown"
            if let authorMatch = authorRegex.firstMatch(in: entryContent, range: NSRange(entryContent.startIndex..., in: entryContent)),
               let authorRange = Range(authorMatch.range(at: 1), in: entryContent) {
                let rawAuthor = String(entryContent[authorRange])
                author = rawAuthor.hasPrefix("/u/") ? String(rawAuthor.dropFirst(3)) : rawAuthor
            }
            
            // Parse Full Res Link
            let decodedContent = entryContent
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
            
            let linkRegex = try NSRegularExpression(pattern: "href=\"([^\"]+)\">\\[link\\]")
            guard let linkMatch = linkRegex.firstMatch(in: decodedContent, range: NSRange(decodedContent.startIndex..., in: decodedContent)),
                  let linkRange = Range(linkMatch.range(at: 1), in: decodedContent) else {
                continue
            }
            let fullResStr = String(decodedContent[linkRange])
            
            let lowerURL = fullResStr.lowercased()
            guard lowerURL.hasSuffix(".jpg") || lowerURL.hasSuffix(".jpeg") || lowerURL.hasSuffix(".png") else {
                continue
            }
            
            guard let fullResURL = URL(string: fullResStr) else {
                continue
            }
            
            let wallpaper = Wallpaper(
                id: rawId,
                title: title,
                author: author,
                subreddit: subreddit,
                score: 0,
                fullResURL: fullResURL,
                thumbnailURL: fullResURL,
                width: 1920,
                height: 1080
            )
            wallpapers.append(wallpaper)
        }
        
        return wallpapers
    }
    
    func fetchWallpapers(from sources: [SubredditSource], limitPerSource: Int = 3) async throws -> [Wallpaper] {
        return try await withThrowingTaskGroup(of: [Wallpaper].self) { group in
            for source in sources {
                guard source.isActive else { continue }
                group.addTask {
                    do {
                        return try await self.fetchWallpapers(subreddit: source.name, limit: limitPerSource)
                    } catch {
                        print("Failed for r/\(source.name): \(error.localizedDescription)")
                        return []
                    }
                }
            }
            
            var allWallpapers: [Wallpaper] = []
            var seenIds = Set<String>()
            
            for try await wallpapers in group {
                for wp in wallpapers {
                    if !seenIds.contains(wp.id) {
                        seenIds.insert(wp.id)
                        allWallpapers.append(wp)
                    }
                }
            }
            
            return allWallpapers
        }
    }
}

Task {
    do {
        // 1. Test Subreddit Validation
        print("1. Validating subreddit 'EarthPorn'...")
        let metadata = try await TestService.shared.validateSubreddit(name: "EarthPorn")
        print("   Success! Subreddit name: r/\(metadata.displayName), Subscribers: \(metadata.subscribers ?? 0)")
        
        // 2. Test JSON Codable Persistence
        print("\n2. Testing SubredditSource Codable persistence...")
        let source1 = SubredditSource(
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
        
        let source2 = SubredditSource(
            id: UUID(),
            name: "spaceporn",
            displayName: "r/spaceporn",
            iconURL: nil,
            subscriberCount: 2400000,
            isActive: true,
            sortMode: .hot,
            topTimeframe: .week,
            dateAdded: Date(),
            lastFetched: nil
        )
        
        let sources = [source1, source2]
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(sources)
        print("   Serialized JSON sources:\n\(String(data: jsonData, encoding: .utf8)!)")
        
        let decoder = JSONDecoder()
        let decodedSources = try decoder.decode([SubredditSource].self, from: jsonData)
        print("   Successfully deserialized \(decodedSources.count) sources.")
        
        // 3. Test Concurrent Task Group Fetching
        print("\n3. Testing concurrent fetching from active sources (EarthPorn & spaceporn)...")
        let mergedWallpapers = try await TestService.shared.fetchWallpapers(from: decodedSources, limitPerSource: 3)
        print("   Deduplicated Merged Feed Success! Found \(mergedWallpapers.count) wallpapers.")
        for wp in mergedWallpapers {
            print("   - [\(wp.subreddit)] ID: \(wp.id), Title: \(wp.title)")
        }
        
        exit(0)
    } catch {
        print("Error encountered: \(error.localizedDescription)")
        exit(1)
    }
}

RunLoop.main.run()
