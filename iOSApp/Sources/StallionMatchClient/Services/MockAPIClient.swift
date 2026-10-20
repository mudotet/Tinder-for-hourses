import Foundation
import SharedModels

public enum MockSampleData {
    public static let currentUserID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    public static let otherUser1ID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    public static let otherUser2ID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
    public static let otherUser3ID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!

    public static let myHorseID = UUID(uuidString: "AAAAAAAA-1111-4111-8111-111111111111")!
    public static let lunaHorseID = UUID(uuidString: "BBBBBBBB-2222-4222-8222-222222222222")!
    public static let dakotaHorseID = UUID(uuidString: "CCCCCCCC-3333-4333-8333-333333333333")!
    public static let saffronHorseID = UUID(uuidString: "DDDDDDDD-4444-4444-8444-444444444444")!
    public static let sampleMatchID = UUID(uuidString: "EEEEEEEE-5555-4555-8555-555555555555")!
    public static let sampleConversationID = UUID(uuidString: "FFFFFFFF-6666-4666-8666-666666666666")!

    public static let currentUser = UserDTO(
        id: currentUserID,
        email: "clara@bluegrassstables.com",
        displayName: "Clara Vance",
        isEmailVerified: true,
        notificationsNewMatch: true,
        notificationsNewMessage: true,
        acceptedTermsVersion: SafetyConstants.currentTermsVersion,
        createdAt: Date().addingTimeInterval(-86_400 * 14)
    )

    public static let myHorse = HorseProfileDTO(
        id: myHorseID,
        ownerID: currentUserID,
        name: "Apollo",
        age: 7,
        sex: .stallion,
        breed: "Hanoverian",
        color: "Dark Bay",
        heightHands: 16.3,
        disciplines: [.dressage, .jumping],
        temperamentTags: ["Steady", "Forward", "Affectionate"],
        bio: "FEI-prospect Hanoverian stallion with three expressive gaits and a calm, gentlemanly barn presence.",
        location: HorseLocationDTO(city: "Lexington, KY", coarseLatitude: 38.04, coarseLongitude: -84.50),
        lookingFor: [.breedingInquiry, .ridingCompanion, .trailBuddy],
        healthInfo: HorseHealthInfoDTO(
            cogginsTestDate: Date().addingTimeInterval(-86_400 * 30),
            vaccinationsUpToDate: true
        ),
        pedigree: "Sire: Donnerhall Line / Dam: De Niro Line",
        photos: [
            HorsePhotoDTO(
                id: UUID(uuidString: "10000000-0000-4000-8000-000000000001")!,
                horseID: myHorseID,
                url: "https://images.unsplash.com/photo-1553284965-83fd3e82fa5a?w=800",
                position: 0,
                createdAt: Date()
            ),
            HorsePhotoDTO(
                id: UUID(uuidString: "10000000-0000-4000-8000-000000000002")!,
                horseID: myHorseID,
                url: "https://images.unsplash.com/photo-1534773728080-33d31da27ae5?w=800",
                position: 1,
                createdAt: Date()
            )
        ],
        distanceKm: 0.0,
        createdAt: Date().addingTimeInterval(-86_400 * 10),
        updatedAt: Date()
    )

