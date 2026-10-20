import SharedModels
import SwiftUI

public struct DiscoverScreen: View {
    @Bindable public var appState: AppStateViewModel
    @Bindable public var viewModel: DiscoverViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragOffset: CGSize = .zero
    @State private var photoIndexByHorse: [UUID: Int] = [:]
    @State private var swipedHistory: [HorseProfileDTO] = []
    @State private var isAnimatingOut = false
    @State private var superLikedBannerHorse: String?
    @State private var selectedHorseForDetail: HorseProfileDTO?
    @State private var showFilterSheet = false
    @State private var showCreateHorseSheet = false

    public init(appState: AppStateViewModel, viewModel: DiscoverViewModel) {
        self.appState = appState
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            EquestrianTheme.screenBackground
                .ignoresSafeArea()

            VStack(spacing: 10) {
                // Tinder Mobile Top Bar
                mobileTopHeaderBar

                if viewModel.state == .loaded, let topCard = viewModel.cards.first {
                    // Card Stack Area
                    ZStack {
                        ForEach(Array(viewModel.cards.prefix(3).enumerated().reversed()), id: \.element.id) { index, horse in
                            let isTop = (index == 0)
                            let currentPhotoIndex = photoIndexByHorse[horse.id, default: 0]
                            TinderHorseCardView(
                                horse: horse,
                                photoIndex: currentPhotoIndex,
                                dragOffset: isTop ? dragOffset : .zero,
                                onStepPhoto: { delta in
                                    let count = max(2, horse.photos.count)
                                    let next = (currentPhotoIndex + delta + count) % count
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        photoIndexByHorse[horse.id] = next
                                    }
                                },
                                onOpenDetails: {
                                    selectedHorseForDetail = horse
                                }
                            )
                            .scaleEffect(isTop ? 1.0 : (1.0 - CGFloat(index) * 0.045))
                            .offset(
                                x: isTop ? dragOffset.width : 0,
                                y: isTop ? dragOffset.height * 0.22 : CGFloat(index) * 11
                            )
                            .rotationEffect(
                                .degrees(isTop && !reduceMotion ? Double(dragOffset.width / 16) : 0)
                            )
                            .animation(.interactiveSpring(response: 0.32, dampingFraction: 0.78), value: viewModel.cards.map(\.id))
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        guard isTop && !isAnimatingOut else { return }
                                        dragOffset = value.translation
                                    }
                                    .onEnded { value in
                                        guard isTop && !isAnimatingOut else { return }
                                        handleDragEnded(value: value, horse: horse)
                                    }
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Iconic Floating Tinder Action Bar
                    tinderBottomActionButtons(topCard: topCard)
                        .padding(.bottom, 8)
                } else {
                    ScreenStateContainerView(state: viewModel.state) {
                        Task {
                            await viewModel.loadCards(activeHorseID: appState.activeHorse?.id, reset: true)
                        }
                    }
                }
            }

            if let superLikedName = superLikedBannerHorse {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(EquestrianTheme.superLikeBlue)
                        Text("You Super Liked \(superLikedName)!")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(EquestrianTheme.charcoalText.opacity(0.92)))
                    .shadow(radius: 10)
                    .padding(.top, 64)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let match = viewModel.celebratedMatch {
                MatchCelebrationOverlay(match: match) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.celebratedMatch = nil
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .zIndex(20)
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

    private var mobileTopHeaderBar: some View {
        HStack(spacing: 12) {
            // Iconic Tinder Red Flame + Brand Wordmark
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(EquestrianTheme.brandGradient)
                Text("stallion")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(EquestrianTheme.brandGradient)
            }

            Spacer()

            // Active Horse Pill Selector
            if let active = appState.activeHorse {
                Menu {
                    ForEach(appState.myHorses) { horse in
                        Button {
                            appState.activeHorseID = horse.id
                        } label: {
                            HStack {
                                Text("\(horse.name) • \(horse.breed)")
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
                        Label("Add Horse Profile", systemImage: "plus")
                    }
                } label: {
                    HStack(spacing: 6) {
                        HorsePhotoView(
                            horseName: active.name,
                            photoURL: active.photos.first?.url,
                            photoIndex: 0
                        )
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())

                        Text(active.name)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(EquestrianTheme.charcoalText)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(EquestrianTheme.tinderRed)
                    }
                    .padding(.leading, 5)
                    .padding(.trailing, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    showCreateHorseSheet = true
                } label: {
                    Label("Add Horse", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(EquestrianTheme.brandGradient))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("createFirstHorseButton")
            }

            // Filter Button
            Button {
                showFilterSheet = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(EquestrianTheme.charcoalText)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("openFiltersButton")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func tinderBottomActionButtons(topCard: HorseProfileDTO) -> some View {
        HStack(spacing: 16) {
            // Rewind Button
            Button {
                guard let previous = swipedHistory.popLast() else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    if !viewModel.cards.contains(where: { $0.id == previous.id }) {
                        viewModel.cards.insert(previous, at: 0)
                    }
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(EquestrianTheme.rewindGold)
                    .frame(width: 46, height: 46)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
                    )
            }
            .buttonStyle(.plain)
            .opacity(swipedHistory.isEmpty ? 0.45 : 1.0)
            .disabled(swipedHistory.isEmpty)

            // NOPE / Pass Button (Red X)
            Button {
                animateAndSwipe(.pass, for: topCard)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(EquestrianTheme.nopeRed)
                    .frame(width: 62, height: 62)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .shadow(color: EquestrianTheme.nopeRed.opacity(0.22), radius: 12, x: 0, y: 5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("passHorseButton")
            .accessibilityLabel("Pass on \(topCard.name)")

            // SUPER LIKE Button (Blue Star)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    superLikedBannerHorse = topCard.name
                }
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    withAnimation {
                        superLikedBannerHorse = nil
                    }
                }
                animateAndSwipe(.like, for: topCard)
            } label: {
                Image(systemName: "star.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(EquestrianTheme.superLikeBlue)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .shadow(color: EquestrianTheme.superLikeBlue.opacity(0.25), radius: 10, x: 0, y: 4)
                    )
            }
            .buttonStyle(.plain)

            // LIKE Button (Tinder Red/Green Heart)
            Button {
                animateAndSwipe(.like, for: topCard)
            } label: {
                Image(systemName: "heart.fill")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(
                        Circle()
                            .fill(EquestrianTheme.brandGradient)
                            .shadow(color: EquestrianTheme.tinderRed.opacity(0.38), radius: 12, x: 0, y: 5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("likeHorseButton")
            .accessibilityLabel("Like \(topCard.name)")

            // Info / Details Button
            Button {
                selectedHorseForDetail = topCard
            } label: {
                Image(systemName: "info")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(EquestrianTheme.tinderRed)
                    .frame(width: 46, height: 46)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("horseDetailsButton")
            .accessibilityLabel("View details for \(topCard.name)")
        }
    }

    private func handleDragEnded(value: DragGesture.Value, horse: HorseProfileDTO) {
        let threshold: CGFloat = 95
        if value.translation.width > threshold {
            animateAndSwipe(.like, for: horse)
        } else if value.translation.width < -threshold {
            animateAndSwipe(.pass, for: horse)
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                dragOffset = .zero
            }
        }
    }

    private func animateAndSwipe(_ direction: SwipeDirection, for horse: HorseProfileDTO) {
        guard let activeHorseID = appState.activeHorse?.id, !isAnimatingOut else { return }
        isAnimatingOut = true
        swipedHistory.append(horse)

        let flyOutX: CGFloat = (direction == .like) ? 460 : -460
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            dragOffset = CGSize(width: flyOutX, height: 30)
        }

        Task {
            try? await Task.sleep(nanoseconds: 190_000_000)
            dragOffset = .zero
            isAnimatingOut = false
            await viewModel.swipe(on: horse, direction: direction, activeHorseID: activeHorseID)
        }
    }
}

/// Full-bleed Tinder photo card with story bars, LIKE/NOPE stamps, and rich overlay metadata.
public struct TinderHorseCardView: View {
    public let horse: HorseProfileDTO
    public let photoIndex: Int
    public let dragOffset: CGSize
    public let onStepPhoto: (Int) -> Void
    public let onOpenDetails: () -> Void

    public init(
        horse: HorseProfileDTO,
        photoIndex: Int = 0,
        dragOffset: CGSize = .zero,
        onStepPhoto: @escaping (Int) -> Void = { _ in },
        onOpenDetails: @escaping () -> Void = {}
    ) {
        self.horse = horse
        self.photoIndex = photoIndex
        self.dragOffset = dragOffset
        self.onStepPhoto = onStepPhoto
        self.onOpenDetails = onOpenDetails
    }

    private var photoCount: Int {
        max(2, horse.photos.count)
    }

    private var currentPhotoURL: String? {
        guard !horse.photos.isEmpty else { return nil }
        return horse.photos[photoIndex % horse.photos.count].url
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // Full-bleed Horse Photography
                HorsePhotoView(
                    horseName: horse.name,
                    photoURL: currentPhotoURL,
                    photoIndex: photoIndex
                )
                .frame(width: geo.size.width, height: geo.size.height)

                // Left / Right Invisible Photo Tap Zones (Tinder Story Navigation)
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onStepPhoto(-1) }
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onStepPhoto(1) }
                }

                // Top Story Progress Bars & Distance Pill
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 5) {
                        ForEach(0..<photoCount, id: \.self) { idx in
                            Capsule()
                                .fill(idx == (photoIndex % photoCount) ? Color.white : Color.white.opacity(0.38))
                                .frame(height: 3.5)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    HStack {
                        if horse.healthInfo?.vaccinationsUpToDate == true {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(EquestrianTheme.likeGreen)
                                Text("Vet Verified")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(.black.opacity(0.45)))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)

                    Spacer()
                }

                // LIKE & NOPE Dynamic Swipe Stamps
                swipeOverlayStamps
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // Bottom Gradient Scrim + Horse Info Panel
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(horse.name)
                            .font(.system(size: 31, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        Text("\(horse.age)")
                            .font(.system(size: 25, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))

                        Text(horse.sex.displayName.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(EquestrianTheme.brandGradient))
                            .foregroundStyle(.white)

                        Spacer()

                        Button {
                            onOpenDetails()
                        } label: {
                            Image(systemName: "chevron.up.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .buttonStyle(.plain)
                    }

                    // Breed, Height & Location Row
                    HStack(spacing: 8) {
                        Label(horse.breed, systemImage: "rosette")
                        Text("•")
                        Text("\(String(format: "%.1f", horse.heightHands)) hh")
                        Text("•")
                        Label(
                            horse.distanceKm != nil
                                ? "\(horse.location.city) (\(Int(horse.distanceKm ?? 12)) km)"
                                : horse.location.city,
                            systemImage: "location.fill"
                        )
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))

                    // Bio Preview
                    Text(horse.bio)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(2)

                    // Discipline & Looking-For Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(horse.disciplines, id: \.self) { disc in
                                Text(disc.displayName)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(.white.opacity(0.22)))
                                    .foregroundStyle(.white)
                            }
                            ForEach(horse.lookingFor, id: \.self) { goal in
                                Text(goal.displayName)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(EquestrianTheme.tinderRed.opacity(0.75)))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
                .padding(18)
                .padding(.top, 44)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55), .black.opacity(0.88)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .onTapGesture {
                    onOpenDetails()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 16, x: 0, y: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(horse.name), \(horse.age) year old \(horse.breed) \(horse.sex.displayName) in \(horse.location.city). \(horse.bio)"
        )
    }

    private var swipeOverlayStamps: some View {
        HStack {
            if dragOffset.width > 20 {
                Text("LIKE")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(EquestrianTheme.likeGreen)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(EquestrianTheme.likeGreen, lineWidth: 4)
                    )
                    .rotationEffect(.degrees(-14))
                    .opacity(min(1.0, Double(dragOffset.width - 20) / 85.0))
                    .padding(.leading, 22)
                    .padding(.top, 44)
            }

            Spacer()

            if dragOffset.width < -20 {
                Text("NOPE")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(EquestrianTheme.nopeRed)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(EquestrianTheme.nopeRed, lineWidth: 4)
                    )
                    .rotationEffect(.degrees(14))
                    .opacity(min(1.0, Double(-dragOffset.width - 20) / 85.0))
                    .padding(.trailing, 22)
                    .padding(.top, 44)
            }
        }
    }
}

/// Backwards-compatible wrapper used by detail previews.
public struct HorseDiscoveryCardView: View {
    public let horse: HorseProfileDTO

