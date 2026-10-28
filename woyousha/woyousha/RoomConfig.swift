import Foundation
import CoreGraphics

/// 共用的房间坐标与交互范围。UI 与数据层使用相同约束。
nonisolated enum RoomConfig {
    static let roomWidth: CGFloat = 800
    static let roomHeight: CGFloat = 800
    static let zoomRange: ClosedRange<CGFloat> = 0.7...3
    static let furnitureRange: ClosedRange<Double> = 0.5...2
    static let initialFurniturePosition = CGPoint(x: 400, y: 460)
    static let pixelStep: Double = 4
    static let inspectorHeight: CGFloat = 242

    static func snap(_ value: Double) -> Double {
        guard value.isFinite else { return 400 }
        return (min(max(value, 40), 760) / pixelStep).rounded() * pixelStep
    }
}
