import Foundation

nonisolated struct HousePlacementPreview {
    let cell: HouseCell
    let footprint: HouseFootprint
    let isValid: Bool
    var signature: String { "\(cell.x),\(cell.y),\(footprint.width),\(footprint.depth),\(isValid)" }
}

/// 画面用的只读快照。拖动候选格可改变快照，保存仍由原来的仓库统一校验。
nonisolated struct HouseSceneItem: Hashable {
    enum Source: Hashable {
        case furniture(String)
        case decoration(RoomDecoration.Kind)
    }
    let id: String
    let source: Source
    var cell: HouseCell
    var mirrored: Bool = false

    var layer: HousePlacementLayer {
        switch source {
        case .furniture(let style): return PixelArtRenderer.wallMountedFurniture.contains(style) ? .wall:.floor
        case .decoration(let kind): return kind.isFloorCovering ? .covering:(kind.isWallMounted ? .wall:.floor)
        }
    }
    @MainActor var metrics: HouseModelMetrics {
        switch source {
        case .furniture(let style): return HouseFurnitureCatalog.furniture(style,mirrored:mirrored)
        case .decoration(let kind): return HouseFurnitureCatalog.decoration(kind,mirrored:mirrored)
        }
    }
    @MainActor var visualHeight: Double { (layer == .wall ? 18:0.2)+metrics.size.z }
    @MainActor func worldMesh(style:String,owner:Int) -> IsoMesh {
        // 异常历史坐标不参与栅格化，原记录仍保留，避免巨大坐标让像素取整溢出。
        let limit=HouseGridConfig.plotSize*3
        guard (-limit...limit).contains(cell.x),(-limit...limit).contains(cell.y) else { return IsoMesh() }
        let raw:IsoMesh
        switch source {
        case .furniture(let id): raw=HouseFurnitureCatalog.furnitureMesh(id,mirrored:mirrored)
        case .decoration(let kind): raw=HouseFurnitureCatalog.decorationMesh(kind,style:style,mirrored:mirrored)
        }
        let origin=metrics.origin(at:cell,wall:layer == .wall)
        return IsoMesh(faces:raw.faces.map { original in
            var face=original
            face.points=face.points.map { $0.offset(origin) }
            face.renderOwner=owner
            return face
        })
    }

    @MainActor func geometryBatch(style:String,owner:Int) -> HouseGeometryBatch? {
        let limit=HouseGridConfig.plotSize*3
        guard (-limit...limit).contains(cell.x),(-limit...limit).contains(cell.y) else { return nil }
        let raw:IsoMesh
        let key:String
        switch source {
        case .furniture(let id):
            key="furniture:\(id):\(mirrored)"
            raw=HouseFurnitureCatalog.furnitureMesh(id,mirrored:mirrored)
        case .decoration(let kind):
            key="decoration:\(kind):\(style):\(mirrored)"
            raw=HouseFurnitureCatalog.decorationMesh(kind,style:style,mirrored:mirrored)
        }
        return .init(key:key,mesh:raw,origin:metrics.origin(at:cell,wall:layer == .wall),owner:owner)
    }
}
