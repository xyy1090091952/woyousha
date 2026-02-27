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
            // 如果因为数据库结构不匹配导致失败，我们不应该让 App 直接崩溃 (fatalError)
            // 在开发阶段，我们可以选择直接删除旧的数据库文件
            print("❌ 数据库加载失败: \(error)")
            print("⚠️ 尝试删除旧数据并重建数据库...")
            
            // 这是一个比较激进的做法，但在开发初期非常有用
            // 它会自动处理因为模型变更导致的迁移错误
            do {
                // 删除旧的存储文件
                try FileManager.default.removeItem(at: URL.applicationSupportDirectory.appending(path: "default.store"))
                // 再次尝试创建
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                // 如果还不行，那就真的没办法了，只能报错
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
