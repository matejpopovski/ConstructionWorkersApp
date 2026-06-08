import SwiftUI

struct SettingsPrivacyView: View {
    @EnvironmentObject private var session: SessionViewModel
    @State private var profile = DemoData.currentUser
    @State private var showingDeleteAccount = false
    @State private var showingSignOut = false
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Profile Visibility") {
                Toggle("Show real name", isOn: $profile.showRealName)
                Toggle("Show current company", isOn: $profile.showCurrentCompany)
                Toggle("Show pay on profile", isOn: $profile.showPayOnProfile)
                Toggle("Show city/state", isOn: $profile.showCityState)
            }
            Section("Contact") {
                Toggle("Allow friend requests", isOn: $profile.allowFriendRequests)
                Picker("Allow messages from", selection: $profile.allowMessagesFrom) {
                    ForEach(AllowMessagesFrom.allCases) { option in
                        Text(option.rawValue.replacingOccurrences(of: "_", with: " ").capitalized).tag(option)
                    }
                }
            }
            Section("Safety") {
                Label("Do not post street addresses, phone numbers, SSNs, or other private details.", systemImage: "lock.shield")
                Label("Anonymous posting is available for job reviews.", systemImage: "person.fill.questionmark")
            }
            Section("Legal & Support") {
                NavigationLink("Privacy Policy") {
                    PrivacyPolicyView()
                }
                NavigationLink("Terms of Use") {
                    TermsAgreementView()
                        .padding()
                        .navigationTitle("Terms of Use")
                        .navigationBarTitleDisplayMode(.inline)
                }
                NavigationLink("Support") {
                    SupportView()
                }
            }
            if let errorMessage {
                Section {
                    ErrorView(message: errorMessage)
                }
            }
            Section {
                Button {
                    savePrivacySettings()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save Privacy Settings")
                    }
                }
                .disabled(isSaving || isDeleting)
                Button("Sign Out", role: .destructive) {
                    showingSignOut = true
                }
                .disabled(isSaving || isDeleting)
                Button("Delete Account", role: .destructive) {
                    showingDeleteAccount = true
                }
                .disabled(isSaving || isDeleting)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.crewCanvas)
        .confirmationDialog("Delete your account?", isPresented: $showingDeleteAccount, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your profile and associated app data. This action cannot be undone.")
        }
        .confirmationDialog("Sign out?", isPresented: $showingSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                session.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out of Construction Gossip?")
        }
        .onAppear {
            profile = session.currentProfile ?? DemoData.currentUser
        }
    }

    private func savePrivacySettings() {
        guard !isSaving else { return }
        errorMessage = nil
        isSaving = true
        Task {
            do {
                try await session.updateCurrentProfile(profile)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func deleteAccount() {
        guard !isDeleting else { return }
        errorMessage = nil
        isDeleting = true
        Task {
            do {
                try await session.deleteCurrentAccount()
            } catch {
                errorMessage = "Account deletion failed: \(error.localizedDescription)"
                isDeleting = false
            }
        }
    }
}
