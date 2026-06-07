import Foundation

struct RedditResponse: Decodable {
    let data: RedditData
}

struct RedditData: Decodable {
    let after: String?
    let children: [RedditPostContainer]
}

struct RedditPostContainer: Decodable {
    let data: RedditPost
}

struct RedditPost: Decodable, Identifiable {
    let id: String
    let title: String
    let author: String
    let subreddit: String
    let score: Int
    let url: String
    let preview: RedditPreview?
}

struct RedditPreview: Decodable {
    let images: [RedditImageContainer]
}

struct RedditImageContainer: Decodable {
    let source: RedditImageResolution
    let resolutions: [RedditImageResolution]
}

struct RedditImageResolution: Decodable {
    let url: String
    let width: Int
    let height: Int
    
    var decodedURL: URL? {
        let cleanURLString = url.replacingOccurrences(of: "&amp;", with: "&")
        return URL(string: cleanURLString)
    }
}
