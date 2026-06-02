import CryptoKit
import Foundation

enum AppError: LocalizedError {
    case duplicateUsername
    case duplicateEmail
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .duplicateUsername:
            "That username is already taken."
        case .duplicateEmail:
            "That email already has an account."
        case .invalidCredentials:
            "Email or password is incorrect."
        }
    }
}

struct StoredAccount: Codable, Identifiable, Equatable {
    var id: UUID
    var username: String
    var email: String
    var passwordHash: String
    var profile: Profile
}

enum LocalStore {
    private static let accountsKey = "crewRate.accounts"
    private static let postsKey = "crewRate.posts"
    private static let commentsKey = "crewRate.comments"
    private static let friendsKey = "crewRate.friends"
    private static let pendingRequestsKey = "crewRate.pendingRequests"
    private static let likedPostsKey = "crewRate.likedPosts"
    private static let likedCommentsKey = "crewRate.likedComments"
    private static let messagesKey = "crewRate.messages"

    static func passwordHash(_ password: String) -> String {
        SHA256.hash(data: Data(password.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func loadAccounts() -> [StoredAccount] {
        load([StoredAccount].self, key: accountsKey, fallback: [])
    }

    static func saveAccounts(_ accounts: [StoredAccount]) {
        save(accounts, key: accountsKey)
    }

    static func loadPosts() -> [Post]? {
        loadOptional([Post].self, key: postsKey)
    }

    static func savePosts(_ posts: [Post]) {
        save(posts, key: postsKey)
    }

    static func loadComments() -> [Comment]? {
        loadOptional([Comment].self, key: commentsKey)
    }

    static func saveComments(_ comments: [Comment]) {
        save(comments, key: commentsKey)
    }

    static func loadFriends() -> [Profile]? {
        loadOptional([Profile].self, key: friendsKey)
    }

    static func saveFriends(_ friends: [Profile]) {
        save(friends, key: friendsKey)
    }

    static func loadPendingRequests() -> [FriendRequest]? {
        loadOptional([FriendRequest].self, key: pendingRequestsKey)
    }

    static func savePendingRequests(_ requests: [FriendRequest]) {
        save(requests, key: pendingRequestsKey)
    }

    static func loadLikedPosts() -> Set<UUID> {
        Set(load([UUID].self, key: likedPostsKey, fallback: []))
    }

    static func saveLikedPosts(_ ids: Set<UUID>) {
        save(Array(ids), key: likedPostsKey)
    }

    static func loadLikedComments() -> Set<UUID> {
        Set(load([UUID].self, key: likedCommentsKey, fallback: []))
    }

    static func saveLikedComments(_ ids: Set<UUID>) {
        save(Array(ids), key: likedCommentsKey)
    }

    static func loadMessages() -> [ChatMessage] {
        load([ChatMessage].self, key: messagesKey, fallback: [])
    }

    static func saveMessages(_ messages: [ChatMessage]) {
        save(messages, key: messagesKey)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String, fallback: T) -> T {
        loadOptional(type, key: key) ?? fallback
    }

    private static func loadOptional<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var currentProfile: Profile?
    private var accounts: [StoredAccount]

    init() {
        accounts = LocalStore.loadAccounts()
    }

    func signUp(username: String, email: String, password: String) async throws -> Profile {
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !accounts.contains(where: { $0.username.lowercased() == normalizedUsername.lowercased() }) else {
            throw AppError.duplicateUsername
        }
        guard !accounts.contains(where: { $0.email.lowercased() == normalizedEmail }) else {
            throw AppError.duplicateEmail
        }
        let profile = Profile(id: UUID(), username: normalizedUsername, email: normalizedEmail, firstName: nil, lastName: nil, profilePhotoURL: nil, state: nil, city: nil, streetAddressPrivateOnly: nil, tradePosition: nil, experienceLevel: nil, currentCompanyOrEmployer: nil, payType: nil, payAmount: nil, unionStatus: nil, yearsExperience: nil, certifications: [], benefitsReceived: [], languagesSpoken: [], bio: nil, openToWork: false, willingToRelocate: false, showRealName: false, showCurrentCompany: false, showPayOnProfile: false, showCityState: false, allowFriendRequests: true, allowMessagesFrom: .friends)
        accounts.append(StoredAccount(id: profile.id, username: normalizedUsername, email: normalizedEmail, passwordHash: LocalStore.passwordHash(password), profile: profile))
        LocalStore.saveAccounts(accounts)
        currentProfile = profile
        return profile
    }

    func login(email: String, password: String) async throws -> Profile {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hash = LocalStore.passwordHash(password)
        guard let account = accounts.first(where: { $0.email.lowercased() == normalizedEmail && $0.passwordHash == hash }) else {
            throw AppError.invalidCredentials
        }
        currentProfile = account.profile
        return account.profile
    }

    func updateAccountProfile(_ profile: Profile) {
        guard let index = accounts.firstIndex(where: { $0.id == profile.id }) else { return }
        accounts[index].username = profile.username
        accounts[index].email = profile.email ?? accounts[index].email
        accounts[index].profile = profile
        LocalStore.saveAccounts(accounts)
        currentProfile = profile
    }

    func signOut() {
        currentProfile = nil
    }
}

@MainActor
final class ProfileService: ObservableObject {
    @Published var profiles: [Profile]

    init() {
        let accountProfiles = LocalStore.loadAccounts().map(\.profile)
        profiles = (DemoData.profiles + accountProfiles).uniquedByID()
    }

    func update(_ profile: Profile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
    }
}

@MainActor
final class PostService: ObservableObject {
    @Published var posts: [Post] {
        didSet { LocalStore.savePosts(posts) }
    }

    init() {
        posts = (LocalStore.loadPosts() ?? DemoData.posts).sorted { $0.createdAt > $1.createdAt }
    }

    func create(_ post: Post) {
        posts.insert(post, at: 0)
    }

    func delete(_ post: Post, currentUserID: UUID) {
        guard post.userID == currentUserID else { return }
        posts.removeAll { $0.id == post.id }
    }

    func adjustLike(_ post: Post, liked: Bool) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index].likeCount = max(0, posts[index].likeCount + (liked ? 1 : -1))
    }
}

@MainActor
final class CommentService: ObservableObject {
    @Published var comments: [Comment] {
        didSet { LocalStore.saveComments(comments) }
    }

