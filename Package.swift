// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Crackinate",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Crackinate",
            path: "Crackinate",
            exclude: [
                "Info.plist",
                "Assets.xcassets",
            ]
        ),
        .executableTarget(
            name: "CrackinateCLI",
            path: "CLI"
        ),
        .testTarget(
            name: "CrackinateTests",
            dependencies: ["Crackinate"],
            path: "CrackinateTests"
        ),
    ]
)
