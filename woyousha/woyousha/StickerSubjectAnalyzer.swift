import CoreGraphics
import Foundation

/// 列表小图的主体测量，不运行识别模型，也不修改保存的照片。
nonisolated enum StickerSubjectAnalyzer {
    struct PreparedImage {
        let image: CGImage
        let visibleCoverage: CGFloat
    }

    struct Subject {
        let image: CGImage
        let hasTransparency: Bool
    }

    /// 共用的显示小图入口：裁主体、统一像素尺寸、白边、面积测量按顺序执行一次。
    static func prepare(_ image: CGImage) -> PreparedImage? {
        guard !Task.isCancelled, let subject = subject(in: image) else { return nil }
        guard subject.hasTransparency else { return PreparedImage(image: image, visibleCoverage: 1) }
        let normalized = normalized(subject.image) ?? subject.image
        let decorated = AlphaOutlineRenderer.outlined(
            normalized, radius: StickerStyle.thumbnailOutlineRadius,
            padding: StickerStyle.thumbnailPadding, roundingRadius: StickerStyle.thumbnailRoundingRadius
        ) ?? normalized // 白边失败仍使用裁紧的主体，不退回大透明画布。
        guard !Task.isCancelled else { return nil }
        return PreparedImage(image: decorated, visibleCoverage: visibleCoverage(of: decorated))
    }

    /// 连接起来的像素视作一个主体。忽略孤立噪点，但保留耳机左右两只等有意义的分离部件。
    static func subject(in image: CGImage) -> Subject? {
        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let bitmap = bitmap(image, pixels: &pixels) else { return nil }
        let hasTransparency = stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] < 240 }
        guard hasTransparency else { return Subject(image: image, hasTransparency: false) }

        var labels = [Int](repeating: 0, count: width * height)
        var componentAreas = [0] // 0 表示背景，真正的主体从 1 开始编号。
        var queue = [Int]()
        queue.reserveCapacity(width * height)
        for start in labels.indices {
            guard labels[start] == 0, pixels[start * 4 + 3] > StickerStyle.subjectAlphaThreshold else { continue }
            guard !Task.isCancelled else { return nil }
            let label = componentAreas.count
            labels[start] = label
            queue.removeAll(keepingCapacity: true)
            queue.append(start)
            var cursor = 0
            while cursor < queue.count {
                let index = queue[cursor]
                cursor += 1
                let x = index % width, y = index / width
                // 8 邻接能保留斜线、细肩带与耳机柄，避免把它们切成一串碎片。
                for nextY in max(0, y - 1)...min(height - 1, y + 1) {
                    for nextX in max(0, x - 1)...min(width - 1, x + 1) {
                        let next = nextY * width + nextX
                        if labels[next] == 0, pixels[next * 4 + 3] > StickerStyle.subjectAlphaThreshold {
                            labels[next] = label
                            queue.append(next)
                        }
                    }
                }
            }
            componentAreas.append(queue.count)
        }
        guard let largest = componentAreas.max(), largest > 0 else { return nil }
        // 主体很小时也保留最大部件，不会因绝对像素门槛把整个物品删掉。
        let minimumArea = min(largest, max(2, Int(ceil(CGFloat(largest) * StickerStyle.minimumComponentRatio))))
        var minX = width, minY = height, maxX = -1, maxY = -1
        for index in labels.indices where labels[index] > 0 {
            if componentAreas[labels[index]] >= minimumArea {
                let x = index % width, y = index / width
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            } else {
                // 清除被忽略的孤立点，避免裁紧后它又被放大成额外的小贴纸。
                for channel in 0..<4 { pixels[index * 4 + channel] = 0 }
            }
        }
        guard maxX >= minX, maxY >= minY, !Task.isCancelled else { return nil }
        let margin = StickerStyle.subjectCropMargin
        minX = max(0, minX - margin); minY = max(0, minY - margin)
        maxX = min(width - 1, maxX + margin); maxY = min(height - 1, maxY + margin)
        // 以被扫描的同一份 RGBA 数据裁图，避免 CGContext 与 CGImage 行方向不一致。
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cleaned = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                    bytesPerRow: width * 4, space: bitmap.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                    provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent),
              let cropped = cleaned.cropping(to: CGRect(x: minX, y: minY,
                                                       width: maxX - minX + 1, height: maxY - minY + 1)) else { return nil }
        return Subject(image: cropped, hasTransparency: true)
    }

    /// 裁紧后先统一最长边，再加固定白边；小主体不会被 4px 留白挤得更小。
    static func normalized(_ image: CGImage) -> CGImage? {
        let factor = StickerStyle.thumbnailDimension / CGFloat(max(image.width, image.height))
        let width = max(1, Int((CGFloat(image.width) * factor).rounded()))
        let height = max(1, Int((CGFloat(image.height) * factor).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// 用 alpha 的总和估算实际可见面积，空心、圆形与分离部件不再按整张矩形计算大小。
    static func visibleCoverage(of image: CGImage) -> CGFloat {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        guard bitmap(image, pixels: &pixels) != nil else { return 1 }
        let alphaSum = stride(from: 3, to: pixels.count, by: 4).reduce(0) { $0 + Int(pixels[$1]) }
        return CGFloat(alphaSum) / (255 * CGFloat(image.width * image.height))
    }

    private static func bitmap(_ image: CGImage, pixels: inout [UInt8]) -> CGImage? {
        pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return context.makeImage()
        }
    }
}
