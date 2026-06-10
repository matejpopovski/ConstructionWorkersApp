import Foundation

enum SupabaseConfig {
    static let projectURL = URL(string: "https://vjnlriimrbjpuegjoykb.supabase.co")!
    static let publishableKey = "sb_publishable_oYXv5roa1MW7WqMcil6pbA_jjU9JPSu"
}

enum SupabaseError: LocalizedError {
    case missingSession
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingSession:
            "You need to sign in again."
        case .invalidResponse:
            "The server response could not be read."
        case let .requestFailed(message):
            message
        }
    }
}

actor SupabaseSessionStore {
    static let shared = SupabaseSessionStore()

    private var accessToken: String?
    private var userID: UUID?
    private var refreshToken: String?

    func update(accessToken: String?, refreshToken: String? = nil, userID: UUID?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userID = userID
        if let accessToken {
            SecureSessionStore.save(value: accessToken, account: "accessToken")
        }
        if let refreshToken {
            SecureSessionStore.save(value: refreshToken, account: "refreshToken")
        }
        if let userID {
            SecureSessionStore.save(value: userID.uuidString, account: "userID")
        }
    }

    func clear() {
        accessToken = nil
        refreshToken = nil
        userID = nil
        SecureSessionStore.clearSession()
    }

    func token() -> String? {
        accessToken
    }

    func savedRefreshToken() -> String? {
        refreshToken
    }

    func currentUserID() -> UUID? {
        userID
    }

    func restoreFromKeychain() -> (accessToken: String?, refreshToken: String?, userID: UUID?) {
        let savedAccessToken = SecureSessionStore.read(account: "accessToken")
        let savedRefreshToken = SecureSessionStore.read(account: "refreshToken")
        let savedUserID = SecureSessionStore.read(account: "userID").flatMap(UUID.init(uuidString:))
        accessToken = savedAccessToken
        refreshToken = savedRefreshToken
        userID = savedUserID
        return (savedAccessToken, savedRefreshToken, savedUserID)
    }
}

private actor SupabaseTokenRefreshCoordinator {
    static let shared = SupabaseTokenRefreshCoordinator()
    private var activeRefresh: Task<Bool, Never>?

    func refresh(using operation: @escaping @Sendable () async -> Bool) async -> Bool {
        if let activeRefresh {
            return await activeRefresh.value
        }
        let task = Task { await operation() }
        activeRefresh = task
        let succeeded = await task.value
        activeRefresh = nil
        return succeeded
    }
}

private actor SignedStorageURLCache {
    static let shared = SignedStorageURLCache()

    private struct Entry {
        let url: URL
        let expiresAt: Date
    }

    private var entries: [String: Entry] = [:]

    func url(for key: String) -> URL? {
        guard let entry = entries[key],
              entry.expiresAt.timeIntervalSinceNow > 300 else {
            entries[key] = nil
            return nil
        }
        return entry.url
    }

    func store(_ url: URL, for key: String, lifetime: TimeInterval) {
        entries[key] = Entry(url: url, expiresAt: .now.addingTimeInterval(lifetime))
    }
}

enum SupabaseClient {
    private static let session = URLSession.shared
    private static let signedStorageURLLifetime = 3600

    static func signUp(username: String, email: String, password: String) async throws -> Profile {
        let payload = AuthRequest(email: email, password: password, data: ["username": username])
        let response: AuthResponse = try await request(path: "/auth/v1/signup", method: "POST", body: payload, authorized: false)
        guard let userID = response.user.id else { throw SupabaseError.invalidResponse }
        await SupabaseSessionStore.shared.update(accessToken: response.accessToken, refreshToken: response.refreshToken, userID: userID)
        let profile = Profile.emptyRemote(id: userID, username: username, email: email)
        return try await upsertProfile(profile)
    }

    static func login(email: String, password: String) async throws -> Profile {
        let payload = AuthRequest(email: email, password: password, data: nil)
        let response: AuthResponse = try await request(path: "/auth/v1/token?grant_type=password", method: "POST", body: payload, authorized: false)
        guard let userID = response.user.id, let accessToken = response.accessToken else { throw SupabaseError.invalidResponse }
        await SupabaseSessionStore.shared.update(accessToken: accessToken, refreshToken: response.refreshToken, userID: userID)
        return try await fetchProfile(id: userID)
    }

    static func requestPasswordRecovery(email: String) async throws {
        let _: EmptyResponse = try await request(
            path: "/auth/v1/recover?redirect_to=constructiongossip%3A%2F%2Fauth%2Freset-password",
            method: "POST",
            body: PasswordRecoveryRequest(email: email),
            authorized: false
        )
    }

    static func verifyPasswordRecoveryCode(email: String, code: String) async throws -> String {
        let response: AuthResponse = try await request(
            path: "/auth/v1/verify",
            method: "POST",
            body: PasswordRecoveryVerificationRequest(email: email, token: code, type: "recovery"),
            authorized: false
        )
        guard let accessToken = response.accessToken else {
            throw SupabaseError.invalidResponse
        }
        return accessToken
    }

