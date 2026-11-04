import Foundation

/// Pixel Plays 的视觉规则：有限色阶、暖高光/紫暗部、材质纹理和清晰投影。
/// 色阶与 Bayer 抖动参考其 MIT 开源引擎，许可保存在 PixelPlays-LICENSE.txt。
nonisolated enum IsoPixelStyle {
    static let cool: UInt32 = 0x59445F
    static let warm: UInt32 = 0xFFECC5
    // 暗面仍带紫，但减轻全局压暗，让木色、珊瑚色和蓝绿保留各自本色。
    static let shadeMultipliers = [0.58, 0.76, 0.92, 1.0, 1.08]
    static let shadeTintAmounts = [0.22, 0.10, 0.025, 0.0, 0.16]
    static let lightingRoundingBias = 0.2
    /// 大面积浅墙面的色阶更靠近，避免把网点读成黑白棋盘。
    static let plasterLightLift = 1.0
    static let silhouetteTint = 0.18
    static let rimTint = 0.25
    static let depthEdgeThreshold = 0.6
    static let occlusionRadii = [1, 2, 3]
    static let occlusionBias = 0.25
    static let occlusionRange = 6.0
    static let occlusionStrength = 0.26
    static let occlusionSteps = 8.0

    // 大平面只在相近色之间变化，纹理不跨越整个受光色阶。
    // 草叶仍保留较大的反差；平滑表面只用单色，不给玻璃/金属撒网点。
    private static let woodSurface = IsoSurfaceTreatment(
        toneFactors:[0.945,0.98,1.015,1.05],ditherStrength:0.28,
        scaleU:0.08,scaleV:0.9,grainStrength:0.95)
    private static let plasterSurface = IsoSurfaceTreatment(
        toneFactors:[0.98,0.992,1.008,1.02],ditherStrength:0.12,
        scaleU:0.08,scaleV:0.08,grainStrength:0.8,speckChance:0.012,speckDarkness:0.12)
    private static let foliageSurface = IsoSurfaceTreatment(
        toneFactors:[0.82,0.94,1.05,1.14],ditherStrength:0.5,
        scaleU:0.5,scaleV:0.5,grainStrength:1.5,singleGrainStrength:0.5)
    private static let smoothSurface = IsoSurfaceTreatment(
        toneFactors:[1],ditherStrength:0,scaleU:0,scaleV:0,grainStrength:0)
    private static let defaultSurface = IsoSurfaceTreatment(
        toneFactors:[0.97,0.99,1.01,1.03],ditherStrength:0.16,
        scaleU:0.2,scaleV:0.2,grainStrength:0.45)

    // 光从左上方照入，物体越高，向屏幕右侧投出的影子越长。
    static let shadowDirectionX = 0.72
    static let shadowDirectionY = -0.12
    static let shadowOpacity = 0.30
    static let contactOpacity = 0.42
    static let shadowPadding = 3.0
    static let contactHeight = 2.5
    static let shadowEdgeDither = 0.22
    static let baseDissolveHeight = 2.5

    private static let bayer4: [Double] =
        [0,8,2,10, 12,4,14,6, 3,11,1,9, 15,7,13,5].map { ($0 + 0.5) / 16 }

    static func dither(_ x: Int, _ y: Int) -> Double { bayer4[(y & 3) * 4 + (x & 3)] }

    /// 哈希与纹理绑定世界坐标，重新绘制、镜像、拖动时不会随机闪动。
    static func hash(_ x: Int, _ y: Int, _ seed: UInt32 = 0) -> Double {
        var h = UInt32(truncatingIfNeeded: x) &* 0x8DA6_B343
        h ^= UInt32(truncatingIfNeeded: y) &* 0xD816_3841
        h ^= seed &* 0xCB1A_B31F
        h ^= h >> 13
        h = h &* 0x5BD1_E995
        h ^= h >> 15
        return Double(h & 0xFFFF) / 65535
    }

    static func noise(_ x: Double, _ y: Double, seed: UInt32) -> Double {
        let ix = Int(floor(x)), iy = Int(floor(y))
        let fx = x - floor(x), fy = y - floor(y)
        let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
        let a = hash(ix, iy, seed), b = hash(ix + 1, iy, seed)
        let c = hash(ix, iy + 1, seed), d = hash(ix + 1, iy + 1, seed)
        return (a + (b - a) * sx) * (1 - sy) + (c + (d - c) * sx) * sy
    }

    static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        func channel(_ shift: Int) -> UInt32 {
            let ca = Double((a >> shift) & 255), cb = Double((b >> shift) & 255)
            return UInt32(min(255, max(0, (ca + (cb - ca) * t).rounded())))
        }
        return channel(16) << 16 | channel(8) << 8 | channel(0)
    }

    static func ramp(_ color: UInt32) -> [UInt32] {
        shadeMultipliers.indices.map { index in
            mix(IsoColor.shade(color, shadeMultipliers[index]), index == 4 ? warm : cool,
                shadeTintAmounts[index])
        }
    }

    static func shadeIndex(_ light: Double) -> Int {
        Int(min(Double(shadeMultipliers.count-1),max(0,floor(light+lightingRoundingBias))))
    }

    static func surfaceTreatment(_ material: IsoMaterial) -> IsoSurfaceTreatment {
        switch material {
        case .wood: return woodSurface
        case .plaster: return plasterSurface
        case .foliage: return foliageSurface
        case .smooth: return smoothSurface
        case .automatic: return defaultSurface
        }
    }

    /// 先决定整个面的受光，再为纹理生成几种接近的颜色，避免深浅棋盘。
    static func surfaceRamp(_ litColor: UInt32, treatment: IsoSurfaceTreatment) -> [UInt32] {
        treatment.toneFactors.map { IsoColor.shade(litColor,$0) }
    }

    /// 墙角阴影采用小步长分档，不再用高反差 Bayer 网点铺满暗部。
    static func occlusionTint(_ amount: Double) -> Double {
        (min(1,max(0,amount))*occlusionSteps).rounded()/occlusionSteps*occlusionStrength
    }

    /// 根据真实面朝向分配明暗：顶面最亮，左侧次之，右侧最暗。
    static func lighting(_ normal: IsoPoint) -> Double {
        min(3.85, max(0.5, 2 - 0.8 * normal.x + 0.3 * normal.y + 1.4 * normal.z))
    }

    /// 纹理在材质表面上采样；木头有顺纹，墙面有斑驳，织物颗粒细而克制。
    static func texture(_ treatment: IsoSurfaceTreatment, u: Double, v: Double, seed: UInt32) -> Double {
        guard treatment.grainStrength>0 else { return 0.5 }
        var value = 0.5+(noise(u*treatment.scaleU,v*treatment.scaleV,seed:seed)-0.5)*treatment.grainStrength
        if treatment.singleGrainStrength>0 {
            value += (hash(Int(floor(u)),Int(floor(v)),seed)-0.5)*treatment.singleGrainStrength
        }
        if treatment.speckChance>0 {
            let speck = hash(Int(floor(u*treatment.speckScale)),Int(floor(v*treatment.speckScale)),seed)
            if speck>1-treatment.speckChance { value -= treatment.speckDarkness }
        }
        return min(1,max(0,value))
    }
}

/// 材质纹理的配置表。色差、抖动、颗粒尺度和稀疏斑点集中管理。
nonisolated struct IsoSurfaceTreatment {
    let toneFactors: [Double]
    let ditherStrength: Double
    let scaleU: Double
    let scaleV: Double
    let grainStrength: Double
    var singleGrainStrength: Double = 0
    var speckChance: Double = 0
    var speckDarkness: Double = 0
    var speckScale: Double = 1.4
}

/// 材质只决定像素纹理，不改变家具的尺寸、编号或保存数据。
nonisolated enum IsoMaterial: Sendable {
    case automatic, wood, plaster, foliage, smooth

    static func inferred(from color: UInt32) -> IsoMaterial {
        let r = Double((color >> 16) & 255), g = Double((color >> 8) & 255), b = Double(color & 255)
        if g > r * 1.08 && g > b * 1.17 { return .foliage }
        if r > g * 1.12 && g > b * 1.18 { return .wood }
        return .automatic
    }
}
