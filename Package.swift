// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "KeepGoing",
  platforms: [.macOS(.v13)],
  targets: [
    .target(name: "KeepGoingShared"),
    .executableTarget(name: "KeepGoing", dependencies: ["KeepGoingShared"]),
    .executableTarget(name: "KeepGoingHelper", dependencies: ["KeepGoingShared"]),
  ]
)
