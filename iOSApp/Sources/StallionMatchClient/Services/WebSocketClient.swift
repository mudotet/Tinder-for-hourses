import Foundation
import SharedModels

public actor WebSocketClient {
    private let baseURL: URL
    private let tokenStore: any TokenStore
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveLoopTask: Task<Void, Never>?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        baseURL: URL = URL(string: "ws://127.0.0.1:8080")!,
        tokenStore: any TokenStore = KeychainTokenStore()
    ) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    public func connect(onMessage: @escaping @Sendable (WebSocketMessage) async -> Void) async {
        disconnect()
        guard let tokens = await tokenStore.loadTokens(), !tokens.accessToken.isEmpty else {
            return
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("/api/v1/ws"), resolvingAgainstBaseURL: false)
        if components?.scheme == "http" { components?.scheme = "ws" }
        if components?.scheme == "https" { components?.scheme = "wss" }
        components?.queryItems = [URLQueryItem(name: "token", value: tokens.accessToken)]

        guard let wsURL = components?.url else { return }
        var request = URLRequest(url: wsURL)
        request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.webSocketTask(with: request)
        self.webSocketTask = task
        task.resume()

        let decoderCopy = self.decoder
        self.receiveLoopTask = Task {
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    switch message {
                    case .string(let text):
                        if let data = text.data(using: .utf8),
                           let decoded = try? decoderCopy.decode(WebSocketMessage.self, from: data)
                        {
                            await onMessage(decoded)
                        }
                    case .data(let data):
                        if let decoded = try? decoderCopy.decode(WebSocketMessage.self, from: data) {
                            await onMessage(decoded)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    break
                }
            }
        }
    }

    public func send(_ message: WebSocketMessage) async throws {
        guard let task = webSocketTask else { return }
        let data = try encoder.encode(message)
        if let string = String(data: data, encoding: .utf8) {
            try await task.send(.string(string))
        }
    }

    public func disconnect() {
        receiveLoopTask?.cancel()
        receiveLoopTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }
}
