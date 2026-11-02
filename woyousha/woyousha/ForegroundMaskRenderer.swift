import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo

/// 小图负责分析边缘，大图负责保留物品颜色和细节；两者只合成一次。
nonisolated enum ForegroundMaskRenderer {
    static func cutout(source: CGImage, softMask: CVPixelBuffer,
                       instanceMask: CVPixelBuffer, padding: CGFloat) -> CGImage? {
        let original = CIImage(cgImage: source)
        let mask = CIImage(cvPixelBuffer: softMask)
        guard mask.extent.width > 0, mask.extent.height > 0 else { return nil }
        let fullMask = mask.transformed(by: CGAffineTransform(
            scaleX: original.extent.width / mask.extent.width,
            y: original.extent.height / mask.extent.height
        ))
        let blend = CIFilter.blendWithMask()
        blend.inputImage = original
        blend.backgroundImage = CIImage(color: .clear).cropped(to: original.extent)
        blend.maskImage = fullMask
        guard let output = blend.outputImage else { return nil }
        // 只扫描 Vision 的小标签图，不把 1024px 原图读回 CPU 扫透明边。
        let crop = foregroundExtent(in: instanceMask, imageExtent: original.extent, padding: padding)
            ?? original.extent
        return AlphaOutlineRenderer.context.createCGImage(output, from: crop)
    }

    /// Vision 标签图为 UInt8，0 表示背景。行号从上往下，Core Image 的 y 从下往上。
    static func foregroundExtent(in mask: CVPixelBuffer, imageExtent: CGRect,
                                 padding: CGFloat) -> CGRect? {
        guard CVPixelBufferGetPixelFormatType(mask) == kCVPixelFormatType_OneComponent8,
              CVPixelBufferLockBaseAddress(mask, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let width = CVPixelBufferGetWidth(mask), height = CVPixelBufferGetHeight(mask)
        let rowBytes = CVPixelBufferGetBytesPerRow(mask)
        let pixels = base.assumingMemoryBound(to: UInt8.self)
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            let row = pixels.advanced(by: y * rowBytes)
            // 边界只需要每行最左/最右的主体，不逐个遍历主体内部的所有像素。
            var left = 0
            while left < width && row[left] == 0 { left += 1 }
            guard left < width else { continue }
            var right = width - 1
            while right > left && row[right] == 0 { right -= 1 }
            if left < minX { minX = left }
            if right > maxX { maxX = right }
            if minY == height { minY = y }
            maxY = y
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let scaleX = imageExtent.width / CGFloat(width)
        let scaleY = imageExtent.height / CGFloat(height)
        let rect = CGRect(
            x: imageExtent.minX + CGFloat(minX) * scaleX,
            y: imageExtent.minY + CGFloat(height - maxY - 1) * scaleY,
            width: CGFloat(maxX - minX + 1) * scaleX,
            height: CGFloat(maxY - minY + 1) * scaleY
        )
        // 给软边留出余量，防止标签图比细化后的边缘稍小而切掉头发、细线等。
        return rect.insetBy(dx: -padding, dy: -padding).integral.intersection(imageExtent)
    }
}
