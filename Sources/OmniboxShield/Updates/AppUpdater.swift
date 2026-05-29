import AppKit

@MainActor
final class AppUpdater {
    private let menuState: StatusMenuController

    init(menuState: StatusMenuController) {
        self.menuState = menuState
    }

    func checkForUpdates() async throws {
        menuState.setUpdateState(.checking)
        defer {
            menuState.setUpdateState(.idle)
        }

        var request = URLRequest(url: AppConstants.latestReleaseURL)
        request.setValue("OmniboxShield", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw UpdaterError.releaseCheckFailed
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let remoteVersion = normalizedVersion(release.tagName)
        let currentVersion = normalizedVersion(Bundle.main.shortVersionString)

        guard isVersion(remoteVersion, newerThan: currentVersion) else {
            AlertPresenter.show(
                title: "Omnibox Shield Is Up to Date",
                message: "Current version: \(Bundle.main.shortVersionString)",
                style: .informational
            )
            return
        }

        guard let asset = release.assets.first(where: { $0.name == AppConstants.expectedReleaseAssetName })
            ?? release.assets.first(where: { $0.name.hasSuffix(".zip") }) else {
            throw UpdaterError.missingReleaseAsset(AppConstants.expectedReleaseAssetName)
        }

        guard AlertPresenter.askForConfirmation(
            title: "Update Available",
            message: "Version \(remoteVersion) is available. Current version: \(currentVersion). Download and install it now?"
        ) else {
            return
        }

        try await downloadAndInstallUpdate(from: asset.browserDownloadURL, version: remoteVersion)
    }

    private func downloadAndInstallUpdate(from url: URL, version: String) async throws {
        menuState.setUpdateState(.downloading)

        var request = URLRequest(url: url)
        request.setValue("OmniboxShield", forHTTPHeaderField: "User-Agent")

        let (downloadedURL, response) = try await URLSession.shared.download(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw UpdaterError.downloadFailed
        }

        let workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OmniboxShieldUpdate-\(UUID().uuidString)", isDirectory: true)
        let zipURL = workDirectory.appendingPathComponent(AppConstants.expectedReleaseAssetName)
        let unzipDirectory = workDirectory.appendingPathComponent("unzipped", isDirectory: true)

        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: downloadedURL, to: zipURL)
        try FileManager.default.createDirectory(at: unzipDirectory, withIntermediateDirectories: true)
        try unzip(zipURL: zipURL, to: unzipDirectory)

        guard let newAppURL = findAppBundle(in: unzipDirectory) else {
            throw UpdaterError.missingAppBundle
        }

        guard let newBundle = Bundle(url: newAppURL),
              newBundle.bundleIdentifier == Bundle.main.bundleIdentifier else {
            throw UpdaterError.bundleIdentifierMismatch
        }

        try installAfterQuit(newAppURL: newAppURL, workDirectory: workDirectory)

        AlertPresenter.show(
            title: "Installing Update",
            message: "Omnibox Shield will quit, replace itself with version \(version), and reopen.",
            style: .informational
        )

        NSApp.terminate(nil)
    }

    private func unzip(zipURL: URL, to destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipURL.path, destinationURL.path]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw UpdaterError.unzipFailed
        }
    }

    private func findAppBundle(in directoryURL: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator where url.pathExtension == "app" {
            return url
        }

        return nil
    }

    private func installAfterQuit(newAppURL: URL, workDirectory: URL) throws {
        let currentAppURL = Bundle.main.bundleURL
        let scriptURL = workDirectory.appendingPathComponent("install-update.sh")
        let script = """
        #!/bin/sh
        set -eu
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do
          sleep 0.2
        done
        /usr/bin/ditto "\(newAppURL.path)" "\(currentAppURL.path)"
        /usr/bin/open "\(currentAppURL.path)"
        /bin/rm -rf "\(workDirectory.path)"
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [scriptURL.path]
        try process.run()
    }
}
