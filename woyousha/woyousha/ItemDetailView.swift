//
//  ItemDetailView.swift
//  woyousha
//
//  Created by ByteDance on 2/27/26.
//

import SwiftUI
import SwiftData

struct ItemDetailView: View {
    let item: Item
    
    @State private var showEditSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 物品大图
                if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                    HStack {
                        Spacer()
                        ZStack {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 350)
                                // 恢复普通投影，因为我们已经生成了带白边的图片
                                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 4)
                                .padding(10) // 给阴影留出空间
                            
                            // AI 处理状态 Tooltip
                            if item.aiStatus == .processing || item.aiStatus == .pending {
                                VStack {
                                    ProgressView()
                                        .controlSize(.large)
                                        .tint(.white)
                                    Text("AI 识别中...")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .padding(.top, 8)
                                }
                                .padding(20)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(12)
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, 10)
                } else {
                    // 没有图片时的占位符
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            VStack(spacing: 10) {
                                Image(systemName: "photo")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.gray)
                                Text("暂无图片")
                                    .foregroundStyle(.gray)
                            }
                        )
                        .cornerRadius(12)
                }
                
                // 物品详细信息
                VStack(alignment: .leading, spacing: 16) {
                    Text(item.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack {
                        Label(item.category.rawValue, systemImage: "tag.fill")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .cornerRadius(8)
                        
                        Spacer()
                        
                        Text(item.createdDate, format: Date.FormatStyle(date: .numeric, time: .standard))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                    
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("位置", systemImage: "location.fill")
                                .font(.headline)
                            
                            if let container = item.container {
                                Text(container.name + (item.location.isEmpty ? "" : " - \(item.location)"))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(item.location.isEmpty ? "未指定位置" : item.location)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("数量", systemImage: "number.square.fill")
                                .font(.headline)
                            Text("\(item.quantity)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if !item.note.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Label("备注", systemImage: "note.text")
                                .font(.headline)
                            Text(item.note)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // 仅当 AI 处理完成或无需处理时才允许编辑
                // 避免用户修改正在被后台任务更新的数据
                if item.aiStatus == .processing || item.aiStatus == .pending {
                    ProgressView()
                        .padding(.trailing, 8)
                } else {
                    Button("编辑") {
                        showEditSheet = true
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddItemView(itemToEdit: item)
        }
        .onAppear {
            checkTimeout()
        }
    }
    
    private func checkTimeout() {
        // 检查是否超时 (60秒)
        if item.aiStatus == .processing || item.aiStatus == .pending {
            let timeout: TimeInterval = 60
            // 优先使用 aiRequestDate，如果没有则回退到 updatedDate
            let startTime = item.aiRequestDate ?? item.updatedDate
            
            if Date().timeIntervalSince(startTime) > timeout {
                item.aiStatus = .failed
                // 无需手动 save，SwiftData 会自动处理，或者在退出时保存
            }
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Item.self, configurations: config)
        let item = Item(name: "测试物品", category: .clothes, quantity: 1, location: "衣柜", note: "这是一个测试备注")
        return ItemDetailView(item: item)
            .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}
