import Crypto
import Fluent
import Foundation
@preconcurrency import JWT
import SharedModels
import Vapor

public struct AccessTokenPayload: JWTPayload, Authenticatable, @unchecked Sendable {
    public var sub: SubjectClaim
    public var exp: ExpirationClaim
    public var iat: IssuedAtClaim
    public var jti: IDClaim
    public var email: String

    public init(userID: UUID, email: String, issuedAt: Date = Date(), expiresInSeconds: TimeInterval = 900) {
        self.sub = SubjectClaim(value: userID.uuidString)
        self.iat = IssuedAtClaim(value: issuedAt)
        self.exp = ExpirationClaim(value: issuedAt.addingTimeInterval(expiresInSeconds))
        self.jti = IDClaim(value: UUID().uuidString)
        self.email = email
    }

    public func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }

    public func requireUserID() throws -> UUID {
        guard let uuid = UUID(uuidString: sub.value) else {
            throw AppError(.unauthorized, code: .unauthorized, message: "Invalid subject claim in token.")
        }
        return uuid
    }
}

public struct UserJWTAuthenticator: AsyncRequestAuthenticator, Sendable {
    public init() {}

    public func authenticate(request: Request) async throws {
        let rawToken: String
        if let bearer = request.headers.bearerAuthorization?.token, !bearer.isEmpty {
            rawToken = bearer
        } else if let queryToken = request.query[String.self, at: "token"], !queryToken.isEmpty {
            rawToken = queryToken
        } else {
            throw AppError(
                .unauthorized,
                code: .unauthorized,
                message: "Missing Bearer access token."
            )
        }

        let payload = try request.jwt.verify(rawToken, as: AccessTokenPayload.self)
        let userID = try payload.requireUserID()

        guard let user = try await UserModel.find(userID, on: request.db) else {
            throw AppError(
                .unauthorized,
                code: .unauthorized,
                message: "Authenticated user no longer exists."
            )
        }

        request.auth.login(payload)
        request.storage[AuthenticatedUserKey.self] = user
    }
}

public struct AuthenticatedUserKey: StorageKey {
    public typealias Value = UserModel
}

extension Request {
    public func requireAuthenticatedUser() throws -> UserModel {
        guard let user = storage[AuthenticatedUserKey.self] else {
            throw AppError(.unauthorized, code: .unauthorized, message: "Authentication required.")
        }
        return user
    }

    public func requireAuthenticatedUserID() throws -> UUID {
        let user = try requireAuthenticatedUser()
        return try user.requireID()
    }
}

public enum TokenHasher {
    public static func sha256Hex(_ rawToken: String) -> String {
        let digest = SHA256.hash(data: Data(rawToken.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func generateSecureRandomToken(byteCount: Int = 32) -> String {
        let bytes = [UInt8].random(count: byteCount)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
