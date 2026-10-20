import SharedModels
import SwiftUI

public enum EquestrianTheme {
    public static let saddleBrown = Color(red: 0.42, green: 0.25, blue: 0.14)
    public static let pastureSage = Color(red: 0.24, green: 0.45, blue: 0.31)
    public static let warmTerracotta = Color(red: 0.74, green: 0.33, blue: 0.22)
    public static let ribbonGold = Color(red: 0.82, green: 0.64, blue: 0.24)
    public static let parchmentBackground = Color(red: 0.97, green: 0.95, blue: 0.91)
    public static let cardSurface = Color(red: 0.99, green: 0.98, blue: 0.95)
}

/// Reusable state container view handling Loading, Empty, Offline, and Error states on every screen.
public struct ScreenStateContainerView: View {
    public let state: ScreenLoadState
    public let retryAction: () -> Void

    public init(state: ScreenLoadState, retryAction: @escaping () -> Void) {
        self.state = state
        self.retryAction = retryAction
    }

    public var body: some View {
        switch state {
        case .idle, .loaded:
            EmptyView()
        case .loading:
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text("Loading barn records...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Loading content")

        case .empty(let message):
            ContentUnavailableView {
                Label("Nothing in the Paddock", systemImage: "figure.equestrian.sports")
                    .foregroundStyle(EquestrianTheme.saddleBrown)
            } description: {
                Text(message)
            } actions: {
                Button("Refresh", action: retryAction)
                    .buttonStyle(.borderedProminent)
                    .tint(EquestrianTheme.saddleBrown)
            }

        case .offline(let message):
            ContentUnavailableView {
                Label("You're Offline", systemImage: "wifi.slash")
                    .foregroundStyle(EquestrianTheme.warmTerracotta)
            } description: {
                Text(message)
            } actions: {
                Button("Retry Connection", action: retryAction)
                    .buttonStyle(.borderedProminent)
                    .tint(EquestrianTheme.saddleBrown)
            }

        case .error(let message):
            ContentUnavailableView {
                Label("Something Went Wrong", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(EquestrianTheme.warmTerracotta)
            } description: {
                Text(message)
            } actions: {
                Button("Try Again", action: retryAction)
                    .buttonStyle(.borderedProminent)
                    .tint(EquestrianTheme.saddleBrown)
            }
        }
    }
}

/// Banner displaying the mandatory animal welfare and no-in-app-payments notice.
public struct AnimalWelfareNoticeBanner: View {
    public init() {}

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(EquestrianTheme.pastureSage)
                .font(.title3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Animal Welfare & No Payments Policy")
                    .font(.footnote.weight(.semibold))
                Text(SafetyConstants.animalWelfareWarning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(EquestrianTheme.pastureSage.opacity(0.12))
        )
        .accessibilityElement(children: .combine)
    }
}
