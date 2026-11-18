import Cocoa
import Carbon
import QuartzCore

/// Положения окна на экране.
enum SnapAction: CaseIterable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird, leftTwoThirds, rightTwoThirds
    case maximize, center, restore

    var title: String {
        switch self {
        case .leftHalf: L("Левая половина")
        case .rightHalf: L("Правая половина")
        case .topHalf: L("Верхняя половина")
        case .bottomHalf: L("Нижняя половина")
        case .topLeft: L("Левый верхний угол")
        case .topRight: L("Правый верхний угол")
        case .bottomLeft: L("Левый нижний угол")
        case .bottomRight: L("Правый нижний угол")
        case .leftThird: L("Левая треть")
        case .centerThird: L("Средняя треть")
        case .rightThird: L("Правая треть")
        case .leftTwoThirds: L("Левые две трети")
        case .rightTwoThirds: L("Правые две трети")
        case .maximize: L("Развернуть на весь экран")
        case .center: L("По центру")
        case .restore: L("Вернуть как было")
        }
    }

    /// (виртуальный код клавиши, подпись)
    var key: (code: UInt32, label: String) {
        switch self {
        case .leftHalf: (UInt32(kVK_LeftArrow), "←")
        case .rightHalf: (UInt32(kVK_RightArrow), "→")
        case .topHalf: (UInt32(kVK_UpArrow), "↑")
        case .bottomHalf: (UInt32(kVK_DownArrow), "↓")
        case .topLeft: (UInt32(kVK_ANSI_U), "U")
        case .topRight: (UInt32(kVK_ANSI_I), "I")
        case .bottomLeft: (UInt32(kVK_ANSI_J), "J")
        case .bottomRight: (UInt32(kVK_ANSI_K), "K")
        case .leftThird: (UInt32(kVK_ANSI_D), "D")
        case .centerThird: (UInt32(kVK_ANSI_F), "F")
        case .rightThird: (UInt32(kVK_ANSI_G), "G")
        case .leftTwoThirds: (UInt32(kVK_ANSI_E), "E")
        case .rightTwoThirds: (UInt32(kVK_ANSI_T), "T")
        case .maximize: (UInt32(kVK_Return), "↩")
        case .center: (UInt32(kVK_ANSI_C), "C")
        case .restore: (UInt32(kVK_Delete), "⌫")
        }
    }

    var shortcut: String { "⌃⌥" + key.label }
}

final class WindowSnapModule {
    private var tap: CFMachPort?
    private var savedFrames: [CFHashCode: CGRect] = [:]
    private let systemWide = AXUIElementCreateSystemWide()
    private lazy var actionsByKey: [Int64: SnapAction] = {
        Dictionary(uniqueKeysWithValues: SnapAction.allCases.map { (Int64($0.key.code), $0) })
    }()

    // Состояние перетаскивания окна.
    private var dragWindow: AXUIElement?
    private var dragStartFrame: CGRect?
    private var isWindowDrag = false
    private var dragChecks = 0
    private var zone: SnapAction?
    private lazy var overlay = SnapOverlay()
    private var swallowNextMouseUp = false
    private var maximizedFrames: [CFHashCode: CGRect] = [:]

    /// Настройки читаются в момент события, здесь делать нечего.
    func apply() {}

