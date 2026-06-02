import SwiftUI

struct SettingsPrivacyView: View {
    @EnvironmentObject private var session: SessionViewModel
    @State private var profile = DemoData.currentUser

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
                    session.currentProfile = profile
                    session.profileService.update(profile)
                }
                Button("Sign Out", role: .destructive) {
                    session.signOut()
                }
            }
        }
        .navigationTitle("Privacy")
        .onAppear {
            profile = session.currentProfile ?? DemoData.currentUser
        }
    }
}
