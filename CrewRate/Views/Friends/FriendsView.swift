import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var session: SessionViewModel
    @State private var conversationQuery = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Pending Follow Requests") {
                    if session.friendService.pendingRequests.isEmpty {
                        EmptyStateView(title: "No pending requests", systemImage: "person.badge.clock")
                    } else {
                        ForEach(session.friendService.pendingRequests) { request in
                            HStack {
                                Label(request.senderUsername, systemImage: "person.crop.circle")
                                Spacer()
                                Button("Accept") { session.friendService.accept(request, profiles: session.profileService.profiles) }
                                    .buttonStyle(.borderedProminent)
                                Button("Reject") { session.friendService.reject(request) }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                Section("Following") {
                    ForEach(session.friendService.friends) { friend in
                        NavigationLink {
                            PublicProfileView(profile: friend)
                        } label: {
                            HStack {
                                ProfileImageView(profile: friend)
                                VStack(alignment: .leading) {
                                    Text(friend.username).font(.headline)
                                    Text(friend.tradeLabel ?? "Worker")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions {
                            Button("Unfollow", role: .destructive) {
                                session.friendService.remove(friend)
                            }
                        }
                    }
                }
                Section("Messages") {
                    if conversationProfiles.isEmpty {
                        EmptyStateView(title: "No conversations found", systemImage: "message")
                    } else {
                        ForEach(conversationProfiles) { profile in
                            NavigationLink {
                                ChatView(profile: profile)
                            } label: {
                                Label(messageLabel(for: profile), systemImage: profile.id == session.currentProfile?.id ? "person.crop.circle" : "message")
                            }
                        }
                    }
                }
            }
            .searchable(text: $conversationQuery, prompt: "Search conversations")
            .navigationTitle("Connections")
        }
    }

    private var conversationProfiles: [Profile] {
        let current = session.currentProfile.map { [$0] } ?? []
        let profiles = (current + session.friendService.friends).uniquedByID()
        let term = conversationQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return profiles }
        return profiles.filter {
            [$0.username, $0.displayName, $0.tradeLabel].compactMap { $0?.lowercased() }.contains { $0.contains(term) }
        }
    }

    private func messageLabel(for profile: Profile) -> String {
        profile.id == session.currentProfile?.id ? "\(profile.username) (you)" : profile.username
    }
}

struct MessagePlaceholderView: View {
    var body: some View {
        ContentUnavailableView("Messages coming soon", systemImage: "message", description: Text("The database schema includes conversation tables for a future real-time chat build."))
            .navigationTitle("Messages")
    }
}

private extension Array where Element == Profile {
    func uniquedByID() -> [Profile] {
        var seen = Set<UUID>()
        return filter { seen.insert($0.id).inserted }
    }
}
