import Cocoa
import SwiftUI

/// Состояние режима снимка поверх экрана.
final class OverlayModel: ObservableObject {
    let image: CGImage        // весь экран, в пикселях
    let scale: CGFloat        // пикселей в одной точке
    let size: CGSize          // размер экрана в точках
    let windows: [CGRect]     // окна на экране (точки), спереди назад

    @Published var selection: CGRect?
    @Published var hoverWindow: CGRect?
    @Published var tool: MarkupTool?
    @Published var color: Color = .red
    @Published var width: CGFloat = 4
    @Published var markups: [Markup] = []
    @Published var current: Markup?
    @Published var textPoint: CGPoint?     // в точках
    @Published var textDraft = ""
    var close: () -> Void = {}

    private(set) lazy var pixelated: CGImage? = MarkupRenderer.makePixelated(image, scale: 12 * scale)
    var needsPixelated: Bool { markups.contains { $0.tool == .blur } || current?.tool == .blur }
    var bounds: CGRect { CGRect(origin: .zero, size: size) }

    init(image: CGImage, scale: CGFloat, size: CGSize, windows: [CGRect]) {
        self.image = image
        self.scale = scale
        self.size = size
        self.windows = windows
    }

    // MARK: Маркеры изменения размера

    enum Handle: CaseIterable { case tl, t, tr, r, br, b, bl, l }

    static func point(_ h: Handle, _ r: CGRect) -> CGPoint {
        switch h {
        case .tl: CGPoint(x: r.minX, y: r.minY)
        case .t: CGPoint(x: r.midX, y: r.minY)
        case .tr: CGPoint(x: r.maxX, y: r.minY)
        case .r: CGPoint(x: r.maxX, y: r.midY)
        case .br: CGPoint(x: r.maxX, y: r.maxY)
        case .b: CGPoint(x: r.midX, y: r.maxY)
        case .bl: CGPoint(x: r.minX, y: r.maxY)
        case .l: CGPoint(x: r.minX, y: r.midY)
        }
    }

    private func handle(at p: CGPoint) -> Handle? {
        guard let s = selection else { return nil }
        return Handle.allCases.first { h in
            let c = Self.point(h, s)
            return abs(c.x - p.x) < 9 && abs(c.y - p.y) < 9
        }
    }

    // MARK: Мышь

    private enum Drag { case select(CGPoint), move(CGRect, CGPoint), resize(Handle, CGRect), draw, none }
    private var drag: Drag?

    func hover(_ p: CGPoint?) {
        guard selection == nil, let p else { hoverWindow = nil; return }
        hoverWindow = windows.first { $0.contains(p) }
    }

    func dragChanged(start: CGPoint, location: CGPoint) {
        let loc = clamp(location, to: bounds)
        if drag == nil {
            if let h = handle(at: start), let s = selection {
                drag = .resize(h, s)
            } else if let s = selection, s.contains(start) {
                if let tool { drag = tool == .text ? Drag.none : .draw } else { drag = .move(s, start) }
            } else if markups.isEmpty && textPoint == nil {
                drag = .select(start)
            } else {
                drag = Drag.none
            }
        }
        switch drag! {
        case .select(let a):
            if hypot(loc.x - a.x, loc.y - a.y) > 3 {
                selection = Self.rect(a, loc)
                hoverWindow = nil
            }
        case .move(let r, let a):
            var n = r.offsetBy(dx: loc.x - a.x, dy: loc.y - a.y)
            n.origin.x = min(max(0, n.minX), size.width - n.width)
            n.origin.y = min(max(0, n.minY), size.height - n.height)
            selection = n
        case .resize(let h, let r):
            selection = Self.resized(r, h, loc)
        case .draw:
            guard let s = selection, let tool else { return }
            let a = px(clamp(start, to: s)), b = px(clamp(loc, to: s))
            if current == nil {
                let c = tool == .highlight ? NSColor(color).withAlphaComponent(0.35).cgColor : NSColor(color).cgColor
                current = Markup(tool: tool, points: [a], color: c, width: width)
            }
            if tool == .pen { current?.points.append(b) } else { current?.points = [a, b] }
        case .none:
            break
        }
    }

