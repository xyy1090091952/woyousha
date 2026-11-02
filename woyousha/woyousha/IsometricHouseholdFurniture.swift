import Foundation

/// 日常家具扩展。独立模型复用现有投影、光照和像素渲染，不依赖图片资源。
nonisolated enum IsometricHouseholdFurniture {
    static func model(_ id: String) -> IsoMesh? {
        var mesh = IsoMesh()
        switch id {
        case "double-bed": bed(&mesh)
        case "nightstand": nightstand(&mesh)
        case "study-desk": desk(&mesh)
        case "dining-chair": chair(&mesh)
        case "coffee-table": coffeeTable(&mesh)
        case "shoe-cabinet": shoeCabinet(&mesh)
        case "dressing-table": dressingTable(&mesh)
        case "washing-machine": washingMachine(&mesh)
        case "oven-stove": stove(&mesh)
        case "air-conditioner": airConditioner(&mesh)
        case "suitcase": suitcase(&mesh)
        default: return nil
        }
        return mesh
    }

    private static func bed(_ m: inout IsoMesh) {
        IsoHouseholdDetails.feet(&m, width: 43, depth: 49, height: 5)
        m.roundedBox(0, 0, 4, 43, 49, 7, radius: 2, color: PixelPalette.wood)
        m.roundedBox(0, -1, 4, 43, 4, 25, radius: 2, color: PixelPalette.woodLight)
        m.front(3, 3.1, 16, 37, 10, PixelPalette.wood)
        m.roundedBox(2, 4, 11, 39, 43, 6, radius: 3, color: PixelPalette.cream)
        // 两只枕头与铺到床尾的被子，让小缩略图也能辨认出双人床。
        for x in [4.0, 23] {
            m.roundedBox(x, 6, 17, 16, 10, 4, radius: 2.5, color: 0xFFF0D2)
        }
        m.roundedBox(1, 20, 15, 41, 28, 6, radius: 2, color: PixelPalette.teal)
        m.roundedBox(1, 20, 21, 41, 5, 1.5, radius: 1, color: PixelPalette.tealLight)
        for x in stride(from: 5.0, through: 37, by: 8) {
            m.top(x, 27, 21.1, 0.7, 17, 0x63B1A6)
            m.front(x, 48.1, 16, 0.7, 4, 0x5DA89D)
        }
    }

    private static func nightstand(_ m: inout IsoMesh) {
        IsoHouseholdDetails.feet(&m, width: 20, depth: 17, height: 4)
        m.roundedBox(0, 0, 3, 20, 17, 18, radius: 1.8, color: PixelPalette.wood)
        m.roundedBox(-1, -1, 21, 22, 19, 2, radius: 1, color: PixelPalette.woodLight)
        for z in [5.0, 13] {
            IsoHouseholdDetails.drawer(&m, x: 2, y: 17.1, z: z, width: 16, height: 6)
        }
        // 桌面有一只小闹钟，区分床头柜和普通大柜子。
        m.box(5, 5, 23, 9, 3, 8, PixelPalette.coral)
        IsoHouseholdDetails.disc(&m, x: 9.5, y: 8.1, z: 27, radius: 3.3, color: PixelPalette.cream)
        m.front(9.1, 8.2, 26.7, 0.6, 2.5, PixelPalette.ink)
        m.front(9.2, 8.2, 26.8, 2, 0.6, PixelPalette.ink)
        m.box(5.5, 5.5, 30, 2, 2, 1.5, PixelPalette.yellow)
        m.box(11.5, 5.5, 30, 2, 2, 1.5, PixelPalette.yellow)
    }

    private static func desk(_ m: inout IsoMesh) {
        IsoHouseholdDetails.feet(&m, width: 42, depth: 23, height: 23)
        m.box(28, 1, 3, 13, 21, 19, PixelPalette.wood)
        for z in [5.0, 11, 17] {
            IsoHouseholdDetails.drawer(&m, x: 29, y: 22.1, z: z, width: 11, height: 4)
        }
        m.roundedBox(-1, -1, 23, 44, 25, 3, radius: 1.5, color: PixelPalette.woodLight)
        // 打开的笔记本、键盘与笔筒随桌面投影，保持自然的空间关系。
        m.box(6, 4, 26, 19, 1.6, 13, PixelPalette.ink)
        m.front(7, 5.7, 27, 17, 11, 0x79BDD0)
        m.front(8, 5.75, 34, 7, 1, PixelPalette.cream)
        m.front(8, 5.75, 29, 12, 3, PixelPalette.teal)
        m.roundedBox(6, 6, 26, 19, 12, 1, radius: 0.5, color: 0x82979B)
        for row in 0..<3 {
            for col in 0..<6 {
                m.top(8 + Double(col) * 2.3, 8 + Double(row) * 2, 27.1, 1.6, 1.3, PixelPalette.ink)
            }
        }
        m.top(13, 15, 27.15, 5, 2, 0xC3D2CA)
        m.cylinder(35, 7, 26, radius: 3, height: 6, color: PixelPalette.coral)
        m.box(33.5, 6, 30, 0.8, 0.8, 7, PixelPalette.yellow)
        m.box(35.5, 7, 30, 0.8, 0.8, 8, PixelPalette.blue)
    }

    private static func chair(_ m: inout IsoMesh) {
        IsoHouseholdDetails.feet(&m, width: 18, depth: 18, height: 16)
        for x in [1.0, 14] { m.box(x, 0, 14, 3, 3, 25, PixelPalette.wood) }
        m.roundedBox(0, 0, 28, 18, 3, 12, radius: 1, color: PixelPalette.woodLight)
        m.front(2, 3.1, 30, 14, 8, PixelPalette.wood)
        m.roundedBox(-1, -1, 16, 20, 20, 3, radius: 2, color: PixelPalette.woodLight)
        m.roundedBox(1, 2, 19, 16, 15, 2, radius: 2, color: PixelPalette.coral)
        m.top(3, 4, 21.1, 12, 0.6, 0xEDAA84)
    }

    private static func coffeeTable(_ m: inout IsoMesh) {
        IsoHouseholdDetails.feet(&m, width: 36, depth: 23, height: 12)
        m.roundedBox(1, 1, 4, 34, 21, 1.6, radius: 1, color: PixelPalette.wood)
        m.roundedBox(-1, -1, 12, 38, 25, 3, radius: 4, color: PixelPalette.woodLight)
        m.box(6, 5, 15, 11, 8, 0.8, PixelPalette.coral)
        m.top(7, 6, 15.9, 9, 6, PixelPalette.cream)
        m.top(8, 7, 16, 6, 1, PixelPalette.teal)
        IsometricFurniture.mug(&m, x: 25, y: 9, z: 15)
        m.box(9, 3, 5.6, 3, 13, 4, PixelPalette.blue)
        m.box(14, 3, 5.6, 3, 13, 4, PixelPalette.yellow)
    }

    private static func shoeCabinet(_ m: inout IsoMesh) {
        IsoHouseholdDetails.feet(&m, width: 35, depth: 14, height: 4)
        m.roundedBox(0, 0, 3, 35, 14, 33, radius: 1.5, color: PixelPalette.cream)
        m.roundedBox(-1, -1, 36, 37, 16, 2, radius: 1, color: PixelPalette.woodLight)
        for z in [6.0, 21] {
            m.front(2, 14.1, z, 31, 12, PixelPalette.woodLight)
            m.front(3, 14.15, z + 1, 29, 10, PixelPalette.wood)
            m.box(14, 14.2, z + 8, 7, 1, 1.2, PixelPalette.cream)
        }
        // 门口摆着一双鞋，柜子顶部放钥匙盘。
        for x in [6.0, 14] {
            m.roundedBox(x, 16, 0, 6, 11, 4, radius: 2, color: PixelPalette.blue)
            m.roundedBox(x, 16, 0, 6, 11, 0.9, radius: 1, color: PixelPalette.cream)
            m.top(x + 1, 18, 4.1, 4, 1, 0x8AC3D2)
        }
        m.cylinder(24, 6, 38, radius: 4.3, height: 0.7, color: PixelPalette.tealLight)
        m.top(22, 4, 38.8, 1.2, 4, PixelPalette.yellow)
    }

    private static func dressingTable(_ m: inout IsoMesh) {
        IsoHouseholdDetails.feet(&m, width: 35, depth: 18, height: 22)
        m.roundedBox(0, 0, 15, 35, 18, 7, radius: 1.5, color: PixelPalette.cream)
        for x in [2.0, 19] {
            IsoHouseholdDetails.drawer(&m, x: x, y: 18.1, z: 16, width: 14, height: 5)
        }
        m.roundedBox(-1, -1, 22, 37, 20, 2.5, radius: 2, color: PixelPalette.woodLight)
        m.box(16, 2, 24, 3, 3, 5, PixelPalette.wood)
        IsoHouseholdDetails.disc(&m, x: 17.5, y: 3, z: 39, radius: 12, color: PixelPalette.wood, depth: 2)
        IsoHouseholdDetails.disc(&m, x: 17.5, y: 5.1, z: 39, radius: 10, color: 0x87C5CC)
        m.face([.init(10, 5.2, 39), .init(17, 5.2, 47), .init(20, 5.2, 47), .init(12, 5.2, 36)], 0xD8F0DF)
        m.box(5, 10, 24.5, 3, 3, 6, PixelPalette.coral)
        m.box(5.5, 10.5, 30.5, 2, 2, 1.5, PixelPalette.yellow)
        m.cylinder(29, 10, 24.5, radius: 2.5, height: 3.5, color: PixelPalette.purple)
    }

    private static func washingMachine(_ m: inout IsoMesh) {
        IsoHouseholdDetails.feet(&m, width: 27, depth: 24, height: 3)
        m.roundedBox(0, 0, 2, 27, 24, 32, radius: 2, color: PixelPalette.cream)
        m.front(1, 24.1, 27, 25, 5, 0xC4DDD6)
        IsoHouseholdDetails.disc(&m, x: 20, y: 24.2, z: 29.5, radius: 1.7, color: PixelPalette.ink)
        m.front(3, 24.2, 28, 8, 2, PixelPalette.teal)
        // 滚筒门由真正的圆形轮廓挤出，门框与玻璃不是方块贴图。
        IsoHouseholdDetails.disc(&m, x: 13.5, y: 24.2, z: 15, radius: 10, color: 0x9DADA8, depth: 1.2)
        IsoHouseholdDetails.disc(&m, x: 13.5, y: 25.5, z: 15, radius: 8, color: PixelPalette.ink)
        IsoHouseholdDetails.disc(&m, x: 13.5, y: 25.6, z: 15, radius: 6.7, color: 0x5B91A0)
        m.face([.init(9, 25.7, 11), .init(15, 25.7, 20), .init(18, 25.7, 20), .init(11, 25.7, 9)], 0x9ED4D2)
        m.box(21, 25.8, 15, 1.4, 1, 4, PixelPalette.cream)
        // 洗好的毛巾叠在机器顶上。
        m.roundedBox(3, 4, 34, 18, 12, 2, radius: 1, color: PixelPalette.coral)
        m.roundedBox(4, 5, 36, 16, 10, 2, radius: 1, color: PixelPalette.tealLight)
    }

    private static func stove(_ m: inout IsoMesh) {
        IsoHouseholdDetails.feet(&m, width: 28, depth: 24, height: 3)
        m.roundedBox(0, 0, 2, 28, 24, 30, radius: 1.5, color: 0xB5CFCC)
        m.front(2, 24.1, 6, 24, 18, PixelPalette.ink)
        m.front(4, 24.2, 8, 20, 13, 0x41576B)
        m.front(5, 24.25, 9, 18, 1, 0x91AEB2)
        m.box(4, 24.3, 22, 20, 1.5, 1.3, PixelPalette.cream)
        for x in [4.0, 10, 17, 23] {
            IsoHouseholdDetails.disc(&m, x: x, y: 24.2, z: 28.5, radius: 1.4, color: PixelPalette.ink)
        }
        m.box(-1, -1, 32, 30, 26, 1.5, PixelPalette.ink)
        for x in [7.0, 21] {
            for y in [6.0, 18] {
                m.cylinder(x, y, 33.5, radius: 4.1, height: 0.3, color: 0x62797F)
                m.cylinder(x, y, 33.9, radius: 2.2, height: 0.4, color: PixelPalette.ink)
            }
        }
        // 小锅与把手让灶台在俯视角仍有清楚的识别特征。
        m.cylinder(7, 6, 34.3, radius: 4.5, height: 5, color: PixelPalette.coral)
        m.cylinder(7, 6, 39.3, radius: 4.7, height: 0.7, color: PixelPalette.cream)
        m.cylinder(7, 6, 40, radius: 1.2, height: 1.2, color: PixelPalette.ink)
        m.box(11, 5, 37, 5, 2, 1, PixelPalette.ink)
    }

    private static func airConditioner(_ m: inout IsoMesh) {
        m.roundedBox(0, 0, 0, 43, 10, 14, radius: 2.5, color: PixelPalette.cream)
        m.front(3, 10.1, 3, 37, 3, PixelPalette.ink)
        for z in [3.5, 4.5, 5.5] {
            m.front(4, 10.2, z, 35, 0.4, 0x8DADA7)
        }
        m.front(31, 10.2, 9, 5, 2, PixelPalette.tealLight)
        m.front(32, 10.25, 9.5, 1, 1, PixelPalette.greenLight)
        m.front(3, 10.2, 11, 7, 0.6, 0xB9C5B8)
        m.top(4, 2, 14.1, 34, 0.6, 0xD6DECE)
    }

    private static func suitcase(_ m: inout IsoMesh) {
        for x in [3.0, 18] {
            m.roundedBox(x, 2, 0, 3, 3, 4, radius: 1, color: PixelPalette.ink)
            m.roundedBox(x, 10, 0, 3, 3, 4, radius: 1, color: PixelPalette.ink)
        }
        m.roundedBox(1, 0, 3, 22, 14, 30, radius: 3, color: PixelPalette.yellow)
        m.front(2, 14.1, 5, 20, 26, 0xDBA948)
        for x in [5.0, 9, 13, 17] {
            m.front(x, 14.2, 7, 1, 22, 0xF6D67E)
        }
        for x in [7.0, 16] { m.box(x, 3, 32, 1.2, 1.2, 10, 0x8CA4A5) }
        m.roundedBox(6, 2.5, 41, 12.5, 2.5, 2.5, radius: 0.7, color: PixelPalette.ink)
        m.box(22.5, 5, 16, 1.5, 4, 6, PixelPalette.ink)
        m.front(16, 14.3, 20, 4, 6, PixelPalette.coral)
        m.front(16.8, 14.35, 21.5, 2.5, 2.5, PixelPalette.cream)
    }
}

