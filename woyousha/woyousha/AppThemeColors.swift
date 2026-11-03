import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// 语义色统一映射到 Logo 色板；普通文字与按钮文字都保持足够的深浅对比。
enum AppTheme {
    static let background = adaptive(light: 0xFFFBF5, dark: 0x271F1C)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x372B25)
    static let inset = adaptive(light: OyohaPalette.cream, dark: 0x48352A)
    static let accent = adaptive(light: OyohaPalette.honey, dark: 0xF0BA79)
    static let accentEdge = adaptive(light: OyohaPalette.honeyEdge, dark: 0xAB7147)
    // 系统链接、选中状态和浅底文字需要比蜜金按钮更深的颜色。
    static let accentText = adaptive(light: 0x895329, dark: 0xF1C58E)
    static let onAccent = adaptive(light: OyohaPalette.coffee, dark: 0x3E281F)
    static let text = adaptive(light: OyohaPalette.coffee, dark: 0xFFF1DD)
    static let secondaryText = adaptive(light: 0x8A6D5D, dark: 0xCAB09C)
    static let line = adaptive(light: 0xEAD8C4, dark: 0x604B3E)
    static let stickerDot = adaptive(light: 0xE6CDB5, dark: 0x775A46)
    static let secondary = adaptive(light: 0x966047, dark: OyohaPalette.peach)
    static let secondaryInset = adaptive(light: 0xFBE9DC, dark: 0x493127)
    // 旧页面的 blue 命名保留为兼容入口，实际使用新的品牌次要色。
    static let blue = secondary
    static let blueInset = secondaryInset
    static let yellow = Color(red: 1, green: 0.79, blue: 0.38)
    static let cameraBackground = Color(red: 0.14, green: 0.11, blue: 0.10)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        })
        #else
        // 电脑预览也使用同一套实际颜色，避免预览与手机各维护一份主题。
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        })
        #endif
    }
}
