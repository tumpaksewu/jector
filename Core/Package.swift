// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProjectorCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ProjectorCore", targets: ["ProjectorCore"]),
               .executable(name: "ProjectorProbe", targets: ["ProjectorProbe"]),
               .executable(name: "InferenceProbe", targets: ["InferenceProbe"])],
    dependencies: [.package(path: "../Inference"), .package(url: "https://github.com/akshaynexus/SwiftADB.git",
                            revision: "1044bec57ee3aef4b7c556fce2e76b24257769e5")],
    targets: [
        .target(name: "ProjectorCore", dependencies: [.product(name: "SwiftADB", package: "SwiftADB")]),
        .executableTarget(name: "ProjectorProbe", dependencies: ["ProjectorCore", .product(name: "SwiftADB", package: "SwiftADB")]),
        .executableTarget(name: "InferenceProbe", dependencies: ["ProjectorCore", .product(name: "ProjectorInference", package: "Inference")]),
        .testTarget(name: "ProjectorCoreTests", dependencies: ["ProjectorCore"])
    ],
    swiftLanguageModes: [.v5]
)
