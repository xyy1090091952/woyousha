import Foundation

/// 房间底板只绘制建筑本身。绿植、地毯、挂画等由装饰物层独立显示与移动。
nonisolated enum IsometricRoom {
    static let sideLength = 128.0
    static let wallHeight = 70.0

    static func model(style: String) -> IsoMesh {
        let green = style == "home2"
        let wall: UInt32 = green ? 0x4F9C8A : 0xE5BE87
        let trim: UInt32 = green ? 0x285D57 : 0x95603D
        let wood: UInt32 = green ? 0xAB8150 : 0xC58B4F
        var m = IsoMesh()
        m.box(-4,-4,-7,136,136,7,trim)
        m.box(-4,-4,0,4,132,wallHeight,wall)
        m.box(-4,-4,0,132,4,wallHeight,wall)
        m.box(-4,-4,wallHeight,4,132,1.2,IsoColor.shade(wall,1.1))
        m.box(-4,-4,wallHeight,132,4,1.2,IsoColor.shade(wall,1.1))
        for row in 0..<16 {
            let y = Double(row)*8
            let shift = (row%2)*16
            for col in -1..<5 {
                let start = max(0,Double(col*32+shift)), end = min(128,Double((col+1)*32+shift))
                guard end > start else { continue }
                let tint = IsoColor.shade(wood,0.95+Double((row*7+col+9)%5)*0.026)
                m.top(start,y,0.06,end-start,7.8,tint)
                m.top(start+0.4,y+7.2,0.10,max(0.1,end-start-0.8),0.5,IsoColor.shade(wood,0.77))
                for grain in 0..<2 {
                    let x = start+2+Double(grain)*6
                    if x+7 < end { m.top(x,y+2+Double(grain)*2,0.13,7,0.28,IsoColor.shade(tint,0.88)) }
                }
            }
        }
        for t in stride(from:8.0,to:128,by:8) {
            m.side(0.06,t,5,0.6,64,IsoColor.shade(wall,0.69))
            m.front(t,0.06,5,0.6,64,IsoColor.shade(wall,0.90))
        }
        m.box(0,0,0,1.2,128,5,trim)
        m.box(0,0,0,128,1.2,5,trim)
        return m
    }

    /// 只用于生成示例预览，不写入用户的家具数据库。
    static func furnishedExample(style: String) -> IsoMesh {
        var m = model(style:style)
        for (id,kind,anchor) in DecorationCatalog.defaultAnchors {
            var decoration=IsometricDecoration.model(kind,style:style)
            if id=="initial-window-plant" || id=="initial-shelf-plant" {
                decoration.faces=decoration.faces.map { face in
                    IsoFace(points:face.points.map { .init($0.x*0.6,$0.y*0.6,$0.z*0.6) },color:face.color,outline:face.outline)
                }
            }
            m.merge(decoration,at:anchor)
        }
        m.merge(IsometricFurniture.model("bingxiang"),at:.init(4,5,0.3))
        m.merge(IsometricFurniture.model("bijia"),at:.init(36,3,0.3))
        m.merge(IsometricFurniture.model("shafa"),at:.init(74,9,0.3))
        m.merge(IsometricFurniture.model("fanzhuo"),at:.init(71,58,0.3))
        m.merge(IsometricFurniture.model("dianshigui").exchangingAxes(),at:.init(6,55,0.3))
        m.merge(IsometricFurniture.model("floor-lamp"),at:.init(112,39,0.3))
        m.merge(IsometricFurniture.model("beikedeng"),at:.init(76,59,22.4))
        m.merge(IsometricFurniture.model("cart"),at:.init(28,101,0.3))
        m.merge(IsometricFurniture.model("beibao"),at:.init(98,105,0.3))
        return m
    }
}
