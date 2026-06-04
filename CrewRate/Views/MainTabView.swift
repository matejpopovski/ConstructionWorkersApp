import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        TabView {
            HomeFeedView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            MessagesView()
                .tabItem { Label("Chat", systemImage: "message.fill") }
            CreatePostView()
                .tabItem { Label("Post", systemImage: "plus.circle.fill") }
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            PublicProfileView(profile: nil)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .sheet(item: pendingPostBinding) { post in
            NavigationStack {
                CommentsView(post: post)
            }
        }
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
