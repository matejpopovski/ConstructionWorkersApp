import PhotosUI
import SwiftUI
import UIKit

struct AuthView: View {
    @State private var mode: AuthMode = .login

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CrewDesign.Spacing.xl) {
                    Spacer(minLength: CrewDesign.Spacing.xxl)
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                        .frame(width: 108, height: 108)
                        .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.large, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
                VStack(spacing: CrewDesign.Spacing.xs) {
                    Text("Construction Gossip")
                        .font(.largeTitle.bold())
                    Text("Connect with workers, compare job experiences, and build your crew.")
                            .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                            .frame(maxWidth: 320)
                }
                Picker("Mode", selection: $mode) {
                    Text("Login").tag(AuthMode.login)
                    Text("Sign Up").tag(AuthMode.signUp)
                }
                .pickerStyle(.segmented)
                    .padding(CrewDesign.Spacing.xxs)
                    .background(Color.crewGray)
                    .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
                if mode == .login {
                    LoginView()
                } else {
                    SignUpView()
                }
                HStack(spacing: CrewDesign.Spacing.md) {
                    NavigationLink("Privacy") {
                        PrivacyPolicyView()
                    }
                    NavigationLink("Terms") {
                        TermsAgreementView()
                            .padding()
                            .navigationTitle("Terms of Use")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    NavigationLink("Support") {
                        SupportView()
                    }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.crewOrange)
                    Spacer(minLength: CrewDesign.Spacing.xl)
                }
                .padding(.horizontal, CrewDesign.Spacing.lg)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .crewScreenBackground()
            .animation(.easeInOut(duration: 0.2), value: mode)
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
    @State private var showingRecoveryConfirmation = false
    @State private var showingRecoverySheet = false
    @State private var recoveryValidationMessage: String?

    var body: some View {
        VStack(spacing: CrewDesign.Spacing.sm) {
            TextInputField(title: "Email", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
            SecureField("Password", text: $password)
                .textContentType(.password)
                .padding(.horizontal, CrewDesign.Spacing.md)
                .frame(minHeight: CrewDesign.Size.controlHeight)
                .background(Color.crewGray)
                .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
            if let error = session.errorMessage {
                ErrorView(message: error)
            }
            if let recoveryValidationMessage {
                ErrorView(message: recoveryValidationMessage)
            }
            PrimaryButton("Login", systemImage: "person.fill") {
                Task { await session.login(email: email, password: password) }
            }
            Button("Forgot password?") {
                let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                guard normalizedEmail.contains("@"), normalizedEmail.contains(".") else {
                    recoveryValidationMessage = "Enter your account email above first."
                    return
                }
                recoveryValidationMessage = nil
                showingRecoveryConfirmation = true
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.crewOrange)
            .buttonStyle(CrewPressButtonStyle())
        }
        .crewCard()
        .confirmationDialog(
            "Send a password recovery email?",
            isPresented: $showingRecoveryConfirmation,
            titleVisibility: .visible
        ) {
            Button("Yes, Send Recovery Email") {
                showingRecoverySheet = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will receive a secure link that opens Construction Gossip so you can choose a new password.")
        }
        .sheet(isPresented: $showingRecoverySheet) {
            ForgotPasswordView(initialEmail: email)
                .environmentObject(session)
        }
    }
}

struct ForgotPasswordView: View {
    @EnvironmentObject private var session: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    let email: String
    @State private var isSending = false
    @State private var didSend = false
    @State private var errorMessage: String?

    init(initialEmail: String) {
        email = initialEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: CrewDesign.Spacing.lg) {
                Image(systemName: didSend ? "envelope.badge.fill" : "lock.rotation")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(Color.crewOrange)

                VStack(spacing: CrewDesign.Spacing.xs) {
                    Text(didSend ? "Check Your Email" : "Recover Your Account")
                        .font(.title2.bold())
                    Text(didSend
                         ? "Open the recovery link sent to \(email). It will return you to Construction Gossip to choose a new password."
                         : "We will send a secure recovery link to the account below.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: CrewDesign.Spacing.sm) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(Color.crewOrange)
                    Text(email)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, CrewDesign.Spacing.md)
                .frame(minHeight: CrewDesign.Size.controlHeight)
                .background(Color.crewGray)
                .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))

                if !didSend {
                    if let errorMessage {
                        ErrorView(message: errorMessage)
                    }
                    Button {
                        sendRecoveryEmail()
                    } label: {
                        Group {
                            if isSending {
                                ProgressView().tint(.black)
                            } else {
                                Label("Send Recovery Email", systemImage: "paperplane.fill")
                            }
                        }
                    }
                    .buttonStyle(CrewPrimaryButtonStyle())
                    .disabled(isSending)
                } else {
                    if let errorMessage {
                        ErrorView(message: errorMessage)
                    }
                    Button("Send Another Link") {
                        sendRecoveryEmail()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.crewOrange)
                    .buttonStyle(CrewPressButtonStyle())
                    .disabled(isSending)
                }
                Spacer()
            }
            .padding(CrewDesign.Spacing.xl)
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .crewScreenBackground()
        }
    }

    private func sendRecoveryEmail() {
        guard !isSending else { return }
        isSending = true
        errorMessage = nil
        Task {
            do {
                try await session.requestPasswordRecovery(email: email)
                didSend = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }

}

struct ResetPasswordView: View {
    @EnvironmentObject private var session: SessionViewModel
    @State private var password = ""
    @State private var confirmation = ""
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            VStack(spacing: CrewDesign.Spacing.lg) {
                Spacer()
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.large, style: .continuous))

                VStack(spacing: CrewDesign.Spacing.xs) {
                    Text(didSave ? "Password Updated" : "Create New Password")
                        .font(.title.bold())
                    Text(didSave
                         ? "Your password was changed successfully. You can now sign in with your new password."
                         : "Choose a password with at least 8 characters that you do not use elsewhere.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                if didSave {
                    Button("Return to Login") {
                        session.cancelPasswordRecovery()
                    }
                    .buttonStyle(CrewPrimaryButtonStyle())
                } else {
                    VStack(spacing: CrewDesign.Spacing.sm) {
                        SecureField("New password", text: $password)
                            .textContentType(.newPassword)
                            .padding(.horizontal, CrewDesign.Spacing.md)
                            .frame(minHeight: CrewDesign.Size.controlHeight)
                            .background(Color.crewGray)
                            .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
                        SecureField("Confirm new password", text: $confirmation)
                            .textContentType(.newPassword)
                            .padding(.horizontal, CrewDesign.Spacing.md)
                            .frame(minHeight: CrewDesign.Size.controlHeight)
                            .background(Color.crewGray)
                            .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
                        if let errorMessage {
                            ErrorView(message: errorMessage)
                        }
                        Button {
                            savePassword()
                        } label: {
                            if isSaving {
                                ProgressView().tint(.black)
                            } else {
                                Label("Update Password", systemImage: "checkmark.shield.fill")
                            }
                        }
                        .buttonStyle(CrewPrimaryButtonStyle())
                        .disabled(isSaving || !isValid)
                        .opacity(isValid ? 1 : 0.55)
                    }
                    .crewCard()
                }
                Spacer()
            }
            .padding(.horizontal, CrewDesign.Spacing.lg)
            .crewScreenBackground()
            .toolbar {
                if !didSave {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel", role: .cancel) {
                            session.cancelPasswordRecovery()
                        }
                    }
                }
            }
        }
    }

    private var isValid: Bool {
        password.count >= 8 && password == confirmation
    }

    private func savePassword() {
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters."
            return
        }
        guard password == confirmation else {
            errorMessage = "Passwords do not match."
            return
        }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await session.updateRecoveredPassword(password)
                didSave = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
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
            VStack(spacing: CrewDesign.Spacing.sm) {
                TextInputField(title: "Username", text: $username)
                    .keyboardType(.asciiCapable)
                    .textContentType(.username)
                TextInputField(title: "Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
                    .padding(.horizontal, CrewDesign.Spacing.md)
                    .frame(minHeight: CrewDesign.Size.controlHeight)
                    .background(Color.crewGray)
                    .clipShape(RoundedRectangle(cornerRadius: CrewDesign.Radius.medium, style: .continuous))
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
            .crewCard()
        } else {
            TermsAgreementView {
                acceptedTerms = true
            }
            .crewCard()
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
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(Color.crewCanvas)
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

extension Binding where Value: Equatable {
    init(_ source: Binding<Value?>, replacingNilWith fallback: Value) {
        self.init(
            get: { source.wrappedValue ?? fallback },
            set: { source.wrappedValue = $0 }
        )
    }
}
