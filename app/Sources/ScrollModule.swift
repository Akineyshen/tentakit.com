import Cocoa

/// Плавная прокрутка колесом мыши и отдельное направление для мыши.
/// Трекпад (непрерывная прокрутка) не трогаем.
final class ScrollModule {
    private var tap: CFMachPort?
    private static let marker: Int64 = 0x4D54_5343   // метка наших собственных событий
    private var remainingY = 0.0, remainingX = 0.0
    private var carryY = 0.0, carryX = 0.0
    private var timer: Timer?
    private var loggedWheel = false
    private var loggedContinuous = false
    private var zoomLogged = 0

    func start() {
        guard tap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                Unmanaged<ScrollModule>.fromOpaque(refcon!).takeUnretainedValue().handle(type, event)
            },
            userInfo: refcon
        ) else {
            Log.write("Прокрутка: НЕ удалось создать перехват")
            return
        }
        tap = t
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        Log.write("Прокрутка: перехват запущен")
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Log.write("Прокрутка: система отключила перехват (\(type.rawValue)), включаю снова")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        guard type == .scrollWheel else { return pass }
        if event.getIntegerValueField(.eventSourceUserData) == Self.marker { return pass }
        diagnose(event)
        guard Settings.scrollEnabled else { return pass }
        // Трекпад (и Magic Mouse) всегда присылают фазу жеста — их не трогаем.
        // Колесо мыши: либо «щелчки» (не непрерывная), либо непрерывная без фазы —
        // так прокрутку отправляет Logi Options+.
        let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
        let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        if continuous && (phase != 0 || momentum != 0) { return pass }

        let reverse = Settings.scrollReverse
        if !loggedWheel {
            loggedWheel = true
            Log.write("Прокрутка: колесо мыши обнаружено (\(continuous ? "через Logi" : "щелчки"), плавность=\(Settings.scrollSmooth), обратное=\(reverse))")
        }
        // Logi Options+ может присылать события без флагов клавиш —
        // поэтому смотрим ещё и на реальное состояние клавиатуры.
        let zoomMask: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate]
        let live = CGEventSource.flagsState(.combinedSessionState)
        let mods = event.flags.union(live).intersection(zoomMask)

        // С ⌘/⌃/⌥ колесо обычно меняет масштаб — не сглаживаем,
        // направление переворачиваем только если так сказано в настройках.
        if !mods.isEmpty {
            let flip = reverse && Settings.scrollReverseZoom
            if zoomLogged < 6 {
                zoomLogged += 1
                Log.write("Прокрутка[масштаб]: флаги события=\(String(event.flags.rawValue, radix: 16)) клавиатура=\(String(live.rawValue, radix: 16)) пиксели=\(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)) переворот=\(flip) приложение=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?")")
            }
            if flip { Self.invert(event) }
            event.flags = event.flags.union(mods)
            return pass
        }
        // Без плавности — только направление.
        if !Settings.scrollSmooth {
            if reverse { Self.invert(event) }
            return pass
        }

        var dy: Double, dx: Double
        if continuous {
            // Logi уже прислал пиксели — берём их, с поправкой на скорость.
            let k = 2.0 * Settings.scrollSpeed
            dy = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)) * k
            dx = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)) * k
        } else {
            let step = 48.0 * Settings.scrollSpeed
            dy = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1)) * step
            dx = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2)) * step
        }
        if event.flags.contains(.maskShift) && dx == 0 { dx = dy; dy = 0 }   // ⇧ + колесо = вбок
        let sign = reverse ? -1.0 : 1.0
        add(&remainingY, dy * sign)
        add(&remainingX, dx * sign)
        startTimer()
        return nil   // исходный «рывок» заменяем плавной анимацией
    }

    /// Подробно записывает первые события прокрутки — для диагностики.
    private var diagnosed = 0
    private func diagnose(_ e: CGEvent) {
        guard diagnosed < 25 else { return }
        diagnosed += 1
        let pid = pid_t(e.getIntegerValueField(.eventSourceUnixProcessID))
        let src = pid == 0 ? "железо" : (NSRunningApplication(processIdentifier: pid)?.localizedName ?? "pid \(pid)")
        Log.write("Прокрутка[диаг]: непрерывная=\(e.getIntegerValueField(.scrollWheelEventIsContinuous)) "
            + "строки=\(e.getIntegerValueField(.scrollWheelEventDeltaAxis1)) "
            + "пиксели=\(e.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)) "
            + "фаза=\(e.getIntegerValueField(.scrollWheelEventScrollPhase)) "
            + "инерция=\(e.getIntegerValueField(.scrollWheelEventMomentumPhase)) "
            + "источник=\(src) модуль=\(Settings.scrollEnabled) плавно=\(Settings.scrollSmooth)")
    }

    private func add(_ remaining: inout Double, _ delta: Double) {
        guard delta != 0 else { return }
        // Сменили направление — сразу едем в новую сторону.
        if remaining != 0 && (remaining > 0) != (delta > 0) { remaining = 0 }
        remaining += delta
    }

    private func startTimer() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        // Чем больше плавность, тем меньшая доля пути проходится за кадр.
        let k = 0.08 + (1.0 - Settings.scrollSmoothness) * 0.32
        let sy = abs(remainingY) < 1 ? remainingY : remainingY * k
        let sx = abs(remainingX) < 1 ? remainingX : remainingX * k
        remainingY -= sy
        remainingX -= sx
        carryY += sy
        carryX += sx
        let iy = Int32(carryY.rounded(.towardZero))
        let ix = Int32(carryX.rounded(.towardZero))
        carryY -= Double(iy)
        carryX -= Double(ix)
        if iy != 0 || ix != 0 { post(iy, ix) }

        if abs(remainingY) < 0.5 && abs(remainingX) < 0.5 {
            remainingY = 0; remainingX = 0; carryY = 0; carryX = 0
            timer?.invalidate()
            timer = nil
        }
    }

    private func post(_ dy: Int32, _ dx: Int32) {
        guard let e = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                              wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0) else { return }
        e.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        e.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        if let loc = CGEvent(source: nil)?.location { e.location = loc }
        e.flags = []
        e.post(tap: .cgSessionEventTap)
    }

    private static func invert(_ e: CGEvent) {
        let axes: [(CGEventField, CGEventField, CGEventField)] = [
            (.scrollWheelEventDeltaAxis1, .scrollWheelEventPointDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1),
            (.scrollWheelEventDeltaAxis2, .scrollWheelEventPointDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2),
        ]
        for (d, p, f) in axes {
            e.setIntegerValueField(d, value: -e.getIntegerValueField(d))
            e.setIntegerValueField(p, value: -e.getIntegerValueField(p))
            e.setDoubleValueField(f, value: -e.getDoubleValueField(f))
        }
    }
}