    func dragEnded(start: CGPoint, location: CGPoint) {
        let loc = clamp(location, to: bounds)
        defer { drag = nil }
        switch drag {
        case .select(let a):
            // Просто клик — берём окно под курсором.
            if hypot(loc.x - a.x, loc.y - a.y) <= 3, let w = hoverWindow ?? windows.first(where: { $0.contains(loc) }) {
                selection = w.intersection(bounds)
                hoverWindow = nil
            }
        case .resize:
            if let s = selection, s.width < 4 || s.height < 4 { selection = nil }
        case .draw:
            guard let c = current else { return }
            current = nil
            let big = c.tool == .pen ? c.points.count > 2 : hypot(c.rect.width, c.rect.height) > 3 * scale
            if big { markups.append(c) }
        case .some(.none):
            if tool == .text, let s = selection, s.contains(loc) {
                commitText()
                textPoint = loc
                textDraft = ""
            }
        default:
            break
        }
    }

    // MARK: Текст и отмена

    func commitText() {
        defer { textPoint = nil; textDraft = "" }
        guard let p = textPoint, !textDraft.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        markups.append(Markup(tool: .text, points: [px(p)], color: NSColor(color).cgColor, width: width, text: textDraft))
    }

    func undo() {
        if textPoint != nil { textPoint = nil; textDraft = ""; return }
        if !markups.isEmpty { markups.removeLast() }
    }

    func escape() {
        if textPoint != nil { textPoint = nil; textDraft = ""; return }
        close()
    }

    // MARK: Результат

    private func renderSelection() -> Screenshot? {
        commitText()
        guard let sel = selection else { return nil }
        let r = CGRect(x: sel.minX * scale, y: sel.minY * scale, width: sel.width * scale, height: sel.height * scale)
            .integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard r.width >= 1, r.height >= 1,
              let ctx = CGContext(data: nil, width: Int(r.width), height: Int(r.height), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.translateBy(x: 0, y: r.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.translateBy(x: -r.minX, y: -r.minY)
        MarkupRenderer.draw(ctx, base: image, pixelated: needsPixelated ? pixelated : nil, items: markups, px: scale)
        guard let out = ctx.makeImage() else { return nil }
        return Screenshot(image: out, pointSize: CGSize(width: r.width / scale, height: r.height / scale))
    }

    func copyAndClose() {
        guard let shot = renderSelection() else { return }
        shot.copyToClipboard()
        Log.write("Скриншоты: скопировано \(shot.image.width)×\(shot.image.height)")
        close()
    }

    func saveAndClose() {
        guard let shot = renderSelection() else { return }
        _ = shot.save()
        shot.copyToClipboard()
        close()
    }

    // MARK: Геометрия

    func px(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * scale, y: p.y * scale) }

    private func clamp(_ p: CGPoint, to r: CGRect) -> CGPoint {
        CGPoint(x: min(max(p.x, r.minX), r.maxX), y: min(max(p.y, r.minY), r.maxY))
    }

    static func rect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    private static func resized(_ r: CGRect, _ h: Handle, _ p: CGPoint) -> CGRect {
        var minX = r.minX, maxX = r.maxX, minY = r.minY, maxY = r.maxY
        switch h {
        case .tl: minX = p.x; minY = p.y
        case .t: minY = p.y
        case .tr: maxX = p.x; minY = p.y
        case .r: maxX = p.x
        case .br: maxX = p.x; maxY = p.y
        case .b: maxY = p.y
        case .bl: minX = p.x; maxY = p.y
        case .l: minX = p.x
        }
        return rect(CGPoint(x: minX, y: minY), CGPoint(x: maxX, y: maxY))
    }
}

/// Окно на весь экран без рамки, которое может принимать клавиатуру.
final class OverlayWindow: NSWindow {
    weak var model: OverlayModel?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) { model?.escape() }

    override func keyDown(with e: NSEvent) {
        guard let model else { return super.keyDown(with: e) }
        switch e.keyCode {
        case 53: model.escape()                                        // Esc
        case 36, 76: if model.selection != nil { model.copyAndClose() } // Return
        default: super.keyDown(with: e)
        }
    }

    override func performKeyEquivalent(with e: NSEvent) -> Bool {
        guard let model, model.textPoint == nil, e.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: e)
        }
        switch e.keyCode {
        case 8: model.copyAndClose(); return true    // ⌘C
        case 1: model.saveAndClose(); return true    // ⌘S
        case 6: model.undo(); return true            // ⌘Z
        default: return super.performKeyEquivalent(with: e)
        }
    }
}

