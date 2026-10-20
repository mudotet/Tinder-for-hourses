import SharedModels
import StallionMatchClient
import SwiftUI

@main
struct StallionMatchiOSApp: App {
    @State private var appState: AppStateViewModel

    init() {
        let useMock = ProcessInfo.processInfo.arguments.contains("--uitesting-mock")
            || ProcessInfo.processInfo.environment["USE_MOCK_API"] == "1"
        if useMock {
            let mockClient = MockAPIClient(myHorses: [])
            _appState = State(initialValue: AppStateViewModel(apiClient: mockClient))
        } else {
            let keychain = KeychainTokenStore()
            let baseURLString = ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://127.0.0.1:8080"
            let baseURL = URL(string: baseURLString) ?? URL(string: "http://127.0.0.1:8080")!
            let liveClient = APIClient(baseURL: baseURL, tokenStore: keychain)
            _appState = State(initialValue: AppStateViewModel(apiClient: liveClient, tokenStore: keychain))
        }
    }

    var body: some Scene {
        WindowGroup {
            StallionMatchRootView(appState: appState)
                .task {
                    if !ProcessInfo.processInfo.arguments.contains("--uitesting-mock") {
                        await appState.restoreSession()
                    }
                }
        }
    }
}
