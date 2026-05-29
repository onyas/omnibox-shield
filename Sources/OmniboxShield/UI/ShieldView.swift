import AppKit

final class ShieldView: NSView {
    private let tip = AppConstants.famousTips.randomElement() ?? AppConstants.famousTips[0]

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
        let detail = "Type \(AppConstants.revealToken) to reveal suggestions for this session."
        let textWidth = min(bounds.width - 64, 560)
        let textX = bounds.midX - textWidth / 2
        title.draw(in: NSRect(x: textX, y: bounds.midY + 8, width: textWidth, height: 24), withAttributes: titleAttributes)
        detail.draw(in: NSRect(x: textX, y: bounds.midY - 18, width: textWidth, height: 22), withAttributes: detailAttributes)
    }
}
