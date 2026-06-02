import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Pending Requests") {
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
                Section("Friends") {
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
                            Button("Remove", role: .destructive) {
                                session.friendService.remove(friend)
                            }
                        }
                    }
                }
                Section("Messages") {
                    if session.friendService.friends.isEmpty {
                        EmptyStateView(title: "Add friends to message", systemImage: "message")
                    } else {
                        ForEach(session.friendService.friends) { friend in
                            NavigationLink {
                                ChatView(profile: friend)
                            } label: {
                                Label(friend.username, systemImage: "message")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Friends")
        }
    }
}

struct MessagePlaceholderView: View {
    var body: some View {
        ContentUnavailableView("Messages coming soon", systemImage: "message", description: Text("The database schema includes conversation tables for a future real-time chat build."))
            .navigationTitle("Messages")
    }
}
