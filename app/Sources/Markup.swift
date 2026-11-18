import Cocoa
import CoreImage

enum MarkupTool: String, CaseIterable, Identifiable {
    case pen, line, arrow, rect, highlight, text, blur
    var id: String { rawValue }

    var title: String {
        switch self {
        case .pen: L("Карандаш")
        case .line: L("Линия")
        case .arrow: L("Стрелка")
        case .rect: L("Рамка")
        case .highlight: L("Маркер")
        case .text: L("Текст")
        case .blur: L("Размытие")
        }
    }
    var symbol: String {
        switch self {
        case .pen: "pencil.tip"
        case .line: "line.diagonal"
        case .arrow: "arrow.up.right"
        case .rect: "rectangle"
        case .highlight: "highlighter"
        case .text: "textformat"
        case .blur: "mosaic"
        }
    }
}

/// Одна пометка. Координаты — в пикселях снимка, начало в левом верхнем углу.
struct Markup: Identifiable {
    let id = UUID()
    var tool: MarkupTool
    var points: [CGPoint]
    var color: CGColor
    var width: CGFloat   // в точках экрана
    var text = ""

    var rect: CGRect {
        guard let a = points.first, let b = points.last else { return .zero }
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
}

/// Отрисовка пометок. Контекст: y вниз, единицы — пиксели снимка.
enum MarkupRenderer {
    static func makePixelated(_ img: CGImage, scale: CGFloat) -> CGImage? {
        let ci = CIImage(cgImage: img)
        guard let f = CIFilter(name: "CIPixellate") else { return nil }
        f.setValue(ci.clampedToExtent(), forKey: kCIInputImageKey)
        f.setValue(scale, forKey: kCIInputScaleKey)
        guard let out = f.outputImage?.cropped(to: ci.extent) else { return nil }
        return CIContext().createCGImage(out, from: ci.extent)
    }

    /// Снимок целиком и пометки поверх.
    static func draw(_ cg: CGContext, base: CGImage, pixelated: CGImage?, items: [Markup], px: CGFloat) {
        let full = CGRect(x: 0, y: 0, width: base.width, height: base.height)
        drawImage(cg, base, full)
        drawItems(cg, pixelated: pixelated, full: full, items: items, px: px)
    }

    static func drawItems(_ cg: CGContext, pixelated: CGImage?, full: CGRect, items: [Markup], px: CGFloat) {
        for m in items { draw(m, in: cg, pixelated: pixelated, full: full, px: px) }
    }

    static func drawImage(_ cg: CGContext, _ img: CGImage, _ r: CGRect) {
        cg.saveGState()
        cg.translateBy(x: r.minX, y: r.maxY)
        cg.scaleBy(x: 1, y: -1)
        cg.draw(img, in: CGRect(origin: .zero, size: r.size))
        cg.restoreGState()
    }

    static func textFontSize(_ width: CGFloat) -> CGFloat { 12 + width * 2.5 }

    private static func draw(_ m: Markup, in cg: CGContext, pixelated: CGImage?, full: CGRect, px: CGFloat) {
        let lw = m.width * px
        cg.saveGState()
        defer { cg.restoreGState() }
        cg.setLineCap(.round)
        cg.setLineJoin(.round)

        switch m.tool {
        case .rect:
            cg.setStrokeColor(m.color)
            cg.setLineWidth(lw)
            cg.addPath(CGPath(roundedRect: m.rect, cornerWidth: 2 * px, cornerHeight: 2 * px, transform: nil))
            cg.strokePath()

        case .highlight:
            cg.setFillColor(m.color)
            cg.fill(m.rect)

        case .pen:
            guard let first = m.points.first else { return }
            cg.setStrokeColor(m.color)
            cg.setLineWidth(lw)
            cg.move(to: first)
            m.points.dropFirst().forEach { cg.addLine(to: $0) }
            cg.strokePath()

        case .line:
            guard let a = m.points.first, let b = m.points.last else { return }
            cg.setStrokeColor(m.color)
            cg.setLineWidth(lw)
            cg.move(to: a)
            cg.addLine(to: b)
            cg.strokePath()

        case .arrow:
            guard let a = m.points.first, let b = m.points.last else { return }
            let angle = atan2(b.y - a.y, b.x - a.x)
            let head = max(lw * 3.2, 12 * px)
            let shaftEnd = CGPoint(x: b.x - cos(angle) * head * 0.6, y: b.y - sin(angle) * head * 0.6)
            cg.setShadow(offset: .zero, blur: 3 * px, color: NSColor.black.withAlphaComponent(0.35).cgColor)
            cg.setStrokeColor(m.color)
            cg.setLineWidth(lw)
            cg.move(to: a)
            cg.addLine(to: shaftEnd)
            cg.strokePath()
            cg.setFillColor(m.color)
            cg.move(to: b)
            cg.addLine(to: CGPoint(x: b.x - cos(angle - .pi / 7) * head, y: b.y - sin(angle - .pi / 7) * head))
            cg.addLine(to: CGPoint(x: b.x - cos(angle + .pi / 7) * head, y: b.y - sin(angle + .pi / 7) * head))
            cg.closePath()
            cg.fillPath()

        case .blur:
            guard let pixelated else { return }
            cg.clip(to: m.rect)
            drawImage(cg, pixelated, full)

        case .text:
            guard let p = m.points.first else { return }
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
            shadow.shadowBlurRadius = 3 * px
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: textFontSize(m.width) * px, weight: .bold),
                .foregroundColor: NSColor(cgColor: m.color) ?? .red,
                .shadow: shadow,
            ]
            let prev = NSGraphicsContext.current
            NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
            NSAttributedString(string: m.text, attributes: attrs).draw(at: p)
            NSGraphicsContext.current = prev
        }
    }
}

enum AppWindows {
    /// Пока открыто хоть одно окно MacTools — значок в Доке, иначе только строка меню.
    static func updateActivationPolicy(closing: NSWindow? = nil) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(hasTitledWindows(except: closing) ? .regular : .accessory)
        }
    }

    static func hasTitledWindows(except w: NSWindow? = nil) -> Bool {
        NSApp.windows.contains { $0 !== w && $0.isVisible && $0.styleMask.contains(.titled) }
    }
}
