//
//  woyoushaApp.swift
//  woyousha
//
//  Created by ByteDance on 2/27/26.
//

import SwiftUI
import SwiftData

@main
struct woyoushaApp: App {
    // 这是一个计算属性，用于初始化数据库容器
    // 这里做了一个简单的错误处理：如果数据库结构变了导致加载失败，我们会尝试删除旧数据重新来过
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        
        // 配置数据库存储位置
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            // 尝试创建数据库容器
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("❌ 数据库加载失败: \(error)")
            
            // 仅在 DEBUG 模式下尝试删除旧数据
            #if DEBUG
            print("⚠️ [DEBUG] 尝试删除旧数据并重建数据库...")
            do {
                // 获取默认存储路径
                let url = URL.applicationSupportDirectory.appending(path: "default.store")
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                    print("✅ 旧数据库已删除")
                }
                
                // 再次尝试创建
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer in DEBUG mode: \(error)")
            }
            #else
            // 生产环境应该有更完善的迁移策略，或者提示用户
            // 这里暂时保留 fatalError，但实际生产中应该记录日志并给用户友好提示
            fatalError("Critical Error: Database failed to load. \(error)")
            #endif
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // 启动时执行一次性迁移任务
                    performImageMigration(modelContainer: sharedModelContainer)
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    // 执行图片迁移：生成缩略图并压缩原图
    private func performImageMigration(modelContainer: ModelContainer) {
        // 使用 detached Task 避免阻塞主线程，并且不使用 MainActor 以避免在主线程处理大量图片
        Task.detached(priority: .background) {
            // 在后台线程创建新的 Context
            let context = ModelContext(modelContainer)
            // 关闭自动保存，手动控制事务提交
            context.autosaveEnabled = false
            
            do {
                // 1. 获取所有物品 (SwiftData Predicate 对 Optional Data 比较可能存在限制，先全部取出再过滤)
                // 优化：仅查询 ID，避免一次性加载所有 Item 的大图数据到内存
                // 但 SwiftData 暂时不支持仅 fetch ID，所以我们分批处理
                
                let descriptor = FetchDescriptor<Item>()
                let allItems = try context.fetch(descriptor)
                
                // 2. 筛选需要迁移的物品
                // 这里我们只拿到引用，还没有加载大图数据 (Faulting 机制)
                let itemsToMigrate = allItems.filter { $0.imageData != nil && $0.thumbnailData == nil }
                
                if itemsToMigrate.isEmpty {
                    return
                }
                
                print("🔄 开始迁移 \(itemsToMigrate.count) 个物品的图片数据...")
                
                var successCount = 0
                let batchSize = 10 // 每批处理 10 个，避免内存峰值
                
                for (index, item) in itemsToMigrate.enumerated() {
                    // 只有在访问 imageData 时才会真正加载数据
                    if let data = item.imageData, let image = UIImage(data: data) {
                        // 1. 生成缩略图 (200px)
                        let thumbnail = ImageUtils.resizeImage(image, maxDimension: 200)
                        item.thumbnailData = thumbnail.pngData()
                        
                        // 2. 压缩原图 (1024px)
                        if max(image.size.width, image.size.height) > 1024 {
                            let resized = ImageUtils.resizeImage(image, maxDimension: 1024)
                            item.imageData = resized.pngData()
                        }
                        
                        successCount += 1
                        
                        // 每处理一批，保存一次并清理上下文，释放内存
                        if (index + 1) % batchSize == 0 {
                            try context.save()
                            // SwiftData 目前没有明确的 reset() API，但保存后内存通常会得到一定释放
                            // 或者我们可以考虑用 PersistentIdentifier 重新 fetch，但这里简单分批保存应该足够缓解 OOM
                        }
                    }
                }
                
                // 保存剩余的更改
                try context.save()
                print("✅ 图片迁移完成：成功处理 \(successCount)/\(itemsToMigrate.count) 个物品")
                
            } catch {
                print("❌ 图片迁移失败: \(error)")
            }
        }
    }
}
