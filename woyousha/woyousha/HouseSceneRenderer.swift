import Foundation
import CoreGraphics

/// 建筑、庭院、网格和物品共用投影。扩建改变取景范围，不改变物品的格子坐标。
nonisolated struct HouseSceneMetrics: Sendable {
    let minX: Int
    let minY: Int
    let maxX: Int
    let maxY: Int
    let width: Int
    let height: Int
    let projection: IsoProjection
    var imageFactor: Double { HouseGridConfig.canvasSize/Double(width) }
    var worldFactor: Double { imageFactor*projection.scale }
    var topInset: Double { (HouseGridConfig.canvasSize-Double(height)*imageFactor)/2 }
    var spriteFactor: Double { worldFactor/PixelArtRenderer.furniturePixelScale }

    init(layout: HouseLayout, occupants: [HouseOccupant] = [], showsPlot: Bool = false,
         ceilingHeight: Double = HouseGridConfig.wallHeight) {
        let cells=layout.floorCells.union(occupants.reduce(into:Set<HouseCell>()){$0.formUnion($1.cells)})
        let margin=HouseGridConfig.yardMargin
        minX=showsPlot ? 0:max(0,(cells.map(\.x).min() ?? 4)-margin)
        minY=showsPlot ? 0:max(0,(cells.map(\.y).min() ?? 4)-margin)
        maxX=showsPlot ? HouseGridConfig.plotSize:min(HouseGridConfig.plotSize,(cells.map(\.x).max() ?? 11)+1+margin)
        maxY=showsPlot ? HouseGridConfig.plotSize:min(HouseGridConfig.plotSize,(cells.map(\.y).max() ?? 11)+1+margin)
        let tile=HouseGridConfig.tile,s=PixelArtRenderer.roomPixelScale
        let ceiling=max(HouseGridConfig.wallHeight,ceilingHeight)
        width=Int(ceil(Double(maxX-minX+maxY-minY)*tile*s+40))
        height=Int(ceil(Double(maxX-minX+maxY-minY)*tile*s*0.5+ceiling*s+48))
        projection=IsoProjection(scale:s,origin:.init(
            x:20+Double(maxY-minX)*tile*s,
            y:24+ceiling*s-Double(minX+minY)*tile*s*0.5))
    }

    func screen(_ point: IsoPoint) -> CGPoint {
        let p=projection.project(point)
        return .init(x:p.x*imageFactor,y:p.y*imageFactor+topInset)
    }
    func center(of cell: HouseCell) -> CGPoint {
        screen(.init((Double(cell.x)+0.5)*HouseGridConfig.tile,(Double(cell.y)+0.5)*HouseGridConfig.tile,0))
    }
    func worldPoint(_ screen:CGPoint,z:Double = 0) -> IsoPoint {
        let dx=(screen.x/imageFactor-projection.origin.x)/projection.scale
        let sum=2*((((screen.y-topInset)/imageFactor-projection.origin.y)/projection.scale)+z)
        return .init((sum+dx)/2,(sum-dx)/2,z)
    }
    func delta(_ screen: CGSize) -> HouseCell {
        guard screen.width.isFinite,screen.height.isFinite else { return .init(x:0,y:0) }
        let x=screen.width/worldFactor,y=screen.height/worldFactor
        let limit=Double(HouseGridConfig.plotSize*2)
        return .init(x:Int(min(limit,max(-limit,(y+x/2)/HouseGridConfig.tile)).rounded()),
                     y:Int(min(limit,max(-limit,(y-x/2)/HouseGridConfig.tile)).rounded()))
    }
}

/// 主线程只准备不可变几何，逐像素绘图交给后台，不跨线程访问 SwiftData 或家具缓存。
nonisolated struct HouseRenderJob: Sendable {
    let scene: IsoMesh
    let casters: IsoMesh
    let metrics: HouseSceneMetrics
    var selectedOwners: Set<Int>
    let shadowReceivers: Set<Int>
    var geometry: [HouseGeometryBatch] = []
    var baseKey: String = ""
    var preview: HousePlacementPreview? = nil

    func render(cancellable: Bool = false) -> CGImage? {
        if cancellable && Task.isCancelled { return nil }
        let shadow=IsoShadowRenderer.render(casters,scale:metrics.projection.scale,groundPlane:0,
                                            cancellable:cancellable)
        var visibleScene=scene
        if let preview {
            for cell in preview.footprint.cells(at:preview.cell) {
                let index=visibleScene.faces.count,tile=HouseGridConfig.tile
                visibleScene.top(Double(cell.x)*tile+0.3,Double(cell.y)*tile+0.3,0.22,tile-0.6,tile-0.6,
                                 preview.isValid ? 0xBBD89A:0xE6AC9E,material:.smooth)
                visibleScene.faces[index].renderOwner=1
            }
        }
        return IsoRasterizer.render(visibleScene,width:metrics.width,height:metrics.height,projection:metrics.projection,
                                    selectedOwners:selectedOwners,shadow:shadow,shadowReceivers:shadowReceivers,
                                    cancellable:cancellable)
    }
}

