import Cocoa
import SwiftUI
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    let dock = DockModule()
    let snap = WindowSnapModule()
    let scroll = ScrollModule()
    let autoQuit = AutoQuitModule()
    let monitor = MonitorModule()
    let screenshots = ScreenshotModule()

    /// Доступ к модулям из интерфейса.
    static private(set) var shared: AppDelegate!

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()
        Log.write("=== Запуск \(AppInfo.name) \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "") из \(Bundle.main.bundlePath), доступ=\(AX.isTrusted), док=\(Settings.dockEnabled), окна=\(Settings.snapEnabled)")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let icon = NSImage(named: "MenuIcon") ?? NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: AppInfo.name)
        icon?.isTemplate = true
        icon?.size = NSSize(width: 18, height: 18)
        statusItem.button?.image = icon
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        snap.apply()
        monitor.apply()   // мониторингу «Универсальный доступ» не нужен
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.snap.apply()
            self?.monitor.apply()
        }

        requestAccessibility()

        // Окно показываем при первом запуске и пока нет доступа.
        // При автозапуске с уже выданным доступом — тихо сидим в строке меню.
        let firstLaunch = !UserDefaults.standard.bool(forKey: "app.launchedBefore")
        UserDefaults.standard.set(true, forKey: "app.launchedBefore")
        if firstLaunch || !AX.isTrusted { openSettings() }

        // Отладка: --snapshot <файл.png> сохраняет снимок окна настроек и выходит.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            let path = args[i + 1]
            openSettings()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                if let num = self?.settingsWindow?.windowNumber,
                   let cg = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(num), [.boundsIgnoreFraming]) {
                    let rep = NSBitmapImageRep(cgImage: cg)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
                }
                NSApp.terminate(nil)
            }
        }
    }

    // MARK: - Доступ

    private func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        Log.write("Проверяю доступ…")
        if AXIsProcessTrustedWithOptions([key: true] as CFDictionary) {
            startModules()
            return
        }
        // Ждём, пока пользователь включит доступ в Настройках.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
            guard AX.isTrusted else { return }
            Log.write("Доступ выдан")
            t.invalidate()
            self?.startModules()
        }
    }

    private func startModules() {
        dock.start()
        snap.start()
        scroll.start()
        autoQuit.start()
        screenshots.start()
    }

    // MARK: - Меню в строке меню

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let title = NSMenuItem(title: AppInfo.name, action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        if !AX.isTrusted {
            menu.addItem(item(L("⚠️ Дать доступ «Универсальный доступ»…"), #selector(openAccess)))
        }
        menu.addItem(.separator())

        let dockItem = item(L("Клик по Доку сворачивает окна"), #selector(toggleDock))
        dockItem.state = Settings.dockEnabled ? .on : .off
        menu.addItem(dockItem)

        let snapItem = item(L("Окна прилипают к краям экрана"), #selector(toggleSnap))
        snapItem.state = Settings.dragSnapEnabled ? .on : .off
        menu.addItem(snapItem)

        let scrollItem = item(L("Плавная прокрутка мыши"), #selector(toggleScroll))
        scrollItem.state = Settings.scrollEnabled ? .on : .off
        menu.addItem(scrollItem)

        let quitItem = item(L("Автозакрытие по красной кнопке"), #selector(toggleAutoQuit))
        quitItem.state = Settings.autoQuitEnabled ? .on : .off
        menu.addItem(quitItem)

        let monItem = item(L("Мониторинг в строке меню"), #selector(toggleMonitor))
        monItem.state = Settings.monitorEnabled ? .on : .off
        menu.addItem(monItem)

        menu.addItem(.separator())
        for mode in ScreenshotModule.Mode.allCases {
            let i = item("\(mode.title)  \(Settings.shotKey(mode).display)", #selector(takeShot(_:)))
            i.representedObject = mode.rawValue
            i.image = NSImage(systemSymbolName: mode.symbol, accessibilityDescription: nil)
            menu.addItem(i)
        }

        menu.addItem(.separator())
        menu.addItem(item(L("Открыть MacTools…"), #selector(openSettings), key: ","))

        let login = item(L("Запускать при входе"), #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item(L("Выйти из MacTools"), #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc private func openAccess() { AX.openAccessibilitySettings() }
    @objc private func toggleDock() { Settings.dockEnabled.toggle() }
    @objc private func toggleSnap() { Settings.dragSnapEnabled.toggle() }
    @objc private func toggleScroll() { Settings.scrollEnabled.toggle() }
    @objc private func toggleAutoQuit() { Settings.autoQuitEnabled.toggle() }
    @objc private func toggleMonitor() { Settings.monitorEnabled.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func takeShot(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String,
              let mode = ScreenshotModule.Mode(rawValue: key) else { return }
        screenshots.capture(mode, delay: 0.25)   // даём меню закрыться
    }

    @objc private func toggleLogin() {
        let svc = SMAppService.mainApp
        do {
            if svc.status == .enabled { try svc.unregister() } else { try svc.register() }
        } catch {
            let alert = NSAlert()
            alert.messageText = L("Не удалось изменить автозапуск")
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 600),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = AppInfo.name
            w.titlebarAppearsTransparent = true
            let host = NSHostingView(rootView: MainView())
            if #available(macOS 14.0, *) { host.sceneBridgingOptions = [.title, .toolbars] }
            w.contentView = host
            w.toolbarStyle = .unified
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.setFrameAutosaveName("MacToolsMain")
            if !w.setFrameUsingName("MacToolsMain") { w.center() }
            settingsWindow = w
        }
        // Пока окно открыто — значок в Доке и обычное меню, как у всех приложений.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // Окно закрыли — снова живём только в строке меню.
    func windowWillClose(_ notification: Notification) {
        AppWindows.updateActivationPolicy(closing: notification.object as? NSWindow)
    }

    // Повторный запуск из «Программ»/Spotlight, когда приложение уже работает.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }
}
