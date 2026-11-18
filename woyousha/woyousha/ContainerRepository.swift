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
        var styleID = FurnitureConfig.styleID(
            name: trimmedName, icon: container?.icon ?? FurnitureConfig.defaultIcon, savedID: furnitureImage
        )
        let oldID=container?.resolvedStyleID
        if HouseFurnitureAttributes.role(styleID) == .decorative,oldID != styleID {
            if !(container?.items?.isEmpty ?? true) { throw FurnitureUseError.containsItems }
            // 新建收纳容器的自动名称若命中装饰造型，使用纸箱。
            if furnitureImage == nil { styleID="zhixiang" } else { throw FurnitureUseError.decorativeTarget }
        }
        let metrics=HouseFurnitureCatalog.furniture(styleID,mirrored:container?.isMirrored ?? false)
        // 编辑收纳容器也要遵守家园占地，不能从编辑页绕过家具碰撞校验。
        if let container,container.isPlaced,container.usesGridPlacement {
            let all=try context.fetch(FetchDescriptor<Container>())
            try HouseStackingRules.validatePlacement(
                .init(id:container.id.uuidString,source:.furniture(styleID),cell:.init(x:container.gridX,y:container.gridY),
                      mirrored:container.isMirrored,attachment:container.surfaceAttachment),
                among:HouseStackingRules.snapshots(containers:all,decorations:RoomDecorationStore.shared.decorations),
                layout:HouseLayoutStore.shared.layout)
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
