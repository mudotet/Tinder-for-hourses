import PhotosUI
import SharedModels
import SwiftUI

public struct ProfileAndSettingsScreen: View {
    @Bindable public var appState: AppStateViewModel
    @State private var horseBeingEdited: HorseProfileDTO?
    @State private var showCreateHorseSheet = false
    @State private var showTermsSheet = false
    @State private var showPrivacySheet = false
    @State private var showDeleteConfirmation = false

    public init(appState: AppStateViewModel) {
        self.appState = appState
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Tinder-style Profile Hero Card
                    VStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            HorsePhotoView(
                                horseName: appState.activeHorse?.name ?? "Apollo",
                                photoURL: appState.activeHorse?.photos.first?.url,
                                photoIndex: 0
                            )
                            .frame(width: 112, height: 112)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(EquestrianTheme.brandGradient, lineWidth: 4)
                            )
                            .shadow(color: EquestrianTheme.tinderRed.opacity(0.28), radius: 12, x: 0, y: 6)

                            if let active = appState.activeHorse {
                                Button {
                                    horseBeingEdited = active
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 32, height: 32)
                                        .background(Circle().fill(EquestrianTheme.brandGradient))
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let active = appState.activeHorse {
                            Text("\(active.name), \(active.age)")
                                .font(.title2.weight(.heavy))
                                .foregroundStyle(EquestrianTheme.charcoalText)
                            Text("\(active.breed) • \(active.location.city)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(EquestrianTheme.slateSecondary)
                        }

                        if let user = appState.currentUser {
                            HStack(spacing: 6) {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                    .foregroundStyle(EquestrianTheme.tinderRed)
                                Text("Handler: \(user.displayName ?? "Horse Owner") (\(user.email))")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(EquestrianTheme.slateSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(EquestrianTheme.softRoseTint))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                    )

                    // My Horses Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("MY HORSES")
                                .font(.caption.weight(.heavy))
                                .tracking(1)
                                .foregroundStyle(EquestrianTheme.tinderRed)
                            Spacer()
                            Button {
                                showCreateHorseSheet = true
                            } label: {
                                Label("Add Horse", systemImage: "plus")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(EquestrianTheme.brandGradient))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("addHorseProfileButton")
                        }

                        ForEach(appState.myHorses) { horse in
                            let isActive = (appState.activeHorse?.id == horse.id)
                            HStack(spacing: 12) {
                                HorsePhotoView(
                                    horseName: horse.name,
                                    photoURL: horse.photos.first?.url,
                                    photoIndex: 0
                                )
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(
                                        isActive ? EquestrianTheme.tinderRed : Color.clear,
                                        lineWidth: 2.5
                                    )
                                )

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(horse.name)
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(EquestrianTheme.charcoalText)
                                        if isActive {
                                            Text("ACTIVE")
                                                .font(.system(size: 9, weight: .heavy))
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 3)
                                                .background(Capsule().fill(EquestrianTheme.brandGradient))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    Text("\(horse.age)yo \(horse.breed) \(horse.sex.displayName) • \(horse.location.city)")
                                        .font(.caption)
                                        .foregroundStyle(EquestrianTheme.slateSecondary)
                                }

                                Spacer()

                                if !isActive {
                                    Button("Use") {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            appState.activeHorseID = horse.id
                                        }
                                    }
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(EquestrianTheme.tinderRed)
                                    .buttonStyle(.plain)
                                }

                                Button("Edit") {
                                    horseBeingEdited = horse
                                }
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(EquestrianTheme.softRoseTint))
                                .foregroundStyle(EquestrianTheme.tinderRed)
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                            )
                        }
                    }

                    // Push Notifications Card
                    if let user = appState.currentUser {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("NOTIFICATIONS")
                                .font(.caption.weight(.heavy))
                                .tracking(1)
                                .foregroundStyle(EquestrianTheme.tinderRed)

                            VStack(spacing: 12) {
                                Toggle(
                                    "New Matches",
                                    isOn: Binding(
                                        get: { user.notificationsNewMatch },
                                        set: { newVal in
                                            Task {
                                                await appState.updateNotificationSettings(
                                                    newMatch: newVal,
                                                    newMessage: user.notificationsNewMessage
                                                )
                                            }
                                        }
                                    )
                                )
                                .tint(EquestrianTheme.tinderRed)

                                Divider()

                                Toggle(
                                    "New Messages",
                                    isOn: Binding(
                                        get: { user.notificationsNewMessage },
                                        set: { newVal in
                                            Task {
                                                await appState.updateNotificationSettings(
                                                    newMatch: user.notificationsNewMatch,
                                                    newMessage: newVal
                                                )
                                            }
                                        }
                                    )
                                )
                                .tint(EquestrianTheme.tinderRed)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                            )
                        }
                    }

                    // Legal & Safety Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SAFETY & LEGAL")
                            .font(.caption.weight(.heavy))
                            .tracking(1)
                            .foregroundStyle(EquestrianTheme.tinderRed)

                        HStack(spacing: 12) {
                            Button {
                                showTermsSheet = true
                            } label: {
                                Label("Terms of Use", systemImage: "doc.text.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(EquestrianTheme.charcoalText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                            }
                            .buttonStyle(.plain)

                            Button {
                                showPrivacySheet = true
                            } label: {
                                Label("Privacy Policy", systemImage: "hand.raised.shield.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(EquestrianTheme.charcoalText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                            }
                            .buttonStyle(.plain)
                        }

                        AnimalWelfareNoticeBanner()
                    }

                    // Account Actions
                    VStack(spacing: 10) {
                        Button {
                            Task { await appState.logout() }
                        } label: {
                            Text("Sign Out / Open Auth Screen")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(EquestrianTheme.tinderRed)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(
                                    Capsule()
                                        .fill(Color.white)
                                        .overlay(Capsule().stroke(EquestrianTheme.tinderRed.opacity(0.35), lineWidth: 1.5))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("logOutButton")

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Delete Account & All Data")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(EquestrianTheme.slateSecondary)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("deleteAccountButton")
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
            .background(EquestrianTheme.screenBackground)
            .sheet(isPresented: $showCreateHorseSheet) {
                NavigationStack {
                    HorseEditorSheet(appState: appState, existingHorse: nil) {}
                }
            }
            .sheet(item: $horseBeingEdited) { horse in
                NavigationStack {
                    HorseEditorSheet(appState: appState, existingHorse: horse) {}
                }
            }
            .sheet(isPresented: $showTermsSheet) {
                NavigationStack { TermsOfUseView() }
            }
            .sheet(isPresented: $showPrivacySheet) {
                NavigationStack { PrivacyPolicyView() }
            }
            .confirmationDialog(
                "Permanently delete your account?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account & All Data", role: .destructive) {
                    Task { try? await appState.deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account, all horse profiles, uploaded photos, matches, and messages.")
            }
        }
    }
}

public struct HorseEditorSheet: View {
    @Bindable public var appState: AppStateViewModel
    public let existingHorse: HorseProfileDTO?
    public let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var age: Int
    @State private var sex: HorseSex
    @State private var breed: String
    @State private var color: String
    @State private var heightHands: Double
    @State private var selectedDisciplines: Set<HorseDiscipline>
    @State private var selectedLookingFor: Set<LookingForCategory>
    @State private var temperamentText: String
    @State private var bio: String
    @State private var city: String
    @State private var coarseLatitude: Double
    @State private var coarseLongitude: Double
    @State private var vaccinationsUpToDate: Bool
    @State private var includeCogginsDate: Bool
    @State private var cogginsDate: Date
    @State private var pedigree: String
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var validationMessage: String?
    @State private var isSaving = false

    public init(
        appState: AppStateViewModel,
        existingHorse: HorseProfileDTO?,
        onSaved: @escaping () -> Void
    ) {
        self.appState = appState
        self.existingHorse = existingHorse
        self.onSaved = onSaved

        _name = State(initialValue: existingHorse?.name ?? "")
        _age = State(initialValue: existingHorse?.age ?? 6)
        _sex = State(initialValue: existingHorse?.sex ?? .mare)
        _breed = State(initialValue: existingHorse?.breed ?? "Warmblood")
        _color = State(initialValue: existingHorse?.color ?? "Bay")
        _heightHands = State(initialValue: existingHorse?.heightHands ?? 16.0)
        _selectedDisciplines = State(initialValue: Set(existingHorse?.disciplines ?? [.trail, .dressage]))
        _selectedLookingFor = State(initialValue: Set(existingHorse?.lookingFor ?? [.trailBuddy, .ridingCompanion]))
        _temperamentText = State(initialValue: existingHorse?.temperamentTags.joined(separator: ", ") ?? "Calm, Friendly")
        _bio = State(initialValue: existingHorse?.bio ?? "")
        _city = State(initialValue: existingHorse?.location.city ?? "Lexington, KY")
        _coarseLatitude = State(initialValue: existingHorse?.location.coarseLatitude ?? 38.04)
        _coarseLongitude = State(initialValue: existingHorse?.location.coarseLongitude ?? -84.50)
        _vaccinationsUpToDate = State(initialValue: existingHorse?.healthInfo?.vaccinationsUpToDate ?? true)
        _includeCogginsDate = State(initialValue: existingHorse?.healthInfo?.cogginsTestDate != nil)
        _cogginsDate = State(initialValue: existingHorse?.healthInfo?.cogginsTestDate ?? Date())
        _pedigree = State(initialValue: existingHorse?.pedigree ?? "")
    }

    public var body: some View {
        Form {
            Section("Photos (2–6 Required for Discovery)") {
                let currentPhotoCount = max(existingHorse?.photos.count ?? 2, selectedPhotoItems.count)
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: SafetyConstants.maxHorsePhotos,
                    matching: .images
                ) {
                    Label(
                        "Select Horse Photos (\(currentPhotoCount)/6)",
                        systemImage: "photo.on.rectangle.angled"
                    )
                    .foregroundStyle(EquestrianTheme.tinderRed)
                }
            }

            Section("Basic Details") {
                TextField("Horse Name", text: $name)
                    .accessibilityIdentifier("horseNameField")
                Stepper("Age: \(age) years", value: $age, in: 0...45)
                Picker("Sex", selection: $sex) {
                    ForEach(HorseSex.allCases, id: \.self) { item in
                        Text(item.displayName).tag(item)
                    }
                }
                TextField("Breed", text: $breed)
                    .accessibilityIdentifier("horseBreedField")
                TextField("Coat Color", text: $color)
                VStack(alignment: .leading) {
                    Text("Height: \(String(format: "%.1f", heightHands)) hands")
                    Slider(value: $heightHands, in: 8.0...19.0, step: 0.1)
                        .tint(EquestrianTheme.tinderRed)
                }
            }

            Section("Disciplines") {
                ForEach(HorseDiscipline.allCases, id: \.self) { disc in
                    Toggle(
                        disc.displayName,
                        isOn: Binding(
                            get: { selectedDisciplines.contains(disc) },
                            set: { isOn in
                                if isOn { selectedDisciplines.insert(disc) }
                                else if selectedDisciplines.count > 1 { selectedDisciplines.remove(disc) }
                            }
                        )
                    )
                }
            }

            Section("Looking For") {
                ForEach(LookingForCategory.allCases, id: \.self) { goal in
                    Toggle(
                        goal.displayName,
                        isOn: Binding(
                            get: { selectedLookingFor.contains(goal) },
                            set: { isOn in
                                if isOn { selectedLookingFor.insert(goal) }
                                else if selectedLookingFor.count > 1 { selectedLookingFor.remove(goal) }
                            }
                        )
                    )
                }
            }

            Section("Bio & Temperament") {
                TextField("Temperament tags (comma separated)", text: $temperamentText)
                TextField("Bio (max 500 chars)", text: $bio, axis: .vertical)
                    .lineLimit(3...6)
                    .accessibilityIdentifier("horseBioField")
                Text("\(bio.count) / \(SafetyConstants.maxBioLength) characters")
                    .font(.caption2)
                    .foregroundStyle(bio.count > SafetyConstants.maxBioLength ? EquestrianTheme.warmTerracotta : .secondary)
            }

            Section("Coarse Location (City Level Only)") {
                TextField("City, State", text: $city)
                    .accessibilityIdentifier("horseCityField")
                Text("Exact coordinates are rounded to ~1.1 km resolution for barn privacy.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section("Health & Pedigree (Optional)") {
                Toggle("Vaccinations Up to Date", isOn: $vaccinationsUpToDate)
                Toggle("Include Coggins Test Date", isOn: $includeCogginsDate)
                if includeCogginsDate {
                    DatePicker("Coggins Date", selection: $cogginsDate, displayedComponents: .date)
                }
                TextField("Pedigree notes (optional)", text: $pedigree)
            }

            if let validationMessage {
                Section {
                    Text(validationMessage)
                        .foregroundStyle(EquestrianTheme.warmTerracotta)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle(existingHorse == nil ? "Create Horse" : "Edit \(existingHorse?.name ?? "Horse")")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await saveHorse() }
                }
                .disabled(isSaving)
                .accessibilityIdentifier("saveHorseProfileButton")
            }
        }
    }

    private func saveHorse() async {
        validationMessage = nil
        switch ObjectionableContentFilter.validateBio(bio) {
        case .valid:
            break
        case .empty:
            validationMessage = "Please enter a bio for your horse."
            return
        case .tooLong(let maxLen):
            validationMessage = "Bio must be \(maxLen) characters or fewer."
            return
        case .objectionableContent:
            validationMessage = "Bio contains prohibited or unsafe language."
            return
        }

        let tags = temperamentText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let location = HorseLocationDTO(
            city: city,
            coarseLatitude: coarseLatitude,
            coarseLongitude: coarseLongitude
        )
        let healthInfo = HorseHealthInfoDTO(
            cogginsTestDate: includeCogginsDate ? cogginsDate : nil,
            vaccinationsUpToDate: vaccinationsUpToDate
        )

        isSaving = true
        defer { isSaving = false }

        do {
            let savedHorse: HorseProfileDTO
            if let existingHorse {
                savedHorse = try await appState.updateHorse(
                    id: existingHorse.id,
                    UpdateHorseProfileRequest(
                        name: name,
                        age: age,
                        sex: sex,
                        breed: breed,
                        color: color,
                        heightHands: heightHands,
                        disciplines: Array(selectedDisciplines),
                        temperamentTags: tags,
                        bio: bio,
                        location: location,
                        lookingFor: Array(selectedLookingFor),
                        healthInfo: healthInfo,
                        pedigree: pedigree.isEmpty ? nil : pedigree
                    )
                )
            } else {
                savedHorse = try await appState.createHorse(
                    CreateHorseProfileRequest(
                        name: name,
                        age: age,
                        sex: sex,
                        breed: breed,
                        color: color,
                        heightHands: heightHands,
                        disciplines: Array(selectedDisciplines),
                        temperamentTags: tags,
                        bio: bio,
                        location: location,
                        lookingFor: Array(selectedLookingFor),
                        healthInfo: healthInfo,
                        pedigree: pedigree.isEmpty ? nil : pedigree
                    )
                )
            }

            for item in selectedPhotoItems {
                if let rawData = try? await item.loadTransferable(type: Data.self) {
                    let compressed = ImageCompressor.compressToJPEG(rawData)
                    _ = try? await appState.apiClient.uploadHorsePhoto(
                        horseID: savedHorse.id,
                        jpegData: compressed
                    )
                }
            }

            onSaved()
            dismiss()
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}

public enum MobileTab: Int, CaseIterable, Hashable {
    case discover = 0
    case matches = 1
    case messages = 2
    case profile = 3

    public var title: String {
        switch self {
        case .discover: return "Discover"
        case .matches: return "Matches"
        case .messages: return "Messages"
        case .profile: return "Profile"
        }
    }

    public var iconName: String {
        switch self {
        case .discover: return "flame.fill"
        case .matches: return "sparkles"
        case .messages: return "message.fill"
        case .profile: return "person.fill"
        }
    }
}

public struct MainTabView: View {
    @Bindable public var appState: AppStateViewModel
    @State private var selectedTab: MobileTab = .discover
    @State private var discoverViewModel: DiscoverViewModel
    @State private var matchesAndConversationsViewModel: MatchesAndConversationsViewModel

    public init(appState: AppStateViewModel) {
        self.appState = appState
        _discoverViewModel = State(initialValue: DiscoverViewModel(apiClient: appState.apiClient))
        _matchesAndConversationsViewModel = State(
            initialValue: MatchesAndConversationsViewModel(apiClient: appState.apiClient)
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch selectedTab {
                case .discover:
                    DiscoverScreen(appState: appState, viewModel: discoverViewModel)
                        .transition(.opacity)
                case .matches:
                    MatchesScreen(appState: appState, viewModel: matchesAndConversationsViewModel)
                        .transition(.opacity)
                case .messages:
                    MessagesScreen(appState: appState, viewModel: matchesAndConversationsViewModel)
                        .transition(.opacity)
                case .profile:
                    ProfileAndSettingsScreen(appState: appState)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Sleek Tinder Red & White Mobile Bottom Navigation Bar
            HStack(spacing: 0) {
                ForEach(MobileTab.allCases, id: \.self) { tab in
                    let isSelected = (selectedTab == tab)
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
                            selectedTab = tab
                        }
                        if tab == .matches || tab == .messages {
                            Task { await matchesAndConversationsViewModel.refreshAll() }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: tab.iconName)
                                    .font(.system(size: isSelected ? 22 : 20, weight: .bold))
                                    .foregroundStyle(
                                        isSelected
                                            ? AnyShapeStyle(EquestrianTheme.brandGradient)
                                            : AnyShapeStyle(Color.gray.opacity(0.45))
                                    )
                                    .scaleEffect(isSelected ? 1.12 : 1.0)
                                    .frame(width: 36, height: 28)

                                if tab == .messages && matchesAndConversationsViewModel.totalUnreadCount > 0 {
                                    Text("\(matchesAndConversationsViewModel.totalUnreadCount)")
                                        .font(.system(size: 9, weight: .heavy))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(EquestrianTheme.brandGradient))
                                        .offset(x: 6, y: -3)
                                }
                            }

                            Text(tab.title)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? EquestrianTheme.tinderRed : Color.gray.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tab_\(tab.title.lowercased())")
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .background(
                Color.white
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: -3)
            )
        }
        .preferredColorScheme(.light)
        .task {
            await matchesAndConversationsViewModel.refreshAll()
        }
    }
}

public struct StallionMatchRootView: View {
    @Bindable public var appState: AppStateViewModel

    public init(appState: AppStateViewModel) {
        self.appState = appState
    }

    public var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView(appState: appState)
            } else {
                AuthRootView(appState: appState)
            }
        }
        .preferredColorScheme(.light)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        let client = MockAPIClient()
        let appState = AppStateViewModel(
            apiClient: client,
            preauthenticatedUser: MockSampleData.currentUser,
            initialHorses: [MockSampleData.myHorse]
        )
        MainTabView(appState: appState)
    }
}
