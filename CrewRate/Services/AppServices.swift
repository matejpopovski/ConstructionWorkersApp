import Foundation

enum AppError: LocalizedError {
    case duplicateUsername
    case duplicateEmail
    case invalidCredentials
    case weakPassword

    var errorDescription: String? {
        switch self {
        case .duplicateUsername:
            "That username is already taken."
        case .duplicateEmail:
            "That email already has an account."
        case .invalidCredentials:
            "Email or password is incorrect."
        case .weakPassword:
            "Password must be at least 8 characters."
        }
    }
}

struct StoredAccount: Codable, Identifiable, Equatable {
    var id: UUID
    var username: String
    var email: String
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
    private static let reportsKey = "crewRate.reports"
    private static let blockedUsersKey = "crewRate.blockedUsers"

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

    static func loadReports() -> [Report] {
        load([Report].self, key: reportsKey, fallback: [])
    }

    static func saveReports(_ reports: [Report]) {
        save(reports, key: reportsKey)
    }

    static func loadBlockedUsers() -> Set<UUID> {
        Set(load([UUID].self, key: blockedUsersKey, fallback: []))
    }

    static func saveBlockedUsers(_ ids: Set<UUID>) {
        save(Array(ids), key: blockedUsersKey)
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
        guard password.count >= 8 else {
            throw AppError.weakPassword
        }
        guard !accounts.contains(where: { $0.username.lowercased() == normalizedUsername.lowercased() }) else {
            throw AppError.duplicateUsername
        }
        guard !accounts.contains(where: { $0.email.lowercased() == normalizedEmail }) else {
            throw AppError.duplicateEmail
        }
        let profile = try await SupabaseClient.signUp(username: normalizedUsername, email: normalizedEmail, password: password)
        accounts.append(StoredAccount(id: profile.id, username: normalizedUsername, email: normalizedEmail, profile: profile))
        LocalStore.saveAccounts(accounts)
        currentProfile = profile
        return profile
    }

    func login(email: String, password: String) async throws -> Profile {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var profile = try await SupabaseClient.login(email: normalizedEmail, password: password)
        profile.email = normalizedEmail
        if let index = accounts.firstIndex(where: { $0.id == profile.id }) {
            accounts[index].profile = profile
        } else {
            accounts.append(StoredAccount(id: profile.id, username: profile.username, email: normalizedEmail, profile: profile))
        }
        LocalStore.saveAccounts(accounts)
        currentProfile = profile
        return profile
    }

    func restoreSession() async throws -> Profile? {
        guard var profile = try await SupabaseClient.restoreSession() else { return nil }
        if let account = accounts.first(where: { $0.id == profile.id }) {
            profile.email = account.email
        }
        currentProfile = profile
        return profile
    }

    func updateAccountProfile(_ profile: Profile, syncRemote: Bool = true) {
        if let index = accounts.firstIndex(where: { $0.id == profile.id }) {
            accounts[index].username = profile.username
            accounts[index].email = profile.email ?? accounts[index].email
            accounts[index].profile = profile
        }
        LocalStore.saveAccounts(accounts)
        currentProfile = profile
        guard syncRemote else { return }
        Task {
            guard var remoteProfile = try? await SupabaseClient.upsertProfile(profile) else { return }
            remoteProfile.email = profile.email
            remoteProfile.profilePhotoData = profile.profilePhotoData
            if let index = accounts.firstIndex(where: { $0.id == remoteProfile.id }) {
                accounts[index].username = remoteProfile.username
                accounts[index].email = remoteProfile.email ?? accounts[index].email
                accounts[index].profile = remoteProfile
                LocalStore.saveAccounts(accounts)
            }
            currentProfile = remoteProfile
        }
    }

    func signOut() {
        currentProfile = nil
        Task { await SupabaseClient.signOut() }
    }

