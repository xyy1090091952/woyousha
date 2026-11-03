import Foundation

/// Logo 的共同本色：按钮、房间和木质家具从同一张色板取色。
/// 这里只存颜色数据，明暗受光交给 IsoPixelStyle，系统深色适配交给 AppTheme。
nonisolated enum OyohaPalette {
    static let honey: UInt32 = 0xE9AF68
    static let honeyEdge: UInt32 = 0xB77843
    static let cream: UInt32 = 0xFFF3DF
    static let peach: UInt32 = 0xF1C3A3
    static let coffee: UInt32 = 0x52352C
    static let wall: UInt32 = 0xF0D1AA
    static let floor: UInt32 = 0xD9954D
    static let trim: UInt32 = 0x986344
}
