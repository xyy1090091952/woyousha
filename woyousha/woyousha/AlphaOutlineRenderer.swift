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
                         maskMaxDimension: CGFloat? = nil, roundingRadius: CGFloat = 0) -> CGImage? {
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
        let rounding = max(0, roundingRadius) * factor
        dilation.radius = Float(max(0, radius) * factor + rounding)
        guard let expanded = dilation.outputImage else { return nil }
        let rounded: CIImage
        if rounding > 0 {
            // 先多扩一点，再圆形收缩，填平轮廓的小缺口和细碎尖角。
            // 只处理小遮罩，照片本身不模糊；家具默认不增加这一步。
            let erosion = CIFilter.morphologyMinimum()
            erosion.inputImage = expanded
            erosion.radius = Float(rounding)
            guard let output = erosion.outputImage else { return nil }
            rounded = output
        } else {
            rounded = expanded
        }
        let fullMask = rounded.transformed(by: CGAffineTransform(scaleX: 1 / factor, y: 1 / factor))

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

    /// 只采样边缘的小透明度图，避免为了判断普通照片而扫描整张图片。
    static func hasTransparentBoundary(_ image: CGImage) -> Bool {
        var pixels = [UInt8](repeating: 0, count: 64)
        let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: 4, height: 4,
                                          bitsPerComponent: 8, bytesPerRow: 16,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: 4, height: 4))
            return true
        }
        guard rendered else { return false }
        return [0, 1, 2, 3, 4, 7, 8, 11, 12, 13, 14, 15].contains { pixels[$0 * 4 + 3] < 240 }
    }

    /// 只用于小缩略图：忽略几乎不可见的 alpha 噪点，保留主体和白边。
    static func trimmingTransparentPadding(_ image: CGImage, alphaThreshold: UInt8 = 8) -> CGImage? {
        let width = image.width, height = image.height
        let rowBytes = width * 4
        var pixels = [UInt8](repeating: 0, count: rowBytes * height)
        let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: rowBytes,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else { return nil }
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[y * rowBytes + x * 4 + 3] > alphaThreshold {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return image.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))
    }
}
