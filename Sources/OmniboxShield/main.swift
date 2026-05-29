import AppKit
import ApplicationServices

private let revealToken = ";;"
private let debugMode = CommandLine.arguments.contains("--debug")
private let shouldPromptForAccessibility = CommandLine.arguments.contains("--prompt-accessibility")
private let famousTips = [
    "Stay hungry. Stay foolish.",
    "Simplicity is the ultimate sophistication.",
    "Focus is saying no.",
    "What you seek is seeking you.",
    "The quieter you become, the more you can hear."
]
private let chromeBundleIDs: Set<String> = [
    "com.google.Chrome",
    "com.google.Chrome.canary",
    "org.chromium.Chromium"
]

@MainActor
final class OmniboxShieldApp: NSObject, NSApplicationDelegate {
    private var shieldWindow: NSPanel?
    private var statusItem: NSStatusItem?
    private var accessibilityStatusItem: NSMenuItem?
    private var pollTimer: Timer?
    private var eventMonitor: Any?
    private var typedBuffer = ""
    private var revealedUntilOmniboxSessionEnds = false
    private var wasOmniboxFocused = false
    private var lastDebugLine = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        requestAccessibilityPermissionIfNeeded()
        createShieldWindow()
        createStatusItem()
        installKeyboardMonitor()

        pollTimer = Timer.scheduledTimer(
            timeInterval: 0.12,
            target: self,
            selector: #selector(refreshFromTimer),
            userInfo: nil,
            repeats: true
        )

