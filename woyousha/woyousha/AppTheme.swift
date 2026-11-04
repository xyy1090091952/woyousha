import SwiftUI

/// 页面布局与业务尺寸。品牌颜色在 AppThemeColors，按钮在 AppControls。
extension AppTheme {
    enum Layout {
        static let pagePadding: CGFloat = 20
        static let cornerRadius: CGFloat = 24
        static let controlHeight = AppControlMetrics.height
        static let photoHeight: CGFloat = 260
        static let imageDimension = PhotoProcessingSettings.imageDimension
        static let thumbnailDimension = StickerStyle.thumbnailDimension
        static let quantityRange = ItemLimits.quantityRange
        static let buttonDepth = AppControlMetrics.depth
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
