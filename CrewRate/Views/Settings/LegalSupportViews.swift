import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CrewDesign.Spacing.md) {
                Text("Effective June 8, 2026")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                policySection(
                    "Information We Collect",
                    "Construction Gossip stores account details, profile information you choose to provide, job reviews, comments, likes, follows, private messages, reports, blocks, and photos you upload. Supabase processes authentication, database, and file-storage data needed to operate the service."
                )
                policySection(
                    "How We Use Information",
                    "We use this information to provide accounts, profiles, feeds, search, messaging, safety controls, moderation, account recovery, and service security. We do not sell personal information."
                )
                policySection(
                    "Visibility",
                    "Job reviews, comments, selected profile fields, and their photos may be visible to other signed-in users. Private messages are limited to conversation participants. Anonymous reviews hide the author's identity from other users, but retain the account link for safety and moderation."
                )
                policySection(
                    "Safety and Retention",
                    "Reports and block records are used to investigate abuse. Data is retained while an account is active and as reasonably needed for security, legal obligations, and dispute resolution."
                )
                policySection(
                    "Your Choices",
                    "You can change profile visibility, block users, report content, delete your own posts and comments, and permanently delete your account from Settings."
                )
                policySection(
                    "Contact",
                    "For privacy questions or deletion support, email support@constructiongossip.app."
                )
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.crewCanvas)
    }

    private func policySection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: CrewDesign.Spacing.xs) {
            Text(title)
                .font(.headline)
            Text(body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SupportView: View {
    var body: some View {
        List {
            Section("Contact") {
                Link(destination: URL(string: "mailto:support@constructiongossip.app")!) {
                    Label("support@constructiongossip.app", systemImage: "envelope")
                }
            }
            Section("Safety") {
                Text("Use the report menu on a review, comment, reply, or profile for harassment, impersonation, private information, or unsafe content.")
                Text("Block a profile to hide that person's content and prevent further interaction in the app.")
            }
            Section("Account") {
                Text("Password recovery is available from the login screen. Permanent account deletion is available in Profile > Settings.")
            }
        }
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}
