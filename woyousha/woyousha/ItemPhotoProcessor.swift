import Foundation
import UIKit
import Vision
import OSLog

nonisolated enum PhotoProcessingSettings {
    static let imageDimension: CGFloat = 1024
    static let analysisDimension: CGFloat = 768
    static let subjectCropPadding: CGFloat = 8
    static let outlineMaskDimension: CGFloat = 256
    static let borderThickness: CGFloat = 14
    static let borderRoundingRadius: CGFloat = 4
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
        let finishedUptime: TimeInterval = PhotoPerformanceTrace.now
    }
    enum ProcessingError: Error { case unreadable }
    private static let logger = Logger(subsystem: "com.OGS.woyousha", category: "PhotoProcessing")

    static func process(_ source: Source,
                        trace: PhotoPerformanceTrace = PhotoPerformanceTrace(),
                        onUpdate: @escaping @MainActor @Sendable (Stage, UIImage) -> Void) async throws -> Result {
        trace.recordInputDelivery()
        let cancellation = VisionCancellation()
        let submitted = PhotoPerformanceTrace.now
        let worker = Task.detached(priority: .userInitiated) {
            trace.record(.workerScheduling, milliseconds: (PhotoPerformanceTrace.now - submitted) * 1000)
            logger.info("Photo worker began")
            try Task.checkCancellation()
            let prepared = trace.measure(.decode) {
                autoreleasepool {
                    switch source {
                    case .data(let data): return ImageUtils.downsample(data)
                    case .image(let image): return ImageUtils.resizeImage(image)
                    }
                }
            }
            guard let prepared else { throw ProcessingError.unreadable }
            trace.setPreparedSize(width: Int(prepared.size.width), height: Int(prepared.size.height))
            try Task.checkCancellation()
            var deliveryStarted = PhotoPerformanceTrace.now
            logger.info("Original preview delivery began")
            await onUpdate(.separating, prepared)
            trace.record(.previewDelivery, milliseconds: (PhotoPerformanceTrace.now - deliveryStarted) * 1000)
            logger.info("Original preview delivery ended")
            try Task.checkCancellation()
            logger.info("Vision request creation began")
            let request = trace.measure(.requestCreation) { VNGenerateForegroundInstanceMaskRequest() }
            logger.info("Vision request creation ended")
            cancellation.install(request)
            defer { cancellation.clear() }
            try Task.checkCancellation()
            let cutout: UIImage?
            do {
                cutout = try autoreleasepool {
                    try ImageUtils.removeBackground(from: prepared, request: request, trace: trace)
                }
            } catch {
                try Task.checkCancellation()
                logger.notice("Foreground separation unavailable: \(error.localizedDescription, privacy: .public)")
                logPerformance(trace, separated: false)
                return Result(image: prepared, separated: false)
            }
            try Task.checkCancellation()
            guard let cutout else {
                logPerformance(trace, separated: false)
                return Result(image: prepared, separated: false)
            }
            deliveryStarted = PhotoPerformanceTrace.now
            logger.info("Cutout preview delivery began")
            await onUpdate(.finishing, cutout)
            trace.record(.cutoutDelivery, milliseconds: (PhotoPerformanceTrace.now - deliveryStarted) * 1000)
            logger.info("Cutout preview delivery ended")
            try Task.checkCancellation()
            let sticker = trace.measure(.outline) {
                autoreleasepool { ImageUtils.addWhiteBorder(to: cutout) ?? cutout }
            }
            try Task.checkCancellation()
            logPerformance(trace, separated: true)
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

    private static func logPerformance(_ trace: PhotoPerformanceTrace, separated: Bool) {
        let snapshot = trace.snapshot(separated: separated)
        for entry in snapshot.entries {
            logger.info("Photo stage \(entry.stage.rawValue, privacy: .public): \(Int(entry.milliseconds)) ms")
        }
        logger.info("Photo total: \(Int(snapshot.totalMilliseconds)) ms")
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
