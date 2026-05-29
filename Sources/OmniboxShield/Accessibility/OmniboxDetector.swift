import AppKit
import ApplicationServices

struct OmniboxFocusState {
    let chromeWindowFrame: NSRect
    let focusedOmniboxFrame: NSRect?
    let focusedOmniboxValue: String
    let debugLine: String
}

final class OmniboxDetector {
    private(set) var lastDebugLine = ""

    func currentState() -> OmniboxFocusState? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier,
              AppConstants.chromeBundleIDs.contains(bundleID) else {
            lastDebugLine = "Frontmost app is not Chrome."
            return nil
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let focused = copyAttribute(appElement, kAXFocusedUIElementAttribute).map { $0 as! AXUIElement }
        let omniboxFocused = focused.map(isLikelyOmnibox(_:)) ?? false
        let debugLine = "Chrome focused: \(focused.map(debugDescription(for:)) ?? "none") | omnibox=\(omniboxFocused)"
        lastDebugLine = debugLine

        guard omniboxFocused, let chromeFrame = chromeWindowFrame(appElement) else {
            return nil
        }

        return OmniboxFocusState(
            chromeWindowFrame: chromeFrame,
            focusedOmniboxFrame: focused.flatMap(axFrame(for:)),
            focusedOmniboxValue: focused.flatMap(omniboxValue(for:)) ?? "",
            debugLine: debugLine
        )
    }

    private func chromeWindowFrame(_ appElement: AXUIElement) -> NSRect? {
        guard let windowObject = copyAttribute(appElement, kAXFocusedWindowAttribute) else {
            return nil
        }

        return axFrame(for: windowObject as! AXUIElement)
    }

    private func isLikelyOmnibox(_ element: AXUIElement) -> Bool {
        let ownText = searchableAccessibilityText(for: element)
        if ownText.localizedCaseInsensitiveContains("address")
            || ownText.localizedCaseInsensitiveContains("search") {
            return true
        }

        var current: AXUIElement? = element
        var depth = 0
        var sawTextInput = false
        var sawToolbar = false

        while let node = current, depth < 8 {
            let role = copyAttribute(node, kAXRoleAttribute) as? String
            let nodeText = searchableAccessibilityText(for: node)

            if role == kAXTextFieldRole as String || role == kAXComboBoxRole as String {
                sawTextInput = true
            }

            if role == kAXToolbarRole as String || nodeText.localizedCaseInsensitiveContains("toolbar") {
                sawToolbar = true
            }

            if nodeText.localizedCaseInsensitiveContains("address and search")
                || nodeText.localizedCaseInsensitiveContains("search or enter address") {
                return true
            }

            current = copyAttribute(node, kAXParentAttribute).map { $0 as! AXUIElement }
            depth += 1
        }

        return sawTextInput && sawToolbar
    }

    private func searchableAccessibilityText(for element: AXUIElement) -> String {
        [
            kAXTitleAttribute,
            kAXDescriptionAttribute,
            kAXHelpAttribute,
            kAXPlaceholderValueAttribute
        ]
        .compactMap { copyAttribute(element, $0) as? String }
        .joined(separator: " ")
    }

    private func omniboxValue(for element: AXUIElement) -> String? {
        copyAttribute(element, kAXValueAttribute) as? String
    }

    private func debugDescription(for element: AXUIElement) -> String {
        let role = copyAttribute(element, kAXRoleAttribute) as? String ?? "unknown-role"
        let subrole = copyAttribute(element, kAXSubroleAttribute) as? String ?? "unknown-subrole"
        let text = searchableAccessibilityText(for: element)
        let value = copyAttribute(element, kAXValueAttribute) as? String ?? ""
        return "role=\(role), subrole=\(subrole), text=\(text), value=\(value)"
    }
}
