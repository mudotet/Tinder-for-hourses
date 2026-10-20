// swift-tools-version: 6.0
import PackageDescription

let cltFrameworksPath = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let cltUsrLibPath = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
let xcodeFrameworksPath = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks"
let xcodePrivateFrameworksPath = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/PrivateFrameworks"
let xcodeUsrLibPath = "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib"

let package = Package(
    name: "Server",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(path: "../SharedModels"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.99.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.11.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.9.0"),
        .package(url: "https://github.com/vapor/jwt.git", from: "4.2.2")
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "SharedModels", package: "SharedModels"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "JWT", package: "jwt")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "Run",
            dependencies: [
                .target(name: "App")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "XCTVapor", package: "vapor"),
                .product(name: "SharedModels", package: "SharedModels")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
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
