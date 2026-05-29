import AppKit
import ApplicationServices

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else { return nil }
    return value
}

func axFrame(for element: AXUIElement) -> NSRect? {
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
