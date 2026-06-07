import Foundation

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
    
    // cleans up the thumbnail URLs reddit gives us.
    // sometimes they escape the ampersands which breaks URLSession.
    var cleanIconURL: String? {
        var icon: String? = nil
        if let commIcon = communityIcon, !commIcon.isEmpty {
            icon = commIcon
        } else if let img = iconImg, !img.isEmpty {
            icon = img
        }
        
        guard let iconUrl = icon else { return nil }
        return iconUrl.replacingOccurrences(of: "&amp;", with: "&")
    }
}

class RedditService {
    static let shared = RedditService()
    private init() {}
    
    func fetchWallpapers(subreddit: String, sort: RedditSort, timeFilter: RedditTimeFilter = .week, after: String? = nil, limit: Int = 50) async throws -> (wallpapers: [Wallpaper], after: String?) {
        do {
            var components = URLComponents(string: "https://www.reddit.com/r/\(subreddit)/\(sort.rawValue).json")!
            var queryItems = [
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
            
            if sort == .top {
                queryItems.append(URLQueryItem(name: "t", value: timeFilter.rawValue))
            }
            
            if let after = after {
                queryItems.append(URLQueryItem(name: "after", value: after))
            }
            
            components.queryItems = queryItems
            
            guard let url = components.url else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if httpResponse.statusCode == 429 {
                throw NSError(domain: "RedditRateLimit", code: 429, userInfo: [NSLocalizedDescriptionKey: "Reddit rate limited. Try again later."])
            }
            
            if httpResponse.statusCode == 403 {
                throw NSError(domain: "RedditNetworkBlock", code: 403, userInfo: [NSLocalizedDescriptionKey: "Reddit blocked requests."])
            }
            
            let decoder = JSONDecoder()
            let redditResponse = try decoder.decode(RedditResponse.self, from: data)
            
            var wallpapers: [Wallpaper] = []
            for child in redditResponse.data.children {
                let post = child.data
                
                // only grab direct image links
                let lowerURL = post.url.lowercased()
                guard lowerURL.hasSuffix(".jpg") || lowerURL.hasSuffix(".jpeg") || lowerURL.hasSuffix(".png") else {
                    continue
                }
                
                guard let preview = post.preview, !preview.images.isEmpty else {
                    continue
                }
                
                let imageSource = preview.images[0].source
                guard let fullResURL = imageSource.decodedURL else { continue }
                
                // find a preview thumbnail close to 600px wide so we don't load huge files in the grid
                let resolutions = preview.images[0].resolutions
                let suitableThumb = resolutions.first(where: { $0.width >= 600 }) ?? resolutions.last
                let thumbURL = suitableThumb?.decodedURL ?? fullResURL
                
                let wallpaper = Wallpaper(
                    id: post.id,
                    title: post.title,
                    author: post.author,
                    subreddit: post.subreddit,
                    score: post.score,
                    fullResURL: fullResURL,
                    thumbnailURL: thumbURL,
                    width: imageSource.width,
                    height: imageSource.height
                )
                wallpapers.append(wallpaper)
            }
            
            return (wallpapers, redditResponse.data.after)
            
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                throw error
            }
            if error is CancellationError {
                throw error
            }
            print("Reddit JSON API failed or blocked: \(error.localizedDescription). Falling back to RSS feed...")
            return try await fetchWallpapersFromRSS(subreddit: subreddit, sort: sort, timeFilter: timeFilter, after: after, limit: limit)
        }
    }
    
    private func fetchWallpapersFromRSS(subreddit: String, sort: RedditSort, timeFilter: RedditTimeFilter, after: String?, limit: Int) async throws -> (wallpapers: [Wallpaper], after: String?) {
        var components = URLComponents(string: "https://www.reddit.com/r/\(subreddit)/\(sort.rawValue).rss")!
        var queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        if sort == .top {
            queryItems.append(URLQueryItem(name: "t", value: timeFilter.rawValue))
        }
        
        if let after = after {
            queryItems.append(URLQueryItem(name: "after", value: after))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 429 {
            throw NSError(domain: "RedditRateLimit", code: 429, userInfo: [NSLocalizedDescriptionKey: "Reddit rate limited. Try again later."])
        }
        
        if httpResponse.statusCode != 200 {
            throw NSError(domain: "RedditNetworkBlock", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Reddit RSS returned status code \(httpResponse.statusCode)."])
        }
        
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "RedditRSSParsing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode RSS feed data as UTF-8."])
        }
        
