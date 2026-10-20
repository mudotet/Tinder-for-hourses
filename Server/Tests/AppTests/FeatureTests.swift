@testable import App
import Fluent
import Foundation
import NIOCore
import SharedModels
import Vapor
import WebSocketKit
import XCTVapor

final class FeatureTests: XCTestCase {
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

    private func signUpUser(
        app: Application,
        email: String,
        displayName: String
    ) async throws -> AuthTokenResponse {
        var result: AuthTokenResponse?
        let payload = SignUpRequest(email: email, password: "Password123!", displayName: displayName)
        try await app.test(.POST, "api/v1/auth/signup", beforeRequest: { req in
            try req.encodeTestJSON(payload)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .created)
            result = try res.decodeTestJSON(AuthTokenResponse.self)
        })
        guard let unwrapped = result else {
            throw Abort(.internalServerError, reason: "Failed to sign up test user")
        }
        return unwrapped
    }

    private func createHorse(
        app: Application,
        token: String,
        name: String,
        age: Int = 6,
        sex: HorseSex = .stallion,
        breed: String = "Warmblood",
        disciplines: [HorseDiscipline] = [.dressage, .jumping],
        lookingFor: [LookingForCategory] = [.ridingCompanion, .breedingInquiry],
        lat: Double = 38.0464,
        lon: Double = -84.4970
    ) async throws -> HorseProfileDTO {
        var created: HorseProfileDTO?
        let requestPayload = CreateHorseProfileRequest(
            name: name,
            age: age,
            sex: sex,
            breed: breed,
            color: "Bay",
            heightHands: 16.2,
            disciplines: disciplines,
            temperamentTags: ["Calm", "Athletic"],
            bio: "\(name) is a well-trained equine partner ready for trail and arena sessions.",
            location: HorseLocationDTO(city: "Lexington, KY", coarseLatitude: lat, coarseLongitude: lon),
            lookingFor: lookingFor,
            healthInfo: HorseHealthInfoDTO(cogginsTestDate: Date(), vaccinationsUpToDate: true),
            pedigree: "Sire: Champion Line"
        )

        try await app.test(.POST, "api/v1/horses", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: token)
            try req.encodeTestJSON(requestPayload)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .created)
            created = try res.decodeTestJSON(HorseProfileDTO.self)
        })

        guard let horse = created else {
            throw Abort(.internalServerError, reason: "Failed to create horse")
        }
        return horse
    }

    // MARK: - Phase 2: Horse Profiles, Photos & StorageService

    func testHorseCRUDPhotoUploadReorderAndIDORProtection() async throws {
        let app = try requireApp()
        let user1 = try await signUpUser(app: app, email: "owner1@stallionmatch.com", displayName: "Owner One")
        let user2 = try await signUpUser(app: app, email: "owner2@stallionmatch.com", displayName: "Owner Two")

        // Create horse with exact coordinates and verify coarse rounding
        let horse = try await createHorse(
            app: app,
            token: user1.accessToken,
            name: "Thunderbolt",
            lat: 38.048912,
            lon: -84.501928
        )
        XCTAssertEqual(horse.location.coarseLatitude, 38.05, accuracy: 0.0001)
        XCTAssertEqual(horse.location.coarseLongitude, -84.50, accuracy: 0.0001)

        // IDOR check: user2 cannot update user1's horse
        try await app.test(.PATCH, "api/v1/horses/\(horse.id.uuidString)", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: user2.accessToken)
            try req.encodeTestJSON(UpdateHorseProfileRequest(name: "Hacked Name"))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .forbidden)
        })

        // Upload 2 photos via StorageService
        var photo1ID = UUID()
        var photo2ID = UUID()

        try await app.test(.POST, "api/v1/horses/\(horse.id.uuidString)/photos", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: user1.accessToken)
            req.headers.contentType = .jpeg
            req.body = ByteBuffer(bytes: [0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02, 0x03, 0xFF, 0xD9])
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .created)
            let photo = try res.decodeTestJSON(HorsePhotoDTO.self)
            XCTAssertEqual(photo.position, 0)
            photo1ID = photo.id
        })

        try await app.test(.POST, "api/v1/horses/\(horse.id.uuidString)/photos", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: user1.accessToken)
            req.headers.contentType = .jpeg
            req.body = ByteBuffer(bytes: [0xFF, 0xD8, 0xFF, 0xE0, 0x04, 0x05, 0x06, 0xFF, 0xD9])
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .created)
            let photo = try res.decodeTestJSON(HorsePhotoDTO.self)
            XCTAssertEqual(photo.position, 1)
            photo2ID = photo.id
        })

        // Reorder photos: [photo2ID, photo1ID]
        try await app.test(.PUT, "api/v1/horses/\(horse.id.uuidString)/photos/reorder", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: user1.accessToken)
            try req.encodeTestJSON(ReorderHorsePhotosRequest(photoIDs: [photo2ID, photo1ID]))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let reordered = try res.decodeTestJSON([HorsePhotoDTO].self)
            XCTAssertEqual(reordered.map(\.id), [photo2ID, photo1ID])
            XCTAssertEqual(reordered.map(\.position), [0, 1])
        })
    }

    // MARK: - Phase 3: Discovery Filters, Pagination, Blocking, Reporting & Atomic Concurrent Swipes

    func testDiscoveryFiltersPaginationBlockingAndReporting() async throws {
        let app = try requireApp()
        let userA = try await signUpUser(app: app, email: "alice@stallionmatch.com", displayName: "Alice")
        let userB = try await signUpUser(app: app, email: "bob@stallionmatch.com", displayName: "Bob")
        let userC = try await signUpUser(app: app, email: "carol@stallionmatch.com", displayName: "Carol")

        let aliceHorse = try await createHorse(
            app: app,
            token: userA.accessToken,
            name: "Starlight",
            sex: .mare,
            lat: 38.04,
            lon: -84.50
        )

        let bobHorse1 = try await createHorse(
            app: app,
            token: userB.accessToken,
            name: "Orion",
            age: 5,
            sex: .stallion,
            breed: "Arabian",
            disciplines: [.endurance],
            lookingFor: [.trailBuddy],
            lat: 38.06,
            lon: -84.52
        )

        let bobHorse2 = try await createHorse(
            app: app,
            token: userB.accessToken,
            name: "Atlas",
            age: 9,
            sex: .gelding,
            breed: "Quarter Horse",
            disciplines: [.western],
            lookingFor: [.ridingCompanion],
            lat: 38.05,
            lon: -84.51
        )

        let carolFarHorse = try await createHorse(
            app: app,
            token: userC.accessToken,
            name: "Pacific Breeze",
            age: 7,
            sex: .stallion,
            breed: "Thoroughbred",
            disciplines: [.racing],
            lookingFor: [.breedingInquiry],
            lat: 34.05, // Los Angeles, far from Lexington KY
            lon: -118.24
        )

        // 1. Filter by maxDistanceKm=50 from Lexington KY -> excludes carolFarHorse
        try await app.test(
            .GET,
            "api/v1/discovery?activeHorseID=\(aliceHorse.id.uuidString)&maxDistanceKm=50",
            beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: userA.accessToken)
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let page = try res.decodeTestJSON(CursorPage<HorseProfileDTO>.self)
                let ids = Set(page.items.map(\.id))
                XCTAssertTrue(ids.contains(bobHorse1.id))
                XCTAssertTrue(ids.contains(bobHorse2.id))
                XCTAssertFalse(ids.contains(carolFarHorse.id))
                XCTAssertFalse(ids.contains(aliceHorse.id))
            }
        )

        // 2. Cursor pagination with limit=1
        var firstCursor: String?
        var firstPageHorseID: UUID?
        try await app.test(
            .GET,
            "api/v1/discovery?activeHorseID=\(aliceHorse.id.uuidString)&maxDistanceKm=50&limit=1",
            beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: userA.accessToken)
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let page = try res.decodeTestJSON(CursorPage<HorseProfileDTO>.self)
                XCTAssertEqual(page.items.count, 1)
                XCTAssertNotNil(page.nextCursor)
                firstCursor = page.nextCursor
                firstPageHorseID = page.items.first?.id
            }
        )

        if let cursor = firstCursor {
            try await app.test(
                .GET,
                "api/v1/discovery?activeHorseID=\(aliceHorse.id.uuidString)&maxDistanceKm=50&limit=1&cursor=\(cursor)",
                beforeRequest: { req in
                    req.headers.bearerAuthorization = BearerAuthorization(token: userA.accessToken)
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let page = try res.decodeTestJSON(CursorPage<HorseProfileDTO>.self)
                    XCTAssertEqual(page.items.count, 1)
                    XCTAssertNotEqual(page.items.first?.id, firstPageHorseID)
                    XCTAssertNil(page.nextCursor)
                }
            )
        }

        // 3. Report Carol's horse -> creates Report and ModerationQueue entry
        try await app.test(.POST, "api/v1/reports", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: userA.accessToken)
            try req.encodeTestJSON(
                CreateReportRequest(
                    targetType: .horse,
                    targetID: carolFarHorse.id,
                    reason: .animalWelfareConcern,
                    details: "Suspicious health listing details."
                )
            )
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .created)
            let report = try res.decodeTestJSON(ReportDTO.self)
            XCTAssertEqual(report.status, .pending)
        })

        let queueCount = try await ModerationQueueModel.query(on: app.db).count()
        XCTAssertEqual(queueCount, 1)

        // 4. Block Bob -> Bob's horses immediately disappear from Alice's discovery
        try await app.test(.POST, "api/v1/blocks", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: userA.accessToken)
            try req.encodeTestJSON(BlockUserRequest(blockedUserID: userB.user.id, reason: "Not a match"))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .created)
        })

        try await app.test(
            .GET,
            "api/v1/discovery?activeHorseID=\(aliceHorse.id.uuidString)&maxDistanceKm=50",
            beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: userA.accessToken)
            },
            afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                let page = try res.decodeTestJSON(CursorPage<HorseProfileDTO>.self)
                XCTAssertTrue(page.items.isEmpty)
            }
        )
    }

    func testConcurrentMutualLikesCreateExactlyOneMatch() async throws {
        let app = try requireApp()
        let user1 = try await signUpUser(app: app, email: "concurrent1@stallionmatch.com", displayName: "Rider 1")
        let user2 = try await signUpUser(app: app, email: "concurrent2@stallionmatch.com", displayName: "Rider 2")

        let horse1 = try await createHorse(app: app, token: user1.accessToken, name: "Apollo")
        let horse2 = try await createHorse(app: app, token: user2.accessToken, name: "Athena", sex: .mare)

        // Fire 6 concurrent swipe requests (3 from horse1->horse2 and 3 from horse2->horse1) simultaneously
        try await withThrowingTaskGroup(of: SwipeResponse.self) { group in
            for i in 0..<6 {
                let isFirstSwiper = (i % 2 == 0)
                let token = isFirstSwiper ? user1.accessToken : user2.accessToken
                let swiperID = isFirstSwiper ? horse1.id : horse2.id
                let targetID = isFirstSwiper ? horse2.id : horse1.id

                group.addTask {
                    var swipeResult: SwipeResponse?
                    try await app.test(.POST, "api/v1/swipes", beforeRequest: { req in
                        req.headers.bearerAuthorization = BearerAuthorization(token: token)
                        try req.encodeTestJSON(
                            SwipeRequest(
                                swiperHorseID: swiperID,
                                targetHorseID: targetID,
                                direction: .like
                            )
                        )
                    }, afterResponse: { res async throws in
                        XCTAssertEqual(res.status, .ok)
                        swipeResult = try res.decodeTestJSON(SwipeResponse.self)
                    })
                    guard let unwrapped = swipeResult else {
                        throw Abort(.internalServerError)
                    }
                    return unwrapped
                }
            }

            var responses: [SwipeResponse] = []
            for try await res in group {
                responses.append(res)
            }
            XCTAssertEqual(responses.count, 6)
            XCTAssertTrue(responses.contains(where: { $0.isMatch && $0.match != nil }))
        }

        // Database must contain EXACTLY 1 Match and 1 Conversation and 2 Swipes
        let matchCount = try await MatchModel.query(on: app.db).count()
        let conversationCount = try await ConversationModel.query(on: app.db).count()
        let swipeCount = try await SwipeModel.query(on: app.db).count()

        XCTAssertEqual(matchCount, 1)
        XCTAssertEqual(conversationCount, 1)
        XCTAssertEqual(swipeCount, 2)
    }

    // MARK: - Phase 4 & Phase 7: Real-Time WebSocket Chat (2 Clients), Read Receipts, Push & Account Deletion

    func testWebSocketTwoClientsChatReadReceiptsAndAccountDeletion() async throws {
        let app = try requireApp()
        app.environment.arguments = ["vapor"]
        app.http.server.configuration.hostname = "127.0.0.1"
        app.http.server.configuration.port = 0
        try await app.startup()

        guard let localPort = app.http.server.shared.localAddress?.port else {
            XCTFail("Failed to bind local test port for WebSocket test")
            return
        }

        let user1 = try await signUpUser(app: app, email: "ws1@stallionmatch.com", displayName: "WS User 1")
        let user2 = try await signUpUser(app: app, email: "ws2@stallionmatch.com", displayName: "WS User 2")

        let horse1 = try await createHorse(app: app, token: user1.accessToken, name: "Comet")
        let horse2 = try await createHorse(app: app, token: user2.accessToken, name: "Nova", sex: .mare)

        // Mutual swipe to create Match + Conversation
        try await app.test(.POST, "api/v1/swipes", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: user1.accessToken)
            try req.encodeTestJSON(SwipeRequest(swiperHorseID: horse1.id, targetHorseID: horse2.id, direction: .like))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
        })

        var conversationID = UUID()
        try await app.test(.POST, "api/v1/swipes", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: user2.accessToken)
            try req.encodeTestJSON(SwipeRequest(swiperHorseID: horse2.id, targetHorseID: horse1.id, direction: .like))
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let swipeRes = try res.decodeTestJSON(SwipeResponse.self)
            XCTAssertTrue(swipeRes.isMatch)
            conversationID = try XCTUnwrap(swipeRes.match?.conversationID)
        })

        // Connect two real WebSocket clients to /api/v1/ws
        actor FrameCollector {
            var messages: [WebSocketMessage] = []
            func append(_ msg: WebSocketMessage) {
                messages.append(msg)
            }
            func all() -> [WebSocketMessage] {
                messages
            }
        }

        let client1Collector = FrameCollector()
        let client2Collector = FrameCollector()

        let wsURL1 = "ws://127.0.0.1:\(localPort)/api/v1/ws?token=\(user1.accessToken)"
        let wsURL2 = "ws://127.0.0.1:\(localPort)/api/v1/ws?token=\(user2.accessToken)"

        let ws1Promise = app.eventLoopGroup.next().makePromise(of: WebSocket.self)
        WebSocket.connect(to: wsURL1, on: app.eventLoopGroup) { ws in
            ws.onText { _, text in
                if let msg = try? WebSocketHub.decodeMessage(text) {
                    Task { await client1Collector.append(msg) }
                }
            }
            ws1Promise.succeed(ws)
        }.cascadeFailure(to: ws1Promise)

        let ws2Promise = app.eventLoopGroup.next().makePromise(of: WebSocket.self)
        WebSocket.connect(to: wsURL2, on: app.eventLoopGroup) { ws in
            ws.onText { _, text in
                if let msg = try? WebSocketHub.decodeMessage(text) {
                    Task { await client2Collector.append(msg) }
                }
            }
            ws2Promise.succeed(ws)
        }.cascadeFailure(to: ws2Promise)

        let ws1 = try await ws1Promise.futureResult.get()
        let ws2 = try await ws2Promise.futureResult.get()

        // Client 1 sends a typing indicator and a real-time chat message to Client 2
        if let typingFrame = WebSocketHub.encodeMessage(
            .typing(WSTypingPayload(conversationID: conversationID, horseID: horse1.id, isTyping: true))
        ) {
            try await ws1.send(typingFrame)
        }

        if let sendFrame = WebSocketHub.encodeMessage(
            .sendMessage(
                WSSendMessagePayload(
                    conversationID: conversationID,
                    senderHorseID: horse1.id,
                    body: "Hi Nova! Would love to go for a trail ride this weekend.",
                    clientMessageID: UUID()
                )
            )
        ) {
            try await ws1.send(sendFrame)
        }

        // Wait briefly for async delivery
        try await Task.sleep(nanoseconds: 250_000_000)

        let client2Frames = await client2Collector.all()
        let receivedMessage = client2Frames.compactMap { frame -> MessageDTO? in
            if case .messageReceived(let msg) = frame { return msg }
            return nil
        }.first
        XCTAssertNotNil(receivedMessage)
        XCTAssertEqual(receivedMessage?.body, "Hi Nova! Would love to go for a trail ride this weekend.")

        // Client 2 sends a markRead frame over WebSocket
        if let markReadFrame = WebSocketHub.encodeMessage(
            .markRead(WSMarkReadPayload(conversationID: conversationID, upToMessageID: receivedMessage?.id))
        ) {
            try await ws2.send(markReadFrame)
        }

        try await Task.sleep(nanoseconds: 250_000_000)

        let client1Frames = await client1Collector.all()
        let receivedReadReceipt = client1Frames.contains { frame in
            if case .readReceipt(let receipt) = frame {
                return receipt.conversationID == conversationID && receipt.readerUserID == user2.user.id
            }
            return false
        }
        XCTAssertTrue(receivedReadReceipt)

        try? await ws1.close()
        try? await ws2.close()

        // Verify APNs push notifications were recorded for both NEW_MATCH and NEW_MESSAGE
        let notifications = await app.pushNotificationService.recordedNotifications()
        XCTAssertTrue(notifications.contains(where: { $0.category == "NEW_MATCH" }))
        XCTAssertTrue(notifications.contains(where: { $0.category == "NEW_MESSAGE" }))

        // Verify end-to-end account deletion removes User 1 and cascades their horses, matches, and messages
        try await app.test(.DELETE, "api/v1/users/me", beforeRequest: { req in
            req.headers.bearerAuthorization = BearerAuthorization(token: user1.accessToken)
        }, afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
        })

        let remainingUser1Horses = try await HorseProfileModel.query(on: app.db)
            .filter(\.$owner.$id == user1.user.id)
            .count()
        XCTAssertEqual(remainingUser1Horses, 0)
    }
}
