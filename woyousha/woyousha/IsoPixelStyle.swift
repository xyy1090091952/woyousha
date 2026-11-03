import Foundation

/// 像素渲染风格（参考“3D 像素网球”）：粗像素 + 表面颗粒 + 柔和环境光遮蔽 + 地面软影 + 弱描边。
/// 房间、家具、装饰都经过这一层；想整体换画风，只需调整这里的常量。
nonisolated enum IsoPixelStyle {
    // 描边：0 = 没有描边，只靠明暗分面；1 = 原来的深色卡通描边。
    static let outlineStrength = 0.3

    // 表面颗粒：像沙地、草地那样逐像素轻微深浅变化，打破大面积平涂。
    static let grainDarkChance = 0.24
    static let grainLightChance = 0.14
    static let grainDark = 0.92
    static let grainLight = 1.05
    /// 2×2 小团块与单像素颗粒的混合比例，越大颗粒越“成团”。
    static let grainClusterWeight = 0.55

    // 环境光遮蔽：凹角、家具脚与地面交界处自然变暗，像真实光线照不进缝隙。
    static let occlusionRadii = [1, 2, 3]
    /// 每像素的弯折程度低于此值视为平面（世界单位），忽略多边形曲面的轻微起伏。
    static let occlusionBias = 0.25
    /// 超过此深度差的遮挡物视为“离得远”，不会把后面的墙面压黑。
    static let occlusionRange = 6.0
    static let occlusionStrength = 0.5
    /// 明暗按台阶分级，再配合有序抖动，过渡呈现像素画特有的网点。
    static let occlusionStep = 0.06

    // 地面软影：落地家具与摆件在脚下投一块柔和阴影，挂墙物品不投影。
    static let shadowColor: UInt32 = 0x2E2118
    static let shadowOpacity = 0.32
    /// 影子从占地边缘向外延伸的距离（世界单位）。
    static let shadowReach = 2.0
    /// 占地内部多深处达到最深。
    static let shadowCore = 3.0
    /// 光从左前上方照来，影子略偏向右后方。
    static let shadowOffsetX = 0.4
    static let shadowOffsetY = -0.6
    static let shadowLevels = 3.0
    /// 影子四角的圆润程度（占短边一半的比例）：圆桌、圆凳不会投出方形影子。
    static let shadowCornerRatio = 0.7
    /// 只用离地这么高以内的部分计算影子范围（世界单位）：遮阳伞、落地灯只在底座下投影，
    /// 不会把高处的伞面投成超出画布的大片阴影。
    static let shadowFootprintHeight = 8.0
    /// 靠近画布边缘的影子逐渐淡出（像素），避免出现被切断的直边。
    static let shadowEdgeFade = 3.0

    // 调色：略降饱和、微微偏暖，接近参考图的自然柔和色。
    static let saturation = 0.9
    static let warmth = 0.02

    /// 4×4 Bayer 有序抖动阈值，范围 0~1。
    private static let bayer4: [Double] = [0,8,2,10, 12,4,14,6, 3,11,1,9, 15,7,13,5].map { ($0 + 0.5) / 16 }

    static func dither(_ x: Int, _ y: Int) -> Double { bayer4[(y & 3) * 4 + (x & 3)] }

    /// 稳定哈希：同一张图每次生成的颗粒完全相同，缓存与重绘不会闪烁。
    static func hash(_ x: Int, _ y: Int, _ seed: UInt32) -> Double {
        var h = UInt32(truncatingIfNeeded: x) &* 0x8DA6_B343
        h ^= UInt32(truncatingIfNeeded: y) &* 0xD816_3841
        h ^= seed &* 0xCB1A_B31F
        h ^= h >> 13
        h = h &* 0x5BD1_E995
        h ^= h >> 15
        return Double(h & 0xFFFF) / 65535
    }

    /// 返回表面颗粒的亮度系数：大多数像素保持原色，少数略暗或略亮。
    static func grain(_ x: Int, _ y: Int, seed: UInt32) -> Double {
        let cluster = hash(x >> 1, y >> 1, seed &+ 0x9E37)
        let single = hash(x, y, seed)
        let n = cluster * grainClusterWeight + single * (1 - grainClusterWeight)
        if n < grainDarkChance { return grainDark }
        if n > 1 - grainLightChance { return grainLight }
        return 1
    }

    /// 环境光遮蔽量（0~1）按台阶量化后转为亮度系数。
    static func occlusionFactor(_ amount: Double, _ x: Int, _ y: Int) -> Double {
        let darkness = min(1, max(0, amount)) * occlusionStrength
        let level = floor(darkness / occlusionStep + dither(x, y))
        return 1 - max(0, level) * occlusionStep
    }

    /// 两色按比例混合，用于把深色描边柔化成“只比面色暗一点”的边。
    static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        func channel(_ shift: Int) -> UInt32 {
            let ca = Double((a >> shift) & 255), cb = Double((b >> shift) & 255)
            return UInt32(min(255, max(0, (ca + (cb - ca) * t).rounded())))
        }
        return channel(16) << 16 | channel(8) << 8 | channel(0)
    }

    /// 最终调色：亮度系数 → 降饱和 → 微暖，输出 0~255 的 RGB。
    static func grade(_ color: UInt32, _ factor: Double) -> (UInt8, UInt8, UInt8) {
        var r = Double((color >> 16) & 255) * factor
        var g = Double((color >> 8) & 255) * factor
        var b = Double(color & 255) * factor
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        r = luminance + (r - luminance) * saturation
        g = luminance + (g - luminance) * saturation
        b = luminance + (b - luminance) * saturation
        r *= 1 + warmth
        b *= 1 - warmth
        func byte(_ v: Double) -> UInt8 { UInt8(min(255, max(0, v.rounded()))) }
        return (byte(r), byte(g), byte(b))
    }

    /// 点到圆角矩形的带符号距离：矩形内为负，越靠中心越小。
    static func signedDistance(x: Double, y: Double, minX: Double, minY: Double, maxX: Double, maxY: Double) -> Double {
        let radius = min(maxX - minX, maxY - minY) * 0.5 * shadowCornerRatio
        // 先把矩形向内收 radius，再把距离减去 radius，四角就成了圆弧。
        let dx = max(minX + radius - x, x - maxX + radius), dy = max(minY + radius - y, y - maxY + radius)
        let outside = hypot(max(dx, 0), max(dy, 0))
        return outside + min(max(dx, dy), 0) - radius
    }

    /// 影子浓度：占地内部最深，向外平滑淡出，再量化成几级并抖动。
    static func shadowAlpha(distance: Double, _ x: Int, _ y: Int) -> Double {
        let t = min(1, max(0, (shadowReach - distance) / (shadowReach + shadowCore)))
        let smooth = t * t * (3 - 2 * t)
        let level = floor(smooth * shadowLevels + dither(x, y) - 0.5)
        return max(0, min(shadowLevels, level)) / shadowLevels * shadowOpacity
    }
}
