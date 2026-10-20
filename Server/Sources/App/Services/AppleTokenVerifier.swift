import Foundation
@preconcurrency import JWT
import SharedModels
import Vapor

public struct VerifiedAppleIdentity: Sendable, Equatable {
    public let subject: String
    public let email: String?
    public let isEmailVerified: Bool

    public init(subject: String, email: String?, isEmailVerified: Bool) {
        self.subject = subject
        self.email = email
        self.isEmailVerified = isEmailVerified
    }
}

/// Signed JWT payload supported in `.testing` / `.development` environments for local Sign in with Apple verification.
public struct LocalAppleIdentityPayload: JWTPayload, @unchecked Sendable {
    public var sub: SubjectClaim
    public var iss: IssuerClaim
    public var aud: AudienceClaim
    public var exp: ExpirationClaim
    public var email: String?
    public var emailVerified: Bool?

    public init(
        subject: String,
        bundleID: String,
        email: String?,
        emailVerified: Bool = true,
        expiresAt: Date = Date().addingTimeInterval(3600)
    ) {
        self.sub = SubjectClaim(value: subject)
        self.iss = IssuerClaim(value: "https://appleid.apple.com")
        self.aud = AudienceClaim(value: [bundleID])
        self.exp = ExpirationClaim(value: expiresAt)
        self.email = email
        self.emailVerified = emailVerified
    }

    public func verify(using signer: JWTSigner) throws {
        guard iss.value == "https://appleid.apple.com" else {
            throw JWTError.claimVerificationFailure(name: "iss", reason: "Invalid Apple issuer")
        }
        try exp.verifyNotExpired()
    }
}

public protocol AppleIdentityVerifier: Sendable {
    func verify(identityToken: String, on request: Request) async throws -> VerifiedAppleIdentity
}

public struct DefaultAppleIdentityVerifier: AppleIdentityVerifier {
    public let bundleID: String

    public init(bundleID: String) {
        self.bundleID = bundleID
    }

    public func verify(identityToken: String, on request: Request) async throws -> VerifiedAppleIdentity {
        if request.application.environment != .production {
            if let localPayload = try? request.jwt.verify(identityToken, as: LocalAppleIdentityPayload.self) {
                try localPayload.aud.verifyIntendedAudience(includes: bundleID)
                return VerifiedAppleIdentity(
                    subject: localPayload.sub.value,
                    email: localPayload.email,
                    isEmailVerified: localPayload.emailVerified ?? true
                )
            }
        }

        do {
            let appleToken = try await request.jwt.apple.verify(
                identityToken,
                applicationIdentifier: bundleID
            ).get()
            let isVerified = appleToken.emailVerified?.value ?? (appleToken.email != nil)
            return VerifiedAppleIdentity(
                subject: appleToken.subject.value,
                email: appleToken.email,
                isEmailVerified: isVerified
            )
        } catch {
            throw AppError(
                .unauthorized,
                code: .unauthorized,
                message: "Invalid Sign in with Apple identity token."
            )
        }
    }
}

public struct AppleIdentityVerifierKey: StorageKey {
    public typealias Value = any AppleIdentityVerifier
}

extension Application {
    public var appleIdentityVerifier: any AppleIdentityVerifier {
        get {
            if let existing = storage[AppleIdentityVerifierKey.self] {
                return existing
            }
            let bundleID = Environment.get("APPLE_BUNDLE_ID") ?? "com.stallionmatch.app"
            let verifier = DefaultAppleIdentityVerifier(bundleID: bundleID)
            storage[AppleIdentityVerifierKey.self] = verifier
            return verifier
        }
        set {
            storage[AppleIdentityVerifierKey.self] = newValue
        }
    }
}