/// Показ и закрытие режима снимка.
final class ScreenshotOverlay {
    private static var current: ScreenshotOverlay?
    private let window: OverlayWindow
    private let model: OverlayModel

    init(image: CGImage, screen: NSScreen, windows: [CGRect], fullScreen: Bool) {
        let scale = CGFloat(image.width) / max(screen.frame.width, 1)
        model = OverlayModel(image: image, scale: scale, size: screen.frame.size, windows: windows)
        if fullScreen { model.selection = model.bounds }

        window = OverlayWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.model = model
        window.level = .screenSaver
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.acceptsMouseMovedEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: OverlayView(model: model))
        window.setFrame(screen.frame, display: false)
        model.close = { [weak self] in self?.dismiss() }
    }

    func show() {
        Self.current?.dismiss()
        Self.current = self
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        NSCursor.crosshair.set()
    }

    func dismiss() {
        window.orderOut(nil)
        if Self.current === self { Self.current = nil }
        NSCursor.arrow.set()
        // Возвращаем фокус приложению, в котором работали.
        if !AppWindows.hasTitledWindows() { NSApp.hide(nil) }
    }
}

// MARK: - Интерфейс

struct OverlayView: View {
    @ObservedObject var model: OverlayModel
    @FocusState private var textFocused: Bool