    static func updatePassword(_ password: String, recoveryAccessToken: String) async throws {
        let _: AuthUserResponse = try await request(
            path: "/auth/v1/user",
            method: "PUT",
            body: PasswordUpdateRequest(password: password),
            authorized: false,
            bearerToken: recoveryAccessToken
        )
    }

    static func restoreSession() async throws -> Profile? {
        let saved = await SupabaseSessionStore.shared.restoreFromKeychain()
        guard let userID = saved.userID else { return nil }
        if saved.accessToken != nil {
            if let profile = try? await fetchProfile(id: userID) {
                return profile
            }
        }
        guard let refreshToken = saved.refreshToken else { return nil }
        let response: AuthResponse = try await request(path: "/auth/v1/token?grant_type=refresh_token", method: "POST", body: RefreshRequest(refreshToken: refreshToken), authorized: false)
        guard let refreshedUserID = response.user.id, let accessToken = response.accessToken else { throw SupabaseError.invalidResponse }
        await SupabaseSessionStore.shared.update(accessToken: accessToken, refreshToken: response.refreshToken ?? refreshToken, userID: refreshedUserID)
        return try await fetchProfile(id: refreshedUserID)
    }

    static func signOut() async {
        await SupabaseSessionStore.shared.clear()
    }

    static func fetchProfiles() async throws -> [Profile] {
        let rows: [ProfileRow] = try await request(path: "/rest/v1/profiles?select=*&order=username.asc", method: "GET", body: OptionalBody.none, authorized: true)
        return rows.map(\.profile)
    }

    static func fetchProfile(id: UUID) async throws -> Profile {
        let rows: [ProfileRow] = try await request(path: "/rest/v1/profiles?id=eq.\(id.uuidString)&select=*&limit=1", method: "GET", body: OptionalBody.none, authorized: true)
        guard let profile = rows.first?.profile else { throw SupabaseError.invalidResponse }
        return profile
    }

    static func upsertProfile(_ profile: Profile) async throws -> Profile {
        var row = ProfileRow(profile)
        if let data = profile.profilePhotoData {
            row.profilePhotoUrl = try await uploadImages([data], bucket: "profile-photos", prefix: "profiles/\(profile.id.uuidString)").first?.absoluteString
        }
        let rows: [ProfileRow] = try await request(path: "/rest/v1/profiles?on_conflict=id", method: "POST", body: row, authorized: true, prefer: "resolution=merge-duplicates,return=representation")
        guard let profile = rows.first?.profile else { throw SupabaseError.invalidResponse }
        return profile
    }

    static func fetchPosts() async throws -> [Post] {
        let rows: [PostRow] = try await request(path: "/rest/v1/posts?select=*&order=created_at.desc", method: "GET", body: OptionalBody.none, authorized: false)
        return rows.map(\.post)
    }

    static func createPost(_ post: Post) async throws -> Post {
        var row = PostRow(post)
        if !post.imageData.isEmpty {
            row.imageUrls = try await uploadImages(post.imageData, bucket: "post-images", prefix: "posts/\(post.id.uuidString)")
        }
        let rows: [PostRow] = try await request(path: "/rest/v1/posts", method: "POST", body: row, authorized: true, prefer: "return=representation")
        guard let created = rows.first?.post else { throw SupabaseError.invalidResponse }
        return created
    }

    static func deletePost(_ post: Post) async throws {
        let _: EmptyResponse = try await request(path: "/rest/v1/posts?id=eq.\(post.id.uuidString)", method: "DELETE", body: OptionalBody.none, authorized: true)
    }

    static func fetchComments() async throws -> [Comment] {
        let rows: [CommentRow] = try await request(path: "/rest/v1/comments?select=*&order=created_at.asc", method: "GET", body: OptionalBody.none, authorized: false)
        return rows.map(\.comment)
    }

    static func createComment(_ comment: Comment) async throws -> Comment {
        var row = CommentRow(comment)
        if !comment.imageData.isEmpty {
            row.imageUrls = try await uploadImages(comment.imageData, bucket: "comment-images", prefix: "comments/\(comment.id.uuidString)")
        }
        let rows: [CommentRow] = try await request(path: "/rest/v1/comments", method: "POST", body: row, authorized: true, prefer: "return=representation")
        guard let created = rows.first?.comment else { throw SupabaseError.invalidResponse }
        return created
    }

    static func deleteComment(_ comment: Comment) async throws {
        let _: EmptyResponse = try await request(
            path: "/rest/v1/comments?id=eq.\(comment.id.uuidString)",
            method: "DELETE",
            body: OptionalBody.none,
            authorized: true
        )
    }

    static func fetchLikes() async throws -> [LikeRow] {
        try await request(path: "/rest/v1/likes?select=*", method: "GET", body: OptionalBody.none, authorized: false)
    }

