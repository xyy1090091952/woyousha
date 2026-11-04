import Foundation
import CoreGraphics

/// 固定物理尺寸来自模型本身，向上取整为格子占地；显示和碰撞从同一个结果派生。
nonisolated struct HouseModelMetrics {
    let footprint: HouseFootprint
    let minimum: IsoPoint
    let size: IsoPoint
    let sprite: CGRect

    init(mesh: IsoMesh) {
        let points=mesh.faces.flatMap(\.points)
        let x0=points.map(\.x).min() ?? 0,y0=points.map(\.y).min() ?? 0,z0=points.map(\.z).min() ?? 0
        let x1=points.map(\.x).max() ?? 16,y1=points.map(\.y).max() ?? 16,z1=points.map(\.z).max() ?? 16
        minimum = .init(x0,y0,z0)
        size = .init(x1-x0,y1-y0,z1-z0)
        footprint = .init(width:max(1,Int(ceil((x1-x0)/HouseGridConfig.tile))),
                          depth:max(1,Int(ceil((y1-y0)/HouseGridConfig.tile))))
        let projection=IsoProjection(scale:PixelArtRenderer.furniturePixelScale,origin:.zero)
        let p=points.map(projection.project)
        let box=CGRect(x:p.map(\.x).min() ?? 0,y:p.map(\.y).min() ?? 0,
                       width:(p.map(\.x).max() ?? 1)-(p.map(\.x).min() ?? 0),
                       height:(p.map(\.y).max() ?? 1)-(p.map(\.y).min() ?? 0))
        sprite=PixelArtRenderer.spriteBounds(contentBounds:box)
    }

    func origin(at cell: HouseCell, wall: Bool = false) -> IsoPoint {
        .init(Double(cell.x)*HouseGridConfig.tile+(Double(footprint.width)*HouseGridConfig.tile-size.x)/2-minimum.x,
              Double(cell.y)*HouseGridConfig.tile+(Double(footprint.depth)*HouseGridConfig.tile-size.y)/2-minimum.y,
              (wall ? 18 : 0.2)-minimum.z)
    }
}

@MainActor
enum HouseFurnitureCatalog {
    private static var cache: [String:HouseModelMetrics] = [:]
    private static var meshes: [String:IsoMesh] = [:]
    private static var shadows: [String:PixelArtShadow?] = [:]
    static func shadow(id:String,mirrored:Bool) -> PixelArtShadow? {
        let key=id+(mirrored ? "-m":"")
        if let saved=shadows[key] { return saved }
        let value=PixelArtRenderer.furnitureShadow(id:id,mirrored:mirrored)
        shadows[key] = .some(value)
        return value
    }
    static func shadow(kind:RoomDecoration.Kind,style:String,mirrored:Bool) -> PixelArtShadow? {
        let key="d-"+kind.rawValue+style+(mirrored ? "-m":"")
        if let saved=shadows[key] { return saved }
        let value=PixelArtRenderer.decorationShadow(kind:kind,style:style,mirrored:mirrored)
        shadows[key] = .some(value)
        return value
    }
    static func furniture(_ id: String, mirrored: Bool = false) -> HouseModelMetrics {
        let key=id+(mirrored ? "-m":"")
        if let value=cache[key] { return value }
        let result=HouseModelMetrics(mesh:furnitureMesh(id,mirrored:mirrored))
        cache[key]=result
        return result
    }
    static func decoration(_ kind: RoomDecoration.Kind, mirrored: Bool = false) -> HouseModelMetrics {
        let key="decoration-"+kind.rawValue+(mirrored ? "-m":"")
        if let value=cache[key] { return value }
        let result=HouseModelMetrics(mesh:decorationMesh(kind,style:"home1",mirrored:mirrored))
        cache[key]=result
        return result
    }
    /// 统一场景直接使用同一套几何，缓存避免拖动每一格都重新生成曲面模型。
    static func furnitureMesh(_ id:String,mirrored:Bool=false) -> IsoMesh {
        let key="f-"+id+(mirrored ? "-m":"")
        if let mesh=meshes[key] { return mesh }
        let original=IsometricFurniture.model(id)
        let mesh=mirrored ? original.exchangingAxes():original
        meshes[key]=mesh
        return mesh
    }
    static func decorationMesh(_ kind:RoomDecoration.Kind,style:String,mirrored:Bool=false) -> IsoMesh {
        let key="d-"+kind.rawValue+style+(mirrored ? "-m":"")
        if let mesh=meshes[key] { return mesh }
        let original=IsometricDecoration.model(kind,style:style)
        let mesh=mirrored ? original.exchangingAxes():original
        meshes[key]=mesh
        return mesh
    }
    static func layer(for id: String) -> HousePlacementLayer {
        PixelArtRenderer.wallMountedFurniture.contains(id) ? .wall:.floor
    }
    static func layer(for kind: RoomDecoration.Kind) -> HousePlacementLayer {
        kind.isFloorCovering ? .covering:(kind.isWallMounted ? .wall:.floor)
    }
    static func outdoors(_ id: String) -> Bool { FurnitureConfig.get(byImageName:id)?.category == .outdoor }

    static func occupants(containers: [Container], decorations: [RoomDecoration]) -> [HouseOccupant] {
        var result=containers.filter { $0.isPlaced && $0.usesGridPlacement }.map { item in
            let id=FurnitureConfig.styleID(name:item.name,icon:item.icon,savedID:item.furnitureImageName)
            return HouseOccupant(id:item.id.uuidString,cell:.init(x:item.gridX,y:item.gridY),
                                 footprint:furniture(id,mirrored:item.isMirrored).footprint,layer:layer(for:id))
        }
        for item in decorations where item.isPlaced {
            guard let x=item.gridX,let y=item.gridY else { continue }
            result.append(HouseOccupant(id:item.id,cell:.init(x:x,y:y),
                footprint:decoration(item.kind,mirrored:item.isMirrored).footprint,layer:layer(for:item.kind)))
        }
        return result
    }
}
