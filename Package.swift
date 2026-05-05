// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "FluidAudioCommand",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(
      name: "fluidaudio",
      targets: ["FluidAudioExecutable"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.14.4"),
    .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins.git", exact: "0.63.2"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.1"),
  ],
  targets: [
    .target(
      name: "FluidAudioCommand",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "FluidAudio", package: "FluidAudio"),
      ]
    ),
    .executableTarget(
      name: "FluidAudioExecutable",
      dependencies: [
        "FluidAudioCommand"
      ]
    ),
    .testTarget(
      name: "FluidAudioCommandTests",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "FluidAudioCommand",
      ]
    ),
    .testTarget(
      name: "FluidAudioCommandIntegrationTests",
      dependencies: [
        "FluidAudioCommand"
      ]
    ),
  ]
)
