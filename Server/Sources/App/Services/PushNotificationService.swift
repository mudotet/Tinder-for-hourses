import Crypto
import Fluent
import Foundation
@preconcurrency import JWT
import SharedModels
import Vapor

public struct PushNotificationRecord: Sendable, Equatable {
    public let recipientUserID: UUID
    public let title: String
    public let body: String
    public let category: String
    public let metadata: [String: String]
    public let sentAt: Date

    public init(
        recipientUserID: UUID,
        title: String,
        body: String,
        category: String,
        metadata: [String: String] = [:],
        sentAt: Date = Date()
    ) {
        self.recipientUserID = recipientUserID
        self.title = title
        self.body = body
        self.category = category
        self.metadata = metadata
        self.sentAt = sentAt
    }
}

public protocol PushNotificationService: Sendable {
    func sendNewMatchNotification(to userID: UUID, match: MatchDTO, on db: Database) async
    func sendNewMessageNotification(to userID: UUID, message: MessageDTO, senderHorseName: String, on db: Database) async
    func recordedNotifications() async -> [PushNotificationRecord]
}

/// Thread-safe stub/recording implementation of `PushNotificationService` used in local dev and tests.
public actor StubPushNotificationService: PushNotificationService {
    private var history: [PushNotificationRecord] = []
    private let logger: Logger

    public init(logger: Logger = Logger(label: "com.stallionmatch.apns.stub")) {
        self.logger = logger
    }

    public func sendNewMatchNotification(to userID: UUID, match: MatchDTO, on db: Database) async {
        guard let user = try? await UserModel.find(userID, on: db), user.notificationsNewMatch else {
            return
        }
        let record = PushNotificationRecord(
            recipientUserID: userID,
            title: "It's a Match!",
            body: "\(match.horseA.name) and \(match.horseB.name) matched on Stallion Match!",
            category: "NEW_MATCH",
            metadata: [
                "matchID": match.id.uuidString,
                "conversationID": match.conversationID.uuidString
            ]
        )
        history.append(record)
        logger.info("[APNs-Stub] Sent NEW_MATCH push to user \(userID)")
    }

    public func sendNewMessageNotification(
        to userID: UUID,
        message: MessageDTO,
        senderHorseName: String,
        on db: Database
    ) async {
        guard let user = try? await UserModel.find(userID, on: db), user.notificationsNewMessage else {
            return
        }
        let record = PushNotificationRecord(
            recipientUserID: userID,
            title: "New message from \(senderHorseName)",
            body: String(message.body.prefix(120)),
            category: "NEW_MESSAGE",
            metadata: [
                "conversationID": message.conversationID.uuidString,
                "messageID": message.id.uuidString
            ]
        )
        history.append(record)
        logger.info("[APNs-Stub] Sent NEW_MESSAGE push to user \(userID)")
    }

    public func recordedNotifications() async -> [PushNotificationRecord] {
        history
    }

    public func clear() {
        history.removeAll()
    }
}

