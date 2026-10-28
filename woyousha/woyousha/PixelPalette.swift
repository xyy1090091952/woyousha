import Foundation

/// 场景统一的游戏像素色板：保持深色描边与清晰明暗，减少灰褐色堆叠。
nonisolated enum PixelPalette {
    static let wood: UInt32 = 0xC78142
    static let woodLight: UInt32 = 0xE9AD62
    static let woodDark: UInt32 = 0x825133
    static let cream: UInt32 = 0xEFDFB7
    static let ink: UInt32 = 0x303646
    static let teal: UInt32 = 0x388D8A
    static let tealLight: UInt32 = 0x66C0B1
    static let green: UInt32 = 0x65A456
    static let greenLight: UInt32 = 0xADD071
    static let coral: UInt32 = 0xD87B61
    static let blue: UInt32 = 0x427EA8
    static let yellow: UInt32 = 0xEFC55B
    static let purple: UInt32 = 0x9272AE
    static let bookColors: [UInt32] = [blue, coral, green, yellow, purple, teal, 0xCE9A60]
}
