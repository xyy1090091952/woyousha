import SwiftUI

/// 缓存只包含代码绘制的小图。拖动家具不会逐帧重画，也不会读取 Assets。
@MainActor
private enum PixelArtCache {
    static var furniture: [String: CGImage] = [:]
    static var furnitureOutlines: [String: CGImage] = [:]
    static var rooms: [String: CGImage] = [:]
    static var decorations: [String: CGImage] = [:]
    static var decorationOutlines: [String: CGImage] = [:]

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
            Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.none)
                .aspectRatio(CGFloat(image.width) / CGFloat(image.height), contentMode: .fit)
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
            Image(decorative:image,scale:1)
                .resizable().interpolation(.none)
                .aspectRatio(CGFloat(image.width)/CGFloat(image.height),contentMode:.fit)
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
        let bounds = PixelArtRenderer.decorationBounds(kind:decoration.kind,mirrored:decoration.isMirrored)
        let factor = RoomConfig.roomWidth / Double(PixelArtRenderer.roomWidth)
            * PixelArtRenderer.roomPixelScale / PixelArtRenderer.furniturePixelScale
            * (scaleOverride ?? decoration.scale)
        PixelDecorationView(kind:decoration.kind,roomStyle:roomStyle,mirrored:decoration.isMirrored,showsOutline:isSelected)
            .frame(width:Double(image?.width ?? 1)*factor,height:Double(image?.height ?? 1)*factor)
            .contentShape(Rectangle())
            // 模型以地面接触点或墙面锚点放置，而不是按位图中心放置。
            .offset(x:bounds.midX*factor,y:bounds.midY*factor)
            .accessibilityLabel(decoration.name)
    }
}

extension FurnitureConfig {
    static func displaySize(for container: Container, scaleOverride: Double? = nil) -> CGSize {
        let style = styleID(name: container.name, icon: container.icon, savedID: container.furnitureImageName)
        let scale = scaleOverride ?? container.scale
        let userScale = scale.isFinite ? min(max(scale, 0.5), 2) : 1
        let image = PixelArtCache.image(id:style,isRoom:false)
        // 统一物理比例：家具一个世界单位与房间一个世界单位等大，不按图标宽度硬拉伸。
        let factor = RoomConfig.roomWidth / CGFloat(PixelArtRenderer.roomWidth)
            * PixelArtRenderer.roomPixelScale / PixelArtRenderer.furniturePixelScale * userScale
        return CGSize(width:CGFloat(image?.width ?? 64)*factor,height:CGFloat(image?.height ?? 80)*factor)
    }

}
