import SwiftUI

struct HomeFeedView: View {
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: CrewDesign.Spacing.sm) {
                    CrewSectionHeader(
                        title: "Your crew feed",
                        subtitle: "Recent job reviews and local worker activity"
                    )
                    .padding(.horizontal, CrewDesign.Spacing.xxs)
                    .padding(.bottom, CrewDesign.Spacing.xxs)

                    ForEach(recommendedPosts) { post in
                        PostCardView(post: post)
                    }
                }
                .padding(.horizontal, CrewDesign.Spacing.sm)
                .padding(.top, CrewDesign.Spacing.sm)
                .padding(.bottom, CrewDesign.Spacing.xxl)
            }
            .crewScreenBackground()
            .navigationTitle("Construction Gossip")
            .navigationBarTitleDisplayMode(.inline)
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
                            Image(systemName: "bell")
                                .foregroundStyle(Color.crewNavy)
                            if session.unreadNotificationCount > 0 {
                                Text(session.unreadNotificationCount > 99 ? "99+" : "\(session.unreadNotificationCount)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, session.unreadNotificationCount > 9 ? 4 : 5)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                                    .offset(x: 7, y: -6)
                            }
                        }
                        .frame(width: CrewDesign.Size.iconButton + 8, height: CrewDesign.Size.iconButton + 8)
                    }
                    NavigationLink {
                        ActivityView()
                    } label: {
                        Image(systemName: "bolt")
                            .frame(width: CrewDesign.Size.iconButton, height: CrewDesign.Size.iconButton)
                    }
                }
            }
        }
    }

    private var recommendedPosts: [Post] {
        return session.postService.posts.filter { post in
            post.userID == session.currentProfile?.id || !session.moderationService.isBlocked(post.userID)
        }.sorted { $0.createdAt > $1.createdAt }
    }
}

struct PostCardView: View {
    @EnvironmentObject private var session: SessionViewModel
    let post: Post
    var onCommentTap: (() -> Void)? = nil
    @State private var showingReport = false
    @State private var showingShareSheet = false
    @State private var showingFriendShare = false
    @State private var sentToFriendName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: CrewDesign.Spacing.sm) {
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
                        .frame(width: CrewDesign.Size.iconButton, height: CrewDesign.Size.iconButton)
                        .contentShape(Rectangle())
                }
            }

            if let company = post.companyOrEmployer {
                Text(company)
                    .font(.title3.weight(.bold))
            }

            if let text = post.textContent, !text.isEmpty {
                Text(text)
                    .font(.body)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let firstImageData = livePost.imageData.first, let image = UIImage(data: firstImageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
            } else if let imageURL = livePost.imageURLs.first {
                RemoteImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .background(Color.crewGray)
                } failure: {
                    Label("Photo unavailable", systemImage: "photo")
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .background(Color.crewGray)
                }
                .frame(height: 220)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
            }

            badges

            Divider()

            HStack(spacing: 0) {
                Button {
                    withAnimation(CrewDesign.standardAnimation) {
                        session.likeService.togglePost(post, postService: session.postService)
                    }
                } label: {
                    Label("\(livePost.likeCount)", systemImage: session.likeService.isPostLiked(livePost) ? "heart.fill" : "heart")
                        .foregroundStyle(session.likeService.isPostLiked(post) ? .red : Color.crewNavy)
                        .frame(maxWidth: .infinity)
                }
                if let onCommentTap {
                    Button(action: onCommentTap) {
                        Label("\(session.commentService.totalCount(for: livePost))", systemImage: "bubble.left")
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    NavigationLink {
                        CommentsView(post: livePost, focusComposerOnAppear: true)
                    } label: {
                        Label("\(session.commentService.totalCount(for: livePost))", systemImage: "bubble.left")
                            .frame(maxWidth: .infinity)
                    }
                }
                Button { showingShareSheet = true } label: {
                    Image(systemName: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Share")
                }
                Button { showingFriendShare = true } label: {
                    Image(systemName: "paperplane")
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Send")
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(height: CrewDesign.Size.compactControlHeight)
            .buttonStyle(CrewPressButtonStyle())
            .foregroundStyle(Color.crewNavy)
        }
        .crewCard()
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [AppShareItem(url: shareURL)])
        }
        .sheet(isPresented: $showingFriendShare) {
            NavigationStack {
                List {
                    ForEach(session.friendService.friends) { friend in
                        Button {
                            Task {
                                if await session.messageService.send(to: friend, from: session.currentProfile, body: "Shared a post with you", imageData: nil, sharedPostID: post.id) {
                                    sentToFriendName = friend.username
                                    showingFriendShare = false
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ProfileImageView(profile: friend)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(friend.username)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("Send this review")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "paperplane.fill")
                                    .foregroundStyle(.black)
                                    .frame(width: 34, height: 34)
                                    .background(Color.crewNavy)
                                    .clipShape(Circle())
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
                    .background(Color.crewNavy)
                    .foregroundStyle(.black)
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
        HStack(alignment: .center, spacing: CrewDesign.Spacing.sm) {
            ProfileImageView(profile: authorProfile, anonymous: post.isAnonymous)
            VStack(alignment: .leading, spacing: 2) {
                Text(post.isAnonymous ? "Anonymous Worker" : post.authorUsername)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    Text(metadataLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

    private var livePost: Post {
        session.postService.posts.first(where: { $0.id == post.id }) ?? post
    }

    private var metadataLine: String {
        let date = DateDisplay.label(for: post.createdAt)
        let location = [post.city, post.state].compactMap { $0 }.joined(separator: ", ")
        return location.isEmpty ? date : "\(date) • \(location)"
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: CrewDesign.Spacing.xs)], alignment: .leading, spacing: CrewDesign.Spacing.xs) {
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
                EmptyStateView(title: "No matching reviews", systemImage: "doc.text.magnifyingglass")
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
