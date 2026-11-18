import Cocoa
import ApplicationServices

/// Помощники для Accessibility API (управление чужими окнами).
enum AX {
    static func attr<T>(_ el: AXUIElement, _ name: String) -> T? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success, let v else { return nil }
        return v as? T
    }

    @discardableResult
    static func set(_ el: AXUIElement, _ name: String, _ value: CFTypeRef) -> Bool {
        AXUIElementSetAttributeValue(el, name as CFString, value) == .success
    }

    /// Обычные окна приложения (без панелей и диалогов), включая свёрнутые.
    static func windows(pid: pid_t) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.5)
        let wins: [AXUIElement] = attr(app, kAXWindowsAttribute) ?? []
        return wins.filter { (attr($0, kAXSubroleAttribute) as String?) == kAXStandardWindowSubrole }
    }

    static func isMinimized(_ w: AXUIElement) -> Bool {
        (attr(w, kAXMinimizedAttribute) as Bool?) ?? false
    }

    static func setMinimized(_ w: AXUIElement, _ value: Bool) {
        set(w, kAXMinimizedAttribute, value as CFBoolean)
    }

    static func focusedWindow() -> AXUIElement? {
        guard let front = NSWorkspace.shared.frontmostApplication else { return nil }
        let app = AXUIElementCreateApplication(front.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.5)
        return attr(app, kAXFocusedWindowAttribute)
    }

    /// Рамка окна в координатах AX (начало — левый верхний угол главного экрана).
    static func frame(_ w: AXUIElement) -> CGRect? {
        guard let pv: AXValue = attr(w, kAXPositionAttribute),
              let sv: AXValue = attr(w, kAXSizeAttribute) else { return nil }
        var p = CGPoint.zero, s = CGSize.zero
        AXValueGetValue(pv, .cgPoint, &p)
        AXValueGetValue(sv, .cgSize, &s)
        return CGRect(origin: p, size: s)
    }

    static func setFrame(_ w: AXUIElement, _ r: CGRect) {
        var p = r.origin, s = r.size
        guard let pv = AXValueCreate(.cgPoint, &p), let sv = AXValueCreate(.cgSize, &s) else { return }
        // Размер → позиция → размер: так окно не упирается в край экрана при переносе.
        set(w, kAXSizeAttribute, sv)
        set(w, kAXPositionAttribute, pv)
        set(w, kAXSizeAttribute, sv)
    }

    /// Быстрая установка рамки за два вызова — для анимации.
    static func setFrameFast(_ w: AXUIElement, _ r: CGRect) {
        var p = r.origin, s = r.size
        guard let pv = AXValueCreate(.cgPoint, &p), let sv = AXValueCreate(.cgSize, &s) else { return }
        set(w, kAXPositionAttribute, pv)
        set(w, kAXSizeAttribute, sv)
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
