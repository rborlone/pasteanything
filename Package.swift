// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "PasteAnything",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PasteAnything",
            path: "Sources/PasteAnything",
            linkerSettings: [.linkedLibrary("sqlite3")]
        )
    ]
)
