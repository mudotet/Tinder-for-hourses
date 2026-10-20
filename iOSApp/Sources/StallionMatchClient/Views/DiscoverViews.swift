import SharedModels
import SwiftUI

public struct DiscoverScreen: View {
    @Bindable public var appState: AppStateViewModel
    @Bindable public var viewModel: DiscoverViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragOffset: CGSize = .zero
    @State private var dragPivotSign: Double = 1.0
    @State private var photoIndexByHorse: [UUID: Int] = [:]
    @State private var swipedHistory: [HorseProfileDTO] = []
    @State private var isAnimatingOut = false
    @State private var actionBurstSymbol: (icon: String, color: Color)?
    @State private var superLikedBannerHorse: String?
    @State private var selectedHorseForDetail: HorseProfileDTO?
    @State private var showFilterSheet = false
    @State private var showCreateHorseSheet = false

    public init(appState: AppStateViewModel, viewModel: DiscoverViewModel) {
        self.appState = appState
        self.viewModel = viewModel
    }

    private var dragProgress: CGFloat {
        min(1.0, abs(dragOffset.width) / 130.0)
    }

    public var body: some View {
        ZStack {
            EquestrianTheme.screenBackground
                .ignoresSafeArea()

            VStack(spacing: 10) {
                mobileTopHeaderBar

                if viewModel.state == .loaded, let topCard = viewModel.cards.first {
                    ZStack {
                        ForEach(Array(viewModel.cards.prefix(3).enumerated().reversed()), id: \.element.id) { index, horse in
                            let isTop = (index == 0)
                            let isSecond = (index == 1)
                            let currentPhotoIndex = photoIndexByHorse[horse.id, default: 0]

                            let cardScale: CGFloat = isTop
                                ? 1.0
                                : (isSecond ? (0.94 + 0.06 * dragProgress) : 0.89)
                            let cardYOffset: CGFloat = isTop
                                ? dragOffset.height * 0.25
                                : (isSecond ? (14.0 * (1.0 - dragProgress)) : 24.0)

                            TinderHorseCardView(
                                horse: horse,
                                photoIndex: currentPhotoIndex,
                                dragOffset: isTop ? dragOffset : .zero,
                                onStepPhoto: { delta in
                                    let count = max(4, horse.photos.count)
                                    let next = (currentPhotoIndex + delta + count) % count
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                        photoIndexByHorse[horse.id] = next
                                    }
                                },
                                onOpenDetails: {
                                    selectedHorseForDetail = horse
                                }
                            )
                            .scaleEffect(cardScale)
                            .offset(
                                x: isTop ? dragOffset.width : 0,
                                y: cardYOffset
                            )
                            .rotationEffect(
                                .degrees(
                                    isTop && !reduceMotion
                                        ? Double(dragOffset.width / 15.0) * dragPivotSign
                                        : 0
                                )
                            )
                            .animation(.interactiveSpring(response: 0.30, dampingFraction: 0.78), value: viewModel.cards.map(\.id))
                            .gesture(
                                DragGesture(minimumDistance: 4)
                                    .onChanged { value in
                                        guard isTop && !isAnimatingOut else { return }
                                        if dragOffset == .zero {
                                            dragPivotSign = (value.startLocation.y < 260) ? 1.0 : -1.0
                                        }
                                        dragOffset = value.translation
                                    }
                                    .onEnded { value in
                                        guard isTop && !isAnimatingOut else { return }
                                        handleDragEnded(value: value, horse: horse)
                                    }
                            )
                        }

                        // Center Action Burst Animation (Like / Nope / Super Like)
                        if let burst = actionBurstSymbol {
                            Circle()
                                .fill(Color.white.opacity(0.92))
                                .frame(width: 96, height: 96)
                                .overlay(
                                    Image(systemName: burst.icon)
                                        .font(.system(size: 46, weight: .black))
                                        .foregroundStyle(burst.color)
                                )
                                .shadow(color: burst.color.opacity(0.45), radius: 20)
                                .transition(.scale(scale: 0.3).combined(with: .opacity))
                                .zIndex(10)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                        Text("SUPER LIKED \(superLikedName.uppercased())!")
                            .font(.caption.weight(.heavy))
                            .tracking(1)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(EquestrianTheme.charcoalText.opacity(0.92)))
                    .shadow(radius: 10)
                    .padding(.top, 60)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let match = viewModel.celebratedMatch {
                MatchCelebrationOverlay(
                    match: match,
                    onSendInstantMessage: { text in
                        guard let myHorse = appState.activeHorse else { return }
                        Task {
                            await viewModel.sendInstantMatchMessage(match: match, body: text, myHorse: myHorse)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                viewModel.celebratedMatch = nil
                            }
                        }
                    },
                    onDismiss: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            viewModel.celebratedMatch = nil
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.90)))
                .zIndex(30)
            }
        }
        .sheet(item: $selectedHorseForDetail) { horse in
            NavigationStack {
                HorseDetailSheet(
                    horse: horse,
                    apiClient: appState.apiClient,
                    onSwipeDecision: { direction in
                        selectedHorseForDetail = nil
                        Task {
                            try? await Task.sleep(nanoseconds: 220_000_000)
                            animateAndSwipe(direction, for: horse)
                        }
                    },
                    onModerationAction: {
                        Task {
                            await viewModel.loadCards(activeHorseID: appState.activeHorse?.id, reset: true)
                        }
                    }
                )
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
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(EquestrianTheme.brandGradient)
                Text("stallion")
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .foregroundStyle(EquestrianTheme.brandGradient)
            }

            Spacer()

            // Deck Counter Pill
            if !viewModel.cards.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(EquestrianTheme.tinderRed)
                    Text("\(viewModel.cards.count) nearby")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(EquestrianTheme.slateSecondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(EquestrianTheme.softRoseTint))
            }

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
                withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
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

