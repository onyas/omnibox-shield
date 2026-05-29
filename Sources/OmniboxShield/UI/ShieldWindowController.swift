import AppKit

@MainActor
final class ShieldWindowController {
    private var shieldWindow: NSPanel?

    func createWindow() {
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

    func show(chromeWindowFrame: NSRect, focusedOmniboxFrame: NSRect?) {
        let shieldFrame = shieldFrame(forChromeWindow: chromeWindowFrame, focusedOmniboxFrame: focusedOmniboxFrame)
        shieldWindow?.setFrame(shieldFrame, display: true)
        shieldWindow?.orderFrontRegardless()
    }

    func hide() {
        shieldWindow?.orderOut(nil)
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
