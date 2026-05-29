import AppKit
import ApplicationServices

@MainActor
final class OmniboxShieldApp: NSObject, NSApplicationDelegate {
    private let shieldWindowController = ShieldWindowController()
    private let statusMenuController = StatusMenuController()
    private let omniboxDetector = OmniboxDetector()
    private lazy var updater = AppUpdater(menuState: statusMenuController)

    private var pollTimer: Timer?
    private var eventMonitor: Any?
    private var revealSession = RevealSession()
    private var lastDebugLine = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        requestAccessibilityPermissionIfNeeded()
        shieldWindowController.createWindow()
        statusMenuController.createStatusItem()
        statusMenuController.onCheckForUpdates = { [weak self] in
            self?.checkForUpdatesFromMenu()
        }

        installKeyboardMonitor()
        startPolling()

        log("Omnibox Shield is running. Look for the control window or menu-bar shield. Press Ctrl-C here to stop it.")
        if AppConstants.debugMode {
            log("Debug mode enabled. Focus Chrome's address bar and watch the focused accessibility element output.")
        }
    }

    private func requestAccessibilityPermissionIfNeeded() {
        if AXIsProcessTrusted() {
            return
        }

        if AppConstants.shouldPromptForAccessibility || !AppConstants.debugMode {
            let options = [
                "AXTrustedCheckOptionPrompt": true
            ] as CFDictionary

            _ = AXIsProcessTrustedWithOptions(options)
            return
        }

        log("Accessibility permission is not granted. Enable Omnibox Shield in System Settings > Privacy & Security > Accessibility.")
    }

    private func startPolling() {
        let timer = Timer.scheduledTimer(
            timeInterval: 0.12,
            target: self,
            selector: #selector(refreshFromTimer),
            userInfo: nil,
            repeats: true
        )

        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func installKeyboardMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleKeyDown(event)
            }
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard revealSession.isOmniboxFocused else { return }

        if revealSession.handleKeyDown(event, revealToken: AppConstants.revealToken) {
            shieldWindowController.hide()
        }
    }

    @objc private func refreshFromTimer() {
        refresh()
    }

    private func refresh() {
        guard AXIsProcessTrusted() else {
            debug("Accessibility permission is not granted.")
            statusMenuController.updateAccessibilityStatus()
            resetOmniboxSession()
            return
        }

        statusMenuController.updateAccessibilityStatus()

        guard let state = omniboxDetector.currentState() else {
            debug(omniboxDetector.lastDebugLine)
            resetOmniboxSession()
            return
        }

        debug(state.debugLine)

        if !revealSession.isOmniboxFocused {
            revealSession.startOmniboxSession()
        }

        if revealSession.revealIfNeeded(omniboxValue: state.focusedOmniboxValue, revealToken: AppConstants.revealToken) {
            shieldWindowController.hide()
            return
        }

        guard !revealSession.isRevealed else {
            shieldWindowController.hide()
            return
        }

        shieldWindowController.show(
            chromeWindowFrame: state.chromeWindowFrame,
            focusedOmniboxFrame: state.focusedOmniboxFrame
        )
    }

    private func resetOmniboxSession() {
        revealSession.reset()
        shieldWindowController.hide()
    }

    private func debug(_ line: String) {
        guard AppConstants.debugMode, line != lastDebugLine else { return }
        lastDebugLine = line
        log(line)
    }

    private func checkForUpdatesFromMenu() {
        Task {
            do {
                try await updater.checkForUpdates()
            } catch {
                AlertPresenter.show(
                    title: "Update Failed",
                    message: error.localizedDescription,
                    style: .warning
                )
            }
        }
    }
}