            // NOPE / Pass Button
            Button {
                triggerBurst(icon: "xmark", color: EquestrianTheme.nopeRed)
                animateAndSwipe(.pass, for: topCard)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(EquestrianTheme.nopeRed)
                    .frame(width: 62, height: 62)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .shadow(color: EquestrianTheme.nopeRed.opacity(0.24), radius: 12, x: 0, y: 5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("passHorseButton")
            .accessibilityLabel("Pass on \(topCard.name)")

            // SUPER LIKE Button
            Button {
                triggerBurst(icon: "star.fill", color: EquestrianTheme.superLikeBlue)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    superLikedBannerHorse = topCard.name
                }
                Task {
                    try? await Task.sleep(nanoseconds: 1_400_000_000)
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
                            .shadow(color: EquestrianTheme.superLikeBlue.opacity(0.28), radius: 10, x: 0, y: 4)
                    )
            }
            .buttonStyle(.plain)

            // LIKE Button (Tinder Red Heart)
            Button {
                triggerBurst(icon: "heart.fill", color: EquestrianTheme.tinderRed)
                animateAndSwipe(.like, for: topCard)
            } label: {
                Image(systemName: "heart.fill")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(
                        Circle()
                            .fill(EquestrianTheme.brandGradient)
                            .shadow(color: EquestrianTheme.tinderRed.opacity(0.40), radius: 12, x: 0, y: 5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("likeHorseButton")
            .accessibilityLabel("Like \(topCard.name)")

            // Info / Lifestyle & Photos Button
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

    private func triggerBurst(icon: String, color: Color) {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.65)) {
            actionBurstSymbol = (icon, color)
        }
        Task {
            try? await Task.sleep(nanoseconds: 230_000_000)
            withAnimation(.easeOut(duration: 0.15)) {
                actionBurstSymbol = nil
            }
        }
    }

    private func handleDragEnded(value: DragGesture.Value, horse: HorseProfileDTO) {
        let predictedWidth = value.predictedEndTranslation.width
        let threshold: CGFloat = 90
        if value.translation.width > threshold || predictedWidth > 180 {
            triggerBurst(icon: "heart.fill", color: EquestrianTheme.tinderRed)
            animateAndSwipe(.like, for: horse)
        } else if value.translation.width < -threshold || predictedWidth < -180 {
            triggerBurst(icon: "xmark", color: EquestrianTheme.nopeRed)
            animateAndSwipe(.pass, for: horse)
        } else {
            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.70)) {
                dragOffset = .zero
            }
        }
    }

