import Foundation
import SharedModels
import Vapor

public actor WebSocketHub {
    private struct ConnectionEntry {
        let id: UUID
        let userID: UUID
        let socket: WebSocket
    }

    private var connectionsByUser: [UUID: [UUID: ConnectionEntry]] = [:]

    public init() {}

    public func register(userID: UUID, socket: WebSocket) -> UUID {
        let connectionID = UUID()
        let entry = ConnectionEntry(id: connectionID, userID: userID, socket: socket)
        connectionsByUser[userID, default: [:]][connectionID] = entry
        return connectionID
    }

    public func unregister(userID: UUID, connectionID: UUID) {
        connectionsByUser[userID]?[connectionID] = nil
        if connectionsByUser[userID]?.isEmpty == true {
            connectionsByUser[userID] = nil
        }
    }

    public func send(_ message: WebSocketMessage, to userID: UUID) async {
        guard let entries = connectionsByUser[userID]?.values, !entries.isEmpty else {
            return
        }
        guard let jsonText = Self.encodeMessage(message) else {
            return
        }
        for entry in entries where !entry.socket.isClosed {
            try? await entry.socket.send(jsonText)
        }
    }

    public func send(_ message: WebSocketMessage, to userIDs: Set<UUID>) async {
        for userID in userIDs {
            await send(message, to: userID)
        }
    }

    public static func encodeMessage(_ message: WebSocketMessage) -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(message) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decodeMessage(_ text: String) throws -> WebSocketMessage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = text.data(using: .utf8) else {
            throw AppError(.badRequest, code: .badRequest, message: "Invalid UTF-8 WebSocket frame.")
        }
        return try decoder.decode(WebSocketMessage.self, from: data)
    }
}

public struct WebSocketHubKey: StorageKey {
    public typealias Value = WebSocketHub
}

extension Application {
    public var webSocketHub: WebSocketHub {
        get {
            if let existing = storage[WebSocketHubKey.self] {
                return existing
            }
            let hub = WebSocketHub()
            storage[WebSocketHubKey.self] = hub
            return hub
        }
        set {
            storage[WebSocketHubKey.self] = newValue
        }
    }
}
