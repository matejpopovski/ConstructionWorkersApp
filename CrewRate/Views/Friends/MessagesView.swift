import SwiftUI

struct MessagesView: View {
    @EnvironmentObject private var session: SessionViewModel
    @State private var query = ""
    @State private var profileDestination: Profile?

    var body: some View {
        NavigationStack {
            List {
                Section("Messages") {
                    if conversationProfiles.isEmpty {
                        EmptyStateView(title: "No conversations found", systemImage: "message")
                    } else {
                        ForEach(conversationProfiles) { profile in
                            HStack(spacing: CrewDesign.Spacing.sm) {
                                Button {
                                    profileDestination = profile
                                } label: {
                                    ProfileImageView(profile: profile, size: 52)
                                }
                                .buttonStyle(CrewPressButtonStyle())
                                .accessibilityLabel("Open \(profile.username)'s profile")

                                NavigationLink {
                                    ChatView(profile: profile)
                                } label: {
                                    HStack(spacing: CrewDesign.Spacing.sm) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(messageLabel(for: profile))
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.primary)
                                        Text(lastMessagePreview(for: profile))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if let date = session.messageService.latestMessage(currentUserID: session.currentProfile?.id, friendID: profile.id)?.createdAt {
                                        Text(DateDisplay.label(for: date))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, CrewDesign.Spacing.xxs)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search messages")
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.crewCanvas)
            .refreshable {
                session.refreshRemoteData()
            }
            .onAppear {
                session.messageService.refresh(currentUserID: session.currentProfile?.id)
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3))
                    session.messageService.refresh(currentUserID: session.currentProfile?.id)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { profileDestination != nil },
                set: { if !$0 { profileDestination = nil } }
            )) {
                if let profileDestination {
                    PublicProfileView(profile: profileDestination)
                }
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
            Section {
                NavigationLink {
                    FollowRequestsView()
                } label: {
                    HStack {
                        Label("Follow requests", systemImage: "person.2.badge.plus")
                        Spacer()
                        if !incomingRequests.isEmpty {
                            Text("\(incomingRequests.count)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            Section("Notifications") {
                if session.socialNotifications.isEmpty {
                    EmptyStateView(title: "No notifications yet", systemImage: "bell")
                } else {
                    ForEach(session.socialNotifications) { notification in
                        notificationRow(notification)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .refreshable {
            session.refreshRemoteData()
        }
        .onAppear {
            session.refreshRemoteData()
            session.markNotificationsRead()
        }
    }

    private var incomingRequests: [FriendRequest] {
        session.friendService.incomingRequests(for: session.currentProfile?.id)
    }

    @ViewBuilder
    private func notificationRow(_ notification: SocialNotification) -> some View {
        if let postID = notification.postID,
           let post = session.postService.posts.first(where: { $0.id == postID }) {
            NavigationLink {
                CommentsView(post: post)
            } label: {
                notificationLabel(notification)
            }
        } else if let profileID = notification.profileID,
                  let profile = session.profileService.profiles.first(where: { $0.id == profileID }) {
            NavigationLink {
                PublicProfileView(profile: profile)
            } label: {
                notificationLabel(notification)
            }
        } else {
            notificationLabel(notification)
        }
    }

    private func notificationLabel(_ notification: SocialNotification) -> some View {
        HStack(spacing: CrewDesign.Spacing.sm) {
            Image(systemName: notification.systemImage)
                .foregroundStyle(notification.systemImage == "heart.fill" ? .red : Color.crewOrange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(notification.text).font(.subheadline)
                Text(notification.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct FollowRequestsView: View {
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        List(incomingRequests) { request in
            HStack {
                Text(request.senderUsername).font(.headline)
                Spacer()
                Button("Confirm") {
                    session.friendService.accept(request, profiles: session.profileService.profiles)
                }
                .buttonStyle(.borderedProminent)
                Button("Decline") {
                    session.friendService.reject(request)
                }
                .buttonStyle(.bordered)
            }
        }
        .overlay {
            if incomingRequests.isEmpty {
                EmptyStateView(title: "No follow requests", systemImage: "person.2")
            }
        }
        .navigationTitle("Follow Requests")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var incomingRequests: [FriendRequest] {
        session.friendService.incomingRequests(for: session.currentProfile?.id)
    }
}

struct ActivityView: View {
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        List(activityPosts) { post in
            NavigationLink {
                CommentsView(post: post)
            } label: {
                Label(notificationText(for: post), systemImage: "hammer.fill")
                    .font(.subheadline)
            }
        }
        .overlay {
            if activityPosts.isEmpty {
                EmptyStateView(title: "No activity yet", systemImage: "bolt")
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { session.refreshRemoteData() }
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
        let author = post.userID == session.currentProfile?.id ? "You" : (post.isAnonymous ? "Anonymous Worker" : post.authorUsername)
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
