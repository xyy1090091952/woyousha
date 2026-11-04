import SwiftData
import Foundation

@MainActor
enum ContainerRepository {
    enum ValidationError: Error { case invalidName }

    static func save(name: String, furnitureImage: String?, editing container: Container?, in context: ModelContext) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ValidationError.invalidName
        }
        let styleID = FurnitureConfig.styleID(
            name: trimmedName, icon: container?.icon ?? FurnitureConfig.defaultIcon, savedID: furnitureImage
        )
        let metrics=HouseFurnitureCatalog.furniture(styleID,mirrored:container?.isMirrored ?? false)
        // 编辑收纳容器也要遵守家园占地，不能从编辑页绕过家具碰撞校验。
        if let container,container.isPlaced,container.usesGridPlacement {
            let all=try context.fetch(FetchDescriptor<Container>())
            try HousePlacementRules.validate(cell:.init(x:container.gridX,y:container.gridY),footprint:metrics.footprint,
                layer:HouseFurnitureCatalog.layer(for:styleID),outdoors:HouseFurnitureCatalog.outdoors(styleID),
                layout:HouseLayoutStore.shared.layout,
                occupants:HouseFurnitureCatalog.occupants(containers:all,decorations:RoomDecorationStore.shared.decorations),
                excluding:container.id.uuidString)
        }
        // 先提交已有变更，再进行本次同步事务。失败回滚不会影响此前的收纳操作。
        try context.save()
        let target = container ?? Container(name: name)
        if container == nil { context.insert(target) }
        target.name = trimmedName
        // 图标和占地由同一造型配置派生，编辑页无需再维护第二套图标选择。
        target.furnitureImageName = styleID
        target.updatedDate = Date()
        if let config = FurnitureConfig.get(byImageName: styleID) {
            target.icon = config.icon
            target.gridWidth = metrics.footprint.width
            target.gridDepth = metrics.footprint.depth
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
