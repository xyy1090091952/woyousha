import Foundation

/// 自然材质本色。暖高光和偏紫暗部统一由 IsoPixelStyle 生成。
nonisolated enum PixelPalette {
    static let wood: UInt32 = 0xB68D66
    static let woodLight: UInt32 = 0xD6BC8C
    static let woodDark: UInt32 = 0x6F5642
    static let cream: UInt32 = 0xE6DEC9
    static let ink: UInt32 = 0x33303F
    static let teal: UInt32 = 0x527F7A
    static let tealLight: UInt32 = 0x81AA96
    static let green: UInt32 = 0x647E48
    static let greenLight: UInt32 = 0xA1AE69
    static let coral: UInt32 = 0xBA7762
    static let blue: UInt32 = 0x607D98
    static let yellow: UInt32 = 0xDAB75E
    static let purple: UInt32 = 0x9A809D
    static let bookColors: [UInt32] = [blue, coral, green, yellow, purple, teal, 0xCE9A60]
}
