import Foundation
import CoreGraphics

/// 建筑、庭院、网格和物品共用投影。扩建改变取景范围，不改变物品的格子坐标。
nonisolated struct HouseSceneMetrics {
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

    init(layout: HouseLayout, occupants: [HouseOccupant] = [], showsPlot: Bool = false) {
        let cells=layout.floorCells.union(occupants.reduce(into:Set<HouseCell>()){$0.formUnion($1.cells)})
        let margin=HouseGridConfig.yardMargin
        minX=showsPlot ? 0:max(0,(cells.map(\.x).min() ?? 4)-margin)
        minY=showsPlot ? 0:max(0,(cells.map(\.y).min() ?? 4)-margin)
        maxX=showsPlot ? HouseGridConfig.plotSize:min(HouseGridConfig.plotSize,(cells.map(\.x).max() ?? 11)+1+margin)
        maxY=showsPlot ? HouseGridConfig.plotSize:min(HouseGridConfig.plotSize,(cells.map(\.y).max() ?? 11)+1+margin)
        let tile=HouseGridConfig.tile,s=PixelArtRenderer.roomPixelScale
        width=Int(ceil(Double(maxX-minX+maxY-minY)*tile*s+40))
        height=Int(ceil(Double(maxX-minX+maxY-minY)*tile*s*0.5+HouseGridConfig.wallHeight*s+48))
        projection=IsoProjection(scale:s,origin:.init(
            x:20+Double(maxY-minX)*tile*s,
            y:24+HouseGridConfig.wallHeight*s-Double(minX+minY)*tile*s*0.5))
    }

    func screen(_ point: IsoPoint) -> CGPoint {
        let p=projection.project(point)
        return .init(x:p.x*imageFactor,y:p.y*imageFactor+topInset)
    }
    func center(of cell: HouseCell) -> CGPoint {
        screen(.init((Double(cell.x)+0.5)*HouseGridConfig.tile,(Double(cell.y)+0.5)*HouseGridConfig.tile,0))
    }
    func delta(_ screen: CGSize) -> HouseCell {
        guard screen.width.isFinite,screen.height.isFinite else { return .init(x:0,y:0) }
        let x=screen.width/worldFactor,y=screen.height/worldFactor
        let limit=Double(HouseGridConfig.plotSize*2)
        return .init(x:Int(min(limit,max(-limit,(y+x/2)/HouseGridConfig.tile)).rounded()),
                     y:Int(min(limit,max(-limit,(y-x/2)/HouseGridConfig.tile)).rounded()))
    }
}

