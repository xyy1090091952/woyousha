import SwiftUI

/// 贴纸拖动删除共用品牌底色与圆角，只在进入删除区时强调危险动作。
struct StickerDeleteZone: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing:8) {
            HStack(spacing:12) {
                Image(systemName:isActive ? "trash.fill":"trash")
                    .font(.system(size:22,weight:.semibold))
                    .frame(width:46,height:46)
                    .background(isActive ? AppTheme.destructiveInset:AppTheme.inset,
                                in:RoundedRectangle(cornerRadius:AppControlMetrics.iconCorner))
                VStack(alignment:.leading,spacing:3) {
                    Text(isActive ? "松手删除":"拖到这里删除")
                        .font(.system(.subheadline,design:.rounded,weight:.bold))
                    Text(isActive ? "移出此区域即可取消":"只删除拖动中的物品")
                        .font(.caption).foregroundStyle(AppTheme.secondaryText)
                }
                Spacer(minLength:0)
            }.foregroundStyle(isActive ? AppTheme.destructive:AppTheme.secondary)
                .padding(.horizontal,18).padding(.vertical,12)
                .background(AppTheme.surface,in:RoundedRectangle(cornerRadius:AppControlMetrics.corner))
                .overlay {
                    RoundedRectangle(cornerRadius:AppControlMetrics.corner)
                        .strokeBorder(isActive ? AppTheme.destructive.opacity(0.5):AppTheme.line,lineWidth:2)
                }
                .padding(.horizontal,16)
        }
        .padding(.top,12).padding(.bottom,20)
        .frame(maxWidth:.infinity)
        .background(AppTheme.background)
        .overlay(alignment:.top) { Rectangle().fill(AppTheme.line).frame(height:1) }
        .animation(reduceMotion ? nil:.easeOut(duration:0.15),value:isActive)
    }
}
