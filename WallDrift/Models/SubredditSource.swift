import Foundation

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