/// 家具和小装饰共用的结构细节。所有形状都在模型坐标里，镜像时一起变换。
nonisolated enum IsoHouseholdDetails {
    static func feet(_ m: inout IsoMesh, width: Double, depth: Double, height: Double) {
        for x in [1.5, width - 4] {
            for y in [1.5, depth - 4] {
                m.box(x, y, 0, 2.5, 2.5, height, PixelPalette.woodDark)
            }
        }
    }

    static func drawer(_ m: inout IsoMesh, x: Double, y: Double, z: Double, width: Double, height: Double) {
        m.front(x, y, z, width, height, PixelPalette.woodLight)
        m.front(x + 0.7, y + 0.05, z + 0.7, width - 1.4, height - 1.4, PixelPalette.wood)
        m.box(x + width / 2 - 2, y + 0.1, z + height / 2, 4, 0.8, 0.8, PixelPalette.cream)
    }

    /// 正面圆形/椭圆形，可挤出厚度；用于滚筒门、钟面、镜子与音箱单元。
    static func disc(_ m: inout IsoMesh, x: Double, y: Double, z: Double, radius: Double,
                     color: UInt32, depth: Double = 0, heightRatio: Double = 1) {
        let points = (0..<24).map { step -> (Double, Double) in
            let angle = Double(step) * .pi * 2 / 24
            return (x + cos(angle) * radius, z + sin(angle) * radius * heightRatio)
        }
        if depth > 0 {
            m.profile(points, y: y, depth: depth, color: color)
        } else {
            m.face(points.map { .init($0.0, y, $0.1) }, color)
        }
    }
}
