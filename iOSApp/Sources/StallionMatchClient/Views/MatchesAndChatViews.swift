import SharedModels
import SwiftUI

public struct MatchesScreen: View {
    @Bindable public var appState: AppStateViewModel
    @Bindable public var viewModel: MatchesAndConversationsViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    public init(appState: AppStateViewModel, viewModel: MatchesAndConversationsViewModel) {
        self.appState = appState
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                EquestrianTheme.screenBackground.ignoresSafeArea()

                if viewModel.matchesState == .loaded {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(spacing: 8) {
                                Image(systemName: "heart.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(EquestrianTheme.brandGradient)
                                Text("New Equine Matches")
                                    .font(.title3.weight(.heavy))
                                    .foregroundStyle(EquestrianTheme.charcoalText)
                                Spacer()
                                Text("\(viewModel.matches.count)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(EquestrianTheme.brandGradient))
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(viewModel.matches) { match in
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
                                        ZStack(alignment: .bottomLeading) {
                                            HorsePhotoView(
                                                horseName: otherHorse.name,
                                                photoURL: otherHorse.photos.first?.url,
                                                photoIndex: 0
                                            )
                                            .frame(height: 220)

                                            LinearGradient(
                                                colors: [.clear, .black.opacity(0.82)],
                                                startPoint: .center,
                                                endPoint: .bottom
                                            )

                                            VStack(alignment: .leading, spacing: 3) {
                                                HStack(spacing: 4) {
                                                    Text("\(otherHorse.name), \(otherHorse.age)")
                                                        .font(.headline.weight(.bold))
                                                        .foregroundStyle(.white)
                                                    Image(systemName: "heart.fill")
                                                        .font(.caption2)
                                                        .foregroundStyle(EquestrianTheme.tinderRed)
                                                }
                                                Text(otherHorse.breed)
                                                    .font(.caption.weight(.medium))
                                                    .foregroundStyle(.white.opacity(0.88))
                                                Text(otherHorse.location.city)
                                                    .font(.caption2)
                                                    .foregroundStyle(.white.opacity(0.75))
                                            }
                                            .padding(12)
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(EquestrianTheme.tinderRed.opacity(0.35), lineWidth: 1.5)
                                        )
                                        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 20)
                    }
                } else {
                    ScreenStateContainerView(state: viewModel.matchesState) {
                        Task { await viewModel.loadMatches() }
                    }
                }
            }
            .task {
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
            ZStack {
                EquestrianTheme.screenBackground.ignoresSafeArea()

                if viewModel.conversationsState == .loaded {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            // Top Horizontal "New Matches" Avatar Strip (Tinder-style)
                            if !viewModel.conversations.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("NEW MATCHES")
                                        .font(.caption.weight(.heavy))
                                        .tracking(1)
                                        .foregroundStyle(EquestrianTheme.tinderRed)
                                        .padding(.horizontal, 16)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 14) {
                                            ForEach(viewModel.conversations) { summary in
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
                                                    VStack(spacing: 6) {
                                                        HorsePhotoView(
                                                            horseName: summary.otherHorse.name,
                                                            photoURL: summary.otherHorse.photos.first?.url,
                                                            photoIndex: 0
                                                        )
                                                        .frame(width: 68, height: 68)
                                                        .clipShape(Circle())
                                                        .overlay(
                                                            Circle().stroke(EquestrianTheme.brandGradient, lineWidth: 2.5)
                                                        )

                                                        Text(summary.otherHorse.name)
                                                            .font(.caption.weight(.bold))
                                                            .foregroundStyle(EquestrianTheme.charcoalText)
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }

                            // Messages List
                            VStack(alignment: .leading, spacing: 10) {
                                Text("MESSAGES")
                                    .font(.caption.weight(.heavy))
                                    .tracking(1)
                                    .foregroundStyle(EquestrianTheme.tinderRed)
                                    .padding(.horizontal, 16)

                                VStack(spacing: 10) {
                                    ForEach(viewModel.conversations) { summary in
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
                                                HorsePhotoView(
                                                    horseName: summary.otherHorse.name,
                                                    photoURL: summary.otherHorse.photos.first?.url,
                                                    photoIndex: 0
                                                )
                                                .frame(width: 60, height: 60)
                                                .clipShape(Circle())

                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack {
                                                        Text(summary.otherHorse.name)
                                                            .font(.headline.weight(.bold))
                                                            .foregroundStyle(EquestrianTheme.charcoalText)
                                                        Text("• \(summary.otherHorse.breed)")
                                                            .font(.caption)
                                                            .foregroundStyle(EquestrianTheme.slateSecondary)
                                                        Spacer()
                                                        if summary.unreadCount > 0 {
                                                            Text("\(summary.unreadCount)")
                                                                .font(.caption2.weight(.bold))
                                                                .padding(.horizontal, 8)
                                                                .padding(.vertical, 4)
                                                                .background(Capsule().fill(EquestrianTheme.brandGradient))
                                                                .foregroundStyle(.white)
                                                        }
                                                    }

                                                    Text(summary.lastMessage?.body ?? "Say hello to \(summary.otherHorse.name)!")
                                                        .font(.subheadline)
                                                        .foregroundStyle(
                                                            summary.unreadCount > 0
                                                                ? EquestrianTheme.charcoalText
                                                                : EquestrianTheme.slateSecondary
                                                        )
                                                        .fontWeight(summary.unreadCount > 0 ? .semibold : .regular)
                                                        .lineLimit(1)
                                                }
                                            }
                                            .padding(14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .fill(Color.white)
                                                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.top, 14)
                        .padding(.bottom, 20)
                    }
                } else {
                    ScreenStateContainerView(state: viewModel.conversationsState) {
                        Task { await viewModel.loadConversations() }
                    }
                }
            }
            .task {
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
            // Custom Tinder Chat Header
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(EquestrianTheme.tinderRed)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)

                HorsePhotoView(
                    horseName: viewModel.conversationSummary.otherHorse.name,
                    photoURL: viewModel.conversationSummary.otherHorse.photos.first?.url,
                    photoIndex: 0
                )
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(EquestrianTheme.tinderRed.opacity(0.4), lineWidth: 1.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.conversationSummary.otherHorse.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(EquestrianTheme.charcoalText)
                    Text("\(viewModel.conversationSummary.otherHorse.breed) • \(viewModel.conversationSummary.otherHorse.location.city)")
                        .font(.caption2)
                        .foregroundStyle(EquestrianTheme.slateSecondary)
                }

                Spacer()

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
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(EquestrianTheme.tinderRed)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white)

            Divider()

            if let banner = viewModel.safetyBannerMessage {
                Text(banner)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(EquestrianTheme.tinderRed)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            }

            if viewModel.state == .loaded {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        AnimalWelfareNoticeBanner()
                            .padding(.bottom, 6)

                        ForEach(viewModel.messages) { msg in
                            let isMine = (msg.senderUserID == currentUserID)
                            HStack(alignment: .bottom, spacing: 8) {
                                if isMine {
                                    Spacer(minLength: 52)
                                } else {
                                    HorsePhotoView(
                                        horseName: viewModel.conversationSummary.otherHorse.name,
                                        photoURL: viewModel.conversationSummary.otherHorse.photos.first?.url,
                                        photoIndex: 0
                                    )
                                    .frame(width: 28, height: 28)
                                    .clipShape(Circle())
                                }

                                VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                                    Text(msg.body)
                                        .font(.subheadline)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .fill(
                                                    isMine
                                                        ? AnyShapeStyle(EquestrianTheme.brandGradient)
                                                        : AnyShapeStyle(Color.white)
                                                )
                                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                                        )
                                        .foregroundStyle(isMine ? .white : EquestrianTheme.charcoalText)

                                    HStack(spacing: 5) {
                                        Text(msg.createdAt.formatted(date: .omitted, time: .shortened))
                                            .font(.caption2)
                                            .foregroundStyle(EquestrianTheme.slateSecondary)
                                        if isMine, msg.readAt != nil {
                                            Text("• Read")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(EquestrianTheme.tinderRed)
                                        }
                                    }
                                }

                                if !isMine { Spacer(minLength: 52) }
                            }
                        }

                        if viewModel.isOtherHorseTyping {
                            HStack(alignment: .bottom, spacing: 8) {
                                HorsePhotoView(
                                    horseName: viewModel.conversationSummary.otherHorse.name,
                                    photoURL: viewModel.conversationSummary.otherHorse.photos.first?.url,
                                    photoIndex: 0
                                )
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())

                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(EquestrianTheme.tinderRed)
                                    Text("\(viewModel.conversationSummary.otherHorse.name) is typing an AI reply...")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(EquestrianTheme.tinderRed)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(EquestrianTheme.softRoseTint)
                                )
                                Spacer()
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(16)
                }
                .background(EquestrianTheme.screenBackground)
            } else {
                ScreenStateContainerView(state: viewModel.state) {
                    Task { await viewModel.loadMessages() }
                }
            }

