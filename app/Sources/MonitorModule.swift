import Cocoa
import SwiftUI
import IOKit.ps

struct BatteryInfo {
    let level: Int
    let charging: Bool
    let onAC: Bool
    let minutesLeft: Int?
}

struct ProcInfo: Identifiable {
    let id = UUID()
    let name: String
    let cpu: Double
    let memMB: Double
}

/// Сбор показателей системы.
final class MonitorModel: ObservableObject {
    @Published var cpu = 0.0
    @Published var cpuUser = 0.0
    @Published var cpuSystem = 0.0
    @Published var cpuHistory: [Double] = []
    @Published var memUsed: UInt64 = 0
    @Published var memApp: UInt64 = 0
    @Published var memWired: UInt64 = 0
    @Published var memCompressed: UInt64 = 0
    let memTotal: UInt64 = ProcessInfo.processInfo.physicalMemory
    @Published var netIn = 0.0
    @Published var netOut = 0.0
    @Published var netHistory: [Double] = []
    @Published var diskFree: Int64 = 0
    @Published var diskTotal: Int64 = 0
    @Published var battery: BatteryInfo?
    @Published var topProcesses: [ProcInfo] = []

    var memFraction: Double { memTotal == 0 ? 0 : Double(memUsed) / Double(memTotal) }
    var diskUsedFraction: Double { diskTotal == 0 ? 0 : 1 - Double(diskFree) / Double(diskTotal) }

    private var lastTicks: [UInt64]?
    private var lastNet: (inB: UInt64, outB: UInt64, at: Date)?
    private static let historyLength = 60

    func sample() {
        sampleCPU()
        sampleMemory()
        sampleNetwork()
        sampleDisk()
        battery = Self.readBattery()
    }

    // MARK: Процессор

    private func sampleCPU() {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let r = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard r == KERN_SUCCESS else { return }
        let t = info.cpu_ticks   // user, system, idle, nice
        let ticks = [UInt64(t.0), UInt64(t.1), UInt64(t.2), UInt64(t.3)]
        defer { lastTicks = ticks }
        guard let last = lastTicks else { return }
        let d = zip(ticks, last).map { $0 >= $1 ? Double($0 - $1) : 0 }
        let total = d.reduce(0, +)
        guard total > 0 else { return }
        cpuUser = (d[0] + d[3]) / total
        cpuSystem = d[1] / total
        cpu = min(1, cpuUser + cpuSystem)
        cpuHistory.append(cpu)
        if cpuHistory.count > Self.historyLength { cpuHistory.removeFirst() }
    }

    // MARK: Память

    private func sampleMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let r = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard r == KERN_SUCCESS else { return }
        let page = UInt64(vm_kernel_page_size)
        let internalPages = UInt64(stats.internal_page_count)
        let purgeable = UInt64(stats.purgeable_count)
        memApp = (internalPages > purgeable ? internalPages - purgeable : 0) * page
        memWired = UInt64(stats.wire_count) * page
        memCompressed = UInt64(stats.compressor_page_count) * page
        memUsed = memApp + memWired + memCompressed
    }

    // MARK: Сеть

    private func sampleNetwork() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return }
        defer { freeifaddrs(ifaddr) }
        var inB: UInt64 = 0, outB: UInt64 = 0
        var ptr = ifaddr
        while let p = ptr {
            let ifa = p.pointee
            if let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK), let data = ifa.ifa_data {
                let name = String(cString: ifa.ifa_name)
                if (name.hasPrefix("en") || name.hasPrefix("pdp_ip")) && (ifa.ifa_flags & UInt32(IFF_UP)) != 0 {
                    let d = data.assumingMemoryBound(to: if_data.self).pointee
                    inB += UInt64(d.ifi_ibytes)
                    outB += UInt64(d.ifi_obytes)
                }
            }
            ptr = ifa.ifa_next
        }
        let now = Date()
        defer { lastNet = (inB, outB, now) }
        guard let last = lastNet else { return }
        let dt = now.timeIntervalSince(last.at)
        guard dt > 0 else { return }
        // Счётчики 32-битные и могут переполниться — тогда просто пропускаем.
        netIn = inB >= last.inB ? Double(inB - last.inB) / dt : 0
        netOut = outB >= last.outB ? Double(outB - last.outB) / dt : 0
        netHistory.append(netIn + netOut)
        if netHistory.count > Self.historyLength { netHistory.removeFirst() }
    }

    // MARK: Диск и батарея

    private func sampleDisk() {
        let v = try? URL(fileURLWithPath: "/").resourceValues(
            forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        diskTotal = Int64(v?.volumeTotalCapacity ?? 0)
        diskFree = v?.volumeAvailableCapacityForImportantUsage ?? 0
    }

    static func readBattery() -> BatteryInfo? {
        guard let snap = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snap)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for ps in list {
            guard let d = IOPSGetPowerSourceDescription(snap, ps)?.takeUnretainedValue() as? [String: Any],
                  (d[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType,
                  let cur = d[kIOPSCurrentCapacityKey] as? Int,
                  let max = d[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            let charging = d[kIOPSIsChargingKey] as? Bool ?? false
            let onAC = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let mins = d[charging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey] as? Int
            return BatteryInfo(level: cur * 100 / max, charging: charging, onAC: onAC,
                               minutesLeft: (mins ?? -1) > 0 ? mins : nil)
        }
        return nil
    }

    // MARK: Процессы

    func refreshProcesses() {
        DispatchQueue.global(qos: .utility).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/ps")
            p.arguments = ["-Aceo", "pcpu=,rss=,comm=", "-r"]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = FileHandle.nullDevice
            guard (try? p.run()) != nil else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            let lines = String(decoding: data, as: UTF8.self).split(separator: "\n").prefix(5)
            let procs: [ProcInfo] = lines.compactMap { line in
                let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
                guard parts.count == 3, let cpu = Double(parts[0].replacingOccurrences(of: ",", with: ".")),
                      let rss = Double(parts[1]) else { return nil }
                return ProcInfo(name: String(parts[2]), cpu: cpu, memMB: rss / 1024)
            }
            DispatchQueue.main.async { self.topProcesses = procs }
        }
    }
}

enum Fmt {
    static func bytes(_ b: UInt64) -> String { bytes(Int64(b)) }
    static func bytes(_ b: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: b, countStyle: .memory)
    }
    static func rate(_ bps: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bps), countStyle: .file) + L("/с")
    }
    /// Короткая скорость для строки меню: 30K, 1.2M.
    static func shortRate(_ bps: Double) -> String {
        let kb = bps / 1024
        if kb < 1000 { return "\(Int(kb.rounded()))K" }
        return String(format: "%.1fM", kb / 1024)
    }
    static func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }
}

