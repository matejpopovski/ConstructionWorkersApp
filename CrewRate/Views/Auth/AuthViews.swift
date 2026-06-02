import PhotosUI
import SwiftUI
import UIKit

struct AuthView: View {
    @State private var mode: AuthMode = .login

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(spacing: 8) {
                    Text("Construction Gossip")
                        .font(.largeTitle.bold())
                    Text("Connect with workers, compare job experiences, and build your crew.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                Picker("Mode", selection: $mode) {
                    Text("Login").tag(AuthMode.login)
                    Text("Sign Up").tag(AuthMode.signUp)
                }
                .pickerStyle(.segmented)
                if mode == .login {
                    LoginView()
                } else {
                    SignUpView()
                }
                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
}

private enum AuthMode {
    case login
    case signUp
}

struct LoginView: View {
    @EnvironmentObject private var session: SessionViewModel
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 12) {
            TextInputField(title: "Email", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
            SecureField("Password", text: $password)
                .textContentType(.password)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            if let error = session.errorMessage {
                ErrorView(message: error)
            }
            PrimaryButton("Login", systemImage: "person.fill") {
                Task { await session.login(email: email, password: password) }
            }
        }
    }
}

struct SignUpView: View {
    @EnvironmentObject private var session: SessionViewModel
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var validationMessage: String?
    @State private var acceptedTerms = false

    var body: some View {
        if acceptedTerms {
            VStack(spacing: 12) {
                TextInputField(title: "Username", text: $username)
                    .keyboardType(.asciiCapable)
                    .textContentType(.username)
                TextInputField(title: "Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                if let validationMessage {
                    ErrorView(message: validationMessage)
                }
                if let error = session.errorMessage {
                    ErrorView(message: error)
                }
                PrimaryButton("Create Account", systemImage: "person.badge.plus") {
                    signUp()
                }
                .disabled(!isValid)
                .opacity(isValid ? 1 : 0.55)
            }
        } else {
            TermsAgreementView {
                acceptedTerms = true
            }
        }
    }

    private var isValid: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && password.count >= 8
    }

    private func signUp() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else {
            validationMessage = "Username is required."
            return
        }
        guard !trimmedEmail.isEmpty else {
            validationMessage = "Email is required."
            return
        }
        guard password.count >= 8 else {
            validationMessage = "Password must be at least 8 characters."
            return
        }
        validationMessage = nil
        Task { await session.signUp(username: trimmedUsername, email: trimmedEmail, password: password) }
    }
}

struct OnboardingProfileView: View {
    @EnvironmentObject private var session: SessionViewModel
    @State private var profile = DemoData.currentUser
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Optional Profile") {
                    HStack {
                        ProfileImageView(profile: profile, size: 72)
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label(profile.profilePhotoData == nil ? "Add Profile Photo" : "Change Photo", systemImage: "camera")
                        }
                    }
                    if let photoErrorMessage {
                        ErrorView(message: photoErrorMessage)
                    }
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
                    TextField("Bio", text: optionalBinding(\.bio), axis: .vertical)
                    Toggle("Open to work", isOn: $profile.openToWork)
                    Toggle("Willing to relocate", isOn: $profile.willingToRelocate)
                }
                Section("Privacy") {
                    Toggle("Show real name", isOn: $profile.showRealName)
                    Toggle("Show city/state", isOn: $profile.showCityState)
                }
            }
            .navigationTitle("Set Up Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        session.finishOnboarding(profile: profile)
                    }
                }
            }
            .onAppear {
                profile = session.currentProfile ?? DemoData.currentUser
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task { await loadSelectedPhoto(newItem) }
            }
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
            guard let data = try await item.loadTransferable(type: Data.self), UIImage(data: data) != nil else {
                photoErrorMessage = "That photo could not be loaded."
                return
            }
            profile.profilePhotoData = data
        } catch {
            photoErrorMessage = "Profile photo attach failed. Please try another image."
        }
    }
}

extension Binding where Value: Equatable {
    init(_ source: Binding<Value?>, replacingNilWith fallback: Value) {
        self.init(
            get: { source.wrappedValue ?? fallback },
            set: { source.wrappedValue = $0 }
        )
    }
}
