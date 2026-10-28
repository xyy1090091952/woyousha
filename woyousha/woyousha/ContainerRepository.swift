import SwiftData
import Foundation

@MainActor
enum ContainerRepository {
    enum ValidationError: Error { case invalidName }

    static func save(name: String, icon: String, furnitureImage: String?, editing container: Container?, in context: ModelContext) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName
        }
        // 先提交已有变更，再进行本次同步事务。失败回滚不会影响此前的收纳操作。
        try context.save()
        let target = container ?? Container(name: name)
        if container == nil { context.insert(target) }
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.icon = icon
        target.furnitureImageName = furnitureImage
        target.updatedDate = Date()
        if let furnitureImage, let config = FurnitureConfig.get(byImageName: furnitureImage) {
            target.gridWidth = config.width
            target.gridDepth = config.depth
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    static func delete(_ container: Container, in context: ModelContext) throws {
        try context.save()
        context.delete(container)
        // Container 的 nullify 关系会保留物品，只清空所属容器。
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
