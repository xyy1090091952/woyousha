import Foundation
import CoreGraphics

/// 位置记录在桌面原始坐标中；桌子转向时自动交换两条水平轴。
nonisolated struct HouseSurfaceAttachment: Codable, Hashable {
    let supportID: String
    var u: Double
    var v: Double
}

nonisolated enum HouseStackingError: LocalizedError {
    case unsupported, missingSupport, outside, occupied
    var errorDescription: String? {
        switch self {
        case .unsupported: return "这件家具不能放到桌面上。"
        case .missingSupport: return "请先把支撑家具放回房间。"
        case .outside: return "摆件需要完整放在桌面内。"
        case .occupied: return "这个位置已有摆件，请换一个桌面位置。"
        }
    }
}

extension Container {
    var surfaceAttachment: HouseSurfaceAttachment? {
        get { surfaceSupportID.map { .init(supportID:$0,u:surfaceU,v:surfaceV) } }
        set { surfaceSupportID=newValue?.supportID;surfaceU=newValue?.u ?? 0.5;surfaceV=newValue?.v ?? 0.5 }
    }
}

@MainActor enum HouseStackingRules {
    static let nudgeDistance = HouseGridConfig.tile/4
    static let clearance = 0.25

    static func snapshots(containers:[Container], decorations:[RoomDecoration]) -> [HouseSceneItem] {
        containers.map {
            .init(id:$0.id.uuidString,source:.furniture($0.resolvedStyleID),cell:.init(x:$0.gridX,y:$0.gridY),
                  mirrored:$0.isMirrored,attachment:$0.surfaceAttachment,isPlaced:$0.isPlaced && $0.usesGridPlacement)
        } + decorations.map {
            .init(id:$0.id,source:.decoration($0.kind),cell:.init(x:$0.gridX ?? 0,y:$0.gridY ?? 0),
                  mirrored:$0.isMirrored,attachment:$0.surfaceAttachment,isPlaced:$0.isPlaced && $0.gridX != nil)
        }
    }

    static func support(for attachment:HouseSurfaceAttachment, among items:[HouseSceneItem]) throws -> HouseSceneItem {
        guard let parent=items.first(where:{$0.id == attachment.supportID}),parent.isPlaced,parent.attachment == nil,
              HouseFurnitureAttributes.surface(parent.source) != nil else { throw HouseStackingError.missingSupport }
        return parent
    }

    /// 桌面使用精确尺寸；小花瓶不需要占据一整格。
    static func localRect(child:HouseSceneItem, attachment:HouseSurfaceAttachment, parent:HouseSceneItem) -> CGRect {
        let surface=HouseFurnitureAttributes.surface(parent.source)!
        let size=child.metrics.size
        let width=parent.mirrored ? size.y:size.x,depth=parent.mirrored ? size.x:size.y
        return .init(x:surface.bounds.minX+attachment.u*surface.bounds.width-width/2,
                     y:surface.bounds.minY+attachment.v*surface.bounds.height-depth/2,width:width,height:depth)
    }

    static func validate(child:HouseSceneItem, attachment:HouseSurfaceAttachment, among items:[HouseSceneItem]) throws {
        guard child.id != attachment.supportID,HouseFurnitureAttributes.canSitOnSurface(child.source) else {
            throw HouseStackingError.unsupported
        }
        let parent=try support(for:attachment,among:items)
        guard attachment.u.isFinite,attachment.v.isFinite,
              (0...1).contains(attachment.u),(0...1).contains(attachment.v) else { throw HouseStackingError.outside }
        let surface=HouseFurnitureAttributes.surface(parent.source)!
        let rect=localRect(child:child,attachment:attachment,parent:parent)
        guard surface.bounds.insetBy(dx:clearance,dy:clearance).contains(rect) else { throw HouseStackingError.outside }
        var blocked=surface.reserved
        for sibling in items where sibling.id != child.id && sibling.isPlaced && sibling.attachment?.supportID == parent.id {
            blocked.append(localRect(child:sibling,attachment:sibling.attachment!,parent:parent))
        }
        guard !blocked.contains(where:{$0.insetBy(dx:-clearance,dy:-clearance).intersects(rect)}) else {
            throw HouseStackingError.occupied
        }
    }

    static func origin(child:HouseSceneItem, attachment:HouseSurfaceAttachment, parent:HouseSceneItem) -> IsoPoint {
        let surface=HouseFurnitureAttributes.surface(parent.source)!
        var x=surface.bounds.minX+attachment.u*surface.bounds.width
        var y=surface.bounds.minY+attachment.v*surface.bounds.height
        if parent.mirrored { swap(&x,&y) }
        let base=parent.metrics.origin(at:parent.cell),model=child.metrics
        return .init(base.x+x-model.minimum.x-model.size.x/2,
                     base.y+y-model.minimum.y-model.size.y/2,
                     base.z+surface.height+0.04-model.minimum.z)
    }

