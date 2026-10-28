import SwiftUI

/// 全应用共用的颜色和尺寸。以后调整风格，只需优先修改这里。
enum AppTheme {
    static let background = adaptive(light: 0xFFFFFF, dark: 0x142630)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x1E3642)
    static let inset = adaptive(light: 0xEFF8E6, dark: 0x294737)
    static let accent = adaptive(light: 0x4EA800, dark: 0x78CE23)
    static let accentEdge = adaptive(light: 0x3B8700, dark: 0x488F13)
    static let accentText = adaptive(light: 0x347A00, dark: 0x9FE35C)
    static let onAccent = adaptive(light: 0xFFFFFF, dark: 0x142800)
    static let text = adaptive(light: 0x39464D, dark: 0xECF7FB)
    static let secondaryText = adaptive(light: 0x707C83, dark: 0xA8BDC5)
    static let line = adaptive(light: 0xE3E8EB, dark: 0x38505B)
    static let blue = adaptive(light: 0x168CCA, dark: 0x58C4F9)
    static let blueInset = adaptive(light: 0xE7F6FE, dark: 0x203F50)
    static let yellow = Color(hex: "FFC939")
    static let cameraBackground = Color(hex: "142630")

    enum Layout {
        static let pagePadding: CGFloat = 20
        static let cornerRadius: CGFloat = 24
        static let controlHeight: CGFloat = 52
        static let photoHeight: CGFloat = 260
        static let imageDimension: CGFloat = 1024
        static let thumbnailDimension: CGFloat = 200
        static let quantityRange = ItemLimits.quantityRange
        static let buttonDepth: CGFloat = 4
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
            .font(.system(.headline, design: .rounded, weight: .heavy))
            .foregroundStyle(isPrimary ? AppTheme.onAccent : AppTheme.blue)
            .padding(.horizontal, 18)
            .frame(minHeight: AppTheme.Layout.controlHeight)
            .background(isPrimary ? AppTheme.accent : AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                if !isPrimary {
                    RoundedRectangle(cornerRadius: 18).strokeBorder(AppTheme.line, lineWidth: 2)
                }
            }
            .offset(y: configuration.isPressed ? AppTheme.Layout.buttonDepth : 0)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(isPrimary ? AppTheme.accentEdge : AppTheme.line)
                    .offset(y: AppTheme.Layout.buttonDepth)
            }
            .padding(.bottom, AppTheme.Layout.buttonDepth)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// 小尺寸工具按钮共用凸起底边，避免首页和表单各画一套按钮。
struct ToyIconButtonStyle: ButtonStyle {
    var isPrimary = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .heavy))
            .foregroundStyle(isPrimary ? AppTheme.onAccent : AppTheme.blue)
            .frame(minWidth: 46, minHeight: 46)
            .background(isPrimary ? AppTheme.accent : AppTheme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(isPrimary ? AppTheme.accent : AppTheme.line, lineWidth: 2) }
            .offset(y: configuration.isPressed ? 3 : 0)
            .background {
                RoundedRectangle(cornerRadius: 16).fill(isPrimary ? AppTheme.accentEdge : AppTheme.line).offset(y: 3)
            }
            .padding(.bottom, 3)
            .opacity(isEnabled ? 1 : 0.45)
    }
}

/// 原创收纳盒小表情，以几何形状绘制，跟随系统深色模式。
struct StorageBuddy: View {
    var body: some View {
        GeometryReader { geo in
            let unit = min(geo.size.width, geo.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: unit * 0.24)
                    .fill(AppTheme.accentEdge).offset(y: unit * 0.07)
                RoundedRectangle(cornerRadius: unit * 0.24).fill(AppTheme.accent)
                RoundedRectangle(cornerRadius: unit * 0.05)
                    .fill(Color.white.opacity(0.4))
                    .frame(width: unit * 0.22, height: unit * 0.18)
                    .offset(y: -unit * 0.34)
                HStack(spacing: unit * 0.09) {
                    ForEach(0..<2) { _ in
                        Ellipse().fill(.white).frame(width: unit * 0.25, height: unit * 0.31)
                            .overlay(alignment: .bottom) {
                                Capsule().fill(Color(hex: "263B29")).frame(width: unit * 0.11, height: unit * 0.17).padding(.bottom, unit * 0.03)
                            }
                    }
                }.offset(y: -unit * 0.02)
                Capsule().fill(Color(hex: "286300"))
                    .frame(width: unit * 0.18, height: unit * 0.07).offset(y: unit * 0.27)
            }
            .frame(width: unit, height: unit)
        }
        .accessibilityHidden(true)
    }
}

struct ContainerBadge: View {
    var symbol: String?
    var furnitureID: String?
    var isSelected = false

    var body: some View {
        Group {
            if let furnitureID {
                PixelFurnitureView(styleID: furnitureID).padding(5)
            } else if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(isSelected ? AppTheme.accentText : AppTheme.blue)
            }
        }
        .frame(width: 56, height: 56)
        .background(isSelected ? AppTheme.inset : AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(isSelected ? AppTheme.accent : AppTheme.line, lineWidth: 2)
        }
        .background {
            RoundedRectangle(cornerRadius: 18).fill(isSelected ? AppTheme.accent : AppTheme.line).offset(y: 3)
        }
        .padding(.bottom, 3)
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
                .font(.system(.headline, design: .rounded, weight: .heavy))
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
                    .strokeBorder(AppTheme.line, lineWidth: 2)
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
                .fill(AppTheme.blueInset)
                .overlay { RoundedRectangle(cornerRadius: 32).strokeBorder(AppTheme.blue.opacity(0.25), lineWidth: 2) }
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
                        .font(.system(size: 38, weight: .bold))
                    Text(emptyTitle)
                        .font(.system(.headline, design: .rounded))
                    Text(emptySubtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .foregroundStyle(AppTheme.blue)
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