    private let presets: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .white, .black]
    private let toolsSize = CGSize(width: 44, height: CGFloat(MarkupTool.allCases.count) * 34 + 50)
    private let actionsSize = CGSize(width: 470, height: 44)

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Замороженный снимок экрана.
            Image(decorative: model.image, scale: model.scale)
                .frame(width: model.size.width, height: model.size.height)

            // Затемнение всего, кроме выделенной области.
            Path { p in
                p.addRect(model.bounds)
                if let s = model.selection { p.addRect(s) }
            }
            .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)

            // Подсветка окна под курсором.
            if let w = model.hoverWindow {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.12))
                    .overlay(Rectangle().strokeBorder(Color.accentColor, lineWidth: 2))
                    .frame(width: w.width, height: w.height)
                    .offset(x: w.minX, y: w.minY)
                    .allowsHitTesting(false)
            }

            // Пометки.
            Canvas { ctx, _ in
                let items = model.markups + (model.current.map { [$0] } ?? [])
                guard !items.isEmpty else { return }
                ctx.withCGContext { cg in
                    if let s = model.selection { cg.clip(to: s) }
                    cg.scaleBy(x: 1 / model.scale, y: 1 / model.scale)
                    let full = CGRect(x: 0, y: 0, width: model.image.width, height: model.image.height)
                    MarkupRenderer.drawItems(cg, pixelated: model.needsPixelated ? model.pixelated : nil,
                                             full: full, items: items, px: model.scale)
                }
            }
            .frame(width: model.size.width, height: model.size.height)
            .allowsHitTesting(false)

            // Слой, который ловит мышь.
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(width: model.size.width, height: model.size.height)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { v in model.dragChanged(start: v.startLocation, location: v.location) }
                        .onEnded { v in
                            model.dragEnded(start: v.startLocation, location: v.location)
                            if model.textPoint != nil { textFocused = true }
                        }
                )
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let p):
                        model.hover(p)
                        updateCursor(p)
                    case .ended:
                        model.hover(nil)
                    }
                }

            if let s = model.selection {
                selectionFrame(s)
                sizeLabel(s)
                toolsBar.offset(toolsOffset(s))
                actionsBar.offset(actionsOffset(s))
            } else {
                hint
            }

            if let p = model.textPoint {
                TextField(L("Текст"), text: $model.textDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: MarkupRenderer.textFontSize(model.width), weight: .bold))
                    .foregroundStyle(model.color)
                    .padding(3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.25)))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [3])))
                    .frame(minWidth: 140, alignment: .leading)
                    .fixedSize()
                    .offset(x: p.x - 3, y: p.y - 3)
                    .focused($textFocused)
                    .onSubmit { model.commitText() }
            }
        }
        .frame(width: model.size.width, height: model.size.height, alignment: .topLeading)
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }

    private func updateCursor(_ p: CGPoint) {
        if let s = model.selection, s.contains(p) {
            switch model.tool {
            case nil: NSCursor.openHand.set()
            case .text?: NSCursor.iBeam.set()
            default: NSCursor.crosshair.set()
            }
        } else {
            NSCursor.crosshair.set()
        }
    }

    // MARK: Рамка выделения

    private func selectionFrame(_ s: CGRect) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .strokeBorder(Color.white, style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .frame(width: s.width, height: s.height)
                .offset(x: s.minX, y: s.minY)
            ForEach(OverlayModel.Handle.allCases, id: \.self) { h in
                let c = OverlayModel.point(h, s)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color.accentColor, lineWidth: 1))
                    .frame(width: 8, height: 8)
                    .offset(x: c.x - 4, y: c.y - 4)
            }
        }
        .allowsHitTesting(false)
    }

    private func sizeLabel(_ s: CGRect) -> some View {
        let y = s.minY > 26 ? s.minY - 24 : s.minY + 4
        return Text("\(Int(s.width * model.scale)) × \(Int(s.height * model.scale))")
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.7)))
            .offset(x: s.minX, y: y)
            .allowsHitTesting(false)
    }

    private var hint: some View {
        Text(L("Выделите область или кликните по окну   ·   Esc — отмена"))
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.65)))
            .frame(width: model.size.width)
            .offset(y: 40)
            .allowsHitTesting(false)
    }

    // MARK: Панель инструментов (справа от области)

    private var toolsBar: some View {
        VStack(spacing: 2) {
            ForEach(MarkupTool.allCases) { t in
                Button {
                    model.commitText()
                    model.tool = model.tool == t ? nil : t
                } label: {
                    Image(systemName: t.symbol)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 32, height: 32)
                        .background(RoundedRectangle(cornerRadius: 7)
                            .fill(model.tool == t ? Color.accentColor : Color.clear))
                        .foregroundStyle(model.tool == t ? Color.white : Color.primary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(t.title)
            }
            Divider().frame(width: 28).padding(.vertical, 3)
            Button { model.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L("Отменить (⌘Z)"))
            .disabled(model.markups.isEmpty && model.textPoint == nil)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 11).fill(.regularMaterial))
        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
    }

    private func toolsOffset(_ s: CGRect) -> CGSize {
        let w = toolsSize.width + 12
        var x = s.maxX + 8
        if x + w > model.size.width { x = s.minX - w - 8 }
        if x < 4 { x = s.maxX - w - 8 }   // места нет ни справа, ни слева — внутри области
        let y = min(max(s.minY, 4), model.size.height - toolsSize.height - 16)
        return CGSize(width: x, height: y)
    }

    // MARK: Панель действий (под областью)

    private var actionsBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach(presets, id: \.self) { c in
                    Circle()
                        .fill(c)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.35)))
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: model.color == c ? 2 : 0).padding(-3))
                        .contentShape(Circle())
                        .onTapGesture { model.color = c }
                }
            }
            Divider().frame(height: 22)
            HStack(spacing: 2) {
                ForEach([2.0, 4.0, 8.0], id: \.self) { w in
                    Button { model.width = w } label: {
                        Circle().frame(width: 4 + w, height: 4 + w)
                            .frame(width: 24, height: 24)
                            .background(RoundedRectangle(cornerRadius: 6)
                                .fill(model.width == w ? Color.white.opacity(0.2) : Color.clear))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(L("Толщина"))
                }
            }
            Spacer(minLength: 4)
            Button { model.saveAndClose() } label: { Image(systemName: "square.and.arrow.down") }
                .help(L("Сохранить в папку и скопировать (⌘S)"))
            Button { model.copyAndClose() } label: { Label(L("Копировать"), systemImage: "doc.on.doc") }
                .buttonStyle(.borderedProminent)
                .help(L("Скопировать и закрыть (⌘C или ↩)"))
            Button { model.close() } label: { Image(systemName: "xmark") }
                .help(L("Закрыть (Esc)"))
        }
        .controlSize(.regular)
        .padding(.horizontal, 10)
        .frame(width: actionsSize.width, height: actionsSize.height)
        .background(RoundedRectangle(cornerRadius: 11).fill(.regularMaterial))
        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
    }

    private func actionsOffset(_ s: CGRect) -> CGSize {
        var x = s.maxX - actionsSize.width
        x = min(max(x, 4), model.size.width - actionsSize.width - 4)
        var y = s.maxY + 8
        if y + actionsSize.height > model.size.height - 4 { y = s.minY - actionsSize.height - 8 }
        if y < 4 { y = s.maxY - actionsSize.height - 8 }   // внутри области, снизу
        return CGSize(width: x, height: y)
    }
}
