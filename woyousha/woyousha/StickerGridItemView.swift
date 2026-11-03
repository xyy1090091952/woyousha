import SwiftUI

struct StickerGridItemView: View {
    let item: Item
    var height: CGFloat = 120
    @State private var thumbnail: StickerThumbnail?

    // 使用 UUID 固定贴纸倾斜角度，改名字或数量时图片不会跳动。
    private var rotationAngle: Double {
        StickerStyle.rotationAngle(for: item.id)
    }

    var body: some View {
        VStack(spacing: StickerStyle.nameSpacing) {
            GeometryReader { geometry in
                if let thumbnail {
                    let size = StickerStyle.imageSize(
                        thumbnail.image.size, fitting: CGSize(width: geometry.size.width, height: height),
                        visibleCoverage: thumbnail.visibleCoverage, rotationDegrees: rotationAngle
                    )
                    let groupSize = StickerStyle.groupSize(
                        imageSize: size, viewport: CGSize(width: geometry.size.width, height: height),
                        hasQuantity: item.quantity > 1
                    )
                    Image(uiImage: thumbnail.image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width, height: size.height)
                        .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 4)
                        .frame(width: groupSize.width, height: groupSize.height)
                        .overlay(alignment: .topTrailing) { quantityLabel(availableWidth: groupSize.width) }
                        // 数量和图像作为同一张贴纸轻微倾斜，名称保持水平便于阅读。
                        .rotationEffect(.degrees(rotationAngle))
                        .frame(width: geometry.size.width, height: height)
                } else {
                    Image(systemName: item.category.symbol)
                        .font(.system(size: height * 0.35, weight: .bold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: geometry.size.width, height: height)
                        .overlay(alignment: .topTrailing) { quantityLabel(availableWidth: geometry.size.width) }
                }
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            // 名称直接占满整列，只有整列宽度都放不下两行时才出现省略号。
            StickerOutlinedText(text: item.name, pointSize: StickerStyle.nameFontSize(height: height),
                                lineLimit: 2, fillsProposedWidth: true)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(StickerStyle.cellPadding)
        // 明确占满网格给出的列宽，避免 UIKit 文字的较小理想宽度把图片区域一起压小。
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name)，\(item.quantity) 件")
        .task(id: item.thumbnailData) {
            // 图片改变才重新加载。数量、名字或网格缩放变化复用缓存，不重新抠图。
            thumbnail = nil
            guard let data = item.thumbnailData else { return }
            let result = await StickerThumbnailStore.thumbnail(id: item.id, data: data)
            guard !Task.isCancelled else { return }
            thumbnail = result
        }
    }

    @ViewBuilder
    private func quantityLabel(availableWidth: CGFloat) -> some View {
        if item.quantity > 1 {
            StickerOutlinedText(
                text: "×\(item.quantity)", pointSize: StickerStyle.quantityFontSize(height: height),
                maximumWidth: max(1, availableWidth)
            )
                .fixedSize()
                .allowsHitTesting(false)
        }
    }
}

#Preview {
    StickerGridItemView(item: Item(name: "蓝色保温杯", category: .other, quantity: 2))
        .padding()
        .background(DotGridBackground())
}
