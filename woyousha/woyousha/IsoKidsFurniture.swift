import Foundation

nonisolated enum IsoKidsFurniture {
    private static let p = PixelPalette.self
    static func build(_ id: String, into m: inout IsoMesh) -> Bool {
        switch id {
        case "kids-table":
            IsoCatalogParts.table(&m,width:34,depth:23,height:15,color:p.yellow)
            m.box(8,5,17.5,13,10,0.7,p.cream)
            for (i,color) in [p.blue,p.coral,p.green].enumerated() {
                m.box(10+Double(i)*3,8,18.2,1,6,0.7,color)
            }
        case "kids-chair":
            IsoCatalogParts.chair(&m,width:16,depth:16,seat:11,back:25,color:p.coral)
            IsoHouseholdDetails.disc(&m,x:8,y:3.1,z:20,radius:3,color:p.yellow)
        case "toy-chest":
            m.roundedBox(0,0,0,30,21,20,radius:3,color:p.tealLight)
            m.box(-1,-1,20,32,23,2,p.woodLight)
            m.front(3,21.1,3,24,14,p.teal)
            for (i,color) in [p.yellow,p.coral,p.cream].enumerated() {
                IsoHouseholdDetails.disc(&m,x:8+Double(i)*7,y:21.2,z:10,radius:2.5,color:color)
            }
            m.box(12,21.3,16,6,1,1,p.ink)
        case "play-kitchen":
            m.box(0,0,0,38,16,23,p.coral)
            m.box(-1,-1,23,40,18,2,p.cream)
            m.box(0,0,25,38,2,17,p.teal)
            m.box(-1,0,41,40,7,2,p.woodLight)
            m.front(3,16.1,3,17,15,p.ink)
            m.front(5,16.2,5,13,10,0x6E98A2)
            m.box(5,16.3,16,13,1,1,p.cream)
            m.front(23,16.1,3,12,18,p.woodLight)
            for x in [8.0,16] { m.cylinder(x,10,25,radius:3,height:0.4,color:p.ink) }
            m.top(24,7,25.1,10,7,p.blue)
            IsoKitchenFurniture.tap(&m,x:29,y:5,z:25)
        case "dollhouse":
            IsoCatalogParts.shelf(&m,width:29,depth:15,height:32,levels:3,color:p.cream,back:true)
            m.box(14,0,2,1.5,15,30,p.cream)
            m.profile([(0,32),(14.5,46),(29,32)],y:0,depth:15,color:p.coral)
            m.profile([(4,34),(14.5,43),(25,34)],y:15.1,depth:0,color:p.woodLight)
            m.box(5,6,4,7,6,4,p.teal)
            m.box(19,5,19,7,8,3,p.purple)
            m.box(20,5,22,5,3,1,p.cream)
            m.front(12,15.2,34,5,6,p.blue)
        case "kids-slide":
            for x in [0.0,20] { m.box(x,0,0,2,12,28,p.yellow) }
            m.box(0,0,28,22,12,3,p.yellow)
            m.face([.init(2,12,29),.init(20,12,29),.init(20,46,2),.init(2,46,2)],p.tealLight)
            for x in [0.0,20] {
                m.face([.init(x,12,29),.init(x+2,12,29),.init(x+2,46,2),.init(x,46,2)],p.teal)
                IsoCatalogParts.rod(&m,.init(x,12,34),.init(x,46,7),radius:1,color:p.teal)
            }
            for z in [6.0,13,20] { m.box(2,-1,z,18,2,2,p.coral) }
        case "rocking-horse":
            for x in [2.0,14] {
                m.face([.init(x,-3,4),.init(x,6,0),.init(x,24,0),.init(x,33,5),
                        .init(x,32,7),.init(x,23,2),.init(x,7,2),.init(x,-2,6)],p.wood)
                for y in [5.0,22] { IsoCatalogParts.rod(&m,.init(x,y,3),.init(x,y,14),radius:1.2,color:p.woodLight) }
            }
            m.roundedBox(0,4,14,19,24,9,radius:4,color:p.woodLight)
            m.roundedBox(3,10,23,13,13,2,radius:2,color:p.coral)
            m.profile([(1,18),(1,33),(5,39),(10,34),(13,32),(12,28),(7,29),(8,18)],
                      y:1,depth:8,color:p.woodLight)
            IsoHouseholdDetails.disc(&m,x:7,y:9.1,z:33,radius:1,color:p.ink)
            IsoCatalogParts.rod(&m,.init(-2,6,28),.init(20,6,28),radius:1,color:p.teal)
        case "cat-tree":
            m.roundedBox(0,0,0,29,27,3,radius:2,color:p.woodLight)
            for (x,y,h) in [(6.0,6.0,38.0),(23.0,20.0,24.0)] {
                m.cylinder(x,y,3,radius:2.3,height:h,color:p.cream)
                for z in stride(from:6.0,through:h,by:3) { m.cylinder(x,y,z,radius:2.5,height:0.5,color:p.wood) }
            }
            m.box(1,10,11,15,15,13,p.purple)
            IsoHouseholdDetails.disc(&m,x:8.5,y:25.1,z:17,radius:4,color:p.ink)
            m.cylinder(23,20,27,radius:8,height:2,color:p.teal)
            m.cylinder(6,6,41,radius:10,height:2,color:p.tealLight)
            IsoCatalogParts.rod(&m,.init(13,6,43),.init(13,6,33),radius:0.3,color:p.cream)
            IsoCatalogParts.ellipsoid(&m,center:.init(13,6,31),radii:.init(2,2,2),color:p.coral)
        case "pet-crate":
            m.box(0,0,0,30,24,3,p.woodLight)
            m.box(0,0,26,30,24,2,p.woodLight)
            for x in stride(from:0.0,through:30,by:5) {
                for y in [0.0,24] { m.box(x,y,3,0.9,0.9,23,IsoCatalogParts.metal) }
            }
            for y in stride(from:0.0,through:24,by:4) {
                for x in [0.0,30] { m.box(x,y,3,0.9,0.9,23,IsoCatalogParts.metal) }
            }
            m.box(0,24.1,14,30,1,0.8,IsoCatalogParts.metal)
            m.box(15,24.2,10,1,1,9,p.ink)
            m.roundedBox(4,4,3,22,17,3,radius:4,color:p.coral)
        case "fish-tank-stand":
            IsoCatalogParts.cabinet(&m,width:39,depth:21,height:24,color:p.woodDark)
            m.front(2,21.1,5,35,17,p.wood)
            m.front(19,21.2,5,0.8,17,p.woodDark)
            m.box(0,0,25.6,39,21,24,0x83BCC6)
            m.box(0,0,49.6,39,21,2,p.ink)
            m.front(2,21.1,28,35,3,p.woodLight)
            for (x,z) in [(10.0,38.0),(27.0,42.0)] {
                m.profile([(x-3,z),(x+2,z+2),(x+5,z),(x+2,z-2)],y:21.2,depth:0,color:p.yellow)
                m.profile([(x-3,z),(x-6,z+2),(x-6,z-2)],y:21.2,depth:0,color:p.coral)
            }
            for x in [5.0,31] { m.front(x,21.2,31,1.2,10,p.green) }
            m.face([.init(3,21.3,34),.init(9,21.3,47),.init(11,21.3,47),.init(5,21.3,34)],0xCBE8E0)
        default: return false
        }
        return true
    }
}
