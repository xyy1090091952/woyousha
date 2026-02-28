//
//  AddItemView.swift
//  woyousha
//
//  Created by ByteDance on 2/27/26.
//

import SwiftUI
import SwiftData
import PhotosUI // 引入相册选择器框架

// 这个页面是用来让用户输入新物品信息的表单
// 类似于 Web 开发中的 <form> 页面
struct AddItemView: View {
    // 环境变量：用于关闭当前弹窗 (类似于 history.back() 或 router.back())
    @Environment(\.dismiss) private var dismiss
    
    // 环境变量：数据库操作上下文 (类似于 DB connection)
    @Environment(\.modelContext) private var modelContext
    
    // 查询所有容器
    @Query(sort: \Container.createdDate) private var containers: [Container]
    
    // 默认选中的容器 (从外部传入)
    var defaultContainer: Container?
    
    // 编辑模式：如果传入了 itemToEdit，说明是编辑现有物品
    var itemToEdit: Item?
    
    // @State 标记的变量是页面内部的状态
    // 当用户输入内容时，这些变量会自动更新 (类似于 Vue 的 v-model)
    @State private var name: String = ""
    @State private var category: Category = .clothes // 默认分类改为枚举类型
    @State private var quantity: Int = 1
    @State private var location: String = ""
    @State private var note: String = ""
    @State private var selectedContainer: Container? // 当前选中的容器
    
    // 图片相关状态
    @State private var selectedImage: UIImage? // 当前显示的图片
    @State private var photosPickerItem: PhotosPickerItem? // 相册选择器的中间对象
    @State private var isCameraPresented = false // 控制相机页面显示
    @State private var isProcessingImage = false // 是否正在进行 AI 抠图
    @State private var errorMessage: String? // 错误提示信息
    @State private var showErrorAlert = false // 控制错误弹窗显示
    @State private var showActionSheet = false // 控制图片选择方式弹窗
    @State private var showPhotoPicker = false // 控制相册选择器显示

