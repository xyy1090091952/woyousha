import Foundation
import SwiftData
import CoreGraphics

/// 装修修改集中到这里，避免造型、占地尺寸和图层在不同页面各更新一半。
@MainActor
enum FurniturePlacementRepository {
    enum ValidationError: Error { case unknownStyle }

    enum Action {
        case place(HouseCell), move(HouseCell), style(String), mirror, store, delete
        case attach(HouseSurfaceAttachment), moveSurface(x:Int,y:Int)
    }

    /// 点击目录后一次完成创建与摆放，避免出现“已创建却没放进房间”的半完成状态。
    static func add(styleID: String, among containers: [Container], decorations: [RoomDecoration] = [],
                    layout: HouseLayout? = nil, in context: ModelContext) throws -> Container {
        let layout=layout ?? HouseLayoutStore.shared.layout
        try layout.validate()
        guard let config = FurnitureConfig.get(byImageName: styleID) else {
            throw ValidationError.unknownStyle
        }
        let model=HouseFurnitureCatalog.furniture(styleID)
        let occupants=HouseFurnitureCatalog.occupants(containers:containers,decorations:decorations)
        let first=layout.rooms[0]
        guard let point=HousePlacementRules.nearest(to:.init(x:first.x+1,y:first.y+1),footprint:model.footprint,
            layer:HouseFurnitureCatalog.layer(for:styleID),outdoors:HouseFurnitureCatalog.outdoors(styleID),
            layout:layout,occupants:occupants) else { throw HouseRuleError.noSpace }
        try context.save()
        let target = Container(
            name: config.name, icon: config.icon, gridX:point.x,gridY:point.y,
            gridWidth: model.footprint.width, gridDepth: model.footprint.depth,
            isPlaced: true, furnitureImageName: config.imageName,
            zIndex: point.x+point.y
        )
        target.usesGridPlacement=true
        context.insert(target)
        do {
            try context.save()
            return target
        } catch {
            context.rollback()
            throw error
        }
    }

