import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// 只使用图片的透明度生成白色轮廓，照片贴纸和家具选中共用。
/// CIContext 可以跨线程复用；滤镜是每次调用的局部变量，不共享可变状态。
nonisolated enum AlphaOutlineRenderer {
    static let context = CIContext(options: [.workingColorSpace: NSNull()])

    /// padding 为 0 时保持原画布大小，适合已经留好透明边缘的家具。
    /// 大照片只在小尺寸遮罩上扩边，主体本身仍保持原始清晰度。
    static func outlined(_ image: CGImage, radius: CGFloat, padding: CGFloat = 0,
                         maskMaxDimension: CGFloat? = nil) -> CGImage? {
        let source = CIImage(cgImage: image)
        let extent = source.extent.insetBy(dx: -padding, dy: -padding).integral
        let transparent = CIImage(color: .clear).cropped(to: extent)
        let canvas = source.composited(over: transparent).cropped(to: extent)
        let longest = max(extent.width, extent.height)
        let factor = maskMaxDimension.map { min(1, $0 / longest) } ?? 1
        let smallCanvas = canvas.transformed(by: CGAffineTransform(scaleX: factor, y: factor))

        // Alpha 转灰度，背景为黑色，主体为白色。忽略 RGB，白色家具也能正确描边。
        let mask = CIFilter.colorMatrix()
        mask.inputImage = smallCanvas
        let alpha = CIVector(x: 0, y: 0, z: 0, w: 1)
        mask.rVector = alpha
        mask.gVector = alpha
        mask.bVector = alpha
        mask.aVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        mask.biasVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        guard let gray = mask.outputImage?.cropped(to: smallCanvas.extent) else { return nil }

        // 圆形扩边沿真实轮廓生长，不画矩形框，也不使用多层阴影模拟。
        let dilation = CIFilter.morphologyMaximum()
        dilation.inputImage = gray
        dilation.radius = Float(max(0, radius) * factor)
        guard let expanded = dilation.outputImage else { return nil }
        let fullMask = expanded.transformed(by: CGAffineTransform(scaleX: 1 / factor, y: 1 / factor))

        let white = CIFilter.colorMatrix()
        white.inputImage = fullMask
        let zero = CIVector(x: 0, y: 0, z: 0, w: 0)
        white.rVector = zero
        white.gVector = zero
        white.bVector = zero
        white.aVector = CIVector(x: 1, y: 0, z: 0, w: 0)
        white.biasVector = CIVector(x: 1, y: 1, z: 1, w: 0)
        guard let outline = white.outputImage?.cropped(to: extent) else { return nil }
        return context.createCGImage(source.composited(over: outline), from: extent)
    }
}
