import Foundation
import Observation
import SharedModels

public enum ScreenLoadState: Sendable, Equatable {
    case idle
    case loading
    case loaded
    case empty(String)
    case offline(String)
    case error(String)
}

@MainActor
@Observable
public final class AppStateViewModel {
    public let apiClient: any APIClientProtocol
    public let tokenStore: any TokenStore

    public var currentUser: UserDTO?
    public var myHorses: [HorseProfileDTO] = []
    public var activeHorseID: UUID?
    public var isAuthenticated: Bool = false
    public var isCheckingSession: Bool = false
    public var authErrorMessage: String?

    public var activeHorse: HorseProfileDTO? {
        if let activeHorseID, let found = myHorses.first(where: { $0.id == activeHorseID }) {
            return found
        }
        return myHorses.first
    }

    public init(
        apiClient: any APIClientProtocol = MockAPIClient(),
        tokenStore: any TokenStore = InMemoryTokenStore(),
        preauthenticatedUser: UserDTO? = nil,
        initialHorses: [HorseProfileDTO] = []
    ) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
        self.currentUser = preauthenticatedUser
        self.myHorses = initialHorses
        self.activeHorseID = initialHorses.first?.id
        self.isAuthenticated = (preauthenticatedUser != nil)
    }

    public func restoreSession() async {
        isCheckingSession = true
        defer { isCheckingSession = false }

        guard await tokenStore.loadTokens() != nil else {
            isAuthenticated = false
            return
        }

        do {
            let user = try await apiClient.getMe()
            let horses = try await apiClient.listMyHorses()
            self.currentUser = user
            self.myHorses = horses
            self.activeHorseID = horses.first?.id
            self.isAuthenticated = true
            self.authErrorMessage = nil
        } catch {
            self.isAuthenticated = false
        }
    }

    public func signUp(email: String, password: String, displayName: String) async {
        authErrorMessage = nil
        do {
            let response = try await apiClient.signUp(
                SignUpRequest(email: email, password: password, displayName: displayName)
            )
            self.currentUser = response.user
            self.myHorses = try await apiClient.listMyHorses()
            self.activeHorseID = self.myHorses.first?.id
            self.isAuthenticated = true
        } catch {
            self.authErrorMessage = error.localizedDescription
        }
    }

    public func login(email: String, password: String) async {
        authErrorMessage = nil
        do {
            let response = try await apiClient.login(LoginRequest(email: email, password: password))
            self.currentUser = response.user
            self.myHorses = try await apiClient.listMyHorses()
            self.activeHorseID = self.myHorses.first?.id
            self.isAuthenticated = true
        } catch {
            self.authErrorMessage = error.localizedDescription
        }
    }

    public func signInWithApple(identityToken: String, fullName: String?, email: String?) async {
        authErrorMessage = nil
        do {
            let response = try await apiClient.signInWithApple(
                AppleSignInRequest(identityToken: identityToken, fullName: fullName, email: email)
            )
            self.currentUser = response.user
            self.myHorses = try await apiClient.listMyHorses()
            self.activeHorseID = self.myHorses.first?.id
            self.isAuthenticated = true
        } catch {
            self.authErrorMessage = error.localizedDescription
        }
    }

    public func createHorse(_ request: CreateHorseProfileRequest) async throws -> HorseProfileDTO {
        let created = try await apiClient.createHorse(request)
        myHorses.append(created)
        if activeHorseID == nil {
            activeHorseID = created.id
        }
        return created
    }

    public func updateHorse(id: UUID, _ request: UpdateHorseProfileRequest) async throws -> HorseProfileDTO {
        let updated = try await apiClient.updateHorse(id: id, request)
        if let index = myHorses.firstIndex(where: { $0.id == id }) {
            myHorses[index] = updated
        }
        return updated
    }

    public func deleteHorse(id: UUID) async throws {
        try await apiClient.deleteHorse(id: id)
        myHorses.removeAll { $0.id == id }
        if activeHorseID == id {
            activeHorseID = myHorses.first?.id
        }
    }

    public func updateNotificationSettings(newMatch: Bool, newMessage: Bool) async {
        do {
            let updated = try await apiClient.updateMe(
                UpdateUserSettingsRequest(
                    notificationsNewMatch: newMatch,
                    notificationsNewMessage: newMessage
                )
            )
            self.currentUser = updated
        } catch {
            self.authErrorMessage = error.localizedDescription
        }
    }

    public func logout() async {
        try? await apiClient.logout()
        self.currentUser = nil
        self.myHorses = []
        self.activeHorseID = nil
        self.isAuthenticated = false
    }

    public func deleteAccount() async throws {
        try await apiClient.deleteAccount()
        self.currentUser = nil
        self.myHorses = []
        self.activeHorseID = nil
        self.isAuthenticated = false
    }
}

