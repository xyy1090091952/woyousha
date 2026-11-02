import Foundation

nonisolated enum IsoBathroomFurniture {
    private static let p = PixelPalette.self
    static func build(_ id: String, into m: inout IsoMesh) -> Bool {
        switch id {
        case "bathtub":
            // 分开建底、四边和内胆，俯视角可以看见凹槽。
            m.roundedBox(0,0,3,46,24,8,radius:5,color:p.cream)
            for x in [0.0,41] { m.roundedBox(x,0,9,5,24,9,radius:2,color:p.cream) }
            for y in [0.0,19] { m.roundedBox(3,y,9,40,5,9,radius:2,color:p.cream) }
            m.roundedBox(5,5,10,36,14,1,radius:3,color:p.tealLight)
            for x in [5.0,35] { m.box(x,3,0,5,5,4,IsoCatalogParts.metal) }
            IsoKitchenFurniture.tap(&m,x:8,y:2,z:18)
        case "shower-stall":
            m.roundedBox(0,0,0,28,28,4,radius:2,color:p.cream)
            // 玻璃以低饱和亮面表示，细框和斜高光避免变成不透明木柜。
            m.side(0,0,4,28,49,0xB2DDDA)
            m.front(0,0,4,28,49,0xCEE7DD)
            m.side(28,0,4,28,49,0x96C7CF)
            for x in [0.0,27] { for y in [0.0,27] { m.box(x,y,4,1,1,49,IsoCatalogParts.metal) } }
            for x in [0.0,27] { m.box(x,0,53,1,28,1.2,IsoCatalogParts.metal) }
            for y in [0.0,27] { m.box(0,y,53,28,1,1.2,IsoCatalogParts.metal) }
            m.front(1,28.1,5,26,47,0xB4D8D9)
            m.face([.init(3,28.2,9),.init(17,28.2,45),.init(20,28.2,45),.init(6,28.2,9)],0xDFF3E9)
            m.box(23,28.3,22,1,1.5,9,p.ink)
            IsoCatalogParts.rod(&m,.init(6,3,18),.init(6,3,46),color:p.ink)
            m.cylinder(6,8,45,radius:4,height:1,color:IsoCatalogParts.metal)
        case "toilet":
            m.roundedBox(3,0,5,20,8,27,radius:3,color:p.cream)
            m.roundedBox(2,-1,32,22,10,2,radius:2,color:p.cream)
            m.cylinder(13,18,0,radius:7,height:12,color:p.cream,topRadius:10)
            m.roundedBox(0,9,11,26,24,6,radius:8,color:p.cream)
            m.roundedBox(4,12,17,18,18,0.5,radius:6,color:p.ink)
            m.roundedBox(6,14,17.6,14,14,0.4,radius:5,color:p.tealLight)
            m.box(18,8.1,27,4,1,1.5,IsoCatalogParts.metal)
        case "pedestal-sink":
            m.cylinder(13,11,0,radius:7,height:3,color:p.cream)
            m.cylinder(13,11,3,radius:4,height:23,color:p.cream,topRadius:5)
            basin(&m,x:0,y:0,z:25,width:26,depth:22)
            IsoKitchenFurniture.tap(&m,x:13,y:2,z:30)
        case "vanity-sink":
            IsoCatalogParts.cabinet(&m,width:42,depth:22,height:25,color:p.teal)
            for x in [2.0,23] {
                m.front(x,22.1,5,17,18,p.tealLight)
                m.box(x+5,22.2,19,6,1,1,p.cream)
            }
            m.box(-1,-1,26.6,44,24,2,p.cream)
            basin(&m,x:9,y:2,z:28.6,width:24,depth:18)
            IsoKitchenFurniture.tap(&m,x:21,y:1,z:33.6)
        case "towel-rack":
            for x in [1.0,23] {
                m.box(x,0,0,2,15,2,p.woodDark)
                IsoCatalogParts.rod(&m,.init(x+1,7,2),.init(x+1,7,35),color:p.woodLight)
            }
            for (i,z) in [20.0,34].enumerated() {
                IsoCatalogParts.rod(&m,.init(2,7,z),.init(24,7,z),color:p.woodLight)
                m.front(5,8,z-14,16,14,i == 0 ? p.teal : p.coral)
                m.front(5,8.1,z-12,16,1,p.cream)
            }
        case "laundry-hamper":
            m.roundedBox(0,0,0,23,21,27,radius:3,color:p.cream)
            for x in stride(from:3.0,through:19,by:4) {
                for z in stride(from:4.0,through:22,by:5) { m.front(x,21.1,z,2,2,p.wood) }
            }
            m.box(-1,-1,27,25,23,2,p.woodLight)
            m.roundedBox(5,4,29,15,11,4,radius:2,color:p.coral)
            m.roundedBox(3,10,29,11,10,3,radius:2,color:p.blue)
        case "drying-rack":
            for x in [4.0,33] {
                IsoCatalogParts.rod(&m,.init(x,0,0),.init(x,24,28),color:IsoCatalogParts.metal)
                IsoCatalogParts.rod(&m,.init(x,24,0),.init(x,0,28),color:IsoCatalogParts.metal)
            }
            for y in stride(from:0.0,through:24,by:4) {
                IsoCatalogParts.rod(&m,.init(0,y,28),.init(38,y,28),radius:0.7,color:IsoCatalogParts.metal)
            }
            m.front(7,20,13,11,15,p.teal)
            m.front(22,12,10,10,18,p.coral)
            m.front(8,20.1,15,9,1,p.cream)
        case "dryer":
            IsoCatalogParts.cabinet(&m,width:27,depth:24,height:35,color:p.cream)
            IsoHouseholdDetails.disc(&m,x:13.5,y:24.1,z:17,radius:10,color:p.woodLight,depth:1.2)
            IsoHouseholdDetails.disc(&m,x:13.5,y:25.4,z:17,radius:8,color:0x6A747A)
            IsoHouseholdDetails.disc(&m,x:13.5,y:25.5,z:17,radius:5.5,color:p.coral)
            m.front(2,24.1,29,23,4,IsoCatalogParts.metal)
            m.front(4,24.2,30,7,2,p.ink)
            IsoHouseholdDetails.disc(&m,x:21,y:24.2,z:31,radius:1.5,color:p.ink)
            for x in [4.0,7,10,13] { m.front(x,24.2,5,1,3,p.woodDark) }
        case "ironing-board":
            for y in [5.0,12] {
                IsoCatalogParts.rod(&m,.init(5,y,0),.init(34,y,24),radius:1.2,color:IsoCatalogParts.metal)
                IsoCatalogParts.rod(&m,.init(34,y,0),.init(5,y,24),radius:1.2,color:IsoCatalogParts.metal)
            }
            m.roundedBox(0,0,24,43,18,2.5,radius:7,color:p.tealLight)
            m.box(29,3,26.5,10,9,2,p.ink)
            m.profile([(30,28),(31,33),(36,34),(38,28)],y:5,depth:5,color:p.coral)
            m.box(32,6,34,4,2,1,p.ink)
        default: return false
        }
        return true
    }

    private static func basin(_ m: inout IsoMesh, x:Double, y:Double, z:Double, width:Double, depth:Double) {
        m.roundedBox(x,y,z,width,depth,4,radius:4,color:p.cream)
        m.roundedBox(x+3,y+4,z+4,width-6,depth-7,0.5,radius:3,color:0xB2D6D2)
        m.cylinder(x+width/2,y+depth/2,z+4.6,radius:1,height:0.1,color:IsoCatalogParts.metal)
    }
}
