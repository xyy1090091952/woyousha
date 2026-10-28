import Foundation
import SwiftData

/// 独立存储冒烟验证，使用内存数据库，不访问手机或用户的正式数据。
@main
struct StorageCheck {
    @MainActor
    static func main() async throws {
        let schema = Schema([Item.self, Container.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let database = try ModelContainer(for: schema, configurations: [configuration])
        let context = database.mainContext
        let cabinet = Container(name: "衣柜", icon: "cabinet")
        let photoBytes = Data([1, 2, 3, 4])
        let originalDate = Date(timeIntervalSince1970: 1_700_000_000)
        let original = Item(
            name: "旧物品", imageData: photoBytes, thumbnailData: photoBytes,
            category: .clothes, quantity: 2, location: "第二层",
            createdDate: originalDate, updatedDate: originalDate,
            note: "保留原备注", container: cabinet, aiStatus: .pending
        )
        original.aiRequestDate = originalDate
        context.insert(cabinet)
        context.insert(original)
        try context.save()

        // 停用识别只清理状态，不改变物品、图片、分类、位置或日期。
        try ItemRepository.clearDisabledRecognition(in: [original], context: context)
        precondition(original.aiStatus == .none && original.aiRequestDate == nil)
        precondition(original.name == "旧物品" && original.imageData == photoBytes)
        precondition(original.category == .clothes && original.quantity == 2)
        precondition(original.location == "第二层" && original.container?.id == cabinet.id)
        precondition(original.createdDate == originalDate && original.updatedDate == originalDate)

        // 编辑草稿不会修改原物品；提交修改后保留相同 ID 和已有照片。
        var draft = ItemDraft(item: original)
        draft.name = "  新名称  "
        draft.quantity = 3
        precondition(original.name == "旧物品")
        try ItemRepository.save(draft, editing: original, in: context)
        precondition(original.name == "新名称" && original.quantity == 3)
        precondition(original.imageData == photoBytes && original.createdDate == originalDate)
        try ItemRepository.save(draft, editing: original, in: context)
        let countAfterEdit = try context.fetchCount(FetchDescriptor<Item>())
        precondition(countAfterEdit == 1)

        // 未选图片也能录入；空白名称必须被数据层拦截。
        var manual = ItemDraft(defaultContainer: cabinet)
        manual.name = "手动录入的物品"
        try ItemRepository.save(manual, editing: nil, in: context)
        manual.name = " \n "
        do {
            try ItemRepository.save(manual, editing: nil, in: context)
            preconditionFailure("空白名称不应保存成功")
        } catch ItemRepository.ValidationError.invalidName {}
        let countAfterManual = try context.fetchCount(FetchDescriptor<Item>())
        precondition(countAfterManual == 2)

        // 容器造型更新，以及 nullify 删除关系：容器删除后两件物品仍然存在。
        try ContainerRepository.save(name: "  大衣柜  ", icon: "hanger", furnitureImage: "yigui", editing: cabinet, in: context)
        precondition(cabinet.name == "大衣柜" && cabinet.gridWidth == 2)
        try ContainerRepository.delete(cabinet, in: context)
        let refreshed = ModelContext(database)
        let survivingItems = try refreshed.fetch(FetchDescriptor<Item>())
        precondition(survivingItems.count == 2 && survivingItems.allSatisfy { $0.container == nil })
        let remainingContainers = try refreshed.fetchCount(FetchDescriptor<Container>())
        precondition(remainingContainers == 0)

        // 禁用实现不会发送请求，明确返回“服务未开启”。
        precondition(!ItemRecognitionService.provider.isEnabled)
        do {
            _ = try await ItemRecognitionService.provider.recognize(imageData: photoBytes)
            preconditionFailure("禁用服务不应返回识别结果")
        } catch ItemRecognitionError.unavailable {}
        print("PASS：旧状态清理、草稿隔离、编辑不重复、手动录入、名称校验、容器删除保留物品、识别停用")
    }
}
