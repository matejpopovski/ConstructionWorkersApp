import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var session: SessionViewModel
    @State private var query = ""
    @State private var selectedFilter = "All"

    private let filters = ["All", "Workers", "Job Reports", "Companies", "Open to Work", "Union"]

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
                if selectedFilter == "Union" {
                    Section {
                        Text("Union shows workers who marked their optional union status as union. It is a filter for workplace context, not a hiring category.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if shouldShow("Workers") {
                    Section("Workers") {
                        ForEach(filteredPeople(results.people)) { profile in
                            NavigationLink {
                                PublicProfileView(profile: profile)
                            } label: {
                                personRow(profile)
                            }
                        }
                    }
                }
                if shouldShow("Job Reports") {
                    Section("Job Reports") {
                        ForEach(results.posts) { post in
                            PostCardView(post: post)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }
                    }
                }
                if shouldShow("Companies") {
                    Section("Companies") {
                        ForEach(results.companies, id: \.self) { company in
                            NavigationLink {
                                CompanyWorkersView(company: company)
                            } label: {
                                Label(company, systemImage: "building.2")
                            }
                        }
                    }
                }
                if query.isEmpty == false && results.people.isEmpty && results.posts.isEmpty && results.companies.isEmpty {
                    EmptyStateView(title: "No matches", systemImage: "magnifyingglass")
                }
            }
            .searchable(text: $query, prompt: "Workers, reports, city, company, job, pay")
            .navigationTitle("Search")
        }
    }

    private func shouldShow(_ section: String) -> Bool {
        selectedFilter == "All" || selectedFilter == section || (selectedFilter == "Open to Work" && section == "Workers") || (selectedFilter == "Union" && section == "Workers")
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

struct CompanyWorkersView: View {
    @EnvironmentObject private var session: SessionViewModel
    let company: String

    private var companyPosts: [Post] {
        session.searchService.posts(for: company, posts: session.postService.posts)
    }

    private var workers: [Profile] {
        let workerIDs = Set(companyPosts.filter { !$0.isAnonymous || $0.userID == session.currentProfile?.id }.map(\.userID))
        return session.profileService.profiles
            .filter { workerIDs.contains($0.id) }
            .sorted { $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending }
    }

    var body: some View {
        List {
            Section("Workers") {
                if workers.isEmpty {
                    EmptyStateView(title: "No workers yet", systemImage: "person.3")
                } else {
                    ForEach(workers) { worker in
                        NavigationLink {
                            PublicProfileView(profile: worker)
                        } label: {
                            HStack {
                                ProfileImageView(profile: worker)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(worker.username)
                                        .font(.headline)
                                    Text([worker.tradeLabel, worker.city, worker.state].compactMap { $0 }.joined(separator: " • "))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Section("Reviews") {
                if companyPosts.isEmpty {
                    EmptyStateView(title: "No reviews yet", systemImage: "doc.text.magnifyingglass")
                } else {
                    ForEach(companyPosts) { post in
                        PostCardView(post: post)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                }
            }
        }
        .navigationTitle(company)
    }
}
