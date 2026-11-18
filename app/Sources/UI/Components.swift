import SwiftUI

/// Цветной квадратик с символом, как в Системных настройках.
struct PageIcon: View {
    let page: Page
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: page.symbol)
            .font(.system(size: size * 0.52, weight: .medium))
            .shadow(color: .black.opacity(0.15), radius: 0.5, y: 0.5)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous).fill(page.color.gradient))
            .overlay(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
    }
}

struct SoonBadge: View {
    var body: some View {
        Text(L("скоро"))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(Color.secondary.opacity(0.15)))
            .foregroundStyle(.secondary)
    }
}

/// Заголовок раздела по центру — как в «Системных настройках».
struct PageHeader: View {
    let page: Page

    var body: some View {
        VStack(spacing: 8) {
            PageIcon(page: page, size: 56)
            Text(page.title).font(.title2.bold())
            Text(page.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

/// Плашка про доступ «Универсальный доступ».
struct PermissionBanner: View {
    @EnvironmentObject var status: AppStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.trusted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(status.trusted ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.trusted ? L("Всё работает") : L("Нужен доступ"))
                    .font(.headline)
                Text(status.trusted
                     ? L("У MacTools есть «Универсальный доступ».")
                     : L("Включите MacTools в «Конфиденциальность и безопасность → Универсальный доступ»."))
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if !status.trusted {
                Button(L("Открыть настройки")) { AX.openAccessibilitySettings() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill((status.trusted ? Color.green : Color.orange).opacity(0.1)))
    }
}

/// Клавиша на клавиатуре.
struct KeyCap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .frame(minWidth: 22, minHeight: 20)
            .padding(.horizontal, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color(nsColor: .separatorColor)))
            .shadow(color: .black.opacity(0.08), radius: 0, y: 1)
    }
}

/// Мини-схема экрана с подсвеченной областью.
struct SnapPreview: View {
    let rect: CGRect
    var color: Color = .accentColor
    private let w: CGFloat = 40, h: CGFloat = 26

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.12))
            RoundedRectangle(cornerRadius: 3)
                .fill(color.gradient)
                .frame(width: max(rect.width * w - 3, 2), height: max(rect.height * h - 3, 2))
                .offset(x: rect.minX * w + 1.5, y: rect.minY * h + 1.5)
        }
        .frame(width: w, height: h)
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(nsColor: .separatorColor)))
    }
}
