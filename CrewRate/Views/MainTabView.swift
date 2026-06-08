import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject private var session: SessionViewModel

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        appearance.shadowColor = UIColor.separator.withAlphaComponent(0.25)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            HomeFeedView()
                .tabItem { Label("Home", systemImage: "house") }
            MessagesView()
                .tabItem { Label("Chat", systemImage: "message") }
                .badge(unreadMessageCount)
            CreatePostView()
                .tabItem { Label("Post", systemImage: "plus.square") }
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            PublicProfileView(profile: nil)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(.crewOrange)
        .sheet(item: pendingPostBinding) { post in
            NavigationStack {
                CommentsView(post: post)
            }
        }
        .task {
            while !Task.isCancelled {
                session.messageService.refresh(currentUserID: session.currentProfile?.id)
                do {
                    try await Task.sleep(for: .seconds(3))
                } catch {
                    return
                }
            }
        }
    }

    private var unreadMessageCount: Int {
        session.messageService.totalUnreadCount(currentUserID: session.currentProfile?.id)
    }

    private var pendingPostBinding: Binding<Post?> {
        Binding(
            get: {
                guard let postID = session.pendingPostID else { return nil }
                return session.postService.posts.first { $0.id == postID }
            },
            set: { post in
                if post == nil {
                    session.pendingPostID = nil
                }
            }
        )
    }
}
