import CoreGraphics
import Foundation

/// 原生 2D 等轴绘制入口，与 JavaScript Canvas 2D 的投影绘制思路相同。
/// 几何模型、光照、遮挡与最后的像素输出各自独立，避免逐张图手调角度。
nonisolated enum PixelArtRenderer {
    static let roomWidth = 448
    static let roomHeight = 368
    static let roomPixelScale = 1.5
    static let furniturePixelScale = 2.0
    // 普通/选中共用画布，四周预留轮廓空间，切换选中不会改变大小或位置。
    static let selectionOutlineRadius = 6.0
    static let spritePadding = selectionOutlineRadius + 2
    static let roomProjection = IsoProjection(scale:roomPixelScale,origin:CGPoint(x:224,y:136))

    static func furniture(id: String, mirrored: Bool = false) -> CGImage? {
        let original=IsometricFurniture.model(id)
        let model=mirrored ? original.exchangingAxes() : original
        let bounds=bounds(of:model)
        let projection=IsoProjection(scale:furniturePixelScale,
                                     origin:CGPoint(x:spritePadding-bounds.minX,y:spritePadding-bounds.minY))
        return IsoRasterizer.render(model,width:Int(ceil(bounds.width+spritePadding*2)),
                                    height:Int(ceil(bounds.height+spritePadding*2)),projection:projection)
    }

    static func furnitureBounds(id: String) -> CGRect {
        bounds(of:IsometricFurniture.model(id))
    }

    static func decoration(kind: RoomDecoration.Kind, style: String, mirrored: Bool = false) -> CGImage? {
        let original = IsometricDecoration.model(kind,style:style)
        let model = mirrored ? original.exchangingAxes() : original
        let box = bounds(of:model)
        let projection = IsoProjection(scale:furniturePixelScale,
                                       origin:CGPoint(x:spritePadding-box.minX,y:spritePadding-box.minY))
        return IsoRasterizer.render(model,width:Int(ceil(box.width+spritePadding*2)),
                                    height:Int(ceil(box.height+spritePadding*2)),projection:projection)
    }

    static func decorationBounds(kind: RoomDecoration.Kind, mirrored: Bool = false) -> CGRect {
        let original = IsometricDecoration.model(kind,style:"home1")
        return bounds(of:mirrored ? original.exchangingAxes() : original)
    }

    private static func bounds(of model: IsoMesh) -> CGRect {
        let projection=IsoProjection(scale:furniturePixelScale,origin:.zero)
        let points=model.faces.flatMap(\.points).map(projection.project)
        guard let first=points.first else { return CGRect(x:0,y:0,width:1,height:1) }
        return points.dropFirst().reduce(CGRect(origin:first,size:.zero)) { bounds,p in
            let x=min(bounds.minX,p.x), y=min(bounds.minY,p.y)
            return CGRect(x:x,y:y,width:max(bounds.maxX,p.x)-x,height:max(bounds.maxY,p.y)-y)
        }
    }

    static func room(style: String) -> CGImage? {
        IsoRasterizer.render(IsometricRoom.model(style:style),width:roomWidth,height:roomHeight,projection:roomProjection)
    }

    static func furnishedExample(style: String) -> CGImage? {
        IsoRasterizer.render(IsometricRoom.furnishedExample(style:style),width:roomWidth,height:roomHeight,projection:roomProjection)
    }
}
