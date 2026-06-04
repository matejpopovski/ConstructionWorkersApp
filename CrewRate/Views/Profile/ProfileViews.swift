import PhotosUI
import SwiftUI
import UIKit

struct PublicProfileView: View {
    @EnvironmentObject private var session: SessionViewModel
    let profile: Profile?

    private var shownProfile: Profile {
        profile ?? session.currentProfile ?? DemoData.currentUser
    }

    private var isCurrentUser: Bool {
        shownProfile.id == session.currentProfile?.id
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let bio = shownProfile.bio, !bio.isEmpty {
                        Text(bio)
                    }
                    socialStats
                    details
                    actionButtons
                    Divider()
                    Text("Posts")
                        .font(.headline)
                    if visibleProfilePosts.isEmpty {
                        EmptyStateView(title: "No public posts yet", systemImage: "doc.text")
                    }
                    ForEach(visibleProfilePosts) { post in
                        PostCardView(post: post)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(shownProfile.username)
            .refreshable {
                session.refreshRemoteData()
            }
            .onAppear {
                session.refreshRemoteData()
            }
            .toolbar {
                if profile == nil {
                    NavigationLink("Edit") {
                        EditProfileView()
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            ProfileImageView(profile: shownProfile, size: 76)
            VStack(alignment: .leading, spacing: 6) {
                Text(shownProfile.displayName)
                    .font(.title2.bold())
                Text("@\(shownProfile.username)")
                    .foregroundStyle(.secondary)
                if shownProfile.openToWork {
                    BadgeView(text: "Open to Work", systemImage: "briefcase")
                }
            }
        }
    }

    private var socialStats: some View {
        HStack(spacing: 20) {
            statBlock(count: followerCount, label: "Followers")
            statBlock(count: followingCount, label: "Following")
            if isCurrentUser {
                statBlock(count: privatePostCount, label: "Private")
            }
        }
        .padding(.vertical, 4)
    }

    private func statBlock(count: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(count)")
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 70, alignment: .leading)
    }

    private var details: some View {
        FlowLayout {
            if shownProfile.showCityState, let city = shownProfile.city, let state = shownProfile.state {
                BadgeView(text: "\(city), \(state)", systemImage: "mappin")
            }
            if let trade = shownProfile.tradeLabel {
                BadgeView(text: trade, systemImage: "hammer")
            }
            if let years = shownProfile.yearsExperience {
                BadgeView(text: "\(years) yrs", systemImage: "calendar")
            }
            if shownProfile.showCurrentCompany, let company = shownProfile.currentCompanyOrEmployer {
                BadgeView(text: company, systemImage: "building.2")
            }
        }
    }

    private var actionButtons: some View {
        HStack {
            if profile != nil {
                if isCurrentUser {
                    Label("This is you", systemImage: "person.crop.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else if session.friendService.isFriend(shownProfile) {
                    Label("Following", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                } else if session.friendService.hasPendingRequest(to: shownProfile) {
                    Label("Pending", systemImage: "clock")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        session.friendService.sendRequest(to: shownProfile, from: session.currentProfile)
                    } label: {
                        Label("Follow", systemImage: "person.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                NavigationLink {
                    ChatView(profile: shownProfile)
                } label: {
                    Label("Message", systemImage: "message")
                }
                .buttonStyle(.bordered)
                if session.moderationService.isBlocked(shownProfile.id) {
                    Button {
                        session.moderationService.unblockUser(shownProfile)
                    } label: {
                        Label("Unblock", systemImage: "person.crop.circle.badge.checkmark")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(role: .destructive) {
                        session.moderationService.blockUser(shownProfile, currentUserID: session.currentProfile?.id)
                        session.friendService.remove(shownProfile)
                    } label: {
                        Label("Block", systemImage: "person.crop.circle.badge.xmark")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var visibleProfilePosts: [Post] {
        session.postService.posts.filter { post in
            post.userID == shownProfile.id
                && (!post.isAnonymous || isCurrentUser)
                && (isCurrentUser || !session.moderationService.isBlocked(post.userID))
        }
    }

    private var privatePostCount: Int {
        session.postService.posts.filter { $0.userID == shownProfile.id && $0.isAnonymous }.count
    }

    private var followerCount: Int {
        if isCurrentUser { return session.friendService.friends.count }
        return session.friendService.isFriend(shownProfile) ? 1 : 0
    }

    private var followingCount: Int {
        if isCurrentUser { return session.friendService.friends.count }
        return session.friendService.isFriend(shownProfile) ? 1 : 0
    }
}

struct EditProfileView: View {
    @EnvironmentObject private var session: SessionViewModel
    @State private var profile = DemoData.currentUser
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoErrorMessage: String?

    var body: some View {
        Form {
            Section("Public Profile") {
                HStack {
                    ProfileImageView(profile: profile, size: 72)
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(profile.profilePhotoData == nil ? "Add Profile Photo" : "Change Photo", systemImage: "camera")
                    }
                }
                if let photoErrorMessage {
                    ErrorView(message: photoErrorMessage)
                }
                TextField("Username", text: $profile.username)
                TextField("First name", text: optionalBinding(\.firstName))
                TextField("Last name", text: optionalBinding(\.lastName))
                StateCityPicker(state: $profile.state, city: $profile.city)
                Picker("Job / Position", selection: Binding($profile.tradePosition, replacingNilWith: .other)) {
                    ForEach(TradePosition.allCases) { trade in
                        Text(trade.rawValue).tag(trade)
                    }
                }
                if profile.tradePosition == .other {
                    TextField("Write job or position", text: optionalBinding(\.customTradePosition))
                }
                TextField("Experience level", text: optionalBinding(\.experienceLevel))
                TextField("Company or employer", text: optionalBinding(\.currentCompanyOrEmployer))
                TextField("Bio", text: optionalBinding(\.bio), axis: .vertical)
            }
            Section("Worker Background") {
                TextField("Years experience", value: $profile.yearsExperience, format: .number)
                    .keyboardType(.numberPad)
                Picker("Union status", selection: Binding($profile.unionStatus, replacingNilWith: .preferNotToSay)) {
                    ForEach(UnionStatus.allCases) { status in
                        Text(status.rawValue.capitalized).tag(status)
                    }
                }
                Text("Union status is optional background for comparing workplace conditions. It is not job-search information.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Private") {
                TextField("Street address private only", text: optionalBinding(\.streetAddressPrivateOnly))
                    .textContentType(.fullStreetAddress)
                Text("Street address is stored for private account use only and is never shown publicly.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                NavigationLink("Privacy Settings") {
                    SettingsPrivacyView()
                }
                Button("Save") {
                    session.updateCurrentProfile(profile)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .onAppear {
            profile = session.currentProfile ?? DemoData.currentUser
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task { await loadSelectedPhoto(newItem) }
        }
    }

    private func optionalBinding(_ keyPath: WritableKeyPath<Profile, String?>) -> Binding<String> {
        Binding(
            get: { profile[keyPath: keyPath] ?? "" },
            set: { profile[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) async {
        photoErrorMessage = nil
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let optimizedData = ImageOptimizer.optimizedJPEGData(from: data, preset: .profile) else {
                photoErrorMessage = "That photo could not be loaded."
                return
            }
            profile.profilePhotoData = optimizedData
        } catch {
            photoErrorMessage = "Profile photo attach failed. Please try another image."
        }
    }
}

struct ChatView: View {
    @EnvironmentObject private var session: SessionViewModel
    let profile: Profile
    @State private var draft = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var photoErrorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    let messages = session.messageService.thread(currentUserID: session.currentProfile?.id, friendID: profile.id)
                    let visibleMessages = messages.filter {
                        $0.senderID == session.currentProfile?.id || !session.moderationService.isBlocked($0.senderID)
                    }
                    if visibleMessages.isEmpty {
                        ContentUnavailableView("No messages yet", systemImage: "message", description: Text("Start a conversation with \(profile.username)."))
                            .padding(.top, 80)
                    } else {
                        ForEach(visibleMessages) { message in
                            ChatBubble(message: message, isMine: message.senderID == session.currentProfile?.id)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .refreshable {
                session.refreshRemoteData()
            }
            if let selectedPhotoData, let image = UIImage(data: selectedPhotoData) {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Button {
                        selectedPhoto = nil
                        self.selectedPhotoData = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
            if let photoErrorMessage {
                ErrorView(message: photoErrorMessage)
                    .padding(.horizontal)
            }
            HStack {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo")
                }
                TextField("Message \(profile.username)", text: $draft)
                    .textFieldStyle(.roundedBorder)
                Button {
                    session.messageService.send(to: profile, from: session.currentProfile, body: draft, imageData: selectedPhotoData)
                    draft = ""
                    selectedPhoto = nil
                    selectedPhotoData = nil
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedPhotoData == nil)
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle(profile.username)
        .onAppear {
            session.messageService.refresh(currentUserID: session.currentProfile?.id)
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task { await loadSelectedPhoto(newItem) }
        }
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

struct ChatBubble: View {
    @EnvironmentObject private var session: SessionViewModel
    let message: ChatMessage
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 6) {
                if let sharedPostID = message.sharedPostID {
                    if let post = session.postService.posts.first(where: { $0.id == sharedPostID }) {
                        NavigationLink {
                            CommentsView(post: post)
                        } label: {
                            SharedPostPreview(post: post)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Label("Post no longer available", systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                    }
                }
                if let imageData = message.imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 180, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else if let imageURL = message.imageURLs.first {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            Label("Photo unavailable", systemImage: "photo")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        default:
                            ProgressView()
                        }
                    }
                    .frame(width: 180, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if !message.body.isEmpty {
                    Text(message.body)
                }
                Text(DateDisplay.label(for: message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(isMine ? .white.opacity(0.75) : .secondary)
            }
            .padding(10)
            .background(isMine ? Color.crewOrange : Color(.secondarySystemBackground))
            .foregroundStyle(isMine ? .black : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            if !isMine { Spacer(minLength: 40) }
        }
    }
}

struct SharedPostPreview: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(Color.crewOrange)
                Text("Shared Post")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(post.isAnonymous ? "Anonymous Worker" : post.authorUsername)
                .font(.subheadline.bold())

            if let company = post.companyOrEmployer {
                Label(company, systemImage: "building.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let text = post.textContent, !text.isEmpty {
                Text(text)
                    .font(.subheadline)
                    .lineLimit(3)
            }

            if let imageData = post.imageData.first, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let imageURL = post.imageURLs.first {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Color.crewGray.overlay(Image(systemName: "photo"))
                    }
                }
                .frame(height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: 240, alignment: .leading)
        .padding(10)
        .background(Color(.systemBackground).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
