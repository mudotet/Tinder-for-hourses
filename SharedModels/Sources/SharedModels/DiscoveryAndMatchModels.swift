import Foundation

/// Query parameters for filtering and paginating horse discovery cards.
public struct DiscoveryFilterQuery: Codable, Sendable, Equatable {
    public var activeHorseID: UUID
    public var maxDistanceKm: Double?
    public var breed: String?
    public var sex: HorseSex?
    public var minAge: Int?
    public var maxAge: Int?
    public var discipline: HorseDiscipline?
    public var lookingFor: LookingForCategory?
    public var cursor: String?
    public var limit: Int?

    public init(
        activeHorseID: UUID,
        maxDistanceKm: Double? = nil,
        breed: String? = nil,
        sex: HorseSex? = nil,
        minAge: Int? = nil,
        maxAge: Int? = nil,
        discipline: HorseDiscipline? = nil,
        lookingFor: LookingForCategory? = nil,
        cursor: String? = nil,
        limit: Int? = 20
    ) {
        self.activeHorseID = activeHorseID
        self.maxDistanceKm = maxDistanceKm
        self.breed = breed
        self.sex = sex
        self.minAge = minAge
        self.maxAge = maxAge
        self.discipline = discipline
        self.lookingFor = lookingFor
        self.cursor = cursor
        self.limit = limit
    }
}

/// Direction of a user's swipe on a target horse profile.
public enum SwipeDirection: String, Codable, Sendable, CaseIterable, Hashable {
    case like
    case pass
}

/// Request payload for recording a swipe from one of the user's horses onto a target horse.
public struct SwipeRequest: Codable, Sendable, Equatable {
    public let swiperHorseID: UUID
    public let targetHorseID: UUID
    public let direction: SwipeDirection

    public init(swiperHorseID: UUID, targetHorseID: UUID, direction: SwipeDirection) {
        self.swiperHorseID = swiperHorseID
        self.targetHorseID = targetHorseID
        self.direction = direction
    }
}

/// Match DTO representing a mutual right-swipe between two horses.
public struct MatchDTO: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let horseA: HorseProfileDTO
    public let horseB: HorseProfileDTO
    public let conversationID: UUID
    public let createdAt: Date

    public init(
        id: UUID,
        horseA: HorseProfileDTO,
        horseB: HorseProfileDTO,
        conversationID: UUID,
        createdAt: Date
    ) {
        self.id = id
        self.horseA = horseA
        self.horseB = horseB
        self.conversationID = conversationID
        self.createdAt = createdAt
    }
}

/// Response returned after processing a swipe.
public struct SwipeResponse: Codable, Sendable, Equatable {
    public let swipeID: UUID
    public let direction: SwipeDirection
    public let isMatch: Bool
    public let match: MatchDTO?

    public init(
        swipeID: UUID,
        direction: SwipeDirection,
        isMatch: Bool,
        match: MatchDTO? = nil
    ) {
        self.swipeID = swipeID
        self.direction = direction
        self.isMatch = isMatch
        self.match = match
    }
}
