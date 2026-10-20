import Foundation
import SharedModels

public enum APIClientError: Error, LocalizedError, Sendable, Equatable {
    case invalidURL
    case offline(String)
    case unauthorized(String)
    case serverError(statusCode: Int, response: APIErrorResponse)
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server endpoint URL."
        case .offline(let message):
            return message
        case .unauthorized(let message):
            return message
        case .serverError(_, let response):
            return response.message
        case .decodingFailed(let details):
            return "Failed to decode server response: \(details)"
        }
    }
}

public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIClientError.offline("Invalid HTTP response from server.")
            }
            return (data, httpResponse)
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
        } catch let apiError as APIClientError {
            throw apiError
        } catch {
            throw APIClientError.offline("Network connection unavailable. Check your internet connection.")
        }
    }
}

public protocol APIClientProtocol: Sendable {
    // Auth & User
    func signUp(_ request: SignUpRequest) async throws -> AuthTokenResponse
    func login(_ request: LoginRequest) async throws -> AuthTokenResponse
    func signInWithApple(_ request: AppleSignInRequest) async throws -> AuthTokenResponse
    func logout() async throws
    func getMe() async throws -> UserDTO
    func updateMe(_ request: UpdateUserSettingsRequest) async throws -> UserDTO
    func registerDeviceToken(_ request: RegisterDeviceTokenRequest) async throws -> DeviceTokenDTO
    func deleteAccount() async throws

    // Horses & Photos
    func listMyHorses() async throws -> [HorseProfileDTO]
    func createHorse(_ request: CreateHorseProfileRequest) async throws -> HorseProfileDTO
    func updateHorse(id: UUID, _ request: UpdateHorseProfileRequest) async throws -> HorseProfileDTO
    func deleteHorse(id: UUID) async throws
    func uploadHorsePhoto(horseID: UUID, jpegData: Data) async throws -> HorsePhotoDTO
    func reorderHorsePhotos(horseID: UUID, photoIDs: [UUID]) async throws -> [HorsePhotoDTO]
    func deleteHorsePhoto(horseID: UUID, photoID: UUID) async throws

    // Discovery, Swipes & Matches
    func discoverHorses(query: DiscoveryFilterQuery) async throws -> CursorPage<HorseProfileDTO>
    func recordSwipe(_ request: SwipeRequest) async throws -> SwipeResponse
    func listMatches() async throws -> [MatchDTO]

    // Chat
    func listConversations() async throws -> [ConversationSummaryDTO]
    func listMessages(conversationID: UUID, cursor: String?, limit: Int) async throws -> CursorPage<MessageDTO>
    func sendMessage(conversationID: UUID, request: SendMessageRequest) async throws -> MessageDTO
    func markMessagesRead(conversationID: UUID, upToMessageID: UUID?) async throws -> MarkMessagesReadResponse

    // Safety
    func listBlocks() async throws -> [BlockDTO]
    func blockUser(_ request: BlockUserRequest) async throws -> BlockDTO
    func unblockUser(blockedUserID: UUID) async throws
    func createReport(_ request: CreateReportRequest) async throws -> ReportDTO
}