    static func createPostLike(postID: UUID) async throws {
        guard let userID = await SupabaseSessionStore.shared.currentUserID() else { throw SupabaseError.missingSession }
        let _: EmptyResponse = try await request(path: "/rest/v1/likes?on_conflict=user_id,post_id", method: "POST", body: LikeRow(id: UUID(), userId: userID, postId: postID, commentId: nil, createdAt: nil), authorized: true, prefer: "resolution=ignore-duplicates")
    }

    static func deletePostLike(postID: UUID) async throws {
        guard let userID = await SupabaseSessionStore.shared.currentUserID() else { throw SupabaseError.missingSession }
        let _: EmptyResponse = try await request(path: "/rest/v1/likes?user_id=eq.\(userID.uuidString)&post_id=eq.\(postID.uuidString)", method: "DELETE", body: OptionalBody.none, authorized: true)
    }

    static func createCommentLike(commentID: UUID) async throws {
        guard let userID = await SupabaseSessionStore.shared.currentUserID() else { throw SupabaseError.missingSession }
        let _: EmptyResponse = try await request(path: "/rest/v1/likes?on_conflict=user_id,comment_id", method: "POST", body: LikeRow(id: UUID(), userId: userID, postId: nil, commentId: commentID, createdAt: nil), authorized: true, prefer: "resolution=ignore-duplicates")
    }

    static func deleteCommentLike(commentID: UUID) async throws {
        guard let userID = await SupabaseSessionStore.shared.currentUserID() else { throw SupabaseError.missingSession }
        let _: EmptyResponse = try await request(path: "/rest/v1/likes?user_id=eq.\(userID.uuidString)&comment_id=eq.\(commentID.uuidString)", method: "DELETE", body: OptionalBody.none, authorized: true)
    }

    static func fetchFriendRequests(currentUserID: UUID) async throws -> [FriendRequest] {
        let rows: [FriendRequestRow] = try await request(path: "/rest/v1/friend_requests?or=(sender_id.eq.\(currentUserID.uuidString),receiver_id.eq.\(currentUserID.uuidString))&select=*&order=created_at.desc", method: "GET", body: OptionalBody.none, authorized: true)
        let profiles = try await fetchProfiles()
        return rows.compactMap { $0.friendRequest(profiles: profiles) }
    }

    static func sendFriendRequest(to receiverID: UUID, senderUsername: String) async throws {
        guard let senderID = await SupabaseSessionStore.shared.currentUserID(), senderID != receiverID else { throw SupabaseError.invalidResponse }
        let row = FriendRequestRow(id: UUID(), senderId: senderID, receiverId: receiverID, status: FriendRequestStatus.pending.rawValue, createdAt: .now)
        let _: EmptyResponse = try await request(path: "/rest/v1/friend_requests?on_conflict=sender_id,receiver_id", method: "POST", body: row, authorized: true, prefer: "resolution=ignore-duplicates")
    }

    static func acceptFriendRequest(_ friendRequest: FriendRequest) async throws {
        let _: EmptyResponse = try await request(path: "/rest/v1/friend_requests?id=eq.\(friendRequest.id.uuidString)", method: "PATCH", body: ["status": FriendRequestStatus.accepted.rawValue], authorized: true)
        guard friendRequest.senderID != friendRequest.receiverID else { return }
        let _: EmptyResponse = try await request(path: "/rest/v1/friendships?on_conflict=user_id,friend_id", method: "POST", body: FriendshipRow(id: UUID(), userId: friendRequest.receiverID, friendId: friendRequest.senderID), authorized: true, prefer: "resolution=ignore-duplicates")
        let _: EmptyResponse = try await request(path: "/rest/v1/friendships?on_conflict=user_id,friend_id", method: "POST", body: FriendshipRow(id: UUID(), userId: friendRequest.senderID, friendId: friendRequest.receiverID), authorized: true, prefer: "resolution=ignore-duplicates")
    }

    static func rejectFriendRequest(_ friendRequest: FriendRequest) async throws {
        let _: EmptyResponse = try await request(path: "/rest/v1/friend_requests?id=eq.\(friendRequest.id.uuidString)", method: "PATCH", body: ["status": FriendRequestStatus.rejected.rawValue], authorized: true)
    }

    static func removeFriendship(with profileID: UUID) async throws {
        guard let currentUserID = await SupabaseSessionStore.shared.currentUserID() else {
            throw SupabaseError.missingSession
        }
        let _: EmptyResponse = try await request(path: "/rest/v1/friendships?user_id=eq.\(currentUserID.uuidString)&friend_id=eq.\(profileID.uuidString)", method: "DELETE", body: OptionalBody.none, authorized: true)
        let _: EmptyResponse = try await request(path: "/rest/v1/friendships?user_id=eq.\(profileID.uuidString)&friend_id=eq.\(currentUserID.uuidString)", method: "DELETE", body: OptionalBody.none, authorized: true)
        let _: EmptyResponse = try await request(
            path: "/rest/v1/friend_requests?or=(and(sender_id.eq.\(currentUserID.uuidString),receiver_id.eq.\(profileID.uuidString)),and(sender_id.eq.\(profileID.uuidString),receiver_id.eq.\(currentUserID.uuidString)))",
            method: "DELETE",
            body: OptionalBody.none,
            authorized: true
        )
    }

