import Foundation
import SharedModels
import Vapor

public actor RateLimiterStore {
    private var buckets: [String: [Date]] = [:]

    public init() {}

    public func shouldAllow(
        key: String,
        maxRequests: Int,
        windowSeconds: TimeInterval,
        now: Date = Date()
    ) -> Bool {
        let cutoff = now.addingTimeInterval(-windowSeconds)
        var timestamps = buckets[key, default: []].filter { $0 > cutoff }
        if timestamps.count >= maxRequests {
            buckets[key] = timestamps
            return false
        }
        timestamps.append(now)
        buckets[key] = timestamps
        return true
    }

    public func reset() {
        buckets.removeAll()
    }
}

public struct RateLimiterKey: StorageKey {
    public typealias Value = RateLimiterStore
}

extension Application {
    public var rateLimiter: RateLimiterStore {
        get {
            if let existing = storage[RateLimiterKey.self] {
                return existing
            }
            let store = RateLimiterStore()
            storage[RateLimiterKey.self] = store
            return store
        }
        set {
            storage[RateLimiterKey.self] = newValue
        }
    }
}

public struct RateLimitMiddleware: AsyncMiddleware, Sendable {
    public let scope: String
    public let maxRequests: Int
    public let windowSeconds: TimeInterval

    public init(scope: String, maxRequests: Int, windowSeconds: TimeInterval) {
        self.scope = scope
        self.maxRequests = maxRequests
        self.windowSeconds = windowSeconds
    }

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let clientIdentifier =
            request.headers.first(name: .xForwardedFor)
            ?? request.remoteAddress?.ipAddress
            ?? "local"
        let key = "\(scope):\(clientIdentifier)"
        let allowed = await request.application.rateLimiter.shouldAllow(
            key: key,
            maxRequests: maxRequests,
            windowSeconds: windowSeconds
        )
        guard allowed else {
            throw AppError(
                .tooManyRequests,
                code: .rateLimited,
                message: "Too many requests for \(scope). Please try again shortly."
            )
        }
        return try await next.respond(to: request)
    }
}
