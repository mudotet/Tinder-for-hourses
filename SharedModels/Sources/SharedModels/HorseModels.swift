import Foundation

/// Biological/equestrian sex categories for a horse profile.
public enum HorseSex: String, Codable, Sendable, CaseIterable, Hashable {
    case mare
    case stallion
    case gelding

    public var displayName: String {
        switch self {
        case .mare: return "Mare"
        case .stallion: return "Stallion"
        case .gelding: return "Gelding"
        }
    }
}

/// Equestrian disciplines supported for horse profiles and discovery filtering.
public enum HorseDiscipline: String, Codable, Sendable, CaseIterable, Hashable {
    case dressage
    case jumping
    case western
    case trail
    case racing
    case endurance
    case pleasure
    case other

    public var displayName: String {
        switch self {
        case .dressage: return "Dressage"
        case .jumping: return "Jumping"
        case .western: return "Western"
        case .trail: return "Trail"
        case .racing: return "Racing"
        case .endurance: return "Endurance"
        case .pleasure: return "Pleasure"
        case .other: return "Other"
        }
    }
}

/// Connection goals a horse owner can specify on a horse profile.
public enum LookingForCategory: String, Codable, Sendable, CaseIterable, Hashable {
    case ridingCompanion = "riding_companion"
    case trailBuddy = "trail_buddy"
    case breedingInquiry = "breeding_inquiry"
    case stablemate = "stablemate"
    case friendship = "friendship"

    public var displayName: String {
        switch self {
        case .ridingCompanion: return "Riding Companion"
        case .trailBuddy: return "Trail Buddy"
        case .breedingInquiry: return "Breeding Inquiry"
        case .stablemate: return "Stablemate"
        case .friendship: return "Friendship"
        }
    }
}

/// Coarse geographic location for a horse profile.
/// Coordinates are always rounded to 2 decimal places (~1.1 km precision) so exact stable locations are never exposed.
public struct HorseLocationDTO: Codable, Sendable, Equatable, Hashable {
    public let city: String
    public let coarseLatitude: Double
    public let coarseLongitude: Double

    public init(city: String, coarseLatitude: Double, coarseLongitude: Double) {
        self.city = city
        self.coarseLatitude = Self.coarsen(coarseLatitude)
        self.coarseLongitude = Self.coarsen(coarseLongitude)
    }

    /// Rounds a coordinate in degrees to 2 decimal places (~1.1 km resolution).
    public static func coarsen(_ coordinate: Double) -> Double {
        (coordinate * 100.0).rounded() / 100.0
    }

    /// Great-circle distance in kilometers using the Haversine formula.
    public func distanceKm(to other: HorseLocationDTO) -> Double {
        let earthRadiusKm = 6371.0
        let dLat = (other.coarseLatitude - coarseLatitude) * .pi / 180.0
        let dLon = (other.coarseLongitude - coarseLongitude) * .pi / 180.0
        let lat1 = coarseLatitude * .pi / 180.0
        let lat2 = other.coarseLatitude * .pi / 180.0

        let a = sin(dLat / 2) * sin(dLat / 2)
            + sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2)
        let c = 2 * atan2(sqrt(a), sqrt(max(0.0, 1.0 - a)))
        return ((earthRadiusKm * c) * 10.0).rounded() / 10.0
    }
}

/// Optional health and vaccination metadata for a horse profile.
public struct HorseHealthInfoDTO: Codable, Sendable, Equatable, Hashable {
    public let cogginsTestDate: Date?
    public let vaccinationsUpToDate: Bool?

    public init(cogginsTestDate: Date? = nil, vaccinationsUpToDate: Bool? = nil) {
        self.cogginsTestDate = cogginsTestDate
        self.vaccinationsUpToDate = vaccinationsUpToDate
    }
}

/// Photo metadata associated with a horse profile (2 to 6 photos required for discovery).
public struct HorsePhotoDTO: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let horseID: UUID
    public let url: String
    public let position: Int
    public let createdAt: Date

    public init(
        id: UUID,
        horseID: UUID,
        url: String,
        position: Int,
        createdAt: Date
    ) {
        self.id = id
        self.horseID = horseID
        self.url = url
        self.position = position
        self.createdAt = createdAt
    }
}