    func deleteAccount(profileID: UUID) async throws {
        try await SupabaseClient.deleteAccount()
        accounts.removeAll { $0.id == profileID }
        LocalStore.saveAccounts(accounts)
        if currentProfile?.id == profileID {
            currentProfile = nil
        }
    }
}

@MainActor
final class ProfileService: ObservableObject {
    @Published var profiles: [Profile]

    init() {
        let accountProfiles = LocalStore.loadAccounts().map(\.profile)
        profiles = accountProfiles.uniquedByIdentity()
        Task {
            if let remoteProfiles = try? await SupabaseClient.fetchProfiles(), !remoteProfiles.isEmpty {
                profiles = remoteProfiles.uniquedByIdentity()
            }
        }
    }

    func refresh() {
        Task {
            if let remoteProfiles = try? await SupabaseClient.fetchProfiles(), !remoteProfiles.isEmpty {
                profiles = remoteProfiles.uniquedByIdentity()
            }
        }
    }

    func update(_ profile: Profile, syncRemote: Bool = true) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else if let index = profiles.firstIndex(where: { $0.username.lowercased() == profile.username.lowercased() }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        guard syncRemote else { return }
        Task {
            guard let remoteProfile = try? await SupabaseClient.upsertProfile(profile),
                  let index = profiles.firstIndex(where: { $0.id == remoteProfile.id }) else { return }
            var merged = remoteProfile
            merged.email = profile.email
            merged.profilePhotoData = profile.profilePhotoData
            profiles[index] = merged
        }
    }

    func remove(profileID: UUID) {
        profiles.removeAll { $0.id == profileID }
    }
}

@MainActor
final class PostService: ObservableObject {
    @Published var posts: [Post] {
        didSet { LocalStore.savePosts(posts) }
    }

    init() {
        posts = (LocalStore.loadPosts() ?? []).sorted { $0.createdAt > $1.createdAt }
        Task {
            if let remotePosts = try? await SupabaseClient.fetchPosts() {
                posts = remotePosts.sorted { $0.createdAt > $1.createdAt }
            }
        }
    }

    func refresh(profiles: [Profile], comments: [Comment] = []) {
        Task {
            if let remotePosts = try? await SupabaseClient.fetchPosts() {
                posts = remotePosts
                    .map { remotePost in
                        var enriched = enrich(remotePost, profiles: profiles, comments: comments)
                        if let localPost = posts.first(where: { $0.id == remotePost.id }) {
                            enriched.imageData = localPost.imageData
                            enriched.likeCount = localPost.likeCount
                        }
                        return enriched
                    }
                    .sorted { $0.createdAt > $1.createdAt }
            }
        }
    }

    func create(_ post: Post) {
        posts.insert(post, at: 0)
        Task {
            if let remotePost = try? await SupabaseClient.createPost(post),
               let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index] = mergeLocalDisplay(from: post, into: remotePost)
            }
        }
    }

    func delete(_ post: Post, currentUserID: UUID) {
        guard post.userID == currentUserID else { return }
        posts.removeAll { $0.id == post.id }
        Task { try? await SupabaseClient.deletePost(post) }
    }

    func deletePosts(by userID: UUID) {
        posts.removeAll { $0.userID == userID }
    }

    func adjustLike(_ post: Post, liked: Bool) {
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index].likeCount = max(0, posts[index].likeCount + (liked ? 1 : -1))
    }

    func applyLikeCounts(_ counts: [UUID: Int]) {
        for index in posts.indices {
            posts[index].likeCount = counts[posts[index].id] ?? 0
        }
    }

    private func mergeLocalDisplay(from localPost: Post, into remotePost: Post) -> Post {
        var merged = remotePost
        merged.authorUsername = localPost.authorUsername
        merged.imageData = localPost.imageData
        merged.likeCount = localPost.likeCount
        merged.commentCount = localPost.commentCount
        return merged
    }

    private func enrich(_ post: Post, profiles: [Profile], comments: [Comment]) -> Post {
        var enriched = post
        if let profile = profiles.first(where: { $0.id == post.userID }) {
            enriched.authorUsername = profile.username
        }
        enriched.commentCount = comments.filter { $0.postID == post.id }.count
        return enriched
    }
}

