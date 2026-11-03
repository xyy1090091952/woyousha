import Foundation

nonisolated enum IsoLivingFurniture {
    private static let p = PixelPalette.self
    static func build(_ id: String, into m: inout IsoMesh) -> Bool {
        switch id {
        case "sectional-sofa":
            // L 型只在真实底座下放支撑腿，右前角的空缺处不能出现悬空腿。
            for (x,y) in [(2.0,2.0),(42.0,2.0),(42.0,20.0),(2.0,38.0),(18.0,38.0)] {
                m.box(x,y,0,2.5,2.5,5,p.woodDark)
            }
            m.roundedBox(0,0,4,47,24,9,radius:3,color:p.teal)
            m.roundedBox(0,18,4,23,24,9,radius:3,color:p.teal)
            m.roundedBox(0,0,13,47,6,20,radius:3,color:p.teal)
            m.roundedBox(0,5,13,5,37,13,radius:2,color:p.teal)
            m.roundedBox(42,4,13,5,20,13,radius:2,color:p.teal)
            for x in [6.0,25] { m.roundedBox(x,7,13,17,16,5,radius:2,color:p.tealLight) }
            m.roundedBox(6,24,13,17,17,5,radius:2,color:p.tealLight)
            m.roundedBox(28,7,18,9,4,9,radius:2,color:p.yellow)
        case "recliner":
            for x in [2.0,20] { for y in [12.0,30] { m.box(x,y,0,2.5,2.5,9,p.woodDark) } }
            m.roundedBox(0,10,8,25,24,6,radius:3,color:p.blue)
            // 斜靠背和抬起的脚托，与普通扶手椅的剪影区分。
            m.sideProfile([(13,12),(2,34),(2,38),(13,16)],x:1,width:23,color:p.blue)
            m.box(0,12,14,4,20,9,p.blue)
            m.box(21,12,14,4,20,9,p.blue)
            m.sideProfile([(30,11),(46,7),(46,10),(30,14)],x:3,width:19,color:p.tealLight)
            // 支撑杆从椅架连到脚托底面，抬起的脚托不会成为悬空薄片。
            for x in [6.0,19] {
                IsoCatalogParts.rod(&m,.init(x,27,8),.init(x,40,8.5),radius:0.8,color:p.woodDark)
            }
        case "rocking-chair":
            IsoCatalogParts.chair(&m,width:22,depth:25,seat:15,back:39,color:p.woodLight)
            for x in [1.0,19] {
                m.sideProfile([(-3,4),(8,0),(24,0),(34,5),
                               (33,7),(23,2),(9,2),(-2,6)],x:x,width:2,color:p.woodDark)
                m.box(x,4,25,2,23,2,p.wood)
                m.box(x,22,18,2,2,8,p.wood)
            }
            for x in [5.0,10,15] { m.front(x,3.1,30,1,7,p.woodDark) }
        case "beanbag":
            IsoCatalogParts.ellipsoid(&m,center:.init(16,15,10),radii:.init(17,16,11),color:p.purple)
            IsoCatalogParts.ellipsoid(&m,center:.init(15,6,20),radii:.init(13,8,15),color:p.purple)
            m.roundedBox(5,12,18,22,16,3,radius:6,color:0xB799C8)
        case "ottoman":
            IsoHouseholdDetails.feet(&m,width:25,depth:21,height:6)
            m.roundedBox(0,0,5,25,21,10,radius:4,color:p.teal)
            m.roundedBox(-0.5,-0.5,14,26,22,4,radius:4,color:p.tealLight)
            for x in [7.0,17] { for y in [6.0,14] { m.top(x,y,18.1,1,1,p.teal) } }
        case "low-stool":
            for x in [3.0,15] {
                IsoCatalogParts.rod(&m,.init(x,3,0),.init(x,5,12),radius:1.7,color:p.wood)
                IsoCatalogParts.rod(&m,.init(x,16,0),.init(x,13,12),radius:1.7,color:p.wood)
            }
            m.roundedBox(0,0,12,21,20,3,radius:4,color:p.yellow)
            m.top(5,4,15.1,11,1,p.wood)
        case "round-coffee-table":
            roundTable(&m,x:20,y:20,radius:21,height:15,color:p.woodLight)
            m.cylinder(20,20,5,radius:15,height:1.5,color:p.wood)
            IsometricFurniture.mug(&m,x:23,y:17,z:17.5)
        case "nesting-tables":
            roundTable(&m,x:14,y:13,radius:14,height:19,color:p.woodLight)
            roundTable(&m,x:36,y:19,radius:11,height:11,color:p.cream)
        case "console-table":
            IsoCatalogParts.table(&m,width:43,depth:13,height:27)
            m.box(1,1,20,41,11,6,p.wood)
            for x in [3.0,24] { IsoHouseholdDetails.drawer(&m,x:x,y:12.1,z:21,width:16,height:4) }
            IsoCatalogParts.plant(&m,x:34,y:5,z:29.5,size:0.8)
            m.cylinder(12,6,29.5,radius:5,height:0.7,color:p.teal)
        case "fireplace":
            m.box(0,0,0,42,16,4,p.cream)
            m.box(0,0,4,8,14,31,p.coral)
            m.box(34,0,4,8,14,31,p.coral)
            m.box(0,0,29,42,14,7,p.coral)
            m.box(-2,-1,36,46,18,3,p.cream)
            m.front(8,2,4,26,25,p.ink)
            for z in [8.0,16,24,32] {
                m.front(1,14.1,z,6,0.5,p.cream)
                m.front(35,14.1,z,6,0.5,p.cream)
            }
            IsoCatalogParts.rod(&m,.init(12,10,6),.init(30,10,6),radius:2,color:p.woodDark)
            for x in [15.0,23,28] {
                m.profile([(x-3,7),(x-1,15),(x+1,12),(x+2,20),(x+4,7)],y:8,depth:0.7,color:p.yellow)
            }
        case "room-divider":
            for (i,x) in [0.0,16,32].enumerated() {
                let y = i == 1 ? 4.0 : 0
                m.box(x,y,2,15,2,45,p.woodDark)
                m.front(x+1,y+2.1,5,13,40,p.cream)
                for z in [16.0,30,44] { m.front(x+1,y+2.2,z,13,1,p.wood) }
                m.box(x,y,0,2,2,48,p.wood)
                m.box(x+13,y,0,2,2,48,p.wood)
            }
        case "bar-cart":
            for x in [2.0,23] { for y in [1.0,16] { IsoCatalogParts.wheel(&m,x:x,y:y,z:3) } }
            for x in [1.0,24] { for y in [1.0,17] { m.box(x,y,5,1.5,1.5,29,p.woodDark) } }
            for z in [7.0,25] { m.box(0,0,z,27,20,2,p.woodLight) }
            m.box(24,0,34,2,20,2,p.wood)
            for x in [6.0,13] {
                m.cylinder(x,6,9,radius:2.2,height:9,color:p.green)
                m.cylinder(x,6,18,radius:1,height:3,color:p.green)
            }
            IsometricFurniture.mug(&m,x:7,y:7,z:27)
            m.cylinder(18,9,27,radius:3,height:0.6,color:p.coral)
        default: return false
        }
        return true
    }

    static func roundTable(_ m: inout IsoMesh, x:Double, y:Double, radius:Double, height:Double, color:UInt32) {
        for angle in [0.4,2.5,4.6] {
            let dx = cos(angle)*radius*0.65, dy = sin(angle)*radius*0.65
            IsoCatalogParts.rod(&m,.init(x+dx,y+dy,0),.init(x+dx*0.8,y+dy*0.8,height),radius:1.5,color:p.woodDark)
        }
        m.cylinder(x,y,height,radius:radius,height:2.5,color:color,sides:24)
    }
}
