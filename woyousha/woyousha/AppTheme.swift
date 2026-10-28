import SwiftUI

/// 全应用共用的颜色和尺寸。以后调整风格，只需优先修改这里。
enum AppTheme {
    static let background = adaptive(light: 0xF6F4EF, dark: 0x1C201D)
    static let surface = adaptive(light: 0xFFFEFA, dark: 0x292E2A)
    static let inset = adaptive(light: 0xECEFE7, dark: 0x353D35)
    static let accent = adaptive(light: 0x355C49, dark: 0xAFCEB6)
    static let onAccent = adaptive(light: 0xFFFFFF, dark: 0x203628)
    static let text = adaptive(light: 0x28372E, dark: 0xF0F3EB)
    static let secondaryText = adaptive(light: 0x6E776F, dark: 0xB2BAB1)
    static let line = adaptive(light: 0xE3E6DC, dark: 0x414A41)
    static let cameraBackground = Color(hex: "141C18")

    enum Layout {
        static let pagePadding: CGFloat = 20
        static let cornerRadius: CGFloat = 24
        static let controlHeight: CGFloat = 52
        static let photoHeight: CGFloat = 260
        static let imageDimension: CGFloat = 1024
        static let thumbnailDimension: CGFloat = 200
        static let quantityRange = ItemLimits.quantityRange
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((value >> 16) & 255) / 255,
                green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255,
                alpha: 1
            )
        })
    }
}

struct AppButtonStyle: ButtonStyle {
    var isPrimary = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(isPrimary ? AppTheme.onAccent : AppTheme.accent)
            .padding(.horizontal, 18)
            .frame(minHeight: AppTheme.Layout.controlHeight)
            .background(isPrimary ? AppTheme.accent : AppTheme.inset, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
    }
}

struct AppSection<Content: View>: View {
    let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(AppTheme.text)
            content
        }
        .appSurface()
    }
}

extension View {
    func appSurface() -> some View {
        padding(AppTheme.Layout.pagePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius)
                    .strokeBorder(AppTheme.line.opacity(0.65), lineWidth: 1)
            }
    }
}

/// 原生照片舞台：共用于录入和详情，让透明贴纸在浅色背景上更清楚。
struct ItemPhotoStage: View {
    let image: UIImage?
    var height: CGFloat = AppTheme.Layout.photoHeight
    var emptyTitle = "给物品拍张照"
    var emptySubtitle = "也可以先填写信息"

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32)
                .fill(AppTheme.inset)
            Circle()
                .fill(AppTheme.surface.opacity(0.65))
                .frame(width: height * 0.76, height: height * 0.76)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(28)
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 6)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera")
                        .font(.system(size: 38, weight: .light))
                    Text(emptyTitle)
                        .font(.system(.headline, design: .rounded))
                    Text(emptySubtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .foregroundStyle(AppTheme.accent)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(image == nil ? "尚未添加物品照片" : "物品照片")
    }
}

extension Category {
    var symbol: String {
        switch self {
        case .clothes: return "tshirt"
        case .tools: return "wrench.and.screwdriver"
        case .medicine: return "pills"
        case .books: return "books.vertical"
        case .food: return "carrot"
        case .digital: return "desktopcomputer"
        case .other: return "shippingbox"
        }
    }
}
