import CoreGraphics
import Foundation

/// 原生 2D 等轴绘制入口，与 JavaScript Canvas 2D 的投影绘制思路相同。
/// 几何模型、光照、遮挡与最后的像素输出各自独立，避免逐张图手调角度。
nonisolated enum PixelArtRenderer {
    // 像素密度：1 个世界单位 = 1.125 个像素。数值越小像素颗粒越粗（参考“3D 像素网球”的粗颗粒）。
    // 画布宽高、投影原点与它一起等比换算；显示时按 RoomConfig 等比放大，家具和装饰的屏幕尺寸与位置不变。
    static let roomPixelScale = 1.125
    static let roomWidth = 336
    static let roomHeight = 276
    // 家具与房间用同样大小的像素，同屏不会出现粗细不一的“混合像素”。
    static let furniturePixelScale = roomPixelScale
    // 普通/选中共用画布，四周预留轮廓空间，切换选中不会改变大小或位置。
    // 白边用世界单位定义，随像素密度自动换算，屏幕上的粗细保持不变；留边再多 2 像素防止白边贴到画布边。
    static let selectionOutlineRadius = 3 * furniturePixelScale
    static let spritePadding = selectionOutlineRadius + 2
    static let roomProjection = IsoProjection(scale:roomPixelScale,origin:CGPoint(x:168,y:102))

    /// 挂在墙上的家具不落地，不投地面影子。
    static let wallMountedFurniture: Set<String> = [
        "chuanghu", "mirror", "wall-panel", "air-conditioner", "floating-cabinet", "wall-bookcase"
    ]

    /// 单件家具/装饰的小画布：模型包围盒四周留出 spritePadding，主体图与影子图共用。
    private struct SpriteCanvas {
        let width: Int
        let height: Int
        let projection: IsoProjection

        init(_ model: IsoMesh) {
            let box = PixelArtRenderer.bounds(of:model)
            width = Int(ceil(box.width+PixelArtRenderer.spritePadding*2))
            height = Int(ceil(box.height+PixelArtRenderer.spritePadding*2))
            projection = IsoProjection(scale:PixelArtRenderer.furniturePixelScale,
                                       origin:CGPoint(x:PixelArtRenderer.spritePadding-box.minX,
                                                      y:PixelArtRenderer.spritePadding-box.minY))
        }

        func render(_ model: IsoMesh) -> CGImage? {
            IsoRasterizer.render(model,width:width,height:height,projection:projection)
        }

        func shadow(_ model: IsoMesh) -> CGImage? {
            IsoRasterizer.groundShadow(model,width:width,height:height,projection:projection)
        }
    }

    private static func furnitureModel(id: String, mirrored: Bool) -> IsoMesh {
        let original=IsometricFurniture.model(id)
        return mirrored ? original.exchangingAxes() : original
    }

    private static func decorationModel(kind: RoomDecoration.Kind, style: String, mirrored: Bool) -> IsoMesh {
        let original = IsometricDecoration.model(kind,style:style)
        return mirrored ? original.exchangingAxes() : original
    }

    static func furniture(id: String, mirrored: Bool = false) -> CGImage? {
        let model=furnitureModel(id:id,mirrored:mirrored)
        return SpriteCanvas(model).render(model)
    }

    /// 与 furniture(id:mirrored:) 同尺寸的透明影子图；挂墙家具返回 nil。
    static func furnitureShadow(id: String, mirrored: Bool = false) -> CGImage? {
        guard !wallMountedFurniture.contains(id) else { return nil }
        let model=furnitureModel(id:id,mirrored:mirrored)
        return SpriteCanvas(model).shadow(model)
    }

    static func furnitureBounds(id: String) -> CGRect {
        bounds(of:IsometricFurniture.model(id))
    }

    static func decoration(kind: RoomDecoration.Kind, style: String, mirrored: Bool = false) -> CGImage? {
        let model = decorationModel(kind:kind,style:style,mirrored:mirrored)
        return SpriteCanvas(model).render(model)
    }

    /// 墙面装饰和平铺地毯没有落地的体积，不投影子。
    static func decorationShadow(kind: RoomDecoration.Kind, style: String, mirrored: Bool = false) -> CGImage? {
        guard !kind.isWallMounted, !kind.isFloorCovering else { return nil }
        let model = decorationModel(kind:kind,style:style,mirrored:mirrored)
        return SpriteCanvas(model).shadow(model)
    }

    static func decorationBounds(kind: RoomDecoration.Kind, mirrored: Bool = false) -> CGRect {
        bounds(of:decorationModel(kind:kind,style:"home1",mirrored:mirrored))
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
