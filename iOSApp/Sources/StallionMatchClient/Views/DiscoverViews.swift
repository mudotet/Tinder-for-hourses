import SharedModels
import SwiftUI

public struct DiscoverScreen: View {
    @Bindable public var appState: AppStateViewModel
    @Bindable public var viewModel: DiscoverViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragOffset: CGSize = .zero
    @State private var selectedHorseForDetail: HorseProfileDTO?
    @State private var showFilterSheet = false
    @State private var showCreateHorseSheet = false

    public init(appState: AppStateViewModel, viewModel: DiscoverViewModel) {
        self.appState = appState
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 16) {
                    // Active Horse Header Bar
                    activeHorseBar

                    if viewModel.state == .loaded, let topCard = viewModel.cards.first {
                        ZStack {
                            ForEach(Array(viewModel.cards.prefix(2).enumerated().reversed()), id: \.element.id) { index, horse in
                                let isTop = (index == 0)
                                HorseDiscoveryCardView(horse: horse)
                                    .scaleEffect(isTop ? 1.0 : 0.96)
                                    .offset(
                                        x: isTop ? dragOffset.width : 0,
                                        y: isTop ? dragOffset.height * 0.25 : 10
                                    )
                                    .rotationEffect(
                                        .degrees(isTop && !reduceMotion ? Double(dragOffset.width / 18) : 0)
                                    )
                                    .onTapGesture {
                                        selectedHorseForDetail = horse
                                    }
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                guard isTop else { return }
                                                dragOffset = value.translation
                                            }
                                            .onEnded { value in
                                                guard isTop else { return }
                                                handleDragEnded(value: value, horse: horse)
                                            }
                                    )
                            }
                        }
                        .padding(.horizontal, 16)

                        // Accessible Like / Pass / Details action bar
                        HStack(spacing: 32) {
                            Button {
                                triggerSwipe(.pass, for: topCard)
                            } label: {
                                Label("Pass", systemImage: "xmark")
                                    .font(.title3.weight(.bold))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(EquestrianTheme.warmTerracotta)
                            .clipShape(Capsule())
                            .accessibilityIdentifier("passHorseButton")
                            .accessibilityLabel("Pass on \(topCard.name)")

                            Button {
                                selectedHorseForDetail = topCard
                            } label: {
                                Image(systemName: "info.circle.fill")
                                    .font(.title2)
                                    .padding(12)
                            }
                            .buttonStyle(.bordered)
                            .tint(EquestrianTheme.saddleBrown)
                            .clipShape(Circle())
                            .accessibilityIdentifier("horseDetailsButton")
                            .accessibilityLabel("View details for \(topCard.name)")

                            Button {
                                triggerSwipe(.like, for: topCard)
                            } label: {
                                Label("Like", systemImage: "heart.fill")
                                    .font(.title3.weight(.bold))
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(EquestrianTheme.pastureSage)
                            .clipShape(Capsule())
                            .accessibilityIdentifier("likeHorseButton")
                            .accessibilityLabel("Like \(topCard.name)")
                        }
                        .padding(.bottom, 12)
                    } else {
                        ScreenStateContainerView(state: viewModel.state) {
                            Task {
                                await viewModel.loadCards(activeHorseID: appState.activeHorse?.id, reset: true)
                            }
                        }
                    }
                }

