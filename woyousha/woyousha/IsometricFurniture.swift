import Foundation

/// 家具由可复用的实体与面上细节组成。颜色、尺寸、摆放都在模型坐标里定义。
nonisolated enum IsometricFurniture {
    static let wood = PixelPalette.wood
    static let cream = PixelPalette.cream
    static let dark = PixelPalette.ink

    static func model(_ id: String) -> IsoMesh {
        var m=IsoMesh()
        switch id {
        case "bingxiang", "bingxiang2": fridge(&m, mint: id=="bingxiang2")
        case "yigui": wardrobe(&m)
        case "shafa", "shafayi": sofa(&m, single:id=="shafayi")
        case "fanzhuo": table(&m)
        case "bijia", "shujia": bookshelf(&m, wide:id=="shujia")
        case "dianshigui", "dianshigui2", "chuwei": cabinet(&m, kitchen:id=="chuwei", wide:id=="dianshigui2")
        case "beibao": backpack(&m)
        case "beikedeng": shellLamp(&m)
        case "floor-lamp": lamp(&m)
        case "lajitong": bin(&m)
        case "chuanghu": window(&m, mirror:false)
        case "mirror": mirrorCabinet(&m)
        case "wall-panel": wallPanel(&m)
        case "mucai": logs(&m)
        case "xichengqi": vacuum(&m)
        case "dianshi": television(&m)
        case "cart": cart(&m)
        default: carton(&m)
        }
        return m
    }

    private static func feet(_ m: inout IsoMesh, w: Double, d: Double, height: Double = 4) {
        for x in [2.0,w-5] { for y in [2.0,d-5] { m.box(x,y,0,3,3,height,dark) } }
    }

    private static func fridge(_ m: inout IsoMesh, mint: Bool) {
        let color: UInt32 = mint ? PixelPalette.tealLight : PixelPalette.blue
        if mint {
            // 大冰箱是双门宽机身，不只是给小冰箱换个颜色。
            feet(&m,w:34,d:24)
            m.roundedBox(0,0,3,34,24,54,radius:3,color:color)
            for x in [1.0,18] {
                m.front(x,24.1,5,15,50,IsoColor.shade(color,1.1))
                m.front(x+1,24.15,7,0.8,44,0xAFDFD0)
            }
            m.front(16.7,24.18,5,0.8,51,dark)
            m.box(14.5,24.3,25,1.1,1.2,14,cream)
            m.box(18.3,24.3,25,1.1,1.2,14,cream)
            m.front(5,24.2,31,7,13,0x286C70)
            m.front(6,24.25,40,5,2,0xAADDD3)
            m.front(24,24.2,46,5,5,PixelPalette.yellow)
            return
        }
        feet(&m,w:25,d:21)
        m.roundedBox(0,0,3,25,21,49,radius:3,color:color)
        m.front(1,21.08,5,23,29,IsoColor.shade(color,1.08))
        m.front(1,21.08,35,23,15,IsoColor.shade(color,1.13))
        m.front(1,21.18,33.5,23,1.2,dark)
        m.box(2,21.3,29,7,1,1.5,0xD2D3C3)
        m.box(2,21.3,36,7,1,1.5,0xD2D3C3)
        // 冰箱贴和小便签，明确跟随门面倾斜。
        m.front(16,21.2,39,5,7,0xE7D9A4)
        m.front(17,21.24,43,3,1,0xB57951)
        m.front(12,21.22,42,2,2,0xD39267)
        m.front(19,21.22,35,2,2,0x8FA886)
        m.front(2,21.22,7,1,19,IsoColor.shade(color,1.3))
    }

    private static func wardrobe(_ m: inout IsoMesh) {
        feet(&m,w:38,d:22)
        m.roundedBox(0,0,4,38,22,50,radius:3,color:wood)
        for x in [2.0,20] {
            m.front(x,22.08,7,16,44,0xDCAE66)
            m.front(x+1,22.12,9,14,40,0xA76837)
            m.front(x+2,22.16,10,12,38,0xCF974E)
            for line in [3.0,7,10] { m.front(x+line,22.20,11,0.5,35,0xB9803B) }
        }
        m.box(16,22.3,28,1.4,1,3,0xEBD295)
        m.box(21,22.3,28,1.4,1,3,0xEBD295)
        m.roundedBox(-1,-1,53,40,24,3,radius:2,color:PixelPalette.woodLight)
    }

    private static func sofa(_ m: inout IsoMesh, single: Bool) {
        let w: Double=single ? 25:45, d=24.0
        let fabric: UInt32=single ? PixelPalette.coral : PixelPalette.teal
        feet(&m,w:w,d:d,height:6)
        m.roundedBox(0,0,5,w,d,8,radius:3,color:0xBA8956)
        m.roundedBox(0,0,12,w,8,22,radius:3.5,color:fabric)
        m.roundedBox(0,4,12,6,20,14,radius:2.7,color:fabric)
        m.roundedBox(w-6,4,12,6,20,14,radius:2.7,color:fabric)
        let count=single ? 1:2
        let cushionW=(w-14)/Double(count)
        for i in 0..<count {
            let x=7+Double(i)*cushionW
            m.roundedBox(x,8,12,cushionW-0.6,15,6,radius:2.5,color:IsoColor.shade(fabric,1.12))
            m.roundedBox(x,7.5,19,cushionW-0.7,2.8,12,radius:1.2,color:IsoColor.shade(fabric,1.08))
            // 固定织物花纹，刷新时不会随机变化。
            for stitch in 0..<6 {
                m.top(x+2+Double(stitch)*1.2,10+Double(stitch%2)*5,18.05,0.6,0.9,
                      IsoColor.shade(fabric,1.23))
            }
        }
        // 扶手高光与坐垫缝线属于模型表面，而非画面上的水平线。
        m.roundedBox(8,10,18,8,4,8,radius:1.5,color:PixelPalette.yellow)
        m.front(10,14.05,22,1,1,0xFFF0C1)
        m.front(13,14.05,22,1,1,0xFFF0C1)
    }

    private static func table(_ m: inout IsoMesh) {
        feet(&m,w:37,d:24,height:18)
        m.roundedBox(-1,-1,18,39,26,4,radius:3,color:PixelPalette.woodLight)
        m.box(5,6,21.2,10,7,1.2,0x567777)
        m.box(6,6,22.5,10,6,0.8,0xE2D6B6)
        mug(&m,x:25,y:8,z:21.3)
    }

    private static func bookshelf(_ m: inout IsoMesh, wide: Bool) {
        let w: Double=wide ? 42:29, d=13.0, h=52.0
        m.box(0,0,1,w,2,h,0xA5916D)
        m.box(0,0,1,2.5,d,h,cream);m.box(w-2.5,0,1,2.5,d,h,cream)
        for z in [1.0,17,33,51] { m.box(0,0,z,w,d,2,cream) }
        let colors = PixelPalette.bookColors
        for row in 0..<3 {
            var x=3.0
            for i in 0..<(wide ? 11:7) {
                let width=2.0+Double(i%2)
                let height=9.0+Double((i*3+row)%5)
                let z=3.0+Double(row)*16
                m.box(x,3,z,width,8,height,colors[(i+row*2)%colors.count])
                m.front(x+0.5,11.1,z+height-3,width-0.7,0.7,0xEBDDC0)
                m.front(x+0.5,11.1,z+2,width-0.7,0.6,0xC7B38A)
                x += width+0.7
            }
        }
    }

    private static func cabinet(_ m: inout IsoMesh, kitchen: Bool, wide: Bool) {
        let w: Double=wide ? 49:38, d=19.0, h=kitchen ? 29.0:20
        feet(&m,w:w,d:d)
        m.roundedBox(0,0,3,w,d,h,radius:2.5,color:wood)
        m.roundedBox(-1,-1,h+3,w+2,d+2,2.5,radius:1,color:kitchen ? cream : PixelPalette.woodLight)
        for i in 0..<2 {
            let x=2+Double(i)*(w/2)
            m.front(x,19.09,5,w/2-4,h-2,kitchen ? PixelPalette.tealLight : 0xD9A05B)
            m.front(x+1,19.14,6,w/2-6,h-4,kitchen ? PixelPalette.teal : 0xC68743)
            m.box(x+w/2-8,19.2,h,3,1,1,0xE9D2A0)
        }
        if kitchen {
            m.top(8,4,h+5.1,17,11,0x8D958E)
            m.top(10,6,h+5.2,13,7,0x5F736F)
            m.box(26,4,h+5,1,1,9,0x8DACA5)
            m.box(23,4,h+13,4,1,1,0xB7CEC2)
            m.merge(plant(),at:.init(32,5,h+5))
        } else {
            // 电视柜包含屏幕及遥控器，与普通厨柜形成明确剪影区别。
            m.merge(model("dianshi"),at:.init((w-34)/2,2,h+5))
            m.box(w-5,14,h+5,2.5,4,1,0x414958)
        }
    }

    private static func backpack(_ m: inout IsoMesh) {
        m.roundedBox(2,1,1,18,10,24,radius:4,color:PixelPalette.coral)
        m.box(0,2,3,3,7,16,0x725140)
        // 两条肩带和弧形提手，便于在小缩略图中区分背包与纸箱。
        m.box(5,-1,2,2,2,21,0x804447); m.box(15,-1,2,2,2,21,0x804447)
        m.beveledBox(7,3,25,8,2,3,bevel:0.6,color:0x824743)
        m.box(7,3,23,1.5,2,4,0x824743); m.box(13.5,3,23,1.5,2,4,0x824743)
        m.roundedBox(5,11,3,12,2.5,9,radius:1,color:0xEFAB65)
        m.front(3,11.06,18,16,0.8,0x3F392D)
        m.box(16,11.4,15,1,0.7,3,0xE8CCA0)
        m.front(6,13.6,10,10,0.7,0xEDD099)
    }

    private static func lamp(_ m: inout IsoMesh) {
        m.cylinder(6,6,0,radius:7,height:2,color:0xC29458)
        m.box(5,5,2,2,2,30,0xAD955B)
        // 四个斜面组成灯罩，顶面/阴影与房间光照一致。
        m.face([.init(-2,14,28),.init(14,14,28),.init(11,11,43),.init(1,11,43)],0xD5BA70,outline:0x796840)
        m.face([.init(14,-2,28),.init(14,14,28),.init(11,11,43),.init(11,1,43)],0xA79257,outline:0x796840)
        m.top(1,1,43,10,10,0xE4D7A2)
        m.box(-2,-2,27,16,16,1.2,0xF2DF9C)
    }

    private static func shellLamp(_ m: inout IsoMesh) {
        m.cylinder(13,9,0,radius:10,height:2,color:0xD89A65)
        m.cylinder(13,9,2,radius:3,height:7,color:0xF0C790)
        var outline: [(Double,Double)] = [(1,9),(25,9)]
        // 扇形轮廓拥有分段凸起，像素化后呈现贝壳的波浪边。
        for i in 0...12 {
            let angle = Double(i) * .pi / 12
            let bump = i%2 == 0 ? 1.0 : 0.5
            outline.append((13 + cos(angle)*(12+bump), 9 + sin(angle)*(17+bump)))
        }
        m.profile(outline,y:7,depth:5,color:0xF4B79A)
        // 从根部向外放射的贝壳纹理，全部在同一斜面上。
        for i in 1..<6 {
            let angle = Double(i) * .pi / 6
            let endpoint = (13 + cos(angle)*11.5, 9 + sin(angle)*16)
            m.face([.init(12.7,12.2,9.5), .init(endpoint.0-0.6,12.2,endpoint.1),
                    .init(endpoint.0+0.6,12.2,endpoint.1), .init(13.3,12.2,9.5)],
                   i%2 == 0 ? 0xFBE2B9 : 0xD38A79)
        }
        m.beveledBox(7,12.3,8,12,1,2,bevel:0.3,color:0xFFE6BF)
    }

    private static func mirrorCabinet(_ m: inout IsoMesh) {
        // 门内可收纳的镜柜，有立体柜体、分开的镜门、把手与底部开放层。
        m.roundedBox(0,0,0,30,8,42,radius:2,color:PixelPalette.teal)
        m.front(2,8.1,9,26,31,0xD9BC88)
        for x in [3.0,16] {
            m.front(x,8.16,11,11,27,0x83C1C5)
            m.face([.init(x+1,8.2,29),.init(x+7,8.2,12),
                    .init(x+10,8.2,12),.init(x+3,8.2,37)],0xD5EFE7)
        }
        m.front(14.5,8.22,10,1,30,0x50797B)
        m.box(12,8.3,17,1,1,5,cream);m.box(17,8.3,17,1,1,5,cream)
        m.front(2,8.1,2,26,6,0x2E5C62)
        m.box(-1,-1,0,32,11,1.5,PixelPalette.woodLight)
        m.box(5,8.3,1.6,3,2,4,PixelPalette.coral)
        m.box(11,8.3,1.6,3,2,5,PixelPalette.blue)
        m.box(4,8.6,5,2,1,1.5,cream)
    }

    private static func wallPanel(_ m: inout IsoMesh) {
        m.box(0,0,0,45,2.5,43,PixelPalette.tealLight)
        for x in stride(from:4.0,to:45,by:6) {
            m.front(x,2.56,1,0.7,41,0x3C9291)
            m.front(x+0.8,2.6,1,0.5,41,0x93D9C1)
        }
        m.box(-1,-0.5,0,47,4,3,PixelPalette.woodDark)
        m.box(-1,-0.5,42,47,4,2,0x84C7AC)
    }

    private static func bin(_ m: inout IsoMesh) {
        m.cylinder(8,7,0,radius:8,height:24,color:PixelPalette.tealLight,topRadius:9)
        m.cylinder(8,7,24,radius:9.7,height:2,color:0xC6E2C9)
        m.cylinder(8,7,26.08,radius:7,height:0.2,color:dark)
        for x in [3.0,7,11] { m.front(x,15.3,4,0.6,16,0x5B9A93) }
    }

    private static func window(_ m: inout IsoMesh, mirror: Bool) {
        m.box(0,0,0,29,3,36,cream)
        m.front(3,3.08,3,23,30,mirror ? 0x9CAFAF:0x8FAAAC)
        m.face([.init(4,3.15,25),.init(17,3.15,4),.init(21,3.15,4),.init(4,3.15,31)],0xD9E1D3)
        if !mirror {
            m.box(13,3.2,2,2,1,32,0xE6DDC1)
            m.box(2,3.2,16,25,1,2,0xE6DDC1)
            m.box(-1,-1,0,31,7,2,wood)
        }
    }

    private static func logs(_ m: inout IsoMesh) {
        for (x,y,z) in [(0.0,0.0,0.0),(0,9,0),(5,4,8)] {
            var log = IsoMesh()
            log.cylinder(0,0,0,radius:4,height:24,color:0x9F652F,sides:10)
            log.cylinder(0,0,24.05,radius:3.3,height:0.08,color:PixelPalette.woodLight,sides:10)
            log.cylinder(0,0,24.15,radius:2,height:0.08,color:0xAD763A,sides:10)
            log.cylinder(0,0,24.25,radius:0.9,height:0.08,color:0xE6B970,sides:8)
            log.faces = log.faces.map { face in
                IsoFace(points:face.points.map { .init($0.z+x,$0.x+y+4,$0.y+z+4) },
                        color:face.color,outline:face.outline)
            }
            m.merge(log)
        }
    }

    private static func vacuum(_ m: inout IsoMesh) {
        m.box(0,0,0,20,14,4,0x695F59)
        m.box(8,3,4,2,2,31,0x9EA7A0)
        m.beveledBox(5,2,12,9,6,16,bevel:1,color:PixelPalette.coral)
        m.front(6,8.1,14,7,10,0x77C2C1)
        m.box(8,1,34,9,2,2,0x4F4942)
    }

    private static func carton(_ m: inout IsoMesh) {
        m.roundedBox(0,0,0,24,20,19,radius:2,color:0xC99655)
        m.top(10,0,19.09,4,20,0xF0D48F)
        m.front(10,20.09,9,4,10,0xF0D48F)
        m.front(3,20.12,4,7,5,0xDFD5B1)
        m.front(4,20.15,6,5,0.7,0x96825E)
        m.top(1,10,19.15,22,0.6,0x8E744E)
    }

    private static func television(_ m: inout IsoMesh) {
        m.box(0,0,6,34,5,24,0x30384D)
        m.front(2,5.1,8,30,20,0x5CAFC5)
        m.face([.init(3,5.2,9),.init(16,5.2,24),.init(27,5.2,9)],0x459669)
        m.face([.init(19,5.25,9),.init(27,5.25,19),.init(31,5.25,9)],0xCCB34D)
        m.front(26,5.3,22,3,3,0xEFE2AF)
        m.box(15,2,1,4,2,5,0x525654)
        m.box(8,-1,0,18,10,1.2,0x6E746F)
    }

    private static func cart(_ m: inout IsoMesh) {
        feet(&m,w:25,d:16,height:5)
        for z in [5.0,20] { m.box(0,0,z,25,16,2,PixelPalette.tealLight) }
        for x in [0.0,23] { m.box(x,0,5,2,2,24,0x455F57);m.box(x,14,5,2,2,24,0x455F57) }
        m.box(2,4,22,8,7,5,0xB9946B)
        m.box(13,2,7,3,10,10,0xB1A578)
        m.box(17,2,7,3,10,11,0x547175)
    }

    static func mug(_ m: inout IsoMesh, x: Double, y: Double, z: Double) {
        m.cylinder(x+2,y+2,z,radius:2.3,height:5,color:cream)
        m.cylinder(x+2,y+2,z+5.1,radius:1.8,height:0.1,color:0x66513F)
        m.box(x+4,y+1,z+1,1.5,2,3,0xCBC8B2)
    }

    static func plant() -> IsoMesh {
        var m=IsoMesh()
        m.cylinder(0,0,0,radius:3,height:5,color:PixelPalette.coral,topRadius:3.4)
        m.cylinder(0,0,4.5,radius:3.8,height:0.8,color:0xF5AC6E)
        m.box(-0.5,-0.5,5,1,1,9,0x4B633B)
        m.beveledBox(-5,-1,9,5,3,2,bevel:0.5,color:PixelPalette.green)
        m.beveledBox(0,-4,12,4,4,2,bevel:0.5,color:0x8ABC55)
        m.beveledBox(-2,-2,15,3,3,2,bevel:0.5,color:PixelPalette.greenLight)
        m.beveledBox(0,1,7,4,3,2,bevel:0.5,color:0x39885D)
        return m
    }
}
