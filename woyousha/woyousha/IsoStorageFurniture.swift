import Foundation

nonisolated enum IsoStorageFurniture {
    private static let p = PixelPalette.self
    static func build(_ id: String, into m: inout IsoMesh) -> Bool {
        switch id {
        case "drawer-chest":
            IsoCatalogParts.cabinet(&m,width:35,depth:20,height:45)
            for z in [5.0,13,21,29,37] { IsoHouseholdDetails.drawer(&m,x:2,y:20.1,z:z,width:31,height:6) }
        case "cube-shelf":
            IsoCatalogParts.shelf(&m,width:40,depth:16,height:39,levels:3,color:p.cream,back:true)
            m.box(19,0,2,2,16,36,p.cream)
            for (x,z,color) in [(3.0,4.0,p.teal),(23.0,4.0,p.coral),(23.0,22.0,p.yellow)] {
                m.roundedBox(x,3,z,14,12,12,radius:1,color:color)
                m.front(x+5,15.1,z+8,4,1.5,p.cream)
            }
            IsoCatalogParts.books(&m,x:3,y:5,z:22,count:4)
        case "sideboard":
            IsoCatalogParts.cabinet(&m,width:46,depth:18,height:29)
            for x in [2.0,24] {
                m.front(x,18.1,5,20,21,p.cream)
                m.box(x+8,18.2,20,5,1,1,p.woodDark)
            }
            m.cylinder(13,8,30.6,radius:5,height:1,color:p.cream)
            m.cylinder(13,8,31.6,radius:4.5,height:1,color:p.cream)
            IsoCatalogParts.plant(&m,x:35,y:7,z:30.6,size:0.65)
        case "glass-cabinet":
            IsoCatalogParts.shelf(&m,width:25,depth:17,height:51,levels:4,color:p.wood,back:true)
            m.front(2,17.1,4,21,45,0x81BAC4)
            for z in [5.0,20,35] {
                m.front(3,17.2,z,19,1.2,p.cream)
                for x in [8.0,17] { IsoHouseholdDetails.disc(&m,x:x,y:17.25,z:z+7,radius:3,color:p.cream) }
            }
            m.front(2,17.3,4,1,45,p.woodLight)
            m.front(22,17.3,4,1,45,p.woodLight)
            m.face([.init(4,17.4,8),.init(16,17.4,46),.init(18,17.4,46),.init(6,17.4,8)],0xC4E4DA)
            m.box(20,17.5,25,1,1,6,p.yellow)
        case "corner-cabinet":
            m.face([.init(0,0,0),.init(28,0,0),.init(0,28,0)],p.wood)
            m.face([.init(28,0,0),.init(0,28,0),.init(0,28,38),.init(28,0,38)],p.wood)
            m.face([.init(0,0,38),.init(28,0,38),.init(0,28,38)],p.woodLight)
            for z in [4.0,22] {
                m.face([.init(25,3,z),.init(3,25,z),.init(3,25,z+13),.init(25,3,z+13)],p.cream)
                IsoCatalogParts.rod(&m,.init(13,15,z+8),.init(16,12,z+8),radius:0.7,color:p.woodDark)
            }
        case "floating-cabinet":
            m.roundedBox(0,0,0,42,12,19,radius:2,color:p.cream)
            for x in [2.0,23] {
                m.front(x,12.1,2,17,15,p.tealLight)
                m.box(x+5,12.2,13,7,1,1,p.woodDark)
            }
            m.box(-0.5,-0.5,19,43,13,1.5,p.woodLight)
        case "entry-bench":
            IsoCatalogParts.shelf(&m,width:39,depth:18,height:17,levels:2)
            m.roundedBox(0,0,18,39,18,4,radius:3,color:p.coral)
            for x in [5.0,14,24] { m.roundedBox(x,5,4,6,11,4,radius:2,color:p.blue) }
        case "coat-tree":
            m.cylinder(12,12,0,radius:10,height:2,color:p.wood)
            IsoCatalogParts.rod(&m,.init(12,12,2),.init(12,12,52),radius:1.8,color:p.woodLight)
            for i in 0..<4 {
                let a = Double(i) * .pi/2, z = 36+Double(i%2)*8
                IsoCatalogParts.rod(&m,.init(12,12,z),.init(12+cos(a)*11,12+sin(a)*11,z+5),radius:1.2,color:p.wood)
            }
            m.profile([(19,25),(17,30),(18,39),(22,39),(24,29),(24,25)],y:11,depth:2,color:p.blue)
            m.cylinder(12,12,52,radius:2,height:2,color:p.wood)
        case "umbrella-stand":
            m.cylinder(11,11,0,radius:9,height:20,color:p.teal)
            m.cylinder(11,11,20,radius:9,height:1,color:p.woodLight)
            m.cylinder(11,11,21.1,radius:7,height:0.1,color:p.ink)
            for (i,x) in [6.0,12,16].enumerated() {
                IsoCatalogParts.rod(&m,.init(x,11,8),.init(x,11,34+Double(i)*3),radius:1.2,color:p.bookColors[i])
                IsoCatalogParts.rod(&m,.init(x,11,34+Double(i)*3),.init(x+3,11,37+Double(i)*3),radius:0.9,color:p.woodLight)
                IsoCatalogParts.rod(&m,.init(x+3,11,37+Double(i)*3),.init(x+5,11,34+Double(i)*3),radius:0.9,color:p.woodLight)
            }
        case "storage-trunk":
            m.roundedBox(0,0,0,39,23,20,radius:3,color:p.woodDark)
            m.roundedBox(0,0,18,39,23,6,radius:3,color:p.wood)
            for x in [6.0,30] {
                m.front(x,23.1,2,2,20,p.yellow)
                m.top(x,1,24.1,2,21,p.yellow)
            }
            m.box(15,23.2,10,9,1.2,3,p.cream)
            m.box(17,23.3,18,5,1,4,p.yellow)
        case "tool-cabinet":
            IsoCatalogParts.cabinet(&m,width:39,depth:19,height:30,color:p.coral)
            for z in [6.0,13,20] {
                m.front(2,19.1,z,35,5,0xBC6452)
                m.box(5,19.2,z+3,29,1,1,IsoCatalogParts.metal)
            }
            m.box(-1,-1,31.6,41,21,2,p.ink)
            for x in [3.0,33] { IsoCatalogParts.wheel(&m,x:x,y:2,z:2,radius:2) }
            IsoCatalogParts.rod(&m,.init(10,8,34),.init(24,8,34),radius:1.2,color:IsoCatalogParts.metal)
            m.box(8,5,33.6,4,6,2,p.yellow)
        case "wicker-basket":
            m.roundedBox(0,0,0,26,22,17,radius:4,color:p.woodLight)
            weave(&m,width:26,depth:22,height:17)
            m.roundedBox(3,3,17,20,16,0.5,radius:3,color:p.woodDark)
            for x in [1.0,24] { m.box(x,7,16,1.5,7,6,p.wood) }
        default: return false
        }
        return true
    }

    static func weave(_ m: inout IsoMesh, width:Double, depth:Double, height:Double) {
        for z in stride(from:3.0,through:height-1,by:3) { m.front(2,depth+0.1,z,width-4,0.7,p.woodDark) }
        for x in stride(from:3.0,through:width-2,by:4) { m.front(x,depth+0.2,2,0.7,height-3,p.cream) }
        for y in stride(from:3.0,through:depth-2,by:4) { m.side(width+0.1,y,2,0.7,height-3,p.wood) }
    }
}