    private func animateAndSwipe(_ direction: SwipeDirection, for horse: HorseProfileDTO) {
        guard let activeHorseID = appState.activeHorse?.id, !isAnimatingOut else { return }
        isAnimatingOut = true
        swipedHistory.append(horse)

        let flyOutX: CGFloat = (direction == .like) ? 480 : -480
        withAnimation(.interpolatingSpring(stiffness: 240, damping: 22)) {
            dragOffset = CGSize(width: flyOutX, height: 36)
        }

        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            dragOffset = .zero
            isAnimatingOut = false
            await viewModel.swipe(on: horse, direction: direction, activeHorseID: activeHorseID)
        }
    }
}

/// Full-bleed Tinder photo card with story bars, photo caption tag, LIKE/NOPE stamps, and rich overlay metadata.
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

    private var lifestyle: HorseLifestyleProfile {
        HorseLifestyleProfile.forHorse(horse)
    }

    private var photoCount: Int {
        max(4, horse.photos.count)
    }

    private var currentPhotoURL: String? {
        guard !horse.photos.isEmpty else { return nil }
        return horse.photos[photoIndex % horse.photos.count].url
    }

    private var currentPhotoBadgeAndCaption: (badge: String, caption: String) {
        let captions = lifestyle.galleryCaptions
        guard !captions.isEmpty else { return ("Portrait", horse.location.city) }
        return captions[photoIndex % captions.count]
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                HorsePhotoView(
                    horseName: horse.name,
                    photoURL: currentPhotoURL,
                    photoIndex: photoIndex
                )
                .frame(width: geo.size.width, height: geo.size.height)
                .id("\(horse.id)-\(photoIndex)")
                .transition(.opacity)

                // Left / Right Invisible Photo Tap Zones (Tinder Story Navigation)
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onStepPhoto(-1) }
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onStepPhoto(1) }
                }

                // Top Story Progress Bars & Photo Lifestyle Tag
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 5) {
                        ForEach(0..<photoCount, id: \.self) { idx in
                            Capsule()
                                .fill(idx == (photoIndex % photoCount) ? Color.white : Color.white.opacity(0.35))
                                .frame(height: 3.5)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.Macro")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(EquestrianTheme.tinderRed)
                            Text(currentPhotoBadgeAndCaption.badge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.black.opacity(0.52)))

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

                swipeOverlayStamps
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // Bottom Gradient Scrim + Horse Info Panel
                VStack(alignment: .leading, spacing: 7) {
                    // Photo Caption Pill
                    Text("📸 \(currentPhotoBadgeAndCaption.caption)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.18)))

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
                            HStack(spacing: 4) {
                                Text("More")
                                    .font(.caption2.weight(.bold))
                                Image(systemName: "chevron.up.circle.fill")
                                    .font(.system(size: 20))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(EquestrianTheme.tinderRed.opacity(0.85)))
                        }
                        .buttonStyle(.plain)
                    }

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

                    Text(horse.bio)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(2)

                    // Lifestyle & Discipline Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            if let hobby = lifestyle.badges.first {
                                HStack(spacing: 4) {
                                    Image(systemName: hobby.icon)
                                        .font(.system(size: 10))
                                    Text(hobby.label)
                                        .font(.caption2.weight(.bold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(EquestrianTheme.tinderRed.opacity(0.85)))
                                .foregroundStyle(.white)
                            }
                            ForEach(horse.disciplines, id: \.self) { disc in
                                Text(disc.displayName)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(.white.opacity(0.22)))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
                .padding(18)
                .padding(.top, 44)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.58), .black.opacity(0.90)],
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
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(EquestrianTheme.likeGreen)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(EquestrianTheme.likeGreen, lineWidth: 4)
                    )
                    .rotationEffect(.degrees(-14))
                    .opacity(min(1.0, Double(dragOffset.width - 20) / 80.0))
                    .scaleEffect(min(1.1, 0.85 + Double(dragOffset.width) / 400.0))
                    .padding(.leading, 22)
                    .padding(.top, 52)
            }

            Spacer()

            if dragOffset.width < -20 {
                Text("NOPE")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(EquestrianTheme.nopeRed)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(EquestrianTheme.nopeRed, lineWidth: 4)
                    )
                    .rotationEffect(.degrees(14))
                    .opacity(min(1.0, Double(-dragOffset.width - 20) / 80.0))
                    .scaleEffect(min(1.1, 0.85 + Double(-dragOffset.width) / 400.0))
                    .padding(.trailing, 22)
                    .padding(.top, 52)
            }
        }
    }
}

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
    public var onSendInstantMessage: (String) -> Void
    public let onDismiss: () -> Void
    @State private var animateHearts = false
    @State private var pulseRing = false
    @State private var quickMessageText = ""

    public init(
        match: MatchDTO,
        onSendInstantMessage: @escaping (String) -> Void = { _ in },
        onDismiss: @escaping () -> Void
    ) {
        self.match = match
        self.onSendInstantMessage = onSendInstantMessage
        self.onDismiss = onDismiss
    }

    private var aiOpeningPreview: String {
        AIEquestrianPersonaEngine.openingIcebreaker(from: match.horseB, to: match.horseA)
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.94),
                    EquestrianTheme.deepCrimson.opacity(0.95),
                    Color.black.opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(spacing: 4) {
                    Text("IT'S A")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .tracking(5)
                        .foregroundStyle(.white.opacity(0.85))

                    Text("MATCH!")
                        .font(.system(size: 46, weight: .black, design: .rounded))
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

                Text("\(match.horseA.name) & \(match.horseB.name) liked each other!")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))

                // Overlapping Horse Avatars with Pulsing Ring & Heart
                ZStack {
                    Circle()
                        .stroke(EquestrianTheme.tinderRed.opacity(0.45), lineWidth: 3)
                        .frame(width: pulseRing ? 240 : 170, height: pulseRing ? 240 : 170)
                        .opacity(pulseRing ? 0.0 : 0.8)

                    HorsePhotoView(
                        horseName: match.horseA.name,
                        photoURL: match.horseA.photos.first?.url,
                        photoIndex: 0
                    )
                    .frame(width: 118, height: 118)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .shadow(color: .black.opacity(0.35), radius: 12)
                    .offset(x: animateHearts ? -46 : -16)
                    .rotationEffect(.degrees(animateHearts ? -6 : 0))

                    HorsePhotoView(
                        horseName: match.horseB.name,
                        photoURL: match.horseB.photos.first?.url,
                        photoIndex: 0
                    )
                    .frame(width: 118, height: 118)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .shadow(color: .black.opacity(0.35), radius: 12)
                    .offset(x: animateHearts ? 46 : 16)
                    .rotationEffect(.degrees(animateHearts ? 6 : 0))

                    Circle()
                        .fill(EquestrianTheme.brandGradient)
                        .frame(width: 46, height: 46)
                        .overlay(
                            Image(systemName: "heart.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        .shadow(color: EquestrianTheme.tinderRed.opacity(0.6), radius: 10)
                        .scaleEffect(animateHearts ? 1.1 : 0.7)
                }
                .padding(.vertical, 6)

                // AI Instant Icebreaker Received Card
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(EquestrianTheme.rewindGold)
                        Text("\(match.horseB.name) sent you an AI icebreaker:")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Text(aiOpeningPreview)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .lineLimit(3)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white.opacity(0.14))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.22), lineWidth: 1))
                )
                .padding(.horizontal, 18)

                // Instant Reply Input Bar (Tinder Style)
                HStack(spacing: 8) {
                    TextField("Say something to \(match.horseB.name)...", text: $quickMessageText)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)

                    Button {
                        let text = quickMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSendInstantMessage(text.isEmpty ? "Hey \(match.horseB.name)! Let's go for a Saturday trail ride! 🐎✨" : text)
                    } label: {
                        Text("SEND")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(EquestrianTheme.brandGradient))
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
                .background(
                    Capsule()
                        .fill(.white.opacity(0.16))
                        .overlay(Capsule().stroke(.white.opacity(0.32), lineWidth: 1))
                )
                .padding(.horizontal, 18)

                // Quick Emoji Reactions
                HStack(spacing: 14) {
                    ForEach(["👋 Hey!", "🍎 Brought apples!", "🌲 Trail ride?", "🥕 Carrots!"], id: \.self) { chip in
                        Button {
                            onSendInstantMessage("\(chip) \(match.horseA.name) would love to meet \(match.horseB.name)!")
                        } label: {
                            Text(chip)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(.white.opacity(0.18)))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    onDismiss()
                } label: {
                    Text("KEEP SWIPING")
                        .font(.caption.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dismissMatchOverlayButton")
            }
            .padding(20)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                animateHearts = true
            }
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulseRing = true
            }
        }
    }
}

