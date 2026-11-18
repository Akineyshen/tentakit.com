import SwiftUI
import UniformTypeIdentifiers

// MARK: - Прокрутка мыши

struct ScrollPage: View {
    @AppStorage("scroll.enabled") private var enabled = true
    @AppStorage("scroll.smooth") private var smooth = true
    @AppStorage("scroll.reverse") private var reverse = true
    @AppStorage("scroll.reverseZoom") private var reverseZoom = true
    @AppStorage("scroll.speed") private var speed = 1.0
    @AppStorage("scroll.smoothness") private var smoothness = 0.5

    var body: some View {
        Form {
            Section { PageHeader(page: .scroll) }

            Section {
                Toggle(L("Включить модуль"), isOn: $enabled)
            } footer: {
                Text(L("Работает только для колеса мыши. Трекпад не затрагивается."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(L("Направление")) {
                Toggle(L("Обратное направление для мыши"), isOn: $reverse)
                Toggle(L("Переворачивать и масштаб (⌘ / ⌃ / ⌥ + колесо)"), isOn: $reverseZoom)
                    .disabled(!reverse)
            }
            .disabled(!enabled)

            Section(L("Плавность")) {
                Toggle(L("Плавная прокрутка"), isOn: $smooth)
                LabeledContent(L("Скорость")) {
                    HStack {
                        Image(systemName: "tortoise").foregroundStyle(.secondary)
                        Slider(value: $speed, in: 0.5...3)
                        Image(systemName: "hare").foregroundStyle(.secondary)
                    }
                }
                .disabled(!smooth)
                LabeledContent(L("Плавность")) {
                    HStack {
                        Text(L("резко")).font(.caption).foregroundStyle(.secondary)
                        Slider(value: $smoothness, in: 0...1)
                        Text(L("мягко")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .disabled(!smooth)
            }
            .disabled(!enabled)

            Section {
                Label(L("Мыши Logitech через Logi Options+ тоже поддерживаются. Направление настраивайте здесь, а в Logi Options+ оставьте «Naturalne» и выключите «Płynne przewijanie», чтобы настройки не накладывались друг на друга."),
                      systemImage: "info.circle")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Автозакрытие

/// Список исключений автозакрытия.
final class ExclusionsModel: ObservableObject {
    @Published private(set) var ids: [String] = Settings.autoQuitExclusions

    func add(_ id: String) {
        guard !ids.contains(id), !Settings.alwaysExcluded.contains(id) else { return }
        ids.append(id)
        Settings.autoQuitExclusions = ids
    }

    func remove(_ id: String) {
        ids.removeAll { $0 == id }
        Settings.autoQuitExclusions = ids
    }

    static func name(for id: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return id
    }

    static func icon(for id: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
    }
}

struct AutoQuitPage: View {
    @AppStorage("autoquit.enabled") private var enabled = true
    @StateObject private var model = ExclusionsModel()

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .filter { !model.ids.contains($0.bundleIdentifier!) && !Settings.alwaysExcluded.contains($0.bundleIdentifier!) }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    var body: some View {
        Form {
            Section { PageHeader(page: .autoquit) }

            Section {
                Toggle(L("Включить модуль"), isOn: $enabled)
            } footer: {
                Text(L("Срабатывает, когда вы закрываете красной кнопкой последнее окно приложения. Если у приложения остались свёрнутые окна, оно не закроется."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section(L("Исключения — эти приложения не закрываются")) {
                row(id: "com.apple.finder", fixed: true)
                ForEach(model.ids, id: \.self) { id in
                    row(id: id, fixed: false)
                }
                HStack {
                    Menu {
                        ForEach(runningApps, id: \.processIdentifier) { app in
                            Button(app.localizedName ?? app.bundleIdentifier!) {
                                model.add(app.bundleIdentifier!)
                            }
                        }
                    } label: {
                        Label(L("Из запущенных"), systemImage: "plus")
                    }
                    .fixedSize()
                    Button {
                        pickApp()
                    } label: {
                        Label(L("Выбрать приложение…"), systemImage: "folder")
                    }
                    Spacer()
                }
            }
            .disabled(!enabled)
        }
        .formStyle(.grouped)
    }

    private func row(id: String, fixed: Bool) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: ExclusionsModel.icon(for: id)).resizable().frame(width: 22, height: 22)
            Text(ExclusionsModel.name(for: id))
            Spacer()
            if fixed {
                Text(L("всегда")).font(.caption).foregroundStyle(.secondary)
            } else {
                Button {
                    model.remove(id)
                } label: {
                    Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help(L("Убрать из исключений"))
            }
        }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.prompt = L("Добавить")
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier { model.add(id) }
        }
    }
}

// MARK: - Удаление приложений

struct CleanerPage: View {
    @StateObject private var model = CleanerModel()
    @State private var confirm = false

    var body: some View {
        HStack(spacing: 0) {
            appList
                .frame(width: 250)
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { if model.apps.isEmpty { model.loadApps() } }
    }

    private var appList: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(L("Поиск приложения"), text: $model.search).textFieldStyle(.plain)
                Button { model.loadApps() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).help(L("Обновить список"))
            }
            .padding(10)
            Divider()
            if model.loadingApps && model.apps.isEmpty {
                ProgressView().frame(maxHeight: .infinity)
            } else {
                List(model.filteredApps, selection: Binding(
                    get: { model.selected },
                    set: { model.select($0) })) { app in
                    HStack(spacing: 8) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                            .resizable().frame(width: 22, height: 22)
                        Text(app.name).lineLimit(1)
                    }
                    .tag(app)
                }
                .listStyle(.sidebar)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let app = model.selected {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                        .resizable().frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.name).font(.title2.bold())
                        Text(app.bundleID ?? L("без идентификатора"))
                            .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    Spacer()
                }
                .padding(20)
                Divider()

                if model.scanning {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text(L("Ищу остатки…")).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach($model.items) { $item in
                            HStack(spacing: 10) {
                                Toggle("", isOn: $item.selected).labelsHidden()
                                    .disabled(item.isApp)
                                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                                    .resizable().frame(width: 18, height: 18)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.isApp ? L("Приложение") : item.url.lastPathComponent).lineLimit(1)
                                    Text(prettyPath(item.url)).font(.caption).foregroundStyle(.secondary)
                                        .lineLimit(1).truncationMode(.middle)
                                }
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                                    .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                                Button {
                                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                                } label: { Image(systemName: "magnifyingglass") }
                                    .buttonStyle(.plain).help(L("Показать в Finder"))
                            }
                        }
                    }

                    Divider()
                    HStack {
                        Text(L("Найдено: %@ · выбрано %@", "\(model.items.count)", "\(ByteCountFormatter.string(fromByteCount: model.selectedSize, countStyle: .file))"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if model.removing { ProgressView().controlSize(.small) }
                        Button(role: .destructive) { confirm = true } label: {
                            Label(L("Удалить в Корзину"), systemImage: "trash")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(model.removing || model.items.allSatisfy { !$0.selected })
                    }
                    .padding(14)
                }
            }
            .confirmationDialog(L("Удалить «%@»?", "\(app.name)"), isPresented: $confirm) {
                Button(L("Переместить в Корзину"), role: .destructive) { model.removeSelected() }
                Button(L("Отмена"), role: .cancel) {}
            } message: {
                Text(L("Приложение будет закрыто, а выбранные объекты (%@ шт.) перемещены в Корзину. Пока Корзина не очищена, всё можно вернуть.", "\(model.items.filter(\.selected).count)"))
            }
        } else {
            VStack(spacing: 14) {
                PageIcon(page: .cleaner, size: 64)
                Text(L("Удаление приложений")).font(.title2.bold())
                Text(L("Выберите приложение слева. MacTools найдёт его настройки, кэши и другие остатки в ~/Library."))
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                if let msg = model.message {
                    Label(msg, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.1)))
                }
            }
            .padding(40)
            .frame(maxWidth: 460)
        }
    }

    private func prettyPath(_ url: URL) -> String {
        url.path.replacingOccurrences(of: Cleaner.home.path, with: "~")
    }
}
