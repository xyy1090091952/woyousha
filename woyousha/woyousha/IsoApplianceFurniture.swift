import Foundation

nonisolated enum IsoApplianceFurniture {
    private static let p = PixelPalette.self
    static func build(_ id: String, into m: inout IsoMesh) -> Bool {
        switch id {
        case "tower-fan":
            m.cylinder(10,10,0,radius:10,height:2,color:p.ink)
            m.roundedBox(5,5,2,10,10,46,radius:4,color:p.cream)
            m.front(7,15.1,7,6,34,p.ink)
            for z in stride(from:8.0,through:40,by:3) { m.front(7,15.2,z,6,0.7,IsoCatalogParts.metal) }
            m.top(8,8,48.1,4,3,p.teal)
        case "pedestal-fan":
            fan(&m,center:.init(13,8,37),radius:13,stand:25)
        case "desk-fan":
            fan(&m,center:.init(11,8,19),radius:10,stand:9)
        case "space-heater":
            m.roundedBox(0,0,3,32,10,24,radius:3,color:p.cream)
            m.front(3,10.1,6,26,17,p.ink)
            for x in [8.0,16,24] { m.front(x,10.2,8,2,13,p.coral) }
            for z in stride(from:7.0,through:22,by:3) { m.front(4,10.3,z,24,0.6,IsoCatalogParts.metal) }
            for x in [3.0,25] { m.box(x,-2,0,4,15,3,p.ink) }
            m.box(24,2,27,3,3,1,p.teal)
        case "air-purifier":
            m.roundedBox(0,0,0,22,20,33,radius:4,color:p.cream)
            m.front(3,20.1,3,16,22,0xBED3CF)
            for x in stride(from:4.0,through:18,by:3) {
                for z in stride(from:5.0,through:23,by:3) { m.front(x,20.2,z,0.8,0.8,p.woodDark) }
            }
            m.top(3,3,33.1,16,13,p.ink)
            for y in [5.0,8,11,14] { m.top(4,y,33.2,14,0.7,IsoCatalogParts.metal) }
            m.front(9,20.2,28,5,2,p.teal)
        case "humidifier":
            m.cylinder(11,11,0,radius:11,height:3,color:p.woodLight)
            m.cylinder(11,11,3,radius:11,height:16,color:0xA2CDD0,topRadius:8,sides:20)
            m.cylinder(11,11,19,radius:8,height:3,color:p.cream,topRadius:4)
            m.cylinder(11,11,22,radius:3,height:1,color:p.ink)
            m.front(8,21.1,6,6,3,p.teal)
            m.front(15,20.1,9,1,6,p.cream)
        case "robot-vacuum":
            m.cylinder(15,15,0,radius:15,height:6,color:p.ink,sides:24)
            m.cylinder(15,15,6,radius:14,height:1.5,color:p.cream,sides:24)
            m.cylinder(15,15,7.5,radius:4,height:2.5,color:p.teal)
            m.top(9,22,7.6,9,1.2,p.ink)
            for i in 0..<3 {
                let a = Double(i) * .pi*2/3
                IsoCatalogParts.rod(&m,.init(24,23,1),.init(24+cos(a)*8,23+sin(a)*8,1),radius:0.6,color:p.woodDark)
            }
        case "water-dispenser":
            m.roundedBox(1,1,0,22,18,32,radius:2,color:p.cream)
            m.front(4,19.1,18,16,10,p.ink)
            for (x,color) in [(8.0,p.blue),(16.0,p.coral)] { m.box(x,18,24,2,3,2,color) }
            m.box(4,16,17,16,6,1,p.woodLight)
            m.cylinder(12,10,32,radius:4,height:5,color:p.teal)
            m.cylinder(12,10,37,radius:8,height:17,color:0x82BCD0,topRadius:7)
            for z in [39.0,50] { m.cylinder(12,10,z,radius:8.2,height:0.6,color:0xAFD9DD) }
            m.front(4,19.1,3,16,12,0xC4D8CB)
        case "projector":
            m.roundedBox(0,0,2,28,21,10,radius:3,color:p.cream)
            IsoHouseholdDetails.disc(&m,x:9,y:21.1,z:7,radius:4.5,color:p.ink,depth:1)
            IsoHouseholdDetails.disc(&m,x:9,y:22.2,z:7,radius:3,color:p.blue)
            IsoHouseholdDetails.disc(&m,x:8,y:22.3,z:8,radius:1,color:0xD8EAE7)
            for x in [19.0,22,25] { m.front(x,21.1,4,1,5,IsoCatalogParts.metal) }
            m.top(20,5,12.1,4,3,p.teal)
            for x in [3.0,23] { m.box(x,3,0,2,2,2,p.ink) }
        case "floor-speakers":
            for x in [0.0,28] {
                m.box(x,0,0,18,16,40,p.woodDark)
                m.front(x+1,16.1,2,16,36,p.ink)
                for (z,r) in [(11.0,6.0),(27.0,4.5),(35.0,1.8)] {
                    IsoHouseholdDetails.disc(&m,x:x+9,y:16.2,z:z,radius:r,color:IsoCatalogParts.metal)
                    IsoHouseholdDetails.disc(&m,x:x+9,y:16.3,z:z,radius:r*0.7,color:p.ink)
                    IsoHouseholdDetails.disc(&m,x:x+9,y:16.4,z:z,radius:r*0.25,color:p.wood)
                }
            }
        default: return false
        }
        return true
    }

    private static func fan(_ m: inout IsoMesh, center:IsoPoint, radius:Double, stand:Double) {
        m.cylinder(center.x,center.y,0,radius:radius*0.8,height:2,color:p.cream)
        m.cylinder(center.x,center.y,2,radius:1.5,height:stand,color:IsoCatalogParts.metal)
        IsoHouseholdDetails.disc(&m,x:center.x,y:center.y,z:center.z,radius:radius,color:p.ink,depth:2)
        IsoHouseholdDetails.disc(&m,x:center.x,y:center.y+2.1,z:center.z,radius:radius-1,color:0xBACDC9)
        for i in 0..<3 {
            let a = Double(i) * .pi*2/3
            m.face([.init(center.x,center.y+2.2,center.z),
                    .init(center.x+cos(a)*radius*0.7,center.y+2.2,center.z+sin(a)*radius*0.7),
                    .init(center.x+cos(a+0.7)*radius*0.8,center.y+2.2,center.z+sin(a+0.7)*radius*0.8)],p.teal)
        }
        for i in 0..<12 {
            let a = Double(i) * .pi/6
            IsoCatalogParts.rod(&m,.init(center.x,center.y+2.3,center.z),
                                .init(center.x+cos(a)*(radius-1),center.y+2.3,center.z+sin(a)*(radius-1)),
                                radius:0.3,color:p.cream)
        }
        IsoHouseholdDetails.disc(&m,x:center.x,y:center.y+2.7,z:center.z,radius:2,color:p.woodLight)
    }
}
