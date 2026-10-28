import SwiftUI
import SwiftData
import PhotosUI
import Observation

/// 单一状态来源：相册加载、抠图和保存互不抢写，并忽略已经取消的图片任务。
@MainActor @Observable
final class ItemEditorModel {
    enum PhotoState {
        case empty, loading, processing, ready, original
    }

    var draft: ItemDraft
    private(set) var image: UIImage?
    private(set) var photoState: PhotoState = .empty
    private(set) var isSaving = false
    var errorMessage: String?

    private let item: Item?
    private var photoTask: Task<Void, Never>?
    private var photoRevision = UUID()
    private var imageChanged = false

    init(item: Item?, defaultContainer: Container?) {
        self.item = item
        draft = ItemDraft(item: item, defaultContainer: defaultContainer)
        image = item?.imageData.flatMap(UIImage.init(data:))
        if image != nil { photoState = .ready }
    }

    var isProcessing: Bool { photoState == .loading || photoState == .processing }
    var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing && !isSaving
    }

    var photoMessage: String {
        switch photoState {
        case .empty: return "照片选填，拍照后会自动制作贴纸"
        case .loading: return "正在读取照片…"
        case .processing: return "正在制作贴纸…"
        case .ready: return "照片已准备好"
        case .original: return "暂时无法分离主体，已保留原图"
        }
    }

    func selectPhoto(_ selection: PhotosPickerItem?) {
        guard let selection else { return }
        let revision = beginPhotoChange()
        photoState = .loading
        photoTask = Task {
            do {
                guard let data = try await selection.loadTransferable(type: Data.self),
                      let loadedImage = UIImage(data: data) else {
                    throw PhotoError.unreadable
                }
                guard isCurrent(revision) else { return }
                await process(loadedImage, revision: revision)
            } catch {
                guard isCurrent(revision) else { return }
                photoState = image == nil ? .empty : .ready
                errorMessage = "无法读取这张照片，请重新选择。"
            }
        }
    }

    func selectCameraImage(_ image: UIImage) {
        let revision = beginPhotoChange()
        photoTask = Task { await process(image, revision: revision) }
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
        photoRevision = UUID()
        if isProcessing { photoState = image == nil ? .empty : (imageChanged ? .original : .ready) }
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
        return photoRevision
    }

    private func isCurrent(_ revision: UUID) -> Bool {
        !Task.isCancelled && revision == photoRevision
    }

    private func process(_ input: UIImage, revision: UUID) async {
        guard isCurrent(revision) else { return }
        photoState = .processing
        let resized = await Task.detached(priority: .userInitiated) {
            ImageUtils.resizeImage(input)
        }.value
        guard isCurrent(revision) else { return }
        image = resized
        imageChanged = true
        let cutout = await ImageUtils.removeBackground(from: resized)
        guard isCurrent(revision) else { return }
        if let cutout {
            let sticker = await Task.detached(priority: .userInitiated) {
                ImageUtils.addWhiteBorder(to: cutout) ?? cutout
            }.value
            guard isCurrent(revision) else { return }
            image = sticker
            photoState = .ready
        } else {
            image = resized
            photoState = .original
        }
    }

    private enum PhotoError: Error { case unreadable }
}
