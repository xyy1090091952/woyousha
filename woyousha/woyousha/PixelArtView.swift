import SwiftUI

/// 缓存只包含代码绘制的小图。拖动家具不会逐帧重画，也不会读取 Assets。
@MainActor
private enum PixelArtCache {
    static var furniture: [String: CGImage] = [:]
    static var rooms: [String: CGImage] = [:]

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
}

struct PixelFurnitureView: View {
    let styleID: String
    var isMirrored = false

    var body: some View {
        if let image = PixelArtCache.image(id: styleID, isRoom: false, mirrored: isMirrored) {
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
