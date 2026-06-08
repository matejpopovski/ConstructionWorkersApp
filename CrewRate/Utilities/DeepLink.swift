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

    static func passwordRecoveryAccessToken(from url: URL) -> String? {
        guard url.scheme == scheme,
              url.host == "auth",
              url.path == "/reset-password" else { return nil }
        let parameters = queryParameters(from: url.fragment) ?? queryParameters(from: url.query)
        guard parameters?["type"] == "recovery" else { return nil }
        return parameters?["access_token"]
    }

    private static func queryParameters(from value: String?) -> [String: String]? {
        guard let value, !value.isEmpty else { return nil }
        var components = URLComponents()
        components.query = value
        return components.queryItems?.reduce(into: [:]) { result, item in
            result[item.name] = item.value
        }
    }
}
