import Cocoa
import Carbon
import ScreenCaptureKit

/// Сочетание клавиш.
struct HotKey: Equatable {
    var code: Int64
    var mods: UInt64   // CGEventFlags: только ⌃⌥⇧⌘
    var label: String

    static let relevant: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]

    var display: String {
        let f = CGEventFlags(rawValue: mods)
        var s = ""
        if f.contains(.maskControl) { s += "⌃" }
        if f.contains(.maskAlternate) { s += "⌥" }
        if f.contains(.maskShift) { s += "⇧" }
        if f.contains(.maskCommand) { s += "⌘" }
        return s + label
    }

    func matches(_ e: CGEvent) -> Bool {
        e.getIntegerValueField(.keyboardEventKeycode) == code
            && e.flags.intersection(Self.relevant).rawValue == mods
    }

    /// Подпись клавиши по её коду (не зависит от раскладки).
    static func label(for code: Int) -> String {
        let special: [Int: String] = [
            36: "↩", 48: "⇥", 49: L("Пробел"), 51: "⌫", 53: "⎋", 117: "⌦",
            123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End", 116: "PgUp", 121: "PgDn",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        ]
        let ansi: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B",
            12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4",
            22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
            32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
            43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 50: "`",
        ]
        return special[code] ?? ansi[code] ?? L("Клавиша %@", "\(code)")
    }
}

/// Снимки экрана как в Lightshot: затемнение, выделение и редактирование прямо на экране.
final class ScreenshotModule {
    enum Mode: String, CaseIterable {
        case area, screen

        var title: String {
            switch self {
            case .area: L("Снимок области или окна")
            case .screen: L("Снимок всего экрана")
            }
        }
        var symbol: String {
            switch self {
            case .area: "rectangle.dashed"
            case .screen: "display"
            }
        }
        var defaultKey: HotKey {
            let mods = CGEventFlags([.maskControl, .maskShift]).rawValue
            switch self {
            case .area: return HotKey(code: Int64(kVK_ANSI_1), mods: mods, label: "1")
            case .screen: return HotKey(code: Int64(kVK_ANSI_2), mods: mods, label: "2")
            }
        }
    }

    /// Пока в настройках записывается новое сочетание — не перехватываем клавиши.
    static var isRecordingShortcut = false

    private var tap: CFMachPort?
    private var busy = false

    static var hasScreenAccess: Bool { CGPreflightScreenCaptureAccess() }

    static func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func start() {
        guard tap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                Unmanaged<ScreenshotModule>.fromOpaque(refcon!).takeUnretainedValue().handle(type, event)
            },
            userInfo: refcon
        ) else {
            Log.write("Скриншоты: НЕ удалось создать перехват клавиш")
            return
        }
        tap = t
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        Log.write("Скриншоты: горячие клавиши запущены, запись экрана=\(Self.hasScreenAccess)")
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        guard type == .keyDown, Settings.shotEnabled, !Self.isRecordingShortcut else { return pass }
        guard let mode = Mode.allCases.first(where: { Settings.shotKey($0).matches(event) }) else { return pass }
        if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            DispatchQueue.main.async { self.capture(mode) }
        }
        return nil
    }

    func capture(_ mode: Mode, delay: Double = 0) {
        guard !busy else { return }
        guard Self.hasScreenAccess else {
            Log.write("Скриншоты: нет доступа к записи экрана")
            CGRequestScreenCaptureAccess()
            let alert = NSAlert()
            alert.messageText = L("Нужен доступ к записи экрана")
            alert.informativeText = L("Включите MacTools в «Конфиденциальность и безопасность → Запись экрана», затем перезапустите MacTools.")
            alert.addButton(withTitle: L("Открыть настройки"))
            alert.addButton(withTitle: L("Позже"))
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn { Self.openScreenRecordingSettings() }
            return
        }
        busy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self.grabAndShow(mode) }
    }

    /// Снимает экран под курсором и показывает поверх него режим выделения.
    private func grabAndShow(_ mode: Mode) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main,
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        else { busy = false; return }
        let windows = Self.windowRects(on: screen)

        Task {
            do {
                let image = try await Self.grab(displayID: displayID, screen: screen)
                await MainActor.run {
                    self.busy = false
                    Log.write("Скриншоты: \(mode.title), экран \(image.width)×\(image.height)")
                    ScreenshotOverlay(image: image, screen: screen, windows: windows, fullScreen: mode == .screen).show()
                }
            } catch {
                await MainActor.run {
                    self.busy = false
                    Log.write("Скриншоты: не удалось снять экран: \(error.localizedDescription)")
                }
            }
        }
    }

    private static func grab(displayID: CGDirectDisplayID, screen: NSScreen) async throws -> CGImage {
        guard #available(macOS 14.0, *) else {
            throw NSError(domain: "MacTools", code: 1, userInfo: [NSLocalizedDescriptionKey: L("Нужна macOS 14 или новее")])
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw NSError(domain: "MacTools", code: 2, userInfo: [NSLocalizedDescriptionKey: L("Экран не найден")])
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let cfg = SCStreamConfiguration()
        let scale = screen.backingScaleFactor
        cfg.width = Int(screen.frame.width * scale)
        cfg.height = Int(screen.frame.height * scale)
        cfg.showsCursor = false
        cfg.captureResolution = .best
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg)
    }

    /// Рамки обычных окон на экране (в точках, от левого верхнего угла экрана), спереди назад.
    private static func windowRects(on screen: NSScreen) -> [CGRect] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return [] }
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        let originX = screen.frame.minX
        let originY = primaryH - screen.frame.maxY
        let local = CGRect(origin: .zero, size: screen.frame.size)
        return list.compactMap { w in
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  (w[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let b = w[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: b as CFDictionary),
                  r.width > 40, r.height > 40 else { return nil }
            let l = r.offsetBy(dx: -originX, dy: -originY).intersection(local)
            return l.isNull || l.width < 40 || l.height < 40 ? nil : l
        }
    }
}

/// Готовый снимок и действия с ним.
struct Screenshot {
    let image: CGImage
    let pointSize: CGSize

    func copyToClipboard() {
        let ns = NSImage(cgImage: image, size: pointSize)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([ns])
    }

    /// Сохраняет PNG в папку из настроек. Возвращает путь или nil.
    func save() -> URL? {
        let folder = URL(fileURLWithPath: Settings.shotFolder, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'в' HH.mm.ss"
        let url = folder.appendingPathComponent(L("Скриншот %@.png", "\(f.string(from: Date()))"))
        let rep = NSBitmapImageRep(cgImage: image)
        rep.size = pointSize   // чтобы на Retina картинка открывалась в правильном размере
        guard let data = rep.representation(using: .png, properties: [:]) else { return nil }
        do {
            try data.write(to: url)
            Log.write("Скриншоты: сохранено \(url.path)")
            return url
        } catch {
            Log.write("Скриншоты: не удалось сохранить: \(error.localizedDescription)")
            return nil
        }
    }
}
