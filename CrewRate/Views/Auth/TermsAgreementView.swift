import SwiftUI

struct TermsAgreementView: View {
    let onAgree: () -> Void

    var body: some View {
        VStack(spacing: CrewDesign.Spacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Terms of Use")
                    .font(.headline)
                Text("You must agree before creating an account.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(TermsOfUse.sections) { section in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(section.title)
                                .font(.subheadline.bold())
                            Text(section.body)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(CrewDesign.Spacing.md)
            }
            .frame(maxHeight: 260)
            .background(Color.crewGray)
            .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))

            PrimaryButton("Agree and Continue", systemImage: "checkmark.circle.fill", action: onAgree)
        }
    }
}

private enum TermsOfUse {
    static let sections: [TermsSection] = [
        TermsSection(
            title: "Effective Date: June 2, 2026",
            body: "App Name: Construction Gossip. Company/Developer: Construction Gossip. Contact: support@constructiongossip.app."
        ),
        TermsSection(
            title: "Welcome",
            body: "These Terms govern your access to and use of the Construction Gossip mobile application, website, services, features, content, and related products. By creating an account, downloading the app, accessing the Service, or using any part of the Service, you agree to these Terms. If you do not agree, you may not use the Service."
        ),
        TermsSection(
            title: "1. Eligibility",
            body: "You must be at least 18 years old to use the Service. By using the Service, you represent that you have the legal right and ability to agree to these Terms and that your use does not violate applicable law or regulation."
        ),
        TermsSection(
            title: "2. Your Account",
            body: "You agree to provide accurate, current, and complete information and to keep that information updated. You are responsible for maintaining the confidentiality of your login credentials and for all activity under your account. We may suspend, restrict, or terminate your account if we believe you violated these Terms, created risk for other users, used the Service unlawfully, or harmed the Service."
        ),
        TermsSection(
            title: "3. Acceptable Use",
            body: "You may not violate any law, harass or threaten others, post false or misleading content, share another person's private information without authorization, upload harmful code, hack or disrupt the Service, create fake accounts, manipulate ratings, spam users, abuse reporting tools, commit fraud, harm minors or vulnerable individuals, or assist others in violating these Terms."
        ),
        TermsSection(
            title: "4. User Content",
            body: "The Service may allow you to create, upload, post, send, display, or share text, photos, videos, comments, reviews, messages, profile information, or other materials. You retain ownership of your content, but grant Construction Gossip a worldwide, non-exclusive, royalty-free, transferable, sublicensable license to host, store, reproduce, modify, adapt, publish, display, distribute, and otherwise use your content as necessary to operate, improve, promote, and provide the Service."
        ),
        TermsSection(
            title: "5. Content Moderation",
            body: "We may review, remove, limit, hide, label, restrict, or refuse to display User Content at our discretion, including content that we believe violates these Terms, creates legal risk, harms users, or negatively affects the Service. We may also suspend or terminate accounts that violate these Terms."
        ),
        TermsSection(
            title: "6. Prohibited Content",
            body: "You may not post harassment, bullying, threats, stalking, hate speech, private personal information, false factual claims about people or companies, sexual exploitation, graphic violence, illegal instructions, spam, scams, phishing, deceptive promotions, copyrighted material without permission, or content that violates Apple App Store or Google Play policies."
        ),
        TermsSection(
            title: "7. Privacy",
            body: "Your use of the Service is also governed by our Privacy Policy. You understand that no electronic transmission or storage method is completely secure. We use reasonable measures to protect information, but cannot guarantee absolute security."
        ),
        TermsSection(
            title: "8. Safety and User Interactions",
            body: "You are responsible for your interactions with other users. We do not verify every statement made by users and do not guarantee the identity, background, intentions, conduct, or accuracy of any user."
        ),
        TermsSection(
            title: "9. Payments and Purchases",
            body: "Some features may require payment, subscription, or in-app purchase. Prices, billing periods, renewal terms, cancellation methods, and refund rules will be shown before purchase where required. Purchases through Apple, Google, or another third-party app store may also be governed by that third party's terms."
        ),
        TermsSection(
            title: "10. Intellectual Property",
            body: "The Service, including software, design, graphics, logos, trademarks, text, features, and content provided by Construction Gossip, is owned by Construction Gossip or its licensors and protected by intellectual property laws. You may not copy, modify, distribute, sell, lease, reverse engineer, or create derivative works from the Service without written permission."
        ),
        TermsSection(
            title: "11. Feedback",
            body: "If you send ideas, suggestions, bug reports, improvements, or other feedback, you agree that we may use that feedback without restriction, payment, or obligation to you."
        ),
        TermsSection(
            title: "12. Third-Party Services",
            body: "The Service may contain links, integrations, advertisements, APIs, payment processors, analytics tools, or other third-party services. We do not control and are not responsible for third-party services, websites, content, privacy practices, or terms."
        ),
        TermsSection(
            title: "13. Disclaimers",
            body: "The Service is provided as is and as available without warranties of any kind. To the fullest extent permitted by law, we disclaim warranties including merchantability, fitness for a particular purpose, title, non-infringement, availability, accuracy, reliability, and security."
        ),
        TermsSection(
            title: "14. Limitation of Liability",
            body: "To the fullest extent permitted by law, Construction Gossip and its owners, employees, contractors, officers, directors, agents, affiliates, and partners will not be liable for indirect, incidental, special, consequential, exemplary, or punitive damages. Our total liability for any claim related to the Service will not exceed the greater of the amount you paid us in the 12 months before the claim arose or $100."
        ),
        TermsSection(
            title: "15. Indemnification",
            body: "You agree to defend, indemnify, and hold harmless Construction Gossip and its owners, employees, contractors, officers, directors, agents, affiliates, and partners from claims, damages, losses, liabilities, costs, and expenses arising from your use or misuse of the Service, your content, your violation of these Terms, your violation of law or third-party rights, or your interactions with other users."
        ),
        TermsSection(
            title: "16. Suspension and Termination",
            body: "We may suspend, restrict, or terminate access at any time if we believe you violated these Terms, created risk or legal exposure, harmed other users, or misused the Service. You may stop using the Service at any time."
        ),
        TermsSection(
            title: "17. Changes",
            body: "We may modify, update, suspend, discontinue, or remove any part of the Service or these Terms at any time. Your continued use of the Service after updated Terms become effective means you accept the updated Terms."
        ),
        TermsSection(
            title: "18. Governing Law and Disputes",
            body: "These Terms are governed by applicable United States law and the laws of the jurisdiction where Construction Gossip is operated, without regard to conflict-of-law principles. Before filing a claim, you agree to contact support@constructiongossip.app and try to resolve the dispute informally."
        ),
        TermsSection(
            title: "19. App Store Terms",
            body: "If you downloaded the Service from the Apple App Store, Google Play Store, or another app marketplace, you also agree to comply with that marketplace's applicable terms, rules, and policies."
        ),
        TermsSection(
            title: "20. Copyright Complaints",
            body: "If you believe content on the Service infringes your copyright, contact support@constructiongossip.app with your name and contact information, a description of the copyrighted work, a description of the allegedly infringing content, a good-faith statement, an accuracy statement, and your physical or electronic signature."
        )
    ]
}

private struct TermsSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}