/// GPU 保留本地模型缓冲，只传家具的新位置；房间和物品数据仍由原仓库管理。
nonisolated struct HouseGeometryBatch: Sendable {
    let key: String
    let mesh: IsoMesh
    var origin: IsoPoint = .init(0,0,0)
    var owner: Int = 0
}

/// 原生像素庭院：草地、步道、围栏与树木。几何/颗粒绑定世界坐标，扩建时不会随机变换。
nonisolated enum HouseSceneRenderer {
    static func model(layout: HouseLayout, metrics: HouseSceneMetrics, style: String,
                      occupants: [HouseOccupant] = []) -> IsoMesh {
        var mesh=IsoMesh()
        let tile=HouseGridConfig.tile
        let green=style == "home2"
        HouseYardScene.appendGround(to:&mesh,layout:layout,metrics:metrics,style:style)
        // 围栏只放在远侧边缘，不挡住屋内拖动和房间入口。
        for x in stride(from:metrics.minX,to:metrics.maxX,by:2) {
            fence(&mesh,x:Double(x)*tile,y:Double(metrics.minY)*tile,alongX:true)
        }
        for y in stride(from:metrics.minY,to:metrics.maxY,by:2) {
            fence(&mesh,x:Double(metrics.minX)*tile,y:Double(y)*tile,alongX:false)
        }

        let defaultWall: UInt32=green ? 0xBCCCAF:OyohaPalette.wall
        let trim: UInt32=green ? 0x62816A:OyohaPalette.trim
        for room in layout.rooms {
            let wall=room.wallFinish?.color ?? defaultWall
            let defaultFloor: UInt32
            switch room.kind {
            case .bathroom: defaultFloor=0xC4DDD1
            case .kitchen: defaultFloor=0xE8DDC1
            case .bedroom: defaultFloor=green ? 0xC9B181:0xDEAC6C
            default: defaultFloor=green ? 0xC5A475:OyohaPalette.floor
            }
            let roomFloor=room.floorFinish?.color ?? defaultFloor
            let floorMaterial:IsoMaterial=room.floorFinish?.material ?? (room.kind == .bathroom || room.kind == .kitchen ? .smooth:.wood)
            mesh.box(Double(room.x)*tile,Double(room.y)*tile,-3,Double(room.width)*tile,Double(room.depth)*tile,3,trim,material:.wood)
            for cell in room.cells {
                let tint=IsoColor.shade(roomFloor,0.97+IsoPixelStyle.hash(cell.x,cell.y,19)*0.06)
                mesh.top(Double(cell.x)*tile+0.18,Double(cell.y)*tile+0.18,0.15,tile-0.36,tile-0.36,tint,
                         material:floorMaterial)
            }
            wallEdge(&mesh,room:room,vertical:true,boundary:room.x,start:room.y,length:room.depth,
                     height:HouseGridConfig.wallHeight,layout:layout,color:wall,trim:trim)
            wallEdge(&mesh,room:room,vertical:false,boundary:room.y,start:room.x,length:room.width,
                     height:HouseGridConfig.wallHeight,layout:layout,color:wall,trim:trim)
            wallEdge(&mesh,room:room,vertical:true,boundary:room.x+room.width,start:room.y,length:room.depth,
                     height:5,layout:layout,color:wall,trim:trim)
            wallEdge(&mesh,room:room,vertical:false,boundary:room.y+room.depth,start:room.x,length:room.width,
                     height:5,layout:layout,color:wall,trim:trim)
        }
        return mesh
    }

    private static func wallEdge(_ mesh: inout IsoMesh,room:HouseRoom,vertical:Bool,boundary:Int,start:Int,length:Int,
                                 height:Double,layout:HouseLayout,color:UInt32,trim:UInt32) {
        let tile=HouseGridConfig.tile
        let doors=layout.doors.filter {$0.vertical == vertical && $0.boundary == boundary && $0.roomIDs.contains(room.id)}
        for cell in start..<(start+length) {
            let neighbor=layout.rooms.first { other in
                guard other.id != room.id else { return false }
                if vertical { return (other.x == boundary || other.x+other.width == boundary) && cell >= other.y && cell < other.y+other.depth }
                return (other.y == boundary || other.y+other.depth == boundary) && cell >= other.x && cell < other.x+other.width
            }
            // 共用墙只画一次，采用靠近观察者的房间颜色，避免不同装修在同一面抢图层。
            if let neighbor,
               vertical ? (room.x+room.width == boundary && neighbor.x == boundary)
                        : (room.y+room.depth == boundary && neighbor.y == boundary) { continue }
            let cutHeight=neighbor == nil ? height:min(height,24)
            if doors.contains(where:{cell >= $0.start && cell < $0.start+2}) { continue }
            let x=vertical ? Double(boundary)*tile-0.8:Double(cell)*tile
            let y=vertical ? Double(cell)*tile:Double(boundary)*tile-0.8
            mesh.box(x,y,0,vertical ? 1.6:tile,vertical ? tile:1.6,cutHeight,color,material:.plaster)
            mesh.box(x,y,cutHeight,vertical ? 1.6:tile,vertical ? tile:1.6,0.6,trim,material:.wood)
        }
    }

    private static func fence(_ mesh: inout IsoMesh,x:Double,y:Double,alongX:Bool) {
        mesh.box(x,y,0,2,2,12,0xDCC29A,material:.wood)
        for z in [4.0,9] {
            mesh.box(x,y,z,alongX ? 32:1.5,alongX ? 1.5:32,1.5,0xE8D4B1,material:.wood)
        }
    }

    /// 墙、家具、装饰在同一个深度缓冲中绘制，隔墙可以挡住后面的椅子，
    /// 前面的椅子也能挡住墙；不再依赖整张图片的 zIndex。
    @MainActor static func prepare(layout: HouseLayout, metrics: HouseSceneMetrics, style: String,
                       occupants: [HouseOccupant] = [],items:[HouseSceneItem] = [],
                       selectedIDs:Set<String> = [],preview:HousePlacementPreview? = nil) -> HouseRenderJob {
        let architectureKey=HouseGeometryCache.key(layout:layout,metrics:metrics,style:style,occupants:occupants)
        let objects=items.map(\.renderSignature).joined(separator:"|")
        let baseKey=architectureKey+objects+"\(metrics.width),\(metrics.height),\(metrics.projection.origin)"
        let selection=Set(items.enumerated().compactMap { selectedIDs.contains($0.element.id) ? $0.offset+2:nil })
        if var cached=HousePreparedSceneCache.job(for:baseKey) {
            cached.selectedOwners=selection
            cached.preview=preview
            return cached
        }
        let architecture=HouseGeometryCache.mesh(for:architectureKey) {
            var mesh=model(layout:layout,metrics:metrics,style:style,occupants:occupants)
            for i in mesh.faces.indices {
                let points=mesh.faces[i].points
                if let z=points.first?.z,z <= 0.3,points.allSatisfy({abs($0.z-z)<0.001}) {
                    mesh.faces[i].renderOwner=1
                }
            }
            return mesh
        }
        var scene=architecture
        var geometry=[HouseGeometryBatch(key:architectureKey,mesh:architecture)]
        var receivers=Set([1])
        for (index,item) in items.enumerated() {
            let owner=index+2
            scene.merge(item.worldMesh(style:style,owner:owner))
            if let batch=item.geometryBatch(style:style,owner:owner) { geometry.append(batch) }
            if item.layer == .covering { receivers.insert(owner) }
        }
        let casters=IsoMesh(faces:scene.faces.filter {
            !receivers.contains($0.renderOwner) && $0.points.contains(where:{$0.z > 0.3})
        })
        let job=HouseRenderJob(scene:scene,casters:casters,metrics:metrics,
                              selectedOwners:selection,shadowReceivers:receivers,geometry:geometry,
                              baseKey:baseKey,preview:preview)
        HousePreparedSceneCache.insert(job)
        return job
    }

    /// 同步入口供静态预览和核验使用；正式页面通过不可变任务在后台绘图。
    @MainActor static func render(layout: HouseLayout, metrics: HouseSceneMetrics, style: String,
                       occupants: [HouseOccupant] = [],items:[HouseSceneItem] = [],
                       selectedIDs:Set<String> = [],preview:HousePlacementPreview? = nil) -> CGImage? {
        prepare(layout:layout,metrics:metrics,style:style,occupants:occupants,
                items:items,selectedIDs:selectedIDs,preview:preview).render()
    }
}