    static func fetchFriendships(currentUserID: UUID) async throws -> [UUID] {
        let rows: [FriendshipRow] = try await request(path: "/rest/v1/friendships?user_id=eq.\(currentUserID.uuidString)&select=friend_id", method: "GET", body: OptionalBody.none, authorized: true)
        return rows.map(\.friendId).filter { $0 != currentUserID }
    }

    static func fetchMessages(currentUserID: UUID) async throws -> MessageSnapshot {
        let memberRows: [ConversationMemberRow] = try await request(path: "/rest/v1/conversation_members?user_id=eq.\(currentUserID.uuidString)&select=conversation_id,user_id,last_read_at", method: "GET", body: OptionalBody.none, authorized: true)
        let conversationIDs = memberRows.map(\.conversationId)
        guard !conversationIDs.isEmpty else { return MessageSnapshot(messages: [], lastReadAtByProfileID: [:]) }

        let conversationList = postgrestList(conversationIDs)
        let allMembers: [ConversationMemberRow] = try await request(path: "/rest/v1/conversation_members?conversation_id=in.\(conversationList)&select=conversation_id,user_id,last_read_at", method: "GET", body: OptionalBody.none, authorized: true)
        let messages: [MessageRow] = try await request(path: "/rest/v1/messages?conversation_id=in.\(conversationList)&select=*&order=created_at.asc", method: "GET", body: OptionalBody.none, authorized: true)
        var mappedMessages: [ChatMessage] = []
        for row in messages {
            let members = allMembers.filter { $0.conversationId == row.conversationId }.map(\.userId)
            let otherUserID = members.first { $0 != currentUserID } ?? currentUserID
            let receiverID = row.senderId == currentUserID ? otherUserID : currentUserID
            var message = row.chatMessage(receiverID: receiverID)
            message.imageURLs = try await signedMessageImageURLs(row.imageUrls)
            mappedMessages.append(message)
        }
        var lastReadAtByProfileID: [UUID: Date] = [:]
        for membership in memberRows {
            let members = allMembers.filter { $0.conversationId == membership.conversationId }
            let otherUserID = members.first { $0.userId != currentUserID }?.userId ?? currentUserID
            lastReadAtByProfileID[otherUserID] = membership.lastReadAt ?? .distantPast
        }
        return MessageSnapshot(messages: mappedMessages, lastReadAtByProfileID: lastReadAtByProfileID)
    }

    static func markConversationRead(with profileID: UUID) async throws {
        let _: EmptyResponse = try await request(
            path: "/rest/v1/rpc/mark_direct_conversation_read",
            method: "POST",
            body: DirectConversationRequest(otherUserID: profileID),
            authorized: true
        )
    }

    static func sendMessage(_ message: ChatMessage) async throws -> ChatMessage {
        let conversationID = try await directConversationID(senderID: message.senderID, receiverID: message.receiverID)
        var row = MessageRow(message: message, conversationID: conversationID)
        if let imageData = message.imageData {
            row.imageUrls = try await uploadImages(
                [imageData],
                bucket: "message-images",
                prefix: "conversations/\(conversationID.uuidString)/\(message.id.uuidString)",
                isPublic: false
            )
        }
        let rows: [MessageRow] = try await request(path: "/rest/v1/messages", method: "POST", body: row, authorized: true, prefer: "return=representation")
        guard let created = rows.first else { throw SupabaseError.invalidResponse }
        var createdMessage = created.chatMessage(receiverID: message.receiverID)
        createdMessage.imageURLs = try await signedMessageImageURLs(created.imageUrls)
        return createdMessage
    }

    static func report(_ report: Report) async throws {
        let _: EmptyResponse = try await request(path: "/rest/v1/moderation_flags", method: "POST", body: ReportRow(report), authorized: true)
    }

    static func block(userID: UUID) async throws {
        guard let blockerID = await SupabaseSessionStore.shared.currentUserID() else { throw SupabaseError.missingSession }
        let _: EmptyResponse = try await request(path: "/rest/v1/blocked_users", method: "POST", body: BlockedUserRow(blockerID: blockerID, blockedID: userID), authorized: true)
    }

    static func unblock(userID: UUID) async throws {
        guard let blockerID = await SupabaseSessionStore.shared.currentUserID() else { throw SupabaseError.missingSession }
        let _: EmptyResponse = try await request(
            path: "/rest/v1/blocked_users?blocker_id=eq.\(blockerID.uuidString)&blocked_id=eq.\(userID.uuidString)",
            method: "DELETE",
            body: OptionalBody.none,
            authorized: true
        )
    }