                if let match = viewModel.celebratedMatch {
                    MatchCelebrationOverlay(match: match) {
                        viewModel.celebratedMatch = nil
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle("Discover")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFilterSheet = true
                    } label: {
                        Label("Filters", systemImage: "slider.horizontal.3")
                    }
                    .accessibilityIdentifier("openFiltersButton")
                }
            }
            .sheet(item: $selectedHorseForDetail) { horse in
                NavigationStack {
                    HorseDetailSheet(horse: horse, apiClient: appState.apiClient) {
                        Task {
                            await viewModel.loadCards(activeHorseID: appState.activeHorse?.id, reset: true)
                        }
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                NavigationStack {
                    DiscoverFilterSheet(viewModel: viewModel, activeHorseID: appState.activeHorse?.id)
                }
            }
            .sheet(isPresented: $showCreateHorseSheet) {
                NavigationStack {
                    HorseEditorSheet(appState: appState, existingHorse: nil) {
                        Task {
                            await viewModel.loadCards(activeHorseID: appState.activeHorse?.id, reset: true)
                        }
                    }
                }
            }
            .task(id: appState.activeHorse?.id) {
                await viewModel.loadCards(activeHorseID: appState.activeHorse?.id, reset: true)
            }
        }
    }

    private var activeHorseBar: some View {
        HStack {
            if let active = appState.activeHorse {
                Menu {
                    ForEach(appState.myHorses) { horse in
                        Button {
                            appState.activeHorseID = horse.id
                        } label: {
                            HStack {
                                Text("\(horse.name) (\(horse.breed))")
                                if horse.id == active.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button {
                        showCreateHorseSheet = true
                    } label: {
                        Label("Add Another Horse", systemImage: "plus")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.equestrian.sports")
                        Text("Swiping as: \(active.name)")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(EquestrianTheme.saddleBrown.opacity(0.12)))
                    .foregroundStyle(EquestrianTheme.saddleBrown)
                }
                .accessibilityLabel("Active horse: \(active.name). Tap to switch horse.")
            } else {
                Button {
                    showCreateHorseSheet = true
                } label: {
                    Label("Create Your First Horse Profile", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(EquestrianTheme.saddleBrown)
                .accessibilityIdentifier("createFirstHorseButton")
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private func handleDragEnded(value: DragGesture.Value, horse: HorseProfileDTO) {
        let threshold: CGFloat = 100
        if value.translation.width > threshold {
            triggerSwipe(.like, for: horse)
        } else if value.translation.width < -threshold {
            triggerSwipe(.pass, for: horse)
        } else {
            if reduceMotion {
                dragOffset = .zero
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    dragOffset = .zero
                }
            }
        }
    }

    private func triggerSwipe(_ direction: SwipeDirection, for horse: HorseProfileDTO) {
        guard let activeHorseID = appState.activeHorse?.id else { return }
        dragOffset = .zero
        Task {
            await viewModel.swipe(on: horse, direction: direction, activeHorseID: activeHorseID)
        }
    }
}

public struct HorseDiscoveryCardView: View {
    public let horse: HorseProfileDTO

    public init(horse: HorseProfileDTO) {
        self.horse = horse
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Hero Banner
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [EquestrianTheme.saddleBrown.opacity(0.85), EquestrianTheme.pastureSage.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 240)
                    .overlay {
                        Image(systemName: "figure.equestrian.sports")
                            .font(.system(size: 76))
                            .foregroundStyle(.white.opacity(0.28))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(horse.name), \(horse.age)")
                            .font(.title.weight(.bold))
                            .foregroundStyle(.white)

                        Text(horse.sex.displayName)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.white.opacity(0.25)))
                            .foregroundStyle(.white)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                        Text(horse.location.city)
                            .font(.subheadline)
                        if let distanceKm = horse.distanceKm {
                            Text("• \(String(format: "%.1f", distanceKm)) km away")
                                .font(.subheadline)
                        }
                    }
                    .foregroundStyle(.white.opacity(0.92))
                }
                .padding(16)
            }

            // Breed, Height & Color
            HStack(spacing: 12) {
                Label(horse.breed, systemImage: "rosette")
                Text("•")
                Text("\(String(format: "%.1f", horse.heightHands)) hh")
                Text("•")
                Text(horse.color)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(EquestrianTheme.saddleBrown)

            // Bio
            Text(horse.bio)
                .font(.body)
                .lineLimit(3)
                .foregroundStyle(.primary)

            // Disciplines & Looking-For Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(horse.disciplines, id: \.self) { disc in
                        Text(disc.displayName)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(EquestrianTheme.saddleBrown.opacity(0.12)))
                            .foregroundStyle(EquestrianTheme.saddleBrown)
                    }
                    ForEach(horse.lookingFor, id: \.self) { goal in
                        Text(goal.displayName)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(EquestrianTheme.pastureSage.opacity(0.15)))
                            .foregroundStyle(EquestrianTheme.pastureSage)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.background)
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(horse.name), \(horse.age) year old \(horse.breed) \(horse.sex.displayName) in \(horse.location.city). \(horse.bio)"
        )
    }
}

public struct MatchCelebrationOverlay: View {
    public let match: MatchDTO
    public let onDismiss: () -> Void

    public init(match: MatchDTO, onDismiss: @escaping () -> Void) {
        self.match = match
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "sparkles")
                    .font(.system(size: 52))
                    .foregroundStyle(EquestrianTheme.ribbonGold)

                Text("It's a Match!")
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("itsAMatchTitle")

                Text("\(match.horseA.name) and \(match.horseB.name) liked each other!")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.9))

                Button {
                    onDismiss()
                } label: {
                    Text("Keep Swiping")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(EquestrianTheme.pastureSage)
                .accessibilityIdentifier("dismissMatchOverlayButton")
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(EquestrianTheme.saddleBrown)
            )
            .padding(32)
        }
    }
}

public struct HorseDetailSheet: View {
    public let horse: HorseProfileDTO
    public let apiClient: any APIClientProtocol
    public let onModerationAction: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var showReportDialog = false
    @State private var selectedReportReason: ReportReason = .inappropriateContent
    @State private var reportDetails = ""
    @State private var statusBanner: String?

