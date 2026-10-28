import Foundation

nonisolated enum IsometricRoom {
    static let sideLength = 128.0
    static let wallHeight = 70.0

    static func model(style: String) -> IsoMesh {
        let green=style=="home2"
        let wall: UInt32=green ? 0x4F9C8A:0xE5BE87
        let trim: UInt32=green ? 0x285D57:0x95603D
        let wood: UInt32=green ? 0xAB8150:0xC58B4F
        var m=IsoMesh()
        // 地台、墙体都有厚度，所有顶边严格共享同一投影。
        m.box(-4,-4,-7,136,136,7,trim)
        m.box(-4,-4,0,4,132,wallHeight,wall)
        m.box(-4,-4,0,132,4,wallHeight,wall)
        m.box(-4,-4,wallHeight,4,132,1.2,IsoColor.shade(wall,1.1))
        m.box(-4,-4,wallHeight,132,4,1.2,IsoColor.shade(wall,1.1))
        // 木板按行错缝；纹理位置可复现，不在刷新时随机闪动。
        for row in 0..<16 {
            let y=Double(row)*8
            let shift=(row%2)*16
            for col in -1..<5 {
                let start=max(0,Double(col*32+shift)), end=min(128,Double((col+1)*32+shift))
                guard end>start else { continue }
                let tint=IsoColor.shade(wood,0.95+Double((row*7+col+9)%5)*0.026)
                m.top(start,y,0.06,end-start,7.8,tint)
                m.top(start+0.4,y+7.2,0.10,max(0.1,end-start-0.8),0.5,IsoColor.shade(wood,0.77))
                for grain in 0..<2 {
                    let x=start+2+Double(grain)*6
                    if x+7<end { m.top(x,y+2+Double(grain)*2,0.13,7,0.28,IsoColor.shade(tint,0.88)) }
                }
            }
        }
        // 墙板接缝和踢脚线。
        for t in stride(from:8.0,to:128,by:8) {
            m.side(0.06,t,5,0.6,64,IsoColor.shade(wall,0.69))
            m.front(t,0.06,5,0.6,64,IsoColor.shade(wall,0.90))
        }
        m.box(0,0,0,1.2,128,5,trim)
        m.box(0,0,0,128,1.2,5,trim)
        window(&m)
        poster(&m,x:72,z:31,green:green)
        // 两个挂板、小书架与盆栽，丰富房间结构而不改动物品数据。
        m.box(12,0.3,55,32,8,1.6,0xC5AE7D)
        let bookColors = PixelPalette.bookColors
        for i in 0..<5 {
            m.box(14+Double(i)*3.8,1,56.7,2.7,6,9+Double(i%3),bookColors[i%4])
            m.front(14.5+Double(i)*3.8,7.06,63,1.7,0.7,0xE2D4AC)
        }
        m.merge(IsometricFurniture.plant(),at:.init(39,4,56.7))
        m.box(51,0.2,30,12,1,15,0xD6CA9F)
        m.front(52,1.3,39,10,5,0x8F9B77)
        for row in 0..<3 {
            for col in 0..<4 {
                m.front(52.5+Double(col)*2.3,1.36,32+Double(row)*2,0.9,0.8,0x8B8465)
            }
        }
        // 织物地毯：条带、内边框和流苏都在地面平面。
        m.top(67,55,0.18,42,40,green ? 0x387F64:0xA64D45)
        m.top(69,57,0.22,38,36,green ? 0x6FAD69:0xD79259)
        for y in stride(from:60.0,to:91,by:4) {
            m.top(71,y,0.26,34,0.6,green ? 0x91C276:0xEEBE7C)
        }
        // 斜纹与小菱形组成织物花纹，提升缩略图中可以辨认的材质层次。
        for row in 0..<5 {
            for col in 0..<5 {
                let x=73+Double(col)*6, y=61+Double(row)*6
                m.face([.init(x,y+2,0.3),.init(x+2,y,0.3),.init(x+4,y+2,0.3),.init(x+2,y+4,0.3)],
                       green ? 0xB8D785:0xF4CD89)
            }
        }
        for x in stride(from:68.0,to:108,by:2) {
            m.top(x,53,0.20,1,2,0xCCBA8E);m.top(x,95,0.20,1,2,0xCCBA8E)
        }
        // 接触处通过深色台座压住植物，不使用漂浮的整块灰色投影。
        m.box(7,104,0.2,13,13,3,0x786248)
        var plant=IsometricFurniture.plant()
        plant.faces=plant.faces.map { face in
            IsoFace(points:face.points.map { .init($0.x*1.7,$0.y*1.7,$0.z*1.7) },color:face.color,outline:face.outline)
        }
        m.merge(plant,at:.init(13,110,3.2))
        return m
    }

    private static func window(_ m: inout IsoMesh) {
        m.box(0,32,24,2,39,32,PixelPalette.cream)
        m.side(2.09,35,27,33,26,0x8EC9CC)
        m.side(2.12,36,28,31,12,0xB7AD7E)
        // 窗外抽象树影，仍在窗玻璃所在的面上。
        m.face([.init(2.16,36,29),.init(2.16,43,43),.init(2.16,52,29)],0x7B8B63)
        m.face([.init(2.19,48,29),.init(2.19,59,40),.init(2.19,66,29)],0xC49669)
        m.face([.init(2.23,37,49),.init(2.23,51,28),.init(2.23,55,28),.init(2.23,39,51)],0xE9E6CA)
        m.box(2.3,50,26,1.2,2,28,0xE8E0C6)
        m.box(0,30,22,11,43,2,0xD7BA82)
        m.merge(IsometricFurniture.plant(),at:.init(6,39,24))
        m.box(3,56,24,5,4,6,0xA58C52)
        m.top(3,56,30.1,5,4,0xD8B867)
    }

    private static func poster(_ m: inout IsoMesh, x: Double, z: Double, green: Bool) {
        m.box(x,0.3,z,25,1.3,29,0x9B6B46)
        m.front(x+1.8,1.7,z+2,21.4,25,0xE1C68F)
        m.front(x+4,1.76,z+4,17,21,green ? 0xA9B180:0x718B83)
        m.face([.init(x+5,1.8,z+5),.init(x+11,1.8,z+18),.init(x+19,1.8,z+5)],0x536B48)
        m.front(x+16,1.84,z+18,3,3,0xE4C973)
        m.front(x+4,1.86,z+4,17,2,0xC7B481)
    }

    /// 只用于开发预览/导出示例；不会往用户数据库添加虚构容器。
    static func furnishedExample(style: String) -> IsoMesh {
        var m=model(style:style)
        m.merge(IsometricFurniture.model("bingxiang"),at:.init(4,5,0.3))
        m.merge(IsometricFurniture.model("bijia"),at:.init(36,3,0.3))
        m.merge(IsometricFurniture.model("shafa"),at:.init(74,9,0.3))
        m.merge(IsometricFurniture.model("fanzhuo"),at:.init(71,58,0.3))
        m.merge(IsometricFurniture.model("dianshigui").exchangingAxes(),at:.init(6,55,0.3))
        m.merge(IsometricFurniture.model("floor-lamp"),at:.init(112,39,0.3))
        m.merge(IsometricFurniture.model("beikedeng"),at:.init(76,59,21.4))
        m.merge(IsometricFurniture.model("cart"),at:.init(28,101,0.3))
        m.merge(IsometricFurniture.model("beibao"),at:.init(98,105,0.3))
        return m
    }
}
