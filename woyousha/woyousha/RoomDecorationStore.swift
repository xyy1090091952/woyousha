import Foundation
import Observation

/// 装饰物状态与存储共用一处。编码失败保持旧状态，避免首页与装修页面显示不一致。
@MainActor @Observable
final class RoomDecorationStore {
    static let shared = RoomDecorationStore()
    private(set) var decorations: [RoomDecoration]
    private let storage: UserDefaults
    private let storageKey = "roomDecorationPlacements.v1"

    enum Action {
        case move(Double, Double), scale(Double), mirror, forward, backward, delete
    }

    init(storage: UserDefaults = .standard) {
        self.storage = storage
        if let data = storage.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([RoomDecoration].self, from:data) {
            // 一次性清理旧版“收回仓库”的记录；房间里正在摆放的装饰保持原位置。
            let placed = saved.filter(\.isPlaced)
            decorations = placed
            if placed.count != saved.count, let cleaned = try? JSONEncoder().encode(placed) {
                storage.set(cleaned, forKey: storageKey)
            }
        } else {
            decorations = DecorationCatalog.defaults
        }
    }

    func perform(_ action: Action, id: String, furnitureLayers: [Int] = []) throws {
        guard let index = decorations.firstIndex(where: { $0.id == id }) else { return }
        var updated = decorations
        switch action {
        case .move(let x, let y):
            updated[index].posX = RoomConfig.snap(x)
            updated[index].posY = RoomConfig.snap(y)
        case .scale(let value):
            guard value.isFinite else { return }
            updated[index].scale = min(max(value,RoomConfig.furnitureRange.lowerBound),RoomConfig.furnitureRange.upperBound)
        case .mirror: updated[index].isMirrored.toggle()
        case .delete: updated.remove(at: index)
        case .forward:
            updated[index].zIndex = (decorations.map(\.zIndex)+furnitureLayers).max().map { $0+1 } ?? 0
        case .backward:
            let layers = decorations.filter { !$0.kind.isFloorCovering }.map(\.zIndex)+furnitureLayers
            updated[index].zIndex = max(-900,(layers.min() ?? 0)-1)
        }
        try commit(updated)
    }

    func add(kind: RoomDecoration.Kind, furnitureLayers: [Int] = []) throws -> String {
        var updated = decorations
        let id = UUID().uuidString
        let position = RoomConfig.initialFurniturePosition
        let layer = (decorations.map(\.zIndex) + furnitureLayers).max().map { $0 + 1 } ?? 0
        updated.append(RoomDecoration(id: id, kind: kind, posX: position.x, posY: position.y, zIndex: layer))
        try commit(updated)
        return id
    }

    /// 先编码保存，再发布界面状态；失败时不会出现“画面已删除、重开又回来”的状态分叉。
    private func commit(_ updated: [RoomDecoration]) throws {
        let data = try JSONEncoder().encode(updated)
        storage.set(data, forKey: storageKey)
        decorations = updated
    }
}
