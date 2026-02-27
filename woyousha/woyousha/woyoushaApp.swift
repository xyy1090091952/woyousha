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
        }
        .modelContainer(sharedModelContainer)
    }
}