    public static let discoveryHorses: [HorseProfileDTO] = [
        HorseProfileDTO(
            id: lunaHorseID,
            ownerID: otherUser1ID,
            name: "Luna",
            age: 6,
            sex: .mare,
            breed: "Andalusian",
            color: "Dapple Grey",
            heightHands: 15.3,
            disciplines: [.dressage, .trail, .pleasure],
            temperamentTags: ["Sensitive", "Loyal", "Sure-Footed"],
            bio: "Graceful Andalusian mare who loves peaceful morning trail rides and classical dressage schooling.",
            location: HorseLocationDTO(city: "Versailles, KY", coarseLatitude: 38.05, coarseLongitude: -84.73),
            lookingFor: [.trailBuddy, .ridingCompanion, .breedingInquiry],
            healthInfo: HorseHealthInfoDTO(
                cogginsTestDate: Date().addingTimeInterval(-86_400 * 20),
                vaccinationsUpToDate: true
            ),
            pedigree: "PRE Registered — Cartujano Bloodline",
            photos: [
                HorsePhotoDTO(
                    id: UUID(uuidString: "20000000-0000-4000-8000-000000000001")!,
                    horseID: lunaHorseID,
                    url: "https://images.unsplash.com/photo-1598974357801-cbca100e65d3?w=800",
                    position: 0,
                    createdAt: Date()
                ),
                HorsePhotoDTO(
                    id: UUID(uuidString: "20000000-0000-4000-8000-000000000002")!,
                    horseID: lunaHorseID,
                    url: "https://images.unsplash.com/photo-1551884831-bbf3cdc6469e?w=800",
                    position: 1,
                    createdAt: Date()
                )
            ],
            distanceKm: 20.2,
            createdAt: Date().addingTimeInterval(-86_400 * 5),
            updatedAt: Date()
        ),
        HorseProfileDTO(
            id: dakotaHorseID,
            ownerID: otherUser2ID,
            name: "Dakota",
            age: 8,
            sex: .gelding,
            breed: "Quarter Horse",
            color: "Chestnut",
            heightHands: 15.1,
            disciplines: [.western, .trail],
            temperamentTags: ["Bombproof", "Easygoing", "Social"],
            bio: "Seasoned trail gelding who crosses water, bridges, and open pastures without batting an eye. Looking for weekend trail companions!",
            location: HorseLocationDTO(city: "Georgetown, KY", coarseLatitude: 38.21, coarseLongitude: -84.56),
            lookingFor: [.trailBuddy, .friendship],
            healthInfo: HorseHealthInfoDTO(
                cogginsTestDate: Date().addingTimeInterval(-86_400 * 45),
                vaccinationsUpToDate: true
            ),
            pedigree: "AQHA Doc Bar / Poco Bueno Lines",
            photos: [
                HorsePhotoDTO(
                    id: UUID(uuidString: "30000000-0000-4000-8000-000000000001")!,
                    horseID: dakotaHorseID,
                    url: "https://images.unsplash.com/photo-1509914398892-963f53e6e2f1?w=800",
                    position: 0,
                    createdAt: Date()
                ),
                HorsePhotoDTO(
                    id: UUID(uuidString: "30000000-0000-4000-8000-000000000002")!,
                    horseID: dakotaHorseID,
                    url: "https://images.unsplash.com/photo-1566251037378-5e04e3bec343?w=800",
                    position: 1,
                    createdAt: Date()
                )
            ],
            distanceKm: 19.6,
            createdAt: Date().addingTimeInterval(-86_400 * 4),
            updatedAt: Date()
        ),
        HorseProfileDTO(
            id: saffronHorseID,
            ownerID: otherUser3ID,
            name: "Saffron",
            age: 5,
            sex: .mare,
            breed: "Arabian",
            color: "Chestnut Flaxen",
            heightHands: 15.0,
            disciplines: [.endurance, .trail],
            temperamentTags: ["Spirited", "Intelligent", "Brave"],
            bio: "50-mile endurance Arabian mare training in the Bluegrass hills. Loves brisk conditioning rides with steady partners.",
            location: HorseLocationDTO(city: "Paris, KY", coarseLatitude: 38.21, coarseLongitude: -84.25),
            lookingFor: [.ridingCompanion, .trailBuddy, .stablemate],
            healthInfo: HorseHealthInfoDTO(
                cogginsTestDate: Date().addingTimeInterval(-86_400 * 15),
                vaccinationsUpToDate: true
            ),
            pedigree: "AHA Crabbet / Egyptian Lines",
            photos: [
                HorsePhotoDTO(
                    id: UUID(uuidString: "40000000-0000-4000-8000-000000000001")!,
                    horseID: saffronHorseID,
                    url: "https://images.unsplash.com/photo-1534773728080-33d31da27ae5?w=800",
                    position: 0,
                    createdAt: Date()
                ),
                HorsePhotoDTO(
                    id: UUID(uuidString: "40000000-0000-4000-8000-000000000002")!,
                    horseID: saffronHorseID,
                    url: "https://images.unsplash.com/photo-1553284965-83fd3e82fa5a?w=800",
                    position: 1,
                    createdAt: Date()
                )
            ],
            distanceKm: 28.9,
            createdAt: Date().addingTimeInterval(-86_400 * 3),
            updatedAt: Date()
        )
    ]