@MainActor
final class CommentService: ObservableObject {
    @Published var comments: [Comment] {
        didSet { LocalStore.saveComments(comments) }
    }

    init() {
        comments = LocalStore.loadComments() ?? []
        Task {
            if let remoteComments = try? await SupabaseClient.fetchComments() {
                comments = remoteComments
            }
        }
    }

    func refresh(profiles: [Profile]) {
        Task {
            if let remoteComments = try? await SupabaseClient.fetchComments() {
                comments = remoteComments.map { comment in
                    var enriched = comment
                    if let profile = profiles.first(where: { $0.id == comment.userID }) {
                        enriched.authorUsername = profile.username
                    }
                    if let localComment = comments.first(where: { $0.id == comment.id }) {
                        enriched.imageData = localComment.imageData
                        enriched.likeCount = localComment.likeCount
                    }
                    return enriched
                }
            }
        }
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
        Task {
            if let remoteComment = try? await SupabaseClient.createComment(comment),
               let index = comments.firstIndex(where: { $0.id == comment.id }) {
                var merged = remoteComment
                merged.authorUsername = comment.authorUsername
                merged.imageData = comment.imageData
                merged.likeCount = comment.likeCount
                comments[index] = merged
            }
        }
    }

    func delete(_ comment: Comment, currentUserID: UUID) {
        guard comment.userID == currentUserID else { return }
        comments.removeAll { $0.id == comment.id || $0.parentCommentID == comment.id }
        Task { try? await SupabaseClient.deleteComment(comment) }
    }

    func deleteComments(by userID: UUID) {
        comments.removeAll { $0.userID == userID }
    }

