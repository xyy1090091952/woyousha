import Foundation

nonisolated enum IsoOutdoorFurniture {
    private static let p = PixelPalette.self
    static func build(_ id: String, into m: inout IsoMesh) -> Bool {
        switch id {
        case "picnic-table":
            for x in [6.0,36] {
                IsoCatalogParts.rod(&m,.init(x,0,0),.init(x,20,25),radius:2,color:p.wood)
                IsoCatalogParts.rod(&m,.init(x,40,0),.init(x,20,25),radius:2,color:p.wood)
                m.box(x-1,0,11,2,40,2,p.wood)
            }
            for y in [0.0,32] { m.box(0,y,13,44,8,2,p.woodLight) }
            for y in [9.0,17,25] { m.box(0,y,25,44,7,2,p.woodLight) }
        case "garden-bench":
            IsoHouseholdDetails.feet(&m,width:43,depth:19,height:15)
            for y in [1.0,7,13] { m.box(0,y,15,43,5,2,p.woodLight) }
            for x in [2.0,39] { m.box(x,0,15,2,2,19,p.woodDark) }
            for z in [23.0,29] { m.box(0,0,z,43,2,5,p.woodLight) }
            for x in [0.0,41] { m.box(x,1,23,2,18,2,p.woodDark) }
        case "folding-chair":
            for x in [0.0,22] {
                IsoCatalogParts.rod(&m,.init(x,0,0),.init(x,22,23),color:IsoCatalogParts.metal)
                IsoCatalogParts.rod(&m,.init(x,24,0),.init(x,2,39),color:IsoCatalogParts.metal)
                m.box(x,4,24,1.5,18,1.5,p.wood)
            }
            m.face([.init(1,3,16),.init(21,3,16),.init(21,22,16),.init(1,22,16)],p.green)
            m.face([.init(1,2,25),.init(21,2,25),.init(21,2,37),.init(1,2,37)],p.green)
            m.front(3,2.1,26,16,1,p.cream)
        case "patio-table":
            IsoLivingFurniture.roundTable(&m,x:14,y:14,radius:15,height:23,color:p.teal)
            for y in [5.0,10,15,20] { m.top(5,y,25.6,18,0.5,p.cream) }
            IsoCatalogParts.plant(&m,x:14,y:14,z:25.5,size:0.6)
        case "parasol":
            m.cylinder(25,25,0,radius:10,height:3,color:p.woodDark)
            IsoCatalogParts.rod(&m,.init(25,25,3),.init(25,25,55),radius:1.2,color:p.woodLight)
            // 分瓣伞面从伞顶连到伞沿；颜色交替但几何是同一把伞。
            for i in 0..<12 {
                let a = Double(i) * .pi/6, b = Double(i+1) * .pi/6
                m.face([.init(25,25,56),.init(25+cos(a)*28,25+sin(a)*28,44),
                        .init(25+cos(b)*28,25+sin(b)*28,44)],i%2 == 0 ? p.coral : p.cream)
                IsoCatalogParts.rod(&m,.init(25,25,55),.init(25+cos(a)*28,25+sin(a)*28,43.8),
                                    radius:0.4,color:p.wood)
            }
        case "barbecue-grill":
            for x in [3.0,32] { for y in [3.0,18] { m.box(x,y,3,2,2,21,p.ink) } }
            for x in [4.0,32] { IsoCatalogParts.wheel(&m,x:x,y:17,z:3,radius:3) }
            m.box(0,0,24,37,23,10,p.ink)
            m.top(2,2,34.1,33,19,p.coral)
            for x in stride(from:4.0,through:33,by:4) {
                IsoCatalogParts.rod(&m,.init(x,2,35),.init(x,21,35),radius:0.6,color:IsoCatalogParts.metal)
            }
            m.box(0,-1,34,37,2,14,p.ink)
            m.box(8,-2,47,20,2,1.5,p.wood)
            m.box(36,3,24,11,17,1.5,p.woodLight)
            m.box(4,3,9,28,16,1,p.wood)
        case "porch-swing":
            for x in [0.0,44] {
                IsoCatalogParts.rod(&m,.init(x,0,0),.init(x,20,54),radius:1.8,color:p.wood)
                IsoCatalogParts.rod(&m,.init(x,40,0),.init(x,20,54),radius:1.8,color:p.wood)
                m.box(x-1,7,18,2,26,2,p.wood)
            }
            IsoCatalogParts.rod(&m,.init(0,20,54),.init(44,20,54),radius:2,color:p.woodDark)
            for x in [5.0,39] {
                for y in [14.0,29] { IsoCatalogParts.rod(&m,.init(x,20,52),.init(x,y,17),radius:0.45,color:p.cream) }
            }
            m.roundedBox(4,12,15,36,19,3,radius:2,color:p.teal)
            m.roundedBox(4,11,18,36,3,14,radius:2,color:p.tealLight)
            for x in [4.0,38] { m.box(x,12,25,2,19,2,p.wood) }
        case "raised-planter":
            IsoHouseholdDetails.feet(&m,width:41,depth:21,height:16)
            m.box(0,0,16,41,21,12,p.wood)
            m.top(2,2,28.1,37,17,p.woodDark)
            for z in [18.0,23] { m.front(1,21.1,z,39,0.7,p.woodLight) }
            for (x,y) in [(8.0,7.0),(20.0,13.0),(32.0,7.0)] {
                IsoCatalogParts.ellipsoid(&m,center:.init(x,y,31),radii:.init(5,4,4),color:p.greenLight)
                m.cylinder(x,y,28.2,radius:0.6,height:6,color:p.green)
            }
        case "greenhouse-shelf":
            IsoCatalogParts.shelf(&m,width:41,depth:19,height:45,levels:3,color:p.green)
            for z in [4.0,24,45] {
                for x in [8.0,21,34] { IsoCatalogParts.plant(&m,x:x,y:9,z:z,size:z == 45 ? 0.6 : 0.8) }
            }
            // 小屋形顶架明确区分普通厨房/书房置物架。
            for x in [0.0,41] {
                IsoCatalogParts.rod(&m,.init(x,0,45),.init(x,9,61),color:p.green)
                IsoCatalogParts.rod(&m,.init(x,9,61),.init(x,19,45),color:p.green)
            }
            IsoCatalogParts.rod(&m,.init(0,9,61),.init(41,9,61),color:p.green)
        case "bicycle":
            bicycle(&m)
        default: return false
        }
        return true
    }

    private static func bicycle(_ m: inout IsoMesh) {
        // 两个完整车轮、三角车架、座管和前叉，无浮空零件。
        for x in [10.0,43] {
            IsoHouseholdDetails.disc(&m,x:x,y:7,z:11,radius:11,color:p.ink,depth:2)
            IsoHouseholdDetails.disc(&m,x:x,y:9.1,z:11,radius:9,color:p.cream)
            for i in 0..<12 {
                let a = Double(i) * .pi/6
                IsoCatalogParts.rod(&m,.init(x,9.2,11),.init(x+cos(a)*9,9.2,11+sin(a)*9),
                                    radius:0.25,color:IsoCatalogParts.metal)
            }
        }
        let rear = IsoPoint(10,10,11), crank = IsoPoint(26,10,9), seat = IsoPoint(21,10,29)
        let fork = IsoPoint(38,10,28), front = IsoPoint(43,10,11)
        for (a,b) in [(rear,crank),(crank,seat),(seat,rear),(seat,fork),(fork,crank),(fork,front)] {
            IsoCatalogParts.rod(&m,a,b,radius:1,color:p.teal)
        }
        m.roundedBox(15,7,30,11,7,2,radius:2,color:p.woodDark)
        IsoCatalogParts.rod(&m,fork,.init(36,10,34),radius:0.9,color:IsoCatalogParts.metal)
        IsoCatalogParts.rod(&m,.init(36,2,34),.init(36,18,34),radius:0.9,color:p.ink)
        IsoHouseholdDetails.disc(&m,x:26,y:10.1,z:9,radius:3,color:IsoCatalogParts.metal,depth:1)
        IsoCatalogParts.rod(&m,.init(26,11.2,9),.init(30,11.2,6),radius:0.7,color:p.ink)
        m.box(29,9,5,3,5,1,p.ink)
        IsoCatalogParts.rod(&m,.init(27,9,10),.init(25,15,0),radius:0.7,color:IsoCatalogParts.metal)
    }
}
