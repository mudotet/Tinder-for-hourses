import Fluent
import Foundation
import SharedModels
import Vapor

public struct MultipartPhotoUpload: Content {
    public var file: File
}

public struct HorseController: RouteCollection, Sendable {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let protected = routes.grouped(UserJWTAuthenticator()).grouped("horses")

        protected.get("mine", use: listMyHorses)
        protected.post(use: createHorse)
        protected.get(":horseID", use: getHorse)
        protected.patch(":horseID", use: updateHorse)
        protected.delete(":horseID", use: deleteHorse)

        protected.on(.POST, ":horseID", "photos", body: .collect(maxSize: "6mb"), use: uploadPhoto)
        protected.put(":horseID", "photos", "reorder", use: reorderPhotos)
        protected.delete(":horseID", "photos", ":photoID", use: deletePhoto)
    }

    @Sendable
    public func listMyHorses(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        let horses = try await HorseProfileModel.query(on: req.db)
            .filter(\.$owner.$id == userID)
            .with(\.$photos)
            .sort(\.$createdAt, .ascending)
            .all()

        let dtos = try horses.map { try $0.toDTO() }
        return try req.encodeJSON(dtos)
    }

    @Sendable
    public func createHorse(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        try req.validateJSON { validations in
            validations.add("name", as: String.self, is: .count(1...80))
            validations.add("age", as: Int.self, is: .range(0...50))
            validations.add("breed", as: String.self, is: .count(1...80))
            validations.add("color", as: String.self, is: .count(1...60))
            validations.add("heightHands", as: Double.self, is: .range(4.0...22.0))
            validations.add("bio", as: String.self, is: .count(1...SafetyConstants.maxBioLength))
        }

        let input = try req.decodeJSON(CreateHorseProfileRequest.self)
        try validateHorseInput(
            name: input.name,
            age: input.age,
            heightHands: input.heightHands,
            disciplines: input.disciplines,
            lookingFor: input.lookingFor,
            bio: input.bio,
            location: input.location
        )

        let horse = HorseProfileModel(
            ownerID: userID,
            name: input.name.trimmingCharacters(in: .whitespacesAndNewlines),
            age: input.age,
            sex: input.sex,
            breed: input.breed.trimmingCharacters(in: .whitespacesAndNewlines),
            color: input.color.trimmingCharacters(in: .whitespacesAndNewlines),
            heightHands: input.heightHands,
            disciplines: input.disciplines,
            temperamentTags: input.temperamentTags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            bio: input.bio.trimmingCharacters(in: .whitespacesAndNewlines),
            location: input.location,
            lookingFor: input.lookingFor,
            healthInfo: input.healthInfo,
            pedigree: input.pedigree?.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        try await horse.save(on: req.db)
        try await horse.$photos.load(on: req.db)
        return try req.encodeJSON(try horse.toDTO(), status: .created)
    }

    @Sendable
    public func getHorse(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        guard let horseID = req.parameters.get("horseID", as: UUID.self) else {
            throw AppError(.badRequest, code: .badRequest, message: "Invalid horse ID.")
        }

        guard
            let horse = try await HorseProfileModel.query(on: req.db)
                .filter(\.$id == horseID)
                .with(\.$photos)
                .first()
        else {
            throw AppError(.notFound, code: .notFound, message: "Horse profile not found.")
        }

        // Prevent blocked users from viewing each other's horses
        if horse.$owner.id != userID {
            let isBlocked = try await BlockModel.query(on: req.db)
                .group(.or) { group in
                    group.group(.and) { g in
                        g.filter(\.$blockerUser.$id == userID)
                        g.filter(\.$blockedUser.$id == horse.$owner.id)
                    }
                    group.group(.and) { g in
                        g.filter(\.$blockerUser.$id == horse.$owner.id)
                        g.filter(\.$blockedUser.$id == userID)
                    }
                }
                .count() > 0

            if isBlocked {
                throw AppError(.notFound, code: .notFound, message: "Horse profile not found.")
            }
        }

        return try req.encodeJSON(try horse.toDTO())
    }

    @Sendable
    public func updateHorse(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        let horse = try await requireOwnedHorse(on: req, ownerID: userID)
        let input = try req.decodeJSON(UpdateHorseProfileRequest.self)

        if let name = input.name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (1...80).contains(trimmed.count) else {
                throw AppError(.badRequest, code: .validationFailed, message: "Name must be 1 to 80 characters.")
            }
            horse.name = trimmed
        }
        if let age = input.age {
            guard (0...50).contains(age) else {
                throw AppError(.badRequest, code: .validationFailed, message: "Age must be between 0 and 50.")
            }
            horse.age = age
        }
        if let sex = input.sex {
            horse.sex = sex.rawValue
        }
        if let breed = input.breed {
            let trimmed = breed.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (1...80).contains(trimmed.count) else {
                throw AppError(.badRequest, code: .validationFailed, message: "Breed must be 1 to 80 characters.")
            }
            horse.breed = trimmed
        }
        if let color = input.color {
            let trimmed = color.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (1...60).contains(trimmed.count) else {
                throw AppError(.badRequest, code: .validationFailed, message: "Color must be 1 to 60 characters.")
            }
            horse.color = trimmed
        }
        if let heightHands = input.heightHands {
            guard (4.0...22.0).contains(heightHands) else {
                throw AppError(.badRequest, code: .validationFailed, message: "Height must be between 4.0 and 22.0 hands.")
            }
            horse.heightHands = heightHands
        }
        if let disciplines = input.disciplines {
            guard !disciplines.isEmpty else {
                throw AppError(.badRequest, code: .validationFailed, message: "At least one discipline is required.")
            }
            horse.disciplines = disciplines.map(\.rawValue)
        }
        if let temperamentTags = input.temperamentTags {
            horse.temperamentTags = temperamentTags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        if let bio = input.bio {
            try validateBioContent(bio)
            horse.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let location = input.location {
            let city = location.city.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !city.isEmpty else {
                throw AppError(.badRequest, code: .validationFailed, message: "City is required.")
            }
            guard (-90.0...90.0).contains(location.coarseLatitude),
                  (-180.0...180.0).contains(location.coarseLongitude)
            else {
                throw AppError(.badRequest, code: .validationFailed, message: "Invalid geographic coordinates.")
            }
            horse.city = city
            horse.coarseLatitude = HorseLocationDTO.coarsen(location.coarseLatitude)
            horse.coarseLongitude = HorseLocationDTO.coarsen(location.coarseLongitude)
        }
        if let lookingFor = input.lookingFor {
            guard !lookingFor.isEmpty else {
                throw AppError(.badRequest, code: .validationFailed, message: "At least one looking-for category is required.")
            }
            horse.lookingFor = lookingFor.map(\.rawValue)
        }
        if let healthInfo = input.healthInfo {
            horse.cogginsTestDate = healthInfo.cogginsTestDate
            horse.vaccinationsUpToDate = healthInfo.vaccinationsUpToDate
        }
        if let pedigree = input.pedigree {
            let trimmed = pedigree.trimmingCharacters(in: .whitespacesAndNewlines)
            horse.pedigree = trimmed.isEmpty ? nil : trimmed
        }

        try await horse.save(on: req.db)
        try await horse.$photos.load(on: req.db)
        return try req.encodeJSON(try horse.toDTO())
    }

    @Sendable
    public func deleteHorse(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        let horse = try await requireOwnedHorse(on: req, ownerID: userID)
        try await horse.$photos.load(on: req.db)

        for photo in horse.photos {
            try? await req.application.storageService.deleteFile(key: photo.storageKey)
        }

        try await horse.delete(on: req.db)
        return try req.encodeJSON(StatusResponse(status: "ok", message: "Horse profile deleted."))
    }

    @Sendable
    public func uploadPhoto(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        let horse = try await requireOwnedHorse(on: req, ownerID: userID)
        let horseID = try horse.requireID()

        let existingPhotos = try await HorsePhotoModel.query(on: req.db)
            .filter(\.$horse.$id == horseID)
            .sort(\.$position, .ascending)
            .all()

        guard existingPhotos.count < SafetyConstants.maxHorsePhotos else {
            throw AppError(
                .badRequest,
                code: .validationFailed,
                message: "A horse profile can have at most \(SafetyConstants.maxHorsePhotos) photos."
            )
        }

        let (fileData, contentType, fileExtension) = try extractUploadedImage(from: req)
        let maxBytes = 5 * 1024 * 1024
        guard !fileData.isEmpty else {
            throw AppError(.badRequest, code: .validationFailed, message: "Uploaded photo data is empty.")
        }
        guard fileData.count <= maxBytes else {
            throw AppError(.payloadTooLarge, code: .payloadTooLarge, message: "Photo exceeds 5 MB limit.")
        }

        let photoUUID = UUID()
        let storageKey = "horses/\(horseID.uuidString.lowercased())/\(photoUUID.uuidString.lowercased()).\(fileExtension)"
        let stored = try await req.application.storageService.uploadFile(
            key: storageKey,
            data: fileData,
            contentType: contentType
        )

        let nextPosition = existingPhotos.count
        let photoModel = HorsePhotoModel(
            id: photoUUID,
            horseID: horseID,
            storageKey: stored.key,
            url: stored.publicURL,
            position: nextPosition
        )
        try await photoModel.save(on: req.db)

        return try req.encodeJSON(try photoModel.toDTO(), status: .created)
    }

    @Sendable
    public func reorderPhotos(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        let horse = try await requireOwnedHorse(on: req, ownerID: userID)
        let horseID = try horse.requireID()
        let input = try req.decodeJSON(ReorderHorsePhotosRequest.self)

        let photos = try await HorsePhotoModel.query(on: req.db)
            .filter(\.$horse.$id == horseID)
            .all()

        let existingIDs = Set(photos.compactMap(\.id))
        guard existingIDs == Set(input.photoIDs), photos.count == input.photoIDs.count else {
            throw AppError(
                .badRequest,
                code: .validationFailed,
                message: "Provided photoIDs must match the horse's existing photos."
            )
        }

        let photosByID = Dictionary(uniqueKeysWithValues: photos.compactMap { photo -> (UUID, HorsePhotoModel)? in
            guard let id = photo.id else { return nil }
            return (id, photo)
        })

        try await req.db.transaction { tx in
            for (index, photoID) in input.photoIDs.enumerated() {
                if let photo = photosByID[photoID] {
                    photo.position = index
                    try await photo.save(on: tx)
                }
            }
        }

        let updatedPhotos = try await HorsePhotoModel.query(on: req.db)
            .filter(\.$horse.$id == horseID)
            .sort(\.$position, .ascending)
            .all()
        let dtos = try updatedPhotos.map { try $0.toDTO() }
        return try req.encodeJSON(dtos)
    }

    @Sendable
    public func deletePhoto(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        let horse = try await requireOwnedHorse(on: req, ownerID: userID)
        let horseID = try horse.requireID()

        guard let photoID = req.parameters.get("photoID", as: UUID.self) else {
            throw AppError(.badRequest, code: .badRequest, message: "Invalid photo ID.")
        }

        guard
            let photo = try await HorsePhotoModel.query(on: req.db)
                .filter(\.$id == photoID)
                .filter(\.$horse.$id == horseID)
                .first()
        else {
            throw AppError(.notFound, code: .notFound, message: "Photo not found on this horse profile.")
        }

        let storageKey = photo.storageKey
        try await photo.delete(on: req.db)
        try? await req.application.storageService.deleteFile(key: storageKey)

        // Normalize remaining photo positions
        let remaining = try await HorsePhotoModel.query(on: req.db)
            .filter(\.$horse.$id == horseID)
            .sort(\.$position, .ascending)
            .all()
        for (idx, item) in remaining.enumerated() where item.position != idx {
            item.position = idx
            try await item.save(on: req.db)
        }

        return try req.encodeJSON(StatusResponse(status: "ok", message: "Photo deleted."))
    }

    // MARK: - Helpers

    private func requireOwnedHorse(on req: Request, ownerID: UUID) async throws -> HorseProfileModel {
        guard let horseID = req.parameters.get("horseID", as: UUID.self) else {
            throw AppError(.badRequest, code: .badRequest, message: "Invalid horse ID.")
        }
        guard let horse = try await HorseProfileModel.find(horseID, on: req.db) else {
            throw AppError(.notFound, code: .notFound, message: "Horse profile not found.")
        }
        guard horse.$owner.id == ownerID else {
            throw AppError(
                .forbidden,
                code: .forbidden,
                message: "You do not have permission to modify this horse profile."
            )
        }
        return horse
    }

    private func validateHorseInput(
        name: String,
        age: Int,
        heightHands: Double,
        disciplines: [HorseDiscipline],
        lookingFor: [LookingForCategory],
        bio: String,
        location: HorseLocationDTO
    ) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError(.badRequest, code: .validationFailed, message: "Horse name cannot be empty.")
        }
        guard (0...50).contains(age) else {
            throw AppError(.badRequest, code: .validationFailed, message: "Age must be between 0 and 50.")
        }
        guard (4.0...22.0).contains(heightHands) else {
            throw AppError(.badRequest, code: .validationFailed, message: "Height must be between 4.0 and 22.0 hands.")
        }
        guard !disciplines.isEmpty else {
            throw AppError(.badRequest, code: .validationFailed, message: "Select at least one discipline.")
        }
        guard !lookingFor.isEmpty else {
            throw AppError(.badRequest, code: .validationFailed, message: "Select at least one looking-for goal.")
        }
        guard !location.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError(.badRequest, code: .validationFailed, message: "Location city is required.")
        }
        guard (-90.0...90.0).contains(location.coarseLatitude),
              (-180.0...180.0).contains(location.coarseLongitude)
        else {
            throw AppError(.badRequest, code: .validationFailed, message: "Invalid latitude or longitude.")
        }
        try validateBioContent(bio)
    }

    private func validateBioContent(_ bio: String) throws {
        switch ObjectionableContentFilter.validateBio(bio) {
        case .valid:
            return
        case .empty:
            throw AppError(.badRequest, code: .validationFailed, message: "Bio cannot be empty.")
        case .tooLong(let maxLength):
            throw AppError(
                .badRequest,
                code: .validationFailed,
                message: "Bio must be \(maxLength) characters or fewer."
            )
        case .objectionableContent:
            throw AppError(
                .badRequest,
                code: .contentRejected,
                message: "Bio contains prohibited or unsafe language."
            )
        }
    }

    private func extractUploadedImage(from req: Request) throws -> (Data, String, String) {
        if let multipart = try? req.content.decode(MultipartPhotoUpload.self) {
            let data = Data(buffer: multipart.file.data)
            let ext = (multipart.file.extension ?? "jpg").lowercased()
            let cleanExt = ["jpg", "jpeg", "png", "webp", "heic"].contains(ext) ? ext : "jpg"
            let contentType = cleanExt == "png" ? "image/png" : "image/jpeg"
            return (data, contentType, cleanExt)
        }

        guard let bodyBuffer = req.body.data else {
            throw AppError(.badRequest, code: .validationFailed, message: "Missing photo upload payload.")
        }
        let data = Data(buffer: bodyBuffer)
        let headerType = req.headers.contentType?.serialize() ?? "image/jpeg"
        let ext = headerType.contains("png") ? "png" : "jpg"
        let contentType = ext == "png" ? "image/png" : "image/jpeg"
        return (data, contentType, ext)
    }
}
