import SharedModels
import SwiftUI

public struct MatchesScreen: View {
    @Bindable public var appState: AppStateViewModel
    @Bindable public var viewModel: MatchesAndConversationsViewModel

    public init(appState: AppStateViewModel, viewModel: MatchesAndConversationsViewModel) {
        self.appState = appState
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.matchesState == .loaded {
                    List(viewModel.matches) { match in
                        let myHorseIDs = Set(appState.myHorses.map(\.id))
                        let myHorse = myHorseIDs.contains(match.horseA.id) ? match.horseA : match.horseB
                        let otherHorse = myHorseIDs.contains(match.horseA.id) ? match.horseB : match.horseA
                        let summary = ConversationSummaryDTO(
                            id: match.conversationID,
                            matchID: match.id,
                            myHorse: myHorse,
                            otherHorse: otherHorse,
                            lastMessage: nil,
                            unreadCount: 0,
                            updatedAt: match.createdAt
                        )

                        NavigationLink {
                            ChatDetailScreen(
                                viewModel: ChatDetailViewModel(
                                    conversationSummary: summary,
                                    apiClient: appState.apiClient
                                ),
                                currentUserID: appState.currentUser?.id ?? MockSampleData.currentUserID,
                                onConversationModerated: {
                                    Task { await viewModel.refreshAll() }
                                }
                            )
                        } label: {
                            HStack(spacing: 14) {
                                Circle()
                                    .fill(EquestrianTheme.saddleBrown.opacity(0.16))
                                    .frame(width: 52, height: 52)
                                    .overlay {
                                        Image(systemName: "figure.equestrian.sports")
                                            .foregroundStyle(EquestrianTheme.saddleBrown)
                                    }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(otherHorse.name) (\(otherHorse.breed))")
                                        .font(.headline)
                                    Text("Matched with \(myHorse.name) • \(otherHorse.location.city)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    ScreenStateContainerView(state: viewModel.matchesState) {
                        Task { await viewModel.loadMatches() }
                    }
                }
            }
            .navigationTitle("Matches")
            .task {
                await viewModel.loadMatches()
            }
            .refreshable {
                await viewModel.loadMatches()
            }
        }
    }
}

public struct MessagesScreen: View {
    @Bindable public var appState: AppStateViewModel
    @Bindable public var viewModel: MatchesAndConversationsViewModel

    public init(appState: AppStateViewModel, viewModel: MatchesAndConversationsViewModel) {
        self.appState = appState
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.conversationsState == .loaded {
                    List(viewModel.conversations) { summary in
                        NavigationLink {
                            ChatDetailScreen(
                                viewModel: ChatDetailViewModel(
                                    conversationSummary: summary,
                                    apiClient: appState.apiClient
                                ),
                                currentUserID: appState.currentUser?.id ?? MockSampleData.currentUserID,
                                onConversationModerated: {
                                    Task { await viewModel.refreshAll() }
                                }
                            )
                        } label: {
                            HStack(spacing: 14) {
                                Circle()
                                    .fill(EquestrianTheme.pastureSage.opacity(0.18))
                                    .frame(width: 52, height: 52)
                                    .overlay {
                                        Image(systemName: "message.fill")
                                            .foregroundStyle(EquestrianTheme.pastureSage)
                                    }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(summary.otherHorse.name)
                                            .font(.headline)
                                        Spacer()
                                        if summary.unreadCount > 0 {
                                            Text("\(summary.unreadCount)")
                                                .font(.caption2.weight(.bold))
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 3)
                                                .background(Capsule().fill(EquestrianTheme.warmTerracotta))
                                                .foregroundStyle(.white)
                                                .accessibilityLabel("\(summary.unreadCount) unread messages")
                                        }
                                    }

                                    Text(summary.lastMessage?.body ?? "Tap to start chatting")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    ScreenStateContainerView(state: viewModel.conversationsState) {
                        Task { await viewModel.loadConversations() }
                    }
                }
            }
            .navigationTitle("Messages")
            .task {
                await viewModel.loadConversations()
            }
            .refreshable {
                await viewModel.loadConversations()
            }
        }
    }
}