/// Complete horse profile representation returned by the API.
public struct HorseProfileDTO: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let ownerID: UUID
    public let name: String
    public let age: Int
    public let sex: HorseSex
    public let breed: String
    public let color: String
    public let heightHands: Double
    public let disciplines: [HorseDiscipline]
    public let temperamentTags: [String]
    public let bio: String
    public let location: HorseLocationDTO
    public let lookingFor: [LookingForCategory]
    public let healthInfo: HorseHealthInfoDTO?
    public let pedigree: String?
    public let photos: [HorsePhotoDTO]
    public let distanceKm: Double?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        ownerID: UUID,
        name: String,
        age: Int,
        sex: HorseSex,
        breed: String,
        color: String,
        heightHands: Double,
        disciplines: [HorseDiscipline],
        temperamentTags: [String],
        bio: String,
        location: HorseLocationDTO,
        lookingFor: [LookingForCategory],
        healthInfo: HorseHealthInfoDTO? = nil,
        pedigree: String? = nil,
        photos: [HorsePhotoDTO] = [],
        distanceKm: Double? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.ownerID = ownerID
        self.name = name
        self.age = age
        self.sex = sex
        self.breed = breed
        self.color = color
        self.heightHands = heightHands
        self.disciplines = disciplines
        self.temperamentTags = temperamentTags
        self.bio = bio
        self.location = location
        self.lookingFor = lookingFor
        self.healthInfo = healthInfo
        self.pedigree = pedigree
        self.photos = photos
        self.distanceKm = distanceKm
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Request payload for creating a new horse profile.
public struct CreateHorseProfileRequest: Codable, Sendable, Equatable {
    public let name: String
    public let age: Int
    public let sex: HorseSex
    public let breed: String
    public let color: String
    public let heightHands: Double
    public let disciplines: [HorseDiscipline]
    public let temperamentTags: [String]
    public let bio: String
    public let location: HorseLocationDTO
    public let lookingFor: [LookingForCategory]
    public let healthInfo: HorseHealthInfoDTO?
    public let pedigree: String?

    public init(
        name: String,
        age: Int,
        sex: HorseSex,
        breed: String,
        color: String,
        heightHands: Double,
        disciplines: [HorseDiscipline],
        temperamentTags: [String],
        bio: String,
        location: HorseLocationDTO,
        lookingFor: [LookingForCategory],
        healthInfo: HorseHealthInfoDTO? = nil,
        pedigree: String? = nil
    ) {
        self.name = name
        self.age = age
        self.sex = sex
        self.breed = breed
        self.color = color
        self.heightHands = heightHands
        self.disciplines = disciplines
        self.temperamentTags = temperamentTags
        self.bio = bio
        self.location = location
        self.lookingFor = lookingFor
        self.healthInfo = healthInfo
        self.pedigree = pedigree
    }
}

/// Request payload for updating an existing horse profile.
public struct UpdateHorseProfileRequest: Codable, Sendable, Equatable {
    public let name: String?
    public let age: Int?
    public let sex: HorseSex?
    public let breed: String?
    public let color: String?
    public let heightHands: Double?
    public let disciplines: [HorseDiscipline]?
    public let temperamentTags: [String]?
    public let bio: String?
    public let location: HorseLocationDTO?
    public let lookingFor: [LookingForCategory]?
    public let healthInfo: HorseHealthInfoDTO?
    public let pedigree: String?

    public init(
        name: String? = nil,
        age: Int? = nil,
        sex: HorseSex? = nil,
        breed: String? = nil,
        color: String? = nil,
        heightHands: Double? = nil,
        disciplines: [HorseDiscipline]? = nil,
        temperamentTags: [String]? = nil,
        bio: String? = nil,
        location: HorseLocationDTO? = nil,
        lookingFor: [LookingForCategory]? = nil,
        healthInfo: HorseHealthInfoDTO? = nil,
        pedigree: String? = nil
    ) {
        self.name = name
        self.age = age
        self.sex = sex
        self.breed = breed
        self.color = color
        self.heightHands = heightHands
        self.disciplines = disciplines
        self.temperamentTags = temperamentTags
        self.bio = bio
        self.location = location
        self.lookingFor = lookingFor
        self.healthInfo = healthInfo
        self.pedigree = pedigree
    }
}

/// Request payload for reordering photos on a horse profile.
public struct ReorderHorsePhotosRequest: Codable, Sendable, Equatable {
    public let photoIDs: [UUID]

    public init(photoIDs: [UUID]) {
        self.photoIDs = photoIDs
    }
}
