import Foundation

/// 宅地内部仅保留庭院和步道；密林、河道由独立外围画布负责。
nonisolated enum HouseYardScene {
    static let revision = "outer-landscape-v3"
    static func appendGround(to mesh:inout IsoMesh,layout:HouseLayout,metrics:HouseSceneMetrics,style:String) {
        let tile=HouseGridConfig.tile,lawn:UInt32=style == "home2" ? 0xA5BA75:0xB7C784
        mesh.box(Double(metrics.minX)*tile,Double(metrics.minY)*tile,-6,
                 Double(metrics.maxX-metrics.minX)*tile,Double(metrics.maxY-metrics.minY)*tile,5.2,0x9B8453,material:.wood)
        let entry=layout.rooms[0],pathX=entry.x+entry.width/2
        let floor=layout.floorCells
        for y in metrics.minY..<metrics.maxY { for x in metrics.minX..<metrics.maxX {
            guard !floor.contains(.init(x:x,y:y)) else { continue }
            mesh.top(Double(x)*tile,Double(y)*tile,-0.8,tile,tile,
                IsoColor.shade(lawn,0.98+IsoPixelStyle.hash(x,y,51)*0.04),material:.plaster)
            if x == pathX && y >= entry.y+entry.depth {
                mesh.roundedBox(Double(x)*tile+1,Double(y)*tile+1,-0.5,tile-2,tile-2,1,radius:2,color:0xE9D9B3)
            } else if IsoPixelStyle.hash(x,y,7)>0.96 {
                mesh.top(Double(x)*tile+6,Double(y)*tile+5,-0.7,3,2,0xEDCE89)
            }
        }}
    }

    /// 少量背景树造型只生成一次，逐像素绘制由后台处理。
    static func treeMesh(seed:Int) -> IsoMesh {
        var mesh=IsoMesh()
        let scale=0.85+Double(seed)*0.08
        mesh.cylinder(0,0,0,radius:1.8*scale,height:25*scale,color:0xA17B4C,sides:6)
        for (x,y,z,r,color) in [(-4.0,0.0,26.0,10.0,UInt32(0x729B58)),
                                (4.0,3.0,29.0,10.0,UInt32(0x83A963)),
                                (0.0,-1.0,37.0,11.0,UInt32(0xA0BD72))] {
            IsoCatalogParts.ellipsoid(&mesh,center:.init(x*scale,y*scale,z*scale),
                radii:.init(r*scale,r*scale,10*scale),color:color)
        }
        return mesh
    }
}