@MainActor
@Observable
public final class DiscoverViewModel {
    private let apiClient: any APIClientProtocol

    public var cards: [HorseProfileDTO] = []
    public var nextCursor: String?
    public var state: ScreenLoadState = .idle
    public var celebratedMatch: MatchDTO?

    // Filter state
    public var maxDistanceKm: Double = 100
    public var filterBreed: String = ""
    public var filterSex: HorseSex?
    public var filterMinAge: Int?
    public var filterMaxAge: Int?
    public var filterDiscipline: HorseDiscipline?
    public var filterLookingFor: LookingForCategory?

    public init(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
    }

    public func loadCards(activeHorseID: UUID?, reset: Bool = true) async {
        guard let activeHorseID else {
            cards = []
            state = .empty("Create your first horse profile to start discovering nearby horses.")
            return
        }

        if reset {
            state = .loading
            nextCursor = nil
        }

        let query = DiscoveryFilterQuery(
            activeHorseID: activeHorseID,
            maxDistanceKm: maxDistanceKm,
            breed: filterBreed.isEmpty ? nil : filterBreed,
            sex: filterSex,
            minAge: filterMinAge,
            maxAge: filterMaxAge,
            discipline: filterDiscipline,
            lookingFor: filterLookingFor,
            cursor: reset ? nil : nextCursor,
            limit: 20
        )

        do {
            let page = try await apiClient.discoverHorses(query: query)
            if reset {
                cards = page.items
            } else {
                cards.append(contentsOf: page.items)
            }
            nextCursor = page.nextCursor
            state = cards.isEmpty
                ? .empty("No more horses match your current filters. Try expanding your distance radius.")
                : .loaded
        } catch let apiError as APIClientError {
            if case .offline(let message) = apiError {
                state = .offline(message)
            } else {
                state = .error(apiError.localizedDescription)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    public func swipe(
        on targetHorse: HorseProfileDTO,
        direction: SwipeDirection,
        activeHorseID: UUID
    ) async {
        cards.removeAll { $0.id == targetHorse.id }
        if cards.isEmpty {
            state = .empty("You've seen all nearby horses for now!")
        }

        do {
            let response = try await apiClient.recordSwipe(
                SwipeRequest(
                    swiperHorseID: activeHorseID,
                    targetHorseID: targetHorse.id,
                    direction: direction
                )
            )
            if response.isMatch, let match = response.match {
                celebratedMatch = match
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    public func resetFilters(activeHorseID: UUID?) async {
        maxDistanceKm = 100
        filterBreed = ""
        filterSex = nil
        filterMinAge = nil
        filterMaxAge = nil
        filterDiscipline = nil
        filterLookingFor = nil
        await loadCards(activeHorseID: activeHorseID, reset: true)
    }
}

@MainActor
@Observable
public final class MatchesAndConversationsViewModel {
    private let apiClient: any APIClientProtocol

    public var matches: [MatchDTO] = []
    public var conversations: [ConversationSummaryDTO] = []
    public var matchesState: ScreenLoadState = .idle
    public var conversationsState: ScreenLoadState = .idle

    public var totalUnreadCount: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }

    public init(apiClient: any APIClientProtocol) {
        self.apiClient = apiClient
    }

    public func refreshAll() async {
        await loadMatches()
        await loadConversations()
    }

    public func loadMatches() async {
        matchesState = .loading
        do {
            let loaded = try await apiClient.listMatches()
            matches = loaded
            matchesState = loaded.isEmpty
                ? .empty("No matches yet. Swipe right on Discover to connect with nearby horses!")
                : .loaded
        } catch let apiError as APIClientError {
            if case .offline(let msg) = apiError {
                matchesState = .offline(msg)
            } else {
                matchesState = .error(apiError.localizedDescription)
            }
        } catch {
            matchesState = .error(error.localizedDescription)
        }
    }

    public func loadConversations() async {
        conversationsState = .loading
        do {
            let loaded = try await apiClient.listConversations()
            conversations = loaded
            conversationsState = loaded.isEmpty
                ? .empty("No conversations yet. Match with a horse to start chatting!")
                : .loaded
        } catch let apiError as APIClientError {
            if case .offline(let msg) = apiError {
                conversationsState = .offline(msg)
            } else {
                conversationsState = .error(apiError.localizedDescription)
            }
        } catch {
            conversationsState = .error(error.localizedDescription)
        }
    }
}

@MainActor
@Observable
public final class ChatDetailViewModel {
    private let apiClient: any APIClientProtocol
    public let conversationSummary: ConversationSummaryDTO

    public var messages: [MessageDTO] = []
    public var draftText: String = ""
    public var isOtherHorseTyping: Bool = false
    public var state: ScreenLoadState = .idle
    public var safetyBannerMessage: String?

    public init(
        conversationSummary: ConversationSummaryDTO,
        apiClient: any APIClientProtocol
    ) {
        self.conversationSummary = conversationSummary
        self.apiClient = apiClient
    }

    public func loadMessages() async {
        state = .loading
        do {
            let page = try await apiClient.listMessages(
                conversationID: conversationSummary.id,
                cursor: nil,
                limit: 50
            )
            messages = page.items.sorted { $0.createdAt < $1.createdAt }
            state = messages.isEmpty
                ? .empty("Say hello to \(conversationSummary.otherHorse.name)!")
                : .loaded
            _ = try? await apiClient.markMessagesRead(
                conversationID: conversationSummary.id,
                upToMessageID: messages.last?.id
            )
        } catch let apiError as APIClientError {
            if case .offline(let msg) = apiError {
                state = .offline(msg)
            } else {
                state = .error(apiError.localizedDescription)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    public func sendMessage() async {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch ObjectionableContentFilter.validateMessage(trimmed) {
        case .valid:
            break
        case .empty:
            return
        case .tooLong(let maxLen):
            safetyBannerMessage = "Message must be \(maxLen) characters or fewer."
            return
        case .objectionableContent:
            safetyBannerMessage = "Message blocked by safety filter: prohibited or payment-solicitation language is not allowed."
            return
        }

        safetyBannerMessage = nil
        let textToSend = trimmed
        draftText = ""

        do {
            let sent = try await apiClient.sendMessage(
                conversationID: conversationSummary.id,
                request: SendMessageRequest(
                    senderHorseID: conversationSummary.myHorse.id,
                    body: textToSend
                )
            )
            if !messages.contains(where: { $0.id == sent.id }) {
                messages.append(sent)
            }
            state = .loaded
        } catch {
            draftText = textToSend
            safetyBannerMessage = error.localizedDescription
        }
    }

    public func handleWebSocketEvent(_ event: WebSocketMessage) {
        switch event {
        case .messageReceived(let msg) where msg.conversationID == conversationSummary.id:
            if !messages.contains(where: { $0.id == msg.id }) {
                messages.append(msg)
                state = .loaded
            }
        case .typing(let payload) where payload.conversationID == conversationSummary.id:
            if payload.horseID == conversationSummary.otherHorse.id {
                isOtherHorseTyping = payload.isTyping
            }
        case .readReceipt(let receipt) where receipt.conversationID == conversationSummary.id:
            messages = messages.map { existing in
                guard existing.readAt == nil else { return existing }
                return MessageDTO(
                    id: existing.id,
                    conversationID: existing.conversationID,
                    senderUserID: existing.senderUserID,
                    senderHorseID: existing.senderHorseID,
                    body: existing.body,
                    readAt: receipt.readAt,
                    createdAt: existing.createdAt
                )
            }
        default:
            break
        }
    }

    public func reportOtherHorse(reason: ReportReason, details: String) async throws {
        _ = try await apiClient.createReport(
            CreateReportRequest(
                targetType: .horse,
                targetID: conversationSummary.otherHorse.id,
                reason: reason,
                details: details
            )
        )
    }

    public func blockOtherOwner(reason: String?) async throws {
        _ = try await apiClient.blockUser(
            BlockUserRequest(
                blockedUserID: conversationSummary.otherHorse.ownerID,
                reason: reason
            )
        )
    }
}
