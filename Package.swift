// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Volta",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "VoltaLanguageCore", targets: ["VoltaLanguageCore"]),
        .executable(name: "Volta", targets: ["Volta"]),
    ],
    targets: [
        .target(name: "VoltaLanguageCore", path: "Sources/VoltaLanguageCore"),
        .testTarget(name: "VoltaLanguageCoreTests", dependencies: ["VoltaLanguageCore"]),
        .testTarget(name: "VoltaAppTests", dependencies: ["Volta", "VoltaLanguageCore"]),
        .executableTarget(
            name: "Volta",
            dependencies: ["VoltaLanguageCore"],
            path: "Sources/Volta",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("UserNotifications"),
            ]
        )
    ]
)
