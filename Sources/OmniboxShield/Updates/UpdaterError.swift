import Foundation

enum UpdaterError: LocalizedError {
    case releaseCheckFailed
    case missingReleaseAsset(String)
    case downloadFailed
    case unzipFailed
    case missingAppBundle
    case bundleIdentifierMismatch

    var errorDescription: String? {
        switch self {
        case .releaseCheckFailed:
            return "Could not fetch the latest GitHub release."
        case .missingReleaseAsset(let name):
            return "The latest GitHub release does not include \(name)."
        case .downloadFailed:
            return "Could not download the update ZIP."
        case .unzipFailed:
            return "Could not unpack the update ZIP."
        case .missingAppBundle:
            return "The update ZIP did not contain an app bundle."
        case .bundleIdentifierMismatch:
            return "The downloaded app does not match Omnibox Shield."
        }
    }
}