        return try parseRSSWallpapers(xmlString, subreddit: subreddit)
    }
    
    private func parseRSSWallpapers(_ xmlString: String, subreddit: String) throws -> (wallpapers: [Wallpaper], after: String?) {
        var wallpapers: [Wallpaper] = []
        
        let entryRegex = try NSRegularExpression(pattern: "<entry>(.*?)</entry>", options: [.dotMatchesLineSeparators])
        let range = NSRange(xmlString.startIndex..., in: xmlString)
        let matches = entryRegex.matches(in: xmlString, range: range)
        
        var lastId: String? = nil
        
        for match in matches {
            guard let entryRange = Range(match.range(at: 1), in: xmlString) else { continue }
            let entryContent = String(xmlString[entryRange])
            
            // let's parse the ID. regex is gross but works
            let idRegex = try NSRegularExpression(pattern: "<id>([^<]+)</id>")
            guard let idMatch = idRegex.firstMatch(in: entryContent, range: NSRange(entryContent.startIndex..., in: entryContent)),
                  let idRange = Range(idMatch.range(at: 1), in: entryContent) else {
                continue
            }
            let fullId = String(entryContent[idRange]) // E.g., t3_1tsuzvq
            
            let rawId: String
            if fullId.hasPrefix("t3_") {
                rawId = String(fullId.dropFirst(3))
            } else {
                rawId = fullId
            }
            lastId = fullId
            
            let titleRegex = try NSRegularExpression(pattern: "<title>([^<]+)</title>")
            guard let titleMatch = titleRegex.firstMatch(in: entryContent, range: NSRange(entryContent.startIndex..., in: entryContent)),
                  let titleRange = Range(titleMatch.range(at: 1), in: entryContent) else {
                continue
            }
            let title = String(entryContent[titleRange])
            
            let authorRegex = try NSRegularExpression(pattern: "<author>\\s*<name>([^<]+)</name>")
            var author = "unknown"
            if let authorMatch = authorRegex.firstMatch(in: entryContent, range: NSRange(entryContent.startIndex..., in: entryContent)),
               let authorRange = Range(authorMatch.range(at: 1), in: entryContent) {
                let rawAuthor = String(entryContent[authorRange])
                if rawAuthor.hasPrefix("/u/") {
                    author = String(rawAuthor.dropFirst(3))
                } else {
                    author = rawAuthor
                }
            }
            
            let thumbRegex = try NSRegularExpression(pattern: "<media:thumbnail\\s+url=\"([^\"]+)\"")
            var thumbURL: URL? = nil
            if let thumbMatch = thumbRegex.firstMatch(in: entryContent, range: NSRange(entryContent.startIndex..., in: entryContent)),
               let thumbRange = Range(thumbMatch.range(at: 1), in: entryContent) {
                let thumbStr = String(entryContent[thumbRange]).replacingOccurrences(of: "&amp;", with: "&")
                thumbURL = URL(string: thumbStr)
            }
            
            // decode html entities from rss payload
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
                thumbnailURL: thumbURL ?? fullResURL,
                width: 1920,
                height: 1080
            )
            wallpapers.append(wallpaper)
        }
        
        print("RSS Fallback: successfully parsed \(wallpapers.count) wallpapers for r/\(subreddit)")
        return (wallpapers, lastId)
    }
    func validateSubreddit(name: String) async throws -> SubredditAboutData {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "r/", with: "")
            .replacingOccurrences(of: "/", with: "")
        
        // try the normal about json first
        do {
            let url = URL(string: "https://www.reddit.com/r/\(cleanName)/about.json")!
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let decoded = try JSONDecoder().decode(SubredditAboutResponse.self, from: data)
                return decoded.data
            }
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                throw error
            }
            if error is CancellationError {
                throw error
            }
            // print("validateSubreddit: JSON API failed: \(error.localizedDescription)")
        }
        
        // backup rss check for rate limits/proxies/cloud environments
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
                subscribers: 0,
                iconImg: nil,
                communityIcon: nil
            )
        } else {
            throw NSError(domain: "SubredditValidation", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Subreddit r/\(cleanName) is private, banned, or does not exist."])
        }
    }
    
    func fetchWallpapers(from sources: [SubredditSource], limitPerSource: Int = 20) async throws -> [Wallpaper] {
        return try await withThrowingTaskGroup(of: [Wallpaper].self) { group in
            for source in sources {
                guard source.isActive else { continue }
                group.addTask {
                    do {
                        let result = try await self.fetchWallpapers(
                            subreddit: source.name,
                            sort: source.sortMode,
                            timeFilter: source.topTimeframe,
                            after: nil,
                            limit: limitPerSource
                        )
                        return result.wallpapers
                    } catch {
                        print("fetchWallpapers(from sources): Failed for r/\(source.name): \(error.localizedDescription)")
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
