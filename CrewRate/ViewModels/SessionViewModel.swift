import Combine
import Foundation

@MainActor
final class SessionViewModel: ObservableObject {
    @Published var currentProfile: Profile?
    @Published var isAuthenticated = false
    @Published var needsOnboarding = false
    @Published var errorMessage: String?

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
    }

    func signUp(username: String, email: String, password: String) async {
        do {
            currentProfile = try await authService.signUp(username: username, email: email, password: password)
            if let currentProfile {
                profileService.update(currentProfile)
            }
            isAuthenticated = true
            needsOnboarding = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func login(email: String, password: String) async {
        do {
            currentProfile = try await authService.login(email: email, password: password)
            isAuthenticated = true
            needsOnboarding = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func finishOnboarding(profile: Profile) {
        currentProfile = profile
        profileService.update(profile)
        authService.updateAccountProfile(profile)
        needsOnboarding = false
    }

    func updateCurrentProfile(_ profile: Profile) {
        currentProfile = profile
        profileService.update(profile)
        authService.updateAccountProfile(profile)
    }

    func signOut() {
        authService.signOut()
        currentProfile = nil
        isAuthenticated = false
        needsOnboarding = false
    }
}
