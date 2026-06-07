import Combine
import Foundation

@MainActor
final class SessionViewModel: ObservableObject {
    @Published var currentProfile: Profile?
    @Published var isAuthenticated = false
    @Published var needsOnboarding = false
    @Published var errorMessage: String?
    @Published var pendingPostID: UUID?
    @Published private(set) var notificationsReadAt = Date.distantPast

    let authService = AuthService()
    let profileService = ProfileService()
    let postService = PostService()
    let commentService = CommentService()
    let friendService = FriendService()
    let messageService = MessageService()
    let searchService = SearchService()
    let likeService = LikeService()
    let storageService = StorageService()
    let moderationService = ModerationService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        authService.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        profileService.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        postService.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        commentService.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        friendService.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        likeService.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        messageService.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        moderationService.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        Task { await restoreSession() }
    }

    func signUp(username: String, email: String, password: String) async {
        do {
            currentProfile = try await authService.signUp(username: username, email: email, password: password)
            loadNotificationReadState()
            if let currentProfile {
                profileService.update(currentProfile)
            }
            isAuthenticated = true
            needsOnboarding = true
            refreshRemoteData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func login(email: String, password: String) async {
        do {
            currentProfile = try await authService.login(email: email, password: password)
            loadNotificationReadState()
            isAuthenticated = true
            needsOnboarding = false
            refreshRemoteData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restoreSession() async {
        do {
            guard let profile = try await authService.restoreSession() else { return }
            currentProfile = profile
            loadNotificationReadState()
            profileService.update(profile)
            isAuthenticated = true
            needsOnboarding = false
            refreshRemoteData()
        } catch {
            authService.signOut()
        }
    }

    func finishOnboarding(profile: Profile) {
        currentProfile = profile
        profileService.update(profile)
        authService.updateAccountProfile(profile)
        needsOnboarding = false
    }

    func updateCurrentProfile(_ profile: Profile) async throws {
        var savedProfile = try await SupabaseClient.upsertProfile(profile)
        savedProfile.email = profile.email
        savedProfile.profilePhotoData = profile.profilePhotoData
        currentProfile = savedProfile
        profileService.update(savedProfile, syncRemote: false)
        authService.updateAccountProfile(savedProfile, syncRemote: false)
    }

    func signOut() {
        authService.signOut()
        currentProfile = nil
        isAuthenticated = false
        needsOnboarding = false
        pendingPostID = nil
    }

    func deleteCurrentAccount() {
        guard let profileID = currentProfile?.id else { return }
        authService.deleteAccount(profileID: profileID)
        profileService.remove(profileID: profileID)
        postService.deletePosts(by: profileID)
        commentService.deleteComments(by: profileID)
        friendService.remove(profileID: profileID)
        messageService.deleteMessages(involving: profileID)
        currentProfile = nil
        isAuthenticated = false
        needsOnboarding = false
        pendingPostID = nil
    }

    func handleDeepLink(_ url: URL) {
        if let postID = DeepLink.postID(from: url) {
            pendingPostID = postID
        }
    }

    func refreshRemoteData() {
        profileService.refresh()
        commentService.refresh(profiles: profileService.profiles)
        postService.refresh(profiles: profileService.profiles, comments: commentService.comments)
        friendService.refresh(currentUserID: currentProfile?.id, profiles: profileService.profiles)
        friendService.removeSelfReferences(currentUserID: currentProfile?.id)
        likeService.refresh(currentUserID: currentProfile?.id, postService: postService, commentService: commentService)
        messageService.refresh(currentUserID: currentProfile?.id)
    }

    var socialNotifications: [SocialNotification] {
        guard let currentUserID = currentProfile?.id else { return [] }
        let profiles = profileService.profiles
        let myPosts = postService.posts.filter { $0.userID == currentUserID }
        let myPostIDs = Set(myPosts.map(\.id))
        let myComments = commentService.comments.filter { $0.userID == currentUserID }
        let myCommentIDs = Set(myComments.map(\.id))
        var items: [SocialNotification] = []

        for request in friendService.incomingRequests(for: currentUserID) {
            items.append(SocialNotification(
                id: "request-\(request.id)",
                text: "\(request.senderUsername) requested to follow you",
                systemImage: "person.crop.circle.badge.plus",
                createdAt: request.createdAt,
                profileID: request.senderID,
                postID: nil
            ))
        }

        for comment in commentService.comments where comment.userID != currentUserID {
            guard let actor = profiles.first(where: { $0.id == comment.userID }) else { continue }
            if let parentID = comment.parentCommentID, myCommentIDs.contains(parentID) {
                items.append(SocialNotification(id: "reply-\(comment.id)", text: "\(actor.username) replied to your comment", systemImage: "arrowshape.turn.up.left.fill", createdAt: comment.createdAt, profileID: actor.id, postID: comment.postID))
            } else if myPostIDs.contains(comment.postID) {
                items.append(SocialNotification(id: "comment-\(comment.id)", text: "\(actor.username) commented on your report", systemImage: "bubble.left.fill", createdAt: comment.createdAt, profileID: actor.id, postID: comment.postID))
            }
        }

        for like in likeService.likes where like.userId != currentUserID {
            guard let actor = profiles.first(where: { $0.id == like.userId }) else { continue }
            if let postID = like.postId, myPostIDs.contains(postID) {
                items.append(SocialNotification(id: "like-\(like.id)", text: "\(actor.username) liked your report", systemImage: "heart.fill", createdAt: like.createdAt ?? .distantPast, profileID: actor.id, postID: postID))
            } else if let commentID = like.commentId, myCommentIDs.contains(commentID),
                      let comment = myComments.first(where: { $0.id == commentID }) {
                let noun = comment.parentCommentID == nil ? "comment" : "reply"
                items.append(SocialNotification(id: "like-\(like.id)", text: "\(actor.username) liked your \(noun)", systemImage: "heart.fill", createdAt: like.createdAt ?? .distantPast, profileID: actor.id, postID: comment.postID))
            }
        }
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    var unreadNotificationCount: Int {
        socialNotifications.filter { $0.createdAt > notificationsReadAt }.count
    }

    func markNotificationsRead() {
        notificationsReadAt = .now
        guard let userID = currentProfile?.id else { return }
        UserDefaults.standard.set(notificationsReadAt, forKey: "notificationsReadAt.\(userID.uuidString)")
    }

    private func loadNotificationReadState() {
        guard let userID = currentProfile?.id else { return }
        notificationsReadAt = UserDefaults.standard.object(forKey: "notificationsReadAt.\(userID.uuidString)") as? Date ?? .distantPast
    }
}

struct SocialNotification: Identifiable {
    let id: String
    let text: String
    let systemImage: String
    let createdAt: Date
    let profileID: UUID?
    let postID: UUID?
}
