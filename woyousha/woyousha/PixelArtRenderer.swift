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

    /// 主体画布尺寸沿用已有规则；长投影使用独立画布，不影响点击范围和保存位置。
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

    /// 独立的方向投影，挂墙家具返回 nil。
    static func furnitureShadow(id: String, mirrored: Bool = false) -> PixelArtShadow? {
        guard !wallMountedFurniture.contains(id) else { return nil }
        let model=furnitureModel(id:id,mirrored:mirrored)
        return IsoShadowRenderer.render(model,scale:furniturePixelScale)
    }

    static func furnitureBounds(id: String, mirrored: Bool = false) -> CGRect {
        bounds(of:furnitureModel(id:id,mirrored:mirrored))
    }

    static func decoration(kind: RoomDecoration.Kind, style: String, mirrored: Bool = false) -> CGImage? {
        let model = decorationModel(kind:kind,style:style,mirrored:mirrored)
        return SpriteCanvas(model).render(model)
    }

    /// 墙面装饰和平铺地毯没有落地的体积，不投影子。
    static func decorationShadow(kind: RoomDecoration.Kind, style: String, mirrored: Bool = false) -> PixelArtShadow? {
        guard !kind.isWallMounted, !kind.isFloorCovering else { return nil }
        let model = decorationModel(kind:kind,style:style,mirrored:mirrored)
        return IsoShadowRenderer.render(model,scale:furniturePixelScale)
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

    /// 包含透明留边的图片范围；影子按这个范围对齐，取整余量也计入。
    static func spriteBounds(contentBounds: CGRect) -> CGRect {
        CGRect(x:contentBounds.minX-spritePadding,y:contentBounds.minY-spritePadding,
               width:ceil(contentBounds.width+spritePadding*2),height:ceil(contentBounds.height+spritePadding*2))
    }

    static func room(style: String) -> CGImage? {
        guard let source=IsoRasterizer.render(IsometricRoom.model(style:style),width:roomWidth,height:roomHeight,projection:roomProjection),
              let shadow=IsoShadowRenderer.render(IsometricRoom.shadowCasters(),scale:roomPixelScale,groundPlane:0),
              let sourceData=source.dataProvider?.data,let shadowData=shadow.image.dataProvider?.data else { return nil }
        var pixels = [UInt8](sourceData as Data)
        let shadowPixels = [UInt8](shadowData as Data)
        for y in 0..<roomHeight {
            for x in 0..<roomWidth {
                // 只覆盖地板上的像素，墙面、底座和透明背景不接收建筑投影。
                let difference = (Double(x)+0.5-roomProjection.origin.x)/roomPixelScale
                let sum = 2*(Double(y)+0.5-roomProjection.origin.y)/roomPixelScale
                let wx = (sum+difference)/2,wy = (sum-difference)/2
                guard wx>=0,wy>=0,wx<=IsometricRoom.sideLength,wy<=IsometricRoom.sideLength else { continue }
                let sx=Int(floor(Double(x)-roomProjection.origin.x-shadow.bounds.minX))
                let sy=Int(floor(Double(y)-roomProjection.origin.y-shadow.bounds.minY))
                guard sx>=0,sy>=0,sx<shadow.image.width,sy<shadow.image.height else { continue }
                let a=(sy*shadow.image.width+sx)*4,b=(y*roomWidth+x)*4
                let alpha=Double(shadowPixels[a+3])/255
                guard alpha>0,pixels[b+3]==255 else { continue }
                for channel in 0..<3 {
                    pixels[b+channel]=UInt8(min(255,(Double(pixels[b+channel])*(1-alpha)+Double(shadowPixels[a+channel])).rounded()))
                }
            }
        }
        return IsoRasterizer.image(pixels,width:roomWidth,height:roomHeight)
    }

    static func furnishedExample(style: String) -> CGImage? {
        IsoRasterizer.render(IsometricRoom.furnishedExample(style:style),width:roomWidth,height:roomHeight,projection:roomProjection)
    }
}
