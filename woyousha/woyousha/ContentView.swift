//
//  ContentView.swift
//  woyousha
//
//  Created by ByteDance on 2/27/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // 获取数据库上下文，用于增删改查操作
    @Environment(\.modelContext) private var modelContext
    
    // @Query 自动从数据库查询 Item 列表，并按照创建时间倒序排列
    // 当数据库发生变化时，这里的数据会自动更新，界面也会自动刷新
    @Query(sort: \Item.createdDate, order: .reverse) private var items: [Item]

    // 控制添加页面的显示状态
    // 类似于 Web 的 <Modal v-model="showAddSheet">
    @State private var showAddSheet = false
    
    // 定义网格布局 (两列)
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        // NavigationStack 替代 NavigationSplitView，因为手帐风格更适合全屏沉浸
        NavigationStack {
            ZStack {
                // 1. 背景层：点阵纸背景
                DotGridBackground(spacing: 20, dotColor: .gray.opacity(0.3))
                
                // 2. 内容层：滚动网格
                ScrollView {
                    if items.isEmpty {
                        // 空状态提示
                        VStack(spacing: 20) {
                            Image(systemName: "pencil.and.scribble")
                                .font(.system(size: 60))
                                .foregroundStyle(.gray.opacity(0.5))
                            Text("开始记录你的手帐吧")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundStyle(.gray)
                            Text("点击右上角 + 添加第一个贴纸")
                                .font(.subheadline)
                                .foregroundStyle(.gray.opacity(0.8))
                        }
                        .padding(.top, 100)
                    } else {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(items) { item in
                                NavigationLink {
                                    ItemDetailView(item: item)
                                } label: {
                                    StickerGridItemView(item: item)
                                }
                                // 添加长按菜单 (Context Menu) 以便删除或编辑
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteItem(item)
                                    } label: {
                                        Label("撕掉贴纸", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(20) // 网格周边的留白
                    }
                }
            }
            .navigationTitle("我的手帐") // 页面标题
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus.circle.fill") // 使用更显眼的加号
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddItemView()
            }
        }
    }

    // 删除单个物品
    private func deleteItem(_ item: Item) {
        withAnimation {
            modelContext.delete(item)
        }
    }
}

// 预览视图，方便在 Xcode 画布中实时查看效果
#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
