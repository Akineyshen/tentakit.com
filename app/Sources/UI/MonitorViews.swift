import SwiftUI

/// Панель, которая открывается по клику на показатели в строке меню.
struct MonitorPopover: View {
    @ObservedObject var model: MonitorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MonitorDetails(model: model, showProcesses: true)
            Divider()
            HStack {
                Button(L("Мониторинг активности")) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                }
                Spacer()
                Text(AppInfo.name).font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}

/// Подробные показатели — используются и в панели, и на странице настроек.
struct MonitorDetails: View {
    @ObservedObject var model: MonitorModel
    var showProcesses = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Процессор
            MetricBlock(icon: "cpu", title: L("Процессор"), value: Fmt.percent(model.cpu), color: .blue) {
                Sparkline(values: model.cpuHistory, maxValue: 1, color: .blue)
                    .frame(height: 34)
                HStack {
                    Legend(color: .blue, text: L("Программы %@", "\(Fmt.percent(model.cpuUser))"))
                    Legend(color: .red, text: L("Система %@", "\(Fmt.percent(model.cpuSystem))"))
                }
            }

            // Память
            MetricBlock(icon: "memorychip", title: L("Память"),
                        value: L("%@ из %@", "\(Fmt.bytes(model.memUsed))", "\(Fmt.bytes(model.memTotal))"), color: .purple) {
                BarView(fraction: model.memFraction, color: .purple)
                HStack {
                    Legend(color: .purple, text: L("Программы %@", "\(Fmt.bytes(model.memApp))"))
                    Legend(color: .orange, text: L("Ядро %@", "\(Fmt.bytes(model.memWired))"))
                    Legend(color: .gray, text: L("Сжато %@", "\(Fmt.bytes(model.memCompressed))"))
                }
            }

            // Сеть
            MetricBlock(icon: "network", title: L("Сеть"), value: "", color: .green) {
                Sparkline(values: model.netHistory, maxValue: nil, color: .green)
                    .frame(height: 28)
                HStack {
                    Label(Fmt.rate(model.netIn), systemImage: "arrow.down").foregroundStyle(.green)
                    Spacer()
                    Label(Fmt.rate(model.netOut), systemImage: "arrow.up").foregroundStyle(.orange)
                }
                .font(.callout.monospacedDigit())
            }

            // Диск
            MetricBlock(icon: "internaldrive", title: L("Диск"),
                        value: L("свободно %@", "\(Fmt.bytes(model.diskFree))"), color: .teal) {
                BarView(fraction: model.diskUsedFraction, color: .teal)
            }

            // Батарея
            if let b = model.battery {
                MetricBlock(icon: batteryIcon(b), title: L("Батарея"), value: "\(b.level)%", color: b.level <= 20 ? .red : .green) {
                    BarView(fraction: Double(b.level) / 100, color: b.level <= 20 ? .red : .green)
                    Text(batteryText(b)).font(.caption).foregroundStyle(.secondary)
                }
            }

            if showProcesses && !model.topProcesses.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L("Больше всего нагружают")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(model.topProcesses) { p in
                        HStack {
                            Text(p.name).lineLimit(1)
                            Spacer()
                            Text(String(format: "%.0f%%", p.cpu)).monospacedDigit().foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .trailing)
                            Text(String(format: L("%.0f МБ"), p.memMB)).monospacedDigit().foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .trailing)
                        }
                        .font(.callout)
                    }
                }
            }
        }
    }

    private func batteryIcon(_ b: BatteryInfo) -> String {
        if b.charging { return "battery.100.bolt" }
        switch b.level {
        case 0..<15: return "battery.0"
        case 15..<40: return "battery.25"
        case 40..<65: return "battery.50"
        case 65..<90: return "battery.75"
        default: return "battery.100"
        }
    }

    private func batteryText(_ b: BatteryInfo) -> String {
        var s = b.charging ? L("Заряжается") : (b.onAC ? L("От сети") : L("От батареи"))
        if let m = b.minutesLeft {
            s += b.charging ? L(" · до полной %@ ч %@ мин", "\(m / 60)", "\(m % 60)") : L(" · осталось %@ ч %@ мин", "\(m / 60)", "\(m % 60)")
        }
        return s
    }
}

struct MetricBlock<Content: View>: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon).foregroundStyle(color).frame(width: 18)
                Text(title).font(.headline)
                Spacer()
                Text(value).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
            }
            content
        }
    }
}

struct Legend: View {
    let color: Color
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
    }
}

struct BarView: View {
    let fraction: Double
    let color: Color
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule().fill(color.gradient)
                    .frame(width: max(4, g.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 8)
        .animation(.easeOut(duration: 0.3), value: fraction)
    }
}

/// Маленький график за последнюю минуту.
struct Sparkline: View {
    let values: [Double]
    let maxValue: Double?
    let color: Color

    var body: some View {
        GeometryReader { g in
            let top = max(maxValue ?? (values.max() ?? 1), 0.0001)
            let n = max(values.count - 1, 1)
            let pts: [CGPoint] = values.enumerated().map { i, v in
                CGPoint(x: g.size.width * CGFloat(i) / CGFloat(n),
                        y: g.size.height * (1 - CGFloat(min(v / top, 1))))
            }
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.06))
                if pts.count > 1 {
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: g.size.height))
                        pts.forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: g.size.height))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [color.opacity(0.35), color.opacity(0.02)],
                                         startPoint: .top, endPoint: .bottom))
                    Path { p in
                        p.move(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                }
            }
        }
    }
}
