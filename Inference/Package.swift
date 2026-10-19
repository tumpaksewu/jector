// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProjectorInference",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ProjectorInference", targets: ["ProjectorInference"])],
    targets: [
        // prepare-runtime.sh fetches the pinned official binary and verifies SHA-256.
        .binaryTarget(name: "llama", path: "Artifacts/llama.xcframework"),
        .target(name: "ProjectorInference", dependencies: ["llama"])
    ],
    swiftLanguageModes: [.v5]
)