    public static let sampleMatch = MatchDTO(
        id: sampleMatchID,
        horseA: myHorse,
        horseB: discoveryHorses[0],
        conversationID: sampleConversationID,
        createdAt: Date().addingTimeInterval(-3600 * 5)
    )

    public static let sampleMessages: [MessageDTO] = [
        MessageDTO(
            id: UUID(uuidString: "70000000-0000-4000-8000-000000000001")!,
            conversationID: sampleConversationID,
            senderUserID: otherUser1ID,
            senderHorseID: lunaHorseID,
            body: "Hi Clara! Apollo has such wonderful movement. Luna and I ride at the Kentucky Horse Park trails on Saturday mornings!",
            readAt: Date().addingTimeInterval(-1800),
            createdAt: Date().addingTimeInterval(-3600)
        ),
        MessageDTO(
            id: UUID(uuidString: "70000000-0000-4000-8000-000000000002")!,
            conversationID: sampleConversationID,
            senderUserID: currentUserID,
            senderHorseID: myHorseID,
            body: "Thank you! Apollo would love to join Luna for a morning hack around the park.",
            readAt: Date().addingTimeInterval(-900),
            createdAt: Date().addingTimeInterval(-1200)
        )
    ]

    public static let sampleConversationSummary = ConversationSummaryDTO(
        id: sampleConversationID,
        matchID: sampleMatchID,
        myHorse: myHorse,
        otherHorse: discoveryHorses[0],
        lastMessage: sampleMessages.last,
        unreadCount: 0,
        updatedAt: Date().addingTimeInterval(-1200)
    )
}

