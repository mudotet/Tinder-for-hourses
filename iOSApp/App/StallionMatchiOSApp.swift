import SharedModels
import StallionMatchClient
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

@main
struct StallionMatchiOSApp: App {
    @State private var appState: AppStateViewModel

    init() {
        #if canImport(AppKit)
        NSApplication.shared.setActivationPolicy(.regular)
        #endif
        if ProcessInfo.processInfo.arguments.contains("--uitesting-mock") {
            let mockClient = MockAPIClient(myHorses: [])
            _appState = State(initialValue: AppStateViewModel(apiClient: mockClient))
        } else if ProcessInfo.processInfo.arguments.contains("--live") {
            let keychain = KeychainTokenStore()
            let baseURLString = ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://127.0.0.1:8080"
            let baseURL = URL(string: baseURLString) ?? URL(string: "http://127.0.0.1:8080")!
            let liveClient = APIClient(baseURL: baseURL, tokenStore: keychain)
            _appState = State(
                initialValue: AppStateViewModel(
                    apiClient: liveClient,
                    tokenStore: keychain,
                    preauthenticatedUser: MockSampleData.currentUser,
                    initialHorses: [MockSampleData.myHorse]
                )
            )
        } else {
            // Default: start immediately in the full interactive mobile flow (no login wall first)
            let mockClient = MockAPIClient()
            _appState = State(
                initialValue: AppStateViewModel(
                    apiClient: mockClient,
                    preauthenticatedUser: MockSampleData.currentUser,
                    initialHorses: [MockSampleData.myHorse]
                )
            )
        }
    }

    var body: some Scene {
        WindowGroup("Horsy") {
            StallionMatchRootView(appState: appState)
                #if os(macOS)
                .frame(minWidth: 393, idealWidth: 402, maxWidth: 430, minHeight: 780, idealHeight: 852, maxHeight: 920)
                #endif
                .task {
                    #if canImport(AppKit)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    if ProcessInfo.processInfo.arguments.contains("--export-screenshots") {
                        await Self.exportAppScreenshots()
                        NSApplication.shared.terminate(nil)
                        return
                    }
                    #endif
                    if ProcessInfo.processInfo.arguments.contains("--live") {
                        await appState.login(email: "demo@stallionmatch.app", password: "StablePass123")
                    }
                }
        }
        #if os(macOS)
        .defaultSize(width: 402, height: 852)
        #endif
    }

    #if canImport(AppKit)
    @MainActor
    private static func exportAppScreenshots() async {
        let outDir = "/Users/tupt/Downloads/self_project/Tinder_for_horses/docs/screenshots"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

        let mockClient = MockAPIClient()
        let lightState = AppStateViewModel(
            apiClient: mockClient,
            preauthenticatedUser: MockSampleData.currentUser,
            initialHorses: [MockSampleData.myHorse]
        )
        lightState.isDarkMode = false

        let darkState = AppStateViewModel(
            apiClient: mockClient,
            preauthenticatedUser: MockSampleData.currentUser,
            initialHorses: [MockSampleData.myHorse]
        )
        darkState.isDarkMode = true

        let discoverVM = DiscoverViewModel(apiClient: mockClient)
        await discoverVM.loadCards(activeHorseID: MockSampleData.myHorse.id, reset: true)
        discoverVM.cards = MockSampleData.discoveryHorses
        discoverVM.state = .loaded

        let matchesVM = MatchesAndConversationsViewModel(apiClient: mockClient)
        await matchesVM.refreshAll()
        matchesVM.matches = [MockSampleData.sampleMatch]
        matchesVM.conversations = [MockSampleData.sampleConversationSummary]
        matchesVM.matchesState = .loaded
        matchesVM.conversationsState = .loaded

        let chatVM = ChatDetailViewModel(
            conversationSummary: MockSampleData.sampleConversationSummary,
            apiClient: mockClient
        )
        await chatVM.loadMessages()
        chatVM.messages = MockSampleData.sampleMessages
        chatVM.state = .loaded
        chatVM.isOtherHorseTyping = true

        await saveWindowSnapshot(
            DiscoverScreen(appState: lightState, viewModel: discoverVM)
                .environment(\.colorScheme, .light),
            appearanceName: .aqua,
            to: "\(outDir)/discover_light.png"
        )

        await saveWindowSnapshot(
            DiscoverScreen(appState: darkState, viewModel: discoverVM)
                .environment(\.colorScheme, .dark),
            appearanceName: .darkAqua,
            to: "\(outDir)/discover_dark.png"
        )

        await saveWindowSnapshot(
            HorseDetailSheet(
                horse: MockSampleData.discoveryHorses[0],
                apiClient: mockClient,
                onSwipeDecision: { _ in },
                onModerationAction: {}
            )
            .environment(\.colorScheme, .light),
            appearanceName: .aqua,
            to: "\(outDir)/horse_detail.png"
        )

        await saveWindowSnapshot(
            ChatDetailScreen(
                viewModel: chatVM,
                currentUserID: MockSampleData.currentUserID
            )
            .environment(\.colorScheme, .light),
            appearanceName: .aqua,
            to: "\(outDir)/chat_screen.png"
        )

        await saveWindowSnapshot(
            MessagesScreen(appState: lightState, viewModel: matchesVM)
                .environment(\.colorScheme, .light),
            appearanceName: .aqua,
            to: "\(outDir)/messages_screen.png"
        )
    }

    @MainActor
    private static func saveWindowSnapshot<V: View>(
        _ view: V,
        appearanceName: NSAppearance.Name,
        to path: String
    ) async {
        let size = NSSize(width: 402, height: 852)
        let hostingView = NSHostingView(
            rootView: view.frame(width: size.width, height: size.height)
        )
        hostingView.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: appearanceName)
        window.contentView = hostingView
        window.orderFront(nil)
        hostingView.layoutSubtreeIfNeeded()
        try? await Task.sleep(nanoseconds: 250_000_000)
        hostingView.layoutSubtreeIfNeeded()

        if let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) {
            hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
            if let pngData = rep.representation(using: .png, properties: [:]) {
                try? pngData.write(to: URL(fileURLWithPath: path))
            }
        }
        window.orderOut(nil)
    }
    #endif
}