    static func perform(_ action: Action, on target: Container, among containers: [Container],
                        decorations: [RoomDecoration] = [], layout:HouseLayout? = nil,
                        in context: ModelContext) throws {
        if case .delete=action { try ContainerRepository.delete(target,in:context);return }
        let layout=layout ?? HouseLayoutStore.shared.layout
        try layout.validate()
        let oldID=FurnitureConfig.styleID(name:target.name,icon:target.icon,savedID:target.furnitureImageName)
        let id: String
        if case .style(let value)=action {
            guard FurnitureConfig.get(byImageName:value) != nil else { throw ValidationError.unknownStyle }
            id=value
        } else { id=oldID }
        let mirrored:Bool
        if case .mirror=action { mirrored = !target.isMirrored } else { mirrored=target.isMirrored }
        let cell:HouseCell
        switch action {
        case .place(let point),.move(let point): cell=point
        default: cell = .init(x:target.gridX,y:target.gridY)
        }
        let model=HouseFurnitureCatalog.furniture(id,mirrored:mirrored)
        // 历史误收纳也不允许换成另一件装饰家具。
        if id != oldID,HouseFurnitureAttributes.role(id) == .decorative,!(target.items?.isEmpty ?? true) {
            throw FurnitureUseError.containsItems
        }
        let snapshots=HouseStackingRules.snapshots(containers:containers,decorations:decorations)
        var attachment=target.surfaceAttachment
        switch action {
        case .place,.move: attachment=nil
        case .attach(let value): attachment=value
        case .moveSurface(let x,let y):
            guard let value=attachment else { throw HouseStackingError.missingSupport }
            attachment=try HouseStackingRules.nudged(value,x:x,y:y,among:snapshots)
        default: break
        }
        if !isStore(action) {
            let proposed=HouseSceneItem(id:target.id.uuidString,source:.furniture(id),cell:cell,
                mirrored:mirrored,attachment:attachment)
            try HouseStackingRules.validatePlacement(proposed,among:snapshots,layout:layout)
        }
        // 先提交已有操作，本次事务失败只回滚本次装修操作。
        try context.save()
        switch action {
        case .place, .move:
            target.isPlaced=true
        case .attach,.moveSurface:
            target.isPlaced=true
        case .style(let id):
            guard let config = FurnitureConfig.get(byImageName: id) else { return }
            target.furnitureImageName = id
            target.icon = config.icon
        case .mirror:
            target.isMirrored.toggle()
        case .store:
            target.isPlaced = false
        case .delete: return
        }
        target.gridX=cell.x;target.gridY=cell.y
        target.surfaceAttachment=attachment
        target.gridWidth=model.footprint.width;target.gridDepth=model.footprint.depth
        target.usesGridPlacement=true
        target.scale=1
        // 图层由地面位置决定，用户无需再手工把家具移到前面或后面。
        target.zIndex=cell.x+cell.y+model.footprint.width+model.footprint.depth
        target.updatedDate = Date()
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// 尺寸升级只更新派生字段，不搬动已有家具或改变物品归属。
    static func synchronizeDimensions(_ containers:[Container], in context:ModelContext) throws {
        let changed=containers.filter {
            let size=HouseFurnitureCatalog.furniture($0.resolvedStyleID,mirrored:$0.isMirrored).footprint
            return $0.gridWidth != size.width || $0.gridDepth != size.depth
        }
        guard !changed.isEmpty else { return }
        try context.save()
        for item in changed {
            let size=HouseFurnitureCatalog.furniture(item.resolvedStyleID,mirrored:item.isMirrored).footprint
            item.gridWidth=size.width;item.gridDepth=size.depth
        }
        do { try context.save() } catch { context.rollback();throw error }
    }

    private static func isStore(_ action: Action) -> Bool {
        if case .store = action { return true }
        return false
    }

    /// 旧贴纸一次性对齐。先备份旧摆放，再一次保存所有格子；失败则不标记升级完成。
    static func adoptGrid(among containers:[Container],layout:HouseLayout,in context:ModelContext,
                          storage:UserDefaults = .standard) throws -> Int {
        let legacy=containers.filter { !$0.usesGridPlacement }
        guard !legacy.isEmpty else { return 0 }
        struct Backup: Codable {
            let id:String
            let x:Double
            let y:Double
            let scale:Double
            let placed:Bool
        }
        let backup=legacy.map { Backup(id:$0.id.uuidString,x:$0.posX.isFinite ? $0.posX:0,
            y:$0.posY.isFinite ? $0.posY:0,scale:$0.scale.isFinite ? $0.scale:1,placed:$0.isPlaced) }
        if storage.data(forKey:"homeStickerBackup.v1") == nil {
            storage.set(try JSONEncoder().encode(backup),forKey:"homeStickerBackup.v1")
        }
        try context.save()
        var stored=0
        for target in legacy.sorted(by:{$0.createdDate == $1.createdDate ? $0.id.uuidString < $1.id.uuidString:$0.createdDate < $1.createdDate}) {
            let id=FurnitureConfig.styleID(name:target.name,icon:target.icon,savedID:target.furnitureImageName)
            let model=HouseFurnitureCatalog.furniture(id,mirrored:target.isMirrored)
            if target.isPlaced {
                let desired=legacyCell(x:target.posX,y:target.posY,layout:layout)
                let occupants=HouseFurnitureCatalog.occupants(containers:containers,decorations:[])
                if let cell=HousePlacementRules.nearest(to:desired,footprint:model.footprint,
                    layer:HouseFurnitureCatalog.layer(for:id),outdoors:HouseFurnitureCatalog.outdoors(id),
                    layout:layout,occupants:occupants,excluding:target.id.uuidString) {
                    target.gridX=cell.x;target.gridY=cell.y
                } else { target.isPlaced=false;stored+=1 }
            }
            target.usesGridPlacement=true;target.scale=1
            target.gridWidth=model.footprint.width;target.gridDepth=model.footprint.depth
        }
        do { try context.save() } catch { context.rollback();throw error }
        return stored
    }

    static func legacyCell(x:Double,y:Double,layout:HouseLayout) -> HouseCell {
        let room=layout.rooms[0]
        guard x.isFinite,y.isFinite else { return .init(x:room.x+1,y:room.y+1) }
        let factor=RoomConfig.roomWidth/Double(PixelArtRenderer.roomWidth)
        let inset=(RoomConfig.roomHeight-Double(PixelArtRenderer.roomHeight)*factor)/2
        let px=(x/factor-PixelArtRenderer.roomProjection.origin.x)/PixelArtRenderer.roomPixelScale
        let py=((y-inset)/factor-PixelArtRenderer.roomProjection.origin.y)/PixelArtRenderer.roomPixelScale
        // 历史值仅用于选“附近的空格”，最终位置仍必须通过同一占地校验。
        return .init(x:room.x+Int(min(24,max(-24,(py+px/2)/HouseGridConfig.tile)).rounded()),
                     y:room.y+Int(min(24,max(-24,(py-px/2)/HouseGridConfig.tile)).rounded()))
    }
}
