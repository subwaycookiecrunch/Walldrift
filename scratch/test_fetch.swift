import Foundation

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

enum RedditSort: String, CaseIterable, Identifiable {
    case hot = "hot"
    case new = "new"
    case top = "top"
    var id: String { self.rawValue }
}

enum RedditTimeFilter: String, CaseIterable, Identifiable {
    case day = "day"
    case week = "week"
    case month = "month"
    case year = "year"
    case all = "all"
    var id: String { self.rawValue }
}

func fetchWallpapersFromRSS(subreddit: String, sort: RedditSort, timeFilter: RedditTimeFilter, after: String?, limit: Int) async throws -> (wallpapers: [Wallpaper], after: String?) {
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
    
    print("Fetching URL: \(url.absoluteString)")
    
    var request = URLRequest(url: url)
    request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw URLError(.badServerResponse)
    }
    
    print("HTTP Status Code: \(httpResponse.statusCode)")
    
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

func parseRSSWallpapers(_ xmlString: String, subreddit: String) throws -> (wallpapers: [Wallpaper], after: String?) {
    var wallpapers: [Wallpaper] = []
    
    let entryRegex = try NSRegularExpression(pattern: "<entry>(.*?)</entry>", options: [.dotMatchesLineSeparators])
    let range = NSRange(xmlString.startIndex..., in: xmlString)
    let matches = entryRegex.matches(in: xmlString, range: range)
    
    var lastId: String? = nil
    
    var first = true
    for match in matches {
        guard let entryRange = Range(match.range(at: 1), in: xmlString) else { continue }
        let entryContent = String(xmlString[entryRange])
        
        if first {
            print("\n--- FIRST ENTRY DEBUG ---")
            print(String(entryContent.prefix(1000)))
            print("-------------------------\n")
            first = false
        }
        
        // Parse ID
        let idRegex = try NSRegularExpression(pattern: "<id>([^<]+)</id>")
        guard let idMatch = idRegex.firstMatch(in: entryContent, range: NSRange(entryContent.startIndex..., in: entryContent)),
              let idRange = Range(idMatch.range(at: 1), in: entryContent) else {
            continue
        }
        let fullId = String(entryContent[idRange])
        
        let rawId: String
        if fullId.hasPrefix("t3_") {
            rawId = String(fullId.dropFirst(3))
        } else {
            rawId = fullId
        }
        lastId = fullId
        
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
            if rawAuthor.hasPrefix("/u/") {
                author = String(rawAuthor.dropFirst(3))
            } else {
                author = rawAuthor
            }
        }
        
        // Parse Thumbnail
        let thumbRegex = try NSRegularExpression(pattern: "<media:thumbnail\\s+url=\"([^\"]+)\"")
        var thumbURL: URL? = nil
        if let thumbMatch = thumbRegex.firstMatch(in: entryContent, range: NSRange(entryContent.startIndex..., in: entryContent)),
           let thumbRange = Range(thumbMatch.range(at: 1), in: entryContent) {
            let thumbStr = String(entryContent[thumbRange]).replacingOccurrences(of: "&amp;", with: "&")
            thumbURL = URL(string: thumbStr)
        }
        
        // Parse Full Res Image URL
        let decodedContent = entryContent
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        
        let linkRegex = try NSRegularExpression(pattern: "href=\"([^\"]+)\">\\[link\\]")
        guard let linkMatch = linkRegex.firstMatch(in: decodedContent, range: NSRange(decodedContent.startIndex..., in: decodedContent)),
              let linkRange = Range(linkMatch.range(at: 1), in: decodedContent) else {
            print("Failed to match linkRegex for post \(rawId)")
            continue
        }
        let fullResStr = String(decodedContent[linkRange])
        
        let lowerURL = fullResStr.lowercased()
        guard lowerURL.hasSuffix(".jpg") || lowerURL.hasSuffix(".jpeg") || lowerURL.hasSuffix(".png") else {
            print("Failed suffix check: \(fullResStr)")
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
    
    return (wallpapers, lastId)
}

Task {
    do {
        print("Testing r/wallpapers...")
        let result = try await fetchWallpapersFromRSS(subreddit: "wallpapers", sort: .hot, timeFilter: .week, after: nil, limit: 5)
        print("Success! Found \(result.wallpapers.count) wallpapers.")
        for wp in result.wallpapers {
            print("- ID: \(wp.id)")
            print("  Title: \(wp.title)")
            print("  Author: \(wp.author)")
            print("  FullRes: \(wp.fullResURL.absoluteString)")
            print("  Thumb: \(wp.thumbnailURL?.absoluteString ?? "none")")
        }
        print("After token: \(result.after ?? "nil")")
        
        if let afterToken = result.after {
            print("\nTesting pagination (page 2) with token \(afterToken)...")
            let result2 = try await fetchWallpapersFromRSS(subreddit: "wallpapers", sort: .hot, timeFilter: .week, after: afterToken, limit: 5)
            print("Success! Found \(result2.wallpapers.count) wallpapers on page 2.")
            for wp in result2.wallpapers {
                print("- ID: \(wp.id)")
                print("  Title: \(wp.title)")
            }
        }
        
        exit(0)
    } catch {
        print("Error: \(error.localizedDescription)")
        exit(1)
    }
}

// Keep command line tool alive until exit(0)
RunLoop.main.run()
