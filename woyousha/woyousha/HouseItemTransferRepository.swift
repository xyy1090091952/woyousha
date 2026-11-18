import Foundation
import SwiftData

nonisolated enum FurnitureUseError: LocalizedError {
    case decorativeTarget, containsItems
    var errorDescription: String? {
        switch self {
        case .decorativeTarget: return "这是装饰家具，请选择容器家具来收纳物品。"
        case .containsItems: return "请先移出已有物品，再换成装饰家具。"
        }
    }
}

/// 两个拖放入口共用事务；批量移动全部保存成功后才通知界面。
@MainActor enum ItemTransferRepository {
    static func move(ids: Set<UUID>, to target: Container?, in context: ModelContext) throws -> Int {
        guard target?.canReceiveItems != false else { throw FurnitureUseError.decorativeTarget }
        guard !ids.isEmpty else { return 0 }
        let items=try context.fetch(FetchDescriptor<Item>()).filter { ids.contains($0.id) }
        guard !items.isEmpty else { return 0 }
        let previous=items.map { ($0,$0.container,$0.updatedDate) }
        for item in items { item.container=target;item.updatedDate=Date() }
        do { try context.save() }
        catch {
            for (item,container,date) in previous { item.container=container;item.updatedDate=date }
            throw error
        }
        return items.count
    }
}
