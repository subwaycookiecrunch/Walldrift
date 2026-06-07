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
    var dateFetched: Date? = nil
    
    var redditPostURL: URL {
        URL(string: "https://reddit.com/r/\(subreddit)/comments/\(id)")!
    }
}
