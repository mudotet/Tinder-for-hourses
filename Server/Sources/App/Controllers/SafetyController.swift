import Fluent
import Foundation
import SharedModels
import Vapor

public struct SafetyController: RouteCollection, Sendable {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let protected = routes.grouped(UserJWTAuthenticator())

        let blocks = protected.grouped("blocks")
        blocks.get(use: listBlocks)
        blocks.post(use: blockUser)
        blocks.delete(":blockedUserID", use: unblockUser)

        let reports = protected.grouped("reports")
        reports.post(use: createReport)
    }

    @Sendable
    public func listBlocks(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        let blocks = try await BlockModel.query(on: req.db)
            .filter(\.$blockerUser.$id == userID)
            .sort(\.$createdAt, .descending)
            .all()

        let dtos = try blocks.map { try $0.toDTO() }
        return try req.encodeJSON(dtos)
    }

    @Sendable
    public func blockUser(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        let input = try req.decodeJSON(BlockUserRequest.self)

        guard input.blockedUserID != userID else {
            throw AppError(.badRequest, code: .validationFailed, message: "You cannot block yourself.")
        }

        guard try await UserModel.find(input.blockedUserID, on: req.db) != nil else {
            throw AppError(.notFound, code: .notFound, message: "Target user not found.")
        }

        if let existing = try await BlockModel.query(on: req.db)
            .filter(\.$blockerUser.$id == userID)
            .filter(\.$blockedUser.$id == input.blockedUserID)
            .first()
        {
            return try req.encodeJSON(try existing.toDTO())
        }

        let block = BlockModel(
            blockerUserID: userID,
            blockedUserID: input.blockedUserID,
            reason: input.reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        try await block.save(on: req.db)
        return try req.encodeJSON(try block.toDTO(), status: .created)
    }

    @Sendable
    public func unblockUser(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        guard let blockedUserID = req.parameters.get("blockedUserID", as: UUID.self) else {
            throw AppError(.badRequest, code: .badRequest, message: "Invalid blockedUserID parameter.")
        }

        if let existing = try await BlockModel.query(on: req.db)
            .filter(\.$blockerUser.$id == userID)
            .filter(\.$blockedUser.$id == blockedUserID)
            .first()
        {
            try await existing.delete(on: req.db)
        }

        return try req.encodeJSON(StatusResponse(status: "ok", message: "User unblocked."))
    }

    @Sendable
    public func createReport(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        let input = try req.decodeJSON(CreateReportRequest.self)

        if let details = input.details, details.count > 1000 {
            throw AppError(
                .badRequest,
                code: .validationFailed,
                message: "Report details must be 1000 characters or fewer."
            )
        }

        let reportDTO: ReportDTO = try await req.db.transaction { tx in
            let report = ReportModel(
                reporterUserID: userID,
                targetType: input.targetType,
                targetID: input.targetID,
                reason: input.reason,
                details: input.details?.trimmingCharacters(in: .whitespacesAndNewlines),
                status: .pending
            )
            try await report.save(on: tx)
            let reportID = try report.requireID()

            let summary = "[\(input.targetType.rawValue.uppercased())] Reason: \(input.reason.rawValue) — \(input.details ?? "No additional details")"
            let queueItem = ModerationQueueModel(
                reportID: reportID,
                targetType: input.targetType,
                targetID: input.targetID,
                summary: String(summary.prefix(500)),
                status: .pending
            )
            try await queueItem.save(on: tx)

            return try report.toDTO()
        }

        return try req.encodeJSON(reportDTO, status: .created)
    }
}