    static func deleteAccount() async throws {
        let _: EmptyResponse = try await request(
            path: "/rest/v1/rpc/delete_current_account",
            method: "POST",
            body: OptionalBody.none,
            authorized: true
        )
        await SupabaseSessionStore.shared.clear()
    }

    static func deleteOwnedMedia(urls: [URL]) async throws {
        for url in Set(urls) {
            guard let object = storageObject(from: url) else { continue }
            let objectPath = "\(object.bucket)/\(object.path)"
            let encodedPath = objectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? objectPath
            let _: EmptyResponse = try await request(
                path: "/storage/v1/object/\(encodedPath)",
                method: "DELETE",
                body: OptionalBody.none,
                authorized: true
            )
        }
    }

    private static func uploadImages(_ images: [Data], bucket: String, prefix: String, isPublic: Bool = true) async throws -> [URL] {
        var urls: [URL] = []
        for (index, data) in images.enumerated() {
            let path = "\(prefix)-\(index).jpg"
            let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
            let uploadPath = "/storage/v1/object/\(bucket)/\(encodedPath)"
            let _: EmptyResponse = try await request(
                path: uploadPath,
                method: "POST",
                rawBody: data,
                contentType: "image/jpeg",
                authorized: true,
                prefer: "return=minimal",
                upsertStorageObject: true
            )
            if isPublic {
                urls.append(SupabaseConfig.projectURL.appending(path: "/storage/v1/object/public/\(bucket)/\(path)"))
            } else if let reference = URL(string: "supabase-storage://\(bucket)/\(path)") {
                urls.append(reference)
            } else {
                throw SupabaseError.invalidResponse
            }
        }
        return urls
    }

    private static func signedMessageImageURLs(_ references: [URL]) async throws -> [URL] {
        var urls: [URL] = []
        for reference in references {
            guard let object = storageObject(from: reference),
                  object.bucket == "message-images" else {
                urls.append(reference)
                continue
            }

            let cacheKey = "\(object.bucket)/\(object.path)"
            if let cachedURL = await SignedStorageURLCache.shared.url(for: cacheKey) {
                urls.append(cachedURL)
                continue
            }

            let encodedPath = object.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? object.path
            let response: SignedStorageURLResponse = try await request(
                path: "/storage/v1/object/sign/\(object.bucket)/\(encodedPath)",
                method: "POST",
                rawBody: try JSONSerialization.data(
                    withJSONObject: ["expiresIn": signedStorageURLLifetime]
                ),
                contentType: "application/json",
                authorized: true
            )
            guard let signedURL = resolvedSignedStorageURL(response.signedURL) else {
                throw SupabaseError.invalidResponse
            }
            await SignedStorageURLCache.shared.store(
                signedURL,
                for: cacheKey,
                lifetime: TimeInterval(signedStorageURLLifetime)
            )
            urls.append(signedURL)
        }
        return urls
    }

    private static func storageObject(from url: URL) -> (bucket: String, path: String)? {
        if url.scheme == "supabase-storage",
           let bucket = url.host,
           !bucket.isEmpty {
            return (bucket, String(url.path.drop(while: { $0 == "/" })))
        }

        for marker in ["/storage/v1/object/public/", "/storage/v1/object/sign/"] {
            guard let range = url.path.range(of: marker) else { continue }
            let objectPath = String(url.path[range.upperBound...])
            let components = objectPath.split(separator: "/", maxSplits: 1).map(String.init)
            guard components.count == 2 else { return nil }
            return (components[0], components[1])
        }
        return nil
    }

    private static func resolvedSignedStorageURL(_ value: String) -> URL? {
        if let absoluteURL = URL(string: value), absoluteURL.scheme != nil {
            return absoluteURL
        }
        let path = value.hasPrefix("/storage/v1/")
            ? value
            : "/storage/v1\(value.hasPrefix("/") ? value : "/\(value)")"
        return URL(string: path, relativeTo: SupabaseConfig.projectURL)?.absoluteURL
    }

    private static func directConversationID(senderID: UUID, receiverID: UUID) async throws -> UUID {
        let rows: [ConversationIDRow] = try await request(
            path: "/rest/v1/rpc/get_or_create_direct_conversation",
            method: "POST",
            body: DirectConversationRequest(otherUserID: receiverID),
            authorized: true
        )
        guard let conversationID = rows.first?.getOrCreateDirectConversation else {
            throw SupabaseError.requestFailed("Messaging setup is incomplete. Apply the latest Supabase chat migration.")
        }
        return conversationID
    }

    private static func postgrestList(_ ids: [UUID]) -> String {
        "(\(ids.map(\.uuidString).joined(separator: ",")))"
    }

