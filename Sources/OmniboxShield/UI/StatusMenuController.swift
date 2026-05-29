import AppKit
import ApplicationServices

@MainActor
final class StatusMenuController {
    var onCheckForUpdates: (() -> Void)?

    private var statusItem: NSStatusItem?
    private var accessibilityStatusItem: NSMenuItem?
    private var updateMenuItem: NSMenuItem?

    func createStatusItem() {
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

        menu.addItem(menuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings)))
        menu.addItem(NSMenuItem.separator())

        let revealItem = NSMenuItem(title: "Reveal token: \(AppConstants.revealToken)", action: nil, keyEquivalent: "")
        revealItem.isEnabled = false
        menu.addItem(revealItem)
        menu.addItem(NSMenuItem.separator())

        let updateItem = menuItem(title: "Check for Updates...", action: #selector(checkForUpdates))
        menu.addItem(updateItem)
        updateMenuItem = updateItem

        menu.addItem(menuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
        updateAccessibilityStatus()
    }

    private func menuItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    func setUpdateState(_ state: UpdateMenuState) {
        updateMenuItem?.isEnabled = state.isEnabled
        updateMenuItem?.title = state.title
    }

    func updateAccessibilityStatus() {
        let trusted = AXIsProcessTrusted()
        accessibilityStatusItem?.title = trusted ? "Accessibility: Granted" : "Accessibility: Missing"

        guard let button = statusItem?.button else {
            return
        }

        button.contentTintColor = trusted ? .labelColor : .systemOrange
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

    @objc private func checkForUpdates() {
        onCheckForUpdates?()
    }
}

struct UpdateMenuState {
    let title: String
    let isEnabled: Bool

    static let idle = UpdateMenuState(title: "Check for Updates...", isEnabled: true)
    static let checking = UpdateMenuState(title: "Checking for Updates...", isEnabled: false)
    static let downloading = UpdateMenuState(title: "Downloading Update...", isEnabled: false)
}
