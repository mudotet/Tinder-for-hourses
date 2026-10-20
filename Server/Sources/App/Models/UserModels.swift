import Fluent
import Foundation
import SharedModels
import Vapor

public final class UserModel: Model, @unchecked Sendable {
    public static let schema = "users"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "email")
    public var email: String

    @OptionalField(key: "password_hash")
    public var passwordHash: String?

    @OptionalField(key: "apple_subject")
    public var appleSubject: String?

    @OptionalField(key: "display_name")
    public var displayName: String?

    @Field(key: "is_email_verified")
    public var isEmailVerified: Bool

    @OptionalField(key: "email_verification_token_hash")
    public var emailVerificationTokenHash: String?

    @Field(key: "notifications_new_match")
    public var notificationsNewMatch: Bool

    @Field(key: "notifications_new_message")
    public var notificationsNewMessage: Bool

    @OptionalField(key: "accepted_terms_version")
    public var acceptedTermsVersion: String?

    @Children(for: \.$owner)
    public var horses: [HorseProfileModel]

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        email: String,
        passwordHash: String? = nil,
        appleSubject: String? = nil,
        displayName: String? = nil,
        isEmailVerified: Bool = false,
        emailVerificationTokenHash: String? = nil,
        notificationsNewMatch: Bool = true,
        notificationsNewMessage: Bool = true,
        acceptedTermsVersion: String? = nil
    ) {
        self.id = id
        self.email = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.passwordHash = passwordHash
        self.appleSubject = appleSubject
        self.displayName = displayName
        self.isEmailVerified = isEmailVerified
        self.emailVerificationTokenHash = emailVerificationTokenHash
        self.notificationsNewMatch = notificationsNewMatch
        self.notificationsNewMessage = notificationsNewMessage
        self.acceptedTermsVersion = acceptedTermsVersion
    }

    public func toDTO() throws -> UserDTO {
        let userID = try requireID()
        return UserDTO(
            id: userID,
            email: email,
            displayName: displayName,
            isEmailVerified: isEmailVerified,
            notificationsNewMatch: notificationsNewMatch,
            notificationsNewMessage: notificationsNewMessage,
            acceptedTermsVersion: acceptedTermsVersion,
            createdAt: createdAt ?? Date()
        )
    }
}

public final class RefreshTokenModel: Model, @unchecked Sendable {
    public static let schema = "refresh_tokens"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserModel

    @Field(key: "token_hash")
    public var tokenHash: String

    @Field(key: "expires_at")
    public var expiresAt: Date

    @Field(key: "is_revoked")
    public var isRevoked: Bool

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        userID: UUID,
        tokenHash: String,
        expiresAt: Date,
        isRevoked: Bool = false
    ) {
        self.id = id
        self.$user.id = userID
        self.tokenHash = tokenHash
        self.expiresAt = expiresAt
        self.isRevoked = isRevoked
    }
}

public final class DeviceTokenModel: Model, @unchecked Sendable {
    public static let schema = "device_tokens"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "user_id")
    public var user: UserModel

    @Field(key: "token")
    public var token: String

    @Field(key: "platform")
    public var platform: String

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        userID: UUID,
        token: String,
        platform: DevicePlatform = .ios
    ) {
        self.id = id
        self.$user.id = userID
        self.token = token
        self.platform = platform.rawValue
    }

    public func toDTO() throws -> DeviceTokenDTO {
        let tokenID = try requireID()
        let devicePlatform = DevicePlatform(rawValue: platform) ?? .ios
        return DeviceTokenDTO(
            id: tokenID,
            userID: $user.id,
            token: token,
            platform: devicePlatform,
            createdAt: createdAt ?? Date()
        )
    }
}