    init() {
        comments = LocalStore.loadComments() ?? DemoData.comments
    }

    func comments(for post: Post) -> [Comment] {
        comments.filter { $0.postID == post.id && $0.parentCommentID == nil }
    }

    func replies(to comment: Comment) -> [Comment] {
        comments.filter { $0.parentCommentID == comment.id }
    }

    func totalCount(for post: Post) -> Int {
        comments.filter { $0.postID == post.id }.count
    }

    func add(_ comment: Comment) {
        comments.append(comment)
    }

    func adjustLike(_ comment: Comment, liked: Bool) {
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }
        comments[index].likeCount = max(0, comments[index].likeCount + (liked ? 1 : -1))
    }
}

@MainActor
final class FriendService: ObservableObject {
    @Published var friends: [Profile] {
        didSet { LocalStore.saveFriends(friends) }
    }
    @Published var pendingRequests: [FriendRequest] {
        didSet { LocalStore.savePendingRequests(pendingRequests) }
    }

    init() {
        friends = LocalStore.loadFriends() ?? Array(DemoData.profiles.dropFirst(1).prefix(2))
        pendingRequests = LocalStore.loadPendingRequests() ?? [
            FriendRequest(id: UUID(), senderID: DemoData.profiles[3].id, receiverID: DemoData.currentUserID, senderUsername: DemoData.profiles[3].username, status: .pending, createdAt: .now.addingTimeInterval(-3600))
        ]
    }

    func isFriend(_ profile: Profile) -> Bool {
        friends.contains { $0.id == profile.id }
    }

    func hasPendingRequest(to profile: Profile) -> Bool {
        pendingRequests.contains { $0.receiverID == profile.id || $0.senderID == profile.id }
    }

    func sendRequest(to profile: Profile, from currentProfile: Profile?) {
        guard !isFriend(profile), !hasPendingRequest(to: profile), let currentProfile else { return }
        pendingRequests.append(FriendRequest(id: UUID(), senderID: currentProfile.id, receiverID: profile.id, senderUsername: currentProfile.username, status: .pending, createdAt: .now))
    }