/// Показатели в строке меню и панель с подробностями по клику.
final class MonitorModule: NSObject {
    let model = MonitorModel()
    private var item: NSStatusItem?
    private var timer: Timer?
    private var interval = 0.0
    private var ticks = 0

    private lazy var panel = MonitorPanel(model: model)

    /// Включает, выключает и перенастраивает модуль по настройкам.
    func apply() {
        if Settings.monitorEnabled {
            if item == nil {
                let it = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                it.button?.target = self
                it.button?.action = #selector(togglePopover(_:))
                item = it
                Log.write("Мониторинг: включён")
            }
            let iv = Settings.monitorInterval
            if timer == nil || iv != interval {
                timer?.invalidate()
                interval = iv
                let t = Timer(timeInterval: iv, repeats: true) { [weak self] _ in self?.tick() }
                RunLoop.main.add(t, forMode: .common)
                timer = t
                tick()
            }
            updateTitle()
        } else {
            timer?.invalidate()
            timer = nil
            if let item { NSStatusBar.system.removeStatusItem(item) }
            item = nil
        }
    }

    private func tick() {
        model.sample()
        ticks += 1
        if panel.isShown {
            if ticks % 2 == 0 { model.refreshProcesses() }
            panel.relayout()
        }
        updateTitle()
    }

    private func updateTitle() {
        guard let button = item?.button else { return }
        var parts: [String] = []
        if Settings.monitorShowCPU { parts.append("CPU \(Fmt.percent(model.cpu))") }
        if Settings.monitorShowRAM { parts.append("RAM \(Fmt.percent(model.memFraction))") }
        if Settings.monitorShowNet { parts.append("↓\(Fmt.shortRate(model.netIn)) ↑\(Fmt.shortRate(model.netOut))") }
        if Settings.monitorShowBattery, let b = model.battery {
            parts.append("\(b.charging ? "⚡︎" : "")\(b.level)%")
        }
        if parts.isEmpty {
            button.attributedTitle = NSAttributedString()
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: L("Мониторинг"))
        } else {
            button.image = nil
            button.attributedTitle = NSAttributedString(
                string: parts.joined(separator: "  "),
                attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)])
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if panel.isShown {
            panel.hide()
        } else {
            model.refreshProcesses()
            panel.show(below: sender)
        }
    }
}

/// Выпадающая панель под строкой меню. Своя, а не NSPopover:
/// позиция считается вручную и никогда не уезжает за край экрана.
final class MonitorPanel {
    private let panel: NSPanel
    private let hosting: NSHostingView<MonitorPopover>
    private var clickMonitor: Any?
    private var anchor: NSRect = .zero

    var isShown: Bool { panel.isVisible }

    init(model: MonitorModel) {
        hosting = NSHostingView(rootView: MonitorPopover(model: model))
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]

        let fx = NSVisualEffectView()
        fx.material = .popover
        fx.blendingMode = .behindWindow
        fx.state = .active
        fx.wantsLayer = true
        fx.layer?.cornerRadius = 12
        fx.layer?.masksToBounds = true
        hosting.translatesAutoresizingMaskIntoConstraints = false
        fx.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: fx.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: fx.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: fx.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: fx.bottomAnchor),
        ])
        panel.contentView = fx
    }

    func show(below button: NSStatusBarButton) {
        guard let bw = button.window else { return }
        anchor = bw.convertToScreen(button.convert(button.bounds, to: nil))
        relayout()
        panel.orderFrontRegardless()
        // Клик в любом другом месте — закрываем.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
    }

    /// Ставит панель под значком и не даёт ей выйти за экран.
    func relayout() {
        let size = hosting.fittingSize
        let screen = NSScreen.screens.first { $0.frame.contains(NSPoint(x: anchor.midX, y: anchor.midY)) }
            ?? NSScreen.main ?? NSScreen.screens[0]
        let vis = screen.visibleFrame
        let w = size.width
        var x = anchor.midX - w / 2
        x = min(max(x, vis.minX + 8), vis.maxX - w - 8)
        let top = min(anchor.minY - 6, vis.maxY - 2)
        let h = min(size.height, top - vis.minY - 8)
        panel.setFrame(NSRect(x: x, y: top - h, width: w, height: h), display: true)
    }

    func hide() {
        panel.orderOut(nil)
        if let m = clickMonitor { NSEvent.removeMonitor(m) }
        clickMonitor = nil
    }
}
