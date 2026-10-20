import Fluent
import Foundation
import SharedModels
import Vapor

public struct ChatController: RouteCollection, Sendable {
    public init() {}

    public func boot(routes: RoutesBuilder) throws {
        let protected = routes.grouped(UserJWTAuthenticator())

        let conversations = protected.grouped("conversations")
        conversations.get(use: listConversations)
        conversations.get(":conversationID", "messages", use: listMessages)
        conversations.post(":conversationID", "messages", use: sendMessageREST)
        conversations.post(":conversationID", "read", use: markReadREST)

        protected.webSocket("ws", onUpgrade: handleWebSocketUpgrade)
    }

    @Sendable
    public func listConversations(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        let summaries = try await fetchConversationSummaries(for: userID, on: req.db)
        return try req.encodeJSON(summaries)
    }

    @Sendable
    public func listMessages(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        guard let conversationID = req.parameters.get("conversationID", as: UUID.self) else {
            throw AppError(.badRequest, code: .badRequest, message: "Invalid conversation ID.")
        }

        _ = try await verifyConversationParticipant(
            conversationID: conversationID,
            userID: userID,
            on: req.db
        )

        let cursorString = req.query[String.self, at: "cursor"]
        let requestedLimit = req.query[Int.self, at: "limit"] ?? 30
        let limit = min(max(requestedLimit, 1), 100)

        let allMessages = try await MessageModel.query(on: req.db)
            .filter(\.$conversation.$id == conversationID)
            .sort(\.$createdAt, .descending)
            .all()

        var passedCursor = (cursorString == nil || cursorString?.isEmpty == true)
        var filtered: [MessageDTO] = []

        for message in allMessages {
            let messageID = try message.requireID()
            if !passedCursor {
                if messageID.uuidString.lowercased() == cursorString?.lowercased() {
                    passedCursor = true
                }
                continue
            }
            filtered.append(try message.toDTO())
        }

        let pageItems = Array(filtered.prefix(limit))
        let hasMore = filtered.count > limit
        let nextCursor = hasMore ? pageItems.last?.id.uuidString : nil

        return try req.encodeJSON(CursorPage(items: pageItems, nextCursor: nextCursor))
    }

    @Sendable
    public func sendMessageREST(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        guard let conversationID = req.parameters.get("conversationID", as: UUID.self) else {
            throw AppError(.badRequest, code: .badRequest, message: "Invalid conversation ID.")
        }

        let input = try req.decodeJSON(SendMessageRequest.self)
        let messageDTO = try await createAndBroadcastMessage(
            conversationID: conversationID,
            senderUserID: userID,
            senderHorseID: input.senderHorseID,
            body: input.body,
            app: req.application,
            db: req.db
        )
        return try req.encodeJSON(messageDTO, status: .created)
    }

    @Sendable
    public func markReadREST(req: Request) async throws -> Response {
        let userID = try req.requireAuthenticatedUserID()
        guard let conversationID = req.parameters.get("conversationID", as: UUID.self) else {
            throw AppError(.badRequest, code: .badRequest, message: "Invalid conversation ID.")
        }

        let input = try? req.decodeJSON(MarkMessagesReadRequest.self)
        let result = try await markConversationMessagesRead(
            conversationID: conversationID,
            readerUserID: userID,
            upToMessageID: input?.upToMessageID,
            app: req.application,
            db: req.db
        )
        return try req.encodeJSON(result)
    }

    // MARK: - WebSocket Handler

    @Sendable
    public func handleWebSocketUpgrade(req: Request, ws: WebSocket) async {
        guard let userID = try? req.requireAuthenticatedUserID() else {
            try? await ws.close(code: .policyViolation)
            return
        }

        let app = req.application
        let connectionID = await app.webSocketHub.register(userID: userID, socket: ws)

        ws.onText { socket, text in
            await Self.processWebSocketText(
                text: text,
                socket: socket,
                userID: userID,
                app: app
            )
        }

        ws.onClose.whenComplete { _ in
            Task {
                await app.webSocketHub.unregister(userID: userID, connectionID: connectionID)
            }
        }
    }

