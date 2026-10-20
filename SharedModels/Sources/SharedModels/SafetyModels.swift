import Foundation

/// Entity types that can be reported by users for moderation.
public enum ReportTargetType: String, Codable, Sendable, CaseIterable, Hashable {
    case user
    case horse
    case message
}

/// Categories of user reports for App Store UGC safety and equestrian welfare compliance.
public enum ReportReason: String, Codable, Sendable, CaseIterable, Hashable {
    case inappropriateContent = "inappropriate_content"
    case animalWelfareConcern = "animal_welfare_concern"
    case illegalSaleOrPaymentSolicitation = "illegal_sale_or_payment_solicitation"
    case harassmentOrAbuse = "harassment_or_abuse"
    case scamOrSpam = "scam_or_spam"
    case other = "other"

    public var displayName: String {
        switch self {
        case .inappropriateContent: return "Inappropriate Content"
        case .animalWelfareConcern: return "Animal Welfare Concern"
        case .illegalSaleOrPaymentSolicitation: return "Payment or Animal Sale Solicitation"
        case .harassmentOrAbuse: return "Harassment or Abuse"
        case .scamOrSpam: return "Scam or Spam"
        case .other: return "Other"
        }
    }
}

/// Server-side moderation queue status for reported content or flagged items.
public enum ModerationStatus: String, Codable, Sendable, CaseIterable, Hashable {
    case pending
    case reviewed
    case actionTaken = "action_taken"
    case dismissed
}

/// Request payload for submitting a safety report.
public struct CreateReportRequest: Codable, Sendable, Equatable {
    public let targetType: ReportTargetType
    public let targetID: UUID
    public let reason: ReportReason
    public let details: String?

    public init(
        targetType: ReportTargetType,
        targetID: UUID,
        reason: ReportReason,
        details: String? = nil
    ) {
        self.targetType = targetType
        self.targetID = targetID
        self.reason = reason
        self.details = details
    }
}

/// Persisted report DTO returned to the reporting user or moderation endpoints.
public struct ReportDTO: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let reporterUserID: UUID
    public let targetType: ReportTargetType
    public let targetID: UUID
    public let reason: ReportReason
    public let details: String?
    public let status: ModerationStatus
    public let createdAt: Date

    public init(
        id: UUID,
        reporterUserID: UUID,
        targetType: ReportTargetType,
        targetID: UUID,
        reason: ReportReason,
        details: String? = nil,
        status: ModerationStatus = .pending,
        createdAt: Date
    ) {
        self.id = id
        self.reporterUserID = reporterUserID
        self.targetType = targetType
        self.targetID = targetID
        self.reason = reason
        self.details = details
        self.status = status
        self.createdAt = createdAt
    }
}

/// Request payload for blocking another user.
public struct BlockUserRequest: Codable, Sendable, Equatable {
    public let blockedUserID: UUID
    public let reason: String?

    public init(blockedUserID: UUID, reason: String? = nil) {
        self.blockedUserID = blockedUserID
        self.reason = reason
    }
}

/// Persisted block relationship DTO.
public struct BlockDTO: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let blockerUserID: UUID
    public let blockedUserID: UUID
    public let createdAt: Date

    public init(
        id: UUID,
        blockerUserID: UUID,
        blockedUserID: UUID,
        createdAt: Date
    ) {
        self.id = id
        self.blockerUserID = blockerUserID
        self.blockedUserID = blockedUserID
        self.createdAt = createdAt
    }
}

/// Shared safety, validation, and animal-welfare constants used across client and server.
public enum SafetyConstants {
    public static let maxBioLength = 500
    public static let maxMessageLength = 2000
    public static let minHorsePhotos = 2
    public static let maxHorsePhotos = 6
    public static let currentTermsVersion = "1.0"

    public static let animalWelfareWarning =
        "Stallion Match does not facilitate payments, deposits, or commercial animal sales in the app. All breeding inquiries and equine introductions must comply with local, state, and federal animal-welfare laws and veterinary health regulations."
}

/// Deterministic objectionable-content filter shared by the iOS app and Vapor server.
public enum ObjectionableContentFilter {
    private static let blockedTerms: Set<String> = [
        "kill",
        "slaughterhouse",
        "dogfood",
        "abuse",
        "starve",
        "wiretransfer",
        "westernunion",
        "cryptopayment",
        "senddeposit",
        "hate",
        "slur",
        "explicit",
        "obscene"
    ]

    private static let blockedPhrases: [String] = [
        "wire transfer",
        "send deposit now",
        "pay via crypto",
        "animal cruelty",
        "illegal slaughter",
        "no coggins needed cash only"
    ]

    /// Result of validating user-generated text.
    public enum ValidationResult: Sendable, Equatable {
        case valid
        case empty
        case tooLong(maxLength: Int)
        case objectionableContent(matchedTerm: String)
    }

    /// Validates a horse bio (non-empty, max 500 characters, free of objectionable content).
    public static func validateBio(_ text: String) -> ValidationResult {
        validate(text, maxLength: SafetyConstants.maxBioLength)
    }

    /// Validates a chat message body (non-empty, max 2000 characters, free of objectionable content).
    public static func validateMessage(_ text: String) -> ValidationResult {
        validate(text, maxLength: SafetyConstants.maxMessageLength)
    }

    /// Validates arbitrary user-generated text against length limits and blocked vocabulary.
    public static func validate(_ text: String, maxLength: Int) -> ValidationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .empty
        }
        guard trimmed.count <= maxLength else {
            return .tooLong(maxLength: maxLength)
        }

        let normalized = trimmed.lowercased()
        for phrase in blockedPhrases where normalized.contains(phrase) {
            return .objectionableContent(matchedTerm: phrase)
        }

        let tokens = normalized.components(separatedBy: CharacterSet.alphanumerics.inverted)
        for token in tokens where !token.isEmpty {
            if blockedTerms.contains(token) {
                return .objectionableContent(matchedTerm: token)
            }
        }

        return .valid
    }
}
