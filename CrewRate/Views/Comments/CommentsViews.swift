import PhotosUI
import SwiftUI
import UIKit

struct CommentsView: View {
    @EnvironmentObject private var session: SessionViewModel
    let post: Post
    @State private var commentText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var photoErrorMessage: String?

    var body: some View {
        List {
            Section {
                PostCardView(post: post)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section("Comments") {
                let comments = session.commentService.comments(for: post)
                if comments.isEmpty {
                    EmptyStateView(title: "No comments yet", systemImage: "bubble.left")
                } else {
                    ForEach(comments) { comment in
                        CommentRowView(comment: comment, post: post)
                    }
                }
            }
            Section("Add Comment") {
                TextField("Write a comment", text: $commentText, axis: .vertical)
                ImagePicker(selectedItem: $selectedPhoto)
                if let selectedPhotoData, let image = UIImage(data: selectedPhotoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if let photoErrorMessage {
                    ErrorView(message: photoErrorMessage)
                }
                Button("Comment") { addComment(parent: nil) }
            }
        }
        .navigationTitle("Discussion")
        .onChange(of: selectedPhoto) { _, newItem in
            Task { await loadSelectedPhoto(newItem) }
        }
    }

    private func addComment(parent: Comment?) {
        guard let profile = session.currentProfile ?? session.profileService.profiles.first else { return }
        let imageData = selectedPhotoData.map { [$0] } ?? []
        let comment = Comment(id: UUID(), postID: post.id, userID: profile.id, parentCommentID: parent?.id, authorUsername: profile.username, textContent: commentText.isEmpty ? nil : commentText, imageURLs: [], imageData: imageData, likeCount: 0, createdAt: .now, updatedAt: .now)
        session.commentService.add(comment)
        commentText = ""
        selectedPhoto = nil
        selectedPhotoData = nil
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) async {
        photoErrorMessage = nil
        selectedPhotoData = nil
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), UIImage(data: data) != nil else {
                photoErrorMessage = "That photo could not be loaded."
                return
            }
            selectedPhotoData = data
        } catch {
            photoErrorMessage = "Photo attach failed. Please try another image."
        }
    }
}

struct CommentRowView: View {
    @EnvironmentObject private var session: SessionViewModel
    let comment: Comment
    let post: Post
    @State private var replyText = ""
    @State private var showingReply = false
    @State private var showingReport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ProfileImageView(profile: authorProfile, size: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(comment.authorUsername).font(.subheadline.bold())
                    Text(comment.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Report", systemImage: "flag") { showingReport = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
            if let text = comment.textContent {
                Text(text)
            }
            if let firstImageData = comment.imageData.first, let image = UIImage(data: firstImageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            HStack {
                Button {
                    session.likeService.toggleComment(comment, commentService: session.commentService)
                } label: {
                    Label("\(comment.likeCount)", systemImage: session.likeService.isCommentLiked(comment) ? "heart.fill" : "heart")
                        .foregroundStyle(session.likeService.isCommentLiked(comment) ? .red : Color.crewNavy)
                }
                Button {
                    showingReply.toggle()
                } label: {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                }
            }
            .buttonStyle(.borderless)
            if showingReply {
                HStack {
                    TextField("@\(comment.authorUsername)", text: $replyText)
                    Button("Send") { addReply() }
                }
            }
            ForEach(session.commentService.replies(to: comment)) { reply in
                ReplyRowView(reply: reply, parentUsername: comment.authorUsername)
            }
        }
        .confirmationDialog("Report this comment", isPresented: $showingReport) {
            Button("Harassment or hate speech", role: .destructive) { session.moderationService.reportComment(comment, reason: "harassment") }
            Button("Private personal information", role: .destructive) { session.moderationService.reportComment(comment, reason: "private_info") }
        }
    }

    private func addReply() {
        guard let profile = session.currentProfile ?? session.profileService.profiles.first else { return }
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = trimmed.hasPrefix("@") ? trimmed : "@\(comment.authorUsername) \(trimmed)"
        let reply = Comment(id: UUID(), postID: post.id, userID: profile.id, parentCommentID: comment.id, authorUsername: profile.username, textContent: body, imageURLs: [], imageData: [], likeCount: 0, createdAt: .now, updatedAt: .now)
        session.commentService.add(reply)
        replyText = ""
        showingReply = false
    }

    private var authorProfile: Profile? {
        session.profileService.profiles.first { $0.id == comment.userID }
    }
}

struct ReplyRowView: View {
    @EnvironmentObject private var session: SessionViewModel
    let reply: Comment
    let parentUsername: String

    var body: some View {
        HStack(alignment: .top) {
            Rectangle().fill(Color.crewGray).frame(width: 3)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(reply.authorUsername).font(.caption.bold())
                    Text("@\(parentUsername)").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        session.likeService.toggleComment(reply, commentService: session.commentService)
                    } label: {
                        Label("\(reply.likeCount)", systemImage: session.likeService.isCommentLiked(reply) ? "heart.fill" : "heart")
                            .foregroundStyle(session.likeService.isCommentLiked(reply) ? .red : Color.crewNavy)
                    }
                    .buttonStyle(.borderless)
                }
                Text(reply.textContent ?? "@\(parentUsername)")
                    .font(.subheadline)
            }
        }
        .padding(.leading, 28)
    }
}
