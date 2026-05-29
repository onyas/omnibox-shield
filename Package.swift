// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OmniboxShield",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "omnibox-shield", targets: ["OmniboxShield"])
    ],
    targets: [
        .executableTarget(name: "OmniboxShield")
    ]
)