    func adjustLike(_ comment: Comment, liked: Bool) {
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }
        comments[index].likeCount = max(0, comments[index].likeCount + (liked ? 1 : -1))
    }

    func applyLikeCounts(_ counts: [UUID: Int]) {
        for index in comments.indices {
            comments[index].likeCount = counts[comments[index].id] ?? 0
        }
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
    @Published private(set) var connectionsByProfileID: [UUID: [Profile]] = [:]

    init() {
        friends = (LocalStore.loadFriends() ?? [])
            .filter { $0.id != DemoData.currentUserID }
        pendingRequests = (LocalStore.loadPendingRequests() ?? [])
            .filter { $0.senderID != $0.receiverID }
            .filter { $0.senderID != DemoData.currentUserID || $0.receiverID != DemoData.currentUserID }
    }

    func refresh(currentUserID: UUID?, profiles: [Profile]) {
        guard let currentUserID else { return }
        Task {
            let remoteRequests = (try? await SupabaseClient.fetchFriendRequests(currentUserID: currentUserID)) ?? []
            let friendIDs = (try? await SupabaseClient.fetchFriendships(currentUserID: currentUserID)) ?? []
            pendingRequests = remoteRequests
                .filter { $0.status == .pending && $0.senderID != $0.receiverID }
                .filter { $0.senderID == currentUserID || $0.receiverID == currentUserID }
            friends = profiles
                .filter { friendIDs.contains($0.id) && $0.id != currentUserID }
                .uniquedByIdentity()
                .sorted { $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending }
            connectionsByProfileID[currentUserID] = friends
        }
    }

    func refreshConnections(for profileID: UUID, profiles: [Profile]) {
        Task {
            guard let friendIDs = try? await SupabaseClient.fetchFriendships(currentUserID: profileID) else { return }
            connectionsByProfileID[profileID] = profiles
                .filter { friendIDs.contains($0.id) && $0.id != profileID }
                .uniquedByIdentity()
                .sorted { $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending }
        }
    }

    func connections(for profileID: UUID) -> [Profile] {
        connectionsByProfileID[profileID] ?? []
    }

    func isFriend(_ profile: Profile) -> Bool {
        friends.contains { $0.id == profile.id }
    }

    func hasPendingRequest(to profile: Profile) -> Bool {
        pendingRequests.contains { $0.receiverID == profile.id || $0.senderID == profile.id }
    }

    func incomingRequests(for currentUserID: UUID?) -> [FriendRequest] {
        guard let currentUserID else { return [] }
        return pendingRequests.filter {
            $0.status == .pending && $0.receiverID == currentUserID && $0.senderID != currentUserID
        }
    }

    func sendRequest(to profile: Profile, from currentProfile: Profile?) {
        guard !isFriend(profile), !hasPendingRequest(to: profile), let currentProfile, profile.id != currentProfile.id else { return }
        let request = FriendRequest(
            id: UUID(),
            senderID: currentProfile.id,
            receiverID: profile.id,
            senderUsername: currentProfile.username,
            status: .pending,
            createdAt: .now
        )
        pendingRequests.append(request)
        Task {
            do {
                try await SupabaseClient.sendFriendRequest(to: profile.id, senderUsername: currentProfile.username)
            } catch {
                pendingRequests.removeAll { $0.id == request.id }
            }
        }
    }

    func accept(_ request: FriendRequest, profiles: [Profile]) {
        pendingRequests.removeAll { $0.id == request.id }
        guard request.senderID != request.receiverID,
              let profile = profiles.first(where: { $0.id == request.senderID }),
              !isFriend(profile) else { return }
        friends.append(profile)
        Task { try? await SupabaseClient.acceptFriendRequest(request) }
    }

    func reject(_ request: FriendRequest) {
        pendingRequests.removeAll { $0.id == request.id }
        Task { try? await SupabaseClient.rejectFriendRequest(request) }
    }

    func remove(_ profile: Profile) {
        friends.removeAll { $0.id == profile.id }
        connectionsByProfileID = connectionsByProfileID.mapValues { $0.filter { $0.id != profile.id } }
        Task { try? await SupabaseClient.removeFriendship(with: profile.id) }
    }

    func remove(profileID: UUID) {
        friends.removeAll { $0.id == profileID }
        pendingRequests.removeAll { $0.senderID == profileID || $0.receiverID == profileID }
    }

    func removeSelfReferences(currentUserID: UUID?) {
        guard let currentUserID else { return }
        friends.removeAll { $0.id == currentUserID }
        pendingRequests.removeAll { $0.senderID == currentUserID && $0.receiverID == currentUserID }
    }
}