/// Complete standalone `MockAPIClient` actor allowing the iOS app, `#Preview`s, and UI tests to run without the server.
public actor MockAPIClient: APIClientProtocol {
    private var currentUser: UserDTO
    private var myHorses: [HorseProfileDTO]
    private var candidateHorses: [HorseProfileDTO]
    private var swipedHorseIDs: Set<UUID> = []
    private var matches: [MatchDTO]
    private var conversations: [ConversationSummaryDTO]
    private var messagesByConversation: [UUID: [MessageDTO]]
    private var blocks: [BlockDTO] = []
    private var reports: [ReportDTO] = []
    private let tokenStore: any TokenStore

    public init(
        currentUser: UserDTO = MockSampleData.currentUser,
        myHorses: [HorseProfileDTO] = [MockSampleData.myHorse],
        candidateHorses: [HorseProfileDTO] = MockSampleData.discoveryHorses,
        matches: [MatchDTO] = [MockSampleData.sampleMatch],
        conversations: [ConversationSummaryDTO] = [MockSampleData.sampleConversationSummary],
        messagesByConversation: [UUID: [MessageDTO]] = [
            MockSampleData.sampleConversationID: MockSampleData.sampleMessages
        ],
        tokenStore: any TokenStore = InMemoryTokenStore()
    ) {
        self.currentUser = currentUser
        self.myHorses = myHorses
        self.candidateHorses = candidateHorses
        self.matches = matches
        self.conversations = conversations
        self.messagesByConversation = messagesByConversation
        self.tokenStore = tokenStore
    }

    public func signUp(_ request: SignUpRequest) async throws -> AuthTokenResponse {
        currentUser = UserDTO(
            id: MockSampleData.currentUserID,
            email: request.email,
            displayName: request.displayName ?? "Horse Handler",
            isEmailVerified: false,
            notificationsNewMatch: true,
            notificationsNewMessage: true,
            acceptedTermsVersion: SafetyConstants.currentTermsVersion,
            createdAt: Date()
        )
        let pair = StoredTokenPair(accessToken: "mock-access-token", refreshToken: "mock-refresh-token")
        try await tokenStore.saveTokens(pair)
        return AuthTokenResponse(
            accessToken: pair.accessToken,
            refreshToken: pair.refreshToken,
            expiresIn: 900,
            user: currentUser
        )
    }

    public func login(_ request: LoginRequest) async throws -> AuthTokenResponse {
        currentUser = UserDTO(
            id: currentUser.id,
            email: request.email,
            displayName: currentUser.displayName ?? "Clara Vance",
            isEmailVerified: true,
            notificationsNewMatch: currentUser.notificationsNewMatch,
            notificationsNewMessage: currentUser.notificationsNewMessage,
            acceptedTermsVersion: currentUser.acceptedTermsVersion,
            createdAt: currentUser.createdAt
        )
        let pair = StoredTokenPair(accessToken: "mock-access-token", refreshToken: "mock-refresh-token")
        try await tokenStore.saveTokens(pair)
        return AuthTokenResponse(
            accessToken: pair.accessToken,
            refreshToken: pair.refreshToken,
            expiresIn: 900,
            user: currentUser
        )
    }

    public func signInWithApple(_ request: AppleSignInRequest) async throws -> AuthTokenResponse {
        currentUser = UserDTO(
            id: currentUser.id,
            email: request.email ?? currentUser.email,
            displayName: request.fullName ?? currentUser.displayName ?? "Apple Equestrian",
            isEmailVerified: true,
            notificationsNewMatch: true,
            notificationsNewMessage: true,
            acceptedTermsVersion: SafetyConstants.currentTermsVersion,
            createdAt: Date()
        )
        let pair = StoredTokenPair(accessToken: "mock-apple-access-token", refreshToken: "mock-apple-refresh-token")
        try await tokenStore.saveTokens(pair)
        return AuthTokenResponse(
            accessToken: pair.accessToken,
            refreshToken: pair.refreshToken,
            expiresIn: 900,
            user: currentUser
        )
    }

    public func logout() async throws {
        try await tokenStore.clearTokens()
    }

    public func getMe() async throws -> UserDTO {
        currentUser
    }

    public func updateMe(_ request: UpdateUserSettingsRequest) async throws -> UserDTO {
        currentUser = UserDTO(
            id: currentUser.id,
            email: currentUser.email,
            displayName: request.displayName ?? currentUser.displayName,
            isEmailVerified: currentUser.isEmailVerified,
            notificationsNewMatch: request.notificationsNewMatch ?? currentUser.notificationsNewMatch,
            notificationsNewMessage: request.notificationsNewMessage ?? currentUser.notificationsNewMessage,
            acceptedTermsVersion: request.acceptedTermsVersion ?? currentUser.acceptedTermsVersion,
            createdAt: currentUser.createdAt
        )
        return currentUser
    }

    public func registerDeviceToken(_ request: RegisterDeviceTokenRequest) async throws -> DeviceTokenDTO {
        DeviceTokenDTO(
            id: UUID(),
            userID: currentUser.id,
            token: request.token,
            platform: request.platform,
            createdAt: Date()
        )
    }

    public func deleteAccount() async throws {
        myHorses.removeAll()
        matches.removeAll()
        conversations.removeAll()
        messagesByConversation.removeAll()
        try await tokenStore.clearTokens()
    }

    public func listMyHorses() async throws -> [HorseProfileDTO] {
        myHorses
    }

    public func createHorse(_ request: CreateHorseProfileRequest) async throws -> HorseProfileDTO {
        if case .objectionableContent = ObjectionableContentFilter.validateBio(request.bio) {
            throw APIClientError.serverError(
                statusCode: 400,
                response: APIErrorResponse(code: .contentRejected, message: "Bio contains prohibited content.")
            )
        }
        let horseID = UUID()
        let horse = HorseProfileDTO(
            id: horseID,
            ownerID: currentUser.id,
            name: request.name,
            age: request.age,
            sex: request.sex,
            breed: request.breed,
            color: request.color,
            heightHands: request.heightHands,
            disciplines: request.disciplines,
            temperamentTags: request.temperamentTags,
            bio: request.bio,
            location: request.location,
            lookingFor: request.lookingFor,
            healthInfo: request.healthInfo,
            pedigree: request.pedigree,
            photos: [
                HorsePhotoDTO(
                    id: UUID(),
                    horseID: horseID,
                    url: "https://images.unsplash.com/photo-1553284965-83fd3e82fa5a?w=800",
                    position: 0,
                    createdAt: Date()
                ),
                HorsePhotoDTO(
                    id: UUID(),
                    horseID: horseID,
                    url: "https://images.unsplash.com/photo-1534773728080-33d31da27ae5?w=800",
                    position: 1,
                    createdAt: Date()
                )
            ],
            distanceKm: 0.0,
            createdAt: Date(),
            updatedAt: Date()
        )
        myHorses.append(horse)
        return horse
    }

    public func updateHorse(id: UUID, _ request: UpdateHorseProfileRequest) async throws -> HorseProfileDTO {
        guard let idx = myHorses.firstIndex(where: { $0.id == id }) else {
            throw APIClientError.serverError(
                statusCode: 404,
                response: APIErrorResponse(code: .notFound, message: "Horse not found")
            )
        }
        let existing = myHorses[idx]
        let updated = HorseProfileDTO(
            id: existing.id,
            ownerID: existing.ownerID,
            name: request.name ?? existing.name,
            age: request.age ?? existing.age,
            sex: request.sex ?? existing.sex,
            breed: request.breed ?? existing.breed,
            color: request.color ?? existing.color,
            heightHands: request.heightHands ?? existing.heightHands,
            disciplines: request.disciplines ?? existing.disciplines,
            temperamentTags: request.temperamentTags ?? existing.temperamentTags,
            bio: request.bio ?? existing.bio,
            location: request.location ?? existing.location,
            lookingFor: request.lookingFor ?? existing.lookingFor,
            healthInfo: request.healthInfo ?? existing.healthInfo,
            pedigree: request.pedigree ?? existing.pedigree,
            photos: existing.photos,
            distanceKm: existing.distanceKm,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        myHorses[idx] = updated
        return updated
    }

    public func deleteHorse(id: UUID) async throws {
        myHorses.removeAll { $0.id == id }
    }

    public func uploadHorsePhoto(horseID: UUID, jpegData: Data) async throws -> HorsePhotoDTO {
        let photo = HorsePhotoDTO(
            id: UUID(),
            horseID: horseID,
            url: "https://images.unsplash.com/photo-1553284965-83fd3e82fa5a?w=800",
            position: 0,
            createdAt: Date()
        )
        return photo
    }

    public func reorderHorsePhotos(horseID: UUID, photoIDs: [UUID]) async throws -> [HorsePhotoDTO] {
        guard let horse = myHorses.first(where: { $0.id == horseID }) else { return [] }
        return horse.photos
    }

    public func deleteHorsePhoto(horseID: UUID, photoID: UUID) async throws {}

    public func discoverHorses(query: DiscoveryFilterQuery) async throws -> CursorPage<HorseProfileDTO> {
        let blockedUserIDs = Set(blocks.map(\.blockedUserID))
        let filtered = candidateHorses.filter { horse in
            guard !swipedHorseIDs.contains(horse.id) else { return false }
            guard !blockedUserIDs.contains(horse.ownerID) else { return false }
            if let sex = query.sex, horse.sex != sex { return false }
            if let breed = query.breed, !breed.isEmpty,
               !horse.breed.localizedCaseInsensitiveContains(breed)
            {
                return false
            }
            if let minAge = query.minAge, horse.age < minAge { return false }
            if let maxAge = query.maxAge, horse.age > maxAge { return false }
            if let discipline = query.discipline, !horse.disciplines.contains(discipline) { return false }
            if let lookingFor = query.lookingFor, !horse.lookingFor.contains(lookingFor) { return false }
            if let maxDist = query.maxDistanceKm, let dist = horse.distanceKm, dist > maxDist { return false }
            return true
        }
        return CursorPage(items: filtered, nextCursor: nil)
    }

    public func recordSwipe(_ request: SwipeRequest) async throws -> SwipeResponse {
        swipedHorseIDs.insert(request.targetHorseID)
        let swipeID = UUID()

        guard request.direction == .like,
              let targetHorse = candidateHorses.first(where: { $0.id == request.targetHorseID })
        else {
            return SwipeResponse(swipeID: swipeID, direction: request.direction, isMatch: false, match: nil)
        }

        let myHorse = myHorses.first(where: { $0.id == request.swiperHorseID }) ?? MockSampleData.myHorse
        let conversationID = UUID()
        let match = MatchDTO(
            id: UUID(),
            horseA: myHorse,
            horseB: targetHorse,
            conversationID: conversationID,
            createdAt: Date()
        )
        matches.insert(match, at: 0)

        let summary = ConversationSummaryDTO(
            id: conversationID,
            matchID: match.id,
            myHorse: myHorse,
            otherHorse: targetHorse,
            lastMessage: nil,
            unreadCount: 0,
            updatedAt: Date()
        )
        conversations.insert(summary, at: 0)
        messagesByConversation[conversationID] = []

        return SwipeResponse(swipeID: swipeID, direction: .like, isMatch: true, match: match)
    }

    public func listMatches() async throws -> [MatchDTO] {
        let blockedUserIDs = Set(blocks.map(\.blockedUserID))
        return matches.filter {
            !blockedUserIDs.contains($0.horseA.ownerID) && !blockedUserIDs.contains($0.horseB.ownerID)
        }
    }

    public func listConversations() async throws -> [ConversationSummaryDTO] {
        let blockedUserIDs = Set(blocks.map(\.blockedUserID))
        return conversations.filter { !blockedUserIDs.contains($0.otherHorse.ownerID) }
    }

    public func listMessages(
        conversationID: UUID,
        cursor: String?,
        limit: Int
    ) async throws -> CursorPage<MessageDTO> {
        let msgs = messagesByConversation[conversationID] ?? []
        return CursorPage(items: msgs, nextCursor: nil)
    }

    public func sendMessage(conversationID: UUID, request: SendMessageRequest) async throws -> MessageDTO {
        if case .objectionableContent = ObjectionableContentFilter.validateMessage(request.body) {
            throw APIClientError.serverError(
                statusCode: 400,
                response: APIErrorResponse(code: .contentRejected, message: "Message contains prohibited language.")
            )
        }
        let message = MessageDTO(
            id: UUID(),
            conversationID: conversationID,
            senderUserID: currentUser.id,
            senderHorseID: request.senderHorseID,
            body: request.body,
            readAt: nil,
            createdAt: Date()
        )
        messagesByConversation[conversationID, default: []].append(message)
        if let idx = conversations.firstIndex(where: { $0.id == conversationID }) {
            let existing = conversations[idx]
            conversations[idx] = ConversationSummaryDTO(
                id: existing.id,
                matchID: existing.matchID,
                myHorse: existing.myHorse,
                otherHorse: existing.otherHorse,
                lastMessage: message,
                unreadCount: 0,
                updatedAt: Date()
            )
        }
        return message
    }

    public func markMessagesRead(
        conversationID: UUID,
        upToMessageID: UUID?
    ) async throws -> MarkMessagesReadResponse {
        let now = Date()
        if let idx = conversations.firstIndex(where: { $0.id == conversationID }) {
            let existing = conversations[idx]
            conversations[idx] = ConversationSummaryDTO(
                id: existing.id,
                matchID: existing.matchID,
                myHorse: existing.myHorse,
                otherHorse: existing.otherHorse,
                lastMessage: existing.lastMessage,
                unreadCount: 0,
                updatedAt: existing.updatedAt
            )
        }
        return MarkMessagesReadResponse(conversationID: conversationID, readCount: 1, readAt: now)
    }

    public func listBlocks() async throws -> [BlockDTO] {
        blocks
    }

    public func blockUser(_ request: BlockUserRequest) async throws -> BlockDTO {
        let block = BlockDTO(
            id: UUID(),
            blockerUserID: currentUser.id,
            blockedUserID: request.blockedUserID,
            createdAt: Date()
        )
        blocks.append(block)
        return block
    }

    public func unblockUser(blockedUserID: UUID) async throws {
        blocks.removeAll { $0.blockedUserID == blockedUserID }
    }

    public func createReport(_ request: CreateReportRequest) async throws -> ReportDTO {
        let report = ReportDTO(
            id: UUID(),
            reporterUserID: currentUser.id,
            targetType: request.targetType,
            targetID: request.targetID,
            reason: request.reason,
            details: request.details,
            status: .pending,
            createdAt: Date()
        )
        reports.append(report)
        return report
    }
}