    private static func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body,
        authorized: Bool,
        prefer: String? = nil,
        bearerToken: String? = nil
    ) async throws -> Response {
        let data = body is OptionalBody ? nil : try encoder.encode(body)
        return try await request(
            path: path,
            method: method,
            rawBody: data,
            contentType: "application/json",
            authorized: authorized,
            prefer: prefer,
            bearerToken: bearerToken
        )
    }

    private static func request<Response: Decodable>(
        path: String,
        method: String,
        rawBody: Data?,
        contentType: String,
        authorized: Bool,
        prefer: String? = nil,
        upsertStorageObject: Bool = false,
        retryAfterRefreshingSession: Bool = true,
        bearerToken: String? = nil
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: SupabaseConfig.projectURL) else { throw SupabaseError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }
        if upsertStorageObject {
            request.setValue("true", forHTTPHeaderField: "x-upsert")
        }
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        } else if authorized, let token = await SupabaseSessionStore.shared.token() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(SupabaseConfig.publishableKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = rawBody

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        if httpResponse.statusCode == 401,
           authorized,
           retryAfterRefreshingSession,
           await refreshAccessToken() {
            return try await self.request(
                path: path,
                method: method,
                rawBody: rawBody,
                contentType: contentType,
                authorized: authorized,
                prefer: prefer,
                upsertStorageObject: upsertStorageObject,
                retryAfterRefreshingSession: false,
                bearerToken: bearerToken
            )
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw SupabaseError.requestFailed(errorMessage(from: data) ?? "Request failed with status \(httpResponse.statusCode).")
        }
        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }
        return try decoder.decode(Response.self, from: data)
    }

    private static func refreshAccessToken() async -> Bool {
        await SupabaseTokenRefreshCoordinator.shared.refresh {
            await performAccessTokenRefresh()
        }
    }

    private static func performAccessTokenRefresh() async -> Bool {
        guard let refreshToken = await SupabaseSessionStore.shared.savedRefreshToken() else {
            return false
        }
        do {
            let response: AuthResponse = try await request(
                path: "/auth/v1/token?grant_type=refresh_token",
                method: "POST",
                body: RefreshRequest(refreshToken: refreshToken),
                authorized: false
            )
            guard let userID = response.user.id,
                  let accessToken = response.accessToken else {
                return false
            }
            await SupabaseSessionStore.shared.update(
                accessToken: accessToken,
                refreshToken: response.refreshToken ?? refreshToken,
                userID: userID
            )
            return true
        } catch {
            return false
        }
    }

    private static func errorMessage(from data: Data) -> String? {
        if let error = try? JSONDecoder().decode(SupabaseAPIError.self, from: data),
           let message = error.displayMessage {
            return message
        }
        return String(data: data, encoding: .utf8)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = iso8601WithFractional.date(from: string) ?? iso8601.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return decoder
    }()

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601 = ISO8601DateFormatter()
}

private struct OptionalBody: Encodable {
    static let none = OptionalBody()
}

private struct EmptyResponse: Decodable {}

private struct SupabaseAPIError: Decodable {
    let message: String?
    let msg: String?
    let error: String?
    let errorDescription: String?

    var displayMessage: String? {
        [message, msg, errorDescription, error]
            .compactMap { value in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed?.isEmpty == false ? trimmed : nil
            }
            .first
    }
}

private struct AuthRequest: Encodable {
    let email: String
    let password: String
    let data: [String: String]?
}

private struct RefreshRequest: Encodable {
    let refreshToken: String
}

private struct PasswordRecoveryRequest: Encodable {
    let email: String
}

private struct PasswordRecoveryVerificationRequest: Encodable {
    let email: String
    let token: String
    let type: String
}

private struct PasswordUpdateRequest: Encodable {
    let password: String
}

private struct SignedStorageURLResponse: Decodable {
    let signedURL: String

    private enum CodingKeys: String, CodingKey {
        case signedURL
    }
}

private struct AuthUserResponse: Decodable {
    let id: UUID?
    let email: String?
}

private struct AuthResponse: Decodable {
    struct User: Decodable {
        let id: UUID?
        let email: String?
    }

    let accessToken: String?
    let refreshToken: String?
    let user: User
}

private struct ProfileRow: Codable {
    var id: UUID
    var username: String
    var firstName: String?
    var lastName: String?
    var profilePhotoUrl: String?
    var state: String?
    var city: String?
    var tradePosition: String?
    var customTradePosition: String?
    var experienceLevel: String?
    var currentCompanyOrEmployer: String?
    var payType: String?
    var payAmount: Decimal?
    var unionStatus: String?
    var yearsExperience: Int?
    var certifications: [String]
    var benefitsReceived: [String]
    var languagesSpoken: [String]
    var bio: String?
    var openToWork: Bool
    var willingToRelocate: Bool
    var showRealName: Bool
    var showCurrentCompany: Bool
    var showPayOnProfile: Bool
    var showCityState: Bool
    var allowFriendRequests: Bool
    var allowMessagesFrom: String
    var createdAt: Date?
    var updatedAt: Date?

