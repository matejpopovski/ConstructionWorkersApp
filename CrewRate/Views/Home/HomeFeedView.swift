import SwiftUI

struct HomeFeedView: View {
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(recommendedPosts) { post in
                        PostCardView(post: post)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Construction Gossip")
            .refreshable {
                session.refreshRemoteData()
            }
            .onAppear {
                session.refreshRemoteData()
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        NotificationsView()
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "hammer.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color.crewOrange, Color.crewNavy)
                            if notificationCount > 0 {
                                Text(notificationCount > 99 ? "99+" : "\(notificationCount)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, notificationCount > 9 ? 4 : 5)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                    NavigationLink {
                        SettingsPrivacyView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }

    private var notificationCount: Int {
        guard let currentUserID = session.currentProfile?.id else {
            return session.friendService.pendingRequests.count
        }
        let myPostIDs = Set(session.postService.posts.filter { $0.userID == currentUserID }.map(\.id))
        let commentNotifications = session.commentService.comments.filter { comment in
            myPostIDs.contains(comment.postID)
                && comment.userID != currentUserID
                && comment.createdAt > Date().addingTimeInterval(-24 * 60 * 60)
        }.count
        return session.friendService.pendingRequests.count + commentNotifications + session.likeService.incomingLikeNotificationCount
    }

    private var recommendedPosts: [Post] {
        let state = session.currentProfile?.state
        return session.postService.posts.filter { post in
            post.userID == session.currentProfile?.id || !session.moderationService.isBlocked(post.userID)
        }.sorted { lhs, rhs in
            let lhsScore = lhs.userID == session.currentProfile?.id ? 2 : (lhs.state == state ? 1 : 0)
            let rhsScore = rhs.userID == session.currentProfile?.id ? 2 : (rhs.state == state ? 1 : 0)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return lhs.createdAt > rhs.createdAt
        }
    }
}

struct PostCardView: View {
    @EnvironmentObject private var session: SessionViewModel
    let post: Post
    @State private var showingReport = false
    @State private var showingShareSheet = false
    @State private var showingFriendShare = false
    @State private var sentToFriendName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                authorHeader
                Spacer()
                Menu {
                    Button("Report", systemImage: "flag") { showingReport = true }
                    if post.userID == session.currentProfile?.id {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            session.postService.delete(post, currentUserID: session.currentProfile?.id ?? post.userID)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }

            if let text = post.textContent, !text.isEmpty {
                Text(text)
                    .font(.body)
            }

            if let firstImageData = post.imageData.first, let image = UIImage(data: firstImageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let imageURL = post.imageURLs.first {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Label("Photo unavailable", systemImage: "photo")
                            .frame(maxWidth: .infinity, minHeight: 180)
                            .background(Color.crewGray)
                    default:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 180)
                            .background(Color.crewGray)
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            badges

            HStack {
                Button {
                    session.likeService.togglePost(post, postService: session.postService)
                } label: {
                    Label("\(post.likeCount)", systemImage: session.likeService.isPostLiked(post) ? "heart.fill" : "heart")
                        .foregroundStyle(session.likeService.isPostLiked(post) ? .red : Color.crewNavy)
                }
                NavigationLink {
                    CommentsView(post: post)
                } label: {
                    Label("\(session.commentService.totalCount(for: post))", systemImage: "bubble.left")
                }
                Button { showingShareSheet = true } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                Button { showingFriendShare = true } label: {
                    Label("Send", systemImage: "person.2")
                }
                Spacer()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.crewNavy)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [shareURL])
        }
        .sheet(isPresented: $showingFriendShare) {
            NavigationStack {
                List {
                    ForEach(session.friendService.friends) { friend in
                        Button {
                            session.messageService.send(to: friend, from: session.currentProfile, body: "Shared a post with you", imageData: nil, sharedPostID: post.id)
                            sentToFriendName = friend.username
                            showingFriendShare = false
                        } label: {
                            HStack(spacing: 12) {
                                ProfileImageView(profile: friend)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(friend.username)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("Send this report")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "paperplane.fill")
                                    .foregroundStyle(Color.crewNavy)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .navigationTitle("Send Post")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showingFriendShare = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .overlay(alignment: .top) {
            if let sentToFriendName {
                Text("Sent to \(sentToFriendName)")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.green)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                            self.sentToFriendName = nil
                        }
                    }
            }
        }
        .confirmationDialog("Report this post", isPresented: $showingReport) {
            Button("Harassment or hate speech", role: .destructive) { session.moderationService.reportPost(post, reporterID: session.currentProfile?.id, reason: "harassment") }
            Button("Private personal information", role: .destructive) { session.moderationService.reportPost(post, reporterID: session.currentProfile?.id, reason: "private_info") }
            Button("False or unsafe claim", role: .destructive) { session.moderationService.reportPost(post, reporterID: session.currentProfile?.id, reason: "unsafe_claim") }
        }
    }

    @ViewBuilder
    private var authorHeader: some View {
        if !post.isAnonymous, let authorProfile {
            NavigationLink {
                PublicProfileView(profile: authorProfile)
            } label: {
                headerContent
            }
            .buttonStyle(.plain)
        } else {
            headerContent
        }
    }

    private var headerContent: some View {
        HStack(alignment: .top, spacing: 10) {
            ProfileImageView(profile: authorProfile, anonymous: post.isAnonymous)
            VStack(alignment: .leading, spacing: 4) {
                Text(post.isAnonymous ? "Anonymous Worker" : post.authorUsername)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(DateDisplay.label(for: post.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var badges: some View {
        FlowLayout {
            if let company = post.companyOrEmployer {
                NavigationLink {
                    CompanyWorkersView(company: company)
                } label: {
                    BadgeView(text: company, systemImage: "building.2")
                }
                .buttonStyle(.plain)
            }
            if let trade = post.tradeLabel {
                NavigationLink {
                    PostAttributeResultsView(title: trade, filter: .job(trade))
                } label: {
                    BadgeView(text: trade, systemImage: "hammer")
                }
                .buttonStyle(.plain)
            }
            if let city = post.city, let state = post.state {
                NavigationLink {
                    PostAttributeResultsView(title: "\(city), \(state)", filter: .location(city: city, state: state))
                } label: {
                    BadgeView(text: "\(city), \(state)", systemImage: "mappin")
                }
                .buttonStyle(.plain)
            }
            if let pay = post.payAmount, let type = post.payType { BadgeView(text: "$\(pay)/\(type.rawValue)", systemImage: "dollarsign.circle") }
            if let averageRating {
                BadgeView(text: "\(averageRating)/5 avg", systemImage: "star.fill")
            }
            if let wouldRecommend = post.wouldRecommend {
                BadgeView(text: wouldRecommend ? "Recommended" : "Not recommended", systemImage: wouldRecommend ? "hand.thumbsup" : "hand.thumbsdown")
            }
        }
    }

    private var authorProfile: Profile? {
        guard !session.moderationService.isBlocked(post.userID) else { return nil }
        return session.profileService.profiles.first { $0.id == post.userID }
    }

    private var shareText: String {
        let company = post.companyOrEmployer ?? "a construction job"
        let text = post.textContent ?? "Check out this construction review."
        let author = post.isAnonymous ? "Anonymous Worker" : post.authorUsername
        return "\(author) on Construction Gossip about \(company): \(text)"
    }

    private var shareURL: URL {
        DeepLink.postURL(for: post)
    }

    private var averageRating: Int? {
        let ratings = [
            post.supervisorFlexibilityRating,
            post.treatmentRating,
            post.safetyRating,
            post.workloadRating,
            post.payFairnessRating
        ].compactMap { $0 }
        guard !ratings.isEmpty else { return nil }
        return Int((Double(ratings.reduce(0, +)) / Double(ratings.count)).rounded())
    }
}

struct FlowLayout<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
            content
        }
    }
}

enum PostAttributeFilter {
    case job(String)
    case location(city: String, state: String)
}

struct PostAttributeResultsView: View {
    @EnvironmentObject private var session: SessionViewModel
    let title: String
    let filter: PostAttributeFilter

    private var posts: [Post] {
        session.postService.posts.filter { post in
            guard post.userID == session.currentProfile?.id || !session.moderationService.isBlocked(post.userID) else { return false }
            switch filter {
            case .job(let job):
                return post.tradeLabel?.caseInsensitiveCompare(job) == .orderedSame
            case .location(let city, let state):
                return post.city?.caseInsensitiveCompare(city) == .orderedSame
                    && post.state?.caseInsensitiveCompare(state) == .orderedSame
            }
        }
    }

    var body: some View {
        List {
            if posts.isEmpty {
                EmptyStateView(title: "No matching reports", systemImage: "doc.text.magnifyingglass")
            } else {
                ForEach(posts) { post in
                    PostCardView(post: post)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }
        }
        .navigationTitle(title)
    }
}