    public init(horse: HorseProfileDTO) {
        self.horse = horse
    }

    public var body: some View {
        TinderHorseCardView(horse: horse)
            .frame(height: 420)
    }
}

public struct MatchCelebrationOverlay: View {
    public let match: MatchDTO
    public let onDismiss: () -> Void
    @State private var animateHearts = false

    public init(match: MatchDTO, onDismiss: @escaping () -> Void) {
        self.match = match
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.92),
                    EquestrianTheme.deepCrimson.opacity(0.94),
                    Color.black.opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("IT'S A")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .tracking(5)
                        .foregroundStyle(.white.opacity(0.85))

                    Text("MATCH!")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(red: 1.0, green: 0.78, blue: 0.84)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .accessibilityIdentifier("itsAMatchTitle")
                }

                Text("\(match.horseA.name) and \(match.horseB.name) liked each other")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))

                // Overlapping Horse Avatars with Glowing Heart
                ZStack {
                    HorsePhotoView(
                        horseName: match.horseA.name,
                        photoURL: match.horseA.photos.first?.url,
                        photoIndex: 0
                    )
                    .frame(width: 126, height: 126)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .shadow(color: .black.opacity(0.35), radius: 12)
                    .offset(x: animateHearts ? -46 : -20)
                    .rotationEffect(.degrees(animateHearts ? -6 : 0))

                    HorsePhotoView(
                        horseName: match.horseB.name,
                        photoURL: match.horseB.photos.first?.url,
                        photoIndex: 0
                    )
                    .frame(width: 126, height: 126)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .shadow(color: .black.opacity(0.35), radius: 12)
                    .offset(x: animateHearts ? 46 : 20)
                    .rotationEffect(.degrees(animateHearts ? 6 : 0))

                    Circle()
                        .fill(EquestrianTheme.brandGradient)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "heart.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        .shadow(color: EquestrianTheme.tinderRed.opacity(0.6), radius: 10)
                        .scaleEffect(animateHearts ? 1.08 : 0.8)
                }
                .padding(.vertical, 10)

                VStack(spacing: 12) {
                    Button {
                        onDismiss()
                    } label: {
                        Text("KEEP SWIPING")
                            .font(.subheadline.weight(.heavy))
                            .tracking(1)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Capsule().fill(EquestrianTheme.brandGradient))
                            .shadow(color: EquestrianTheme.tinderRed.opacity(0.45), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("dismissMatchOverlayButton")
                }
                .padding(.horizontal, 28)
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                animateHearts = true
            }
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
                            .foregroundStyle(EquestrianTheme.charcoalText)
                        HStack(spacing: 8) {
                            ForEach(horse.temperamentTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(EquestrianTheme.softRoseTint))
                                    .foregroundStyle(EquestrianTheme.tinderRed)
                            }
                        }
                    }
                }

                if let health = horse.healthInfo {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Health & Veterinary Records")
                            .font(.headline)
                            .foregroundStyle(EquestrianTheme.charcoalText)
                        if let vaccinations = health.vaccinationsUpToDate {
                            Label(
                                vaccinations ? "Vaccinations Up to Date" : "Vaccinations Pending",
                                systemImage: vaccinations ? "checkmark.seal.fill" : "clock"
                            )
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(vaccinations ? EquestrianTheme.likeGreen : .secondary)
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
                            .foregroundStyle(EquestrianTheme.charcoalText)
                        Text(pedigree)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                AnimalWelfareNoticeBanner()

                if let statusBanner {
                    Text(statusBanner)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(EquestrianTheme.likeGreen)
                }

                Divider()

                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        showReportDialog = true
                    } label: {
                        Label("Report Profile", systemImage: "flag.fill")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(EquestrianTheme.nopeRed)

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
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(EquestrianTheme.nopeRed)
                }
            }
            .padding(16)
        }
        .background(Color.white)
        .navigationTitle(horse.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(EquestrianTheme.tinderRed)
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
                        Button("Submit") {
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Maximum Distance")
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text("\(Int(viewModel.maxDistanceKm)) km")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(EquestrianTheme.tinderRed)
                    }
                    Slider(value: $viewModel.maxDistanceKm, in: 10...500, step: 10)
                        .tint(EquestrianTheme.tinderRed)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))

                VStack(alignment: .leading, spacing: 14) {
                    Text("Horse Preferences")
                        .font(.subheadline.weight(.bold))

                    TextField("Breed (e.g. Andalusian, Hanoverian)", text: $viewModel.filterBreed)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Text("Sex")
                            .font(.subheadline)
                        Spacer()
                        Picker("Sex", selection: $viewModel.filterSex) {
                            Text("Any").tag(HorseSex?.none)
                            ForEach(HorseSex.allCases, id: \.self) { sex in
                                Text(sex.displayName).tag(HorseSex?.some(sex))
                            }
                        }
                    }

                    HStack {
                        Text("Discipline")
                            .font(.subheadline)
                        Spacer()
                        Picker("Discipline", selection: $viewModel.filterDiscipline) {
                            Text("Any").tag(HorseDiscipline?.none)
                            ForEach(HorseDiscipline.allCases, id: \.self) { disc in
                                Text(disc.displayName).tag(HorseDiscipline?.some(disc))
                            }
                        }
                    }

                    HStack {
                        Text("Looking For")
                            .font(.subheadline)
                        Spacer()
                        Picker("Looking For", selection: $viewModel.filterLookingFor) {
                            Text("Any").tag(LookingForCategory?.none)
                            ForEach(LookingForCategory.allCases, id: \.self) { goal in
                                Text(goal.displayName).tag(LookingForCategory?.some(goal))
                            }
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))

                Button {
                    Task {
                        await viewModel.loadCards(activeHorseID: activeHorseID, reset: true)
                        dismiss()
                    }
                } label: {
                    Text("Apply Filters")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(EquestrianTheme.brandGradient))
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await viewModel.resetFilters(activeHorseID: activeHorseID)
                        dismiss()
                    }
                } label: {
                    Text("Reset All Filters")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EquestrianTheme.tinderRed)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
        }
        .background(EquestrianTheme.screenBackground)
        .navigationTitle("Discovery Settings")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }
}

struct DiscoverScreen_Previews: PreviewProvider {
    static var previews: some View {
        let client = MockAPIClient()
        let appState = AppStateViewModel(
            apiClient: client,
            preauthenticatedUser: MockSampleData.currentUser,
            initialHorses: [MockSampleData.myHorse]
        )
        let discoverVM = DiscoverViewModel(apiClient: client)
        DiscoverScreen(appState: appState, viewModel: discoverVM)
    }
}
