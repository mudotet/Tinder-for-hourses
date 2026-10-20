// swift-tools-version: 6.0
import PackageDescription

let cltFrameworksPath = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let cltUsrLibPath = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
let xcodeFrameworksPath = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks"
let xcodePrivateFrameworksPath = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/PrivateFrameworks"
let xcodeUsrLibPath = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib"
let previewsPluginPath = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libPreviewsMacros.dylib"

let package = Package(
    name: "StallionMatchApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "StallionMatchClient",
            targets: ["StallionMatchClient"]
        )
    ],
    dependencies: [
        .package(path: "../SharedModels")
    ],
    targets: [
        .target(
            name: "StallionMatchClient",
            dependencies: [
                .product(name: "SharedModels", package: "SharedModels")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .unsafeFlags([
                    "-Xfrontend", "-load-plugin-library",
                    "-Xfrontend", previewsPluginPath
                ])
            ]
        ),
        .testTarget(
            name: "StallionMatchClientTests",
            dependencies: [
                "StallionMatchClient",
                .product(name: "SharedModels", package: "SharedModels")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .unsafeFlags([
                    "-F\(cltFrameworksPath)",
                    "-F\(xcodeFrameworksPath)",
                    "-F\(xcodePrivateFrameworksPath)",
                    "-I\(xcodeUsrLibPath)",
                    "-Xfrontend", "-load-plugin-library",
                    "-Xfrontend", previewsPluginPath
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F\(cltFrameworksPath)",
                    "-F\(xcodeFrameworksPath)",
                    "-F\(xcodePrivateFrameworksPath)",
                    "-L\(xcodeUsrLibPath)",
                    "-Xlinker", "-rpath", "-Xlinker", cltFrameworksPath,
                    "-Xlinker", "-rpath", "-Xlinker", cltUsrLibPath,
                    "-Xlinker", "-rpath", "-Xlinker", xcodeFrameworksPath,
                    "-Xlinker", "-rpath", "-Xlinker", xcodePrivateFrameworksPath,
                    "-Xlinker", "-rpath", "-Xlinker", xcodeUsrLibPath
                ])
            ]
        )
    ]
)
