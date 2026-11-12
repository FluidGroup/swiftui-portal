// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "swiftui-portal",
  platforms: [
    .iOS(.v17)
  ],
  products: [
    .library(name: "Portal", targets: ["Portal"])
  ],
  targets: [
    .target(name: "Portal"),
    .testTarget(name: "PortalTests", dependencies: ["Portal"])
  ],
  swiftLanguageModes: [.v6]
)
