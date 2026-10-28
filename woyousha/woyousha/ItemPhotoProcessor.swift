import Foundation
import UIKit
import Vision
import OSLog

nonisolated enum PhotoProcessingSettings {
    static let imageDimension: CGFloat = 1024
    static let outlineMaskDimension: CGFloat = 256
    static let borderThickness: CGFloat = 12
    static let slowFeedbackDelay: TimeInterval = 2.5
}

/// 一条后台流水线负责缩图、分离和描边，主线程只接收阶段与预览。
nonisolated enum ItemPhotoProcessor {
    enum Source: Sendable {
        case data(Data), image(UIImage)
    }
    enum Stage: Sendable { case separating, finishing }
    struct Result: Sendable {
        let image: UIImage
        let separated: Bool
    }
    enum ProcessingError: Error { case unreadable }
    private static let logger = Logger(subsystem: "com.OGS.woyousha", category: "PhotoProcessing")

    static func process(_ source: Source,
                        onUpdate: @escaping @MainActor @Sendable (Stage, UIImage) -> Void) async throws -> Result {
        let cancellation = VisionCancellation()
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            var started = Date()
            let prepared = autoreleasepool {
                switch source {
                case .data(let data): return ImageUtils.downsample(data)
                case .image(let image): return ImageUtils.resizeImage(image)
                }
            }
            guard let prepared else { throw ProcessingError.unreadable }
            try Task.checkCancellation()
            logDuration("decode", since: started)
            await onUpdate(.separating, prepared)
            try Task.checkCancellation()
            started = Date()
            let request = VNGenerateForegroundInstanceMaskRequest()
            cancellation.install(request)
            defer { cancellation.clear() }
            try Task.checkCancellation()
            let cutout: UIImage?
            do {
                cutout = try autoreleasepool { try ImageUtils.removeBackground(from: prepared, request: request) }
            } catch {
                try Task.checkCancellation()
                logger.notice("Foreground separation unavailable: \(error.localizedDescription, privacy: .public)")
                return Result(image: prepared, separated: false)
            }
            try Task.checkCancellation()
            logDuration("separate", since: started)
            guard let cutout else { return Result(image: prepared, separated: false) }
            await onUpdate(.finishing, cutout)
            try Task.checkCancellation()
            started = Date()
            let sticker = autoreleasepool { ImageUtils.addWhiteBorder(to: cutout) ?? cutout }
            try Task.checkCancellation()
            logDuration("outline", since: started)
            return Result(image: sticker, separated: true)
        }
        // detached 任务不会自动继承父任务的取消，必须显式传递到任务和 Vision。
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
            cancellation.cancel()
        }
    }

    private static func logDuration(_ stage: String, since start: Date) {
        let milliseconds = Int(Date().timeIntervalSince(start) * 1000)
        logger.info("Photo stage \(stage, privacy: .public): \(milliseconds) ms")
    }
}

/// 锁只保护请求的登记/取消；Vision 运算始终在后台，cancel 在锁外调用。
/// 先取消、后登记的竞态也会立即取消请求，不让旧照片继续抢占计算资源。
nonisolated private final class VisionCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var request: VNRequest?
    private var isCancelled = false

    func install(_ request: VNRequest) {
        lock.lock()
        self.request = request
        let shouldCancel = isCancelled
        lock.unlock()
        if shouldCancel { request.cancel() }
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let pending = request
        lock.unlock()
        pending?.cancel()
    }

    func clear() {
        lock.lock()
        request = nil
        lock.unlock()
    }
}