    private static func processWebSocketText(
        text: String,
        socket: WebSocket,
        userID: UUID,
        app: Application
    ) async {
        let controller = ChatController()
        do {
            let incoming = try WebSocketHub.decodeMessage(text)
            switch incoming {
            case .ping:
                if let pongJSON = WebSocketHub.encodeMessage(.pong) {
                    try? await socket.send(pongJSON)
                }

            case .sendMessage(let payload):
                _ = try await controller.createAndBroadcastMessage(
                    conversationID: payload.conversationID,
                    senderUserID: userID,
                    senderHorseID: payload.senderHorseID,
                    body: payload.body,
                    app: app,
                    db: app.db
                )

            case .typing(let payload):
                let context = try await controller.verifyConversationParticipant(
                    conversationID: payload.conversationID,
                    userID: userID,
                    on: app.db
                )
                guard try context.myHorse.requireID() == payload.horseID else {
                    throw AppError(.forbidden, code: .forbidden, message: "Horse does not belong to sender.")
                }
                await app.webSocketHub.send(.typing(payload), to: context.otherUserID)

            case .markRead(let payload):
                _ = try await controller.markConversationMessagesRead(
                    conversationID: payload.conversationID,
                    readerUserID: userID,
                    upToMessageID: payload.upToMessageID,
                    app: app,
                    db: app.db
                )

            default:
                break
            }
        } catch let appError as AppError {
            let errFrame = WebSocketMessage.error(
                APIErrorResponse(code: appError.code, message: appError.message)
            )
            if let encoded = WebSocketHub.encodeMessage(errFrame) {
                try? await socket.send(encoded)
            }
        } catch {
            let errFrame = WebSocketMessage.error(
                APIErrorResponse(code: .badRequest, message: "Invalid WebSocket message format.")
            )
            if let encoded = WebSocketHub.encodeMessage(errFrame) {
                try? await socket.send(encoded)
            }
        }
    }

    // MARK: - Core Chat Logic

    private struct ParticipantContext: Sendable {
        let conversation: ConversationModel
        let myHorse: HorseProfileModel
        let otherHorse: HorseProfileModel
        let otherUserID: UUID
    }

    private func verifyConversationParticipant(
        conversationID: UUID,
        userID: UUID,
        on db: Database
    ) async throws -> ParticipantContext {
        let loadedConversation = try await ConversationModel.query(on: db)
            .filter(\.$id == conversationID)
            .with(\.$match) { match in
                match.with(\.$horseA) { $0.with(\.$photos) }
                match.with(\.$horseB) { $0.with(\.$photos) }
            }
            .first()
        guard let conversation = loadedConversation else {
            throw AppError(.notFound, code: .notFound, message: "Conversation not found.")
        }

        let horseA = conversation.match.horseA
        let horseB = conversation.match.horseB
        let myHorse: HorseProfileModel
        let otherHorse: HorseProfileModel

        if horseA.$owner.id == userID {
            myHorse = horseA
            otherHorse = horseB
        } else if horseB.$owner.id == userID {
            myHorse = horseB
            otherHorse = horseA
        } else {
            throw AppError(
                .forbidden,
                code: .forbidden,
                message: "You are not a participant in this conversation."
            )
        }

        let otherUserID = otherHorse.$owner.id
        let isBlocked = try await BlockModel.query(on: db)
            .group(.or) { group in
                group.group(.and) { g in
                    g.filter(\.$blockerUser.$id == userID)
                    g.filter(\.$blockedUser.$id == otherUserID)
                }
                group.group(.and) { g in
                    g.filter(\.$blockerUser.$id == otherUserID)
                    g.filter(\.$blockedUser.$id == userID)
                }
            }
            .count() > 0

        if isBlocked {
            throw AppError(
                .forbidden,
                code: .forbidden,
                message: "Cannot access conversation with a blocked user."
            )
        }

        return ParticipantContext(
            conversation: conversation,
            myHorse: myHorse,
            otherHorse: otherHorse,
            otherUserID: otherUserID
        )
    }

    private func createAndBroadcastMessage(
        conversationID: UUID,
        senderUserID: UUID,
        senderHorseID: UUID,
        body: String,
        app: Application,
        db: Database
    ) async throws -> MessageDTO {
        switch ObjectionableContentFilter.validateMessage(body) {
        case .valid:
            break
        case .empty:
            throw AppError(.badRequest, code: .validationFailed, message: "Message body cannot be empty.")
        case .tooLong(let maxLen):
            throw AppError(
                .badRequest,
                code: .validationFailed,
                message: "Message body exceeds maximum length of \(maxLen) characters."
            )
        case .objectionableContent:
            throw AppError(
                .badRequest,
                code: .contentRejected,
                message: "Message contains prohibited or unsafe content."
            )
        }

        let context = try await verifyConversationParticipant(
            conversationID: conversationID,
            userID: senderUserID,
            on: db
        )

        guard try context.myHorse.requireID() == senderHorseID else {
            throw AppError(
                .forbidden,
                code: .forbidden,
                message: "senderHorseID does not match your horse in this conversation."
            )
        }

        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let messageModel = MessageModel(
            conversationID: conversationID,
            senderUserID: senderUserID,
            senderHorseID: senderHorseID,
            body: trimmedBody
        )
        try await messageModel.save(on: db)

        context.conversation.updatedAt = Date()
        try await context.conversation.save(on: db)

        let messageDTO = try messageModel.toDTO()

        // Broadcast new message to both participants
        await app.webSocketHub.send(
            .messageReceived(messageDTO),
            to: [senderUserID, context.otherUserID]
        )

        // Compute recipient's updated unread count for this conversation and across all conversations
        let recipientConvUnread = try await countUnreadMessages(
            in: conversationID,
            for: context.otherUserID,
            on: db
        )
        let recipientTotalUnread = try await countTotalUnreadMessages(
            for: context.otherUserID,
            on: db
        )
        await app.webSocketHub.send(
            .unreadCountUpdated(
                WSUnreadCountPayload(
                    conversationID: conversationID,
                    unreadCount: recipientConvUnread,
                    totalUnreadCount: recipientTotalUnread
                )
            ),
            to: context.otherUserID
        )

        await app.pushNotificationService.sendNewMessageNotification(
            to: context.otherUserID,
            message: messageDTO,
            senderHorseName: context.myHorse.name,
            on: db
        )

        return messageDTO
    }

