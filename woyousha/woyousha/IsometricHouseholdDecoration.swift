import Foundation

/// 生活小装饰拥有独立剪影；沿用房间色板，并在两种房间风格中保留辨识度。
nonisolated enum IsometricHouseholdDecoration {
    static func clock() -> IsoMesh {
        var m = IsoMesh()
        IsoHouseholdDetails.disc(&m, x: 0, y: 0, z: 12, radius: 12, color: PixelPalette.wood, depth: 2)
        IsoHouseholdDetails.disc(&m, x: 0, y: 2.1, z: 12, radius: 10, color: PixelPalette.cream)
        for step in 0..<12 {
            let angle = Double(step) * .pi * 2 / 12
            IsoHouseholdDetails.disc(&m, x: sin(angle) * 8, y: 2.2, z: 12 + cos(angle) * 8,
                                     radius: step % 3 == 0 ? 0.8 : 0.5, color: PixelPalette.ink)
        }
        m.front(-0.5, 2.3, 11.5, 1, 6, PixelPalette.ink)
        m.face([.init(-0.4, 2.3, 12.3), .init(5, 2.3, 9), .init(5.5, 2.3, 9.8), .init(0.3, 2.3, 12.8)], PixelPalette.ink)
        IsoHouseholdDetails.disc(&m, x: 0, y: 2.4, z: 12, radius: 1.2, color: PixelPalette.coral)
        return m
    }

    static func flowers(style: String) -> IsoMesh {
        var m = IsoMesh()
        m.cylinder(0, 0, 0, radius: 3.7, height: 8, color: PixelPalette.blue, topRadius: 5)
        m.cylinder(0, 0, 8, radius: 5, height: 5, color: 0x81BDC7, topRadius: 2.6)
        m.cylinder(0, 0, 13, radius: 2.8, height: 2, color: PixelPalette.blue)
        for (x, y, z) in [(-5.0, 0.0, 24.0), (1, -3, 28), (5, 2, 22), (-1, 4, 26)] {
            m.box(x * 0.45 - 0.4, y * 0.45 - 0.4, 13, 0.8, 0.8, z - 13, PixelPalette.green)
            m.beveledBox(x * 0.5 - 3, y * 0.5, 18, 5, 2, 2, bevel: 0.5, color: PixelPalette.greenLight)
            flower(&m, x: x, y: y, z: z, color: style == "home2" ? PixelPalette.yellow : PixelPalette.coral)
        }
        return m
    }

    private static func flower(_ m: inout IsoMesh, x: Double, y: Double, z: Double, color: UInt32) {
        for step in 0..<5 {
            let a = Double(step) * .pi * 2 / 5
            m.roundedBox(x + cos(a) * 2.5 - 2, y + sin(a) * 2.5 - 2, z, 4, 4, 2.5, radius: 1.5, color: color)
        }
        m.cylinder(x, y, z + 2.3, radius: 1.8, height: 0.8, color: PixelPalette.yellow)
    }

    static func tableLamp() -> IsoMesh {
        var m = IsoMesh()
        m.cylinder(0, 0, 0, radius: 6, height: 1.5, color: PixelPalette.teal)
        m.box(-0.7, -0.7, 1.5, 1.4, 1.4, 13, PixelPalette.woodDark)
        m.cylinder(0, 0, 13, radius: 8, height: 10, color: PixelPalette.yellow, topRadius: 4)
        m.cylinder(0, 0, 12.8, radius: 8.1, height: 0.7, color: PixelPalette.cream)
        m.cylinder(0, 0, 23, radius: 4.2, height: 0.7, color: PixelPalette.cream)
        m.box(4, 0, 10, 0.6, 0.6, 4, PixelPalette.woodDark)
        m.cylinder(4.3, 0.3, 9, radius: 0.8, height: 1, color: PixelPalette.coral)
        return m
    }

    static func cactus() -> IsoMesh {
        var m = IsoMesh()
        m.cylinder(0, 0, 0, radius: 5, height: 7, color: PixelPalette.coral, topRadius: 6)
        m.cylinder(0, 0, 6, radius: 6.4, height: 1.4, color: PixelPalette.woodLight)
        m.cylinder(0, 0, 7.5, radius: 5, height: 0.2, color: PixelPalette.woodDark)
        m.roundedBox(-2.8, -2.8, 7.7, 5.6, 5.6, 20, radius: 2.5, color: PixelPalette.green)
        m.roundedBox(-8, -2, 16, 7, 4, 4, radius: 1.5, color: PixelPalette.green)
        m.roundedBox(-8, -2, 17, 4, 4, 7, radius: 1.7, color: PixelPalette.green)
        m.roundedBox(1, -1, 13, 6, 4, 4, radius: 1.5, color: PixelPalette.greenLight)
        m.roundedBox(4, -1, 14, 3, 4, 8, radius: 1.4, color: PixelPalette.greenLight)
        for z in [11.0, 16, 21, 25] {
            m.front(-1.5, 2.9, z, 0.7, 1.5, PixelPalette.cream)
            m.front(1, 2.9, z - 1, 0.7, 1.5, PixelPalette.cream)
        }
        flower(&m, x: 0, y: 0, z: 27, color: PixelPalette.coral)
        return m
    }

    static func cushions(style: String) -> IsoMesh {
        var m = IsoMesh()
        let color = style == "home2" ? PixelPalette.green : PixelPalette.coral
        m.roundedBox(-12, -6, 0, 18, 14, 5, radius: 3, color: color)
        m.roundedBox(-4, -9, 5, 17, 14, 5, radius: 3, color: PixelPalette.yellow)
        // 小菱形缝线与第二层靠垫形成松软的叠放效果。
        for x in [-1.0, 5] {
            m.face([.init(x, -4, 10.1), .init(x + 2, -6, 10.1),
                    .init(x + 4, -4, 10.1), .init(x + 2, -2, 10.1)], PixelPalette.cream)
        }
        m.front(-9, 8.05, 2, 12, 0.6, 0xF1BB93)
        return m
    }

    static func teddyBear() -> IsoMesh {
        var m = IsoMesh()
        let fur = PixelPalette.woodLight
        m.roundedBox(-6, -4, 3, 12, 10, 13, radius: 4, color: fur)
        for x in [-8.0, 3] {
            m.roundedBox(x, 3, 0, 6, 8, 5, radius: 2.5, color: fur)
        }
        for x in [-9.0, 5] {
            m.roundedBox(x, 0, 7, 5, 6, 8, radius: 2, color: fur)
        }
        m.roundedBox(-7, -4, 15, 14, 10, 12, radius: 4, color: fur)
        for x in [-5.5, 5.5] {
            IsoHouseholdDetails.disc(&m, x: x, y: -1, z: 26, radius: 3, color: fur, depth: 3)
            IsoHouseholdDetails.disc(&m, x: x, y: 2.1, z: 26, radius: 1.6, color: PixelPalette.coral)
        }
        IsoHouseholdDetails.disc(&m, x: 0, y: 6.1, z: 19, radius: 3.5, color: PixelPalette.cream, heightRatio: 0.7)
        for x in [-3.0, 3] {
            IsoHouseholdDetails.disc(&m, x: x, y: 6.2, z: 23, radius: 0.9, color: PixelPalette.ink)
        }
        IsoHouseholdDetails.disc(&m, x: 0, y: 6.3, z: 20, radius: 1, color: PixelPalette.ink)
        m.front(-0.3, 6.35, 18.5, 0.6, 1.5, PixelPalette.ink)
        m.face([.init(0, 6.2, 15), .init(-4, 6.2, 17), .init(-4, 6.2, 13)], PixelPalette.coral)
        m.face([.init(0, 6.2, 15), .init(4, 6.2, 17), .init(4, 6.2, 13)], PixelPalette.coral)
        return m
    }

    static func floorMirror() -> IsoMesh {
        var m = IsoMesh()
        m.roundedBox(-12, -3, 0, 24, 13, 2, radius: 2, color: PixelPalette.wood)
        m.box(-7, 0, 2, 2, 3, 8, PixelPalette.woodDark)
        m.box(5, 0, 2, 2, 3, 8, PixelPalette.woodDark)
        IsoHouseholdDetails.disc(&m, x: 0, y: 0, z: 29, radius: 11, color: PixelPalette.woodLight, depth: 2, heightRatio: 2)
        IsoHouseholdDetails.disc(&m, x: 0, y: 2.1, z: 29, radius: 9.2, color: 0x8DC7C9, heightRatio: 2.15)
        m.face([.init(-7, 2.2, 27), .init(2, 2.2, 46),
                .init(5, 2.2, 43), .init(-6, 2.2, 20)], 0xDEF3E0)
        m.face([.init(-4, 2.21, 15), .init(6, 2.21, 35),
                .init(7, 2.21, 30), .init(-2, 2.21, 13)], 0xBDE2D5)
        return m
    }

    static func aquarium() -> IsoMesh {
        var m = IsoMesh()
        m.box(-16, -8, 0, 32, 16, 2, PixelPalette.woodDark)
        m.box(-15, -7, 2, 30, 14, 20, 0x6AADB7)
        m.top(-14, -6, 22.1, 28, 12, 0x92D5D0)
        m.front(-14, 7.1, 3, 28, 17, 0x62B7C1)
        m.front(-14, 7.2, 3, 28, 2, PixelPalette.woodLight)
        // 鱼和水草在可见玻璃后以同一平面表现，避免被不透明玻璃遮住。
        for (x, z) in [(-7.0, 12.0), (6, 16)] {
            m.face([.init(x - 3, 7.3, z), .init(x, 7.3, z + 2),
                    .init(x + 3, 7.3, z), .init(x, 7.3, z - 2)], PixelPalette.yellow)
            m.face([.init(x + 2, 7.3, z), .init(x + 5, 7.3, z + 2),
                    .init(x + 5, 7.3, z - 2)], PixelPalette.coral)
            m.front(x - 1.8, 7.35, z, 0.7, 0.7, PixelPalette.ink)
        }
        for x in [-11.0, 9] {
            m.front(x, 7.3, 5, 1.3, 6, PixelPalette.green)
            m.face([.init(x, 7.31, 8), .init(x - 3, 7.31, 12),
                    .init(x - 2, 7.31, 7)], PixelPalette.greenLight)
        }
        for z in [11.0, 16, 19] {
            IsoHouseholdDetails.disc(&m, x: 1.5, y: 7.4, z: z, radius: 0.6, color: PixelPalette.cream)
        }
        m.face([.init(-12, 7.5, 5), .init(-5, 7.5, 20),
                .init(-3.5, 7.5, 20), .init(-10.5, 7.5, 5)], 0xB2E4DD)
        m.box(-16, -8, 22.2, 32, 16, 1.5, PixelPalette.ink)
        m.box(-11, -3, 23.7, 22, 6, 0.8, 0x77918A)
        return m
    }

    static func speaker() -> IsoMesh {
        var m = IsoMesh()
        m.roundedBox(-6, -5, 0, 12, 10, 24, radius: 1.7, color: PixelPalette.woodDark)
        m.front(-5, 5.1, 1, 10, 22, PixelPalette.ink)
        IsoHouseholdDetails.disc(&m, x: 0, y: 5.2, z: 8, radius: 4, color: 0x718A8B)
        IsoHouseholdDetails.disc(&m, x: 0, y: 5.25, z: 8, radius: 2.7, color: 0x394B59)
        IsoHouseholdDetails.disc(&m, x: 0, y: 5.3, z: 8, radius: 1.3, color: PixelPalette.ink)
        IsoHouseholdDetails.disc(&m, x: 0, y: 5.2, z: 18, radius: 2.5, color: 0x718A8B)
        IsoHouseholdDetails.disc(&m, x: 0, y: 5.3, z: 18, radius: 1.4, color: PixelPalette.ink)
        m.top(-2, -1, 24.1, 1, 1, PixelPalette.greenLight)
        return m
    }

    static func petBed() -> IsoMesh {
        var m = IsoMesh()
        m.roundedBox(-14, -10, 0, 28, 20, 3, radius: 5, color: PixelPalette.wood)
        m.roundedBox(-14, -10, 2, 28, 5, 7, radius: 2, color: PixelPalette.coral)
        m.roundedBox(-14, -7, 2, 5, 17, 7, radius: 2, color: PixelPalette.coral)
        m.roundedBox(9, -7, 2, 5, 17, 7, radius: 2, color: PixelPalette.coral)
        m.roundedBox(-9, -5, 3, 18, 14, 3, radius: 3, color: PixelPalette.cream)
        m.roundedBox(-13, 7, 2, 8, 3, 5, radius: 1, color: PixelPalette.coral)
        m.roundedBox(5, 7, 2, 8, 3, 5, radius: 1, color: PixelPalette.coral)
        // 入口处的骨头玩具，补足宠物用品的生活细节。
        m.box(-3, 13, 0.5, 6, 2, 1.5, PixelPalette.cream)
        for x in [-3.0, 3] {
            m.cylinder(x, 13.5, 0, radius: 1.7, height: 2, color: PixelPalette.cream)
            m.cylinder(x, 15, 0, radius: 1.7, height: 2, color: PixelPalette.cream)
        }
        return m
    }
}
