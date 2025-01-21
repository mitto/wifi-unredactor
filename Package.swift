// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "wifi-unredactor",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(
            name: "wifi-unredactor",
            targets: ["wifi-unredactor"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "wifi-unredactor",
            dependencies: [],
            path: "Sources/wifi-unredactor"
        ),
        .testTarget(
            name: "wifi-unredactorTests",
            dependencies: ["wifi-unredactor"],
            path: "Tests/wifi-unredactorTests"
        )
    ]
)
