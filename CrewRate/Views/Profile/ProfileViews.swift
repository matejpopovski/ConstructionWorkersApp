import PhotosUI
import SwiftUI
import UIKit

struct PublicProfileView: View {
    @EnvironmentObject private var session: SessionViewModel
    let profile: Profile?
    @State private var showingUnfollowConfirmation = false

    private var shownProfile: Profile {
        profile ?? session.currentProfile ?? DemoData.currentUser
    }

    private var isCurrentUser: Bool {
        shownProfile.id == session.currentProfile?.id
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CrewDesign.Spacing.lg) {
                    header
                    socialStats
                    actionButtons
                    details
                    CrewSectionHeader(
                        title: "Job reports",
                        subtitle: isCurrentUser ? "Your public and anonymous activity" : "Reports shared by \(shownProfile.username)"
                    )
                    if visibleProfilePosts.isEmpty {
                        EmptyStateView(title: "No public posts yet", systemImage: "doc.text")
                            .frame(maxWidth: .infinity)
                            .crewCard()
                    }
                    ForEach(visibleProfilePosts) { post in
                        PostCardView(post: post)
                    }
                }
                .padding(.horizontal, CrewDesign.Spacing.sm)
                .padding(.top, CrewDesign.Spacing.md)
                .padding(.bottom, CrewDesign.Spacing.xxl)
            }
            .crewScreenBackground()
            .navigationTitle(shownProfile.username)
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                session.refreshRemoteData()
            }
            .onAppear {
                session.refreshRemoteData()
                session.friendService.refreshConnections(for: shownProfile.id, profiles: session.profileService.profiles)
            }
            .toolbar {
                if profile == nil {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        NavigationLink {
                            EditProfileView()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        NavigationLink {
                            SettingsPrivacyView()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .confirmationDialog(
                "Unfollow @\(shownProfile.username)?",
                isPresented: $showingUnfollowConfirmation,
                titleVisibility: .visible
            ) {
                Button("Unfollow", role: .destructive) {
                    session.friendService.remove(shownProfile)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Their reports will no longer be prioritized in your crew feed.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CrewDesign.Spacing.md) {
            HStack(alignment: .center, spacing: CrewDesign.Spacing.md) {
                ProfileImageView(profile: shownProfile, size: CrewDesign.Size.profileAvatar)
                VStack(alignment: .leading, spacing: CrewDesign.Spacing.xxs) {
                    Text(shownProfile.displayName)
                        .font(.title2.weight(.bold))
                    Text("@\(shownProfile.username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let trade = shownProfile.tradeLabel {
                        Text(trade)
                            .font(.subheadline.weight(.medium))
                    }
                }
                Spacer(minLength: 0)
            }
            if let bio = shownProfile.bio, !bio.isEmpty {
                Text(bio)
                    .font(.body)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if shownProfile.openToWork {
                BadgeView(text: "Open to Work", systemImage: "briefcase")
            }
        }
        .crewCard()
    }

    private var socialStats: some View {
        HStack(spacing: 0) {
            statBlock(count: visibleProfilePosts.count, label: "Reports")
            Divider().frame(height: 32)
            NavigationLink {
                SocialConnectionsView(profile: shownProfile, title: "Followers")
            } label: {
                statBlock(count: followerCount, label: "Followers")
            }
            .buttonStyle(.plain)
            Divider().frame(height: 32)
            NavigationLink {
                SocialConnectionsView(profile: shownProfile, title: "Following")
            } label: {
                statBlock(count: followingCount, label: "Following")
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .crewCard(verticalPadding: CrewDesign.Spacing.sm)
    }

    private func statBlock(count: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.headline.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: CrewDesign.Spacing.sm) {
            Text("Worker details")
                .font(.subheadline.weight(.bold))
            FlowLayout {
                if shownProfile.showCityState, let city = shownProfile.city {
                    NavigationLink {
                        WorkerAttributeResultsView(title: city, filter: .city(city))
                    } label: {
                        BadgeView(text: city, systemImage: "building")
                    }
                    .buttonStyle(.plain)
                }
                if shownProfile.showCityState, let state = shownProfile.state {
                    NavigationLink {
                        WorkerAttributeResultsView(title: state, filter: .state(state))
                    } label: {
                        BadgeView(text: state, systemImage: "map")
                    }
                    .buttonStyle(.plain)
                }
                if let trade = shownProfile.tradeLabel {
                    NavigationLink {
                        WorkerAttributeResultsView(title: trade, filter: .job(trade))
                    } label: {
                        BadgeView(text: trade, systemImage: "hammer")
                    }
                    .buttonStyle(.plain)
                }
                if let years = shownProfile.yearsExperience {
                    BadgeView(text: "\(years) yrs", systemImage: "calendar")
                }
                if shownProfile.showCurrentCompany, let company = shownProfile.currentCompanyOrEmployer {
                    BadgeView(text: company, systemImage: "building.2")
                }
            }
        }
        .crewCard()
    }

    @ViewBuilder
    private var actionButtons: some View {
        if profile != nil && !isCurrentUser {
            HStack(spacing: CrewDesign.Spacing.xs) {
                if session.friendService.isFriend(shownProfile) {
                    CrewActionButton(title: "Following", systemImage: "checkmark", prominent: true) {
                        showingUnfollowConfirmation = true
                    }
                } else if session.friendService.hasPendingRequest(to: shownProfile) {
                    CrewActionButton(title: "Pending", systemImage: "clock") {}
                        .disabled(true)
                } else {
                    CrewActionButton(title: "Follow", systemImage: "person.badge.plus", prominent: true) {
                        session.friendService.sendRequest(to: shownProfile, from: session.currentProfile)
                    }
                }
                NavigationLink {
                    ChatView(profile: shownProfile)
                } label: {
                    Label("Message", systemImage: "message")
                }
                .buttonStyle(CrewSecondaryButtonStyle())
                Menu {
                    if session.moderationService.isBlocked(shownProfile.id) {
                        Button("Unblock", systemImage: "person.crop.circle.badge.checkmark") {
                            session.moderationService.unblockUser(shownProfile)
                        }
                    } else {
                        Button("Block", systemImage: "person.crop.circle.badge.xmark", role: .destructive) {
                            session.moderationService.blockUser(shownProfile, currentUserID: session.currentProfile?.id)
                            session.friendService.remove(shownProfile)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .buttonStyle(CrewIconButtonStyle())
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

    private var followerCount: Int {
        profileConnections.count
    }

    private var followingCount: Int {
        profileConnections.count
    }

    private var profileConnections: [Profile] {
        if isCurrentUser, session.friendService.connections(for: shownProfile.id).isEmpty {
            return session.friendService.friends
        }
        return session.friendService.connections(for: shownProfile.id)
    }
}

struct SocialConnectionsView: View {
    @EnvironmentObject private var session: SessionViewModel
    let profile: Profile
    let title: String

    var body: some View {
        List(connections) { connection in
            NavigationLink {
                PublicProfileView(profile: connection)
            } label: {
                HStack(spacing: CrewDesign.Spacing.sm) {
                    ProfileImageView(profile: connection)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(connection.username).font(.headline)
                        Text([connection.tradeLabel, connection.city, connection.state].compactMap { $0 }.joined(separator: " • "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .overlay {
            if connections.isEmpty {
                EmptyStateView(title: "No \(title.lowercased()) yet", systemImage: "person.2")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            session.friendService.refreshConnections(for: profile.id, profiles: session.profileService.profiles)
        }
    }

    private var connections: [Profile] {
        if profile.id == session.currentProfile?.id,
           session.friendService.connections(for: profile.id).isEmpty {
            return session.friendService.friends
        }
        return session.friendService.connections(for: profile.id)
    }
}

enum WorkerAttributeFilter {
    case job(String)
    case city(String)
    case state(String)
}

struct WorkerAttributeResultsView: View {
    @EnvironmentObject private var session: SessionViewModel
    let title: String
    let filter: WorkerAttributeFilter

    var body: some View {
        List(workers) { worker in
            NavigationLink {
                PublicProfileView(profile: worker)
            } label: {
                HStack(spacing: CrewDesign.Spacing.sm) {
                    ProfileImageView(profile: worker)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(worker.username).font(.headline)
                        Text([worker.tradeLabel, worker.city, worker.state].compactMap { $0 }.joined(separator: " • "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .overlay {
            if workers.isEmpty {
                EmptyStateView(title: "No workers found", systemImage: "person.3")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var workers: [Profile] {
        session.profileService.profiles.filter { profile in
            guard profile.id == session.currentProfile?.id || !session.moderationService.isBlocked(profile.id) else { return false }
            switch filter {
            case .job(let job): return profile.tradeLabel?.caseInsensitiveCompare(job) == .orderedSame
            case .city(let city): return profile.city?.caseInsensitiveCompare(city) == .orderedSame
            case .state(let state): return profile.state?.caseInsensitiveCompare(state) == .orderedSame
            }
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var profile = DemoData.currentUser
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoErrorMessage: String?
    @State private var saveErrorMessage: String?
    @State private var isSaving = false

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
                if let saveErrorMessage {
                    ErrorView(message: saveErrorMessage)
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
                Button {
                    saveProfile()
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isSaving ? "Saving..." : "Save Changes")
                        Spacer()
                    }
                }
                .buttonStyle(CrewPrimaryButtonStyle())
                .disabled(isSaving)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.crewCanvas)
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

    private func saveProfile() {
        guard !isSaving else { return }
        saveErrorMessage = nil
        isSaving = true
        Task {
            do {
                try await session.updateCurrentProfile(profile)
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                saveErrorMessage = error.localizedDescription
            }
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
                .padding(CrewDesign.Spacing.md)
                .frame(maxWidth: .infinity)
            }
            .background(Color.crewCanvas)
            .refreshable {
                session.refreshRemoteData()
            }
            if let selectedPhotoData, let image = UIImage(data: selectedPhotoData) {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
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
            if let errorMessage = session.messageService.errorMessage {
                ErrorView(message: errorMessage)
                    .padding(.horizontal)
            }
            HStack(spacing: CrewDesign.Spacing.xs) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo")
                        .frame(width: CrewDesign.Size.iconButton, height: CrewDesign.Size.iconButton)
                }
                TextField("Message \(profile.username)", text: $draft)
                    .padding(.horizontal, CrewDesign.Spacing.sm)
                    .frame(minHeight: CrewDesign.Size.iconButton)
                    .background(Color.crewGray)
                    .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.large, style: .continuous))
                Button {
                    session.messageService.send(to: profile, from: session.currentProfile, body: draft, imageData: selectedPhotoData)
                    draft = ""
                    selectedPhoto = nil
                    selectedPhotoData = nil
                } label: {
                    Image(systemName: "paperplane.fill")
                        .frame(width: CrewDesign.Size.iconButton, height: CrewDesign.Size.iconButton)
                }
                .foregroundStyle(.white)
                .background(Color.crewNavy)
                .clipShape(Circle())
                .buttonStyle(CrewPressButtonStyle())
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedPhotoData == nil)
            }
            .padding(.horizontal, CrewDesign.Spacing.sm)
            .padding(.vertical, CrewDesign.Spacing.xs)
            .background(.bar)
        }
        .navigationTitle(profile.username)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            session.messageService.refresh(currentUserID: session.currentProfile?.id)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                session.messageService.refresh(currentUserID: session.currentProfile?.id)
            }
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
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
                } else if let imageURL = message.imageURLs.first {
                    RemoteImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        ProgressView()
                    } failure: {
                        Label("Photo unavailable", systemImage: "photo")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 180, height: 140)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
                }
                if !message.body.isEmpty {
                    Text(message.body)
                }
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    Text(DateDisplay.label(for: message.createdAt))
                        .font(.caption2)
                        .foregroundStyle(isMine ? .white.opacity(0.75) : .secondary)
                }
            }
            .padding(.horizontal, CrewDesign.Spacing.sm)
            .padding(.vertical, 10)
            .background(isMine ? Color.crewNavy : Color.crewSurface)
            .foregroundStyle(isMine ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.large, style: .continuous))
            .overlay {
                if !isMine {
                    RoundedRectangle(cornerRadius: CrewDesign.Radius.large, style: .continuous)
                        .stroke(Color.crewDivider, lineWidth: 0.75)
                }
            }
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
                    .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.small, style: .continuous))
            } else if let imageURL = post.imageURLs.first {
                RemoteImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.crewGray.overlay(ProgressView())
                } failure: {
                    Color.crewGray.overlay(Image(systemName: "photo"))
                }
                .frame(height: 90)
                .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.small, style: .continuous))
            }
        }
        .frame(maxWidth: 240, alignment: .leading)
        .padding(CrewDesign.Spacing.sm)
        .background(Color(.systemBackground).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
    }
}
