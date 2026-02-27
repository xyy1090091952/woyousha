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

    var body: some View {
        // NavigationSplitView 适配 iPad 和 Mac 的分栏布局
        // 在 iPhone 上会自动变成我们熟悉的导航栏模式
        NavigationSplitView {
            List {
                // 遍历所有物品
                ForEach(items) { item in
                    // NavigationLink 定义了点击跳转的目标
                    NavigationLink {
                        // 跳转到的详情页面
                        ItemDetailView(item: item)
                    } label: {
                        // 列表项的显示样式
                        HStack(spacing: 12) {
                            // 缩略图
                            if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit() // 保持比例
                                    .frame(width: 50, height: 50)
                                    // 列表页也去掉背景，加一点点阴影
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                            } else {
                                Image(systemName: "cube.box.fill")
                                    .font(.title2)
                                    .frame(width: 50, height: 50)
                                    .background(Color.gray.opacity(0.1))
                                    .foregroundStyle(.gray)
                                    .cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.headline)
                                HStack(spacing: 6) {
                                    Text(item.category.rawValue)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundStyle(.blue)
                                        .cornerRadius(4)
                                    
                                    if !item.location.isEmpty {
                                        Text(item.location)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Spacer()
                            Text("x\(item.quantity)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteItems) // 启用左滑删除功能
            }
            .navigationTitle("我的物品") // 页面标题
            .toolbar {
                // 顶部工具栏按钮
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton() // 系统自带的编辑按钮
                }
                ToolbarItem {
                    Button(action: { showAddSheet = true }) {
                        Label("添加物品", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddItemView()
            }
        } detail: {
            Text("请选择一个物品查看详情")
        }
    }

    // 删除物品
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

// 预览视图，方便在 Xcode 画布中实时查看效果
#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
