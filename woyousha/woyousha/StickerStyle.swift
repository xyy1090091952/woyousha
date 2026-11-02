import CoreGraphics
import Foundation

/// 手帐贴纸的尺寸参数共用，缩放网格时不另写一套字体或边框数值。
nonisolated enum StickerStyle {
    static let dotSpacing: CGFloat = 24
    static let dotDiameter: CGFloat = 2
    static let thumbnailDimension: CGFloat = 200
    static let thumbnailOutlineRadius: CGFloat = 2
    static let thumbnailRoundingRadius: CGFloat = 1
    static let thumbnailPadding: CGFloat = 4
    static let subjectAlphaThreshold: UInt8 = 8
    static let minimumComponentRatio: CGFloat = 0.01
    static let subjectCropMargin = 1
    static let minimumColumnCount = 2
    static let maximumColumnCount = 5
    static let columnSpacing: CGFloat = 16
    static let rowSpacing: CGFloat = 12
    static let cellPadding: CGFloat = 4
    static let imageInset: CGFloat = 4
    static let nameSpacing: CGFloat = 6
    static let imageHeightRatio: CGFloat = 1.2
    static let minimumImageHeight: CGFloat = 60
    static let maximumImageHeight: CGFloat = 240
    // 同一格内让“看得见的面积”接近半个正方形，给细长/空心物品留下放大余地。
    static let targetVisibleAreaRatio: CGFloat = 0.50
    static let minimumVisibleCoverage: CGFloat = 0.05
    static let minimumRotation: Double = 2
    static let maximumRotation: Double = 5.5
    static let textOutlineWidth: CGFloat = 4
    static let minimumQuantityWidth: CGFloat = 30
    static let tabCornerRadius: CGFloat = 30
    static let tabOverlap: CGFloat = 24
    static let thumbnailCacheCount = 128
    static let thumbnailCacheBytes = 16 * 1024 * 1024

    static func quantityFontSize(height: CGFloat) -> CGFloat {
        min(24, max(16, height * 0.15))
    }

    static func nameFontSize(height: CGFloat) -> CGFloat {
        min(20, max(14, height * 0.125))
    }

    /// 极细长物品也给数量留一行空间，三位数不会被压进物品的几像素宽度中。
    static func groupSize(imageSize: CGSize, viewport: CGSize, hasQuantity: Bool) -> CGSize {
        guard hasQuantity else { return imageSize }
        let minimumWidth = min(minimumQuantityWidth, max(1, viewport.width - imageInset))
        let minimumHeight = quantityFontSize(height: viewport.height) * 1.4 + textOutlineWidth * 2
        return CGSize(width: max(imageSize.width, minimumWidth), height: max(imageSize.height, minimumHeight))
    }

    static func clampedColumnCount(_ count: Int) -> Int {
        min(max(count, minimumColumnCount), maximumColumnCount)
    }

    static func columnWidth(containerWidth: CGFloat, pagePadding: CGFloat, count: Int) -> CGFloat {
        let columns = clampedColumnCount(count)
        return max(1, (containerWidth - pagePadding * 2 - CGFloat(columns - 1) * columnSpacing) / CGFloat(columns))
    }

    static func imageHeight(columnWidth: CGFloat) -> CGFloat {
        min(maximumImageHeight, max(minimumImageHeight, columnWidth * imageHeightRatio))
    }

    /// 使用固定哈希而非每次随机：改名字、数量、切分类、缩放网格均不会改变倾斜角。
    static func rotationAngle(for id: UUID) -> Double {
        let hash = id.uuidString.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        let magnitude = minimumRotation + Double((hash >> 1) % 101) / 100 * (maximumRotation - minimumRotation)
        return hash & 1 == 0 ? magnitude : -magnitude
    }

    /// 透明背景不算大小：先按可见面积统一体感，再限制倾斜后的边界，保持比例和完整主体。
    static func imageSize(_ imageSize: CGSize, fitting viewport: CGSize,
                          visibleCoverage: CGFloat = 1, rotationDegrees: Double = 0) -> CGSize {
        let width = max(1, viewport.width - imageInset * 2)
        let height = max(1, viewport.height - imageInset * 2)
        guard imageSize.width > 0, imageSize.height > 0 else { return CGSize(width: width, height: height) }
        let radians = rotationDegrees * .pi / 180
        let cosine = abs(cos(radians)), sine = abs(sin(radians))
        let rotatedWidth = imageSize.width * cosine + imageSize.height * sine
        let rotatedHeight = imageSize.width * sine + imageSize.height * cosine
        let safeFactor = min(width / rotatedWidth, height / rotatedHeight)
        let coverage = min(1, max(minimumVisibleCoverage, visibleCoverage))
        let targetArea = pow(min(width, height), 2) * targetVisibleAreaRatio
        let areaFactor = sqrt(targetArea / (imageSize.width * imageSize.height * coverage))
        let factor = min(safeFactor, areaFactor)
        return CGSize(width: imageSize.width * factor, height: imageSize.height * factor)
    }
}