@MainActor
final class SearchService {
    func search(query: String, profiles: [Profile], posts: [Post]) -> (people: [Profile], posts: [Post], companies: [String]) {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let uniqueProfiles = profiles.uniquedByIdentity()
        guard !term.isEmpty else { return (uniqueProfiles, posts, companies(from: posts)) }
        let people = uniqueProfiles.filter { profile in
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

    func posts(for company: String, posts: [Post]) -> [Post] {
        posts.filter { $0.companyOrEmployer?.caseInsensitiveCompare(company) == .orderedSame }
    }
}

@MainActor
final class LikeService: ObservableObject {
    @Published private(set) var incomingLikeNotificationCount = 0
    @Published private(set) var likes: [LikeRow] = []
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

    func refresh(currentUserID: UUID?, postService: PostService, commentService: CommentService) {
        Task {
            guard let remoteLikes = try? await SupabaseClient.fetchLikes() else { return }
            likes = remoteLikes
            let postCounts = Dictionary(grouping: remoteLikes.compactMap(\.postId), by: { $0 }).mapValues(\.count)
            let commentCounts = Dictionary(grouping: remoteLikes.compactMap(\.commentId), by: { $0 }).mapValues(\.count)
            postService.applyLikeCounts(postCounts)
            commentService.applyLikeCounts(commentCounts)
            guard let currentUserID else { return }
            likedPostIDs = Set(remoteLikes.filter { $0.userId == currentUserID }.compactMap(\.postId))
            likedCommentIDs = Set(remoteLikes.filter { $0.userId == currentUserID }.compactMap(\.commentId))
            let myPostIDs = Set(postService.posts.filter { $0.userID == currentUserID }.map(\.id))
            incomingLikeNotificationCount = remoteLikes.filter { like in
                guard let postID = like.postId else { return false }
                return myPostIDs.contains(postID) && like.userId != currentUserID
            }.count
        }
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
            Task { try? await SupabaseClient.deletePostLike(postID: post.id) }
        } else {
            likedPostIDs.insert(post.id)
            postService.adjustLike(post, liked: true)
            Task { try? await SupabaseClient.createPostLike(postID: post.id) }
        }
    }

    func toggleComment(_ comment: Comment, commentService: CommentService) {
        if likedCommentIDs.contains(comment.id) {
            likedCommentIDs.remove(comment.id)
            commentService.adjustLike(comment, liked: false)
            Task { try? await SupabaseClient.deleteCommentLike(commentID: comment.id) }
        } else {
            likedCommentIDs.insert(comment.id)
            commentService.adjustLike(comment, liked: true)
            Task { try? await SupabaseClient.createCommentLike(commentID: comment.id) }
        }
    }
}

@MainActor
final class MessageService: ObservableObject {
    @Published private(set) var errorMessage: String?
    @Published private(set) var sendingProfileIDs: Set<UUID> = []
    @Published private(set) var lastReadAtByProfileID: [UUID: Date] = [:]
    private var isRefreshing = false
    @Published var messages: [ChatMessage] {
        didSet { LocalStore.saveMessages(messages) }
    }

    init() {
        messages = LocalStore.loadMessages()
    }