            // Quick AI Icebreaker Suggestion Strip
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AIEquestrianPersonaEngine.quickIcebreakers, id: \.self) { suggestion in
                        Button {
                            viewModel.draftText = suggestion
                            Task { await viewModel.sendMessage() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10, weight: .bold))
                                Text(suggestion)
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(EquestrianTheme.tinderRed)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(EquestrianTheme.softRoseTint)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 2)
            }
            .background(Color.white)

            // Mobile Chat Input Pill Bar
            HStack(spacing: 10) {
                TextField(
                    "Send a message to \(viewModel.conversationSummary.otherHorse.name)...",
                    text: $viewModel.draftText
                )
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(EquestrianTheme.screenBackground)
                        .overlay(Capsule().stroke(Color.gray.opacity(0.22), lineWidth: 1))
                )
                .accessibilityIdentifier("chatMessageInputField")

                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle().fill(
                                viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? AnyShapeStyle(Color.gray.opacity(0.35))
                                    : AnyShapeStyle(EquestrianTheme.brandGradient)
                            )
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("sendChatMessageButton")
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white)
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
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

struct ChatDetailScreen_Previews: PreviewProvider {
    static var previews: some View {
        let client = MockAPIClient()
        let chatVM = ChatDetailViewModel(
            conversationSummary: MockSampleData.sampleConversationSummary,
            apiClient: client
        )
        NavigationStack {
            ChatDetailScreen(
                viewModel: chatVM,
                currentUserID: MockSampleData.currentUserID
            )
        }
    }
}
