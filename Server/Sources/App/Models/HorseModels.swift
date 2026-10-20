import Fluent
import Foundation
import SharedModels
import Vapor

public final class HorseProfileModel: Model, @unchecked Sendable {
    public static let schema = "horse_profiles"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "owner_id")
    public var owner: UserModel

    @Field(key: "name")
    public var name: String

    @Field(key: "age")
    public var age: Int

    @Field(key: "sex")
    public var sex: String

    @Field(key: "breed")
    public var breed: String

    @Field(key: "color")
    public var color: String

    @Field(key: "height_hands")
    public var heightHands: Double

    @Field(key: "disciplines")
    public var disciplines: [String]

    @Field(key: "temperament_tags")
    public var temperamentTags: [String]

    @Field(key: "bio")
    public var bio: String

    @Field(key: "city")
    public var city: String

    @Field(key: "coarse_latitude")
    public var coarseLatitude: Double

    @Field(key: "coarse_longitude")
    public var coarseLongitude: Double

    @Field(key: "looking_for")
    public var lookingFor: [String]

    @OptionalField(key: "coggins_test_date")
    public var cogginsTestDate: Date?

    @OptionalField(key: "vaccinations_up_to_date")
    public var vaccinationsUpToDate: Bool?

    @OptionalField(key: "pedigree")
    public var pedigree: String?

    @Children(for: \.$horse)
    public var photos: [HorsePhotoModel]

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
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
        pedigree: String? = nil
    ) {
        self.id = id
        self.$owner.id = ownerID
        self.name = name
        self.age = age
        self.sex = sex.rawValue
        self.breed = breed
        self.color = color
        self.heightHands = heightHands
        self.disciplines = disciplines.map(\.rawValue)
        self.temperamentTags = temperamentTags
        self.bio = bio
        self.city = location.city
        self.coarseLatitude = HorseLocationDTO.coarsen(location.coarseLatitude)
        self.coarseLongitude = HorseLocationDTO.coarsen(location.coarseLongitude)
        self.lookingFor = lookingFor.map(\.rawValue)
        self.cogginsTestDate = healthInfo?.cogginsTestDate
        self.vaccinationsUpToDate = healthInfo?.vaccinationsUpToDate
        self.pedigree = pedigree
    }

    public func toDTO(
        photoDTOs: [HorsePhotoDTO]? = nil,
        distanceKm: Double? = nil
    ) throws -> HorseProfileDTO {
        let horseID = try requireID()
        let resolvedPhotos: [HorsePhotoDTO]
        if let photoDTOs {
            resolvedPhotos = photoDTOs.sorted { $0.position < $1.position }
        } else if let loaded = $photos.value {
            resolvedPhotos = try loaded.map { try $0.toDTO() }.sorted { $0.position < $1.position }
        } else {
            resolvedPhotos = []
        }

        let healthInfo: HorseHealthInfoDTO?
        if cogginsTestDate != nil || vaccinationsUpToDate != nil {
            healthInfo = HorseHealthInfoDTO(
                cogginsTestDate: cogginsTestDate,
                vaccinationsUpToDate: vaccinationsUpToDate
            )
        } else {
            healthInfo = nil
        }

        return HorseProfileDTO(
            id: horseID,
            ownerID: $owner.id,
            name: name,
            age: age,
            sex: HorseSex(rawValue: sex) ?? .mare,
            breed: breed,
            color: color,
            heightHands: heightHands,
            disciplines: disciplines.compactMap { HorseDiscipline(rawValue: $0) },
            temperamentTags: temperamentTags,
            bio: bio,
            location: HorseLocationDTO(
                city: city,
                coarseLatitude: coarseLatitude,
                coarseLongitude: coarseLongitude
            ),
            lookingFor: lookingFor.compactMap { LookingForCategory(rawValue: $0) },
            healthInfo: healthInfo,
            pedigree: pedigree,
            photos: resolvedPhotos,
            distanceKm: distanceKm,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? createdAt ?? Date()
        )
    }
}

public final class HorsePhotoModel: Model, @unchecked Sendable {
    public static let schema = "horse_photos"

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "horse_id")
    public var horse: HorseProfileModel

    @Field(key: "storage_key")
    public var storageKey: String

    @Field(key: "url")
    public var url: String

    @Field(key: "position")
    public var position: Int

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        horseID: UUID,
        storageKey: String,
        url: String,
        position: Int
    ) {
        self.id = id
        self.$horse.id = horseID
        self.storageKey = storageKey
        self.url = url
        self.position = position
    }

    public func toDTO() throws -> HorsePhotoDTO {
        let photoID = try requireID()
        return HorsePhotoDTO(
            id: photoID,
            horseID: $horse.id,
            url: url,
            position: position,
            createdAt: createdAt ?? Date()
        )
    }
}