    init(_ profile: Profile) {
        id = profile.id
        username = profile.username
        firstName = profile.firstName
        lastName = profile.lastName
        profilePhotoUrl = profile.profilePhotoURL?.absoluteString
        state = profile.state
        city = profile.city
        tradePosition = profile.tradePosition?.rawValue
        customTradePosition = profile.customTradePosition
        experienceLevel = profile.experienceLevel
        currentCompanyOrEmployer = profile.currentCompanyOrEmployer
        payType = profile.payType?.rawValue
        payAmount = profile.payAmount
        unionStatus = profile.unionStatus?.rawValue
        yearsExperience = profile.yearsExperience
        certifications = profile.certifications
        benefitsReceived = profile.benefitsReceived
        languagesSpoken = profile.languagesSpoken
        bio = profile.bio
        openToWork = profile.openToWork
        willingToRelocate = profile.willingToRelocate
        showRealName = profile.showRealName
        showCurrentCompany = profile.showCurrentCompany
        showPayOnProfile = profile.showPayOnProfile
        showCityState = profile.showCityState
        allowFriendRequests = profile.allowFriendRequests
        allowMessagesFrom = profile.allowMessagesFrom.rawValue
        createdAt = profile.id == UUID() ? .now : nil
        updatedAt = .now
    }

    var profile: Profile {
        Profile(
            id: id,
            username: username,
            email: nil,
            firstName: firstName,
            lastName: lastName,
            profilePhotoURL: profilePhotoUrl.flatMap(URL.init(string:)),
            profilePhotoData: nil,
            state: state,
            city: city,
            streetAddressPrivateOnly: nil,
            tradePosition: tradePosition.flatMap(TradePosition.init(rawValue:)),
            customTradePosition: customTradePosition,
            experienceLevel: experienceLevel,
            currentCompanyOrEmployer: currentCompanyOrEmployer,
            payType: payType.flatMap(PayType.init(rawValue:)),
            payAmount: payAmount,
            unionStatus: unionStatus.flatMap(UnionStatus.init(rawValue:)),
            yearsExperience: yearsExperience,
            certifications: certifications,
            benefitsReceived: benefitsReceived,
            languagesSpoken: languagesSpoken,
            bio: bio,
            openToWork: openToWork,
            willingToRelocate: willingToRelocate,
            showRealName: showRealName,
            showCurrentCompany: showCurrentCompany,
            showPayOnProfile: showPayOnProfile,
            showCityState: showCityState,
            allowFriendRequests: allowFriendRequests,
            allowMessagesFrom: AllowMessagesFrom(rawValue: allowMessagesFrom) ?? .friends
        )
    }
}

private struct PostRow: Codable {
    var id: UUID
    var userId: UUID
    var postType: String
    var textContent: String?
    var imageUrls: [URL]
    var isAnonymous: Bool
    var companyOrEmployer: String?
    var tradePosition: String?
    var customTradePosition: String?
    var city: String?
    var state: String?
    var payType: String?
    var payAmount: Decimal?
    var overtimeAvailable: Bool?
    var benefits: [String]
    var supervisorFlexibilityRating: Int?
    var treatmentRating: Int?
    var safetyRating: Int?
    var workloadRating: Int?
    var payFairnessRating: Int?
    var wouldRecommend: Bool?
    var tags: [String]
    var createdAt: Date?
    var updatedAt: Date?

    init(_ post: Post) {
        id = post.id
        userId = post.userID
        postType = post.postType.rawValue
        textContent = post.textContent
        imageUrls = post.imageURLs
        isAnonymous = post.isAnonymous
        companyOrEmployer = post.companyOrEmployer
        tradePosition = post.tradePosition?.rawValue
        customTradePosition = post.customTradePosition
        city = post.city
        state = post.state
        payType = post.payType?.rawValue
        payAmount = post.payAmount
        overtimeAvailable = post.overtimeAvailable
        benefits = post.benefits
        supervisorFlexibilityRating = post.supervisorFlexibilityRating
        treatmentRating = post.treatmentRating
        safetyRating = post.safetyRating
        workloadRating = post.workloadRating
        payFairnessRating = post.payFairnessRating
        wouldRecommend = post.wouldRecommend
        tags = post.tags
        createdAt = post.createdAt
        updatedAt = post.updatedAt
    }

    var post: Post {
        Post(id: id, userID: userId, authorUsername: "", postType: PostType(rawValue: postType) ?? .workReport, textContent: textContent, imageURLs: imageUrls, imageData: [], isAnonymous: isAnonymous, companyOrEmployer: companyOrEmployer, tradePosition: tradePosition.flatMap(TradePosition.init(rawValue:)), customTradePosition: customTradePosition, city: city, state: state, payType: payType.flatMap(PayType.init(rawValue:)), payAmount: payAmount, overtimeAvailable: overtimeAvailable, benefits: benefits, supervisorFlexibilityRating: supervisorFlexibilityRating, treatmentRating: treatmentRating, safetyRating: safetyRating, workloadRating: workloadRating, payFairnessRating: payFairnessRating, wouldRecommend: wouldRecommend, tags: tags, likeCount: 0, commentCount: 0, createdAt: createdAt ?? .now, updatedAt: updatedAt ?? .now)
    }
}

