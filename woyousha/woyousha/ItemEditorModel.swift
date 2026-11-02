import SwiftUI
import SwiftData
import PhotosUI
import Observation

/// 单一状态来源：相册加载、抠图和保存互不抢写，并忽略已经取消的图片任务。
@MainActor @Observable
final class ItemEditorModel {
    enum PhotoState {
        case empty, loading, separating, finishing, ready, original, unmodified
    }

    var draft: ItemDraft
    private(set) var image: UIImage?
    private(set) var photoState: PhotoState = .empty
    private(set) var processingIsTakingLong = false
    private(set) var lastPhotoPerformance: PhotoPerformanceTrace.Snapshot?
    private(set) var isSaving = false
    var errorMessage: String?

    private let item: Item?
    @ObservationIgnored private var photoTask: Task<Void, Never>?
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?
    @ObservationIgnored private var photoRevision = UUID()
    @ObservationIgnored private var originalImage: UIImage?
    @ObservationIgnored private var previousPhotoState: PhotoState = .empty
    @ObservationIgnored private var imageChanged = false

    init(item: Item?, defaultContainer: Container?) {
        self.item = item
        draft = ItemDraft(item: item, defaultContainer: defaultContainer)
        image = item?.imageData.flatMap(UIImage.init(data:))
        lastPhotoPerformance = PhotoPerformanceStore.load()
        if image != nil { photoState = .ready }
    }

    var isProcessing: Bool {
        photoState == .loading || photoState == .separating || photoState == .finishing
    }
    var canKeepOriginalPhoto: Bool { isProcessing && originalImage != nil }
    var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing && !isSaving
    }

    var photoMessage: String {
        switch photoState {
        case .empty: return "照片选填，拍照后会自动制作贴纸"
        case .loading: return "正在读取照片…"
        case .separating: return "正在分离物品主体…"
        case .finishing: return "正在生成贴纸白边…"
        case .ready: return "照片已准备好"
        case .original: return "暂时无法分离主体，已保留原图"
        case .unmodified: return "已保留原图，可以继续填写并保存"
        }
    }

    func selectPhoto(_ selection: PhotosPickerItem?) {
        guard let selection else { return }
        let trace = PhotoPerformanceTrace()
        let revision = beginPhotoChange()
        photoTask = Task {
            do {
                let started = PhotoPerformanceTrace.now
                guard let data = try await selection.loadTransferable(type: Data.self) else {
                    throw ItemPhotoProcessor.ProcessingError.unreadable
                }
                guard isCurrent(revision) else { return }
                trace.record(.albumLoad, milliseconds: (PhotoPerformanceTrace.now - started) * 1000)
                await process(.data(data), revision: revision, trace: trace)
            } catch {
                guard isCurrent(revision) else { return }
                finishUnreadablePhoto()
            }
        }
    }

    func selectCameraData(_ data: Data, captureTiming: PhotoCaptureTiming? = nil) {
        let trace = PhotoPerformanceTrace(capture: captureTiming)
        let revision = beginPhotoChange()
        photoTask = Task { await process(.data(data), revision: revision, trace: trace) }
    }

    func selectCameraImage(_ image: UIImage) {
        let trace = PhotoPerformanceTrace()
        let revision = beginPhotoChange()
        photoTask = Task { await process(.image(image), revision: revision, trace: trace) }
    }

    /// 用户可以结束等待；取消运算后保存同一张照片的原图，不丢失表单草稿。
    func keepOriginalPhoto() {
        guard canKeepOriginalPhoto, let originalImage else { return }
        cancelPhotoTask()
        image = originalImage
        imageChanged = true
        photoState = .unmodified
    }

    func removePhoto() {
        cancelPhotoTask()
        image = nil
        draft.imageData = nil
        draft.thumbnailData = nil
        imageChanged = true
        photoState = .empty
    }

    func cancelPhotoTask() {
        photoTask?.cancel()
        photoTask = nil
        stopSlowFeedback()
        photoRevision = UUID()
        if isProcessing {
            if let originalImage {
                image = originalImage
                imageChanged = true
                photoState = .unmodified
            } else {
                photoState = image == nil ? .empty : previousPhotoState
            }
        }
        originalImage = nil
    }

    func save(in context: ModelContext) async -> Bool {
        guard canSave else { return false }
        isSaving = true
        defer { isSaving = false }
        // PNG 编码在后台进行，避免点保存时界面卡住；未换图时保留原数据。
        if imageChanged, let image {
            let fullDimension = AppTheme.Layout.imageDimension
            let thumbnailDimension = AppTheme.Layout.thumbnailDimension
            let encoded = await Task.detached(priority: .userInitiated) {
                let full = ImageUtils.resizeImage(image, maxDimension: fullDimension)
                let thumbnail = ImageUtils.resizeImage(image, maxDimension: thumbnailDimension)
                return (full.pngData(), thumbnail.pngData())
            }.value
            guard let data = encoded.0, let thumbnail = encoded.1 else {
                errorMessage = "照片保存失败，请重新选择照片后再试。"
                return false
            }
            draft.imageData = data
            draft.thumbnailData = thumbnail
        }
        do {
            try ItemRepository.save(draft, editing: item, in: context)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        } catch {
            errorMessage = "物品没有保存成功，请重试。"
            return false
        }
    }

    private func beginPhotoChange() -> UUID {
        cancelPhotoTask()
        previousPhotoState = photoState
        lastPhotoPerformance = nil
        photoState = .loading
        let revision = photoRevision
        // 只改变提示，不编造进度百分比，也不靠延时掩盖实际处理速度。
        feedbackTask = Task {
            try? await Task.sleep(for: .seconds(PhotoProcessingSettings.slowFeedbackDelay))
            guard isCurrent(revision), isProcessing else { return }
            processingIsTakingLong = true
        }
        return photoRevision
    }

    private func isCurrent(_ revision: UUID) -> Bool {
        !Task.isCancelled && revision == photoRevision
    }

    private func process(_ source: ItemPhotoProcessor.Source, revision: UUID, trace: PhotoPerformanceTrace) async {
        guard isCurrent(revision) else { return }
        do {
            let result = try await ItemPhotoProcessor.process(source, trace: trace) { [weak self] stage, preview in
                guard let self, self.isCurrent(revision) else { return }
                self.image = preview
                self.imageChanged = true
                switch stage {
                case .separating:
                    self.originalImage = preview
                    self.photoState = .separating
                case .finishing:
                    self.photoState = .finishing
                }
            }
            guard isCurrent(revision) else { return }
            trace.record(.resultDelivery, milliseconds: (PhotoPerformanceTrace.now - result.finishedUptime) * 1000)
            image = result.image
            imageChanged = true
            photoState = result.separated ? .ready : .original
            originalImage = nil
            stopSlowFeedback()
            // 通过版本检查后才保存；取消或更换照片时，旧任务不能留下误导性的用时。
            let performance = trace.snapshot(separated: result.separated)
            lastPhotoPerformance = performance
            PhotoPerformanceStore.save(performance)
        } catch {
            guard isCurrent(revision) else { return }
            finishUnreadablePhoto()
        }
    }

    private func finishUnreadablePhoto() {
        stopSlowFeedback()
        originalImage = nil
        photoState = image == nil ? .empty : previousPhotoState
        errorMessage = "无法读取这张照片，请重新选择。"
    }

    private func stopSlowFeedback() {
        feedbackTask?.cancel()
        feedbackTask = nil
        processingIsTakingLong = false
    }
}