public struct ChatDetailScreen: View {
    @Bindable public var viewModel: ChatDetailViewModel
    public let currentUserID: UUID
    public let onConversationModerated: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var showReportSheet = false
    @State private var selectedReason: ReportReason = .inappropriateContent
    @State private var reportDetails = ""

    public init(
        viewModel: ChatDetailViewModel,
        currentUserID: UUID,
        onConversationModerated: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.currentUserID = currentUserID
        self.onConversationModerated = onConversationModerated
    }

    public var body: some View {
        VStack(spacing: 0) {
            AnimalWelfareNoticeBanner()
                .padding(.horizontal, 12)
                .padding(.top, 8)

            if let banner = viewModel.safetyBannerMessage {
                Text(banner)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EquestrianTheme.warmTerracotta)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }

            if viewModel.state == .loaded {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { msg in
                            let isMine = (msg.senderUserID == currentUserID)
                            HStack {
                                if isMine { Spacer(minLength: 48) }
                                VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                                    Text(msg.body)
                                        .font(.body)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(
                                                    isMine
                                                        ? EquestrianTheme.saddleBrown
                                                        : EquestrianTheme.pastureSage.opacity(0.16)
                                                )
                                        )
                                        .foregroundStyle(isMine ? .white : .primary)

                                    HStack(spacing: 6) {
                                        Text(msg.createdAt.formatted(date: .omitted, time: .shortened))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        if isMine, msg.readAt != nil {
                                            Text("• Read")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(EquestrianTheme.pastureSage)
                                        }
                                    }
                                }
                                if !isMine { Spacer(minLength: 48) }
                            }
                        }

                        if viewModel.isOtherHorseTyping {
                            HStack {
                                Text("\(viewModel.conversationSummary.otherHorse.name) is typing...")
                                    .font(.caption.italic())
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                }
            } else {
                ScreenStateContainerView(state: viewModel.state) {
                    Task { await viewModel.loadMessages() }
                }
            }

            Divider()

            HStack(spacing: 10) {
                TextField(
                    "Message \(viewModel.conversationSummary.otherHorse.name)...",
                    text: $viewModel.draftText
                )
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("chatMessageInputField")

                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .padding(8)
                }
                .buttonStyle(.borderedProminent)
                .tint(EquestrianTheme.saddleBrown)
                .disabled(viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("sendChatMessageButton")
                .accessibilityLabel("Send message")
            }
            .padding(12)
        }
        .navigationTitle(viewModel.conversationSummary.otherHorse.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        showReportSheet = true
                    } label: {
                        Label("Report Horse / Conversation", systemImage: "flag.fill")
                    }

                    Button(role: .destructive) {
                        Task {
                            try? await viewModel.blockOtherOwner(reason: "Blocked from chat")
                            onConversationModerated()
                            dismiss()
                        }
                    } label: {
                        Label("Block Owner", systemImage: "hand.raised.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Safety options")
            }
        }
        .sheet(isPresented: $showReportSheet) {
            NavigationStack {
                Form {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(ReportReason.allCases, id: \.self) { reason in
                            Text(reason.displayName).tag(reason)
                        }
                    }
                    TextField("Details (optional)", text: $reportDetails, axis: .vertical)
                        .lineLimit(3...6)
                }
                .navigationTitle("Report Conversation")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showReportSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Submit") {
                            Task {
                                try? await viewModel.reportOtherHorse(
                                    reason: selectedReason,
                                    details: reportDetails
                                )
                                showReportSheet = false
                            }
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.loadMessages()
        }
    }
}

#Preview("Messages & Chat") {
    let client = MockAPIClient()
    let chatVM = ChatDetailViewModel(
        conversationSummary: MockSampleData.sampleConversationSummary,
        apiClient: client
    )
    return NavigationStack {
        ChatDetailScreen(
            viewModel: chatVM,
            currentUserID: MockSampleData.currentUserID
        )
    }
}
