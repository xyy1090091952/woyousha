import Foundation

/// 装饰模型以放置锚点为原点，移动和缩放不会改变与地面/墙面的等轴关系。
nonisolated enum IsometricDecoration {
    static func model(_ kind: RoomDecoration.Kind, style: String) -> IsoMesh {
        var m = IsoMesh()
        switch kind {
        case .plant:
            m = IsometricFurniture.plant()
            m.faces = m.faces.map { face in
                IsoFace(points:face.points.map { .init($0.x*1.7,$0.y*1.7,$0.z*1.7) },color:face.color,outline:face.outline)
            }
            m.cylinder(0,0,-2,radius:6,height:2,color:PixelPalette.woodLight)
        case .rug:
            m.top(-21,-20,0,42,40,style=="home2" ? 0x387F64:0xA64D45)
            m.top(-19,-18,0.03,38,36,style=="home2" ? 0x6FAD69:0xD79259)
            for row in 0..<5 {
                for col in 0..<5 {
                    let x = -15+Double(col)*6, y = -14+Double(row)*6
                    m.face([.init(x,y+2,0.08),.init(x+2,y,0.08),.init(x+4,y+2,0.08),.init(x+2,y+4,0.08)],
                           style=="home2" ? 0xB8D785:0xF4CD89)
                }
            }
            for x in stride(from:-20.0,to:20,by:2) {
                m.top(x,-22,0,1,2,PixelPalette.cream)
                m.top(x,20,0,1,2,PixelPalette.cream)
            }
        case .window:
            m.roundedBox(0,-19.5,2,2,39,32,radius:0.7,color:PixelPalette.cream)
            m.side(2.1,-16.5,5,33,26,0x8EC9CC)
            m.face([.init(2.2,-14,27),.init(2.2,1,5),.init(2.2,6,5),.init(2.2,-10,30)],0xE8F4DD)
            m.box(2.3,-1.5,4,1.2,2,28,PixelPalette.cream)
            m.roundedBox(0,-21.5,0,11,43,2,radius:0.8,color:PixelPalette.woodLight)
        case .picture:
            m.roundedBox(-12.5,0,0,25,1.6,29,radius:0.6,color:PixelPalette.wood)
            m.front(-10.5,1.7,2,21,25,PixelPalette.cream)
            m.front(-8.5,1.8,4,17,21,0x6AAA8F)
            m.face([.init(-7.5,1.9,5),.init(-1.5,1.9,18),.init(6.5,1.9,5)],0x39724E)
            m.front(3.5,1.92,18,3,3,PixelPalette.yellow)
        case .wallShelf:
            m.roundedBox(-16,0.3,0,32,8,2,radius:1,color:PixelPalette.woodLight)
            for i in 0..<5 {
                m.box(-14+Double(i)*3.8,1,2.1,2.7,6,9+Double(i%3),PixelPalette.bookColors[i])
                m.front(-13.5+Double(i)*3.8,7.1,8.5,1.7,0.7,PixelPalette.cream)
            }
        case .calendar:
            m.roundedBox(-6,0,0,12,1,15,radius:0.4,color:PixelPalette.cream)
            m.front(-5,1.1,9,10,5,PixelPalette.greenLight)
            for row in 0..<3 {
                for col in 0..<4 { m.front(-4.5+Double(col)*2.3,1.2,2+Double(row)*2,0.9,0.8,PixelPalette.teal) }
            }
        case .clock: m = IsometricHouseholdDecoration.clock()
        case .flowers: m = IsometricHouseholdDecoration.flowers(style: style)
        case .tableLamp: m = IsometricHouseholdDecoration.tableLamp()
        case .cactus: m = IsometricHouseholdDecoration.cactus()
        case .cushions: m = IsometricHouseholdDecoration.cushions(style: style)
        case .teddyBear: m = IsometricHouseholdDecoration.teddyBear()
        case .floorMirror: m = IsometricHouseholdDecoration.floorMirror()
        case .aquarium: m = IsometricHouseholdDecoration.aquarium()
        case .speaker: m = IsometricHouseholdDecoration.speaker()
        case .petBed: m = IsometricHouseholdDecoration.petBed()
        }
        return m
    }
}
