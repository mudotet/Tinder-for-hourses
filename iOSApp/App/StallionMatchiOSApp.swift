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
}
