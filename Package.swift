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
        .testTarget(
            name: "CrackinateTests",
            dependencies: ["Crackinate"],
            path: "CrackinateTests"
        ),
    ]
)