    /// 父家具收起时组合隐藏；删除父家具后子物件仍保留在待布置区。
    static func resolve(_ items:[HouseSceneItem]) -> [HouseSceneItem] {
        items.filter(\.isPlaced).compactMap { original in
            var item=original
            guard let attachment=item.attachment else { return item }
            guard let parent=try? support(for:attachment,among:items) else { return nil }
            item.cell=parent.cell
            item.resolvedOrigin=origin(child:item,attachment:attachment,parent:parent)
            return item
        }
    }

    static func firstFree(child:HouseSceneItem, parentID:String, among items:[HouseSceneItem]) -> HouseSurfaceAttachment? {
        for row in 1..<20 { for column in 1..<20 {
            let attachment=HouseSurfaceAttachment(supportID:parentID,u:Double(column)/20,v:Double(row)/20)
            if (try? validate(child:child,attachment:attachment,among:items)) != nil { return attachment }
        }}
        return nil
    }

    static func destinations(child:HouseSceneItem, among items:[HouseSceneItem]) -> [HouseSurfaceAttachment] {
        guard HouseFurnitureAttributes.canSitOnSurface(child.source) else { return [] }
        return items.filter {$0.isPlaced && $0.attachment == nil && $0.id != child.id}.compactMap {
            firstFree(child:child,parentID:$0.id,among:items)
        }
    }

    static func nudged(_ attachment:HouseSurfaceAttachment, x:Int,y:Int, among items:[HouseSceneItem]) throws -> HouseSurfaceAttachment {
        let parent=try support(for:attachment,among:items),surface=HouseFurnitureAttributes.surface(parent.source)!
        return .init(supportID:attachment.supportID,
                     u:attachment.u+Double(parent.mirrored ? y:x)*nudgeDistance/surface.bounds.width,
                     v:attachment.v+Double(parent.mirrored ? x:y)*nudgeDistance/surface.bounds.height)
    }

    /// 从摆件底部中心按桌面高度逆投影，避免花瓶看起来对准桌面却被判断成地面。
    static func dragAttachment(child:HouseSceneItem, screen:CGPoint, metrics:HouseSceneMetrics,
                               among items:[HouseSceneItem]) -> HouseSurfaceAttachment? {
        guard HouseFurnitureAttributes.canSitOnSurface(child.source) else { return nil }
        let parents=items.filter {$0.isPlaced && $0.attachment == nil && $0.id != child.id &&
            HouseFurnitureAttributes.surface($0.source) != nil}.sorted {$0.cell.x+$0.cell.y > $1.cell.x+$1.cell.y}
        for parent in parents {
            let surface=HouseFurnitureAttributes.surface(parent.source)!,base=parent.metrics.origin(at:parent.cell)
            let point=metrics.worldPoint(screen,z:base.z+surface.height)
            var x=point.x-base.x,y=point.y-base.y
            if parent.mirrored { swap(&x,&y) }
            let u=(x-surface.bounds.minX)/surface.bounds.width,v=(y-surface.bounds.minY)/surface.bounds.height
            if (0...1).contains(u),(0...1).contains(v) {
                // 细分槽位减少无意义刷新，同时保留细小摆件的移动精度。
                return .init(supportID:parent.id,u:(u*40).rounded()/40,v:(v*40).rounded()/40)
            }
        }
        return nil
    }

    static func validatePlacement(_ target:HouseSceneItem, among items:[HouseSceneItem], layout:HouseLayout) throws {
        if let attachment=target.attachment { try validate(child:target,attachment:attachment,among:items) }
        else {
            let occupants=items.filter {$0.isPlaced && $0.attachment == nil}.map {
                HouseOccupant(id:$0.id,cell:$0.cell,footprint:$0.metrics.footprint,layer:$0.layer)
            }
            let outdoor:Bool
            if case .furniture(let id)=target.source { outdoor=HouseFurnitureCatalog.outdoors(id) } else { outdoor=false }
            try HousePlacementRules.validate(cell:target.cell,footprint:target.metrics.footprint,layer:target.layer,
                outdoors:outdoor,layout:layout,occupants:occupants,excluding:target.id)
        }
        // 换造型/转向也不能把桌面上的摆件挤出桌沿或撞进内置书本。
        let updated=items.map {$0.id == target.id ? target:$0}
        for child in updated where child.isPlaced && child.attachment?.supportID == target.id {
            try validate(child:child,attachment:child.attachment!,among:updated)
        }
    }
}
