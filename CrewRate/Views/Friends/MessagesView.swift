import SwiftUI

struct MessagesView: View {
    @EnvironmentObject private var session: SessionViewModel
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Messages") {
                    if conversationProfiles.isEmpty {
                        EmptyStateView(title: "No conversations found", systemImage: "message")
                    } else {
                        ForEach(conversationProfiles) { profile in
                            NavigationLink {
                                ChatView(profile: profile)
                            } label: {
                                HStack(spacing: 12) {
                                    ProfileImageView(profile: profile)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(messageLabel(for: profile))
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(lastMessagePreview(for: profile))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search messages")
            .navigationTitle("Chat")
            .refreshable {
                session.refreshRemoteData()
            }
            .onAppear {
                session.messageService.refresh(currentUserID: session.currentProfile?.id)
            }
        }
    }

    private var conversationProfiles: [Profile] {
        let current = session.currentProfile.map { [$0] } ?? []
        let profiles = (current + session.friendService.friends)
            .filter { $0.id == session.currentProfile?.id || !session.moderationService.isBlocked($0.id) }
            .uniquedByID()
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filteredProfiles = term.isEmpty ? profiles : profiles.filter {
            [$0.username, $0.displayName, $0.tradeLabel].compactMap { $0?.lowercased() }.contains { $0.contains(term) }
        }
        return filteredProfiles.sorted { lhs, rhs in
            let lhsLatest = session.messageService.latestMessage(currentUserID: session.currentProfile?.id, friendID: lhs.id)?.createdAt
            let rhsLatest = session.messageService.latestMessage(currentUserID: session.currentProfile?.id, friendID: rhs.id)?.createdAt
            switch (lhsLatest, rhsLatest) {
            case let (lhsDate?, rhsDate?):
                return lhsDate > rhsDate
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                return lhs.username.localizedCaseInsensitiveCompare(rhs.username) == .orderedAscending
            }
        }
    }

    private func messageLabel(for profile: Profile) -> String {
        profile.id == session.currentProfile?.id ? "\(profile.username) (you)" : profile.username
    }

    private func lastMessagePreview(for profile: Profile) -> String {
        let messages = session.messageService.thread(currentUserID: session.currentProfile?.id, friendID: profile.id)
        guard let last = messages.last else { return "Start a conversation" }
        if let sharedPostID = last.sharedPostID, let post = session.postService.posts.first(where: { $0.id == sharedPostID }) {
            return "Shared post: \(post.companyOrEmployer ?? post.textContent ?? "Construction report")"
        }
        if last.sharedPostID != nil { return "Shared post" }
        if !last.body.isEmpty { return last.body }
        return "Photo"
    }
}

struct NotificationsView: View {
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        List {
            Section("Follow Requests") {
                if session.friendService.pendingRequests.isEmpty {
                    EmptyStateView(title: "No follow requests", systemImage: "hammer")
                } else {
                    ForEach(session.friendService.pendingRequests) { request in
                        HStack {
                            Label(request.senderUsername, systemImage: "person.crop.circle.badge.plus")
                            Spacer()
                            Button("Accept") {
                                session.friendService.accept(request, profiles: session.profileService.profiles)
                            }
                            .buttonStyle(.borderedProminent)
                            Button("Reject") {
                                session.friendService.reject(request)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            Section("Activity") {
                if activityPosts.isEmpty {
                    EmptyStateView(title: "No activity yet", systemImage: "bell")
                } else {
                    ForEach(activityPosts.prefix(10)) { post in
                        NavigationLink {
                            CommentsView(post: post)
                        } label: {
                            Label(notificationText(for: post), systemImage: "hammer.fill")
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .refreshable {
            session.refreshRemoteData()
        }
        .onAppear {
            session.refreshRemoteData()
        }
    }

    private var activityPosts: [Post] {
        let currentUserID = session.currentProfile?.id
        let friendIDs = Set(session.friendService.friends.map(\.id))
        return session.postService.posts.filter { post in
            guard !session.moderationService.isBlocked(post.userID) else { return false }
            return post.userID == currentUserID || friendIDs.contains(post.userID)
        }
    }

    private func notificationText(for post: Post) -> String {
        let author = post.isAnonymous ? "Anonymous Worker" : post.authorUsername
        let company = post.companyOrEmployer ?? "a job"
        return "\(author) posted a report about \(company)"
    }
}

private extension Array where Element == Profile {
    func uniquedByID() -> [Profile] {
        var seen = Set<UUID>()
        return filter { seen.insert($0.id).inserted }
    }
}
