import SwiftUI
import ServiceManagement

/// Живое состояние приложения для интерфейса.
final class AppStatus: ObservableObject {
    @Published var trusted = AX.isTrusted
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        if trusted != AX.isTrusted { trusted = AX.isTrusted }
        let login = SMAppService.mainApp.status == .enabled
        if launchAtLogin != login { launchAtLogin = login }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("MacTools: автозапуск — \(error.localizedDescription)")
        }
        refresh()
    }
}

/// Разделы в боковой панели.
enum Page: String, Hashable, Identifiable {
    case overview, dock, windows, stats, cleaner, scroll, screenshots, autoquit, general

    var id: String { rawValue }

    static let modules: [Page] = [.dock, .windows, .scroll, .autoquit, .cleaner, .stats, .screenshots]
    static let soon: [Page] = []

    var isReady: Bool { !Page.soon.contains(self) }

    var title: String {
        switch self {
        case .overview: L("Обзор")
        case .dock: L("Док")
        case .windows: L("Раскладка окон")
        case .stats: L("Мониторинг")
        case .cleaner: L("Удаление приложений")
        case .scroll: L("Прокрутка мыши")
        case .screenshots: L("Скриншоты")
        case .autoquit: L("Автозакрытие")
        case .general: L("Основные")
        }
    }

    var summary: String {
        switch self {
        case .overview: L("Все модули MacTools")
        case .dock: L("Клик по значку в Доке сворачивает окна, повторный клик разворачивает их обратно.")
        case .windows: L("Перетащите окно к краю или в угол экрана, и оно встанет на половину или четверть.")
        case .stats: L("Процессор, память, сеть и батарея в строке меню.")
        case .cleaner: L("Удаление приложений вместе с их остатками. Всё уходит в Корзину.")
        case .scroll: L("Плавная прокрутка и отдельное направление для мыши.")
        case .screenshots: L("Как Lightshot: выделите область, рисуйте прямо на ней и копируйте одним нажатием.")
        case .autoquit: L("Красная кнопка на последнем окне завершает приложение. Можно добавить исключения.")
        case .general: L("Автозапуск, доступ и информация о приложении.")
        }
    }

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2.fill"
        case .dock: "dock.rectangle"
        case .windows: "rectangle.split.2x1.fill"
        case .stats: "chart.bar.xaxis"
        case .cleaner: "trash.fill"
        case .scroll: "computermouse.fill"
        case .screenshots: "camera.viewfinder"
        case .autoquit: "power"
        case .general: "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .overview: .indigo
        case .dock: Color(red: 0.2, green: 0.2, blue: 0.22)
        case .windows: .blue
        case .stats: .green
        case .cleaner: .gray
        case .scroll: .orange
        case .screenshots: .purple
        case .autoquit: .red
        case .general: .gray
        }
    }
}

extension SnapAction {
    /// Область экрана для мини-схемы (0…1, начало — левый верхний угол).
    var unitRect: CGRect {
        let t: CGFloat = 1.0 / 3.0
        switch self {
        case .leftHalf: return CGRect(x: 0, y: 0, width: 0.5, height: 1)
        case .rightHalf: return CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        case .topHalf: return CGRect(x: 0, y: 0, width: 1, height: 0.5)
        case .bottomHalf: return CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
        case .topLeft: return CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        case .topRight: return CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        case .bottomLeft: return CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)
        case .bottomRight: return CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        case .leftThird: return CGRect(x: 0, y: 0, width: t, height: 1)
        case .centerThird: return CGRect(x: t, y: 0, width: t, height: 1)
        case .rightThird: return CGRect(x: 2 * t, y: 0, width: t, height: 1)
        case .leftTwoThirds: return CGRect(x: 0, y: 0, width: 2 * t, height: 1)
        case .rightTwoThirds: return CGRect(x: t, y: 0, width: 2 * t, height: 1)
        case .maximize: return CGRect(x: 0, y: 0, width: 1, height: 1)
        case .center: return CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        case .restore: return CGRect(x: 0.1, y: 0.25, width: 0.45, height: 0.5)
        }
    }

    static let groups: [(title: String, actions: [SnapAction])] = [
        (L("Половины"), [.leftHalf, .rightHalf, .topHalf, .bottomHalf]),
        (L("Четверти"), [.topLeft, .topRight, .bottomLeft, .bottomRight]),
        (L("Трети"), [.leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds]),
        (L("Другое"), [.maximize, .center, .restore]),
    ]
}