    /// Перехват клавиатуры и мыши. Нужен «Универсальный доступ».
    func start() {
        guard tap == nil else { return }
        AXUIElementSetMessagingTimeout(systemWide, 0.1)
        let types: [CGEventType] = [.keyDown, .leftMouseDown, .leftMouseDragged, .leftMouseUp]
        let mask = types.reduce(CGEventMask(0)) { $0 | CGEventMask(1 << $1.rawValue) }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                let me = Unmanaged<WindowSnapModule>.fromOpaque(refcon!).takeUnretainedValue()
                return me.handle(type, event)
            },
            userInfo: refcon
        ) else {
            Log.write("Окна: НЕ удалось создать перехват")
            return
        }
        tap = t
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        Log.write("Окна: перехват запущен")
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            Log.write("Окна: система отключила перехват, включаю снова")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .leftMouseDown:    if mouseDown(event) { return nil }
        case .leftMouseDragged: mouseDragged(event)
        case .leftMouseUp:
            if swallowNextMouseUp { swallowNextMouseUp = false; return nil }
            mouseUp(event)
        case .keyDown:          return keyDown(event) ? nil : pass
        default: break
        }
        return pass   // мышь никогда не глотаем
    }

    // MARK: - Перетаскивание к краям экрана

    /// Возвращает true, если клик обработан нами и его нужно «проглотить».
    private func mouseDown(_ event: CGEvent) -> Bool {
        resetDrag()
        guard Settings.dragSnapEnabled || Settings.greenButtonMaximize else { return false }
        var hit: AXUIElement?
        let p = event.location
        guard AXUIElementCopyElementAtPosition(systemWide, Float(p.x), Float(p.y), &hit) == .success,
              let el = hit else { return false }

        if Settings.greenButtonMaximize, handleGreenButton(el, event) { return true }
        guard Settings.dragSnapEnabled else { return false }

        let role: String? = AX.attr(el, kAXRoleAttribute)
        let win: AXUIElement? = role == kAXWindowRole ? el : AX.attr(el, kAXWindowAttribute)
        guard let win, (AX.attr(win, kAXSubroleAttribute) as String?) == kAXStandardWindowSubrole,
              let frame = AX.frame(win) else { return false }
        dragWindow = win
        dragStartFrame = frame
        return false
    }

    // MARK: - Зелёная кнопка

    /// Зелёная кнопка: развернуть окно на весь экран, оставив видимыми строку меню и Док.
    /// Повторное нажатие возвращает прежний размер. С зажатой ⌥ кнопка работает как обычно.
    private func handleGreenButton(_ el: AXUIElement, _ event: CGEvent) -> Bool {
        let sub: String? = AX.attr(el, kAXSubroleAttribute)
        guard sub == kAXFullScreenButtonSubrole || sub == kAXZoomButtonSubrole else { return false }
        guard !event.flags.contains(.maskAlternate) else { return false }
        guard let win: AXUIElement = AX.attr(el, kAXWindowAttribute) else { return false }
        // Окно уже в настоящем полноэкранном режиме — пусть кнопка его выключит.
        if (AX.attr(win, "AXFullScreen") as Bool?) == true { return false }
        swallowNextMouseUp = true
        DispatchQueue.main.async { self.toggleMaximize(win) }
        return true
    }

    private func toggleMaximize(_ win: AXUIElement) {
        guard let cur = AX.frame(win) else { return }
        let cocoa = toCocoa(cur)
        guard let screen = screenFor(CGPoint(x: cocoa.midX, y: cocoa.midY)) else { return }
        let target = toAX(screen.visibleFrame.integral)
        let key = CFHash(win)
        if Self.close(cur, target) {
            let old = maximizedFrames.removeValue(forKey: key) ?? {
                // Прежний размер неизвестен — делаем окно поменьше и по центру.
                let v = screen.visibleFrame
                return toAX(CGRect(x: v.minX + v.width * 0.1, y: v.minY + v.height * 0.1,
                                   width: v.width * 0.8, height: v.height * 0.8).integral)
            }()
            Log.write("Окна: зелёная кнопка — вернуть размер")
            resize(win, to: old, systemKey: Int64(kVK_ANSI_R))
        } else {
            maximizedFrames[key] = cur
            Log.write("Окна: зелёная кнопка — развернуть (строка меню и Док видны)")
            resize(win, to: target, systemKey: Int64(kVK_ANSI_F))
        }
    }

    private static func close(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 12 && abs(a.minY - b.minY) < 12
            && abs(a.width - b.width) < 24 && abs(a.height - b.height) < 24
    }

    /// Работает ли в этой системе «Окно → Заполнить» (⌃🌐F). nil — ещё не проверяли.
    private var systemTilingWorks: Bool?
    private var animTimer: Timer?

    /// Меняет размер окна: системной командой с родной анимацией,
    /// а если она не сработала — своей плавной анимацией.
    private func resize(_ win: AXUIElement, to target: CGRect, systemKey: Int64) {
        guard Settings.windowAnimation else { AX.setFrame(win, target); return }
        guard systemTilingWorks != false else { animate(win, to: target); return }

        // Системная команда действует на активное окно — делаем его активным.
        var pid: pid_t = 0
        AXUIElementGetPid(win, &pid)
        if let app = NSRunningApplication(processIdentifier: pid) {
            if #available(macOS 14, *) { app.activate() } else { app.activate(options: []) }
        }
        AXUIElementPerformAction(win, kAXRaiseAction as CFString)
        AX.set(win, kAXMainAttribute, kCFBooleanTrue)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            Self.postGlobeShortcut(systemKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if let f = AX.frame(win), Self.close(f, target) {
                    if self.systemTilingWorks != true { Log.write("Окна: системная анимация работает") }
                    self.systemTilingWorks = true
                } else {
                    Log.write("Окна: системная команда не сработала — включаю свою анимацию")
                    if self.systemTilingWorks == nil { self.systemTilingWorks = false }
                    self.animate(win, to: target)
                }
            }
        }
    }

    /// ⌃ + 🌐 (fn) + клавиша — системные сочетания раскладки окон в macOS 15+.
    private static func postGlobeShortcut(_ key: Int64) {
        let src = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(key), keyDown: down) else { continue }
            e.flags = [.maskControl, .maskSecondaryFn]
            e.post(tap: .cghidEventTap)
        }
    }

    /// Своя плавная анимация (запасной вариант).
    private func animate(_ win: AXUIElement, to target: CGRect) {
        animTimer?.invalidate()
        guard let from = AX.frame(win) else { AX.setFrame(win, target); return }
        let start = CACurrentMediaTime()
        let duration = 0.22
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            let p = min(1, (CACurrentMediaTime() - start) / duration)
            let e = 1 - pow(1 - p, 3)   // плавное замедление в конце
            if p >= 1 {
                AX.setFrame(win, target)
                timer.invalidate()
                self?.animTimer = nil
                return
            }
            let r = CGRect(x: from.minX + (target.minX - from.minX) * e,
                           y: from.minY + (target.minY - from.minY) * e,
                           width: from.width + (target.width - from.width) * e,
                           height: from.height + (target.height - from.height) * e)
            AX.setFrameFast(win, r)
        }
        RunLoop.main.add(t, forMode: .common)
        animTimer = t
    }

    private func mouseDragged(_ event: CGEvent) {
        guard let win = dragWindow, let start = dragStartFrame else { return }

        // Сначала убеждаемся, что тащат именно окно: оно сдвинулось, а размер тот же.
        if !isWindowDrag {
            dragChecks += 1
            guard dragChecks % 2 == 0, let now = AX.frame(win) else { return }
            let moved = abs(now.minX - start.minX) > 2 || abs(now.minY - start.minY) > 2
            let sameSize = abs(now.width - start.width) < 1 && abs(now.height - start.height) < 1
            if moved && sameSize {
                isWindowDrag = true
            } else if !sameSize || dragChecks > 40 {
                resetDrag()   // это изменение размера или выделение текста — не наше дело
                return
            } else {
                return
            }
        }

        let cursor = cocoaPoint(event.location)
        let newZone = zoneFor(cursor)
        guard newZone != zone else { return }
        zone = newZone
        if let newZone, let screen = screenFor(cursor) {
            overlay.show(rect(for: newZone, in: screen.visibleFrame, current: toCocoa(start)))
        } else {
            overlay.hide()
        }
    }

    private func mouseUp(_ event: CGEvent) {
        defer { resetDrag() }
        guard isWindowDrag, let action = zone, let win = dragWindow, let start = dragStartFrame,
              let screen = screenFor(cocoaPoint(event.location)) else { return }
        let target = rect(for: action, in: screen.visibleFrame, current: toCocoa(start))
        let key = CFHash(win)
        if savedFrames[key] == nil { savedFrames[key] = start }
        Log.write("Окна: перетаскивание → \(action.title)")
        // Даём системе закончить перетаскивание, потом ставим окно.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            AX.setFrame(win, self.toAX(target.integral))
        }
    }

    private func resetDrag() {
        dragWindow = nil
        dragStartFrame = nil
        isWindowDrag = false
        dragChecks = 0
        if zone != nil { zone = nil; overlay.hide() }
    }

    /// Зона прилипания для точки курсора (координаты Cocoa).
    private func zoneFor(_ p: CGPoint) -> SnapAction? {
        guard let f = screenFor(p)?.frame else { return nil }
        let edge: CGFloat = 6       // насколько близко к краю
        let corner: CGFloat = 120   // размер угловой зоны вдоль края

        let left = p.x <= f.minX + edge
        let right = p.x >= f.maxX - edge - 1
        let top = p.y >= f.maxY - edge - 1
        let bottom = p.y <= f.minY + edge
        let nearTop = p.y >= f.maxY - corner
        let nearBottom = p.y <= f.minY + corner
        let nearLeft = p.x <= f.minX + corner
        let nearRight = p.x >= f.maxX - corner

        if (left && nearTop) || (top && nearLeft) { return .topLeft }
        if (right && nearTop) || (top && nearRight) { return .topRight }
        if (left && nearBottom) || (bottom && nearLeft) { return .bottomLeft }
        if (right && nearBottom) || (bottom && nearRight) { return .bottomRight }
        if left { return .leftHalf }
        if right { return .rightHalf }
        if top { return .maximize }
        if bottom { return .bottomHalf }
        return nil
    }

    // MARK: - Горячие клавиши (по желанию, по умолчанию выключены)

    private func keyDown(_ event: CGEvent) -> Bool {
        guard Settings.snapEnabled else { return false }
        let f = event.flags
        guard f.contains(.maskControl), f.contains(.maskAlternate),
              !f.contains(.maskCommand), !f.contains(.maskShift) else { return false }
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        guard let action = actionsByKey[code] else { return false }
        if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            DispatchQueue.main.async { self.perform(action) }
        }
        return true
    }

    private func perform(_ action: SnapAction) {
        guard let win = AX.focusedWindow(), let current = AX.frame(win) else { NSSound.beep(); return }
        let key = CFHash(win)
        if action == .restore {
            if let old = savedFrames.removeValue(forKey: key) { AX.setFrame(win, old) }
            return
        }
        if savedFrames[key] == nil { savedFrames[key] = current }
        let cocoa = toCocoa(current)
        guard let screen = screenFor(CGPoint(x: cocoa.midX, y: cocoa.midY)) else { return }
        AX.setFrame(win, toAX(rect(for: action, in: screen.visibleFrame, current: cocoa).integral))
    }

    // MARK: - Геометрия

    /// Целевая рамка (Cocoa) для действия на видимой области экрана v.
    private func rect(for action: SnapAction, in v: CGRect, current: CGRect) -> CGRect {
        let w = v.width, h = v.height
        switch action {
        case .leftHalf:       return CGRect(x: v.minX,         y: v.minY,       width: w / 2,     height: h)
        case .rightHalf:      return CGRect(x: v.minX + w / 2, y: v.minY,       width: w / 2,     height: h)
        case .topHalf:        return CGRect(x: v.minX,         y: v.minY + h/2, width: w,         height: h / 2)
        case .bottomHalf:     return CGRect(x: v.minX,         y: v.minY,       width: w,         height: h / 2)
        case .topLeft:        return CGRect(x: v.minX,         y: v.minY + h/2, width: w / 2,     height: h / 2)
        case .topRight:       return CGRect(x: v.minX + w / 2, y: v.minY + h/2, width: w / 2,     height: h / 2)
        case .bottomLeft:     return CGRect(x: v.minX,         y: v.minY,       width: w / 2,     height: h / 2)
        case .bottomRight:    return CGRect(x: v.minX + w / 2, y: v.minY,       width: w / 2,     height: h / 2)
        case .leftThird:      return CGRect(x: v.minX,         y: v.minY,       width: w / 3,     height: h)
        case .centerThird:    return CGRect(x: v.minX + w / 3, y: v.minY,       width: w / 3,     height: h)
        case .rightThird:     return CGRect(x: v.minX + 2*w/3, y: v.minY,       width: w / 3,     height: h)
        case .leftTwoThirds:  return CGRect(x: v.minX,         y: v.minY,       width: 2 * w / 3, height: h)
        case .rightTwoThirds: return CGRect(x: v.minX + w / 3, y: v.minY,       width: 2 * w / 3, height: h)
        case .maximize, .restore: return v
        case .center:
            let cw = min(current.width, w), ch = min(current.height, h)
            return CGRect(x: v.midX - cw / 2, y: v.midY - ch / 2, width: cw, height: ch)
        }
    }

    private func screenFor(_ p: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.insetBy(dx: -1, dy: -1).contains(p) } ?? NSScreen.main
    }

    private var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    private func cocoaPoint(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: primaryHeight - p.y) }
    private func toAX(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }
    private func toCocoa(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }
}

/// Полупрозрачная подсветка места, куда встанет окно.
final class SnapOverlay {
    private lazy var panel: NSPanel = {
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]

        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 14
        blur.layer?.masksToBounds = true
        blur.layer?.borderWidth = 2
        blur.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.8).cgColor
        blur.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
        p.contentView = blur
        return p
    }()

    func show(_ frame: CGRect) {
        let f = frame.insetBy(dx: 6, dy: 6)
        if panel.isVisible {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                panel.animator().setFrame(f, display: true)
            }
        } else {
            panel.setFrame(f, display: true)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                panel.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
    }
}
