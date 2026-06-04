import Foundation

enum DeepLink {
    static let scheme = "constructiongossip"

    static func postURL(for post: Post) -> URL {
        URL(string: "\(scheme)://post/\(post.id.uuidString)")!
    }

    static func postID(from url: URL) -> UUID? {
        guard url.scheme == scheme, url.host == "post" else { return nil }
        let idString = url.pathComponents.dropFirst().first
        return idString.flatMap(UUID.init(uuidString:))
    }
}
