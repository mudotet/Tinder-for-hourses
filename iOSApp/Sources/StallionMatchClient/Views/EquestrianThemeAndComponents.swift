import SharedModels
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

public enum EquestrianTheme {
    // Iconic Tinder Red & White Mobile Palette
    public static let tinderRed = Color(red: 0.996, green: 0.235, blue: 0.447)      // #FE3C72
    public static let tinderCoral = Color(red: 1.000, green: 0.376, blue: 0.212)    // #FF6036
    public static let deepCrimson = Color(red: 0.890, green: 0.110, blue: 0.290)    // #E31C4A
    public static let likeGreen = Color(red: 0.145, green: 0.847, blue: 0.525)      // #25D886
    public static let nopeRed = Color(red: 1.000, green: 0.231, blue: 0.361)        // #FF3B5C
    public static let superLikeBlue = Color(red: 0.145, green: 0.706, blue: 1.000)  // #25B4FF
    public static let boostPurple = Color(red: 0.659, green: 0.235, blue: 0.969)    // #A83CF7
    public static let rewindGold = Color(red: 0.980, green: 0.741, blue: 0.141)     // #FABD24
    public static let charcoalText = Color(red: 0.110, green: 0.114, blue: 0.141)   // #1C1D24
    public static let slateSecondary = Color(red: 0.455, green: 0.475, blue: 0.529) // #747987
    public static let screenBackground = Color(red: 0.980, green: 0.980, blue: 0.992)
    public static let softRoseTint = Color(red: 1.000, green: 0.945, blue: 0.961)

    public static let brandGradient = LinearGradient(
        colors: [tinderRed, tinderCoral],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Backwards-compatible semantic aliases
    public static let saddleBrown = tinderRed
    public static let pastureSage = likeGreen
    public static let warmTerracotta = nopeRed
    public static let ribbonGold = rewindGold
    public static let parchmentBackground = Color.white
    public static let cardSurface = Color.white
}

/// High-performance local & remote horse photo view with automatic fallback to bundled demo photography.
public struct HorsePhotoView: View {
    public let horseName: String
    public let photoURL: String?
    public let photoIndex: Int

    public init(horseName: String, photoURL: String? = nil, photoIndex: Int = 0) {
        self.horseName = horseName
        self.photoURL = photoURL
        self.photoIndex = photoIndex
    }

