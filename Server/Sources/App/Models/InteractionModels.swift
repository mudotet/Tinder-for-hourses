import Fluent
import Foundation
import SharedModels
import Vapor

public final class SwipeModel: Model, @unchecked Sendable {
    public static let schema = "swipes"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "swiper_horse_id")
    public var swiperHorse: HorseProfileModel

    @Parent(key: "target_horse_id")
    public var targetHorse: HorseProfileModel

    @Field(key: "direction")
    public var direction: String

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        swiperHorseID: UUID,
        targetHorseID: UUID,
        direction: SwipeDirection
    ) {
        self.id = id
        self.$swiperHorse.id = swiperHorseID
        self.$targetHorse.id = targetHorseID
        self.direction = direction.rawValue
    }
}

public final class MatchModel: Model, @unchecked Sendable {
    public static let schema = "matches"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "horse_a_id")
    public var horseA: HorseProfileModel

    @Parent(key: "horse_b_id")
    public var horseB: HorseProfileModel

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    /// Always stores the canonical ordered pair `(horseA, horseB)` where `horseA.uuidString < horseB.uuidString`.
    public init(
        id: UUID? = nil,
        horse1ID: UUID,
        horse2ID: UUID
    ) {
        self.id = id
        let (canonicalA, canonicalB) = Self.canonicalPair(horse1ID, horse2ID)
        self.$horseA.id = canonicalA
        self.$horseB.id = canonicalB
    }

    public static func canonicalPair(_ id1: UUID, _ id2: UUID) -> (UUID, UUID) {
        if id1.uuidString.lowercased() < id2.uuidString.lowercased() {
            return (id1, id2)
        } else {
            return (id2, id1)
        }
    }
}

public final class ConversationModel: Model, @unchecked Sendable {
    public static let schema = "conversations"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "match_id")
    public var match: MatchModel

    @Children(for: \.$conversation)
    public var messages: [MessageModel]

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(id: UUID? = nil, matchID: UUID) {
        self.id = id
        self.$match.id = matchID
    }
}

public final class MessageModel: Model, @unchecked Sendable {
    public static let schema = "messages"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "conversation_id")
    public var conversation: ConversationModel

    @Parent(key: "sender_user_id")
    public var senderUser: UserModel

    @Parent(key: "sender_horse_id")
    public var senderHorse: HorseProfileModel

    @Field(key: "body")
    public var body: String

    @OptionalField(key: "read_at")
    public var readAt: Date?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        conversationID: UUID,
        senderUserID: UUID,
        senderHorseID: UUID,
        body: String,
        readAt: Date? = nil
    ) {
        self.id = id
        self.$conversation.id = conversationID
        self.$senderUser.id = senderUserID
        self.$senderHorse.id = senderHorseID
        self.body = body
        self.readAt = readAt
    }

    public func toDTO() throws -> MessageDTO {
        let messageID = try requireID()
        return MessageDTO(
            id: messageID,
            conversationID: $conversation.id,
            senderUserID: $senderUser.id,
            senderHorseID: $senderHorse.id,
            body: body,
            readAt: readAt,
            createdAt: createdAt ?? Date()
        )
    }
}

public final class BlockModel: Model, @unchecked Sendable {
    public static let schema = "blocks"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "blocker_user_id")
    public var blockerUser: UserModel

    @Parent(key: "blocked_user_id")
    public var blockedUser: UserModel

    @OptionalField(key: "reason")
    public var reason: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        blockerUserID: UUID,
        blockedUserID: UUID,
        reason: String? = nil
    ) {
        self.id = id
        self.$blockerUser.id = blockerUserID
        self.$blockedUser.id = blockedUserID
        self.reason = reason
    }

    public func toDTO() throws -> BlockDTO {
        let blockID = try requireID()
        return BlockDTO(
            id: blockID,
            blockerUserID: $blockerUser.id,
            blockedUserID: $blockedUser.id,
            createdAt: createdAt ?? Date()
        )
    }
}

public final class ReportModel: Model, @unchecked Sendable {
    public static let schema = "reports"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "reporter_user_id")
    public var reporterUser: UserModel

    @Field(key: "target_type")
    public var targetType: String

    @Field(key: "target_id")
    public var targetID: UUID

    @Field(key: "reason")
    public var reason: String

    @OptionalField(key: "details")
    public var details: String?

    @Field(key: "status")
    public var status: String

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        reporterUserID: UUID,
        targetType: ReportTargetType,
        targetID: UUID,
        reason: ReportReason,
        details: String? = nil,
        status: ModerationStatus = .pending
    ) {
        self.id = id
        self.$reporterUser.id = reporterUserID
        self.targetType = targetType.rawValue
        self.targetID = targetID
        self.reason = reason.rawValue
        self.details = details
        self.status = status.rawValue
    }

    public func toDTO() throws -> ReportDTO {
        let reportID = try requireID()
        return ReportDTO(
            id: reportID,
            reporterUserID: $reporterUser.id,
            targetType: ReportTargetType(rawValue: targetType) ?? .user,
            targetID: targetID,
            reason: ReportReason(rawValue: reason) ?? .other,
            details: details,
            status: ModerationStatus(rawValue: status) ?? .pending,
            createdAt: createdAt ?? Date()
        )
    }
}

public final class ModerationQueueModel: Model, @unchecked Sendable {
    public static let schema = "moderation_queue"

    @ID(key: .id)
    public var id: UUID?

    @OptionalParent(key: "report_id")
    public var report: ReportModel?

    @Field(key: "target_type")
    public var targetType: String

    @Field(key: "target_id")
    public var targetID: UUID

    @Field(key: "summary")
    public var summary: String

    @Field(key: "status")
    public var status: String

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @OptionalField(key: "reviewed_at")
    public var reviewedAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        reportID: UUID? = nil,
        targetType: ReportTargetType,
        targetID: UUID,
        summary: String,
        status: ModerationStatus = .pending,
        reviewedAt: Date? = nil
    ) {
        self.id = id
        self.$report.id = reportID
        self.targetType = targetType.rawValue
        self.targetID = targetID
        self.summary = summary
        self.status = status.rawValue
        self.reviewedAt = reviewedAt
    }
}
