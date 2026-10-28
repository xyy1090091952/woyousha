import SwiftUI

struct StickerGridItemView: View {
    let item: Item
    var height: CGFloat = 120

    // 使用 UUID 固定贴纸倾斜角度，改名字或数量时图片不会跳动。
    private var rotationAngle: Double {
        Double(item.id.uuidString.utf8.reduce(0) { $0 + Int($1) } % 5 - 2)
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Group {
                    // 列表只读小缩略图，避免同时解码很多张大图。
                    if let data = item.thumbnailData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                            .rotationEffect(.degrees(rotationAngle))
                            .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 4)
                    } else {
                        Image(systemName: item.category.symbol)
                            .font(.system(size: height * 0.35, weight: .light))
                            .foregroundStyle(AppTheme.accent.opacity(0.65))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(AppTheme.inset.opacity(0.65), in: RoundedRectangle(cornerRadius: 22))
                    }
                }
                .frame(height: height)
                .frame(maxWidth: .infinity)
                if item.quantity > 1 {
                    Text("×\(item.quantity)")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AppTheme.surface, in: Capsule())
                        .overlay { Capsule().strokeBorder(AppTheme.line, lineWidth: 1) }
                }
            }
            Text(item.name)
                .font(.system(height < 100 ? .caption : .subheadline, design: .rounded, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(AppTheme.text)
                .frame(maxWidth: .infinity)
        }
        .padding(6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name)，\(item.quantity) 件")
    }
}

#Preview {
    StickerGridItemView(item: Item(name: "蓝色保温杯", category: .other, quantity: 2))
        .padding()
        .background(AppTheme.background)
}
