import Cocoa
import ApplicationServices

/// Нажали красную кнопку на последнем окне — приложение завершается.
/// Приложения из списка исключений не трогаем.
final class AutoQuitModule {
    private var tap: CFMachPort?
    private let systemWide = AXUIElementCreateSystemWide()
    private var pendingPid: pid_t?

    func start() {
        guard tap == nil else { return }
        AXUIElementSetMessagingTimeout(systemWide, 0.1)
        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
                 | CGEventMask(1 << CGEventType.leftMouseUp.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,           // только наблюдаем, клики не меняем
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                Unmanaged<AutoQuitModule>.fromOpaque(refcon!).takeUnretainedValue().handle(type, event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            Log.write("Автозакрытие: НЕ удалось создать перехват")
            return
        }
        tap = t
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        Log.write("Автозакрытие: перехват запущен")
    }

    static func isExcluded(_ bundleID: String?) -> Bool {
        guard let bundleID else { return true }
        return Settings.alwaysExcluded.contains(bundleID) || Settings.autoQuitExclusions.contains(bundleID)
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .leftMouseDown:
            pendingPid = nil
            guard Settings.autoQuitEnabled else { return }
            let p = event.location
            var hit: AXUIElement?
            guard AXUIElementCopyElementAtPosition(systemWide, Float(p.x), Float(p.y), &hit) == .success,
                  let el = hit,
                  (AX.attr(el, kAXSubroleAttribute) as String?) == kAXCloseButtonSubrole else { return }
            var pid: pid_t = 0
            AXUIElementGetPid(el, &pid)
            guard let app = NSRunningApplication(processIdentifier: pid),
                  app.activationPolicy == .regular else { return }
            if Self.isExcluded(app.bundleIdentifier) {
                Log.write("Автозакрытие: \(app.localizedName ?? "?") в исключениях — не трогаю")
                return
            }
            Log.write("Автозакрытие: нажата красная кнопка в \(app.localizedName ?? "?")")
            pendingPid = pid
        case .leftMouseUp:
            guard let pid = pendingPid else { return }
            pendingPid = nil
            // Даём окну закрыться, потом смотрим, остались ли ещё окна.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.checkAndQuit(pid) }
        default:
            break
        }
    }

    private func checkAndQuit(_ pid: pid_t) {
        guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else {
            Log.write("Автозакрытие: приложение уже закрылось само")
            return
        }
        guard !Self.isExcluded(app.bundleIdentifier) else { return }
        let axApp = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(axApp, 0.5)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else {
            Log.write("Автозакрытие: не удалось узнать окна \(app.localizedName ?? "?"), не трогаю")
            return
        }
        // Некоторые приложения (Discord, Slack и др.) по красной кнопке не закрывают окно,
        // а прячут себя целиком. Это тоже значит «пользователь закрыл последнее окно».
        if app.isHidden {
            Log.write("Автозакрытие: \(app.localizedName ?? "?") спряталось вместо закрытия — завершаю")
            app.terminate()
            return
        }
        // Считаем любые окна, включая свёрнутые: если хоть что-то осталось — не закрываем.
        if windows.isEmpty {
            Log.write("Автозакрытие: последнее окно \(app.localizedName ?? "?") закрыто — завершаю")
            app.terminate()
        } else {
            Log.write("Автозакрытие: у \(app.localizedName ?? "?") осталось окон: \(windows.count)")
        }
    }
}
