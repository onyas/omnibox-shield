import Foundation

extension Bundle {
    var shortVersionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }
}

func normalizedVersion(_ value: String) -> String {
    value.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
}

func isVersion(_ candidate: String, newerThan current: String) -> Bool {
    let candidateParts = versionParts(candidate)
    let currentParts = versionParts(current)
    let count = max(candidateParts.count, currentParts.count)

    for index in 0..<count {
        let lhs = index < candidateParts.count ? candidateParts[index] : 0
        let rhs = index < currentParts.count ? currentParts[index] : 0

        if lhs > rhs { return true }
        if lhs < rhs { return false }
    }

    return false
}

private func versionParts(_ value: String) -> [Int] {
    value
        .split(separator: ".")
        .map { part in
            let digits = part.prefix { $0.isNumber }
            return Int(digits) ?? 0
        }
}