        RunLoop.main.add(pollTimer!, forMode: .common)
        log("Omnibox Shield is running. Look for the control window or menu-bar shield. Press Ctrl-C here to stop it.")
        if debugMode {
            log("Debug mode enabled. Focus Chrome's address bar and watch the focused accessibility element output.")
        }
    }

    private func requestAccessibilityPermissionIfNeeded() {
        if AXIsProcessTrusted() {
            return
        }

        if shouldPromptForAccessibility || !debugMode {
            let options = [
                "AXTrustedCheckOptionPrompt": true
            ] as CFDictionary

            _ = AXIsProcessTrustedWithOptions(options)
            return
        }

        log("Accessibility permission is not granted. Enable Omnibox Shield in System Settings > Privacy & Security > Accessibility.")
    }

    private func createShieldWindow() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 340),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false

        let view = ShieldView(frame: window.contentView?.bounds ?? .zero)
        view.autoresizingMask = [.width, .height]
        window.contentView = view
        window.orderOut(nil)
        shieldWindow = window
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: "Omnibox Shield")
            button.title = button.image == nil ? "S" : ""
        }

        let menu = NSMenu()
        let accessibilityItem = NSMenuItem(title: "Accessibility: Checking", action: nil, keyEquivalent: "")
        accessibilityItem.isEnabled = false
        menu.addItem(accessibilityItem)
        accessibilityStatusItem = accessibilityItem

        let openSettingsItem = NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        menu.addItem(openSettingsItem)
        menu.addItem(NSMenuItem.separator())

        let revealItem = NSMenuItem(title: "Reveal token: \(revealToken)", action: nil, keyEquivalent: "")
        revealItem.isEnabled = false
        menu.addItem(revealItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
        updateStatusItem()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func installKeyboardMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleKeyDown(event)
            }
        }
    }

    @objc private func refreshFromTimer() {
        refresh()
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard wasOmniboxFocused else { return }

        if event.keyCode == 36 || event.keyCode == 53 {
            resetOmniboxSession()
            return
        }

        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
            return
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
            revealedUntilOmniboxSessionEnds = true
            shieldWindow?.orderOut(nil)
        }
    }

    private func refresh() {
        guard AXIsProcessTrusted() else {
            debug("Accessibility permission is not granted.")
            updateStatusItem()
            shieldWindow?.orderOut(nil)
            return
        }

        updateStatusItem()

        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier,
              chromeBundleIDs.contains(bundleID) else {
            debug("Frontmost app is not Chrome.")
            resetOmniboxSession()
            return
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let focused = copyAttribute(appElement, kAXFocusedUIElementAttribute).map { $0 as! AXUIElement }
        let omniboxFocused = focused.map(isLikelyOmnibox(_:)) ?? false
        debug("Chrome focused: \(focused.map(debugDescription(for:)) ?? "none") | omnibox=\(omniboxFocused)")

        if !omniboxFocused {
            resetOmniboxSession()
            return
        }

        if !wasOmniboxFocused {
            typedBuffer = ""
            revealedUntilOmniboxSessionEnds = false
        }

        wasOmniboxFocused = true

        guard !revealedUntilOmniboxSessionEnds,
              let chromeFrame = chromeWindowFrame(appElement) else {
            shieldWindow?.orderOut(nil)
            return
        }

        let focusedFrame = focused.flatMap(axFrame(for:))
        let shieldFrame = shieldFrame(forChromeWindow: chromeFrame, focusedOmniboxFrame: focusedFrame)
        shieldWindow?.setFrame(shieldFrame, display: true)
        shieldWindow?.orderFrontRegardless()
    }

    private func resetOmniboxSession() {
        wasOmniboxFocused = false
        typedBuffer = ""
        revealedUntilOmniboxSessionEnds = false
        shieldWindow?.orderOut(nil)
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

    private func debugDescription(for element: AXUIElement) -> String {
        let role = copyAttribute(element, kAXRoleAttribute) as? String ?? "unknown-role"
        let subrole = copyAttribute(element, kAXSubroleAttribute) as? String ?? "unknown-subrole"
        let text = searchableAccessibilityText(for: element)
        let value = copyAttribute(element, kAXValueAttribute) as? String ?? ""
        return "role=\(role), subrole=\(subrole), text=\(text), value=\(value)"
    }

    private func debug(_ line: String) {
        guard debugMode, line != lastDebugLine else { return }
        lastDebugLine = line
        log(line)
    }

    private func updateStatusItem() {
        let trusted = AXIsProcessTrusted()
        accessibilityStatusItem?.title = trusted ? "Accessibility: Granted" : "Accessibility: Missing"

        guard let button = statusItem?.button else {
            return
        }

        button.contentTintColor = trusted ? .labelColor : .systemOrange
    }

    private func chromeWindowFrame(_ appElement: AXUIElement) -> NSRect? {
        guard let windowObject = copyAttribute(appElement, kAXFocusedWindowAttribute),
              let positionObject = copyAttribute(windowObject as! AXUIElement, kAXPositionAttribute),
              let sizeObject = copyAttribute(windowObject as! AXUIElement, kAXSizeAttribute) else {
            return nil
        }

        let positionValue = positionObject as! AXValue
        let sizeValue = sizeObject as! AXValue
        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue, .cgPoint, &position)
        AXValueGetValue(sizeValue, .cgSize, &size)

        return NSRect(origin: position, size: size)
    }

    private func axFrame(for element: AXUIElement) -> NSRect? {
        guard let positionObject = copyAttribute(element, kAXPositionAttribute),
              let sizeObject = copyAttribute(element, kAXSizeAttribute) else {
            return nil
        }

        let positionValue = positionObject as! AXValue
        let sizeValue = sizeObject as! AXValue
        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue, .cgPoint, &position)
        AXValueGetValue(sizeValue, .cgSize, &size)

        return NSRect(origin: position, size: size)
    }

    private func shieldFrame(forChromeWindow chromeFrame: NSRect, focusedOmniboxFrame: NSRect?) -> NSRect {
        let anchorFrame = focusedOmniboxFrame ?? chromeFrame
        let screen = screen(containing: anchorFrame) ?? screen(containing: chromeFrame) ?? NSScreen.main

        let screenHeight = screen?.frame.height ?? 0
        let height: CGFloat = min(420, max(260, chromeFrame.height * 0.42))
        let verticalGap: CGFloat = 8
        let panelInset: CGFloat = 8
        let panelX = chromeFrame.minX + panelInset
        let panelWidth = max(360, chromeFrame.width - panelInset * 2)

        if let omniboxFrame = focusedOmniboxFrame, omniboxFrame.width > 220 {
            let appKitY = screenHeight - omniboxFrame.maxY - verticalGap - height
            return NSRect(
                x: panelX,
                y: appKitY,
                width: panelWidth,
                height: height
            )
        }

        let topInset: CGFloat = 82
        let appKitY = screenHeight - chromeFrame.origin.y - topInset - height

        return NSRect(
            x: panelX,
            y: appKitY,
            width: panelWidth,
            height: height
        )
    }

    private func screen(containing frame: NSRect) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.frame.intersects(frame) || screen.frame.contains(NSPoint(x: frame.midX, y: frame.midY))
        }
    }
}

private final class ShieldView: NSView {
    private let tip = famousTips.randomElement() ?? famousTips[0]

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 10, yRadius: 10)
        NSColor(calibratedRed: 0.965, green: 0.968, blue: 0.972, alpha: 0.995).setFill()
        path.fill()

        NSColor(calibratedRed: 0.72, green: 0.76, blue: 0.82, alpha: 0.75).setStroke()
        path.lineWidth = 1
        path.stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.13, green: 0.16, blue: 0.20, alpha: 1),
            .paragraphStyle: paragraph
        ]

        let detailAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor(calibratedRed: 0.35, green: 0.39, blue: 0.45, alpha: 1),
            .paragraphStyle: paragraph
        ]

        let title = tip
        let detail = "Type ;; to reveal suggestions for this session."
        let textWidth = min(bounds.width - 64, 560)
        let textX = bounds.midX - textWidth / 2
        title.draw(in: NSRect(x: textX, y: bounds.midY + 8, width: textWidth, height: 24), withAttributes: titleAttributes)
        detail.draw(in: NSRect(x: textX, y: bounds.midY - 18, width: textWidth, height: 22), withAttributes: detailAttributes)
    }
}

private func copyAttribute(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else { return nil }
    return value
}

private func log(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

log("Omnibox Shield process started.")
if debugMode {
    log("Debug mode enabled before AppKit launch.")
}

let app = NSApplication.shared
let delegate = OmniboxShieldApp()
app.delegate = delegate
app.run()
