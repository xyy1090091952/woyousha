import SwiftUI
import UIKit

/// 真正描边的圆体文字：数量和名称复用一个 UILabel，不叠加十几层文字。
struct StickerOutlinedText: UIViewRepresentable {
    let text: String
    let pointSize: CGFloat
    var lineLimit = 1
    var maximumWidth: CGFloat?
    /// 名称占满整列宽度居中绘制；数量角标仍按文字本身大小显示。
    var fillsProposedWidth = false
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
        label.setNeedsDisplay()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: StickerStrokeLabel, context: Context) -> CGSize? {
        let width = min(proposal.width ?? .greatestFiniteMagnitude, maximumWidth ?? .greatestFiniteMagnitude)
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        // 不再把视图宽度“贴着字形”收紧：列有多宽文字就有多宽，只有整列都放不下才换行或省略。
        if fillsProposedWidth, width.isFinite, width > 0 {
            return CGSize(width: width, height: size.height)
        }
        return size
    }
}

/// 为文字白边留空间，三位数和两行名称的描边不会被 UILabel 的边界裁掉。
/// 测量和绘制共用同一套排版规则，避免“量的时候放得下、画的时候被挤到下一行再省略”。
final class StickerStrokeLabel: UILabel {
    var outlineInset: CGFloat = 5
    /// 屏幕会把视图宽度对齐到物理像素，量好的宽度可能被吃掉零点几个点，这里预留 1pt 余量。
    private static let layoutSlack: CGFloat = 1
    private static let measuringOptions: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]

    override var intrinsicContentSize: CGSize {
        let size = textSize(maximumWidth: .greatestFiniteMagnitude)
        return CGSize(width: size.width + outlineInset * 2, height: size.height + outlineInset * 2)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let measured = textSize(maximumWidth: max(1, size.width - outlineInset * 2))
        return CGSize(width: min(size.width, measured.width + outlineInset * 2),
                      height: measured.height + outlineInset * 2)
    }

    override func drawText(in rect: CGRect) {
        guard let attributedText, attributedText.length > 0 else { return }
        let contentRect = rect.insetBy(dx: outlineInset, dy: outlineInset)
        let attributes = drawingAttributes(maximumWidth: contentRect.width)
        guard let drawingFont = attributes[.font] as? UIFont else { return }
        let options = Self.measuringOptions.union(.truncatesLastVisibleLine)

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

    /// 绘制时真正使用的字体与段落：单行数量过长时等比缩小，多行名称按字换行。
    private func drawingAttributes(maximumWidth: CGFloat) -> [NSAttributedString.Key: Any] {
        guard let attributedText, attributedText.length > 0, let font else { return [:] }
        var attributes = attributedText.attributes(at: 0, effectiveRange: nil)
        var drawingFont = font
        if adjustsFontSizeToFitWidth {
            let width = (attributedText.string as NSString).size(withAttributes: [.font: font]).width
            if width > maximumWidth {
                let factor = max(minimumScaleFactor, maximumWidth / max(1, width))
                drawingFont = font.withSize(font.pointSize * factor)
            }
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = textAlignment
        paragraph.lineBreakMode = numberOfLines == 1 ? lineBreakMode : .byWordWrapping
        attributes[.font] = drawingFont
        attributes[.paragraphStyle] = paragraph
        return attributes
    }

    /// 用与绘制完全相同的参数测量文字，再按行数上限截取高度。
    private func textSize(maximumWidth: CGFloat) -> CGSize {
        guard let attributedText, attributedText.length > 0 else { return .zero }
        let attributes = drawingAttributes(maximumWidth: maximumWidth)
        let bounds = CGSize(width: maximumWidth, height: .greatestFiniteMagnitude)
        let full = (attributedText.string as NSString)
            .boundingRect(with: bounds, options: Self.measuringOptions, attributes: attributes, context: nil)
        var height = ceil(full.height)
        if numberOfLines > 0 {
            // 用 N 行占位字测出“最多 N 行”的真实高度，与绘制时的行距一致。
            let sample = Array(repeating: "国", count: numberOfLines).joined(separator: "\n") as NSString
            let limit = sample.boundingRect(with: bounds, options: Self.measuringOptions,
                                            attributes: attributes, context: nil)
            height = min(height, ceil(limit.height))
        }
        return CGSize(width: ceil(full.width) + Self.layoutSlack, height: height + Self.layoutSlack)
    }
}
