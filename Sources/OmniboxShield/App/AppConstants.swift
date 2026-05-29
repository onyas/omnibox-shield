import Foundation

enum AppConstants {
    static let revealToken = ";;"
    static let debugMode = CommandLine.arguments.contains("--debug")
    static let shouldPromptForAccessibility = CommandLine.arguments.contains("--prompt-accessibility")

    static let latestReleaseURL = URL(string: "https://api.github.com/repos/onyas/omnibox-shield/releases/latest")!
    static let expectedReleaseAssetName = "Omnibox.Shield.zip"

    static let famousTips = [
        "Stay hungry. Stay foolish.",
        "Simplicity is the ultimate sophistication.",
        "Focus is saying no.",
        "What you seek is seeking you.",
        "The quieter you become, the more you can hear."
    ]

    static let chromeBundleIDs: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "org.chromium.Chromium"
    ]
}

func log(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}
