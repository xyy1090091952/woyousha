import SwiftData
import Foundation

/// 页面只编辑草稿，点击保存才更新数据库，取消不会改动原物品。
struct ItemDraft {
    var name = ""
    var category: Category = .other
    var quantity = 1
    var location = ""
    var note = ""
    var container: Container?
    var imageData: Data?
    var thumbnailData: Data?

    init(item: Item? = nil, defaultContainer: Container? = nil) {
        container = item?.container ?? defaultContainer
        guard let item else { return }
        name = item.name
        category = item.category
        quantity = item.quantity
        location = item.location
        note = item.note
        imageData = item.imageData
        thumbnailData = item.thumbnailData
    }

    func apply(to item: Item, normalizeText: Bool = true) {
        item.name = normalizeText ? name.trimmingCharacters(in: .whitespacesAndNewlines) : name
        item.category = category
        item.quantity = quantity
        item.location = normalizeText ? location.trimmingCharacters(in: .whitespacesAndNewlines) : location
        item.note = normalizeText ? note.trimmingCharacters(in: .whitespacesAndNewlines) : note
        item.container = container
        item.imageData = imageData
        item.thumbnailData = thumbnailData
    }
}

@MainActor
enum ItemRepository {
    enum ValidationError: Error { case invalidName, invalidQuantity }

    static func save(_ draft: ItemDraft, editing item: Item?, in context: ModelContext) throws {
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidName
        }
        guard ItemLimits.quantityRange.contains(draft.quantity) else { throw ValidationError.invalidQuantity }
        let target = item ?? Item()
        let previous = ItemDraft(item: target)
        let previousDate = target.updatedDate
        let previousStatus = target.aiStatusRawValue
        let previousRequestDate = target.aiRequestDate
        if item == nil { context.insert(target) }
        draft.apply(to: target)
        target.updatedDate = Date()
        target.aiStatus = .none
        target.aiRequestDate = nil

        do {
            try context.save()
        } catch {
            // 仅恢复本次编辑，避免 rollback 撤销同一上下文中的其他操作。
            if item == nil {
                context.delete(target)
            } else {
                previous.apply(to: target, normalizeText: false)
                target.updatedDate = previousDate
                target.aiStatusRawValue = previousStatus
                target.aiRequestDate = previousRequestDate
            }
            throw error
        }
    }

    /// 保留旧数据库字段，只清除已经停用的识别状态，旧物品可立即编辑。
    static func clearDisabledRecognition(in items: [Item], context: ModelContext) throws {
        guard !ItemRecognitionService.provider.isEnabled else { return }
        let staleItems = items.filter { $0.aiStatus != .none || $0.aiRequestDate != nil }
        guard !staleItems.isEmpty else { return }
        let previous = staleItems.map { ($0, $0.aiStatusRawValue, $0.aiRequestDate) }
        for item in staleItems {
            item.aiStatus = .none
            item.aiRequestDate = nil
        }
        do {
            try context.save()
        } catch {
            for (item, status, date) in previous {
                item.aiStatusRawValue = status
                item.aiRequestDate = date
            }
            throw error
        }
    }
}
