import Foundation

/// Request payload for registering a new user account via email and password.
public struct SignUpRequest: Codable, Sendable, Equatable {
    public let email: String
    public let password: String
    public let displayName: String?

    public init(email: String, password: String, displayName: String? = nil) {
        self.email = email
        self.password = password
        self.displayName = displayName
    }
}

/// Request payload for authenticating an existing user via email and password.
public struct LoginRequest: Codable, Sendable, Equatable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

/// Request payload for authenticating via Sign in with Apple.
public struct AppleSignInRequest: Codable, Sendable, Equatable {
    public let identityToken: String
    public let authorizationCode: String?
    public let fullName: String?
    public let email: String?

    public init(
        identityToken: String,
        authorizationCode: String? = nil,
        fullName: String? = nil,
        email: String? = nil
    ) {
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.fullName = fullName
        self.email = email
    }
}

/// Request payload for exchanging a refresh token for a rotated token pair.
public struct RefreshTokenRequest: Codable, Sendable, Equatable {
    public let refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

/// Request payload for revoking an active refresh token during logout.
public struct LogoutRequest: Codable, Sendable, Equatable {
    public let refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

/// Request payload for verifying an email verification token.
public struct VerifyEmailRequest: Codable, Sendable, Equatable {
    public let token: String

    public init(token: String) {
        self.token = token
    }
}

/// Authenticated user profile DTO.
public struct UserDTO: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let email: String
    public let displayName: String?
    public let isEmailVerified: Bool
    public let notificationsNewMatch: Bool
    public let notificationsNewMessage: Bool
    public let acceptedTermsVersion: String?
    public let createdAt: Date

    public init(
        id: UUID,
        email: String,
        displayName: String? = nil,
        isEmailVerified: Bool = false,
        notificationsNewMatch: Bool = true,
        notificationsNewMessage: Bool = true,
        acceptedTermsVersion: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.isEmailVerified = isEmailVerified
        self.notificationsNewMatch = notificationsNewMatch
        self.notificationsNewMessage = notificationsNewMessage
        self.acceptedTermsVersion = acceptedTermsVersion
        self.createdAt = createdAt
    }
}

/// Response returned after successful signup, login, Apple Sign In, or token refresh.
public struct AuthTokenResponse: Codable, Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresIn: Int
    public let user: UserDTO

    public init(
        accessToken: String,
        refreshToken: String,
        expiresIn: Int = 900,
        user: UserDTO
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.user = user
    }
}

/// Request payload for updating user preferences and notification settings.
public struct UpdateUserSettingsRequest: Codable, Sendable, Equatable {
    public let displayName: String?
    public let notificationsNewMatch: Bool?
    public let notificationsNewMessage: Bool?
    public let acceptedTermsVersion: String?

    public init(
        displayName: String? = nil,
        notificationsNewMatch: Bool? = nil,
        notificationsNewMessage: Bool? = nil,
        acceptedTermsVersion: String? = nil
    ) {
        self.displayName = displayName
        self.notificationsNewMatch = notificationsNewMatch
        self.notificationsNewMessage = notificationsNewMessage
        self.acceptedTermsVersion = acceptedTermsVersion
    }
}

/// Supported push notification platforms.
public enum DevicePlatform: String, Codable, Sendable, CaseIterable, Hashable {
    case ios
}

/// Request payload for registering an APNs device token.
public struct RegisterDeviceTokenRequest: Codable, Sendable, Equatable {
    public let token: String
    public let platform: DevicePlatform

    public init(token: String, platform: DevicePlatform = .ios) {
        self.token = token
        self.platform = platform
    }
}

/// Registered device token DTO.
public struct DeviceTokenDTO: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let userID: UUID
    public let token: String
    public let platform: DevicePlatform
    public let createdAt: Date

    public init(
        id: UUID,
        userID: UUID,
        token: String,
        platform: DevicePlatform = .ios,
        createdAt: Date
    ) {
        self.id = id
        self.userID = userID
        self.token = token
        self.platform = platform
        self.createdAt = createdAt
    }
}
