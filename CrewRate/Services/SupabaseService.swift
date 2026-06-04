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

    func update(accessToken: String?, userID: UUID?) {
        self.accessToken = accessToken
        self.userID = userID
    }

    func clear() {
        accessToken = nil
        userID = nil
    }

    func token() -> String? {
        accessToken
    }

    func currentUserID() -> UUID? {
        userID
    }
}

enum SupabaseClient {
    private static let session = URLSession.shared

    static func signUp(username: String, email: String, password: String) async throws -> Profile {
        let payload = AuthRequest(email: email, password: password, data: ["username": username])
        let response: AuthResponse = try await request(path: "/auth/v1/signup", method: "POST", body: payload, authorized: false)
        guard let userID = response.user.id else { throw SupabaseError.invalidResponse }
        await SupabaseSessionStore.shared.update(accessToken: response.accessToken, userID: userID)
        let profile = Profile.emptyRemote(id: userID, username: username, email: email)
        return try await upsertProfile(profile)
    }

    static func login(email: String, password: String) async throws -> Profile {
        let payload = AuthRequest(email: email, password: password, data: nil)
        let response: AuthResponse = try await request(path: "/auth/v1/token?grant_type=password", method: "POST", body: payload, authorized: false)
        guard let userID = response.user.id, let accessToken = response.accessToken else { throw SupabaseError.invalidResponse }
        await SupabaseSessionStore.shared.update(accessToken: accessToken, userID: userID)
        return try await fetchProfile(id: userID)
    }

    static func signOut() async {
        await SupabaseSessionStore.shared.clear()
    }

    static func fetchProfiles() async throws -> [Profile] {
        let rows: [ProfileRow] = try await request(path: "/rest/v1/profiles?select=*&order=username.asc", method: "GET", body: OptionalBody.none, authorized: false)
        return rows.map(\.profile)
    }

    static func fetchProfile(id: UUID) async throws -> Profile {
        let rows: [ProfileRow] = try await request(path: "/rest/v1/profiles?id=eq.\(id.uuidString)&select=*&limit=1", method: "GET", body: OptionalBody.none, authorized: true)
        guard let profile = rows.first?.profile else { throw SupabaseError.invalidResponse }
        return profile
    }

