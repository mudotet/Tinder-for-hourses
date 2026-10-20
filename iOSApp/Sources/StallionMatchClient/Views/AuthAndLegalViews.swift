import AuthenticationServices
import SharedModels
import SwiftUI

public struct AuthRootView: View {
    @Bindable public var appState: AppStateViewModel
    @State private var isSignUpMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSubmitting = false
    @State private var showTermsSheet = false
    @State private var showPrivacySheet = false

    public init(appState: AppStateViewModel) {
        self.appState = appState
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "figure.equestrian.sports")
                            .font(.system(size: 56))
                            .foregroundStyle(EquestrianTheme.saddleBrown)
                            .accessibilityHidden(true)

                        Text("Stallion Match")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(EquestrianTheme.saddleBrown)

                        Text("Connect horses for trail rides, companionship, and verified breeding inquiries.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    Picker("Authentication Mode", selection: $isSignUpMode) {
                        Text("Sign Up").tag(true)
                        Text("Log In").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("authModePicker")

                    VStack(spacing: 14) {
                        if isSignUpMode {
                            TextField("Owner / Handler Name", text: $displayName)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("displayNameField")
                                .accessibilityLabel("Owner or handler name")
                        }

                        TextField("Email Address", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("emailField")
                            .accessibilityLabel("Email address")

                        SecureField("Password (min 8 characters)", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("passwordField")
                            .accessibilityLabel("Password")
                    }

                    if let errorMessage = appState.authErrorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(EquestrianTheme.warmTerracotta)
                            .multilineTextAlignment(.center)
                            .accessibilityLabel("Error: \(errorMessage)")
                    }

                    Button {
                        Task {
                            isSubmitting = true
                            if isSignUpMode {
                                await appState.signUp(
                                    email: email,
                                    password: password,
                                    displayName: displayName
                                )
                            } else {
                                await appState.login(email: email, password: password)
                            }
                            isSubmitting = false
                        }
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            }
                            Text(isSignUpMode ? "Create Account" : "Log In")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(EquestrianTheme.saddleBrown)
                    .disabled(email.isEmpty || password.count < 8 || isSubmitting)
                    .accessibilityIdentifier("submitAuthButton")

                    SignInWithAppleButton(isSignUpMode ? .signUp : .signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success(let auth):
                            if let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                               let tokenData = credential.identityToken,
                               let tokenString = String(data: tokenData, encoding: .utf8)
                            {
                                let formattedName = [
                                    credential.fullName?.givenName,
                                    credential.fullName?.familyName
                                ]
                                .compactMap { $0 }
                                .joined(separator: " ")

                                Task {
                                    await appState.signInWithApple(
                                        identityToken: tokenString,
                                        fullName: formattedName.isEmpty ? nil : formattedName,
                                        email: credential.email
                                    )
                                }
                            }
                        case .failure(let error):
                            appState.authErrorMessage = error.localizedDescription
                        }
                    }
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("signInWithAppleButton")

                    AnimalWelfareNoticeBanner()

                    HStack(spacing: 16) {
                        Button("Terms of Use") {
                            showTermsSheet = true
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(EquestrianTheme.saddleBrown)

                        Text("•").foregroundStyle(.secondary)

                        Button("Privacy Policy") {
                            showPrivacySheet = true
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(EquestrianTheme.saddleBrown)
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("Welcome")
            .sheet(isPresented: $showTermsSheet) {
                NavigationStack { TermsOfUseView() }
            }
            .sheet(isPresented: $showPrivacySheet) {
                NavigationStack { PrivacyPolicyView() }
            }
        }
    }
}

public struct TermsOfUseView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stallion Match Terms of Use")
                    .font(.title2.weight(.bold))

                Text("Effective Version: \(SafetyConstants.currentTermsVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("""
                1. Eligibility & Responsible Horsemanship
                Stallion Match is a platform for adult horse owners, trainers, and handlers (18+) to introduce their horses for companionship, trail riding, stablemates, and breeding inquiries.

                2. Zero Tolerance for Objectionable Content or Abuse
                Users may not post abusive, defamatory, sexually explicit, or animal-cruelty content in horse bios, photos, or chat messages. Every reported profile or message is reviewed in our server moderation queue within 24 hours, and violating accounts are removed immediately.

                3. Animal Welfare & No In-App Payments
                \(SafetyConstants.animalWelfareWarning)

                4. Blocking & Reporting
                You can block any user or report any horse profile, user, or message at any time. Blocking immediately hides all profiles and disables communication between both accounts.
                """)
                .font(.body)

                AnimalWelfareNoticeBanner()
            }
            .padding(20)
        }
        .navigationTitle("Terms of Use")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

public struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stallion Match Privacy Policy")
                    .font(.title2.weight(.bold))

                Text("""
                1. Data We Collect
                • Account Information: Email address, optional display name, and encrypted password hash (Bcrypt) or Sign in with Apple identifier.
                • Horse Profiles: Photos (2–6 per horse), breed, age, discipline, temperament tags, optional Coggins/vaccination dates, and bio.
                • Coarse Location Only: We round all geographic coordinates to 2 decimal places (~1.1 km city-level resolution) before storage. Your exact barn or stable coordinates are never stored or shared.

                2. Token Security
                Authentication tokens are stored exclusively in the iOS Keychain and rotated on every refresh.

                3. Complete Account Deletion
                You can permanently delete your account at any time in Settings -> Delete Account. Account deletion immediately removes your user record, horse profiles, uploaded photos, swipes, matches, and chat history from our database and storage.
                """)
                .font(.body)
            }
            .padding(20)
        }
        .navigationTitle("Privacy Policy")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

#Preview("Auth Root") {
    AuthRootView(appState: AppStateViewModel())
}
