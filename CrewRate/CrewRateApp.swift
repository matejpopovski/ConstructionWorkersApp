import SwiftUI

@main
struct CrewRateApp: App {
    @StateObject private var session = SessionViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .tint(.crewOrange)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        Group {
            if session.isAuthenticated {
                if session.needsOnboarding {
                    OnboardingProfileView()
                } else {
                    MainTabView()
                }
            } else {
                AuthView()
            }
        }
    }
}
