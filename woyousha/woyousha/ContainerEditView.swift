//
//  ContainerEditView.swift
//  woyousha
//
//  Created by ByteDance on 2/28/26.
//

import SwiftUI
import SwiftData

struct ContainerEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var containerToEdit: Container?
    
    @State private var name: String = ""
    @State private var icon: String = "cube.box"
    @State private var showDeleteConfirmation = false
    
    // 预设的一些可爱家具图标
    let availableIcons = [
        "cube.box", "archivebox", "shippingbox", // 盒子
        "cabinet", "refrigerator", "washer", "dishwasher", // 家电/柜子
        "cart", "basket", "bag", "backpack", "suitcase", // 移动容器
        "books.vertical", "books.vertical.fill", // 书架
        "deskclock", "lamp.desk", // 桌面
        "bed.double", "sofa", "chair", // 家具
        "door.left.hand.closed", "window.vertical.closed", // 房间
        "tshirt", "hanger" // 衣柜相关
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("容器信息") {
                    TextField("容器名称 (例如: 衣柜)", text: $name)
                }
                
                Section("选择图标") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 16) {
                        ForEach(availableIcons, id: \.self) { iconName in
                            Image(systemName: iconName)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .foregroundStyle(icon == iconName ? .white : .primary)
                                .background(icon == iconName ? Color.blue : Color.gray.opacity(0.1))
                                .clipShape(Circle())
                                .onTapGesture {
                                    withAnimation {
                                        icon = iconName
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: icon)
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                            Text(name.isEmpty ? "预览" : name)
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                // 只有在编辑已有容器时才显示删除按钮
                if let _ = containerToEdit {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("删除容器")
                                Spacer()
                            }
                        }
                    } footer: {
                        Text("删除容器后，其中的物品将自动移至“未分类”")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(containerToEdit == nil ? "新建容器" : "编辑容器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveContainer()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let container = containerToEdit {
                    name = container.name
                    icon = container.icon
                }
            }
            .alert("删除容器", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) { }
                Button("确认删除", role: .destructive) {
                    deleteContainer()
                }
            } message: {
                Text("确定要删除这个容器吗？其中的物品将自动移至“未分类”。")
            }
        }
    }
    
    private func deleteContainer() {
        guard let container = containerToEdit else { return }
        
        // 1. 获取容器中的所有物品，处理可选值
        let itemsToMove = container.items ?? []
        
        // 2. 将这些物品的 container 设置为 nil (移至未分类)
        for item in itemsToMove {
            item.container = nil
        }
        
        // 3. 删除容器
        modelContext.delete(container)
        
        // 4. 保存更改
        try? modelContext.save()
        
        // 5. 关闭页面
        dismiss()
    }
    
    private func saveContainer() {
        if let container = containerToEdit {
            container.name = name
            container.icon = icon
            container.updatedDate = Date()
        } else {
            let newContainer = Container(name: name, icon: icon)
            modelContext.insert(newContainer)
        }
        
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    ContainerEditView()
}
