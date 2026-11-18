import Cocoa
import ApplicationServices

/// Клик по значку активного приложения в Доке сворачивает его окна,
/// повторный клик — разворачивает их обратно.
final class DockModule {
    private var tap: CFMachPort?
    private var swallowNextMouseUp = false
    private let systemWide = AXUIElementCreateSystemWide()

    var isRunning: Bool { tap != nil }

    func start() {
        guard tap == nil else { return }
        AXUIElementSetMessagingTimeout(systemWide, 0.1)

        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
                 | CGEventMask(1 << CGEventType.leftMouseUp.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                let me = Unmanaged<DockModule>.fromOpaque(refcon!).takeUnretainedValue()
                return me.handle(type, event)
            },
            userInfo: refcon
        ) else {
            Log.write("Док: НЕ удалось создать перехват кликов (нет доступа?)")
            return
        }
        tap = t
        let src = CFMachPortCreateRunLoopSource(nil, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        Log.write("Док: перехват кликов запущен")
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            Log.write("Док: система отключила перехват (\(type.rawValue)), включаю снова")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        case .leftMouseUp:
            if swallowNextMouseUp { swallowNextMouseUp = false; return nil }
            return pass
        case .leftMouseDown:
            break
        default:
            return pass
        }

        guard Settings.dockEnabled else { return pass }
        // С зажатыми ⌘/⌥/⌃/⇧ Док работает как обычно.
        let mods = event.flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
        guard mods.isEmpty else { return pass }

        guard let app = dockApp(at: event.location) else { return pass }
        guard !app.isHidden else { Log.write("Док: \(app.localizedName ?? "?") скрыто — обычный клик"); return pass }

        let isFront = NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
        let wins = AX.windows(pid: app.processIdentifier)
        let visible = wins.filter { !AX.isMinimized($0) }
        let minimized = wins.filter { AX.isMinimized($0) }

        Log.write("Док: \(app.localizedName ?? "?") активно=\(isFront) окон=\(wins.count) видимых=\(visible.count) свёрнутых=\(minimized.count)")

        // 1-й клик: приложение активно и его окна видны → свернуть.
        if isFront && !visible.isEmpty {
            swallowNextMouseUp = true
            let mode = Settings.dockMode
            DispatchQueue.main.async {
                if mode == "hide" {
                    app.hide()
                } else {
                    visible.forEach { AX.setMinimized($0, true) }
                }
            }
            return nil
        }

        // 2-й клик: все окна свёрнуты → развернуть все.
        if visible.isEmpty && !minimized.isEmpty {
            swallowNextMouseUp = true
            DispatchQueue.main.async {
                if #available(macOS 14, *) { app.activate() } else { app.activate(options: []) }
                minimized.forEach { AX.setMinimized($0, false) }
            }
            return nil
        }

        return pass
    }

    /// Какое запущенное приложение находится под курсором в Доке.
    private func dockApp(at p: CGPoint) -> NSRunningApplication? {
        guard let dockPid = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
        else { return nil }

        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(p.x), Float(p.y), &hit) == .success,
              let el = hit else { return nil }

        var pid: pid_t = 0
        AXUIElementGetPid(el, &pid)
        guard pid == dockPid else { return nil }
        let role: String = AX.attr(el, kAXRoleAttribute) ?? "-"
        let sub: String = AX.attr(el, kAXSubroleAttribute) ?? "-"
        let url: URL? = AX.attr(el, kAXURLAttribute)
        Log.write("Док: клик по элементу role=\(role) subrole=\(sub) url=\(url?.path ?? "нет")")
        guard sub == "AXApplicationDockItem", let url else { return nil }

        let path = url.standardizedFileURL.path
        let app = NSWorkspace.shared.runningApplications.first {
            $0.bundleURL?.standardizedFileURL.path == path
        }
        if app == nil { Log.write("Док: приложение не запущено — обычный клик") }
        return app
    }
}
