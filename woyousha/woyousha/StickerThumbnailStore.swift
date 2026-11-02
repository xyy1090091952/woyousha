import UIKit

/// 图片与测量结果一起缓存，SwiftUI 布局时只算尺寸，不再次扫描透明像素。
nonisolated struct StickerThumbnail {
    let image: UIImage
    let visibleCoverage: CGFloat
}

/// 只修饰显示用的小图，不改写数据库里的原照片；已有贴纸无需重新拍照。
@MainActor
enum StickerThumbnailStore {
    private final class Entry {
        let data: Data
        let thumbnail: StickerThumbnail
        init(data: Data, thumbnail: StickerThumbnail) { self.data = data; self.thumbnail = thumbnail }
    }

    private static let cache: NSCache<NSString, Entry> = {
        let cache = NSCache<NSString, Entry>()
        cache.countLimit = StickerStyle.thumbnailCacheCount
        cache.totalCostLimit = StickerStyle.thumbnailCacheBytes
        return cache
    }()

    static func thumbnail(id: UUID, data: Data) async -> StickerThumbnail? {
        let key = id.uuidString as NSString
        if let entry = cache.object(forKey: key), entry.data == data { return entry.thumbnail }
        let worker = Task.detached(priority: .userInitiated) {
            guard !Task.isCancelled else { return Optional<StickerThumbnail>.none }
            return autoreleasepool { StickerThumbnailRenderer.render(data) }
        }
        let result = await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            worker.cancel()
        }
        guard !Task.isCancelled, let result else { return nil }
        let cost = (result.image.cgImage?.bytesPerRow ?? 0) * (result.image.cgImage?.height ?? 0) + data.count
        cache.setObject(Entry(data: data, thumbnail: result), forKey: key, cost: cost)
        return result
    }
}

nonisolated enum StickerThumbnailRenderer {
    static func render(_ data: Data) -> StickerThumbnail? {
        guard let image = ImageUtils.downsample(data, maxDimension: StickerStyle.thumbnailDimension),
              let source = image.cgImage,
              let prepared = StickerSubjectAnalyzer.prepare(source) else { return nil }
        guard !Task.isCancelled else { return nil }
        return StickerThumbnail(image: UIImage(cgImage: prepared.image, scale: 1, orientation: .up),
                                visibleCoverage: prepared.visibleCoverage)
    }
}
