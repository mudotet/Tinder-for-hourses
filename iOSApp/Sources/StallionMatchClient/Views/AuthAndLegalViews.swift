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
                VStack(spacing: 22) {
                    // Tinder Red Gradient Hero Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(EquestrianTheme.brandGradient)
                                .frame(width: 82, height: 82)
                                .shadow(color: EquestrianTheme.tinderRed.opacity(0.38), radius: 14, x: 0, y: 6)

                            Image(systemName: "flame.fill")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        Text("stallion")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(EquestrianTheme.brandGradient)

                        Text("Swipe, match, and connect horses for trail rides, companionship, and verified breeding inquiries.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(EquestrianTheme.slateSecondary)
                            .padding(.horizontal, 12)
                    }
                    .padding(.top, 24)

                    // Instant Skip-Auth Button
                    Button {
                        appState.currentUser = MockSampleData.currentUser
                        if appState.myHorses.isEmpty {
                            appState.myHorses = [MockSampleData.myHorse]
                            appState.activeHorseID = MockSampleData.myHorse.id
                        }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            appState.isAuthenticated = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                            Text("Skip Login & Explore App Now")
                                .fontWeight(.heavy)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(EquestrianTheme.brandGradient))
                        .shadow(color: EquestrianTheme.tinderRed.opacity(0.35), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("quickDemoLoginButton")

                    Picker("Authentication Mode", selection: $isSignUpMode) {
                        Text("Sign Up").tag(true)
                        Text("Log In").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("authModePicker")

                    VStack(spacing: 12) {
                        if isSignUpMode {
                            TextField("Owner / Handler Name", text: $displayName)
                                .textFieldStyle(.plain)
                                .padding(13)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                .accessibilityIdentifier("displayNameField")
                        }

                        TextField("Email Address", text: $email)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .padding(13)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            .accessibilityIdentifier("emailField")

                        SecureField("Password (min 8 characters)", text: $password)
                            .textFieldStyle(.plain)
                            .padding(13)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            .accessibilityIdentifier("passwordField")
                    }

                    if let errorMessage = appState.authErrorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(EquestrianTheme.tinderRed)
                            .multilineTextAlignment(.center)
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
                                ProgressView().tint(EquestrianTheme.tinderRed)
                            }
                            Text(isSignUpMode ? "Create Account" : "Log In")
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(EquestrianTheme.tinderRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            Capsule()
                                .fill(Color.white)
                                .overlay(Capsule().stroke(EquestrianTheme.tinderRed, lineWidth: 1.5))
                        )
                    }
                    .buttonStyle(.plain)
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
                    .frame(height: 46)
                    .clipShape(Capsule())
                    .accessibilityIdentifier("signInWithAppleButton")

                    AnimalWelfareNoticeBanner()

                    HStack(spacing: 16) {
                        Button("Terms of Use") {
                            showTermsSheet = true
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(EquestrianTheme.tinderRed)

                        Text("•")
                            .foregroundStyle(.secondary)

                        Button("Privacy Policy") {
                            showPrivacySheet = true
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(EquestrianTheme.tinderRed)
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 22)
            }
            .background(EquestrianTheme.screenBackground)
            .sheet(isPresented: $showTermsSheet) {
                NavigationStack {
                    TermsOfUseView()
                }
            }
            .sheet(isPresented: $showPrivacySheet) {
                NavigationStack {
                    PrivacyPolicyView()
                }
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
                    .foregroundStyle(EquestrianTheme.tinderRed)

                Text("Effective Version: \(SafetyConstants.currentTermsVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("""
                1. Eligibility & Conduct
                You must be at least 18 years old and the lawful owner or authorized handler of any horse profile you list on Stallion Match. Zero tolerance applies to abusive, fraudulent, or objectionable user-generated content.

                2. No In-App Payments or Animal Sales
                Stallion Match is a discovery and communication platform for trail riding companions, stablemates, and breeding inquiries. No financial transactions, stud fee payments, or animal sales are processed in the application.

                3. Animal Welfare & Veterinary Compliance
                Users are solely responsible for verifying health certificates, negative Coggins tests, vaccination records, and complying with all local, state, and federal animal-welfare and equine transport regulations.

                4. Content Moderation & Account Termination
                Reported profiles or messages are reviewed by our moderation team within 24 hours. Accounts violating these Terms will be suspended or permanently removed.
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
                    .foregroundStyle(EquestrianTheme.tinderRed)

                Text("""
                1. Information We Collect
                • Account credentials (email address, hashed password or Apple ID subject identifier).
                • Horse profile information and uploaded horse photographs.
                • Coarse city-level location (rounded to 2 decimal places / ~1.1 km resolution). Exact GPS coordinates of your barn or stable are never stored or shared.
                • Chat messages and safety/moderation reports.

                2. How We Use Information
                We use your data exclusively to provide horse discovery, matching, real-time messaging, and push notifications. We never sell your personal data or track you across third-party apps.

                3. Data Retention & Account Deletion
                You can permanently delete your account at any time in Settings → Delete Account. Account deletion immediately removes your user record, horse profiles, uploaded photos, swipes, matches, and messages from our database and storage.
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
