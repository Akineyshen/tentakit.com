import SwiftUI

/// Главное окно в стиле «Системных настроек».
struct MainView: View {
    @StateObject private var status = AppStatus()
    @State private var selection: Page? = MainView.startPage

    /// Раздел при открытии (для отладки: --page dock).
    static var startPage: Page {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--page"), i + 1 < args.count, let p = Page(rawValue: args[i + 1]) { return p }
        return .overview
    }
    @State private var search = ""
    @AppStorage(Lang.key) private var language = "auto"

    private static let groups: [[Page]] = [
        [.dock, .windows, .scroll, .autoquit],
        [.stats, .screenshots, .cleaner],
        [.general],
    ]

    private func matches(_ p: Page) -> Bool {
        let q = search.trimmingCharacters(in: .whitespaces)
        return q.isEmpty || p.title.localizedCaseInsensitiveContains(q) || p.summary.localizedCaseInsensitiveContains(q)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                if search.isEmpty {
                    AppCardRow().tag(Page.overview)
                }
                ForEach(Array(Self.groups.enumerated()), id: \.offset) { _, group in
                    let pages = group.filter(matches)
                    if !pages.isEmpty {
                        Section { ForEach(pages) { row($0) } }
                    }
                }
            }
            .searchable(text: $search, placement: .sidebar, prompt: L("Поиск"))
            .navigationSplitViewColumnWidth(min: 215, ideal: 235, max: 300)
        } detail: {
            detail(for: selection ?? .overview)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle((selection ?? .overview) == .overview ? AppInfo.name : (selection ?? .overview).title)
        }
        .id(language)
        .environmentObject(status)
        .frame(minWidth: 760, minHeight: 540)
    }

    private func row(_ p: Page) -> some View {
        Label {
            Text(p.title)
        } icon: {
            PageIcon(page: p, size: 22)
        }
        .tag(p)
    }

    @ViewBuilder
    private func detail(for page: Page) -> some View {
        switch page {
        case .overview: OverviewPage(selection: $selection)
        case .dock: DockPage()
        case .windows: WindowsPage()
        case .scroll: ScrollPage()
        case .autoquit: AutoQuitPage()
        case .cleaner: CleanerPage()
        case .stats: MonitorPage()
        case .screenshots: ScreenshotPage()
        case .general: GeneralPage()
        }
    }
}

