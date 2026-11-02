import SwiftUI
import UIKit

/// 真正描边的圆体文字：数量和名称复用一个 UILabel，不叠加十几层文字。
struct StickerOutlinedText: UIViewRepresentable {
    let text: String
    let pointSize: CGFloat
    var lineLimit = 1
    var maximumWidth: CGFloat?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeUIView(context: Context) -> StickerStrokeLabel {
        let label = StickerStrokeLabel()
        label.backgroundColor = .clear
        label.textAlignment = .center
        label.isAccessibilityElement = false // 外层贴纸统一读出名称和数量。
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: StickerStrokeLabel, context: Context) {
        let base = UIFont.systemFont(ofSize: pointSize, weight: .heavy)
        let rounded = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        let font = UIFontMetrics(forTextStyle: .headline).scaledFont(
            for: UIFont(descriptor: rounded, size: pointSize),
            compatibleWith: label.traitCollection
        )
        label.numberOfLines = lineLimit
        label.font = font
        label.adjustsFontSizeToFitWidth = lineLimit == 1
        label.minimumScaleFactor = 0.5
        label.lineBreakMode = .byTruncatingTail
        label.outlineInset = ceil(StickerStyle.textOutlineWidth) + 1
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: UIColor(AppTheme.text)
        ])
        label.invalidateIntrinsicContentSize()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: StickerStrokeLabel, context: Context) -> CGSize? {
        let width = min(proposal.width ?? .greatestFiniteMagnitude, maximumWidth ?? .greatestFiniteMagnitude)
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }
}

/// 为文字白边留空间，三位数和两行名称的描边不会被 UILabel 的边界裁掉。
final class StickerStrokeLabel: UILabel {
    var outlineInset: CGFloat = 5

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + outlineInset * 2, height: size.height + outlineInset * 2)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let available = CGSize(width: max(1, size.width - outlineInset * 2),
                               height: max(1, size.height - outlineInset * 2))
        let measured = super.sizeThatFits(available)
        return CGSize(width: min(size.width, measured.width + outlineInset * 2),
                      height: measured.height + outlineInset * 2)
    }

    override func drawText(in rect: CGRect) {
        guard let attributedText, attributedText.length > 0, let font else { return }
        let contentRect = rect.insetBy(dx: outlineInset, dy: outlineInset)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = textAlignment
        paragraph.lineBreakMode = numberOfLines == 1 ? lineBreakMode : .byWordWrapping
        var attributes = attributedText.attributes(at: 0, effectiveRange: nil)
        var drawingFont = font
        if adjustsFontSizeToFitWidth {
            let width = (attributedText.string as NSString).size(withAttributes: [.font: font]).width
            if width > contentRect.width {
                let factor = max(minimumScaleFactor, contentRect.width / max(1, width))
                drawingFont = font.withSize(font.pointSize * factor)
            }
        }
        attributes[.font] = drawingFont
        attributes[.paragraphStyle] = paragraph
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine]

        // 白色描边位于字形内外两侧，最后再画深色字芯，避免粗白边把数字吃成细线。
        var outline = attributes
        outline[.strokeColor] = UIColor.white
        outline[.strokeWidth] = -100 * StickerStyle.textOutlineWidth / drawingFont.pointSize
        UIGraphicsGetCurrentContext()?.setLineJoin(.round)
        NSAttributedString(string: attributedText.string, attributes: outline)
            .draw(with: contentRect, options: options, context: nil)
        NSAttributedString(string: attributedText.string, attributes: attributes)
            .draw(with: contentRect, options: options, context: nil)
    }
}
