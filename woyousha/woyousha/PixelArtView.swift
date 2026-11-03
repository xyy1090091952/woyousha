import SwiftUI

/// 缓存只包含代码绘制的小图。拖动家具不会逐帧重画，也不会读取 Assets。
/// 投影与主体独立缓存；拖动时只移动图片，不重新计算几何和纹理。
@MainActor
private enum PixelArtCache {
    static var furniture: [String: CGImage] = [:]
    static var furnitureOutlines: [String: CGImage] = [:]
    static var furnitureShadows: [String: PixelArtShadow?] = [:]
    static var furnitureBounds: [String: CGRect] = [:]
    static var rooms: [String: CGImage] = [:]
    static var decorations: [String: CGImage] = [:]
    static var decorationOutlines: [String: CGImage] = [:]
    static var decorationShadows: [String: PixelArtShadow?] = [:]
    static var decorationBounds: [String: CGRect] = [:]

    static func bounds(id: String, mirrored: Bool) -> CGRect {
        let key = id + (mirrored ? "-mirrored" : "")
        if let bounds = furnitureBounds[key] { return bounds }
        let bounds = PixelArtRenderer.furnitureBounds(id:id,mirrored:mirrored)
        furnitureBounds[key] = bounds
        return bounds
    }

    static func bounds(kind: RoomDecoration.Kind, mirrored: Bool) -> CGRect {
        let key = kind.rawValue + (mirrored ? "-mirrored" : "")
        if let bounds = decorationBounds[key] { return bounds }
        let bounds = PixelArtRenderer.decorationBounds(kind:kind,mirrored:mirrored)
        decorationBounds[key] = bounds
        return bounds
    }

    static func image(id: String, isRoom: Bool, mirrored: Bool = false) -> CGImage? {
        if isRoom {
            if let cached = rooms[id] { return cached }
            let image = PixelArtRenderer.room(style: id)
            rooms[id] = image
            return image
        }
        let key = id + (mirrored ? "-mirrored" : "")
        if let cached = furniture[key] { return cached }
        let image = PixelArtRenderer.furniture(id: id, mirrored: mirrored)
        furniture[key] = image
        return image
    }

    static func furnitureOutline(id: String, mirrored: Bool) -> CGImage? {
        let key = id + (mirrored ? "-mirrored" : "")
        if let cached = furnitureOutlines[key] { return cached }
        guard let source = image(id: id, isRoom: false, mirrored: mirrored),
              let outlined = AlphaOutlineRenderer.outlined(source, radius: PixelArtRenderer.selectionOutlineRadius) else { return nil }
        furnitureOutlines[key] = outlined
        return outlined
    }

    /// 挂墙家具没有影子，缓存里存 nil，避免反复计算。
    static func furnitureShadow(id: String, mirrored: Bool) -> PixelArtShadow? {
        let key = id + (mirrored ? "-mirrored" : "")
        if let cached = furnitureShadows[key] { return cached }
        let shadow = PixelArtRenderer.furnitureShadow(id: id, mirrored: mirrored)
        furnitureShadows[key] = .some(shadow)
        return shadow
    }

    static func decorationShadow(kind: RoomDecoration.Kind, style: String, mirrored: Bool) -> PixelArtShadow? {
        let key = kind.rawValue + style + (mirrored ? "-mirror" : "")
        if let cached = decorationShadows[key] { return cached }
        let shadow = PixelArtRenderer.decorationShadow(kind: kind, style: style, mirrored: mirrored)
        decorationShadows[key] = .some(shadow)
        return shadow
    }

    static func decoration(kind: RoomDecoration.Kind, style: String, mirrored: Bool) -> CGImage? {
        let key = kind.rawValue + style + (mirrored ? "-mirror" : "")
        if let image = decorations[key] { return image }
        let image = PixelArtRenderer.decoration(kind:kind,style:style,mirrored:mirrored)
        decorations[key] = image
        return image
    }

    static func decorationOutline(kind: RoomDecoration.Kind, style: String, mirrored: Bool) -> CGImage? {
        let key = kind.rawValue + style + (mirrored ? "-mirror" : "")
        if let cached = decorationOutlines[key] { return cached }
        guard let source = decoration(kind: kind, style: style, mirrored: mirrored),
              let outlined = AlphaOutlineRenderer.outlined(source, radius: PixelArtRenderer.selectionOutlineRadius) else { return nil }
        decorationOutlines[key] = outlined
        return outlined
    }
}

/// 图标与房间主体只按家具本身排版。影子只能由独立的地面组件显示。
/// 从入口移除投影参数，避免未来新增目录时再次把长影子混进缩略图。
private struct PixelSpriteImage: View {
    let image: CGImage

    var body: some View {
        Image(decorative:image,scale:1)
            .resizable().interpolation(.none)
            .aspectRatio(CGFloat(image.width)/CGFloat(image.height),contentMode:.fit)
    }
}

struct PixelFurnitureView: View {
    let styleID: String
    var isMirrored = false
    var showsOutline = false

    var body: some View {
        let original = PixelArtCache.image(id: styleID, isRoom: false, mirrored: isMirrored)
        let image = showsOutline
            ? (PixelArtCache.furnitureOutline(id: styleID, mirrored: isMirrored) ?? original)
            : original
        if let image {
            PixelSpriteImage(image: image)
        }
    }
}

struct PixelRoomView: View {
    let styleID: String
    var body: some View {
        if let image = PixelArtCache.image(id: styleID, isRoom: true) {
            Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.none)
                .aspectRatio(CGFloat(PixelArtRenderer.roomWidth) / CGFloat(PixelArtRenderer.roomHeight), contentMode: .fit)
        }
    }
}

