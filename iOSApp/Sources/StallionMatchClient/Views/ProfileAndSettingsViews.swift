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
            List {
                if let user = appState.currentUser {
                    Section("Owner / Handler Account") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName ?? "Horse Handler")
                                .font(.headline)
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("My Horses") {
                    ForEach(appState.myHorses) { horse in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(horse.name)
                                        .font(.headline)
                                    if appState.activeHorse?.id == horse.id {
                                        Text("Active")
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(EquestrianTheme.pastureSage.opacity(0.2)))
                                            .foregroundStyle(EquestrianTheme.pastureSage)
                                    }
                                }
                                Text("\(horse.age)yo \(horse.breed) \(horse.sex.displayName) • \(horse.location.city)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Edit") {
                                horseBeingEdited = horse
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Button {
                        showCreateHorseSheet = true
                    } label: {
                        Label("Add Horse Profile", systemImage: "plus.circle.fill")
                            .foregroundStyle(EquestrianTheme.saddleBrown)
                    }
                    .accessibilityIdentifier("addHorseProfileButton")
                }

                if let user = appState.currentUser {
                    Section("Push Notifications") {
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
                    }
                }

                Section("Safety & Legal") {
                    Button("Terms of Use") { showTermsSheet = true }
                    Button("Privacy Policy") { showPrivacySheet = true }
                    AnimalWelfareNoticeBanner()
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                }

                Section {
                    Button("Log Out") {
                        Task { await appState.logout() }
                    }
                    .foregroundStyle(EquestrianTheme.saddleBrown)
                    .accessibilityIdentifier("logOutButton")

                    Button("Delete Account & All Data", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .accessibilityIdentifier("deleteAccountButton")
                }
            }
            .navigationTitle("Profile & Settings")
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

            // Compress and upload any newly picked photos
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

public struct MainTabView: View {
    @Bindable public var appState: AppStateViewModel
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
        TabView {
            DiscoverScreen(appState: appState, viewModel: discoverViewModel)
                .tabItem {
                    Label("Discover", systemImage: "Copy" == "" ? "sparkles" : "figure.equestrian.sports")
                }

            MatchesScreen(appState: appState, viewModel: matchesAndConversationsViewModel)
                .tabItem {
                    Label("Matches", systemImage: "heart.circle.fill")
                }

            MessagesScreen(appState: appState, viewModel: matchesAndConversationsViewModel)
                .tabItem {
                    Label("Messages", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .badge(matchesAndConversationsViewModel.totalUnreadCount)

            ProfileAndSettingsScreen(appState: appState)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .tint(EquestrianTheme.saddleBrown)
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
    }
}

#Preview("Main Tab View") {
    let client = MockAPIClient()
    let appState = AppStateViewModel(
        apiClient: client,
        preauthenticatedUser: MockSampleData.currentUser,
        initialHorses: [MockSampleData.myHorse]
    )
    return MainTabView(appState: appState)
}
