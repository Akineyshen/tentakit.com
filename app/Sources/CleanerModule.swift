import Cocoa

/// Установленное приложение.
struct InstalledApp: Identifiable, Hashable {
    let url: URL
    let name: String
    let bundleID: String?
    var id: URL { url }
}

/// Найденный файл или папка, которые можно удалить.
struct CleanupItem: Identifiable, Hashable {
    let url: URL
    let size: Int64
    let isApp: Bool
    var selected = true
    var id: URL { url }
}

/// Поиск приложений и их остатков. Удаление — только в Корзину.
enum Cleaner {
    static let home = FileManager.default.homeDirectoryForCurrentUser
    static let library = home.appendingPathComponent("Library")

    /// Приложения, которые можно удалить (системные и сам MacTools пропускаем).
    static func installedApps() -> [InstalledApp] {
        let fm = FileManager.default
        let roots = [URL(fileURLWithPath: "/Applications"),
                     URL(fileURLWithPath: "/Applications/Utilities"),
                     home.appendingPathComponent("Applications")]
        var result: [InstalledApp] = []
        var seen = Set<String>()
        for root in roots {
            guard let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { continue }
            for url in items where url.pathExtension == "app" {
                let path = url.resolvingSymlinksInPath().path
                guard !seen.contains(path), !path.hasPrefix("/System/") else { continue }
                guard fm.isDeletableFile(atPath: url.path) else { continue }
                let bid = Bundle(url: url)?.bundleIdentifier
                if bid == AppInfo.bundleID { continue }
                seen.insert(path)
                result.append(InstalledApp(url: url,
                                           name: fm.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""),
                                           bundleID: bid))
            }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Сам .app и его остатки в ~/Library.
    static func items(for app: InstalledApp) -> [CleanupItem] {
        var urls: [URL] = [app.url]
        let fm = FileManager.default
        func add(_ u: URL) {
            if fm.fileExists(atPath: u.path), !urls.contains(u) { urls.append(u) }
        }
        func lib(_ parts: String...) -> URL {
            parts.reduce(library) { $0.appendingPathComponent($1) }
        }
        func scan(_ dir: URL, _ match: (String) -> Bool) {
            guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { return }
            for n in names where match(n) { add(dir.appendingPathComponent(n)) }
        }

        if let bid = app.bundleID, !bid.isEmpty {
            for sub in ["Application Support", "Caches", "Containers", "Logs", "HTTPStorages",
                        "WebKit", "Application Scripts"] {
                add(lib(sub, bid))
            }
            add(lib("Saved Application State", "\(bid).savedState"))
            add(lib("Cookies", "\(bid).binarycookies"))
            add(lib("HTTPStorages", "\(bid).binarycookies"))
            scan(lib("Preferences")) { $0 == "\(bid).plist" || $0.hasPrefix("\(bid).") && $0.hasSuffix(".plist") }
            scan(lib("Preferences", "ByHost")) { $0.hasPrefix("\(bid).") }
            scan(lib("LaunchAgents")) { $0.hasPrefix(bid) }
            // Group Containers называются вроде TEAMID.com.company.app
            scan(lib("Group Containers")) { $0.hasSuffix(".\(bid)") || $0 == bid }
        }
        // Папки с точным именем приложения.
        for sub in ["Application Support", "Caches", "Logs"] {
            add(lib(sub, app.name))
        }

        return urls.map { CleanupItem(url: $0, size: size(of: $0), isApp: $0 == app.url) }
    }

    static func size(of url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .isDirectoryKey]
        let values = try? url.resourceValues(forKeys: Set(keys))
        guard values?.isDirectory == true else { return Int64(values?.totalFileAllocatedSize ?? 0) }
        var total: Int64 = 0
        if let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in true }) {
            for case let f as URL in e {
                total += Int64((try? f.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
            }
        }
        return total
    }

    /// Закрывает приложение, если оно запущено. true — если удалось.
    static func quitIfRunning(_ app: InstalledApp) -> Bool {
        guard let bid = app.bundleID else { return true }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bid)
        guard !running.isEmpty else { return true }
        running.forEach { $0.terminate() }
        for _ in 0..<25 {   // ждём до 5 секунд
            if running.allSatisfy({ $0.isTerminated }) { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return running.allSatisfy { $0.isTerminated }
    }
}

/// Состояние экрана «Удаление приложений».
final class CleanerModel: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var search = ""
    @Published var selected: InstalledApp?
    @Published var items: [CleanupItem] = []
    @Published var loadingApps = false
    @Published var scanning = false
    @Published var removing = false
    @Published var message: String?

    var filteredApps: [InstalledApp] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var selectedSize: Int64 { items.filter(\.selected).reduce(0) { $0 + $1.size } }

    func loadApps() {
        loadingApps = true
        DispatchQueue.global(qos: .userInitiated).async {
            let list = Cleaner.installedApps()
            DispatchQueue.main.async {
                self.apps = list
                self.loadingApps = false
                if let s = self.selected, !list.contains(s) { self.selected = nil; self.items = [] }
            }
        }
    }

    func select(_ app: InstalledApp?) {
        selected = app
        items = []
        message = nil
        guard let app else { return }
        scanning = true
        DispatchQueue.global(qos: .userInitiated).async {
            let found = Cleaner.items(for: app)
            let total = ByteCountFormatter.string(fromByteCount: found.reduce(0) { $0 + $1.size }, countStyle: .file)
            Log.write("Удаление: \(app.name) — найдено объектов \(found.count), всего \(total)")
            DispatchQueue.main.async {
                guard self.selected == app else { return }
                self.items = found
                self.scanning = false
            }
        }
    }

    func removeSelected() {
        guard let app = selected else { return }
        let toRemove = items.filter(\.selected)
        guard !toRemove.isEmpty else { return }
        removing = true
        DispatchQueue.global(qos: .userInitiated).async {
            var msg: String
            if !Cleaner.quitIfRunning(app) {
                msg = L("Не удалось закрыть «%@». Закройте его вручную и попробуйте снова.", "\(app.name)")
            } else {
                var done = 0, failed: [String] = []
                var freed: Int64 = 0
                for item in toRemove {
                    do {
                        try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                        done += 1
                        freed += item.size
                    } catch {
                        failed.append(item.url.lastPathComponent)
                        Log.write("Удаление: не удалось \(item.url.path): \(error.localizedDescription)")
                    }
                }
                let size = ByteCountFormatter.string(fromByteCount: freed, countStyle: .file)
                msg = L("В Корзину перемещено: %@ (%@).", "\(done)", "\(size)")
                if !failed.isEmpty { msg += L(" Не удалось: %@.", "\(failed.joined(separator: ", "))") }
                Log.write("Удаление: \(app.name) — \(msg)")
            }
            DispatchQueue.main.async {
                self.removing = false
                self.message = msg
                self.items = []
                self.selected = nil
                self.loadApps()
            }
        }
    }
}
