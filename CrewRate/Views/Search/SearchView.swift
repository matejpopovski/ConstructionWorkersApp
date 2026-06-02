import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var session: SessionViewModel
    @State private var query = ""
    @State private var selectedFilter = "All"

    private let filters = ["All", "People", "Posts", "Companies", "Open to Work", "Union"]

    var body: some View {
        NavigationStack {
            let results = session.searchService.search(query: query, profiles: session.profileService.profiles, posts: session.postService.posts)
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(filters, id: \.self) { filter in
                                FilterChip(title: filter, isSelected: selectedFilter == filter) {
                                    selectedFilter = filter
                                }
                            }
                        }
                    }
                }
                if shouldShow("People") {
                    Section("People") {
                        ForEach(filteredPeople(results.people)) { profile in
                            NavigationLink {
                                PublicProfileView(profile: profile)
                            } label: {
                                personRow(profile)
                            }
                        }
                    }
                }
                if shouldShow("Posts") {
                    Section("Posts") {
                        ForEach(results.posts) { post in
                            PostCardView(post: post)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }
                    }
                }
                if shouldShow("Companies") {
                    Section("Companies") {
                        ForEach(results.companies, id: \.self) { company in
                            Label(company, systemImage: "building.2")
                        }
                    }
                }
                if query.isEmpty == false && results.people.isEmpty && results.posts.isEmpty && results.companies.isEmpty {
                    EmptyStateView(title: "No matches", systemImage: "magnifyingglass")
                }
            }
            .searchable(text: $query, prompt: "People, posts, city, company, trade, pay")
            .navigationTitle("Search")
        }
    }

    private func shouldShow(_ section: String) -> Bool {
        selectedFilter == "All" || selectedFilter == section || (selectedFilter == "Open to Work" && section == "People") || (selectedFilter == "Union" && section == "People")
    }

    private func filteredPeople(_ people: [Profile]) -> [Profile] {
        switch selectedFilter {
        case "Open to Work":
            people.filter(\.openToWork)
        case "Union":
            people.filter { $0.unionStatus == .union }
        default:
            people
        }
    }

    private func personRow(_ profile: Profile) -> some View {
        HStack {
            ProfileImageView(profile: profile)
            VStack(alignment: .leading) {
                Text(profile.username).font(.headline)
                Text([profile.tradeLabel, profile.city, profile.state].compactMap { $0 }.joined(separator: " • "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if profile.openToWork {
                BadgeView(text: "Open", systemImage: "briefcase")
            }
        }
    }
}
