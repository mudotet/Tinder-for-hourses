// swift-tools-version: 6.0
import PackageDescription

let cltFrameworksPath = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let cltUsrLibPath = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
let xcodeFrameworksPath = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks"
let xcodePrivateFrameworksPath = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/PrivateFrameworks"
let xcodeUsrLibPath = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib"

let package = Package(
    name: "SharedModels",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SharedModels",
            targets: ["SharedModels"]
        )
    ],
    targets: [
        .target(
            name: "SharedModels",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SharedModelsTests",
            dependencies: ["SharedModels"],
            swiftSettings: [
                .unsafeFlags([
                    "-F\(cltFrameworksPath)",
                    "-F\(xcodeFrameworksPath)",
                    "-F\(xcodePrivateFrameworksPath)",
                    "-I\(xcodeUsrLibPath)"
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
