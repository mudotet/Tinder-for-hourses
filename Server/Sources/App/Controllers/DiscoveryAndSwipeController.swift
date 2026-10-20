import Fluent
import FluentSQL
import Foundation
import SharedModels
import Vapor

public struct DiscoveryAndSwipeController: RouteCollection, Sendable {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let protected = routes.grouped(UserJWTAuthenticator())

        protected.get("discovery", use: discoverHorses)
        protected.get("matches", use: listMatches)

        let swipeRateLimit = RateLimitMiddleware(scope: "swipes", maxRequests: 120, windowSeconds: 60)
        protected.grouped("swipes").grouped(swipeRateLimit).post(use: recordSwipe)
    }

    @Sendable
    public func discoverHorses(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        guard let activeHorseIDString = req.query[String.self, at: "activeHorseID"],
              let activeHorseID = UUID(uuidString: activeHorseIDString)
        else {
            throw AppError(
                .badRequest,
                code: .validationFailed,
                message: "Query parameter 'activeHorseID' (valid UUID) is required."
            )
        }

        guard
            let activeHorse = try await HorseProfileModel.query(on: req.db)
                .filter(\.$id == activeHorseID)
                .first()
        else {
            throw AppError(.notFound, code: .notFound, message: "Active horse profile not found.")
        }

        guard activeHorse.$owner.id == userID else {
            throw AppError(
                .forbidden,
                code: .forbidden,
                message: "Active horse does not belong to the authenticated user."
            )
        }

        let maxDistanceKm = req.query[Double.self, at: "maxDistanceKm"]
        let breedFilter = req.query[String.self, at: "breed"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sexFilter = req.query[String.self, at: "sex"].flatMap(HorseSex.init(rawValue:))
        let minAge = req.query[Int.self, at: "minAge"]
        let maxAge = req.query[Int.self, at: "maxAge"]
        let disciplineFilter = req.query[String.self, at: "discipline"].flatMap(HorseDiscipline.init(rawValue:))
        let lookingForFilter = req.query[String.self, at: "lookingFor"].flatMap(LookingForCategory.init(rawValue:))
        let cursorString = req.query[String.self, at: "cursor"]
        let requestedLimit = req.query[Int.self, at: "limit"] ?? 20
        let limit = min(max(requestedLimit, 1), 50)

        // 1. Collect blocked user IDs in both directions
        let blocks = try await BlockModel.query(on: req.db)
            .group(.or) { group in
                group.filter(\.$blockerUser.$id == userID)
                group.filter(\.$blockedUser.$id == userID)
            }
            .all()

        var excludedUserIDs: Set<UUID> = [userID]
        for block in blocks {
            excludedUserIDs.insert(block.$blockerUser.id)
            excludedUserIDs.insert(block.$blockedUser.id)
        }

        // 2. Collect target horse IDs already swiped by activeHorseID
        let existingSwipes = try await SwipeModel.query(on: req.db)
            .filter(\.$swiperHorse.$id == activeHorseID)
            .all()
        let swipedHorseIDs = Set(existingSwipes.map { $0.$targetHorse.id })

        // 3. Query candidate horses
        var query = HorseProfileModel.query(on: req.db)
            .filter(\.$owner.$id !~ Array(excludedUserIDs))
            .with(\.$photos)
            .sort(\.$id, .ascending)

        if !swipedHorseIDs.isEmpty {
            query = query.filter(\.$id !~ Array(swipedHorseIDs))
        }
        if let breedFilter, !breedFilter.isEmpty {
            query = query.filter(\.$breed =~ breedFilter)
        }
        if let sexFilter {
            query = query.filter(\.$sex == sexFilter.rawValue)
        }
        if let minAge {
            query = query.filter(\.$age >= minAge)
        }
        if let maxAge {
            query = query.filter(\.$age <= maxAge)
        }

        let candidates = try await query.all()
        let originLocation = HorseLocationDTO(
            city: activeHorse.city,
            coarseLatitude: activeHorse.coarseLatitude,
            coarseLongitude: activeHorse.coarseLongitude
        )

        // Apply array & distance filters and deterministic cursor pagination
        var filteredDTOs: [HorseProfileDTO] = []
        var passedCursor = (cursorString == nil || cursorString?.isEmpty == true)

        for candidate in candidates {
            let candidateID = try candidate.requireID()
            if !passedCursor {
                if candidateID.uuidString.lowercased() == cursorString?.lowercased() {
                    passedCursor = true
                }
                continue
            }

            if let disciplineFilter, !candidate.disciplines.contains(disciplineFilter.rawValue) {
                continue
            }
            if let lookingForFilter, !candidate.lookingFor.contains(lookingForFilter.rawValue) {
                continue
            }

            let candidateLoc = HorseLocationDTO(
                city: candidate.city,
                coarseLatitude: candidate.coarseLatitude,
                coarseLongitude: candidate.coarseLongitude
            )
            let distance = originLocation.distanceKm(to: candidateLoc)
            if let maxDistanceKm, distance > maxDistanceKm {
                continue
            }

            let dto = try candidate.toDTO(distanceKm: distance)
            filteredDTOs.append(dto)
        }

        let pageItems = Array(filteredDTOs.prefix(limit))
        let hasMore = filteredDTOs.count > limit
        let nextCursor = hasMore ? pageItems.last?.id.uuidString : nil

        let page = CursorPage(items: pageItems, nextCursor: nextCursor)
        return try req.encodeJSON(page)
    }

    @Sendable
    public func recordSwipe(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        let input = try req.decodeJSON(SwipeRequest.self)

        guard input.swiperHorseID != input.targetHorseID else {
            throw AppError(.badRequest, code: .validationFailed, message: "A horse cannot swipe on itself.")
        }

        guard
            let swiperHorse = try await HorseProfileModel.query(on: req.db)
                .filter(\.$id == input.swiperHorseID)
                .with(\.$photos)
                .first()
        else {
            throw AppError(.notFound, code: .notFound, message: "Swiper horse profile not found.")
        }

        guard swiperHorse.$owner.id == userID else {
            throw AppError(
                .forbidden,
                code: .forbidden,
                message: "Swiper horse does not belong to the authenticated user."
            )
        }

        guard
            let targetHorse = try await HorseProfileModel.query(on: req.db)
                .filter(\.$id == input.targetHorseID)
                .with(\.$photos)
                .first()
        else {
            throw AppError(.notFound, code: .notFound, message: "Target horse profile not found.")
        }

        guard targetHorse.$owner.id != userID else {
            throw AppError(
                .badRequest,
                code: .validationFailed,
                message: "You cannot swipe on your own horse profile."
            )
        }

        // Verify neither user has blocked the other
        let isBlocked = try await BlockModel.query(on: req.db)
            .group(.or) { group in
                group.group(.and) { g in
                    g.filter(\.$blockerUser.$id == userID)
                    g.filter(\.$blockedUser.$id == targetHorse.$owner.id)
                }
                group.group(.and) { g in
                    g.filter(\.$blockerUser.$id == targetHorse.$owner.id)
                    g.filter(\.$blockedUser.$id == userID)
                }
            }
            .count() > 0

        if isBlocked {
            throw AppError(.forbidden, code: .forbidden, message: "Cannot swipe on a blocked user's horse.")
        }

        // Atomic, idempotent swipe + match + conversation creation inside a transaction
        struct AtomicSwipeOutcome: Sendable {
            let swipeID: UUID
            let matchDTO: MatchDTO?
            let wasNewlyMatched: Bool
        }

        let outcome: AtomicSwipeOutcome = try await req.db.transaction { tx in
            guard let sql = tx as? SQLDatabase else {
                throw AppError(.internalServerError, code: .internalError, message: "SQL database unavailable.")
            }

            let proposedSwipeID = UUID()
            struct IDRow: Decodable {
                let id: UUID
            }

            let swipeRows = try await sql.raw("""
                INSERT INTO swipes (id, swiper_horse_id, target_horse_id, direction, created_at)
                VALUES (\(bind: proposedSwipeID), \(bind: input.swiperHorseID), \(bind: input.targetHorseID), \(bind: input.direction.rawValue), NOW())
                ON CONFLICT (swiper_horse_id, target_horse_id)
                DO UPDATE SET direction = EXCLUDED.direction
                RETURNING id;
                """).all(decoding: IDRow.self)

            let swipeID = swipeRows.first?.id ?? proposedSwipeID

            guard input.direction == .like else {
                return AtomicSwipeOutcome(swipeID: swipeID, matchDTO: nil, wasNewlyMatched: false)
            }

            // Check if targetHorse has also liked swiperHorse
            let reciprocalLike = try await SwipeModel.query(on: tx)
                .filter(\.$swiperHorse.$id == input.targetHorseID)
                .filter(\.$targetHorse.$id == input.swiperHorseID)
                .filter(\.$direction == SwipeDirection.like.rawValue)
                .first()

            guard reciprocalLike != nil else {
                return AtomicSwipeOutcome(swipeID: swipeID, matchDTO: nil, wasNewlyMatched: false)
            }

            let (canonicalA, canonicalB) = MatchModel.canonicalPair(input.swiperHorseID, input.targetHorseID)
            let proposedMatchID = UUID()

            let insertedMatchRows = try await sql.raw("""
                INSERT INTO matches (id, horse_a_id, horse_b_id, created_at)
                VALUES (\(bind: proposedMatchID), \(bind: canonicalA), \(bind: canonicalB), NOW())
                ON CONFLICT (horse_a_id, horse_b_id) DO NOTHING
                RETURNING id;
                """).all(decoding: IDRow.self)

            let wasNewlyInserted = !insertedMatchRows.isEmpty

            guard
                let matchModel = try await MatchModel.query(on: tx)
                    .filter(\.$horseA.$id == canonicalA)
                    .filter(\.$horseB.$id == canonicalB)
                    .first()
            else {
                throw AppError(.internalServerError, code: .internalError, message: "Failed to load match record.")
            }

            let matchID = try matchModel.requireID()
            let proposedConversationID = UUID()

            _ = try await sql.raw("""
                INSERT INTO conversations (id, match_id, created_at, updated_at)
                VALUES (\(bind: proposedConversationID), \(bind: matchID), NOW(), NOW())
                ON CONFLICT (match_id) DO NOTHING;
                """).run()

            guard
                let conversation = try await ConversationModel.query(on: tx)
                    .filter(\.$match.$id == matchID)
                    .first()
            else {
                throw AppError(.internalServerError, code: .internalError, message: "Failed to load conversation record.")
            }

            let horseADTO = (canonicalA == input.swiperHorseID)
                ? try swiperHorse.toDTO()
                : try targetHorse.toDTO()
            let horseBDTO = (canonicalB == input.swiperHorseID)
                ? try swiperHorse.toDTO()
                : try targetHorse.toDTO()

            let matchDTO = MatchDTO(
                id: matchID,
                horseA: horseADTO,
                horseB: horseBDTO,
                conversationID: try conversation.requireID(),
                createdAt: matchModel.createdAt ?? Date()
            )
            return AtomicSwipeOutcome(
                swipeID: swipeID,
                matchDTO: matchDTO,
                wasNewlyMatched: wasNewlyInserted
            )
        }

        if let matchDTO = outcome.matchDTO, outcome.wasNewlyMatched {
            let ownerA = matchDTO.horseA.ownerID
            let ownerB = matchDTO.horseB.ownerID
            await req.application.pushNotificationService.sendNewMatchNotification(
                to: ownerA,
                match: matchDTO,
                on: req.db
            )
            await req.application.pushNotificationService.sendNewMatchNotification(
                to: ownerB,
                match: matchDTO,
                on: req.db
            )
            await req.application.webSocketHub.send(.matchCreated(matchDTO), to: [ownerA, ownerB])
        }

        let response = SwipeResponse(
            swipeID: outcome.swipeID,
            direction: input.direction,
            isMatch: outcome.matchDTO != nil,
            match: outcome.matchDTO
        )
        return try req.encodeJSON(response)
    }

    @Sendable
    public func listMatches(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        let myHorses = try await HorseProfileModel.query(on: req.db)
            .filter(\.$owner.$id == userID)
            .all()
        let myHorseIDs = try myHorses.map { try $0.requireID() }
        guard !myHorseIDs.isEmpty else {
            return try req.encodeJSON([MatchDTO]())
        }

        let blocks = try await BlockModel.query(on: req.db)
            .group(.or) { group in
                group.filter(\.$blockerUser.$id == userID)
                group.filter(\.$blockedUser.$id == userID)
            }
            .all()
        var blockedUserIDs = Set<UUID>()
        for block in blocks {
            if block.$blockerUser.id != userID { blockedUserIDs.insert(block.$blockerUser.id) }
            if block.$blockedUser.id != userID { blockedUserIDs.insert(block.$blockedUser.id) }
        }

        let matches = try await MatchModel.query(on: req.db)
            .group(.or) { group in
                group.filter(\.$horseA.$id ~~ myHorseIDs)
                group.filter(\.$horseB.$id ~~ myHorseIDs)
            }
            .with(\.$horseA) { $0.with(\.$photos) }
            .with(\.$horseB) { $0.with(\.$photos) }
            .sort(\.$createdAt, .descending)
            .all()

        var matchDTOs: [MatchDTO] = []
        for match in matches {
            if blockedUserIDs.contains(match.horseA.$owner.id) || blockedUserIDs.contains(match.horseB.$owner.id) {
                continue
            }
            let matchID = try match.requireID()
            guard
                let conversation = try await ConversationModel.query(on: req.db)
                    .filter(\.$match.$id == matchID)
                    .first()
            else {
                continue
            }
            let dto = MatchDTO(
                id: matchID,
                horseA: try match.horseA.toDTO(),
                horseB: try match.horseB.toDTO(),
                conversationID: try conversation.requireID(),
                createdAt: match.createdAt ?? Date()
            )
            matchDTOs.append(dto)
        }

        return try req.encodeJSON(matchDTOs)
    }
}
