import Foundation

/// 自然材质本色。暖高光和偏紫暗部统一由 IsoPixelStyle 生成。
nonisolated enum PixelPalette {
    static let wood: UInt32 = 0xCD985D
    static let woodLight: UInt32 = 0xE8BB7C
    static let woodDark = OyohaPalette.trim
    static let cream = OyohaPalette.cream
    static let ink: UInt32 = 0x403139
    // 暖屋里用少量鲜明的冷色点缀，避免所有家具都混成灰褐色。
    static let teal: UInt32 = 0x3F9A91
    static let tealLight: UInt32 = 0x91CAB3
    static let green: UInt32 = 0x71964A
    static let greenLight: UInt32 = 0xB2CA73
    static let coral: UInt32 = 0xE78F71
    static let blue: UInt32 = 0x6399BF
    static let yellow = OyohaPalette.honey
    static let purple: UInt32 = 0xB793BE
    static let bookColors: [UInt32] = [blue, coral, green, yellow, purple, teal, 0xE0A25E]
}