    static func upsertProfile(_ profile: Profile) async throws -> Profile {
        let rows: [ProfileRow] = try await request(path: "/rest/v1/profiles?on_conflict=id", method: "POST", body: ProfileRow(profile), authorized: true, prefer: "resolution=merge-duplicates,return=representation")
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

    static func fetchFriendships(currentUserID: UUID) async throws -> [UUID] {
        let rows: [FriendshipRow] = try await request(path: "/rest/v1/friendships?user_id=eq.\(currentUserID.uuidString)&select=friend_id", method: "GET", body: OptionalBody.none, authorized: true)
        return rows.map(\.friendId).filter { $0 != currentUserID }
    }

    static func fetchMessages(currentUserID: UUID) async throws -> [ChatMessage] {
        let memberRows: [ConversationMemberRow] = try await request(path: "/rest/v1/conversation_members?user_id=eq.\(currentUserID.uuidString)&select=conversation_id,user_id", method: "GET", body: OptionalBody.none, authorized: true)
        let conversationIDs = memberRows.map(\.conversationId)
        guard !conversationIDs.isEmpty else { return [] }

        let conversationList = postgrestList(conversationIDs)
        let allMembers: [ConversationMemberRow] = try await request(path: "/rest/v1/conversation_members?conversation_id=in.\(conversationList)&select=conversation_id,user_id", method: "GET", body: OptionalBody.none, authorized: true)
        let messages: [MessageRow] = try await request(path: "/rest/v1/messages?conversation_id=in.\(conversationList)&select=*&order=created_at.asc", method: "GET", body: OptionalBody.none, authorized: true)
        return messages.map { row in
            let members = allMembers.filter { $0.conversationId == row.conversationId }.map(\.userId)
            let otherUserID = members.first { $0 != currentUserID } ?? currentUserID
            let receiverID = row.senderId == currentUserID ? otherUserID : currentUserID
            return row.chatMessage(receiverID: receiverID)
        }
    }

    static func sendMessage(_ message: ChatMessage) async throws -> ChatMessage {
        let conversationID = try await directConversationID(senderID: message.senderID, receiverID: message.receiverID)
        var row = MessageRow(message: message, conversationID: conversationID)
        if let imageData = message.imageData {
            row.imageUrls = try await uploadImages([imageData], bucket: "message-images", prefix: "messages/\(message.id.uuidString)")
        }
        let rows: [MessageRow] = try await request(path: "/rest/v1/messages", method: "POST", body: row, authorized: true, prefer: "return=representation")
        guard let created = rows.first else { throw SupabaseError.invalidResponse }
        return created.chatMessage(receiverID: message.receiverID)
    }

    static func report(_ report: Report) async throws {
        let _: EmptyResponse = try await request(path: "/rest/v1/moderation_flags", method: "POST", body: ReportRow(report), authorized: true)
    }

    static func block(userID: UUID) async throws {
        guard let blockerID = await SupabaseSessionStore.shared.currentUserID() else { throw SupabaseError.missingSession }
        let _: EmptyResponse = try await request(path: "/rest/v1/blocked_users", method: "POST", body: BlockedUserRow(blockerID: blockerID, blockedID: userID), authorized: true)
    }

    static func deleteAccount() async throws {
        guard let userID = await SupabaseSessionStore.shared.currentUserID() else { throw SupabaseError.missingSession }
        let _: EmptyResponse = try await request(path: "/rest/v1/profiles?id=eq.\(userID.uuidString)", method: "DELETE", body: OptionalBody.none, authorized: true)
        await SupabaseSessionStore.shared.clear()
    }

    private static func uploadImages(_ images: [Data], bucket: String, prefix: String) async throws -> [URL] {
        var urls: [URL] = []
        for (index, data) in images.enumerated() {
            let path = "\(prefix)-\(index).jpg"
            let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
            let uploadPath = "/storage/v1/object/\(bucket)/\(encodedPath)"
            let _: EmptyResponse = try await request(path: uploadPath, method: "POST", rawBody: data, contentType: "image/jpeg", authorized: true, prefer: "return=minimal")
            urls.append(SupabaseConfig.projectURL.appending(path: "/storage/v1/object/public/\(bucket)/\(path)"))
        }
        return urls
    }

    private static func directConversationID(senderID: UUID, receiverID: UUID) async throws -> UUID {
        let userIDs = Array(Set([senderID, receiverID]))
        let memberRows: [ConversationMemberRow] = try await request(path: "/rest/v1/conversation_members?user_id=in.\(postgrestList(userIDs))&select=conversation_id,user_id", method: "GET", body: OptionalBody.none, authorized: true)
        let grouped = Dictionary(grouping: memberRows, by: \.conversationId)
        if let existing = grouped.first(where: { _, members in
            let memberIDs = Set(members.map(\.userId))
            return userIDs.allSatisfy { memberIDs.contains($0) }
        })?.key {
            return existing
        }

        let conversations: [ConversationRow] = try await request(path: "/rest/v1/conversations", method: "POST", body: ConversationRow(id: UUID(), title: nil), authorized: true, prefer: "return=representation")
        guard let conversationID = conversations.first?.id else { throw SupabaseError.invalidResponse }
        let _: EmptyResponse = try await request(path: "/rest/v1/conversation_members", method: "POST", body: ConversationMemberInsertRow(conversationId: conversationID, userId: senderID), authorized: true)
        if receiverID != senderID {
            let _: EmptyResponse = try await request(path: "/rest/v1/conversation_members", method: "POST", body: ConversationMemberInsertRow(conversationId: conversationID, userId: receiverID), authorized: true)
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
        prefer: String? = nil
    ) async throws -> Response {
        let data = body is OptionalBody ? nil : try encoder.encode(body)
        return try await request(path: path, method: method, rawBody: data, contentType: "application/json", authorized: authorized, prefer: prefer)
    }

    private static func request<Response: Decodable>(
        path: String,
        method: String,
        rawBody: Data?,
        contentType: String,
        authorized: Bool,
        prefer: String? = nil
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: SupabaseConfig.projectURL) else { throw SupabaseError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }
        if authorized, let token = await SupabaseSessionStore.shared.token() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(SupabaseConfig.publishableKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = rawBody

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw SupabaseError.requestFailed(errorMessage(from: data) ?? "Request failed with status \(httpResponse.statusCode).")
        }
        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }
        return try decoder.decode(Response.self, from: data)
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

private struct AuthResponse: Decodable {
    struct User: Decodable {
        let id: UUID?
        let email: String?
    }

    let accessToken: String?
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
    var streetAddressPrivateOnly: String?
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
        streetAddressPrivateOnly = profile.streetAddressPrivateOnly
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
            streetAddressPrivateOnly: streetAddressPrivateOnly,
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

private struct ConversationMemberRow: Decodable {
    var conversationId: UUID
    var userId: UUID
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