/// Comprehensive Tinder-style Horse Information, Lifestyle, Hobby & Multi-Photo Showcase Sheet.
public struct HorseDetailSheet: View {
    public let horse: HorseProfileDTO
    public let apiClient: any APIClientProtocol
    public var onSwipeDecision: ((SwipeDirection) -> Void)?
    public let onModerationAction: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotoIndex = 0
    @State private var showReportDialog = false
    @State private var selectedReportReason: ReportReason = .inappropriateContent
    @State private var reportDetails = ""
    @State private var statusBanner: String?

    public init(
        horse: HorseProfileDTO,
        apiClient: any APIClientProtocol,
        onSwipeDecision: ((SwipeDirection) -> Void)? = nil,
        onModerationAction: @escaping () -> Void
    ) {
        self.horse = horse
        self.apiClient = apiClient
        self.onSwipeDecision = onSwipeDecision
        self.onModerationAction = onModerationAction
    }

    private var lifestyle: HorseLifestyleProfile {
        HorseLifestyleProfile.forHorse(horse)
    }

    private let badgeColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    public var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 1. Interactive Multi-Photo Hero Gallery + Thumbnail Strip
                    VStack(spacing: 10) {
                        ZStack(alignment: .bottomLeading) {
                            HorsePhotoView(
                                horseName: horse.name,
                                photoURL: horse.photos.isEmpty ? nil : horse.photos[selectedPhotoIndex % horse.photos.count].url,
                                photoIndex: selectedPhotoIndex
                            )
                            .frame(height: 360)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .id(selectedPhotoIndex)

                            LinearGradient(
                                colors: [.clear, .black.opacity(0.80)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                let info = lifestyle.galleryCaptions[selectedPhotoIndex % lifestyle.galleryCaptions.count]
                                Text(info.badge.uppercased())
                                    .font(.system(size: 10, weight: .heavy))
                                    .tracking(1)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(EquestrianTheme.brandGradient))
                                    .foregroundStyle(.white)

                                Text("\(horse.name), \(horse.age)")
                                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)

                                Text(info.caption)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .padding(18)
                        }

                        // 4-Photo Lifestyle Thumbnail Selector
                        HStack(spacing: 10) {
                            ForEach(0..<4, id: \.self) { idx in
                                let isSelected = (selectedPhotoIndex == idx)
                                Button {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                        selectedPhotoIndex = idx
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        HorsePhotoView(
                                            horseName: horse.name,
                                            photoURL: idx < horse.photos.count ? horse.photos[idx].url : nil,
                                            photoIndex: idx
                                        )
                                        .frame(height: 64)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    isSelected ? EquestrianTheme.tinderRed : Color.clear,
                                                    lineWidth: 2.5
                                                )
                                        )

                                        Text(lifestyle.galleryCaptions[idx % lifestyle.galleryCaptions.count].badge)
                                            .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                                            .foregroundStyle(isSelected ? EquestrianTheme.tinderRed : EquestrianTheme.slateSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 2. Owner / Handler & Verified Barn Card
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(EquestrianTheme.softRoseTint)
                                .frame(width: 46, height: 46)
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                                .foregroundStyle(EquestrianTheme.tinderRed)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Handler: \(lifestyle.handlerName)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(EquestrianTheme.charcoalText)
                            Text("\(lifestyle.handlerTitle) • \(lifestyle.verifiedBarnName)")
                                .font(.caption)
                                .foregroundStyle(EquestrianTheme.slateSecondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                    )

                    // 3. About & Essentials Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ABOUT \(horse.name.uppercased())")
                            .font(.caption.weight(.heavy))
                            .tracking(1)
                            .foregroundStyle(EquestrianTheme.tinderRed)

                        Text(horse.bio)
                            .font(.subheadline)
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
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                    )

                    // 4. Lifestyle & Hobbies Grid (6 Categories)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(EquestrianTheme.tinderRed)
                            Text("LIFESTYLE, HOBBIES & FAVORITES")
                                .font(.caption.weight(.heavy))
                                .tracking(1)
                                .foregroundStyle(EquestrianTheme.tinderRed)
                        }

                        LazyVGrid(columns: badgeColumns, spacing: 10) {
                            ForEach(lifestyle.badges) { badge in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: badge.icon)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(EquestrianTheme.tinderRed)
                                        .frame(width: 24, height: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(badge.category.uppercased())
                                            .font(.system(size: 9, weight: .heavy))
                                            .foregroundStyle(EquestrianTheme.slateSecondary)
                                        Text(badge.label)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(EquestrianTheme.charcoalText)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white)
                                        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
                                )
                            }
                        }
                    }

                    // 5. Personality Prompts (Tinder/Hinge Style)
                    ForEach(lifestyle.prompts) { prompt in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: prompt.icon)
                                    .foregroundStyle(EquestrianTheme.tinderRed)
                                Text(prompt.promptTitle)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(EquestrianTheme.slateSecondary)
                            }
                            Text("“\(prompt.answer)”")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(EquestrianTheme.charcoalText)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(EquestrianTheme.softRoseTint)
                        )
                    }

                    // 6. Full Moments & Lifestyle Photo Stream
                    VStack(alignment: .leading, spacing: 14) {
                        Text("\(horse.name.uppercased())'S LIFESTYLE & HOBBY ALBUM")
                            .font(.caption.weight(.heavy))
                            .tracking(1)
                            .foregroundStyle(EquestrianTheme.tinderRed)

                        ForEach(1..<4, id: \.self) { idx in
                            let captionInfo = lifestyle.galleryCaptions[idx % lifestyle.galleryCaptions.count]
                            ZStack(alignment: .bottomLeading) {
                                HorsePhotoView(
                                    horseName: horse.name,
                                    photoURL: idx < horse.photos.count ? horse.photos[idx].url : nil,
                                    photoIndex: idx
                                )
                                .frame(height: 260)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.78)],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(captionInfo.badge.uppercased())
                                        .font(.system(size: 9, weight: .heavy))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(EquestrianTheme.brandGradient))
                                        .foregroundStyle(.white)
                                    Text(captionInfo.caption)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                                .padding(14)
                            }
                        }
                    }

                    // 7. Health & Pedigree Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("VETERINARY & PEDIGREE")
                            .font(.caption.weight(.heavy))
                            .tracking(1)
                            .foregroundStyle(EquestrianTheme.tinderRed)

                        if let health = horse.healthInfo {
                            if let vaccinations = health.vaccinationsUpToDate {
                                Label(
                                    vaccinations ? "Vaccinations & Coggins Verified Up to Date" : "Vaccinations Pending",
                                    systemImage: vaccinations ? "checkmark.seal.fill" : "clock"
                                )
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(vaccinations ? EquestrianTheme.likeGreen : .secondary)
                            }
                        }
                        if let pedigree = horse.pedigree, !pedigree.isEmpty {
                            Text("Pedigree: \(pedigree)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(EquestrianTheme.slateSecondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))

                    AnimalWelfareNoticeBanner()

                    if let statusBanner {
                        Text(statusBanner)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(EquestrianTheme.likeGreen)
                    }

                    // Safety Actions
                    HStack(spacing: 12) {
                        Button(role: .destructive) {
                            showReportDialog = true
                        } label: {
                            Label("Report \(horse.name)", systemImage: "flag.fill")
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
                    .padding(.bottom, onSwipeDecision != nil ? 84 : 16)
                }
                .padding(16)
            }
            .background(EquestrianTheme.screenBackground)

            // Floating Tinder Bottom Swipe Bar inside Detail View
            if let onSwipeDecision {
                HStack(spacing: 24) {
                    Button {
                        onSwipeDecision(.pass)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(EquestrianTheme.nopeRed)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Color.white).shadow(radius: 8))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onSwipeDecision(.like)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                            Text("LIKE \(horse.name.uppercased())")
                                .fontWeight(.heavy)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(EquestrianTheme.brandGradient).shadow(color: EquestrianTheme.tinderRed.opacity(0.4), radius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [EquestrianTheme.screenBackground.opacity(0.0), EquestrianTheme.screenBackground],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .navigationTitle("\(horse.name)'s Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Close") { dismiss() }
                    .fontWeight(.bold)
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

                    TextField("Breed (e.g. Andalusian, Holsteiner)", text: $viewModel.filterBreed)
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