    public var body: some View {
        GeometryReader { geo in
            if let image = Self.resolvePlatformImage(horseName: horseName, photoURL: photoURL, photoIndex: photoIndex) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } else if let urlString = photoURL, let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    default:
                        fallbackArtwork(size: geo.size)
                    }
                }
            } else {
                fallbackArtwork(size: geo.size)
            }
        }
    }

    @ViewBuilder
    private func fallbackArtwork(size: CGSize) -> some View {
        ZStack {
            EquestrianTheme.brandGradient
            Image(systemName: "figure.equestrian.sports")
                .font(.system(size: min(size.width, size.height) * 0.32, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(width: size.width, height: size.height)
    }

    private static let demoPhotosDir = "/Users/tupt/Downloads/self_project/Tinder_for_horses/Server/Public/uploads/demo"
    nonisolated(unsafe) private static let memoryCache = NSCache<NSString, AnyObject>()

    private static func resolveLocalFilePath(horseName: String, photoURL: String?, photoIndex: Int) -> String? {
        if let photoURL {
            if photoURL.hasPrefix("file://"), let path = URL(string: photoURL)?.path,
               FileManager.default.fileExists(atPath: path)
            {
                return path
            }
            if photoURL.hasPrefix("/"), FileManager.default.fileExists(atPath: photoURL) {
                return photoURL
            }
        }

        let lower = horseName.lowercased()
        let candidates: [String]
        if lower.contains("luna") {
            candidates = photoIndex % 2 == 0
                ? ["luna_1.jpg", "luna_2.jpg", "saffron_1.jpg"]
                : ["luna_2.jpg", "luna_1.jpg", "saffron_1.jpg"]
        } else if lower.contains("dakota") {
            candidates = photoIndex % 2 == 0
                ? ["dakota_1.jpg", "thunder_1.jpg", "apollo_1.jpg"]
                : ["thunder_1.jpg", "dakota_1.jpg"]
        } else if lower.contains("saffron") || lower.contains("starlight") || lower.contains("duchess") {
            candidates = photoIndex % 2 == 0
                ? ["saffron_1.jpg", "luna_1.jpg", "luna_2.jpg"]
                : ["luna_1.jpg", "saffron_1.jpg"]
        } else if lower.contains("thunder") || lower.contains("shadow") {
            candidates = photoIndex % 2 == 0
                ? ["thunder_1.jpg", "dakota_1.jpg", "apollo_1.jpg"]
                : ["dakota_1.jpg", "thunder_1.jpg"]
        } else if lower.contains("apollo") {
            candidates = photoIndex % 2 == 0
                ? ["apollo_1.jpg", "thunder_1.jpg", "dakota_1.jpg"]
                : ["thunder_1.jpg", "apollo_1.jpg"]
        } else {
            let all = ["luna_1.jpg", "dakota_1.jpg", "saffron_1.jpg", "apollo_1.jpg", "thunder_1.jpg", "luna_2.jpg"]
            let idx = abs(horseName.hashValue + photoIndex) % all.count
            candidates = [all[idx]] + all
        }

        for file in candidates {
            let fullPath = "\(demoPhotosDir)/\(file)"
            if FileManager.default.fileExists(atPath: fullPath) {
                return fullPath
            }
        }
        return nil
    }

    private static func resolvePlatformImage(horseName: String, photoURL: String?, photoIndex: Int) -> Image? {
        guard let path = resolveLocalFilePath(horseName: horseName, photoURL: photoURL, photoIndex: Int(photoIndex)) else {
            return nil
        }
        let key = path as NSString
        #if canImport(AppKit)
        if let cached = memoryCache.object(forKey: key) as? NSImage {
            return Image(nsImage: cached)
        }
        if let nsImage = NSImage(contentsOfFile: path) {
            memoryCache.setObject(nsImage, forKey: key)
            return Image(nsImage: nsImage)
        }
        #elseif canImport(UIKit)
        if let cached = memoryCache.object(forKey: key) as? UIImage {
            return Image(uiImage: cached)
        }
        if let uiImage = UIImage(contentsOfFile: path) {
            memoryCache.setObject(uiImage, forKey: key)
            return Image(uiImage: uiImage)
        }
        #endif
        return nil
    }
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
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(EquestrianTheme.softRoseTint)
                        .frame(width: 86, height: 86)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(EquestrianTheme.brandGradient)
                }
                ProgressView()
                    .tint(EquestrianTheme.tinderRed)
                Text("Finding horses near you...")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(EquestrianTheme.slateSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        case .empty(let message):
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(EquestrianTheme.softRoseTint)
                        .frame(width: 96, height: 96)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(EquestrianTheme.brandGradient)
                }
                Text("No More Horses Nearby")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(EquestrianTheme.charcoalText)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(EquestrianTheme.slateSecondary)
                    .padding(.horizontal, 28)
                Button {
                    retryAction()
                } label: {
                    Text("Reload Deck")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(EquestrianTheme.brandGradient))
                        .shadow(color: EquestrianTheme.tinderRed.opacity(0.35), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        case .offline(let message):
            VStack(spacing: 16) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 42))
                    .foregroundStyle(EquestrianTheme.tinderRed)
                Text("You're Offline")
                    .font(.headline)
                    .foregroundStyle(EquestrianTheme.charcoalText)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(EquestrianTheme.slateSecondary)
                Button {
                    retryAction()
                } label: {
                    Text("Try Again")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(EquestrianTheme.brandGradient))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        case .error(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(EquestrianTheme.tinderRed)
                Text("Something Went Wrong")
                    .font(.headline)
                    .foregroundStyle(EquestrianTheme.charcoalText)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(EquestrianTheme.slateSecondary)
                Button {
                    retryAction()
                } label: {
                    Text("Retry")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(EquestrianTheme.brandGradient))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
    }
}

/// Animal-welfare & no-payments compliance notice required by App Store Review.
public struct AnimalWelfareNoticeBanner: View {
    public init() {}

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(EquestrianTheme.tinderRed)
                .font(.subheadline)
            Text(SafetyConstants.animalWelfareWarning)
                .font(.caption2)
                .foregroundStyle(EquestrianTheme.slateSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(EquestrianTheme.softRoseTint)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Safety notice: \(SafetyConstants.animalWelfareWarning)")
    }
}
