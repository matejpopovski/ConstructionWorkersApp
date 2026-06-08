import PhotosUI
import SwiftUI
import UIKit

struct CommentsView: View {
    @EnvironmentObject private var session: SessionViewModel
    let post: Post
    var focusComposerOnAppear = false
    @State private var commentText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var photoErrorMessage: String?
    @FocusState private var isCommentFieldFocused: Bool

    var body: some View {
        List {
            Section {
                PostCardView(post: post) {
                    isCommentFieldFocused = true
                }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section("Comments") {
                let comments = session.commentService.comments(for: post).filter { !session.moderationService.isBlocked($0.userID) }
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
                    .focused($isCommentFieldFocused)
                ImagePicker(selectedItem: $selectedPhoto)
                if let selectedPhotoData, let image = UIImage(data: selectedPhotoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 140)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
                }
                if let photoErrorMessage {
                    ErrorView(message: photoErrorMessage)
                }
                Button("Comment") { addComment(parent: nil) }
                    .buttonStyle(CrewPrimaryButtonStyle())
                    .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedPhotoData == nil)
            }
        }
        .navigationTitle("Discussion")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.crewCanvas)
        .refreshable {
            session.refreshRemoteData()
        }
        .onAppear {
            session.refreshRemoteData()
            if focusComposerOnAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isCommentFieldFocused = true
                }
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task { await loadSelectedPhoto(newItem) }
        }
    }

    private func addComment(parent: Comment?) {
        guard let profile = session.currentProfile ?? session.profileService.profiles.first else { return }
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || selectedPhotoData != nil else { return }
        let imageData = selectedPhotoData.map { [$0] } ?? []
        let comment = Comment(id: UUID(), postID: post.id, userID: profile.id, parentCommentID: parent?.id, authorUsername: profile.username, textContent: trimmed.isEmpty ? nil : trimmed, imageURLs: [], imageData: imageData, likeCount: 0, createdAt: .now, updatedAt: .now)
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
            guard let data = try await item.loadTransferable(type: Data.self),
                  let optimizedData = ImageOptimizer.optimizedJPEGData(from: data, preset: .message) else {
                photoErrorMessage = "That photo could not be loaded."
                return
            }
            selectedPhotoData = optimizedData
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
        VStack(alignment: .leading, spacing: CrewDesign.Spacing.sm) {
            HStack(alignment: .top) {
                ProfileImageView(profile: authorProfile, size: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(comment.authorUsername).font(.subheadline.bold())
                    Text(comment.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    if comment.userID == session.currentProfile?.id {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            guard let currentUserID = session.currentProfile?.id else { return }
                            session.commentService.delete(comment, currentUserID: currentUserID)
                        }
                    } else {
                        Button("Report", systemImage: "flag") { showingReport = true }
                    }
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
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
            } else if let imageURL = comment.imageURLs.first {
                RemoteImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .background(Color.crewGray)
                } failure: {
                    Label("Photo unavailable", systemImage: "photo")
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .background(Color.crewGray)
                }
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            HStack {
                Button {
                    withAnimation(CrewDesign.standardAnimation) {
                        session.likeService.toggleComment(comment, commentService: session.commentService)
                    }
                } label: {
                    Label("\(liveComment.likeCount)", systemImage: session.likeService.isCommentLiked(liveComment) ? "heart.fill" : "heart")
                        .foregroundStyle(session.likeService.isCommentLiked(liveComment) ? .red : Color.crewNavy)
                }
                Button {
                    showingReply.toggle()
                } label: {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                }
            }
            .buttonStyle(.borderless)
            if showingReply {
                HStack(spacing: CrewDesign.Spacing.xs) {
                    TextField("@\(comment.authorUsername)", text: $replyText)
                        .padding(.horizontal, CrewDesign.Spacing.sm)
                        .frame(minHeight: CrewDesign.Size.compactControlHeight)
                        .background(Color.crewGray)
                        .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
                    Button { addReply() } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .buttonStyle(CrewIconButtonStyle())
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            ForEach(session.commentService.replies(to: comment).filter { !session.moderationService.isBlocked($0.userID) }) { reply in
                ReplyRowView(reply: reply, parentUsername: comment.authorUsername)
            }
        }
        .confirmationDialog("Report this comment", isPresented: $showingReport) {
            Button("Harassment or hate speech", role: .destructive) { session.moderationService.reportComment(comment, reporterID: session.currentProfile?.id, reason: "harassment") }
            Button("Private personal information", role: .destructive) { session.moderationService.reportComment(comment, reporterID: session.currentProfile?.id, reason: "private_info") }
        }
    }

    private func addReply() {
        guard let profile = session.currentProfile ?? session.profileService.profiles.first else { return }
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showingReply = false
            return
        }
        let body = trimmed.hasPrefix("@") ? trimmed : "@\(comment.authorUsername) \(trimmed)"
        let reply = Comment(id: UUID(), postID: post.id, userID: profile.id, parentCommentID: comment.id, authorUsername: profile.username, textContent: body, imageURLs: [], imageData: [], likeCount: 0, createdAt: .now, updatedAt: .now)
        session.commentService.add(reply)
        replyText = ""
        showingReply = false
    }

    private var authorProfile: Profile? {
        session.profileService.profiles.first { $0.id == comment.userID }
    }

    private var liveComment: Comment {
        session.commentService.comments.first(where: { $0.id == comment.id }) ?? comment
    }
}

struct ReplyRowView: View {
    @EnvironmentObject private var session: SessionViewModel
    let reply: Comment
    let parentUsername: String
    @State private var showingReport = false

    var body: some View {
        HStack(alignment: .top) {
            Rectangle().fill(Color.crewGray).frame(width: 3)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(reply.authorUsername).font(.caption.bold())
                    Text("@\(parentUsername)").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        withAnimation(CrewDesign.standardAnimation) {
                            session.likeService.toggleComment(reply, commentService: session.commentService)
                        }
                    } label: {
                        Label("\(liveReply.likeCount)", systemImage: session.likeService.isCommentLiked(liveReply) ? "heart.fill" : "heart")
                            .foregroundStyle(session.likeService.isCommentLiked(liveReply) ? .red : Color.crewNavy)
                    }
                    .buttonStyle(.borderless)
                    Menu {
                        if reply.userID == session.currentProfile?.id {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                guard let currentUserID = session.currentProfile?.id else { return }
                                session.commentService.delete(reply, currentUserID: currentUserID)
                            }
                        } else {
                            Button("Report", systemImage: "flag", role: .destructive) {
                                showingReport = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
                Text(reply.textContent ?? "@\(parentUsername)")
                    .font(.subheadline)
            }
        }
        .padding(.leading, 28)
        .confirmationDialog("Report this reply", isPresented: $showingReport) {
            Button("Harassment or hate speech", role: .destructive) {
                session.moderationService.reportComment(reply, reporterID: session.currentProfile?.id, reason: "harassment")
            }
            Button("Private personal information", role: .destructive) {
                session.moderationService.reportComment(reply, reporterID: session.currentProfile?.id, reason: "private_info")
            }
        }
    }

    private var liveReply: Comment {
        session.commentService.comments.first(where: { $0.id == reply.id }) ?? reply
    }
}
