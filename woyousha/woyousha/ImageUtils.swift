import UIKit
import ImageIO
import Vision
import CoreImage

/// 纯图片工具不绑定主线程；读取、缩放、Vision 和编码由调用方放到后台。
nonisolated enum ImageUtils {
    /// 从压缩数据直接解码小图，不先展开手机拍出的整张大照片。
    /// ImageIO 同时应用 EXIF 方向，输出固定为 1 倍像素。
    static func downsample(_ data: Data, maxDimension: CGFloat = PhotoProcessingSettings.imageDimension) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [
            kCGImageSourceShouldCache: false
        ] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image, scale: 1, orientation: .up)
    }

    /// 已有 UIImage 的兼容入口。保存时继续复用，保留透明背景和统一方向。
    static func resizeImage(_ image: UIImage, maxDimension: CGFloat = PhotoProcessingSettings.imageDimension) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let longest = max(size.width, size.height)
        if longest <= maxDimension && image.scale == 1 && image.imageOrientation == .up { return image }
        let ratio = min(1, maxDimension / longest)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// 输入已经统一方向。轮廓细化限制在 768px，1024px 主体只进行一次合成。
    /// 推理与精细边缘分别计时，不能把它们笼统归为一次“抠图”。
    static func removeBackground(from image: UIImage, request: VNGenerateForegroundInstanceMaskRequest,
                                 trace: PhotoPerformanceTrace) throws -> UIImage? {
        #if targetEnvironment(simulator)
        return nil // 模拟器保留原图，主体分离在真机验证。
        #else
        guard let cgImage = image.cgImage else { return nil }
        let analysisImage = trace.measure(.analysisResize) {
            resizeImage(image, maxDimension: PhotoProcessingSettings.analysisDimension)
        }
        guard let analysisCGImage = analysisImage.cgImage else { return nil }
        trace.setAnalysisSize(width: analysisCGImage.width, height: analysisCGImage.height)
        try Task.checkCancellation()
        let handler = trace.measure(.handlerCreation) {
            VNImageRequestHandler(cgImage: analysisCGImage, orientation: .up)
        }
        try trace.measure(.vision) { try handler.perform([request]) }
        try Task.checkCancellation()
        guard let result = request.results?.first, !result.allInstances.isEmpty else { return nil }
        let pixels = try trace.measure(.refinement) {
            try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
        }
        try Task.checkCancellation()
        let cutout = trace.measure(.composite) {
            ForegroundMaskRenderer.cutout(source: cgImage, softMask: pixels,
                                         instanceMask: result.instanceMask,
                                         padding: PhotoProcessingSettings.subjectCropPadding)
        }
        try Task.checkCancellation()
        guard let cutout else { return nil }
        return UIImage(cgImage: cutout, scale: 1, orientation: .up)
        #endif
    }

    static func addWhiteBorder(to image: UIImage, thickness: CGFloat = PhotoProcessingSettings.borderThickness) -> UIImage? {
        guard let source = image.cgImage,
              let result = AlphaOutlineRenderer.outlined(
                source,
                radius: thickness,
                padding: ceil(thickness) + 2,
                maskMaxDimension: PhotoProcessingSettings.outlineMaskDimension,
                roundingRadius: PhotoProcessingSettings.borderRoundingRadius
              ) else { return nil }
        return UIImage(cgImage: result, scale: image.scale, orientation: image.imageOrientation)
    }
}
