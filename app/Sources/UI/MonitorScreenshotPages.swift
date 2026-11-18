import SwiftUI

// MARK: - Мониторинг

struct MonitorPage: View {
    @ObservedObject private var model = AppDelegate.shared.monitor.model
    @AppStorage("monitor.enabled") private var enabled = true
    @AppStorage("monitor.cpu") private var showCPU = true
    @AppStorage("monitor.ram") private var showRAM = true
    @AppStorage("monitor.net") private var showNet = true
    @AppStorage("monitor.battery") private var showBattery = false
    @AppStorage("monitor.interval") private var interval = 2.0

    var body: some View {
        Form {
            Section { PageHeader(page: .stats) }

            Section {
                Toggle(L("Показывать в строке меню"), isOn: $enabled)
            } footer: {
                Text(L("Нажмите на показатели в строке меню, чтобы открыть подробности."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(L("Что показывать в строке меню")) {
                Toggle(L("Процессор"), isOn: $showCPU)
                Toggle(L("Память"), isOn: $showRAM)
                Toggle(L("Сеть (скорость загрузки и отдачи)"), isOn: $showNet)
                Toggle(L("Батарея"), isOn: $showBattery)
                Picker(L("Обновлять каждые"), selection: $interval) {
                    Text(L("1 секунду")).tag(1.0)
                    Text(L("2 секунды")).tag(2.0)
                    Text(L("5 секунд")).tag(5.0)
                }
            }
            .disabled(!enabled)

            Section(L("Сейчас")) {
                if enabled {
                    MonitorDetails(model: model).padding(.vertical, 6)
                } else {
                    Text(L("Включите модуль, чтобы видеть показатели.")).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Скриншоты

struct ScreenshotPage: View {
    @AppStorage("shot.enabled") private var enabled = true
    @AppStorage("shot.folder") private var folder = NSHomeDirectory() + "/Desktop"
    @State private var hasAccess = ScreenshotModule.hasScreenAccess
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section { PageHeader(page: .screenshots) }

            Section {
                HStack(spacing: 12) {
                    Image(systemName: hasAccess ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(hasAccess ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hasAccess ? L("Запись экрана разрешена") : L("Нужен доступ к записи экрана")).font(.headline)
                        if !hasAccess {
                            Text(L("Включите MacTools в «Запись экрана и звука», затем перезапустите MacTools."))
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if !hasAccess {
                        Button(L("Открыть настройки")) {
                            CGRequestScreenCaptureAccess()
                            ScreenshotModule.openScreenRecordingSettings()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            Section {
                Toggle(L("Горячие клавиши для снимков"), isOn: $enabled)
                ForEach(ScreenshotModule.Mode.allCases, id: \.self) { mode in
                    HStack(spacing: 12) {
                        Image(systemName: mode.symbol).frame(width: 22).foregroundStyle(.pink)
                        Text(mode.title)
                        Spacer()
                        KeyRecorder(mode: mode)
                        Button(L("Снять")) {
                            AppDelegate.shared.screenshots.capture(mode, delay: 0.3)
                        }
                        .disabled(!hasAccess)
                    }
                    .opacity(enabled ? 1 : 0.5)
                }
            } header: {
                Text(L("Сочетания клавиш"))
            } footer: {
                Text(L("Нажмите на сочетание, чтобы задать своё. Нужна хотя бы одна из клавиш ⌘ ⌃ ⌥."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(L("Как пользоваться")) {
                tip("rectangle.dashed", L("Выделите область мышью или просто кликните по окну."))
                tip("arrow.up.left.and.arrow.down.right", L("Тяните за белые квадратики, чтобы изменить размер. Без выбранного инструмента область можно перетаскивать."))
                tip("pencil.tip", L("Справа от области — инструменты: карандаш, линия, стрелка, рамка, маркер, текст, размытие."))
                tip("doc.on.doc", L("⌘C или ↩ — скопировать. ⌘S — сохранить в папку. ⌘Z — отменить. Esc — закрыть."))
            }

            Section(L("Сохранение")) {
                LabeledContent(L("Папка для ⌘S")) {
                    HStack {
                        Text(folder.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        Button(L("Изменить…")) { pickFolder() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(timer) { _ in hasAccess = ScreenshotModule.hasScreenAccess }
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        Label { Text(text).fixedSize(horizontal: false, vertical: true) } icon: {
            Image(systemName: icon).foregroundStyle(.pink)
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: folder)
        panel.prompt = L("Выбрать")
        if panel.runModal() == .OK, let url = panel.url { folder = url.path }
    }
}

/// Кнопка-«записыватель» сочетания клавиш.
struct KeyRecorder: View {
    let mode: ScreenshotModule.Mode
    @State private var key: HotKey
    @State private var recording = false
    @State private var monitor: Any?

    init(mode: ScreenshotModule.Mode) {
        self.mode = mode
        _key = State(initialValue: Settings.shotKey(mode))
    }

    var body: some View {
        HStack(spacing: 4) {
            Button {
                recording ? stop() : start()
            } label: {
                Text(recording ? L("Нажмите сочетание…") : key.display)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .frame(minWidth: 110)
            }
            .buttonStyle(.bordered)
            .tint(recording ? .accentColor : nil)

            if key != mode.defaultKey && !recording {
                Button {
                    Settings.setShotKey(nil, for: mode)
                    key = mode.defaultKey
                } label: { Image(systemName: "arrow.counterclockwise") }
                    .buttonStyle(.plain)
                    .help(L("Вернуть %@", "\(mode.defaultKey.display)"))
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        ScreenshotModule.isRecordingShortcut = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            if e.keyCode == 53 { stop(); return nil }   // Esc — отмена
            let f = e.modifierFlags
            guard f.contains(.command) || f.contains(.control) || f.contains(.option) else {
                NSSound.beep(); return nil
            }
            var flags: CGEventFlags = []
            if f.contains(.control) { flags.insert(.maskControl) }
            if f.contains(.option) { flags.insert(.maskAlternate) }
            if f.contains(.shift) { flags.insert(.maskShift) }
            if f.contains(.command) { flags.insert(.maskCommand) }
            let k = HotKey(code: Int64(e.keyCode), mods: flags.rawValue, label: HotKey.label(for: Int(e.keyCode)))
            Settings.setShotKey(k, for: mode)
            key = k
            Log.write("Скриншоты: новое сочетание для «\(mode.title)» — \(k.display)")
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        ScreenshotModule.isRecordingShortcut = false
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }
}
