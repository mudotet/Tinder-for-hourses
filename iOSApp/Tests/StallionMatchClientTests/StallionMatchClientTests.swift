import Foundation
import SharedModels
@testable import StallionMatchClient
import XCTest

actor MockRefreshTransport: HTTPTransport {
    private var getMeAttemptCount = 0
    private var refreshCallCount = 0
    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return enc
    }()

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url ?? URL(string: "http://127.0.0.1:8080")!
        let path = url.path

        if path == "/api/v1/users/me" {
            getMeAttemptCount += 1
            let authHeader = request.value(forHTTPHeaderField: "Authorization") ?? ""
            if getMeAttemptCount == 1 || authHeader != "Bearer fresh-access-token-2" {
                let errData = try encoder.encode(
                    APIErrorResponse(code: .unauthorized, message: "Expired access token")
                )
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: 401,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                )!
                return (errData, response)
            }

            let userData = try encoder.encode(MockSampleData.currentUser)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (userData, response)
        }

        if path == "/api/v1/auth/refresh" {
            refreshCallCount += 1
            let tokenResponse = AuthTokenResponse(
                accessToken: "fresh-access-token-2",
                refreshToken: "rotated-refresh-token-2",
                expiresIn: 900,
                user: MockSampleData.currentUser
            )
            let data = try encoder.encode(tokenResponse)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (data, response)
        }

        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil)!
        return (Data(), response)
    }

    func stats() -> (getMeAttempts: Int, refreshCalls: Int) {
        (getMeAttemptCount, refreshCallCount)
    }
}

final class StallionMatchClientTests: XCTestCase {
    func testAPIClientAutomaticTokenRefreshAndRetryOnceOn401() async throws {
        let tokenStore = InMemoryTokenStore(
            initial: StoredTokenPair(
                accessToken: "expired-access-token-1",
                refreshToken: "initial-refresh-token-1"
            )
        )
        let transport = MockRefreshTransport()
        let client = APIClient(
            baseURL: URL(string: "http://127.0.0.1:8080")!,
            transport: transport,
            tokenStore: tokenStore
        )

        let me = try await client.getMe()
        XCTAssertEqual(me.email, MockSampleData.currentUser.email)

        let stats = await transport.stats()
        XCTAssertEqual(stats.getMeAttempts, 2, "Should retry the original request once after refreshing")
        XCTAssertEqual(stats.refreshCalls, 1, "Should invoke /api/v1/auth/refresh exactly once")

        let stored = await tokenStore.loadTokens()
        XCTAssertEqual(stored?.accessToken, "fresh-access-token-2")
        XCTAssertEqual(stored?.refreshToken, "rotated-refresh-token-2")
    }

    func testKeychainTokenStoreSaveLoadAndClear() async throws {
        let keychain = KeychainTokenStore(
            service: "com.stallionmatch.tests.\(UUID().uuidString)",
            account: "test_account"
        )
        let pair = StoredTokenPair(accessToken: "keychain-access", refreshToken: "keychain-refresh")
        try await keychain.saveTokens(pair)

        let loaded = await keychain.loadTokens()
        XCTAssertEqual(loaded, pair)

        try await keychain.clearTokens()
        let afterClear = await keychain.loadTokens()
        XCTAssertNil(afterClear)
    }

    @MainActor
    func testViewModelsSignUpCreateHorseDiscoverSwipeMatchAndChat() async throws {
        let mockClient = MockAPIClient(myHorses: [])
        let appState = AppStateViewModel(apiClient: mockClient)

        // 1. Sign up
        await appState.signUp(
            email: "clara@stallionmatch.com",
            password: "Password123!",
            displayName: "Clara Vance"
        )
        XCTAssertTrue(appState.isAuthenticated)
        XCTAssertEqual(appState.currentUser?.email, "clara@stallionmatch.com")

        // 2. Create horse profile
        let createdHorse = try await appState.createHorse(
            CreateHorseProfileRequest(
                name: "Apollo",
                age: 7,
                sex: .stallion,
                breed: "Hanoverian",
                color: "Dark Bay",
                heightHands: 16.3,
                disciplines: [.dressage, .jumping],
                temperamentTags: ["Calm", "Forward"],
                bio: "Warmblood stallion ready for trail rides and dressage sessions.",
                location: HorseLocationDTO(city: "Lexington, KY", coarseLatitude: 38.04, coarseLongitude: -84.50),
                lookingFor: [.trailBuddy, .breedingInquiry]
            )
        )
        XCTAssertEqual(appState.activeHorse?.id, createdHorse.id)

        // 3. Load discovery cards & swipe right to create a match
        let discoverVM = DiscoverViewModel(apiClient: mockClient)
        await discoverVM.loadCards(activeHorseID: createdHorse.id, reset: true)
        XCTAssertEqual(discoverVM.state, .loaded)
        XCTAssertEqual(discoverVM.cards.count, MockSampleData.discoveryHorses.count)

        let targetHorse = try XCTUnwrap(discoverVM.cards.first)
        await discoverVM.swipe(on: targetHorse, direction: .like, activeHorseID: createdHorse.id)
        XCTAssertNotNil(discoverVM.celebratedMatch)
        XCTAssertEqual(discoverVM.cards.count, MockSampleData.discoveryHorses.count - 1)

        // 4. Verify chat view model sends messages and blocks objectionable content
        let chatVM = ChatDetailViewModel(
            conversationSummary: MockSampleData.sampleConversationSummary,
            apiClient: mockClient
        )
        await chatVM.loadMessages()
        XCTAssertEqual(chatVM.messages.count, 2)

        chatVM.draftText = "Please send deposit now via wire transfer"
        await chatVM.sendMessage()
        XCTAssertNotNil(chatVM.safetyBannerMessage, "Objectionable payment solicitation must be rejected")
        XCTAssertEqual(chatVM.messages.count, 2)

        chatVM.draftText = "Looking forward to our trail ride on Saturday!"
        await chatVM.sendMessage()
        XCTAssertNil(chatVM.safetyBannerMessage)
        XCTAssertEqual(chatVM.messages.count, 3)

        // 5. Delete account clears session and horses
        try await appState.deleteAccount()
        XCTAssertFalse(appState.isAuthenticated)
        XCTAssertTrue(appState.myHorses.isEmpty)
    }
}