/// Full APNs HTTP/2 token-based push sender using ES256 provider authentication tokens.
public actor APNsPushNotificationService: PushNotificationService {
    public struct APNsProviderTokenPayload: JWTPayload, @unchecked Sendable {
        public var iss: IssuerClaim
        public var iat: IssuedAtClaim

        public init(teamID: String, issuedAt: Date = Date()) {
            self.iss = IssuerClaim(value: teamID)
            self.iat = IssuedAtClaim(value: issuedAt)
        }

        public func verify(using signer: JWTSigner) throws {}
    }

    private struct APNsApsAlert: Codable, Sendable {
        let title: String
        let body: String
    }

    private struct APNsApsPayload: Codable, Sendable {
        let alert: APNsApsAlert
        let sound: String
        let category: String
    }

    private struct APNsEnvelope: Codable, Sendable {
        let aps: APNsApsPayload
        let metadata: [String: String]
    }

    private let keyID: String
    private let teamID: String
    private let topic: String
    private let privateKeyPEM: String
    private let isProduction: Bool
    private let client: any Client
    private let logger: Logger
    private var history: [PushNotificationRecord] = []

    public init(
        keyID: String,
        teamID: String,
        topic: String,
        privateKeyPEM: String,
        isProduction: Bool,
        client: any Client,
        logger: Logger
    ) {
        self.keyID = keyID
        self.teamID = teamID
        self.topic = topic
        self.privateKeyPEM = privateKeyPEM
        self.isProduction = isProduction
        self.client = client
        self.logger = logger
    }

    public func sendNewMatchNotification(to userID: UUID, match: MatchDTO, on db: Database) async {
        guard let user = try? await UserModel.find(userID, on: db), user.notificationsNewMatch else {
            return
        }
        let record = PushNotificationRecord(
            recipientUserID: userID,
            title: "It's a Match!",
            body: "\(match.horseA.name) and \(match.horseB.name) matched on Stallion Match!",
            category: "NEW_MATCH",
            metadata: [
                "matchID": match.id.uuidString,
                "conversationID": match.conversationID.uuidString
            ]
        )
        history.append(record)
        await deliver(record: record, on: db)
    }

    public func sendNewMessageNotification(
        to userID: UUID,
        message: MessageDTO,
        senderHorseName: String,
        on db: Database
    ) async {
        guard let user = try? await UserModel.find(userID, on: db), user.notificationsNewMessage else {
            return
        }
        let record = PushNotificationRecord(
            recipientUserID: userID,
            title: "New message from \(senderHorseName)",
            body: String(message.body.prefix(120)),
            category: "NEW_MESSAGE",
            metadata: [
                "conversationID": message.conversationID.uuidString,
                "messageID": message.id.uuidString
            ]
        )
        history.append(record)
        await deliver(record: record, on: db)
    }

    public func recordedNotifications() async -> [PushNotificationRecord] {
        history
    }

    private func deliver(record: PushNotificationRecord, on db: Database) async {
        let deviceTokens = (try? await DeviceTokenModel.query(on: db)
            .filter(\.$user.$id == record.recipientUserID)
            .all()) ?? []
        guard !deviceTokens.isEmpty else { return }

        let host = isProduction
            ? "https://api.push.apple.com"
            : "https://api.sandbox.push.apple.com"

        do {
            let signers = JWTSigners()
            try signers.use(.es256(key: .private(pem: privateKeyPEM)), kid: JWKIdentifier(string: keyID))
            let jwt = try signers.sign(
                APNsProviderTokenPayload(teamID: teamID),
                kid: JWKIdentifier(string: keyID)
            )

            let envelope = APNsEnvelope(
                aps: APNsApsPayload(
                    alert: APNsApsAlert(title: record.title, body: record.body),
                    sound: "default",
                    category: record.category
                ),
                metadata: record.metadata
            )
            let bodyData = try JSONEncoder().encode(envelope)

            for device in deviceTokens {
                var headers = HTTPHeaders()
                headers.replaceOrAdd(name: .authorization, value: "bearer \(jwt)")
                headers.replaceOrAdd(name: "apns-topic", value: topic)
                headers.replaceOrAdd(name: "apns-push-type", value: "alert")
                headers.replaceOrAdd(name: "apns-priority", value: "10")

                let uri = URI(string: "\(host)/3/device/\(device.token)")
                let response = try await client.post(uri, headers: headers) { req in
                    req.body = ByteBuffer(data: bodyData)
                }
                if response.status == .gone {
                    try? await device.delete(on: db)
                }
            }
        } catch {
            logger.error("[APNs] Failed to deliver APNs push: \(error.localizedDescription)")
        }
    }
}

public struct PushNotificationServiceKey: StorageKey {
    public typealias Value = any PushNotificationService
}

extension Application {
    public var pushNotificationService: any PushNotificationService {
        get {
            if let existing = storage[PushNotificationServiceKey.self] {
                return existing
            }
            let stub = StubPushNotificationService(logger: logger)
            storage[PushNotificationServiceKey.self] = stub
            return stub
        }
        set {
            storage[PushNotificationServiceKey.self] = newValue
        }
    }
}
