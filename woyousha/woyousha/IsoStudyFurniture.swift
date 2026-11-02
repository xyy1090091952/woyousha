import Foundation

nonisolated enum IsoStudyFurniture {
    private static let p = PixelPalette.self
    static func build(_ id: String, into m: inout IsoMesh) -> Bool {
        switch id {
        case "corner-desk":
            IsoCatalogParts.table(&m,width:44,depth:20,height:24)
            IsoCatalogParts.table(&m,width:18,depth:43,height:24)
            m.box(7,4,26.5,16,2,11,p.ink)
            m.front(8,6.1,27.5,14,9,p.blue)
            m.box(13,7,26.5,3,3,2,p.ink)
            m.box(24,6,26.5,12,8,1,p.cream)
            IsoCatalogParts.books(&m,x:2,y:27,z:26.5,count:3)
        case "standing-desk":
            for x in [4.0,34] {
                m.box(x,0,0,5,22,2,p.ink)
                m.box(x+1,9,2,3,4,25,IsoCatalogParts.metal)
                m.box(x+1.5,9.5,24,2,3,11,p.cream)
            }
            m.box(5,9,24,32,3,2,IsoCatalogParts.metal)
            m.roundedBox(0,0,35,43,24,3,radius:2,color:p.woodLight)
            m.front(30,24.1,35.5,8,1.5,p.ink)
            m.box(7,5,38,21,1.5,12,p.ink)
            m.front(8,6.6,39,19,10,p.tealLight)
            m.box(7,7,38,21,12,1,IsoCatalogParts.metal)
        case "office-chair":
            m.cylinder(12,12,4,radius:2,height:13,color:IsoCatalogParts.metal)
            for i in 0..<5 {
                let a = Double(i) * .pi*2/5
                let x = 12+cos(a)*12, y = 12+sin(a)*12
                IsoCatalogParts.rod(&m,.init(12,12,5),.init(x,y,3),radius:1.3,color:p.ink)
                IsoCatalogParts.wheel(&m,x:x,y:y,z:2,radius:2)
            }
            m.roundedBox(0,1,17,24,23,4,radius:4,color:p.ink)
            m.roundedBox(1,0,23,22,4,19,radius:4,color:p.blue)
            for x in [0.0,22] {
                m.box(x,8,20,2,3,7,IsoCatalogParts.metal)
                m.roundedBox(x-1,6,27,4,15,2,radius:1,color:p.ink)
            }
        case "drafting-table":
            for x in [3.0,36] {
                IsoCatalogParts.rod(&m,.init(x,1,0),.init(x,11,25),radius:2,color:p.wood)
                IsoCatalogParts.rod(&m,.init(x,23,0),.init(x,11,25),radius:2,color:p.wood)
            }
            m.face([.init(0,0,35),.init(41,0,35),.init(41,26,25),.init(0,26,25)],p.woodLight)
            m.face([.init(5,4,33.6),.init(34,4,33.6),.init(34,21,27.1),.init(5,21,27.1)],p.cream)
            IsoCatalogParts.rod(&m,.init(7,8,32.3),.init(29,17,28.8),radius:0.4,color:p.blue)
            m.box(0,25,24,41,2,2,p.wood)
            m.cylinder(35,21,27,radius:1,height:1,color:p.coral)
        case "filing-cabinet":
            IsoCatalogParts.cabinet(&m,width:23,depth:21,height:42,color:IsoCatalogParts.metal)
            for z in [6.0,18,30] {
                m.front(2,21.1,z,19,10,0xBCCBC7)
                m.box(8,21.2,z+6,6,1,1,p.ink)
                m.front(7,21.2,z+2,8,2,p.cream)
            }
        case "wall-bookcase":
            IsoCatalogParts.shelf(&m,width:42,depth:9,height:30,levels:3,color:p.cream,back:true)
            IsoCatalogParts.books(&m,x:3,y:2,z:4,count:9)
            IsoCatalogParts.books(&m,x:21,y:2,z:17,count:5)
            IsoCatalogParts.plant(&m,x:9,y:4,z:17,size:0.5)
        case "ladder-bookcase":
            for x in [0.0,22] {
                IsoCatalogParts.rod(&m,.init(x,22,0),.init(x,2,48),radius:1.5,color:p.wood)
                IsoCatalogParts.rod(&m,.init(x,0,0),.init(x,2,48),radius:1.5,color:p.wood)
            }
            for row in 0..<4 {
                let z = 4+Double(row)*13, depth = 20-Double(row)*4
                m.box(0,1,z,24,depth,2,p.woodLight)
                if row < 3 { IsoCatalogParts.books(&m,x:3,y:2,z:z+2,count:row == 0 ? 5 : 3) }
            }
        case "printer":
            m.roundedBox(0,0,0,29,22,12,radius:2,color:p.cream)
            m.box(1,1,12,27,16,3,p.ink)
            m.box(2,2,15,25,14,1,p.cream)
            m.front(3,22.1,3,23,4,p.ink)
            m.box(4,18,3,21,12,0.8,p.cream)
            m.top(7,23,3.9,15,0.7,p.blue)
            m.box(5,1,16,19,1,12,p.cream)
            m.front(19,22.2,9,5,2,p.teal)
        case "floor-globe":
            m.cylinder(13,12,0,radius:11,height:2,color:p.wood)
            m.cylinder(13,12,2,radius:2,height:22,color:p.wood)
            IsoCatalogParts.ellipsoid(&m,center:.init(13,12,36),radii:.init(12,12,12),color:p.blue)
            // 陆地嵌在球面附近，底座和弧形支架仍保持独立剪影。
            m.profile([(8,39),(10,45),(15,44),(18,39),(14,36),(11,36)],y:23,depth:0,color:p.greenLight)
            for i in 0..<12 {
                let a = -Double.pi/2+Double(i) * .pi/12
                let b = a + .pi/12
                IsoCatalogParts.rod(&m,.init(13+cos(a)*15,12,36+sin(a)*15),
                                    .init(13+cos(b)*15,12,36+sin(b)*15),radius:0.9,color:p.yellow)
            }
        case "easel":
            for x in [1.0,25] { IsoCatalogParts.rod(&m,.init(x,19,0),.init(13,4,51),radius:1.5,color:p.wood) }
            IsoCatalogParts.rod(&m,.init(13,-8,0),.init(13,4,48),radius:1.5,color:p.wood)
            m.box(0,8,16,27,4,2,p.woodLight)
            m.box(1,6,18,25,2,28,p.cream)
            m.front(3,8.1,20,21,24,0x9DCCD3)
            m.profile([(3,20),(3,28),(10,35),(18,24),(24,30),(24,20)],y:8.2,depth:0,color:p.green)
            IsoHouseholdDetails.disc(&m,x:18,y:8.3,z:39,radius:3,color:p.yellow)
        case "piano":
            m.box(0,0,3,44,14,38,p.woodDark)
            m.box(-1,-1,41,46,16,2,p.wood)
            m.box(1,12,22,42,13,3,p.ink)
            for i in 0..<18 {
                m.box(2+Double(i)*2.2,14,25,2,10,1,p.cream)
                if i%7 != 2 && i%7 != 6 { m.box(3.5+Double(i)*2.2,14,26,1,6,1.5,p.ink) }
            }
            for x in [2.0,39] { m.box(x,19,0,3,4,22,p.woodDark) }
            for x in [18.0,23,28] { m.box(x,16,2,1.8,6,1,p.yellow) }
            m.front(4,14.1,31,36,7,p.wood)
        case "sewing-machine":
            m.roundedBox(0,0,0,29,19,3,radius:2,color:p.cream)
            m.roundedBox(18,3,3,9,12,20,radius:2,color:p.teal)
            m.roundedBox(4,3,19,22,9,5,radius:2,color:p.tealLight)
            m.box(4,4,12,5,7,8,p.teal)
            m.box(6,8,5,0.8,0.8,8,IsoCatalogParts.metal)
            m.top(3,9,3.1,12,7,p.coral)
            IsoHouseholdDetails.disc(&m,x:24,y:15.1,z:13,radius:3.5,color:p.cream,depth:1)
            m.cylinder(22,7,24,radius:1.4,height:5,color:p.coral)
        default: return false
        }
        return true
    }
}