struct PixelDecorationView: View {
    let kind: RoomDecoration.Kind
    var roomStyle = "home1"
    var mirrored = false
    var showsOutline = false
    var body: some View {
        let original = PixelArtCache.decoration(kind: kind, style: roomStyle, mirrored: mirrored)
        let image = showsOutline
            ? (PixelArtCache.decorationOutline(kind: kind, style: roomStyle, mirrored: mirrored) ?? original)
            : original
        if let image {
            PixelSpriteImage(image: image)
        }
    }
}

struct DecorationPlacementView: View {
    let decoration: RoomDecoration
    let roomStyle: String
    var isSelected = false
    var scaleOverride: Double?

    var body: some View {
        let image = PixelArtCache.decoration(kind:decoration.kind,style:roomStyle,mirrored:decoration.isMirrored)
        let bounds = PixelArtCache.bounds(kind:decoration.kind,mirrored:decoration.isMirrored)
        let factor = RoomConfig.roomWidth / Double(PixelArtRenderer.roomWidth)
            * PixelArtRenderer.roomPixelScale / PixelArtRenderer.furniturePixelScale
            * (scaleOverride ?? decoration.scale)
        PixelDecorationView(kind:decoration.kind,roomStyle:roomStyle,mirrored:decoration.isMirrored,
                            showsOutline:isSelected)
            .frame(width:Double(image?.width ?? 1)*factor,height:Double(image?.height ?? 1)*factor)
            .contentShape(Rectangle())
            // 模型以地面接触点或墙面锚点放置，而不是按位图中心放置。
            .offset(x:bounds.midX*factor,y:bounds.midY*factor)
            .accessibilityLabel(decoration.name)
    }
}

/// 房间内的投影统一放在地面层。它不接收点击，也不参与选中白边。
struct PixelFurnitureShadowView: View {
    let styleID: String
    let mirrored: Bool
    let scale: Double

    var body: some View {
        if let shadow = PixelArtCache.furnitureShadow(id:styleID,mirrored:mirrored) {
            // 与家具主体的历史数据兜底规则一致，异常缩放不能让影子和主体分离。
            let userScale = scale.isFinite ? min(max(scale,RoomConfig.furnitureRange.lowerBound),RoomConfig.furnitureRange.upperBound) : 1
            let factor = RoomConfig.roomWidth/CGFloat(PixelArtRenderer.roomWidth)*userScale
            let sprite = PixelArtRenderer.spriteBounds(contentBounds:PixelArtCache.bounds(id:styleID,mirrored:mirrored))
            PixelShadowPlacement(shadow:shadow,factor:factor,reference:CGPoint(x:sprite.midX,y:sprite.midY))
        }
    }
}

struct PixelDecorationShadowView: View {
    let decoration: RoomDecoration
    let roomStyle: String
    var scaleOverride: Double?

    var body: some View {
        if let shadow = PixelArtCache.decorationShadow(kind:decoration.kind,style:roomStyle,mirrored:decoration.isMirrored) {
            let factor = RoomConfig.roomWidth/CGFloat(PixelArtRenderer.roomWidth)*(scaleOverride ?? decoration.scale)
            PixelShadowPlacement(shadow:shadow,factor:factor,reference:.zero)
        }
    }
}

private struct PixelShadowPlacement: View {
    let shadow: PixelArtShadow
    let factor: CGFloat
    let reference: CGPoint

    var body: some View {
        Image(decorative:shadow.image,scale:1)
            .resizable().interpolation(.none)
            .frame(width:shadow.bounds.width*factor,height:shadow.bounds.height*factor)
            .offset(x:(shadow.bounds.midX-reference.x)*factor,y:(shadow.bounds.midY-reference.y)*factor)
            .allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// 将地面投影限定在房间的地板菱形内，避免影子跑到白色背景和墙面上。
struct RoomFloorShadowMask: Shape {
    func path(in rect: CGRect) -> Path {
        let factor = rect.width/CGFloat(PixelArtRenderer.roomWidth)
        let inset = (rect.height-CGFloat(PixelArtRenderer.roomHeight)*factor)/2
        let side = IsometricRoom.sideLength
        let points: [IsoPoint] = [.init(0,0,0),.init(side,0,0),.init(side,side,0),.init(0,side,0)]
        var path = Path()
        for (index,point) in points.enumerated() {
            let p = PixelArtRenderer.roomProjection.project(point)
            let screen = CGPoint(x:rect.minX+p.x*factor,y:rect.minY+p.y*factor+inset)
            if index == 0 { path.move(to:screen) } else { path.addLine(to:screen) }
        }
        path.closeSubpath()
        return path
    }
}

extension FurnitureConfig {
    /// 图片缓存属于 UI 主线程；尺寸读取也在同一线程，避免并发修改缓存。
    @MainActor
    static func displaySize(for container: Container, scaleOverride: Double? = nil) -> CGSize {
        let style = styleID(name: container.name, icon: container.icon, savedID: container.furnitureImageName)
        let scale = scaleOverride ?? container.scale
        let userScale = scale.isFinite ? min(max(scale,RoomConfig.furnitureRange.lowerBound),RoomConfig.furnitureRange.upperBound) : 1
        let image = PixelArtCache.image(id:style,isRoom:false)
        // 统一物理比例：家具一个世界单位与房间一个世界单位等大，不按图标宽度硬拉伸。
        let factor = RoomConfig.roomWidth / CGFloat(PixelArtRenderer.roomWidth)
            * PixelArtRenderer.roomPixelScale / PixelArtRenderer.furniturePixelScale * userScale
        return CGSize(width:CGFloat(image?.width ?? 64)*factor,height:CGFloat(image?.height ?? 80)*factor)
    }

}