/// Typed `APIClient` actor with automatic token refresh & retry-once on 401, Keychain persistence, and cancellation support.
public actor APIClient: APIClientProtocol {
    public let baseURL: URL
    private let transport: any HTTPTransport
    private let tokenStore: any TokenStore
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        baseURL: URL = URL(string: "http://127.0.0.1:8080")!,
        transport: any HTTPTransport = URLSessionHTTPTransport(),
        tokenStore: any TokenStore = KeychainTokenStore()
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.tokenStore = tokenStore

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    // MARK: - Auth & User

    public func signUp(_ request: SignUpRequest) async throws -> AuthTokenResponse {
        let response: AuthTokenResponse = try await requestJSON(
            method: "POST",
            path: "/api/v1/auth/signup",
            body: request,
            requiresAuth: false
        )
        try await tokenStore.saveTokens(
            StoredTokenPair(accessToken: response.accessToken, refreshToken: response.refreshToken)
        )
        return response
    }

    public func login(_ request: LoginRequest) async throws -> AuthTokenResponse {
        let response: AuthTokenResponse = try await requestJSON(
            method: "POST",
            path: "/api/v1/auth/login",
            body: request,
            requiresAuth: false
        )
        try await tokenStore.saveTokens(
            StoredTokenPair(accessToken: response.accessToken, refreshToken: response.refreshToken)
        )
        return response
    }

    public func signInWithApple(_ request: AppleSignInRequest) async throws -> AuthTokenResponse {
        let response: AuthTokenResponse = try await requestJSON(
            method: "POST",
            path: "/api/v1/auth/apple",
            body: request,
            requiresAuth: false
        )
        try await tokenStore.saveTokens(
            StoredTokenPair(accessToken: response.accessToken, refreshToken: response.refreshToken)
        )
        return response
    }

    public func logout() async throws {
        if let tokens = await tokenStore.loadTokens() {
            let _: StatusResponse? = try? await requestJSON(
                method: "POST",
                path: "/api/v1/auth/logout",
                body: LogoutRequest(refreshToken: tokens.refreshToken),
                requiresAuth: true
            )
        }
        try await tokenStore.clearTokens()
    }

    public func getMe() async throws -> UserDTO {
        try await requestJSON(method: "GET", path: "/api/v1/users/me", requiresAuth: true)
    }

    public func updateMe(_ request: UpdateUserSettingsRequest) async throws -> UserDTO {
        try await requestJSON(
            method: "PATCH",
            path: "/api/v1/users/me",
            body: request,
            requiresAuth: true
        )
    }

    public func registerDeviceToken(_ request: RegisterDeviceTokenRequest) async throws -> DeviceTokenDTO {
        try await requestJSON(
            method: "POST",
            path: "/api/v1/users/me/devices",
            body: request,
            requiresAuth: true
        )
    }

    public func deleteAccount() async throws {
        let _: StatusResponse = try await requestJSON(
            method: "DELETE",
            path: "/api/v1/users/me",
            requiresAuth: true
        )
        try await tokenStore.clearTokens()
    }

    // MARK: - Horses & Photos

    public func listMyHorses() async throws -> [HorseProfileDTO] {
        try await requestJSON(method: "GET", path: "/api/v1/horses/mine", requiresAuth: true)
    }

    public func createHorse(_ request: CreateHorseProfileRequest) async throws -> HorseProfileDTO {
        try await requestJSON(
            method: "POST",
            path: "/api/v1/horses",
            body: request,
            requiresAuth: true
        )
    }

    public func updateHorse(id: UUID, _ request: UpdateHorseProfileRequest) async throws -> HorseProfileDTO {
        try await requestJSON(
            method: "PATCH",
            path: "/api/v1/horses/\(id.uuidString)",
            body: request,
            requiresAuth: true
        )
    }

    public func deleteHorse(id: UUID) async throws {
        let _: StatusResponse = try await requestJSON(
            method: "DELETE",
            path: "/api/v1/horses/\(id.uuidString)",
            requiresAuth: true
        )
    }

    public func uploadHorsePhoto(horseID: UUID, jpegData: Data) async throws -> HorsePhotoDTO {
        try await requestRawData(
            method: "POST",
            path: "/api/v1/horses/\(horseID.uuidString)/photos",
            data: jpegData,
            contentType: "image/jpeg",
            requiresAuth: true
        )
    }

    public func reorderHorsePhotos(horseID: UUID, photoIDs: [UUID]) async throws -> [HorsePhotoDTO] {
        try await requestJSON(
            method: "PUT",
            path: "/api/v1/horses/\(horseID.uuidString)/photos/reorder",
            body: ReorderHorsePhotosRequest(photoIDs: photoIDs),
            requiresAuth: true
        )
    }

    public func deleteHorsePhoto(horseID: UUID, photoID: UUID) async throws {
        let _: StatusResponse = try await requestJSON(
            method: "DELETE",
            path: "/api/v1/horses/\(horseID.uuidString)/photos/\(photoID.uuidString)",
            requiresAuth: true
        )
    }

    // MARK: - Discovery, Swipes & Matches

    public func discoverHorses(query: DiscoveryFilterQuery) async throws -> CursorPage<HorseProfileDTO> {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "activeHorseID", value: query.activeHorseID.uuidString)
        ]
        if let maxDistanceKm = query.maxDistanceKm {
            queryItems.append(URLQueryItem(name: "maxDistanceKm", value: String(maxDistanceKm)))
        }
        if let breed = query.breed, !breed.isEmpty {
            queryItems.append(URLQueryItem(name: "breed", value: breed))
        }
        if let sex = query.sex {
            queryItems.append(URLQueryItem(name: "sex", value: sex.rawValue))
        }
        if let minAge = query.minAge {
            queryItems.append(URLQueryItem(name: "minAge", value: String(minAge)))
        }
        if let maxAge = query.maxAge {
            queryItems.append(URLQueryItem(name: "maxAge", value: String(maxAge)))
        }
        if let discipline = query.discipline {
            queryItems.append(URLQueryItem(name: "discipline", value: discipline.rawValue))
        }
        if let lookingFor = query.lookingFor {
            queryItems.append(URLQueryItem(name: "lookingFor", value: lookingFor.rawValue))
        }
        if let cursor = query.cursor, !cursor.isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let limit = query.limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }

        return try await requestJSON(
            method: "GET",
            path: "/api/v1/discovery",
            queryItems: queryItems,
            requiresAuth: true
        )
    }

    public func recordSwipe(_ request: SwipeRequest) async throws -> SwipeResponse {
        try await requestJSON(
            method: "POST",
            path: "/api/v1/swipes",
            body: request,
            requiresAuth: true
        )
    }

    public func listMatches() async throws -> [MatchDTO] {
        try await requestJSON(method: "GET", path: "/api/v1/matches", requiresAuth: true)
    }

    // MARK: - Chat

    public func listConversations() async throws -> [ConversationSummaryDTO] {
        try await requestJSON(method: "GET", path: "/api/v1/conversations", requiresAuth: true)
    }

    public func listMessages(
        conversationID: UUID,
        cursor: String? = nil,
        limit: Int = 30
    ) async throws -> CursorPage<MessageDTO> {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor, !cursor.isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await requestJSON(
            method: "GET",
            path: "/api/v1/conversations/\(conversationID.uuidString)/messages",
            queryItems: queryItems,
            requiresAuth: true
        )
    }

    public func sendMessage(conversationID: UUID, request: SendMessageRequest) async throws -> MessageDTO {
        try await requestJSON(
            method: "POST",
            path: "/api/v1/conversations/\(conversationID.uuidString)/messages",
            body: request,
            requiresAuth: true
        )
    }

    public func markMessagesRead(
        conversationID: UUID,
        upToMessageID: UUID? = nil
    ) async throws -> MarkMessagesReadResponse {
        try await requestJSON(
            method: "POST",
            path: "/api/v1/conversations/\(conversationID.uuidString)/read",
            body: MarkMessagesReadRequest(upToMessageID: upToMessageID),
            requiresAuth: true
        )
    }

    // MARK: - Safety

    public func listBlocks() async throws -> [BlockDTO] {
        try await requestJSON(method: "GET", path: "/api/v1/blocks", requiresAuth: true)
    }

    public func blockUser(_ request: BlockUserRequest) async throws -> BlockDTO {
        try await requestJSON(
            method: "POST",
            path: "/api/v1/blocks",
            body: request,
            requiresAuth: true
        )
    }

    public func unblockUser(blockedUserID: UUID) async throws {
        let _: StatusResponse = try await requestJSON(
            method: "DELETE",
            path: "/api/v1/blocks/\(blockedUserID.uuidString)",
            requiresAuth: true
        )
    }

    public func createReport(_ request: CreateReportRequest) async throws -> ReportDTO {
        try await requestJSON(
            method: "POST",
            path: "/api/v1/reports",
            body: request,
            requiresAuth: true
        )
    }

    // MARK: - Internal Request Execution & Automatic 401 Token Refresh

    private func requestJSON<ResponseType: Decodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        requiresAuth: Bool
    ) async throws -> ResponseType {
        try await executeWithAutoRefresh(
            method: method,
            path: path,
            queryItems: queryItems,
            bodyData: nil,
            contentType: nil,
            requiresAuth: requiresAuth
        )
    }

    private func requestJSON<RequestType: Encodable, ResponseType: Decodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: RequestType,
        requiresAuth: Bool
    ) async throws -> ResponseType {
        let data = try encoder.encode(body)
        return try await executeWithAutoRefresh(
            method: method,
            path: path,
            queryItems: queryItems,
            bodyData: data,
            contentType: "application/json",
            requiresAuth: requiresAuth
        )
    }

    private func requestRawData<ResponseType: Decodable>(
        method: String,
        path: String,
        data: Data,
        contentType: String,
        requiresAuth: Bool
    ) async throws -> ResponseType {
        try await executeWithAutoRefresh(
            method: method,
            path: path,
            queryItems: [],
            bodyData: data,
            contentType: contentType,
            requiresAuth: requiresAuth
        )
    }

    private func executeWithAutoRefresh<ResponseType: Decodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem],
        bodyData: Data?,
        contentType: String?,
        requiresAuth: Bool,
        allowRetryOn401: Bool = true
    ) async throws -> ResponseType {
        try Task.checkCancellation()

        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw APIClientError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.httpBody = bodyData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if let contentType {
            urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        if requiresAuth {
            guard let tokens = await tokenStore.loadTokens(), !tokens.accessToken.isEmpty else {
                throw APIClientError.unauthorized("Please sign in to continue.")
            }
            urlRequest.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, httpResponse) = try await transport.send(urlRequest)
        try Task.checkCancellation()

        if httpResponse.statusCode == 401, requiresAuth, allowRetryOn401 {
            // Attempt automatic token refresh and retry once
            let refreshed = try await attemptTokenRefresh()
            if refreshed {
                return try await executeWithAutoRefresh(
                    method: method,
                    path: path,
                    queryItems: queryItems,
                    bodyData: bodyData,
                    contentType: contentType,
                    requiresAuth: requiresAuth,
                    allowRetryOn401: false
                )
            }
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
                if httpResponse.statusCode == 401 {
                    throw APIClientError.unauthorized(apiError.message)
                }
                throw APIClientError.serverError(statusCode: httpResponse.statusCode, response: apiError)
            }
            if httpResponse.statusCode == 401 {
                throw APIClientError.unauthorized("Session expired. Please log in again.")
            }
            throw APIClientError.serverError(
                statusCode: httpResponse.statusCode,
                response: APIErrorResponse(code: .internalError, message: "HTTP \(httpResponse.statusCode)")
            )
        }

        do {
            return try decoder.decode(ResponseType.self, from: data)
        } catch {
            throw APIClientError.decodingFailed(error.localizedDescription)
        }
    }

    private func attemptTokenRefresh() async throws -> Bool {
        guard let currentTokens = await tokenStore.loadTokens(), !currentTokens.refreshToken.isEmpty else {
            return false
        }

        let refreshURL = baseURL.appendingPathComponent("/api/v1/auth/refresh")
        var request = URLRequest(url: refreshURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(RefreshTokenRequest(refreshToken: currentTokens.refreshToken))

        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode),
              let rotated = try? decoder.decode(AuthTokenResponse.self, from: data)
        else {
            try? await tokenStore.clearTokens()
            return false
        }

        try await tokenStore.saveTokens(
            StoredTokenPair(accessToken: rotated.accessToken, refreshToken: rotated.refreshToken)
        )
        return true
    }
}
