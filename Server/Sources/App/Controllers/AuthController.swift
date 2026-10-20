import Crypto
import Fluent
import Foundation
@preconcurrency import JWT
import SharedModels
import Vapor

public struct AuthController: RouteCollection, Sendable {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let authRateLimit = RateLimitMiddleware(scope: "auth", maxRequests: 30, windowSeconds: 60)
        let publicAuth = routes.grouped("auth").grouped(authRateLimit)

        publicAuth.post("signup", use: signUp)
        publicAuth.post("login", use: login)
        publicAuth.post("apple", use: signInWithApple)
        publicAuth.post("refresh", use: refresh)
        publicAuth.post("verify-email", use: verifyEmail)

        let protected = routes.grouped(UserJWTAuthenticator())
        protected.grouped("auth").post("logout", use: logout)

        let users = protected.grouped("users")
        users.get("me", use: getMe)
        users.patch("me", use: updateMe)
        users.post("me", "devices", use: registerDeviceToken)
        users.delete("me", use: deleteAccount)
    }

    @Sendable
    public func signUp(req: Request) async throws -> Response {
        try req.validateJSON { validations in
            validations.add("email", as: String.self, is: .email)
            validations.add("password", as: String.self, is: .count(8...128))
        }
        let input = try req.decodeJSON(SignUpRequest.self)
        let normalizedEmail = input.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let existingCount = try await UserModel.query(on: req.db)
            .filter(\.$email == normalizedEmail)
            .count()
        guard existingCount == 0 else {
            throw AppError(
                .conflict,
                code: .conflict,
                message: "An account with that email address already exists."
            )
        }

        let passwordHash = try Bcrypt.hash(input.password)
        let rawVerificationToken = TokenHasher.generateSecureRandomToken(byteCount: 24)
        let verificationTokenHash = TokenHasher.sha256Hex(rawVerificationToken)

        let user = UserModel(
            email: normalizedEmail,
            passwordHash: passwordHash,
            displayName: input.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
            isEmailVerified: false,
            emailVerificationTokenHash: verificationTokenHash,
            acceptedTermsVersion: SafetyConstants.currentTermsVersion
        )
        try await user.save(on: req.db)

        let baseURL = Environment.get("PUBLIC_BASE_URL") ?? "http://127.0.0.1:8080"
        req.logger.info(
            "[EmailVerification] Verify email for \(normalizedEmail): \(baseURL)/api/v1/auth/verify-email?token=\(rawVerificationToken)"
        )

        let tokenResponse = try await issueTokens(for: user, on: req)
        return try req.encodeJSON(tokenResponse, status: .created)
    }

    @Sendable
    public func login(req: Request) async throws -> Response {
        try req.validateJSON { validations in
            validations.add("email", as: String.self, is: .email)
            validations.add("password", as: String.self, is: !.empty)
        }
        let input = try req.decodeJSON(LoginRequest.self)
        let normalizedEmail = input.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let user = try await UserModel.query(on: req.db)
                .filter(\.$email == normalizedEmail)
                .first(),
            let passwordHash = user.passwordHash,
            try Bcrypt.verify(input.password, created: passwordHash)
        else {
            throw AppError(
                .unauthorized,
                code: .unauthorized,
                message: "Invalid email or password."
            )
        }

        let tokenResponse = try await issueTokens(for: user, on: req)
        return try req.encodeJSON(tokenResponse)
    }

    @Sendable
    public func signInWithApple(req: Request) async throws -> Response {
        try req.validateJSON { validations in
            validations.add("identityToken", as: String.self, is: !.empty)
        }
        let input = try req.decodeJSON(AppleSignInRequest.self)

        let identity = try await req.application.appleIdentityVerifier.verify(
            identityToken: input.identityToken,
            on: req
        )

        var user = try await UserModel.query(on: req.db)
            .filter(\.$appleSubject == identity.subject)
            .first()

        if user == nil, let email = (identity.email ?? input.email)?.lowercased() {
            user = try await UserModel.query(on: req.db)
                .filter(\.$email == email)
                .first()
            if let existingUser = user {
                existingUser.appleSubject = identity.subject
                existingUser.isEmailVerified = existingUser.isEmailVerified || identity.isEmailVerified
                try await existingUser.save(on: req.db)
            }
        }

        if user == nil {
            let resolvedEmail =
                (identity.email ?? input.email)?.lowercased()
                ?? "apple_\(identity.subject.prefix(16))@privaterelay.appleid.com"
            let newUser = UserModel(
                email: resolvedEmail,
                appleSubject: identity.subject,
                displayName: input.fullName,
                isEmailVerified: identity.isEmailVerified,
                acceptedTermsVersion: SafetyConstants.currentTermsVersion
            )
            try await newUser.save(on: req.db)
            user = newUser
        }

        guard let authenticatedUser = user else {
            throw AppError(.internalServerError, code: .internalError, message: "Failed to resolve Apple user.")
        }

        let tokenResponse = try await issueTokens(for: authenticatedUser, on: req)
        return try req.encodeJSON(tokenResponse)
    }

    @Sendable
    public func refresh(req: Request) async throws -> Response {
        try req.validateJSON { validations in
            validations.add("refreshToken", as: String.self, is: !.empty)
        }
        let input = try req.decodeJSON(RefreshTokenRequest.self)
        let incomingHash = TokenHasher.sha256Hex(input.refreshToken)

        let tokenResponse: AuthTokenResponse = try await req.db.transaction { tx in
            guard
                let storedToken = try await RefreshTokenModel.query(on: tx)
                    .filter(\.$tokenHash == incomingHash)
                    .with(\.$user)
                    .first()
            else {
                throw AppError(
                    .unauthorized,
                    code: .unauthorized,
                    message: "Invalid refresh token."
                )
            }

            if storedToken.isRevoked || storedToken.expiresAt <= Date() {
                storedToken.isRevoked = true
                try await storedToken.save(on: tx)
                throw AppError(
                    .unauthorized,
                    code: .unauthorized,
                    message: "Refresh token has expired or been revoked."
                )
            }

            // Rotate refresh token: revoke the old one and issue a new one atomically
            storedToken.isRevoked = true
            try await storedToken.save(on: tx)

            return try await issueTokens(for: storedToken.user, on: req, database: tx)
        }

        return try req.encodeJSON(tokenResponse)
    }

    @Sendable
    public func verifyEmail(req: Request) async throws -> Response {
        try req.validateJSON { validations in
            validations.add("token", as: String.self, is: !.empty)
        }
        let input = try req.decodeJSON(VerifyEmailRequest.self)
        let tokenHash = TokenHasher.sha256Hex(input.token)

        guard
            let user = try await UserModel.query(on: req.db)
                .filter(\.$emailVerificationTokenHash == tokenHash)
                .first()
        else {
            throw AppError(
                .badRequest,
                code: .validationFailed,
                message: "Invalid or expired email verification token."
            )
        }

        user.isEmailVerified = true
        user.emailVerificationTokenHash = nil
        try await user.save(on: req.db)

        return try req.encodeJSON(StatusResponse(status: "ok", message: "Email verified successfully."))
    }

    @Sendable
    public func logout(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        if let input = try? req.decodeJSON(LogoutRequest.self), !input.refreshToken.isEmpty {
            let hash = TokenHasher.sha256Hex(input.refreshToken)
            if let token = try await RefreshTokenModel.query(on: req.db)
                .filter(\.$tokenHash == hash)
                .filter(\.$user.$id == userID)
                .first()
            {
                token.isRevoked = true
                try await token.save(on: req.db)
            }
        } else {
            let tokens = try await RefreshTokenModel.query(on: req.db)
                .filter(\.$user.$id == userID)
                .filter(\.$isRevoked == false)
                .all()
            for token in tokens {
                token.isRevoked = true
                try await token.save(on: req.db)
            }
        }

        return try req.encodeJSON(StatusResponse(status: "ok", message: "Logged out successfully."))
    }

    @Sendable
    public func getMe(req: Request) async throws -> Response {
        let user = try req.requireAuthenticatedUser()
        return try req.encodeJSON(try user.toDTO())
    }

    @Sendable
    public func updateMe(req: Request) async throws -> Response {
        let user = try req.requireAuthenticatedUser()
        let input = try req.decodeJSON(UpdateUserSettingsRequest.self)

        if let displayName = input.displayName {
            let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count <= 80 else {
                throw AppError(
                    .badRequest,
                    code: .validationFailed,
                    message: "Display name must be 80 characters or fewer."
                )
            }
            user.displayName = trimmed.isEmpty ? nil : trimmed
        }
        if let notificationsNewMatch = input.notificationsNewMatch {
            user.notificationsNewMatch = notificationsNewMatch
        }
        if let notificationsNewMessage = input.notificationsNewMessage {
            user.notificationsNewMessage = notificationsNewMessage
        }
        if let acceptedTermsVersion = input.acceptedTermsVersion {
            user.acceptedTermsVersion = acceptedTermsVersion
        }

        try await user.save(on: req.db)
        return try req.encodeJSON(try user.toDTO())
    }

    @Sendable
    public func registerDeviceToken(req: Request) async throws -> Response {
        try req.validateJSON { validations in
            validations.add("token", as: String.self, is: .count(8...512))
        }
        let userID = try req.requireAuthenticatedUserID()
        let input = try req.decodeJSON(RegisterDeviceTokenRequest.self)
        let trimmedToken = input.token.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = try await DeviceTokenModel.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$token == trimmedToken)
            .first()
        {
            existing.platform = input.platform.rawValue
            try await existing.save(on: req.db)
            return try req.encodeJSON(try existing.toDTO())
        }

        let deviceToken = DeviceTokenModel(
            userID: userID,
            token: trimmedToken,
            platform: input.platform
        )
        try await deviceToken.save(on: req.db)
        return try req.encodeJSON(try deviceToken.toDTO())
    }

    @Sendable
    public func deleteAccount(req: Request) async throws -> Response {
        let user = try req.requireAuthenticatedUser()
        let userID = try user.requireID()

        let horses = try await HorseProfileModel.query(on: req.db)
            .filter(\.$owner.$id == userID)
            .with(\.$photos)
            .all()

        for horse in horses {
            for photo in horse.photos {
                try? await req.application.storageService.deleteFile(key: photo.storageKey)
            }
        }

        try await user.delete(on: req.db)
        return try req.encodeJSON(StatusResponse(status: "ok", message: "Account and all associated data deleted."))
    }

    // MARK: - Helpers

    private func issueTokens(
        for user: UserModel,
        on req: Request,
        database: Database? = nil
    ) async throws -> AuthTokenResponse {
        let db = database ?? req.db
        let userID = try user.requireID()
        let accessExpirationSeconds = Int(Environment.get("JWT_ACCESS_EXPIRATION_SECONDS") ?? "900") ?? 900
        let refreshExpirationDays = Int(Environment.get("JWT_REFRESH_EXPIRATION_DAYS") ?? "30") ?? 30

        let accessPayload = AccessTokenPayload(
            userID: userID,
            email: user.email,
            expiresInSeconds: TimeInterval(accessExpirationSeconds)
        )
        let accessToken = try req.jwt.sign(accessPayload)

        let rawRefreshToken = TokenHasher.generateSecureRandomToken(byteCount: 32)
        let refreshTokenHash = TokenHasher.sha256Hex(rawRefreshToken)
        let refreshExpiresAt = Date().addingTimeInterval(TimeInterval(refreshExpirationDays * 86_400))

        let refreshModel = RefreshTokenModel(
            userID: userID,
            tokenHash: refreshTokenHash,
            expiresAt: refreshExpiresAt,
            isRevoked: false
        )
        try await refreshModel.save(on: db)

        return AuthTokenResponse(
            accessToken: accessToken,
            refreshToken: rawRefreshToken,
            expiresIn: accessExpirationSeconds,
            user: try user.toDTO()
        )
    }
}
