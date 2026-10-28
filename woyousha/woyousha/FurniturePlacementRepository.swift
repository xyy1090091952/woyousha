import Foundation
import SwiftData
import CoreGraphics

/// 装修修改集中到这里，避免造型、占地尺寸和图层在不同页面各更新一半。
@MainActor
enum FurniturePlacementRepository {
    enum Action {
        case place(CGPoint), move(CGPoint), style(String), mirror, scale(Double)
        case forward, backward, store
    }

    static func perform(_ action: Action, on target: Container, among containers: [Container], in context: ModelContext) throws {
        // 先提交已有操作，本次事务失败只回滚本次装修操作。
        try context.save()
        switch action {
        case .place(let point):
            target.isPlaced = true
            target.posX = RoomConfig.snap(point.x)
            target.posY = RoomConfig.snap(point.y)
            target.zIndex = (containers.map(\.zIndex).max() ?? 0) + 1
        case .move(let point):
            target.posX = RoomConfig.snap(point.x)
            target.posY = RoomConfig.snap(point.y)
        case .style(let id):
            guard let config = FurnitureConfig.get(byImageName: id) else { return }
            target.furnitureImageName = id
            target.gridWidth = config.width
            target.gridDepth = config.depth
        case .mirror:
            target.isMirrored.toggle()
        case .scale(let value):
            guard value.isFinite else { return }
            target.scale = min(max(value, RoomConfig.furnitureRange.lowerBound), RoomConfig.furnitureRange.upperBound)
        case .forward, .backward:
            var ordered = containers.filter(\.isPlaced).sorted {
                $0.zIndex == $1.zIndex ? $0.createdDate < $1.createdDate : $0.zIndex < $1.zIndex
            }
            guard let index = ordered.firstIndex(where: { $0.id == target.id }) else { return }
            let destination = index + (isForward(action) ? 1 : -1)
            if ordered.indices.contains(destination) { ordered.swapAt(index, destination) }
            for (level, container) in ordered.enumerated() { container.zIndex = level }
        case .store:
            target.isPlaced = false
        }
        target.updatedDate = Date()
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func isForward(_ action: Action) -> Bool {
        if case .forward = action { return true }
        return false
    }
}
