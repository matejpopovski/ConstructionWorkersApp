import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeFeedView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            CreatePostView()
                .tabItem { Label("Post", systemImage: "plus.circle.fill") }
            FriendsView()
                .tabItem { Label("Friends", systemImage: "person.2.fill") }
            PublicProfileView(profile: nil)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}
