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
        let useMock = ProcessInfo.processInfo.arguments.contains("--uitesting-mock")
            || ProcessInfo.processInfo.environment["USE_MOCK_API"] == "1"
        if useMock {
            let mockClient = MockAPIClient(myHorses: [])
            _appState = State(initialValue: AppStateViewModel(apiClient: mockClient))
        } else if ProcessInfo.processInfo.arguments.contains("--demo-mock") {
            let mockClient = MockAPIClient()
            _appState = State(
                initialValue: AppStateViewModel(
                    apiClient: mockClient,
                    preauthenticatedUser: MockSampleData.currentUser,
                    initialHorses: [MockSampleData.myHorse]
                )
            )
        } else {
            let keychain = KeychainTokenStore()
            let baseURLString = ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://127.0.0.1:8080"
            let baseURL = URL(string: baseURLString) ?? URL(string: "http://127.0.0.1:8080")!
            let liveClient = APIClient(baseURL: baseURL, tokenStore: keychain)
            _appState = State(initialValue: AppStateViewModel(apiClient: liveClient, tokenStore: keychain))
        }
    }

    var body: some Scene {
        WindowGroup("Stallion Match") {
            StallionMatchRootView(appState: appState)
                #if os(macOS)
                .frame(minWidth: 400, idealWidth: 420, maxWidth: 500, minHeight: 760, idealHeight: 840, maxHeight: 960)
                #endif
                .task {
                    #if canImport(AppKit)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    #endif
                    if ProcessInfo.processInfo.arguments.contains("--auto-demo") {
                        await appState.login(email: "demo@stallionmatch.app", password: "StablePass123")
                    } else if !ProcessInfo.processInfo.arguments.contains("--uitesting-mock")
                        && !ProcessInfo.processInfo.arguments.contains("--demo-mock")
                    {
                        await appState.restoreSession()
                    }
                }
        }
        #if os(macOS)
        .defaultSize(width: 420, height: 840)
        #endif
    }
}
