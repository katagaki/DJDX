// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DJDXStudio",
    platforms: [.macOS("26.0")],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "DJDXStudio",
            dependencies: ["Yams"]
        ),
    ]
)
