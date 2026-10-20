import Foundation

/// Persisted chat message DTO.
public struct MessageDTO: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let conversationID: UUID
    public let senderUserID: UUID
    public let senderHorseID: UUID
    public let body: String
    public let readAt: Date?
    public let createdAt: Date

    public init(
        id: UUID,
        conversationID: UUID,
        senderUserID: UUID,
        senderHorseID: UUID,
        body: String,
        readAt: Date? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.conversationID = conversationID
        self.senderUserID = senderUserID
        self.senderHorseID = senderHorseID
        self.body = body
        self.readAt = readAt
        self.createdAt = createdAt
    }
}

/// Summary of a conversation between two matched horses, including unread message count.
public struct ConversationSummaryDTO: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let matchID: UUID
    public let myHorse: HorseProfileDTO
    public let otherHorse: HorseProfileDTO
    public let lastMessage: MessageDTO?
    public let unreadCount: Int
    public let updatedAt: Date

    public init(
        id: UUID,
        matchID: UUID,
        myHorse: HorseProfileDTO,
        otherHorse: HorseProfileDTO,
        lastMessage: MessageDTO? = nil,
        unreadCount: Int = 0,
        updatedAt: Date
    ) {
        self.id = id
        self.matchID = matchID
        self.myHorse = myHorse
        self.otherHorse = otherHorse
        self.lastMessage = lastMessage
        self.unreadCount = unreadCount
        self.updatedAt = updatedAt
    }
}

/// REST request payload for sending a message to a conversation.
public struct SendMessageRequest: Codable, Sendable, Equatable {
    public let senderHorseID: UUID
    public let body: String

    public init(senderHorseID: UUID, body: String) {
        self.senderHorseID = senderHorseID
        self.body = body
    }
}

/// REST request payload for marking messages in a conversation as read.
public struct MarkMessagesReadRequest: Codable, Sendable, Equatable {
    public let upToMessageID: UUID?

    public init(upToMessageID: UUID? = nil) {
        self.upToMessageID = upToMessageID
    }
}

/// REST response payload after marking messages in a conversation as read.
public struct MarkMessagesReadResponse: Codable, Sendable, Equatable {
    public let conversationID: UUID
    public let readCount: Int
    public let readAt: Date

    public init(conversationID: UUID, readCount: Int, readAt: Date) {
        self.conversationID = conversationID
        self.readCount = readCount
        self.readAt = readAt
    }
}

/// WebSocket payload for sending a chat message over `/api/v1/ws`.
public struct WSSendMessagePayload: Codable, Sendable, Equatable, Hashable {
    public let conversationID: UUID
    public let senderHorseID: UUID
    public let body: String
    public let clientMessageID: UUID?

    public init(
        conversationID: UUID,
        senderHorseID: UUID,
        body: String,
        clientMessageID: UUID? = nil
    ) {
        self.conversationID = conversationID
        self.senderHorseID = senderHorseID
        self.body = body
        self.clientMessageID = clientMessageID
    }
}

/// WebSocket payload for broadcasting or receiving typing indicators.
public struct WSTypingPayload: Codable, Sendable, Equatable, Hashable {
    public let conversationID: UUID
    public let horseID: UUID
    public let isTyping: Bool

    public init(conversationID: UUID, horseID: UUID, isTyping: Bool) {
        self.conversationID = conversationID
        self.horseID = horseID
        self.isTyping = isTyping
    }
}

/// WebSocket payload for marking messages as read.
public struct WSMarkReadPayload: Codable, Sendable, Equatable, Hashable {
    public let conversationID: UUID
    public let upToMessageID: UUID?

    public init(conversationID: UUID, upToMessageID: UUID? = nil) {
        self.conversationID = conversationID
        self.upToMessageID = upToMessageID
    }
}

