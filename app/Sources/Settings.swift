import Foundation

enum Settings {
    static var d: UserDefaults { .standard }

    /// Эти приложения автозакрытие не трогает никогда.
    static let alwaysExcluded: Set<String> = ["com.apple.finder", AppInfo.bundleID]

    static func registerDefaults() {
        d.register(defaults: [
            "dock.enabled": true,
            "dock.mode": "minimize",   // "minimize" или "hide"
            "snap.drag": true,         // прилипание окон при перетаскивании к краям
            "window.greenButton": true, // зелёная кнопка разворачивает, не уходя в полноэкранный режим
            "window.animation": true,   // анимация разворачивания
            "snap.enabled": false,     // горячие клавиши ⌃⌥ (по желанию)
            "scroll.enabled": true,
            "scroll.smooth": true,
            "scroll.reverse": true,    // обратное направление только для мыши
            "scroll.reverseZoom": true,  // переворачивать ли и масштаб (⌘/⌃/⌥ + колесо)
            "scroll.speed": 1.0,       // 0.5 … 3
            "scroll.smoothness": 0.5,  // 0 … 1
            "autoquit.enabled": true,
            "autoquit.exclusions": [String](),
            "monitor.enabled": true,
            "monitor.cpu": true,
            "monitor.ram": true,
            "monitor.net": true,
            "monitor.battery": false,
            "monitor.interval": 2.0,
            "shot.enabled": true,
            "shot.openEditor": true,
            "shot.autoCopy": true,
            "shot.sound": true,
            "shot.folder": FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path,
        ])
    }

    static var dockEnabled: Bool {
        get { d.bool(forKey: "dock.enabled") }
        set { d.set(newValue, forKey: "dock.enabled") }
    }
    static var dockMode: String { d.string(forKey: "dock.mode") ?? "minimize" }

    static var dragSnapEnabled: Bool {
        get { d.bool(forKey: "snap.drag") }
        set { d.set(newValue, forKey: "snap.drag") }
    }
    static var greenButtonMaximize: Bool {
        get { d.bool(forKey: "window.greenButton") }
        set { d.set(newValue, forKey: "window.greenButton") }
    }
    static var windowAnimation: Bool { d.bool(forKey: "window.animation") }
    static var snapEnabled: Bool {
        get { d.bool(forKey: "snap.enabled") }
        set { d.set(newValue, forKey: "snap.enabled") }
    }

    static var scrollEnabled: Bool {
        get { d.bool(forKey: "scroll.enabled") }
        set { d.set(newValue, forKey: "scroll.enabled") }
    }
    static var scrollSmooth: Bool { d.bool(forKey: "scroll.smooth") }
    static var scrollReverse: Bool { d.bool(forKey: "scroll.reverse") }
    static var scrollReverseZoom: Bool { d.bool(forKey: "scroll.reverseZoom") }
    static var scrollSpeed: Double { d.double(forKey: "scroll.speed") }
    static var scrollSmoothness: Double { d.double(forKey: "scroll.smoothness") }

    static var autoQuitEnabled: Bool {
        get { d.bool(forKey: "autoquit.enabled") }
        set { d.set(newValue, forKey: "autoquit.enabled") }
    }
    static var monitorEnabled: Bool {
        get { d.bool(forKey: "monitor.enabled") }
        set { d.set(newValue, forKey: "monitor.enabled") }
    }
    static var monitorShowCPU: Bool { d.bool(forKey: "monitor.cpu") }
    static var monitorShowRAM: Bool { d.bool(forKey: "monitor.ram") }
    static var monitorShowNet: Bool { d.bool(forKey: "monitor.net") }
    static var monitorShowBattery: Bool { d.bool(forKey: "monitor.battery") }
    static var monitorInterval: Double { max(1, d.double(forKey: "monitor.interval")) }

    static var shotEnabled: Bool {
        get { d.bool(forKey: "shot.enabled") }
        set { d.set(newValue, forKey: "shot.enabled") }
    }
    static var shotOpenEditor: Bool { d.bool(forKey: "shot.openEditor") }
    static var shotAutoCopy: Bool { d.bool(forKey: "shot.autoCopy") }
    static var shotSound: Bool { d.bool(forKey: "shot.sound") }
    static var shotFolder: String {
        get { d.string(forKey: "shot.folder") ?? NSHomeDirectory() + "/Desktop" }
        set { d.set(newValue, forKey: "shot.folder") }
    }

    static func shotKey(_ mode: ScreenshotModule.Mode) -> HotKey {
        guard let v = d.dictionary(forKey: "shot.key.\(mode.rawValue)"),
              let code = v["code"] as? Int, let mods = v["mods"] as? Int, let label = v["label"] as? String
        else { return mode.defaultKey }
        return HotKey(code: Int64(code), mods: UInt64(mods), label: label)
    }
    static func setShotKey(_ k: HotKey?, for mode: ScreenshotModule.Mode) {
        let key = "shot.key.\(mode.rawValue)"
        if let k {
            d.set(["code": Int(k.code), "mods": Int(k.mods), "label": k.label], forKey: key)
        } else {
            d.removeObject(forKey: key)
        }
    }

    static var autoQuitExclusions: [String] {
        get { d.stringArray(forKey: "autoquit.exclusions") ?? [] }
        set { d.set(newValue, forKey: "autoquit.exclusions") }
    }
}
