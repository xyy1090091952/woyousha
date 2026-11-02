import Foundation

nonisolated enum IsoKitchenFurniture {
    private static let p = PixelPalette.self
    static func build(_ id: String, into m: inout IsoMesh) -> Bool {
        switch id {
        case "round-dining-table":
            m.cylinder(21,21,0,radius:12,height:3,color:p.wood)
            m.cylinder(21,21,3,radius:3,height:25,color:p.wood)
            m.cylinder(21,21,28,radius:23,height:3,color:p.woodLight,sides:24)
            for x in [10.0,31] { m.cylinder(x,21,31,radius:6,height:0.7,color:p.cream) }
            IsometricFurniture.mug(&m,x:21,y:11,z:31)
        case "breakfast-bar":
            for x in [3.0,38] { m.box(x,1,0,3,16,36,p.woodDark) }
            m.box(2,1,16,40,2,16,p.wood)
            m.roundedBox(0,0,36,46,21,3,radius:2,color:p.woodLight)
            m.box(2,16,10,40,1.5,1.5,IsoCatalogParts.metal)
            IsometricFurniture.mug(&m,x:12,y:8,z:39)
            m.cylinder(32,9,39,radius:5,height:0.6,color:p.cream)
        case "bar-stool":
            m.cylinder(11,11,0,radius:11,height:2,color:p.ink)
            m.cylinder(11,11,2,radius:1.8,height:26,color:IsoCatalogParts.metal)
            m.cylinder(11,11,12,radius:7,height:0.8,color:IsoCatalogParts.metal)
            m.cylinder(11,11,28,radius:10,height:3,color:p.coral)
            m.roundedBox(2,1,31,18,3,9,radius:2,color:p.coral)
        case "kitchen-island":
            IsoCatalogParts.cabinet(&m,width:43,depth:34,height:28,color:p.teal)
            m.box(-3,-2,29.6,49,38,3,p.cream)
            for x in [2.0,23] {
                m.front(x,34.1,5,18,21,p.tealLight)
                m.box(x+5,34.2,23,8,1,1,p.woodDark)
            }
            m.top(6,5,32.7,18,13,IsoCatalogParts.metal)
            m.top(8,7,32.8,14,9,p.ink)
            m.top(9,8,32.9,12,7,p.blue)
            tap(&m,x:15,y:4,z:32.7)
            m.box(29,14,32.7,10,12,0.8,p.woodLight)
        case "kitchen-shelf":
            IsoCatalogParts.shelf(&m,width:37,depth:18,height:43,levels:4,color:IsoCatalogParts.metal)
            for z in [5.0,18,31] {
                for x in [7.0,18,29] {
                    m.cylinder(x,7,z,radius:3.2,height:z == 18 ? 5 : 7,color:z == 18 ? p.cream : p.teal)
                    m.cylinder(x,7,z+(z == 18 ? 5 : 7),radius:3.4,height:1,color:p.woodLight)
                }
            }
        case "microwave":
            m.roundedBox(0,0,0,33,20,19,radius:2,color:p.cream)
            m.front(2,20.1,2,23,15,p.ink)
            m.front(4,20.2,4,19,11,0x507181)
            m.front(5,20.3,12,16,1,0x9ABEC4)
            m.box(24,20.3,4,1,1,11,p.woodDark)
            m.front(27,20.2,12,4,3,p.teal)
            for z in [5.0,9] { IsoHouseholdDetails.disc(&m,x:29,y:20.3,z:z,radius:1.3,color:p.ink) }
        case "rice-cooker":
            m.cylinder(12,11,1,radius:11,height:13,color:p.cream,sides:20)
            m.cylinder(12,11,14,radius:11.5,height:3,color:p.tealLight,sides:20)
            m.roundedBox(7,8,17,10,4,2,radius:1,color:p.ink)
            m.front(8,22.1,5,8,5,p.teal)
            m.front(10,22.2,6,4,2,p.cream)
            for x in [-1.0,22] { m.box(x,8,8,3,6,2,p.ink) }
        case "electric-kettle":
            m.cylinder(11,11,0,radius:10,height:2,color:p.ink)
            m.cylinder(11,11,2,radius:9,height:14,color:p.coral,topRadius:6,sides:20)
            m.cylinder(11,11,16,radius:6,height:2,color:p.cream)
            m.cylinder(11,11,18,radius:1.4,height:1.4,color:p.ink)
            m.profile([(2,7),(-4,15),(-4,18),(4,14)],y:9,depth:3,color:p.coral)
            for (a,b) in [(IsoPoint(18,10,14),IsoPoint(24,10,13)),
                          (.init(24,10,13),.init(24,10,5)),(.init(24,10,5),.init(19,10,5))] {
                IsoCatalogParts.rod(&m,a,b,radius:1.3,color:p.ink)
            }
        case "coffee-machine":
            m.box(0,0,0,25,23,3,p.ink)
            m.roundedBox(1,1,3,23,9,25,radius:2,color:p.coral)
            m.box(1,1,22,23,18,6,p.coral)
            m.front(4,19.1,23,17,3,p.ink)
            m.box(10,12,14,5,5,9,IsoCatalogParts.metal)
            m.box(14,15,16,8,1.5,1.5,p.ink)
            m.cylinder(12,15,3,radius:3.5,height:6,color:p.cream)
            m.box(2,21,3,21,2,1,IsoCatalogParts.metal)
            m.cylinder(18,5,28,radius:5,height:7,color:p.woodDark,topRadius:3)
        case "toaster":
            m.roundedBox(0,0,0,25,16,15,radius:4,color:p.yellow)
            for y in [4.0,10] {
                m.top(4,y,15.1,16,2,p.ink)
                m.box(6,y,15,12,1.5,4,p.woodLight)
                m.front(7,y+1.6,16,10,2,p.cream)
            }
            m.box(24,7,6,2,2,5,p.ink)
            IsoHouseholdDetails.disc(&m,x:19,y:16.1,z:6,radius:2,color:p.ink)
        case "dishwasher":
            IsoCatalogParts.cabinet(&m,width:26,depth:24,height:34,color:IsoCatalogParts.metal)
            m.front(1,24.1,4,24,28,0xCDD9D0)
            m.front(2,24.2,27,22,4,p.ink)
            m.front(5,24.3,28,6,1.5,p.tealLight)
            m.box(5,24.3,23,16,1,1.5,p.ink)
            m.front(2,24.2,5,22,0.7,0xA3B7B1)
        case "chest-freezer":
            m.roundedBox(0,0,2,42,24,26,radius:2,color:p.cream)
            m.box(0,0,28,42,24,3,0xB5D5D0)
            m.top(2,2,31.1,38,20,p.cream)
            m.box(16,24.2,27,10,1.5,1.5,p.ink)
            m.front(2,24.1,5,7,5,p.teal)
            for x in [32.0,35,38] { m.front(x,24.1,5,1,8,IsoCatalogParts.metal) }
            for x in [4.0,36] { IsoCatalogParts.wheel(&m,x:x,y:3,z:2,radius:2) }
        default: return false
        }
        return true
    }

    static func tap(_ m: inout IsoMesh, x:Double, y:Double, z:Double) {
        IsoCatalogParts.rod(&m,.init(x,y,z),.init(x,y,z+9),color:IsoCatalogParts.metal)
        IsoCatalogParts.rod(&m,.init(x,y,z+9),.init(x,y+6,z+9),color:IsoCatalogParts.metal)
        IsoCatalogParts.rod(&m,.init(x,y+6,z+9),.init(x,y+6,z+7),color:IsoCatalogParts.metal)
    }
}
