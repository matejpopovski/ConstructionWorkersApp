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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsPrivacyView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }

    private var recommendedPosts: [Post] {
        let state = session.currentProfile?.state
        return session.postService.posts.sorted { lhs, rhs in
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
                ProfileImageView(profile: authorProfile, anonymous: post.isAnonymous)
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.isAnonymous ? "Anonymous Worker" : post.authorUsername)
                        .font(.headline)
                    Text(DateDisplay.label(for: post.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Report", systemImage: "flag") { showingReport = true }
                    if post.userID == session.currentProfile?.id {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            session.postService.delete(post, currentUserID: post.userID)
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
            } else if !post.imageURLs.isEmpty {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.crewGray)
                    .frame(height: 180)
                    .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary))
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
            ShareSheet(activityItems: [shareText])
        }
        .sheet(isPresented: $showingFriendShare) {
            NavigationStack {
                List {
                    ForEach(session.friendService.friends) { friend in
                        Button {
                            session.messageService.send(to: friend, from: session.currentProfile, body: shareText, imageData: post.imageData.first)
                            sentToFriendName = friend.username
                            showingFriendShare = false
                        } label: {
                            Label(friend.username, systemImage: "person.crop.circle")
                        }
                    }
                }
                .navigationTitle("Send to Friend")
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
            Button("Harassment or hate speech", role: .destructive) { session.moderationService.reportPost(post, reason: "harassment") }
            Button("Private personal information", role: .destructive) { session.moderationService.reportPost(post, reason: "private_info") }
            Button("False or unsafe claim", role: .destructive) { session.moderationService.reportPost(post, reason: "unsafe_claim") }
        }
    }

    private var badges: some View {
        FlowLayout {
            if let company = post.companyOrEmployer { BadgeView(text: company, systemImage: "building.2") }
            if let trade = post.tradeLabel { BadgeView(text: trade, systemImage: "hammer") }
            if let city = post.city, let state = post.state { BadgeView(text: "\(city), \(state)", systemImage: "mappin") }
            if let pay = post.payAmount, let type = post.payType { BadgeView(text: "$\(pay)/\(type.rawValue)", systemImage: "dollarsign.circle") }
        }
    }

    private var authorProfile: Profile? {
        session.profileService.profiles.first { $0.id == post.userID }
    }

    private var shareText: String {
        let company = post.companyOrEmployer ?? "a construction job"
        let text = post.textContent ?? "Check out this construction review."
        return "\(post.authorUsername) on Construction Gossip about \(company): \(text)"
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
