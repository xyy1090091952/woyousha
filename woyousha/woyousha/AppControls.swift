import SwiftUI

/// 主按钮和工具按钮共用尺寸；表单和首页都从这里复用。
enum AppControlMetrics {
    static let height: CGFloat = 52
    static let depth: CGFloat = 4
    static let corner: CGFloat = 18
    static let iconSize: CGFloat = 46
    static let iconCorner: CGFloat = 16
    static let iconDepth: CGFloat = 3
}

struct AppButtonStyle: ButtonStyle {
    var isPrimary = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .heavy))
            .foregroundStyle(isPrimary ? AppTheme.onAccent : AppTheme.secondary)
            .padding(.horizontal, 18)
            .frame(minHeight: AppControlMetrics.height)
            .background(isPrimary ? AppTheme.accent : AppTheme.inset,
                        in: RoundedRectangle(cornerRadius: AppControlMetrics.corner))
            .overlay {
                if !isPrimary {
                    RoundedRectangle(cornerRadius: AppControlMetrics.corner).strokeBorder(AppTheme.line, lineWidth: 2)
                }
            }
            .offset(y: configuration.isPressed ? AppControlMetrics.depth : 0)
            .background {
                RoundedRectangle(cornerRadius: AppControlMetrics.corner)
                    .fill(isPrimary ? AppTheme.accentEdge : AppTheme.line)
                    .offset(y: AppControlMetrics.depth)
            }
            .padding(.bottom, AppControlMetrics.depth)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// 小尺寸工具按钮共用凸起底边，减弱动态效果时不添加按压动画。
struct ToyIconButtonStyle: ButtonStyle {
    var isPrimary = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .heavy))
            .foregroundStyle(isPrimary ? AppTheme.onAccent : AppTheme.secondary)
            .frame(minWidth: AppControlMetrics.iconSize, minHeight: AppControlMetrics.iconSize)
            .background(isPrimary ? AppTheme.accent : AppTheme.inset,
                        in: RoundedRectangle(cornerRadius: AppControlMetrics.iconCorner))
            .overlay {
                RoundedRectangle(cornerRadius: AppControlMetrics.iconCorner)
                    .strokeBorder(isPrimary ? AppTheme.accent : AppTheme.line, lineWidth: 2)
            }
            .offset(y: configuration.isPressed ? AppControlMetrics.iconDepth : 0)
            .background {
                RoundedRectangle(cornerRadius: AppControlMetrics.iconCorner)
                    .fill(isPrimary ? AppTheme.accentEdge : AppTheme.line)
                    .offset(y: AppControlMetrics.iconDepth)
            }
            .padding(.bottom, AppControlMetrics.iconDepth)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