/// WebSocket payload notifying participants that messages were read.
public struct WSReadReceiptPayload: Codable, Sendable, Equatable, Hashable {
    public let conversationID: UUID
    public let readerUserID: UUID
    public let upToMessageID: UUID?
    public let readAt: Date

    public init(
        conversationID: UUID,
        readerUserID: UUID,
        upToMessageID: UUID? = nil,
        readAt: Date
    ) {
        self.conversationID = conversationID
        self.readerUserID = readerUserID
        self.upToMessageID = upToMessageID
        self.readAt = readAt
    }
}

/// WebSocket payload notifying a user of updated unread message counts.
public struct WSUnreadCountPayload: Codable, Sendable, Equatable, Hashable {
    public let conversationID: UUID
    public let unreadCount: Int
    public let totalUnreadCount: Int

    public init(conversationID: UUID, unreadCount: Int, totalUnreadCount: Int) {
        self.conversationID = conversationID
        self.unreadCount = unreadCount
        self.totalUnreadCount = totalUnreadCount
    }
}

/// Discriminated union of all real-time WebSocket frames exchanged on `/api/v1/ws`.
public enum WebSocketMessage: Codable, Sendable, Equatable {
    case sendMessage(WSSendMessagePayload)
    case messageReceived(MessageDTO)
    case typing(WSTypingPayload)
    case markRead(WSMarkReadPayload)
    case readReceipt(WSReadReceiptPayload)
    case unreadCountUpdated(WSUnreadCountPayload)
    case matchCreated(MatchDTO)
    case ping
    case pong
    case error(APIErrorResponse)

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private enum MessageType: String, Codable, Sendable {
        case sendMessage = "send_message"
        case messageReceived = "message_received"
        case typing = "typing"
        case markRead = "mark_read"
        case readReceipt = "read_receipt"
        case unreadCountUpdated = "unread_count_updated"
        case matchCreated = "match_created"
        case ping = "ping"
        case pong = "pong"
        case error = "error"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)
        switch type {
        case .sendMessage:
            let payload = try container.decode(WSSendMessagePayload.self, forKey: .payload)
            self = .sendMessage(payload)
        case .messageReceived:
            let payload = try container.decode(MessageDTO.self, forKey: .payload)
            self = .messageReceived(payload)
        case .typing:
            let payload = try container.decode(WSTypingPayload.self, forKey: .payload)
            self = .typing(payload)
        case .markRead:
            let payload = try container.decode(WSMarkReadPayload.self, forKey: .payload)
            self = .markRead(payload)
        case .readReceipt:
            let payload = try container.decode(WSReadReceiptPayload.self, forKey: .payload)
            self = .readReceipt(payload)
        case .unreadCountUpdated:
            let payload = try container.decode(WSUnreadCountPayload.self, forKey: .payload)
            self = .unreadCountUpdated(payload)
        case .matchCreated:
            let payload = try container.decode(MatchDTO.self, forKey: .payload)
            self = .matchCreated(payload)
        case .ping:
            self = .ping
        case .pong:
            self = .pong
        case .error:
            let payload = try container.decode(APIErrorResponse.self, forKey: .payload)
            self = .error(payload)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .sendMessage(let payload):
            try container.encode(MessageType.sendMessage, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .messageReceived(let payload):
            try container.encode(MessageType.messageReceived, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .typing(let payload):
            try container.encode(MessageType.typing, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .markRead(let payload):
            try container.encode(MessageType.markRead, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .readReceipt(let payload):
            try container.encode(MessageType.readReceipt, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .unreadCountUpdated(let payload):
            try container.encode(MessageType.unreadCountUpdated, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .matchCreated(let payload):
            try container.encode(MessageType.matchCreated, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .ping:
            try container.encode(MessageType.ping, forKey: .type)
        case .pong:
            try container.encode(MessageType.pong, forKey: .type)
        case .error(let payload):
            try container.encode(MessageType.error, forKey: .type)
            try container.encode(payload, forKey: .payload)
        }
    }
}
