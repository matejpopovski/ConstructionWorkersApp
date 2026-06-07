import SwiftUI

struct SettingsPrivacyView: View {
    @EnvironmentObject private var session: SessionViewModel
    @State private var profile = DemoData.currentUser
    @State private var showingDeleteAccount = false
    @State private var showingSignOut = false

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
                Label("Street address, phone number, SSN, and private details are not displayed publicly.", systemImage: "lock.shield")
                Label("Anonymous posting is available for work reports and general posts.", systemImage: "person.fill.questionmark")
            }
            Section {
                Button("Save Privacy Settings") {
                    Task { try? await session.updateCurrentProfile(profile) }
                }
                Button("Sign Out", role: .destructive) {
                    showingSignOut = true
                }
                Button("Delete Account", role: .destructive) {
                    showingDeleteAccount = true
                }
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.crewCanvas)
        .confirmationDialog("Delete your account?", isPresented: $showingDeleteAccount, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                session.deleteCurrentAccount()
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
}
