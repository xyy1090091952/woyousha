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
    @State private var isAnalyzingImage = false // 是否正在进行 AI 识别

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
                                    if isProcessingImage || isAnalyzingImage {
                                        VStack {
                                            ProgressView()
                                                .controlSize(.large)
                                                .tint(.white)
                                            Text(isProcessingImage ? "AI 抠图中..." : "AI 识别中...")
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                                .padding(.top, 8)
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(Color.black.opacity(0.6))
                                        .cornerRadius(12)
                                    }
                                }
                                .overlay(alignment: .topTrailing) {
                                    // 删除图片按钮
                                    if !isProcessingImage && !isAnalyzingImage {
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
                                
                                // 操作按钮区域
                                if !isProcessingImage && !isAnalyzingImage {
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
                    // 禁用条件：正在处理图片，或者没有选择图片（selectedImage 为空）
                    .disabled(isProcessingImage || selectedImage == nil)
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
    
    // 调用豆包 AI 识别图片 (改为后台任务)
    private func analyzeImageInBackground(for item: Item, originalImage: UIImage) {
        // 设置状态为处理中
        item.aiStatus = .processing
        
        Task.detached(priority: .userInitiated) {
            do {
                // 压缩原图，避免 Vision/豆包 API 处理过大图片导致内存飙升
                let resizedImage = ImageUtils.resizeImage(originalImage, maxDimension: 1024)
                
                // 使用压缩后的图片进行识别
                let result = try await DoubaoService.shared.analyzeImage(image: resizedImage)
                
                await MainActor.run {
                    // 更新物品信息
                    withAnimation {
                        item.name = result.name
                        item.category = result.category
                        item.aiStatus = .success
                    }
                    // 尝试保存上下文
                    try? modelContext.save()
                }
            } catch {
                await MainActor.run {
                    // 标记失败
                    item.aiStatus = .failed
                    
                    // 区分错误类型并打印日志，便于调试
                    // 未来可以根据错误类型决定是否自动重试或在 UI 上显示具体错误信息
                    if let analysisError = error as? DoubaoService.AnalysisError {
                        switch analysisError {
                        case .networkError(let netError):
                            print("❌ 后台 AI 识别失败 (网络错误): \(netError.localizedDescription)")
                        case .missingApiKey:
                            print("❌ 后台 AI 识别失败 (API Key 缺失)")
                        case .apiError(let msg):
                            print("❌ 后台 AI 识别失败 (API 错误): \(msg)")
                        case .invalidResponse, .decodingError:
                             print("❌ 后台 AI 识别失败 (数据解析错误)")
                        case .invalidImage:
                             print("❌ 后台 AI 识别失败 (图片无效)")
                        }
                    } else {
                        print("❌ 后台 AI 识别失败 (未知错误): \(error.localizedDescription)")
                    }
                    
                    // 尝试保存上下文
                    try? modelContext.save()
                }
            }
        }
    }
    
    // AI 抠图逻辑 (修改为支持提前保存)
    private func removeBackground() {
        guard let inputImage = selectedImage else { return }
        isProcessingImage = true
        // 重置状态
        isAnalyzingImage = false
        
        Task {
            // 调用 ImageUtils 进行抠图
            if let outputImage = await ImageUtils.removeBackground(from: inputImage) {
                await MainActor.run {
                    // 添加白色描边 (可选)
                    let finalImage: UIImage
                    if let borderedImage = ImageUtils.addWhiteBorder(to: outputImage) {
                         finalImage = borderedImage
                    } else {
                         finalImage = outputImage
                    }
                    selectedImage = finalImage
                    isProcessingImage = false
                    
                    // 优化：抠图完成后立即进入"识别中"状态
                    // 这样用户即使不点击保存，也能看到状态变化
                    // 如果用户点击保存，saveItem 会接管这个状态并启动后台任务
                    isAnalyzingImage = true
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
        // 关键优化：压缩图片以降低内存占用和存储空间
        var imageData: Data? = nil
        var thumbnailData: Data? = nil
        
        if let image = selectedImage {
             // 再次确保图片尺寸合理 (虽然抠图过程可能已经压缩过，但为了安全起见)
             // 1024px 对于贴纸展示已经足够清晰，能有效防止 OOM
             let resized = ImageUtils.resizeImage(image, maxDimension: 1024)
             imageData = resized.pngData()
             
             // 生成缩略图 (200px)
             // 列表页加载 200px 的图片比加载 1024px 的原图快得多，且内存占用极低
             let thumbnail = ImageUtils.resizeImage(image, maxDimension: 200)
             thumbnailData = thumbnail.pngData()
        }
        
        // 2. 准备 Item 对象
        let targetItem: Item
        
        if let item = itemToEdit {
            // --- 更新现有物品 ---
            item.name = name.isEmpty ? "未命名" : name
            item.imageData = imageData
            item.thumbnailData = thumbnailData // 更新缩略图
            item.category = category
            item.quantity = quantity
            item.location = location
            item.note = note
            item.container = selectedContainer
            item.updatedDate = Date()
            targetItem = item
        } else {
            // --- 创建新物品 ---
            let newItem = Item(
                name: name.isEmpty ? "新物品" : name, // 如果名字为空，先给个默认值
                imageData: imageData,
                thumbnailData: thumbnailData, // 保存缩略图
                category: category,
                quantity: quantity,
                location: location,
                createdDate: Date(),
                updatedDate: Date(),
                note: note,
                container: selectedContainer
            )
            
            // 如果抠图已完成且处于识别等待状态，设置初始状态为 pending
            // 这样回到列表页就能立即看到 Loading
            if isAnalyzingImage {
                newItem.aiStatus = .pending
            }
            
            modelContext.insert(newItem)
            targetItem = newItem
        }
        
        // 3. 触发后台 AI 识别 (如果是新图片且未识别)
        // 只要有图片且名字是默认值/空的，我们就尝试识别
        // 这里不需要再判断 isProcessingImage，因为只有抠图完成后用户才能点击保存（或者我们允许处理中保存？）
        // 假设 selectedImage 已经包含足够特征用于识别
        if let imageToAnalyze = selectedImage {
            // 如果名字没填，或者显式需要识别
            if name.isEmpty || name == "新物品" {
                // 启动后台识别任务
                analyzeImageInBackground(for: targetItem, originalImage: imageToAnalyze)
            }
        }
        
        // 4. 提交事务
        do {
            try modelContext.save()
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