    public init(
        horse: HorseProfileDTO,
        apiClient: any APIClientProtocol,
        onModerationAction: @escaping () -> Void
    ) {
        self.horse = horse
        self.apiClient = apiClient
        self.onModerationAction = onModerationAction
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HorseDiscoveryCardView(horse: horse)

                if !horse.temperamentTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Temperament")
                            .font(.headline)
                        HStack(spacing: 8) {
                            ForEach(horse.temperamentTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(EquestrianTheme.ribbonGold.opacity(0.2)))
                            }
                        }
                    }
                }

                if let health = horse.healthInfo {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Health & Veterinary Records")
                            .font(.headline)
                        if let vaccinations = health.vaccinationsUpToDate {
                            Label(
                                vaccinations ? "Vaccinations Up to Date" : "Vaccinations Pending",
                                systemImage: vaccinations ? "checkmark.seal.fill" : "clock"
                            )
                            .font(.subheadline)
                            .foregroundStyle(vaccinations ? EquestrianTheme.pastureSage : .secondary)
                        }
                        if let coggins = health.cogginsTestDate {
                            Text("Coggins Test Date: \(coggins.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let pedigree = horse.pedigree, !pedigree.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pedigree")
                            .font(.headline)
                        Text(pedigree)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                AnimalWelfareNoticeBanner()

                if let statusBanner {
                    Text(statusBanner)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(EquestrianTheme.pastureSage)
                }

                Divider()

                // Safety Actions (Report / Block)
                HStack(spacing: 16) {
                    Button(role: .destructive) {
                        showReportDialog = true
                    } label: {
                        Label("Report Profile", systemImage: "flag.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        Task {
                            _ = try? await apiClient.blockUser(
                                BlockUserRequest(blockedUserID: horse.ownerID, reason: "Blocked from profile view")
                            )
                            onModerationAction()
                            dismiss()
                        }
                    } label: {
                        Label("Block Owner", systemImage: "hand.raised.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(16)
        }
        .navigationTitle(horse.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Close") { dismiss() }
            }
        }
        .sheet(isPresented: $showReportDialog) {
            NavigationStack {
                Form {
                    Picker("Reason", selection: $selectedReportReason) {
                        ForEach(ReportReason.allCases, id: \.self) { reason in
                            Text(reason.displayName).tag(reason)
                        }
                    }
                    TextField("Additional details (optional)", text: $reportDetails, axis: .vertical)
                        .lineLimit(3...6)
                }
                .navigationTitle("Report \(horse.name)")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showReportDialog = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Submit Report") {
                            Task {
                                _ = try? await apiClient.createReport(
                                    CreateReportRequest(
                                        targetType: .horse,
                                        targetID: horse.id,
                                        reason: selectedReportReason,
                                        details: reportDetails
                                    )
                                )
                                showReportDialog = false
                                statusBanner = "Report submitted to our moderation team."
                            }
                        }
                    }
                }
            }
        }
    }
}

public struct DiscoverFilterSheet: View {
    @Bindable public var viewModel: DiscoverViewModel
    public let activeHorseID: UUID?
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: DiscoverViewModel, activeHorseID: UUID?) {
        self.viewModel = viewModel
        self.activeHorseID = activeHorseID
    }

    public var body: some View {
        Form {
            Section("Distance Radius") {
                VStack(alignment: .leading) {
                    Text("Maximum Distance: \(Int(viewModel.maxDistanceKm)) km")
                        .font(.subheadline.weight(.medium))
                    Slider(value: $viewModel.maxDistanceKm, in: 10...500, step: 10)
                        .tint(EquestrianTheme.saddleBrown)
                }
            }

            Section("Horse Attributes") {
                TextField("Breed (e.g. Hanoverian, Arabian)", text: $viewModel.filterBreed)

                Picker("Sex", selection: $viewModel.filterSex) {
                    Text("Any").tag(HorseSex?.none)
                    ForEach(HorseSex.allCases, id: \.self) { sex in
                        Text(sex.displayName).tag(HorseSex?.some(sex))
                    }
                }

                Picker("Discipline", selection: $viewModel.filterDiscipline) {
                    Text("Any").tag(HorseDiscipline?.none)
                    ForEach(HorseDiscipline.allCases, id: \.self) { disc in
                        Text(disc.displayName).tag(HorseDiscipline?.some(disc))
                    }
                }

                Picker("Looking For", selection: $viewModel.filterLookingFor) {
                    Text("Any").tag(LookingForCategory?.none)
                    ForEach(LookingForCategory.allCases, id: \.self) { goal in
                        Text(goal.displayName).tag(LookingForCategory?.some(goal))
                    }
                }
            }

            Section {
                Button("Reset All Filters", role: .destructive) {
                    Task {
                        await viewModel.resetFilters(activeHorseID: activeHorseID)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle("Discovery Filters")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    Task {
                        await viewModel.loadCards(activeHorseID: activeHorseID, reset: true)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("Discover Screen") {
    let client = MockAPIClient()
    let appState = AppStateViewModel(
        apiClient: client,
        preauthenticatedUser: MockSampleData.currentUser,
        initialHorses: [MockSampleData.myHorse]
    )
    let discoverVM = DiscoverViewModel(apiClient: client)
    return DiscoverScreen(appState: appState, viewModel: discoverVM)
}