    func accept(_ request: FriendRequest, profiles: [Profile]) {
        pendingRequests.removeAll { $0.id == request.id }
        guard let profile = profiles.first(where: { $0.id == request.senderID }), !isFriend(profile) else { return }
        friends.append(profile)
    }

    func reject(_ request: FriendRequest) {
        pendingRequests.removeAll { $0.id == request.id }
    }

    func remove(_ profile: Profile) {
        friends.removeAll { $0.id == profile.id }
    }
}

@MainActor
final class SearchService {
    func search(query: String, profiles: [Profile], posts: [Post]) -> (people: [Profile], posts: [Post], companies: [String]) {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return (profiles, posts, companies(from: posts)) }
        let people = profiles.filter { profile in
            [profile.username, profile.city, profile.state, profile.tradeLabel, profile.currentCompanyOrEmployer].compactMap { $0?.lowercased() }.contains { $0.contains(term) }
        }
        let matchingPosts = posts.filter { post in
            [post.textContent, post.companyOrEmployer, post.city, post.state, post.tradeLabel].compactMap { $0?.lowercased() }.contains { $0.contains(term) }
        }
        return (people, matchingPosts, companies(from: matchingPosts).filter { $0.lowercased().contains(term) })
    }

    private func companies(from posts: [Post]) -> [String] {
        Array(Set(posts.compactMap(\.companyOrEmployer))).sorted()
    }
}

@MainActor
final class LikeService: ObservableObject {
    @Published private(set) var likedPostIDs: Set<UUID> {
        didSet { LocalStore.saveLikedPosts(likedPostIDs) }
    }
    @Published private(set) var likedCommentIDs: Set<UUID> {
        didSet { LocalStore.saveLikedComments(likedCommentIDs) }
    }

    init() {
        likedPostIDs = LocalStore.loadLikedPosts()
        likedCommentIDs = LocalStore.loadLikedComments()
    }

    func isPostLiked(_ post: Post) -> Bool {
        likedPostIDs.contains(post.id)
    }

    func isCommentLiked(_ comment: Comment) -> Bool {
        likedCommentIDs.contains(comment.id)
    }

    func togglePost(_ post: Post, postService: PostService) {
        if likedPostIDs.contains(post.id) {
            likedPostIDs.remove(post.id)
            postService.adjustLike(post, liked: false)
        } else {
            likedPostIDs.insert(post.id)
            postService.adjustLike(post, liked: true)
        }
    }

    func toggleComment(_ comment: Comment, commentService: CommentService) {
        if likedCommentIDs.contains(comment.id) {
            likedCommentIDs.remove(comment.id)
            commentService.adjustLike(comment, liked: false)
        } else {
            likedCommentIDs.insert(comment.id)
            commentService.adjustLike(comment, liked: true)
        }
    }
}

@MainActor
final class MessageService: ObservableObject {
    @Published var messages: [ChatMessage] {
        didSet { LocalStore.saveMessages(messages) }
    }

    init() {
        messages = LocalStore.loadMessages()
    }

    func thread(currentUserID: UUID?, friendID: UUID) -> [ChatMessage] {
        guard let currentUserID else { return [] }
        return messages
            .filter { ($0.senderID == currentUserID && $0.receiverID == friendID) || ($0.senderID == friendID && $0.receiverID == currentUserID) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func send(to receiver: Profile, from sender: Profile?, body: String, imageData: Data?) {
        guard let sender else { return }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || imageData != nil else { return }
        messages.append(ChatMessage(id: UUID(), senderID: sender.id, receiverID: receiver.id, body: trimmed, imageData: imageData, createdAt: .now))
    }
}

@MainActor
final class StorageService {
    func uploadProfilePhoto() async -> URL? { nil }
    func uploadPostImages() async -> [URL] { [] }
    func uploadCommentImages() async -> [URL] { [] }
}

@MainActor
final class ModerationService {
    func reportPost(_ post: Post, reason: String) {}
    func reportComment(_ comment: Comment, reason: String) {}
    func blockUser(_ profile: Profile) {}
}

private extension Array where Element == Profile {
    func uniquedByID() -> [Profile] {
        var seen = Set<UUID>()
        return filter { seen.insert($0.id).inserted }
    }
}
