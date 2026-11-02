import Foundation

/// 按目录的显式分类路由。未知编号返回 nil，旧家具仍走原来的模型入口。
nonisolated enum IsometricExpandedFurniture {
    static func model(_ id: String) -> IsoMesh? {
        guard let config = FurnitureExpansionCatalog.byID[id] else { return nil }
        var m = IsoMesh()
        let found: Bool
        switch config.category {
        case .bedroom: found = IsoBedroomFurniture.build(id, into: &m)
        case .livingRoom: found = IsoLivingFurniture.build(id, into: &m)
        case .study: found = IsoStudyFurniture.build(id, into: &m)
        case .kitchen: found = IsoKitchenFurniture.build(id, into: &m)
        case .bathroom: found = IsoBathroomFurniture.build(id, into: &m)
        case .storage: found = IsoStorageFurniture.build(id, into: &m)
        case .appliances: found = IsoApplianceFurniture.build(id, into: &m)
        case .childrenAndPets: found = IsoKidsFurniture.build(id, into: &m)
        case .outdoor: found = IsoOutdoorFurniture.build(id, into: &m)
        case .lighting: found = false
        }
        return found ? m : nil
    }
}

/// 复用的是结构部件；每件家具的剪影、组合与细节由各分类文件单独定义。
nonisolated enum IsoCatalogParts {
    static let wood = PixelPalette.wood
    static let light = PixelPalette.woodLight
    static let cream = PixelPalette.cream
    static let metal: UInt32 = 0x8DA6A7
    static let dark = PixelPalette.ink

    /// 任意方向的圆杆。斜腿、梯子、车架都用真实空间连接，镜像时不会断开。
    static func rod(_ m: inout IsoMesh, _ a: IsoPoint, _ b: IsoPoint,
                    radius: Double = 1, color: UInt32 = wood) {
        let dx = b.x-a.x, dy = b.y-a.y, dz = b.z-a.z
        let length = sqrt(dx*dx+dy*dy+dz*dz)
        guard length > 0.001 else { return }
        let nx = dx/length, ny = dy/length, nz = dz/length
        let horizontal = hypot(nx, ny)
        let u = horizontal > 0.001 ? IsoPoint(-ny/horizontal, nx/horizontal, 0) : IsoPoint(1,0,0)
        let v = IsoPoint(ny*u.z-nz*u.y, nz*u.x-nx*u.z, nx*u.y-ny*u.x)
        func ring(_ p: IsoPoint) -> [IsoPoint] {
            (0..<8).map {
                let angle = Double($0) * .pi/4
                let c = cos(angle)*radius, s = sin(angle)*radius
                return .init(p.x+u.x*c+v.x*s, p.y+u.y*c+v.y*s, p.z+u.z*c+v.z*s)
            }
        }
        let first = ring(a), last = ring(b)
        for i in 0..<8 {
            let j = (i+1)%8
            m.face([first[i],first[j],last[j],last[i]], IsoColor.shade(color, 0.83+Double(i%4)*0.08))
        }
        m.face(last, IsoColor.shade(color, 1.15))
        m.face(first, IsoColor.shade(color, 0.8))
    }

    /// 椭球用于豆袋、地球仪、宠物玩具与水壶等曲面主体。
    static func ellipsoid(_ m: inout IsoMesh, center: IsoPoint, radii: IsoPoint, color: UInt32) {
        let segments = 16, levels = 8
        func point(_ row: Int, _ col: Int) -> IsoPoint {
            let latitude = -Double.pi/2+Double(row) * .pi/Double(levels)
            let angle = Double(col) * .pi*2/Double(segments)
            return .init(center.x+radii.x*cos(latitude)*cos(angle),
                         center.y+radii.y*cos(latitude)*sin(angle), center.z+radii.z*sin(latitude))
        }
        for row in 0..<levels {
            for col in 0..<segments {
                let light = 0.86+0.10*sin(Double(col) * .pi*2/Double(segments))+Double(row)*0.025
                m.face([point(row,col),point(row,col+1),point(row+1,col+1),point(row+1,col)],
                       IsoColor.shade(color, light))
            }
        }
    }

    static func table(_ m: inout IsoMesh, width: Double, depth: Double, height: Double,
                      color: UInt32 = light) {
        IsoHouseholdDetails.feet(&m, width: width, depth: depth, height: height)
        m.roundedBox(-1,-1,height,width+2,depth+2,2.5,radius:2,color:color)
    }

    static func shelf(_ m: inout IsoMesh, width: Double, depth: Double, height: Double,
                      levels: Int, color: UInt32 = wood, back: Bool = false) {
        if back { m.box(0,0,2,width,1.5,height,color) }
        for x in [0.0,width-2] { m.box(x,0,0,2,depth,height,color) }
        for row in 0..<levels {
            m.box(0,0,2+Double(row)*(height-4)/Double(max(1,levels-1)),width,depth,1.8,light)
        }
    }

    static func books(_ m: inout IsoMesh, x: Double, y: Double, z: Double, count: Int = 5) {
        for i in 0..<count {
            let h = 7+Double(i%3)*2
            m.box(x+Double(i)*3.4,y,z,2.5,7,h,PixelPalette.bookColors[i%PixelPalette.bookColors.count])
            m.front(x+Double(i)*3.4+0.5,y+7.1,z+2,1.5,0.6,cream)
        }
    }

    static func cabinet(_ m: inout IsoMesh, width: Double, depth: Double, height: Double,
                        color: UInt32 = wood) {
        IsoHouseholdDetails.feet(&m, width: width, depth: depth, height: 4)
        m.roundedBox(0,0,3,width,depth,height-3,radius:1.5,color:color)
        m.box(-0.6,-0.6,height,width+1.2,depth+1.2,1.6,light)
    }

    static func chair(_ m: inout IsoMesh, width: Double = 20, depth: Double = 20,
                      seat: Double = 17, back: Double = 34, color: UInt32 = PixelPalette.teal) {
        IsoHouseholdDetails.feet(&m,width:width,depth:depth,height:seat)
        m.roundedBox(0,0,seat,width,depth,3,radius:2,color:color)
        for x in [1.0,width-3] { m.box(x,0,seat,2,2,back-seat,wood) }
        m.roundedBox(0,0,back-10,width,3,10,radius:2,color:color)
    }

    static func wheel(_ m: inout IsoMesh, x: Double, y: Double, z: Double, radius: Double = 3) {
        IsoHouseholdDetails.disc(&m,x:x,y:y,z:z,radius:radius,color:dark,depth:2)
        IsoHouseholdDetails.disc(&m,x:x,y:y+2.1,z:z,radius:radius*0.4,color:metal)
    }

    static func plant(_ m: inout IsoMesh, x: Double, y: Double, z: Double, size: Double = 1) {
        m.cylinder(x,y,z,radius:3*size,height:5*size,color:PixelPalette.coral,topRadius:4*size)
        for i in 0..<4 {
            let a = Double(i) * .pi/2
            ellipsoid(&m,center:.init(x+cos(a)*2*size,y+sin(a)*2*size,z+8*size),
                      radii:.init(2*size,2*size,4*size),color:i%2 == 0 ? PixelPalette.green : PixelPalette.greenLight)
        }
    }
}