    var body: some View {
        NavigationStack {
            Form {
                // 第一部分：图片展示与操作
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            // 图片展示区域
                            if let image = selectedImage {
                                ZStack {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 200)
                                        .cornerRadius(12)
                                        .shadow(radius: 4)
                                    
                                    // AI 处理中的 Loading 遮罩
                                    if isProcessingImage {
                                        ZStack {
                                            Color.black.opacity(0.3)
                                                .cornerRadius(12)
                                            ProgressView("AI 抠图中...")
                                                .foregroundStyle(.white)
                                                .tint(.white)
                                        }
                                        .frame(height: 200)
                                    }
                                }
                                .overlay(alignment: .topTrailing) {
                                    // 删除图片按钮
                                    if !isProcessingImage {
                                        Button {
                                            withAnimation {
                                                selectedImage = nil
                                                photosPickerItem = nil
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(.red)
                                                .background(.white)
                                                .clipShape(Circle())
                                        }
                                        .padding(8)
                                    }
                                }
                                
                                // 重新选择/拍照按钮 (替代原来的抠图按钮)
                                if !isProcessingImage {
                                    Button("更换图片") {
                                        showActionSheet = true
                                    }
                                    .font(.subheadline)
                                    .buttonStyle(.borderless)
                                }
                                
                            } else {
                                // 没有图片时的占位符 - 使用统一入口，点击后弹出 ActionSheet
                                Button(action: { showActionSheet = true }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.blue)
                                        Text("添加照片")
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text("拍照或相册 (自动抠图)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(width: 200, height: 150)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                            .foregroundStyle(.blue.opacity(0.5))
                                    )
                                }
                                .confirmationDialog("选择图片来源", isPresented: $showActionSheet) {
                                    Button("拍照") {
                                        isCameraPresented = true
                                    }
                                    
                                    // 这里我们不能直接放 PhotosPicker，因为它是一个 View，不是 Button Action
                                    // 这是一个 Swift UI 的局限性
                                    // 解决方法：我们在界面上放置一个隐藏的 PhotosPicker，并通过状态变量来触发它
                                    // 但是 PhotosPicker 没有 isPresented 绑定
                                    
                                    // 所以，为了实现“点击 ActionSheet 里的相册按钮打开相册”，我们需要：
                                    // 1. 在这里放一个普通 Button("从相册选择")
                                    // 2. 点击后设置一个 showPhotoPicker = true
                                    // 3. 在 body 里放一个 .photosPicker(isPresented: $showPhotoPicker)
                                    // 好消息是：iOS 16+ 的 PhotosPicker 确实支持 isPresented
                                    
                                    Button("从相册选择") {
                                        showPhotoPicker = true
                                    }
                                    
                                    Button("取消", role: .cancel) {}
                                }
                                .photosPicker(isPresented: $showPhotoPicker, selection: $photosPickerItem, matching: .images)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear) // 让这一行背景透明
                
                // 第二部分：基本信息
                Section("基本信息") {
                    // TextField 类似于 <input type="text">
                    TextField("物品名称", text: $name)
                    
                    // Picker 类似于 <select> 下拉框
                    Picker("分类", selection: $category) {
                        // 使用枚举的所有 case 动态生成列表
                        ForEach(Category.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                }
                
                // 第三部分：位置与数量
                Section("位置与数量") {
                    Picker("存放容器", selection: $selectedContainer) {
                        Text("未分类").tag(Optional<Container>.none)
                        ForEach(containers) { container in
                            Text(container.name).tag(Optional(container))
                        }
                    }
                    
                    TextField("具体位置 (例如: 第二层)", text: $location)
                    
                    // Stepper 是加减号控件，适合调节数量
                    Stepper("数量: \(quantity)", value: $quantity, in: 1...999)
                }
                
                // 第四部分：备注
                Section("备注") {
                    // TextEditor 类似于 <textarea> 多行文本框
                    TextField("备注信息 (选填)", text: $note, axis: .vertical)
                        .lineLimit(3...6) // 限制显示 3-6 行高度
                }
            }
            .navigationTitle(itemToEdit == nil ? "添加新物品" : "编辑物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左上角取消按钮
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss() // 关闭页面
                    }
                }
                
                // 右上角保存按钮
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveItem()
                    }
                    .disabled(isProcessingImage) // 名字为空或正在处理图片时禁用
                }
            }
            .sheet(isPresented: $isCameraPresented) {
                CameraView(selectedImage: $selectedImage, isPresented: $isCameraPresented)
            }
            // 监听相册选择器的结果
            .onChange(of: photosPickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            selectedImage = image
                            // 自动触发抠图
                            removeBackground()
                        }
                    }
                }
            }
            // 监听相机关闭事件，如果拍了新照片，自动抠图
            .onChange(of: isCameraPresented) { oldValue, newValue in
                if oldValue == true && newValue == false {
                    // 相机关闭了，如果有图片，且不是编辑模式下的原图（简单判断：如果 selectedImage 存在）
                    // 为了避免重复抠图，这里假设拍照就是为了新图。
                    // 只要 selectedImage 不为空，就处理。
                    if selectedImage != nil {
                        removeBackground()
                    }
                }
            }
            // 页面加载时填充数据 (如果是编辑模式)
            .onAppear {
                if let item = itemToEdit {
                    name = item.name
                    category = item.category
                    quantity = item.quantity
                    location = item.location
                    note = item.note
                    selectedContainer = item.container
                    if let data = item.imageData {
                        selectedImage = UIImage(data: data)
                    }
                } else if let defaultContainer {
                    selectedContainer = defaultContainer
                }
            }
            // 错误提示弹窗
            .alert("发生错误", isPresented: $showErrorAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
    }
    
    // AI 抠图逻辑
    private func removeBackground() {
        guard let inputImage = selectedImage else { return }
        isProcessingImage = true
        
        Task {
            // 调用 ImageUtils 进行抠图
            if let outputImage = await ImageUtils.removeBackground(from: inputImage) {
                await MainActor.run {
                    // 添加白色描边 (可选)
                    if let borderedImage = ImageUtils.addWhiteBorder(to: outputImage) {
                         selectedImage = borderedImage
                    } else {
                         selectedImage = outputImage
                    }
                    isProcessingImage = false
                }
            } else {
                await MainActor.run {
                    isProcessingImage = false
                    errorMessage = "自动抠图失败，已保留原图"
                    showErrorAlert = true
                }
            }
        }
    }
    
    // 保存逻辑
    private func saveItem() {
        // 1. 处理图片数据
        // 关键修复：使用 pngData() 以保留透明通道 (Alpha Channel)
        // jpegData 会自动把透明背景填充为白色，导致抠图效果失效
        let imageData = selectedImage?.pngData()
        
        if let item = itemToEdit {
            // --- 更新现有物品 ---
            item.name = name
            item.imageData = imageData
            item.category = category
            item.quantity = quantity
            item.location = location
            item.note = note
            item.container = selectedContainer
            item.updatedDate = Date() // 更新时间为当前时间
        } else {
            // --- 创建新物品 ---
            let newItem = Item(
                name: name,
                imageData: imageData, // 保存图片
                category: category,
                quantity: quantity,
                location: location,
                createdDate: Date(),
                updatedDate: Date(),
                note: note,
                container: selectedContainer
            )
            modelContext.insert(newItem)
        }
        
        // 3. 提交事务
        do {
            // 尝试保存上下文以确保数据持久化
            // 虽然 SwiftData 通常会自动保存，但显式保存可以捕获错误
            try modelContext.save()
            
            // 4. 关闭页面
            dismiss()
        } catch {
            print("❌ 保存物品失败: \(error)")
            errorMessage = "保存失败: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
}

// 预览视图
#Preview {
    AddItemView()
        .modelContainer(for: Item.self, inMemory: true)
}
