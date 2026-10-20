@testable import App
import Fluent
import Foundation
@preconcurrency import JWT
import SharedModels
import XCTVapor

extension XCTHTTPRequest {
    mutating func encodeTestJSON<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        self.body = ByteBuffer(data: data)
        self.headers.contentType = .json
    }
}

extension XCTHTTPResponse {
    func decodeTestJSON<T: Decodable>(_ type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = Data(buffer: self.body)
        return try decoder.decode(type, from: data)
    }
}

final class AuthTests: XCTestCase {
    private var app: Application?

    override func setUp() async throws {
        let application = try await Application.make(.testing)
        try await configure(application)
        try await application.autoRevert()
        try await application.autoMigrate()
        await application.rateLimiter.reset()
        self.app = application
    }

    override func tearDown() async throws {
        if let app = self.app {
            try await app.asyncShutdown()
        }
        self.app = nil
    }

    private func requireApp() throws -> Application {
        guard let app else {
            throw Abort(.internalServerError, reason: "Test Application not initialized")
        }
        return app
    }

    func testSignUpLoginRefreshAndLogoutFlow() async throws {
        let app = try requireApp()

        // 1. Sign up
        let signUpPayload = SignUpRequest(
            email: "handler@stallionmatch.com",
            password: "StrongPassword123!",
            displayName: "Clara Vance"
        )

        var currentAccessToken = ""
        var currentRefreshToken = ""

        try await app.test(.POST, "api/v1/auth/signup", beforeRequest: { req in
            try req.encodeTestJSON(signUpPayload)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .created)
            let authResponse = try res.decodeTestJSON(AuthTokenResponse.self)
            XCTAssertEqual(authResponse.user.email, "handler@stallionmatch.com")
            XCTAssertEqual(authResponse.user.displayName, "Clara Vance")
            XCTAssertFalse(authResponse.accessToken.isEmpty)
            XCTAssertFalse(authResponse.refreshToken.isEmpty)
            currentAccessToken = authResponse.accessToken
            currentRefreshToken = authResponse.refreshToken
        })

        // 2. Duplicate sign up returns 409 Conflict with {code, message}
        try await app.test(.POST, "api/v1/auth/signup", beforeRequest: { req in
            try req.encodeTestJSON(signUpPayload)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .conflict)
            let err = try res.decodeTestJSON(APIErrorResponse.self)
            XCTAssertEqual(err.code, APIErrorCode.conflict.rawValue)
        })

        // 3. Login with valid credentials
        let loginPayload = LoginRequest(
            email: "handler@stallionmatch.com",
            password: "StrongPassword123!"
        )
        try await app.test(.POST, "api/v1/auth/login", beforeRequest: { req in
            try req.encodeTestJSON(loginPayload)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let authResponse = try res.decodeTestJSON(AuthTokenResponse.self)
            currentAccessToken = authResponse.accessToken
            currentRefreshToken = authResponse.refreshToken
        })

        // 4. Refresh token rotation: exchange currentRefreshToken for a new pair
        let firstRefreshToken = currentRefreshToken
        var rotatedRefreshToken = ""
        try await app.test(.POST, "api/v1/auth/refresh", beforeRequest: { req in
            try req.encodeTestJSON(RefreshTokenRequest(refreshToken: firstRefreshToken))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let authResponse = try res.decodeTestJSON(AuthTokenResponse.self)
            XCTAssertNotEqual(authResponse.refreshToken, firstRefreshToken)
            currentAccessToken = authResponse.accessToken
            rotatedRefreshToken = authResponse.refreshToken
        })

        // 5. Reusing the old rotated refresh token must fail with 401
        try await app.test(.POST, "api/v1/auth/refresh", beforeRequest: { req in
            try req.encodeTestJSON(RefreshTokenRequest(refreshToken: firstRefreshToken))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
            let err = try res.decodeTestJSON(APIErrorResponse.self)
            XCTAssertEqual(err.code, APIErrorCode.unauthorized.rawValue)
        })

        // 6. Access protected /api/v1/users/me with new access token
        try await app.test(.GET, "api/v1/users/me", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: currentAccessToken)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let me = try res.decodeTestJSON(UserDTO.self)
            XCTAssertEqual(me.email, "handler@stallionmatch.com")
        })

        // 7. Logout revokes the rotated refresh token
        try await app.test(.POST, "api/v1/auth/logout", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: currentAccessToken)
            try req.encodeTestJSON(LogoutRequest(refreshToken: rotatedRefreshToken))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
        })

        try await app.test(.POST, "api/v1/auth/refresh", beforeRequest: { req in
            try req.encodeTestJSON(RefreshTokenRequest(refreshToken: rotatedRefreshToken))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .unauthorized)
        })
    }

    func testSignInWithAppleTokenValidation() async throws {
        let app = try requireApp()

        let applePayload = LocalAppleIdentityPayload(
            subject: "apple-user-00192837",
            bundleID: "com.stallionmatch.app",
            email: "rider@privaterelay.appleid.com",
            emailVerified: true
        )
        let identityToken = try app.jwt.signers.sign(applePayload)

        let requestBody = AppleSignInRequest(
            identityToken: identityToken,
            authorizationCode: "code-xyz",
            fullName: "Sierra Sterling",
            email: "rider@privaterelay.appleid.com"
        )

        try await app.test(.POST, "api/v1/auth/apple", beforeRequest: { req in
            try req.encodeTestJSON(requestBody)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let auth = try res.decodeTestJSON(AuthTokenResponse.self)
            XCTAssertEqual(auth.user.email, "rider@privaterelay.appleid.com")
            XCTAssertEqual(auth.user.displayName, "Sierra Sterling")
            XCTAssertTrue(auth.user.isEmailVerified)
        })
    }
}
