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
    
    var containerToEdit: Container? = nil
    var onDelete: (() -> Void)? = nil
    
    @State private var name: String = ""
    @State private var icon: String = "cube.box"
    @State private var selectedFurnitureImage: String? = nil
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
                
                Section("选择家园中的造型") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            // 默认（无特殊造型）
                            VStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedFurnitureImage == nil ? Color.blue : Color.gray.opacity(0.1))
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: "cube.box")
                                        .font(.largeTitle)
                                        .foregroundStyle(selectedFurnitureImage == nil ? .white : .gray)
                                }
                                Text("默认")
                                    .font(.caption)
                            }
                            .onTapGesture {
                                withAnimation {
                                    selectedFurnitureImage = nil
                                }
                            }
                            
                            // 预设家具列表
                            ForEach(FurnitureConfig.all, id: \.name) { config in
                                VStack {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedFurnitureImage == config.imageName ? Color.blue : Color.gray.opacity(0.1))
                                            .frame(width: 80, height: 80)
                                        
                                        Image(config.imageName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 60, height: 60)
                                    }
                                    Text(config.name)
                                        .font(.caption)
                                }
                                .onTapGesture {
                                    withAnimation {
                                        selectedFurnitureImage = config.imageName
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            if let furnitureImage = selectedFurnitureImage {
                                Image(furnitureImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 100)
                            } else {
                                Image(systemName: icon)
                                    .font(.system(size: 60))
                                    .foregroundStyle(.blue)
                            }
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
                    selectedFurnitureImage = container.furnitureImageName
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
        
        // 由于 Container 模型中设置了 @Relationship(deleteRule: .nullify, inverse: \Item.container)
        // 删除容器时，关联的物品会自动将 container 属性置为 nil (即移至未分类)
        // 所以这里只需要删除容器即可，不需要手动迁移物品
        
        // 1. 删除容器
        modelContext.delete(container)
        
        // 2. 保存更改
        try? modelContext.save()
        
        // 3. 执行回调并关闭页面
        onDelete?()
        dismiss()
    }
    
    private func saveContainer() {
        if let container = containerToEdit {
            container.name = name
            container.icon = icon
            container.furnitureImageName = selectedFurnitureImage
            container.updatedDate = Date()
            
            // 如果选择了家具造型，自动更新占地大小
            if let imageName = selectedFurnitureImage,
               let config = FurnitureConfig.get(byImageName: imageName) {
                container.gridWidth = config.width
                container.gridDepth = config.depth
            }
        } else {
            let newContainer = Container(name: name, icon: icon)
            newContainer.furnitureImageName = selectedFurnitureImage
            
            // 如果选择了家具造型，自动更新占地大小
            if let imageName = selectedFurnitureImage,
               let config = FurnitureConfig.get(byImageName: imageName) {
                newContainer.gridWidth = config.width
                newContainer.gridDepth = config.depth
            }
            
            modelContext.insert(newContainer)
        }
        
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    ContainerEditView()
}
