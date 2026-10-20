import Foundation

/// Standard error codes returned by the Stallion Match REST and WebSocket APIs.
public enum APIErrorCode: String, Codable, Sendable, CaseIterable, Hashable {
    case badRequest = "BAD_REQUEST"
    case validationFailed = "VALIDATION_FAILED"
    case unauthorized = "UNAUTHORIZED"
    case forbidden = "FORBIDDEN"
    case notFound = "NOT_FOUND"
    case conflict = "CONFLICT"
    case rateLimited = "RATE_LIMITED"
    case contentRejected = "CONTENT_REJECTED"
    case payloadTooLarge = "PAYLOAD_TOO_LARGE"
    case internalError = "INTERNAL_ERROR"
}

/// Consistent error payload `{ "code": "...", "message": "..." }` returned across `/api/v1`.
public struct APIErrorResponse: Codable, Sendable, Equatable, Hashable, Error, LocalizedError {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }

    public init(code: APIErrorCode, message: String) {
        self.code = code.rawValue
        self.message = message
    }

    public var errorDescription: String? {
        message
    }
}

/// Generic status response for operations that do not return a resource body.
public struct StatusResponse: Codable, Sendable, Equatable, Hashable {
    public let status: String
    public let message: String?

    public init(status: String = "ok", message: String? = nil) {
        self.status = status
        self.message = message
    }
}

/// Generic cursor-paginated response wrapper used by discovery and message history endpoints.
public struct CursorPage<T: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public let items: [T]
    public let nextCursor: String?

    public init(items: [T], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}
