import Foundation

nonisolated enum IsoBedroomFurniture {
    private static let p = PixelPalette.self

    static func build(_ id: String, into m: inout IsoMesh) -> Bool {
        switch id {
        case "single-bed":
            bed(&m, width:25, z:5, blanket:p.blue)
            m.box(0,0,4,25,3,24,p.wood)
            m.front(2,3.1,18,21,6,p.woodLight)
        case "bunk-bed":
            bed(&m,width:27,z:5,blanket:p.coral)
            bed(&m,width:27,z:37,blanket:p.teal)
            posts(&m,height:57)
            // 上层护栏与可攀爬的侧梯。
            for x in [0.0,25] { m.box(x,4,51,2,36,2,p.woodLight) }
            ladder(&m,x:29,y:35,height:47)
        case "loft-bed":
            bed(&m,width:29,z:39,blanket:p.purple)
            posts(&m,height:58,width:29)
            m.box(2,2,22,25,18,2,p.woodLight)
            m.box(20,3,2,7,14,19,p.wood)
            IsoHouseholdDetails.drawer(&m,x:21,y:17.1,z:9,width:5,height:8)
            IsoCatalogParts.books(&m,x:3,y:4,z:24,count:4)
            ladder(&m,x:31,y:34,height:50)
        case "tatami-bed":
            m.roundedBox(0,0,0,46,48,7,radius:2,color:p.wood)
            for x in [1.0,24] {
                m.box(x,1,7,21,46,1,p.greenLight)
                for y in stride(from:3.0,through:45,by:3) { m.top(x,y,8.1,21,0.5,0x91B067) }
            }
            m.roundedBox(5,6,8,36,38,3,radius:3,color:p.cream)
            m.roundedBox(4,21,11,38,23,3,radius:2,color:p.coral)
            m.roundedBox(9,8,11,25,9,4,radius:2,color:p.cream)
        case "crib":
            bed(&m,width:25,z:9,blanket:p.yellow,length:38)
            for x in [0.0,24] {
                for y in stride(from:0.0,through:36,by:6) { m.box(x,y,9,1.3,1.3,22,p.cream) }
                m.box(x,0,31,1.5,38,2,p.woodLight)
            }
            for y in [0.0,37] {
                for x in stride(from:0.0,through:24,by:6) { m.box(x,y,9,1.3,1.3,22,p.cream) }
                m.box(0,y,31,25,1.5,2,p.woodLight)
            }
        case "daybed":
            IsoCatalogParts.table(&m,width:45,depth:22,height:8,color:p.wood)
            m.roundedBox(1,1,10,43,20,5,radius:3,color:p.coral)
            m.roundedBox(0,0,15,45,4,13,radius:2,color:p.coral)
            m.roundedBox(0,0,14,5,22,17,radius:2,color:p.coral)
            m.roundedBox(6,7,15,10,12,4,radius:3,color:p.cream)
        case "bedroom-bench":
            IsoCatalogParts.table(&m,width:40,depth:15,height:12)
            m.roundedBox(0,0,14,40,15,4,radius:3,color:p.blue)
            for x in [8.0,20,32] { m.top(x,7,18.1,1,1,p.cream) }
        case "blanket-chest":
            IsoCatalogParts.cabinet(&m,width:37,depth:23,height:19)
            m.front(3,23.1,5,31,11,p.woodDark)
            m.front(4,23.2,6,29,9,p.wood)
            m.box(15,23.3,12,7,1,2,p.yellow)
            m.roundedBox(6,5,21,23,13,3,radius:1,color:p.cream)
            m.roundedBox(7,6,24,21,11,2,radius:1,color:p.teal)
        case "fabric-wardrobe":
            m.box(0,0,3,39,19,48,p.blue)
            for x in [0.0,37] { m.box(x,0,0,2,20,54,p.woodLight) }
            m.box(0,0,53,39,20,2,p.woodLight)
            m.front(2,19.1,5,35,46,0xA3C6C7)
            m.front(19,19.2,6,1,44,p.ink)
            m.front(4,19.2,6,0.7,44,p.cream)
            m.box(18,19.3,28,3,1,4,p.yellow)
        case "sliding-wardrobe":
            IsoCatalogParts.cabinet(&m,width:44,depth:22,height:55,color:p.cream)
            for x in [2.0,23] {
                m.front(x,22.1,6,19,46,p.woodLight)
                m.front(x+1,22.2,7,17,44,p.wood)
                m.front(x+14,22.3,25,1.5,12,p.ink)
            }
            for z in [4.0,53] { m.box(1,22.2,z,42,1,1,p.ink) }
        case "clothes-rack":
            for x in [2.0,36] {
                m.box(x,0,0,3,22,2,p.ink)
                IsoCatalogParts.rod(&m,.init(x+1,10,2),.init(x+1,10,48),color:p.woodLight)
            }
            IsoCatalogParts.rod(&m,.init(3,10,48),.init(37,10,48),radius:1.5,color:p.woodLight)
            for (i,x) in [8.0,18,28].enumerated() {
                m.profile([(x-4,40),(x,45),(x+4,40)],y:9,depth:1,color:p.cream)
                m.profile([(x-5,38),(x-3,40),(x+3,40),(x+5,38),(x+4,22),(x-4,22)],
                          y:9,depth:2,color:p.bookColors[i])
            }
        case "bedside-shelf":
            IsoCatalogParts.shelf(&m,width:19,depth:15,height:27,levels:3,color:p.cream)
            IsoCatalogParts.books(&m,x:3,y:4,z:4,count:3)
            m.roundedBox(3,4,15,12,8,3,radius:1,color:p.coral)
            IsoCatalogParts.plant(&m,x:9,y:7,z:27,size:0.65)
        default: return false
        }
        return true
    }

    private static func bed(_ m: inout IsoMesh, width:Double, z:Double, blanket:UInt32, length:Double = 46) {
        if z < 10 { IsoHouseholdDetails.feet(&m,width:width,depth:length,height:z) }
        m.box(0,0,z,width,length,4,p.wood)
        m.roundedBox(1,2,z+4,width-2,length-3,4,radius:2,color:p.cream)
        m.roundedBox(1,18,z+7,width-2,length-19,3,radius:2,color:blanket)
        m.roundedBox(3,4,z+8,width-6,9,3,radius:2,color:p.cream)
        m.top(2,19,z+10.1,width-4,3,IsoColor.shade(blanket,1.25))
    }
    private static func posts(_ m: inout IsoMesh, height:Double, width:Double = 27) {
        for x in [0.0,width-2] { for y in [0.0,44] { m.box(x,y,0,2,2,height,p.woodLight) } }
        for z in [25.0,height-2] { m.box(0,0,z,width,2,2,p.wood) }
    }
    private static func ladder(_ m: inout IsoMesh, x:Double, y:Double, height:Double) {
        for dx in [0.0,9] { IsoCatalogParts.rod(&m,.init(x+dx,y+7,0),.init(x+dx,y,height),color:p.woodLight) }
        for z in stride(from:6.0,through:height-2,by:8) {
            IsoCatalogParts.rod(&m,.init(x,y+7*(1-z/height),z),.init(x+9,y+7*(1-z/height),z),color:p.woodLight)
        }
    }
}
