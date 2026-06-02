import SwiftUI

struct MainTabView: View {
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
    }
}
