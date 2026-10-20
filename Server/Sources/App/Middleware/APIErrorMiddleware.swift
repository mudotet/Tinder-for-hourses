import Foundation
import JWT
import SharedModels
import Vapor

/// Structured application error that maps directly to `APIErrorResponse` (`{ "code", "message" }`) and an HTTP status.
public struct AppError: AbortError, Sendable {
    public let status: HTTPResponseStatus
    public let code: APIErrorCode
    public let message: String

    public var reason: String { message }

    public init(
        _ status: HTTPResponseStatus,
        code: APIErrorCode,
        message: String
    ) {
        self.status = status
        self.code = code
        self.message = message
    }
}

/// Custom error middleware that formats all errors consistently as `{ "code": "...", "message": "..." }`.
public struct APIErrorMiddleware: AsyncMiddleware, Sendable {
    public init() {}

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch {
            return Self.handle(error: error, for: request)
        }
    }

    public static func handle(error: Error, for request: Request) -> Response {
        let status: HTTPResponseStatus
        let payload: APIErrorResponse

        if let appError = error as? AppError {
            status = appError.status
            payload = APIErrorResponse(code: appError.code, message: appError.message)
        } else if let validationsError = error as? ValidationsError {
            status = .badRequest
            payload = APIErrorResponse(
                code: .validationFailed,
                message: validationsError.description
            )
        } else if error is JWTError {
            status = .unauthorized
            payload = APIErrorResponse(
                code: .unauthorized,
                message: "Invalid or expired authentication token."
            )
        } else if let abort = error as? AbortError {
            status = abort.status
            let code = Self.mapStatusToCode(abort.status)
            payload = APIErrorResponse(code: code, message: abort.reason)
        } else if error is DecodingError {
            status = .badRequest
            payload = APIErrorResponse(
                code: .badRequest,
                message: "Malformed JSON request payload."
            )
        } else {
            request.logger.report(error: error)
            status = .internalServerError
            payload = APIErrorResponse(
                code: .internalError,
                message: "An unexpected server error occurred."
            )
        }

        let response = Response(status: status)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)
            response.body = .init(data: data)
            response.headers.replaceOrAdd(name: .contentType, value: "application/json; charset=utf-8")
        } catch {
            response.body = .init(string: "{\"code\":\"INTERNAL_ERROR\",\"message\":\"Encoding failure\"}")
            response.headers.replaceOrAdd(name: .contentType, value: "application/json; charset=utf-8")
        }
        return response
    }

    private static func mapStatusToCode(_ status: HTTPResponseStatus) -> APIErrorCode {
        switch status {
        case .badRequest, .unprocessableEntity:
            return .validationFailed
        case .unauthorized:
            return .unauthorized
        case .forbidden:
            return .forbidden
        case .notFound:
            return .notFound
        case .conflict:
            return .conflict
        case .tooManyRequests:
            return .rateLimited
        case .payloadTooLarge:
            return .payloadTooLarge
        default:
            return status.code >= 500 ? .internalError : .badRequest
        }
    }
}