private struct CommentRow: Codable {
    var id: UUID
    var postId: UUID
    var userId: UUID
    var parentCommentId: UUID?
    var textContent: String?
    var imageUrls: [URL]
    var createdAt: Date?
    var updatedAt: Date?

    init(_ comment: Comment) {
        id = comment.id
        postId = comment.postID
        userId = comment.userID
        parentCommentId = comment.parentCommentID
        textContent = comment.textContent
        imageUrls = comment.imageURLs
        createdAt = comment.createdAt
        updatedAt = comment.updatedAt
    }

    var comment: Comment {
        Comment(id: id, postID: postId, userID: userId, parentCommentID: parentCommentId, authorUsername: "", textContent: textContent, imageURLs: imageUrls, imageData: [], likeCount: 0, createdAt: createdAt ?? .now, updatedAt: updatedAt ?? .now)
    }
}

private struct ReportRow: Encodable {
    var reporterId: UUID
    var targetType: String
    var targetId: UUID
    var reason: String

    init(_ report: Report) {
        reporterId = report.reporterID
        targetType = report.targetType
        targetId = report.targetID
        reason = report.reason
    }
}

private struct BlockedUserRow: Encodable {
    var blockerID: UUID
    var blockedID: UUID
}

struct LikeRow: Codable {
    var id: UUID
    var userId: UUID
    var postId: UUID?
    var commentId: UUID?
    var createdAt: Date?
}

private struct FriendRequestRow: Codable {
    var id: UUID
    var senderId: UUID
    var receiverId: UUID
    var status: String
    var createdAt: Date?

    func friendRequest(profiles: [Profile]) -> FriendRequest? {
        guard let status = FriendRequestStatus(rawValue: status) else { return nil }
        let senderUsername = profiles.first { $0.id == senderId }?.username ?? "Worker"
        return FriendRequest(id: id, senderID: senderId, receiverID: receiverId, senderUsername: senderUsername, status: status, createdAt: createdAt ?? .now)
    }
}

private struct FriendshipRow: Codable {
    var id: UUID?
    var userId: UUID?
    var friendId: UUID

    init(id: UUID, userId: UUID, friendId: UUID) {
        self.id = id
        self.userId = userId
        self.friendId = friendId
    }
}

private struct ConversationRow: Codable {
    var id: UUID
    var title: String?
}

private struct DirectConversationRequest: Encodable {
    var otherUserID: UUID
}

private struct ConversationIDRow: Decodable {
    var getOrCreateDirectConversation: UUID
}

struct MessageSnapshot {
    var messages: [ChatMessage]
    var lastReadAtByProfileID: [UUID: Date]
}

private struct ConversationMemberRow: Decodable {
    var conversationId: UUID
    var userId: UUID
    var lastReadAt: Date?
}

private struct ConversationMemberInsertRow: Encodable {
    var conversationId: UUID
    var userId: UUID
}

private struct MessageRow: Codable {
    var id: UUID
    var conversationId: UUID
    var senderId: UUID
    var body: String?
    var imageUrls: [URL]
    var sharedPostId: UUID?
    var createdAt: Date?

    init(message: ChatMessage, conversationID: UUID) {
        id = message.id
        conversationId = conversationID
        senderId = message.senderID
        body = message.body.isEmpty ? nil : message.body
        imageUrls = message.imageURLs
        sharedPostId = message.sharedPostID
        createdAt = message.createdAt
    }

    func chatMessage(receiverID: UUID) -> ChatMessage {
        ChatMessage(id: id, senderID: senderId, receiverID: receiverID, body: body ?? "", imageData: nil, imageURLs: imageUrls, sharedPostID: sharedPostId, createdAt: createdAt ?? .now)
    }
}

private extension Profile {
    static func emptyRemote(id: UUID, username: String, email: String) -> Profile {
        Profile(id: id, username: username, email: email, firstName: nil, lastName: nil, profilePhotoURL: nil, state: nil, city: nil, streetAddressPrivateOnly: nil, tradePosition: nil, experienceLevel: nil, currentCompanyOrEmployer: nil, payType: nil, payAmount: nil, unionStatus: nil, yearsExperience: nil, certifications: [], benefitsReceived: [], languagesSpoken: [], bio: nil, openToWork: false, willingToRelocate: false, showRealName: false, showCurrentCompany: false, showPayOnProfile: false, showCityState: false, allowFriendRequests: true, allowMessagesFrom: .friends)
    }
}