@MainActor private enum HousePreparedSceneCache {
    private static var entries:[HouseRenderJob]=[]
    static func job(for key:String) -> HouseRenderJob? { entries.first {$0.baseKey == key} }
    static func insert(_ job:HouseRenderJob) {
        entries.append(job)
        if entries.count>3 { entries.removeFirst() }
    }
}

/// 建筑只有房型、装修、取景或树木遮挡变化才重建；换选中家具复用同一个模型。
@MainActor private enum HouseGeometryCache {
    private static var entries: [(String,IsoMesh)] = []
    static func key(layout:HouseLayout,metrics:HouseSceneMetrics,style:String,occupants:[HouseOccupant]) -> String {
        let rooms=layout.rooms.map {
            "\($0.id):\($0.kind):\($0.x):\($0.y):\($0.width):\($0.depth):\($0.floorFinish?.rawValue ?? ""):\($0.wallFinish?.rawValue ?? "")"
        }.joined(separator:"|")
        return "yard:\(HouseYardScene.revision):\(style):\(rooms):\(metrics.minX),\(metrics.minY),\(metrics.maxX),\(metrics.maxY)"
    }
    static func mesh(for key:String,create:() -> IsoMesh) -> IsoMesh {
        if let entry=entries.first(where:{$0.0 == key}) { return entry.1 }
        let mesh=create()
        entries.append((key,mesh))
        if entries.count>3 { entries.removeFirst() }
        return mesh
    }
}
