import Foundation
import XCTest
@testable import SharedModels

final class SharedModelsTests: XCTestCase {
    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func testHorseLocationCoarseningAndDistance() {
        let lexington = HorseLocationDTO(
            city: "Lexington, KY",
            coarseLatitude: 38.0405837,
            coarseLongitude: -84.5037164
        )
        XCTAssertEqual(lexington.coarseLatitude, 38.04, accuracy: 0.0001)
        XCTAssertEqual(lexington.coarseLongitude, -84.50, accuracy: 0.0001)

        let louisville = HorseLocationDTO(
            city: "Louisville, KY",
            coarseLatitude: 38.252665,
            coarseLongitude: -85.758456
        )
        let distance = lexington.distanceKm(to: louisville)
        XCTAssertGreaterThan(distance, 100.0)
        XCTAssertLessThan(distance, 130.0)
    }

    func testHorseProfileCodableRoundTrip() throws {
        let horseID = UUID()
        let ownerID = UUID()
        let now = Date(timeIntervalSince1970: 1_760_000_000)

        let photo1 = HorsePhotoDTO(
            id: UUID(),
            horseID: horseID,
            url: "https://cdn.example.com/horses/1.jpg",
            position: 0,
            createdAt: now
        )
        let photo2 = HorsePhotoDTO(
            id: UUID(),
            horseID: horseID,
            url: "https://cdn.example.com/horses/2.jpg",
            position: 1,
            createdAt: now
        )

        let horse = HorseProfileDTO(
            id: horseID,
            ownerID: ownerID,
            name: "Apollo",
            age: 7,
            sex: .stallion,
            breed: "Warmblood",
            color: "Bay",
            heightHands: 16.2,
            disciplines: [.dressage, .jumping],
            temperamentTags: ["Calm", "Forward", "Friendly"],
            bio: "Gentle warmblood stallion looking for trail buddies and dressage companions.",
            location: HorseLocationDTO(city: "Ocala, FL", coarseLatitude: 29.1872, coarseLongitude: -82.1401),
            lookingFor: [.trailBuddy, .breedingInquiry],
            healthInfo: HorseHealthInfoDTO(cogginsTestDate: now, vaccinationsUpToDate: true),
            pedigree: "Sire: Donnerhall Line / Dam: Sandro Hit Line",
            photos: [photo1, photo2],
            distanceKm: 14.5,
            createdAt: now,
            updatedAt: now
        )

        let page = CursorPage(items: [horse], nextCursor: "cursor-123")
        let data = try makeEncoder().encode(page)
        let decoded = try makeDecoder().decode(CursorPage<HorseProfileDTO>.self, from: data)

        XCTAssertEqual(decoded, page)
        XCTAssertEqual(decoded.items.first?.location.coarseLatitude, 29.19)
    }

    func testWebSocketMessageCodable() throws {
        let encoder = makeEncoder()
        let decoder = makeDecoder()
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let conversationID = UUID()
        let horseID = UUID()
        let userID = UUID()

        let messages: [WebSocketMessage] = [
            .sendMessage(
                WSSendMessagePayload(
                    conversationID: conversationID,
                    senderHorseID: horseID,
                    body: "Hello from the barn!",
                    clientMessageID: UUID()
                )
            ),
            .messageReceived(
                MessageDTO(
                    id: UUID(),
                    conversationID: conversationID,
                    senderUserID: userID,
                    senderHorseID: horseID,
                    body: "Hello back!",
                    readAt: nil,
                    createdAt: now
                )
            ),
            .typing(WSTypingPayload(conversationID: conversationID, horseID: horseID, isTyping: true)),
            .markRead(WSMarkReadPayload(conversationID: conversationID, upToMessageID: UUID())),
            .readReceipt(
                WSReadReceiptPayload(
                    conversationID: conversationID,
                    readerUserID: userID,
                    upToMessageID: nil,
                    readAt: now
                )
            ),
            .unreadCountUpdated(
                WSUnreadCountPayload(
                    conversationID: conversationID,
                    unreadCount: 2,
                    totalUnreadCount: 5
                )
            ),
            .ping,
            .pong,
            .error(APIErrorResponse(code: .unauthorized, message: "Invalid token"))
        ]

        for message in messages {
            let data = try encoder.encode(message)
            let roundTripped = try decoder.decode(WebSocketMessage.self, from: data)
            XCTAssertEqual(roundTripped, message)
        }
    }

    func testObjectionableContentFilter() {
        XCTAssertEqual(
            ObjectionableContentFilter.validateBio("Sweet 8yo Quarter Horse mare who loves trail rides."),
            .valid
        )
        XCTAssertEqual(ObjectionableContentFilter.validateBio("   "), .empty)

        let oversizedBio = String(repeating: "a", count: SafetyConstants.maxBioLength + 1)
        XCTAssertEqual(
            ObjectionableContentFilter.validateBio(oversizedBio),
            .tooLong(maxLength: SafetyConstants.maxBioLength)
        )

        let objectionable = ObjectionableContentFilter.validateMessage("Please send deposit now via wire transfer")
        if case .objectionableContent = objectionable {
            // Expected
        } else {
            XCTFail("Expected objectionable content rejection")
        }
    }
}