    func refresh(currentUserID: UUID?) {
        guard let currentUserID, !isRefreshing else { return }
        isRefreshing = true
        Task {
            defer { isRefreshing = false }
            do {
                let snapshot = try await SupabaseClient.fetchMessages(currentUserID: currentUserID)
                messages = (snapshot.messages + messages)
                    .uniquedByMessageID()
                    .sorted { $0.createdAt < $1.createdAt }
                lastReadAtByProfileID.merge(snapshot.lastReadAtByProfileID) { local, remote in
                    max(local, remote)
                }
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func thread(currentUserID: UUID?, friendID: UUID) -> [ChatMessage] {
        guard let currentUserID else { return [] }
        return messages
            .filter { ($0.senderID == currentUserID && $0.receiverID == friendID) || ($0.senderID == friendID && $0.receiverID == currentUserID) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func latestMessage(currentUserID: UUID?, friendID: UUID) -> ChatMessage? {
        thread(currentUserID: currentUserID, friendID: friendID).last
    }

    func unreadCount(currentUserID: UUID?, friendID: UUID) -> Int {
        guard let currentUserID else { return 0 }
        let lastReadAt = lastReadAtByProfileID[friendID] ?? .distantPast
        return thread(currentUserID: currentUserID, friendID: friendID)
            .filter { $0.senderID == friendID && $0.createdAt > lastReadAt }
            .count
    }

    func totalUnreadCount(currentUserID: UUID?) -> Int {
        guard let currentUserID else { return 0 }
        return messages
            .filter { message in
                guard message.receiverID == currentUserID,
                      message.senderID != currentUserID else { return false }
                let lastReadAt = lastReadAtByProfileID[message.senderID] ?? .distantPast
                return message.createdAt > lastReadAt
            }
            .count
    }

    func markRead(profileID: UUID) {
        lastReadAtByProfileID[profileID] = .now
        Task { try? await SupabaseClient.markConversationRead(with: profileID) }
    }

    func isSending(to profileID: UUID) -> Bool {
        sendingProfileIDs.contains(profileID)
    }

    @discardableResult
    func send(to receiver: Profile, from sender: Profile?, body: String, imageData: Data?, sharedPostID: UUID? = nil) async -> Bool {
        guard let sender, !sendingProfileIDs.contains(receiver.id) else { return false }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || imageData != nil || sharedPostID != nil else { return false }
        let pendingMessage = ChatMessage(id: UUID(), senderID: sender.id, receiverID: receiver.id, body: trimmed, imageData: imageData, sharedPostID: sharedPostID, createdAt: .now)
        messages.append(pendingMessage)
        sendingProfileIDs.insert(receiver.id)
        defer { sendingProfileIDs.remove(receiver.id) }
        do {
            let remoteMessage = try await SupabaseClient.sendMessage(pendingMessage)
            messages.removeAll { $0.id == pendingMessage.id }
            messages.append(remoteMessage)
            refresh(currentUserID: sender.id)
            errorMessage = nil
            return true
        } catch {
            messages.removeAll { $0.id == pendingMessage.id }
            errorMessage = error.localizedDescription
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func deleteMessages(involving userID: UUID) {
        messages.removeAll { $0.senderID == userID || $0.receiverID == userID }
    }
}

private extension Array where Element == ChatMessage {
    func uniquedByMessageID() -> [ChatMessage] {
        var seen = Set<UUID>()
        return filter { seen.insert($0.id).inserted }
    }
}

@MainActor
final class StorageService {
    func uploadProfilePhoto() async -> URL? { nil }
    func uploadPostImages() async -> [URL] { [] }
    func uploadCommentImages() async -> [URL] { [] }
}

@MainActor
final class ModerationService: ObservableObject {
    @Published private(set) var reports: [Report] {
        didSet { LocalStore.saveReports(reports) }
    }
    @Published private(set) var blockedUserIDs: Set<UUID> {
        didSet { LocalStore.saveBlockedUsers(blockedUserIDs) }
    }

    init() {
        reports = LocalStore.loadReports()
        blockedUserIDs = LocalStore.loadBlockedUsers()
    }

    func reportPost(_ post: Post, reporterID: UUID?, reason: String) {
        guard let reporterID else { return }
        let report = Report(id: UUID(), reporterID: reporterID, targetType: "post", targetID: post.id, reason: reason, createdAt: .now)
        reports.append(report)
        Task { try? await SupabaseClient.report(report) }
    }

    func reportComment(_ comment: Comment, reporterID: UUID?, reason: String) {
        guard let reporterID else { return }
        let report = Report(id: UUID(), reporterID: reporterID, targetType: "comment", targetID: comment.id, reason: reason, createdAt: .now)
        reports.append(report)
        Task { try? await SupabaseClient.report(report) }
    }

    func reportProfile(_ profile: Profile, reporterID: UUID?, reason: String) {
        guard let reporterID, reporterID != profile.id else { return }
        let report = Report(id: UUID(), reporterID: reporterID, targetType: "profile", targetID: profile.id, reason: reason, createdAt: .now)
        reports.append(report)
        Task { try? await SupabaseClient.report(report) }
    }

    func blockUser(_ profile: Profile, currentUserID: UUID?) {
        guard profile.id != currentUserID else { return }
        blockedUserIDs.insert(profile.id)
        Task { try? await SupabaseClient.block(userID: profile.id) }
    }

    func unblockUser(_ profile: Profile) {
        blockedUserIDs.remove(profile.id)
        Task { try? await SupabaseClient.unblock(userID: profile.id) }
    }

    func isBlocked(_ userID: UUID) -> Bool {
        blockedUserIDs.contains(userID)
    }
}

private extension Array where Element == Profile {
    func uniquedByIdentity() -> [Profile] {
        var seen = Set<UUID>()
        var usernames = Set<String>()
        var emails = Set<String>()
        return filter { profile in
            let username = profile.username.lowercased()
            let email = profile.email?.lowercased()
            guard seen.insert(profile.id).inserted else { return false }
            guard usernames.insert(username).inserted else { return false }
            if let email {
                guard emails.insert(email).inserted else { return false }
            }
            return true
        }
    }
}
