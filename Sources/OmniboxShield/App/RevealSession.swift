import AppKit

struct RevealSession {
    private(set) var isOmniboxFocused = false
    private(set) var isRevealed = false
    private var typedBuffer = ""

    mutating func startOmniboxSession() {
        isOmniboxFocused = true
        typedBuffer = ""
        isRevealed = false
    }

    mutating func handleKeyDown(_ event: NSEvent, revealToken: String) -> Bool {
        if event.keyCode == 36 || event.keyCode == 53 {
            reset()
            return false
        }

        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
            return false
        }

        if event.keyCode == 51 {
            if !typedBuffer.isEmpty {
                typedBuffer.removeLast()
            }
        } else if characters.rangeOfCharacter(from: .controlCharacters) == nil {
            typedBuffer.append(characters)
            typedBuffer = String(typedBuffer.suffix(24))
        }

        if typedBuffer.contains(revealToken) {
            isRevealed = true
            return true
        }

        return false
    }

    mutating func revealIfNeeded(omniboxValue: String, revealToken: String) -> Bool {
        guard omniboxValue.contains(revealToken) else {
            return false
        }

        isRevealed = true
        return true
    }

    mutating func reset() {
        isOmniboxFocused = false
        isRevealed = false
        typedBuffer = ""
    }
}