    private func markConversationMessagesRead(
        conversationID: UUID,
        readerUserID: UUID,
        upToMessageID: UUID?,
        app: Application,
        db: Database
    ) async throws -> MarkMessagesReadResponse {
        let context = try await verifyConversationParticipant(
            conversationID: conversationID,
            userID: readerUserID,
            on: db
        )

        let unreadMessages = try await MessageModel.query(on: db)
            .filter(\.$conversation.$id == conversationID)
            .filter(\.$senderUser.$id != readerUserID)
            .filter(\.$readAt == nil)
            .sort(\.$createdAt, .ascending)
            .all()

        let now = Date()
        var markedCount = 0

        for msg in unreadMessages {
            msg.readAt = now
            try await msg.save(on: db)
            markedCount += 1
            if let upToMessageID, msg.id == upToMessageID {
                break
            }
        }

        let receipt = WSReadReceiptPayload(
            conversationID: conversationID,
            readerUserID: readerUserID,
            upToMessageID: upToMessageID,
            readAt: now
        )
        await app.webSocketHub.send(
            .readReceipt(receipt),
            to: [readerUserID, context.otherUserID]
        )

        let remainingConvUnread = try await countUnreadMessages(
            in: conversationID,
            for: readerUserID,
            on: db
        )
        let totalUnread = try await countTotalUnreadMessages(for: readerUserID, on: db)

        await app.webSocketHub.send(
            .unreadCountUpdated(
                WSUnreadCountPayload(
                    conversationID: conversationID,
                    unreadCount: remainingConvUnread,
                    totalUnreadCount: totalUnread
                )
            ),
            to: readerUserID
        )

        return MarkMessagesReadResponse(
            conversationID: conversationID,
            readCount: markedCount,
            readAt: now
        )
    }

    private func countUnreadMessages(
        in conversationID: UUID,
        for userID: UUID,
        on db: Database
    ) async throws -> Int {
        try await MessageModel.query(on: db)
            .filter(\.$conversation.$id == conversationID)
            .filter(\.$senderUser.$id != userID)
            .filter(\.$readAt == nil)
            .count()
    }

    private func countTotalUnreadMessages(
        for userID: UUID,
        on db: Database
    ) async throws -> Int {
        let summaries = try await fetchConversationSummaries(for: userID, on: db)
        return summaries.reduce(0) { $0 + $1.unreadCount }
    }

    private func fetchConversationSummaries(
        for userID: UUID,
        on db: Database
    ) async throws -> [ConversationSummaryDTO] {
        let myHorses = try await HorseProfileModel.query(on: db)
            .filter(\.$owner.$id == userID)
            .all()
        let myHorseIDs = try myHorses.map { try $0.requireID() }
        guard !myHorseIDs.isEmpty else {
            return []
        }

        let blocks = try await BlockModel.query(on: db)
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

        let matches = try await MatchModel.query(on: db)
            .group(.or) { group in
                group.filter(\.$horseA.$id ~~ myHorseIDs)
                group.filter(\.$horseB.$id ~~ myHorseIDs)
            }
            .with(\.$horseA) { $0.with(\.$photos) }
            .with(\.$horseB) { $0.with(\.$photos) }
            .all()

        var summaries: [ConversationSummaryDTO] = []
        for match in matches {
            let matchID = try match.requireID()
            let horseA = match.horseA
            let horseB = match.horseB

            if blockedUserIDs.contains(horseA.$owner.id) || blockedUserIDs.contains(horseB.$owner.id) {
                continue
            }

            guard
                let conversation = try await ConversationModel.query(on: db)
                    .filter(\.$match.$id == matchID)
                    .first()
            else {
                continue
            }

            let conversationID = try conversation.requireID()
            let myHorse = (horseA.$owner.id == userID) ? horseA : horseB
            let otherHorse = (horseA.$owner.id == userID) ? horseB : horseA

            let lastMessage = try await MessageModel.query(on: db)
                .filter(\.$conversation.$id == conversationID)
                .sort(\.$createdAt, .descending)
                .first()

            let unreadCount = try await countUnreadMessages(in: conversationID, for: userID, on: db)

            summaries.append(
                ConversationSummaryDTO(
                    id: conversationID,
                    matchID: matchID,
                    myHorse: try myHorse.toDTO(),
                    otherHorse: try otherHorse.toDTO(),
                    lastMessage: try lastMessage?.toDTO(),
                    unreadCount: unreadCount,
                    updatedAt: conversation.updatedAt ?? conversation.createdAt ?? Date()
                )
            )
        }

        return summaries.sorted { $0.updatedAt > $1.updatedAt }
    }
}