/// 原生像素庭院：草地、步道、围栏与树木。几何/颗粒绑定世界坐标，扩建时不会随机变换。
nonisolated enum HouseSceneRenderer {
    static func model(layout: HouseLayout, metrics: HouseSceneMetrics, style: String,
                      occupants: [HouseOccupant] = []) -> IsoMesh {
        var mesh=IsoMesh()
        let tile=HouseGridConfig.tile
        let floor=layout.floorCells, occupied=occupants.reduce(into:Set<HouseCell>()){$0.formUnion($1.cells)}
        let green=style == "home2"
        let lawn: UInt32=green ? 0xA5BA75:0xB7C784
        let ground: UInt32=0x9B8453
        mesh.box(Double(metrics.minX)*tile,Double(metrics.minY)*tile,-6,
                 Double(metrics.maxX-metrics.minX)*tile,Double(metrics.maxY-metrics.minY)*tile,5,ground,material:.wood)
        // 庭院的砖石步道通到客厅前侧，房间覆盖的部分不会再画草地或步道。
        let entrance=layout.rooms[0]
        let pathX=entrance.x+entrance.width/2
        for y in metrics.minY..<metrics.maxY {
            for x in metrics.minX..<metrics.maxX {
                let cell=HouseCell(x:x,y:y)
                guard !floor.contains(cell) else { continue }
                // 草地是大平面，用相近色和稀疏纹理；树冠才使用较丰富的叶片材质。
                let tint=IsoColor.shade(lawn,0.98+IsoPixelStyle.hash(x,y,51)*0.04)
                mesh.top(Double(x)*tile,Double(y)*tile,-0.8,tile,tile,tint,material:.plaster)
                if abs(x-pathX) <= 0 && y >= entrance.y+entrance.depth {
                    mesh.roundedBox(Double(x)*tile+1,Double(y)*tile+1,-0.5,tile-2,tile-2,1,
                                    radius:2,color:0xE9D9B3)
                } else if !occupied.contains(cell) && IsoPixelStyle.hash(x,y,7)>0.965 {
                    mesh.top(Double(x)*tile+6,Double(y)*tile+5,-0.7,3,2,0xEDCE89)
                }
            }
        }
        let treeSpots=[HouseCell(x:1,y:5),.init(x:3,y:1),.init(x:18,y:2),.init(x:20,y:16),.init(x:5,y:20)]
        for cell in treeSpots where cell.x >= metrics.minX && cell.x < metrics.maxX && cell.y >= metrics.minY && cell.y < metrics.maxY {
            let area=HouseFootprint(width:2,depth:2).cells(at:cell)
            guard area.isDisjoint(with:floor),area.isDisjoint(with:occupied) else { continue }
            tree(&mesh,x:(Double(cell.x)+0.8)*tile,y:(Double(cell.y)+0.8)*tile)
        }
        // 围栏只放在远侧边缘，不挡住屋内拖动和房间入口。
        for x in stride(from:metrics.minX,to:metrics.maxX,by:2) {
            fence(&mesh,x:Double(x)*tile,y:Double(metrics.minY)*tile,alongX:true)
        }
        for y in stride(from:metrics.minY,to:metrics.maxY,by:2) {
            fence(&mesh,x:Double(metrics.minX)*tile,y:Double(y)*tile,alongX:false)
        }

        let wall: UInt32=green ? 0xBCCCAF:OyohaPalette.wall
        let trim: UInt32=green ? 0x62816A:OyohaPalette.trim
        for room in layout.rooms {
            let roomFloor: UInt32
            switch room.kind {
            case .bathroom: roomFloor=0xC4DDD1
            case .kitchen: roomFloor=0xE8DDC1
            case .bedroom: roomFloor=green ? 0xC9B181:0xDEAC6C
            default: roomFloor=green ? 0xC5A475:OyohaPalette.floor
            }
            mesh.box(Double(room.x)*tile,Double(room.y)*tile,-3,Double(room.width)*tile,Double(room.depth)*tile,3,trim,material:.wood)
            for cell in room.cells {
                let tint=IsoColor.shade(roomFloor,0.97+IsoPixelStyle.hash(cell.x,cell.y,19)*0.06)
                mesh.top(Double(cell.x)*tile+0.18,Double(cell.y)*tile+0.18,0.15,tile-0.36,tile-0.36,tint,
                         material:room.kind == .bathroom || room.kind == .kitchen ? .smooth:.wood)
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
        let shared=layout.rooms.contains { other in
            guard other.id != room.id else { return false }
            if vertical { return (other.x == boundary || other.x+other.width == boundary) && max(start,other.y)<min(start+length,other.y+other.depth) }
            return (other.y == boundary || other.y+other.depth == boundary) && max(start,other.x)<min(start+length,other.x+other.width)
        }
        let cutHeight=shared ? min(height,24):height
        for cell in start..<(start+length) {
            if doors.contains(where:{cell >= $0.start && cell < $0.start+2}) { continue }
            let x=vertical ? Double(boundary)*tile-0.8:Double(cell)*tile
            let y=vertical ? Double(cell)*tile:Double(boundary)*tile-0.8
            mesh.box(x,y,0,vertical ? 1.6:tile,vertical ? tile:1.6,cutHeight,color,material:.plaster)
            mesh.box(x,y,cutHeight,vertical ? 1.6:tile,vertical ? tile:1.6,0.6,trim,material:.wood)
        }
    }

    private static func tree(_ mesh: inout IsoMesh,x:Double,y:Double) {
        mesh.cylinder(x,y,0,radius:2,height:22,color:0xAC7C4D,sides:6)
        for (dx,dy,z,r) in [(-5.0,0.0,23.0,9.0),(5,3,25,10),(0,-2,33,11)] {
            IsoCatalogParts.ellipsoid(&mesh,center:.init(x+dx,y+dy,z),radii:.init(r,r,9),color:z>30 ? 0x91B465:0x71974E)
        }
    }
    private static func fence(_ mesh: inout IsoMesh,x:Double,y:Double,alongX:Bool) {
        mesh.box(x,y,0,2,2,12,0xDCC29A,material:.wood)
        for z in [4.0,9] {
            mesh.box(x,y,z,alongX ? 32:1.5,alongX ? 1.5:32,1.5,0xE8D4B1,material:.wood)
        }
    }

    static func render(layout: HouseLayout, metrics: HouseSceneMetrics, style: String,
                       occupants: [HouseOccupant] = []) -> CGImage? {
        IsoRasterizer.render(model(layout:layout,metrics:metrics,style:style,occupants:occupants),
                             width:metrics.width,height:metrics.height,projection:metrics.projection)
    }
}