/// Карточка приложения вверху боковой панели — как карточка Apple ID.
struct AppCardRow: View {
    @EnvironmentObject var status: AppStatus

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(AppInfo.name).font(.system(size: 13, weight: .semibold))
                HStack(spacing: 4) {
                    Circle().fill(status.trusted ? Color.green : Color.orange).frame(width: 6, height: 6)
                    Text(status.trusted ? L("Всё работает") : L("Нужен доступ"))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Обзор

struct OverviewPage: View {
    @Binding var selection: Page?
    @EnvironmentObject var status: AppStatus
    @AppStorage("dock.enabled") private var dockEnabled = true
    @AppStorage("snap.drag") private var snapEnabled = true
    @AppStorage("scroll.enabled") private var scrollEnabled = true
    @AppStorage("autoquit.enabled") private var autoQuitEnabled = true
    @AppStorage("monitor.enabled") private var monitorEnabled = true
    @AppStorage("shot.enabled") private var shotEnabled = true

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable().frame(width: 72, height: 72)
                    Text(AppInfo.name).font(.title2.bold())
                    Text(L("Все нужные утилиты в одном приложении"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            if !status.trusted {
                Section { PermissionBanner() }
            }

            Section(L("Модули")) {
                ModuleRow(page: .dock, isOn: $dockEnabled, selection: $selection)
                ModuleRow(page: .windows, isOn: $snapEnabled, selection: $selection)
                ModuleRow(page: .scroll, isOn: $scrollEnabled, selection: $selection)
                ModuleRow(page: .autoquit, isOn: $autoQuitEnabled, selection: $selection)
            }
            Section {
                ModuleRow(page: .stats, isOn: $monitorEnabled, selection: $selection)
                ModuleRow(page: .screenshots, isOn: $shotEnabled, selection: $selection)
                ModuleRow(page: .cleaner, isOn: nil, selection: $selection)
            }
        }
        .formStyle(.grouped)
    }
}

/// Строка модуля: значок, название, описание и переключатель — как в Настройках.
struct ModuleRow: View {
    let page: Page
    let isOn: Binding<Bool>?
    @Binding var selection: Page?

    var body: some View {
        HStack(spacing: 12) {
            Button { selection = page } label: {
                HStack(spacing: 12) {
                    PageIcon(page: page, size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(page.title)
                        Text(page.summary)
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let isOn {
                Toggle("", isOn: isOn).toggleStyle(.switch).labelsHidden().controlSize(.small)
            } else {
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Док

struct DockPage: View {
    @AppStorage("dock.enabled") private var enabled = true
    @AppStorage("dock.mode") private var mode = "minimize"

    var body: some View {
        Form {
            Section { PageHeader(page: .dock) }

            Section {
                Toggle(L("Включить модуль"), isOn: $enabled)
                Picker(L("При первом клике"), selection: $mode) {
                    Text(L("Свернуть окна в Док")).tag("minimize")
                    Text(L("Скрыть приложение (как ⌘H)")).tag("hide")
                }
                .pickerStyle(.radioGroup)
                .disabled(!enabled)
            }

            Section(L("Как это работает")) {
                step(1, L("Нажмите на значок активного приложения в Доке: его окна свернутся."))
                step(2, L("Нажмите ещё раз: все окна развернутся обратно."))
                step(3, L("С зажатой ⌘, ⌥, ⌃ или ⇧ Док работает как обычно."))
            }
        }
        .formStyle(.grouped)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(n)")
                .font(.caption.bold()).foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue.gradient))
            Text(text)
        }
    }
}

// MARK: - Раскладка окон

struct WindowsPage: View {
    @AppStorage("snap.drag") private var dragEnabled = true
    @AppStorage("snap.enabled") private var keysEnabled = false
    @AppStorage("window.greenButton") private var greenButton = true
    @AppStorage("window.animation") private var animation = true

    private let zones: [(place: String, action: SnapAction)] = [
        (L("К левому краю"), .leftHalf),
        (L("К правому краю"), .rightHalf),
        (L("К верхнему краю"), .maximize),
        (L("К нижнему краю"), .bottomHalf),
        (L("В левый верхний угол"), .topLeft),
        (L("В правый верхний угол"), .topRight),
        (L("В левый нижний угол"), .bottomLeft),
        (L("В правый нижний угол"), .bottomRight),
    ]

    var body: some View {
        Form {
            Section { PageHeader(page: .windows) }

            Section {
                Toggle(L("Окна прилипают к краям экрана"), isOn: $dragEnabled)
            } footer: {
                Text(L("Тащите окно за заголовок. Когда курсор коснётся края или угла, появится подсветка. Отпустите, и окно встанет на это место."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Toggle(L("Зелёная кнопка разворачивает окно, не скрывая строку меню и Док"), isOn: $greenButton)
                Toggle(L("Анимация, как в системе"), isOn: $animation)
                    .disabled(!greenButton)
            } header: {
                Text(L("Зелёная кнопка"))
            } footer: {
                Text(L("Окно займёт весь экран, но строка меню сверху и Док останутся видны. Повторное нажатие вернёт прежний размер. С зажатой ⌥ кнопка работает как обычно."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(L("Куда тащить")) {
                ForEach(zones, id: \.place) { z in
                    HStack(spacing: 12) {
                        SnapPreview(rect: z.action.unitRect)
                        Text(z.place)
                        Spacer()
                        Text(z.action.title).foregroundStyle(.secondary)
                    }
                    .opacity(dragEnabled ? 1 : 0.4)
                }
            }

            Section {
                Toggle(L("Горячие клавиши ⌃⌥ (дополнительно)"), isOn: $keysEnabled)
                if keysEnabled {
                    ForEach(SnapAction.allCases, id: \.self) { a in
                        HStack(spacing: 12) {
                            SnapPreview(rect: a.unitRect)
                            Text(a.title)
                            Spacer()
                            HStack(spacing: 3) {
                                KeyCap(text: "⌃"); KeyCap(text: "⌥"); KeyCap(text: a.key.label)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Основные

struct GeneralPage: View {
    @EnvironmentObject var status: AppStatus
    @AppStorage(Lang.key) private var language = "auto"

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        Form {
            Section { PageHeader(page: .general) }

            Section(L("Язык")) {
                Picker(L("Язык"), selection: $language) {
                    Text(L("Как в системе")).tag("auto")
                    Text("Polski").tag("pl")
                    Text("Русский").tag("ru")
                    Text("English").tag("en")
                }
            }

            Section(L("Запуск")) {
                Toggle(L("Запускать MacTools при входе в систему"), isOn: Binding(
                    get: { status.launchAtLogin },
                    set: { status.setLaunchAtLogin($0) }))
            }

            Section(L("Доступ")) {
                PermissionBanner()
            }

            Section(L("О приложении")) {
                LabeledContent(L("Версия"), value: version)
                LabeledContent(L("Модулей"), value: "\(Page.modules.count)")
            }

            Section {
                Button(L("Выйти из MacTools"), role: .destructive) { NSApp.terminate(nil) }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Скоро

struct ComingSoonPage: View {
    let page: Page

    var body: some View {
        VStack(spacing: 14) {
            PageIcon(page: page, size: 72)
            Text(page.title).font(.title.bold())
            Text(page.summary).foregroundStyle(.secondary).multilineTextAlignment(.center)
            SoonBadge().padding(.top, 4)
            Text(L("Этот модуль появится в следующих версиях."))
                .font(.callout).foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(maxWidth: 420)
    }
}
