import SwiftUI
import SwiftData

// Isometric 网格配置已废弃，移除相关代码
// 使用简单的坐标转换配置
struct RoomConfig {
    // 房间背景图片尺寸 (基于 home1.png / home2.png 的大致比例)
    // 假设图片是方形或者接近方形的等轴测图
    // 为了适应屏幕，我们设置一个合理的默认大小
    static let roomWidth: CGFloat = 800 
    static let roomHeight: CGFloat = 800
    
    // 用于家具尺寸计算的基础瓦片宽度
    static let tileWidth: CGFloat = 64
}

struct HomeDecorationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // 查询所有容器
    @Query(sort: \Container.zIndex) private var containers: [Container]
    
    // 是否处于预览模式
    var isPreviewMode: Bool = false
    
    // 视图状态
    @State private var offset: CGSize = .zero // 画布偏移
    @State private var lastOffset: CGSize = .zero
    @State private var scale: CGFloat = 1.0 // 缩放
    @State private var lastScale: CGFloat = 1.0
    
    // 编辑模式状态
    @State private var isEditing = false
    
    // 选中的容器 ID
    @Binding var selectedContainerID: String?
    
    // 正在拖拽的容器 ID (用于显示幽灵图或跟随手指)
    @State private var draggingContainerID: String?
    @State private var dragOffset: CGSize = .zero
    
    // 当前选择的房间背景图
    @AppStorage("currentRoomImage") private var currentRoomImage: String = "home1"
    
    init(isPreviewMode: Bool = false, isEditing: Bool = false, selectedContainerID: Binding<String?> = .constant(nil)) {
        self.isPreviewMode = isPreviewMode
        _isEditing = State(initialValue: isEditing)
        self._selectedContainerID = selectedContainerID
    }
    
    var body: some View {
        ZStack {
            // 背景色
            if !isPreviewMode {
                Color(hex: "F2F2F7").ignoresSafeArea()
            } else {
                Color.clear
            }
            
            // 自由布局画布
            GeometryReader { geo in
                ZStack {
                    // 0. 房间背景图
                    Image(currentRoomImage)
                        .resizable()
                        .scaledToFit()
                        // 移除灰色背景
                        // .background(Color.gray.opacity(0.1)) 
                        .frame(width: RoomConfig.roomWidth, height: RoomConfig.roomHeight)
                        .position(x: RoomConfig.roomWidth/2, y: RoomConfig.roomHeight/2)
                        // 点击背景取消选中
                        .onTapGesture {
                            if isEditing {
                                withAnimation {
                                    selectedContainerID = nil
                                }
                            }
                        }
                        .zIndex(-1000) // 确保背景始终在最底层
                    
                    // 1. 绘制已放置的家具 (贴纸)
                    furnitureLayer
                    
                    // 2. 气泡式菜单 (跟随选中家具)
                    // 只有在编辑模式、选中了家具、且当前没有在拖拽家具时显示
                    if let selectedID = selectedContainerID,
                       let container = containers.first(where: { $0.id.uuidString == selectedID }),
                       isEditing && draggingContainerID == nil {
                        
                        FurnitureBubbleMenu(container: container, onBringToFront: {
                            bringToFront(container)
                        }, onSendToBack: {
                            sendToBack(container)
                        }, onDelete: {
                            withAnimation {
                                container.isPlaced = false
                                selectedContainerID = nil
                            }
                        })
                        // 位置：跟随家具，并向上偏移
                        // 注意：这里的位置是在画布坐标系中
                        .position(x: container.posX, y: container.posY - 80 / scale) // 向上偏移 80 点 (考虑缩放)
                        // 抵消画布的缩放，保持菜单大小一致
                        .scaleEffect(1/scale)
                        .zIndex(1000) // 确保菜单始终在最顶层
                        .transaction { transaction in
                            // 禁用位置变化的动画，实现“闪现”效果
                            transaction.animation = nil
                        }
                    }
                }
                // 初始位置：居中显示
                .frame(width: RoomConfig.roomWidth, height: RoomConfig.roomHeight)
                // 调整初始偏移，确保画布中心对齐屏幕中心
                .offset(x: (geo.size.width - RoomConfig.roomWidth) / 2 + offset.width,
                        y: (geo.size.height - RoomConfig.roomHeight) / 2 + offset.height)
                .scaleEffect(scale)
            }
            .contentShape(Rectangle())
            // 画布交互手势 (拖拽移动画布，缩放画布)
            .gesture(
                SimultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            // 如果没有选中家具在拖拽，则拖拽画布
                            if draggingContainerID == nil {
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        },
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                )
            )
            
            // 顶部房间切换栏 (仅在编辑模式显示)
            if isEditing && !isPreviewMode {
                VStack {
                    HStack {
                        Spacer()
                        Picker("房间风格", selection: $currentRoomImage) {
                            Text("风格 1").tag("home1")
                            Text("风格 2").tag("home2")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                        .padding()
                        Spacer()
                    }
                    Spacer()
                }
            }
            
            // 底部家具栏 (仅在编辑模式下显示)
            VStack {
                Spacer()
                if isEditing && !isPreviewMode {
                    furnitureDrawer
                        .transition(.move(edge: .bottom))
                }
            }
        }
        .navigationTitle(isPreviewMode ? "" : (isEditing ? "装修模式" : "我的家"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isPreviewMode {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "完成" : "装修") {
                        if isEditing {
                            dismiss()
                        } else {
                            withAnimation {
                                isEditing.toggle()
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if isPreviewMode {
                scale = 0.5 // 预览模式缩小适应
                lastScale = 0.5
            }
        }
    }
    
    // 家具层
    var furnitureLayer: some View {
        ForEach(containers.filter { $0.isPlaced }) { container in
            FurnitureView(container: container, isSelected: selectedContainerID == container.id.uuidString)
                // 位置绑定
                .position(x: container.posX + (draggingContainerID == container.id.uuidString ? dragOffset.width / scale : 0),
                          y: container.posY + (draggingContainerID == container.id.uuidString ? dragOffset.height / scale : 0))
                .zIndex(Double(container.zIndex))
                // 使用 highPriorityGesture 确保点击优先于背景拖拽
                .highPriorityGesture(
                    TapGesture()
                        .onEnded {
                            if isEditing {
                                withAnimation {
                                    selectedContainerID = container.id.uuidString
                                }
                            } else {
                                withAnimation {
                                    selectedContainerID = (selectedContainerID == container.id.uuidString) ? nil : container.id.uuidString
                                }
                            }
                        }
                )
                // 拖拽手势
                .gesture(
                    isEditing ? DragGesture(minimumDistance: 10) // 增加最小拖拽距离，避免误触点击
                        .onChanged { value in
                            if draggingContainerID == nil {
                                draggingContainerID = container.id.uuidString
                                // 拖拽开始时自动选中
                                selectedContainerID = container.id.uuidString
                            }
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            if draggingContainerID == container.id.uuidString {
                                // 更新模型坐标 (考虑缩放比例，位移需要除以 scale)
                                container.posX += value.translation.width / scale
                                container.posY += value.translation.height / scale
                            }
                            draggingContainerID = nil
                            dragOffset = .zero
                        } : nil
                )
                // 缩放手势 (选中时生效) - SwiftUI 的 MagnificationGesture 如果放在这里可能会和外层冲突
                // 简化起见，我们可以在操作栏加 Slider，或者使用 SimultaneousGesture
        }
    }
    
    // 底部家具抽屉
    var furnitureDrawer: some View {
        VStack(alignment: .leading) {
            Text("仓库")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    let unplacedContainers = containers.filter { !$0.isPlaced }
                    
                    if unplacedContainers.isEmpty {
                        Text("没有可放置的家具")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ForEach(unplacedContainers) { container in
                            VStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .shadow(radius: 2)
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: container.icon)
                                        .font(.largeTitle)
                                        .foregroundStyle(.blue)
                                }
                                Text(container.name)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .onTapGesture {
                                // 点击放置到屏幕中心
                                withAnimation {
                                    container.isPlaced = true
                                    // 放置在当前可视区域中心 (简单处理为房间中心)
                                    container.posX = RoomConfig.roomWidth / 2
                                    container.posY = RoomConfig.roomHeight / 2
                                    container.zIndex = (containers.map { $0.zIndex }.max() ?? 0) + 1
                                    selectedContainerID = container.id.uuidString
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding()
        .shadow(radius: 10)
    }
    
    // 层级管理函数
    func bringToFront(_ container: Container) {
        let maxZ = containers.map { $0.zIndex }.max() ?? 0
        container.zIndex = maxZ + 1
    }
    
    func sendToBack(_ container: Container) {
        let minZ = containers.map { $0.zIndex }.min() ?? 0
        // 限制 zIndex 不低于 0，避免穿透到背景图（背景图 zIndex 为 -1000）
        container.zIndex = max(0, minZ - 1)
    }
}

// 气泡菜单组件
struct FurnitureBubbleMenu: View {
    let container: Container
    var onBringToFront: () -> Void
    var onSendToBack: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // 1. 功能按钮行
            HStack(spacing: 16) {
                // 镜像
                Button(action: {
                    withAnimation {
                        container.isMirrored.toggle()
                    }
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                            .font(.system(size: 14))
                        Text("镜像")
                            .font(.system(size: 10))
                    }
                    .frame(width: 36)
                }
                .foregroundStyle(.primary)
                
                // 置顶
                Button(action: onBringToFront) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.up.to.line")
                            .font(.system(size: 14))
                        Text("置顶")
                            .font(.system(size: 10))
                    }
                    .frame(width: 36)
                }
                .foregroundStyle(.primary)
                
                // 置底
                Button(action: onSendToBack) {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 14))
                        Text("置底")
                            .font(.system(size: 10))
                    }
                    .frame(width: 36)
                }
                .foregroundStyle(.primary)
                
                // 删除
                Button(action: onDelete) {
                    VStack(spacing: 2) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                        Text("收起")
                            .font(.system(size: 10))
                    }
                    .frame(width: 36)
                }
                .foregroundStyle(.red)
            }
            
            Divider()
            
            // 2. 缩放滑块
            HStack(spacing: 8) {
                Text("缩放")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                
                Slider(value: Binding(
                    get: { container.scale },
                    set: { container.scale = $0 }
                ), in: 0.5...2.0)
                .frame(width: 120)
                
                Text("\(Int(container.scale * 100))%")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        // 添加一个小三角箭头指向下方
        .overlay(alignment: .bottom) {
            Image(systemName: "triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.regularMaterial)
                .rotationEffect(.degrees(180))
                .offset(y: 8)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
        }
        .frame(width: 260) // 固定宽度
    }
}

// 单个家具视图
struct FurnitureView: View {
    let container: Container
    let isSelected: Bool
    
    var furnitureConfig: FurnitureConfig? {
        if let imageName = container.furnitureImageName,
           let config = FurnitureConfig.get(byImageName: imageName) {
            return config
        }
        return FurnitureConfig.all.first { container.name.contains($0.name) }
    }
    
    var body: some View {
        // 渲染逻辑：图片或降级方块
        Group {
            if let config = furnitureConfig {
                // 计算当前尺寸
                let width = RoomConfig.tileWidth * CGFloat(max(config.width, config.depth)) * config.scale * container.scale
                
                Image(config.imageName)
                    .resizable()
                    .scaledToFit()
                    // 原始尺寸乘以用户自定义缩放
                    .frame(width: width)
                    .scaleEffect(x: container.isMirrored ? -1 : 1, y: 1) // 镜像
                    // 选中状态：添加贴纸描边效果
                    .shadow(color: isSelected ? .white : .clear, radius: 0, x: 2, y: 0)
                    .shadow(color: isSelected ? .white : .clear, radius: 0, x: -2, y: 0)
                    .shadow(color: isSelected ? .white : .clear, radius: 0, x: 0, y: 2)
                    .shadow(color: isSelected ? .white : .clear, radius: 0, x: 0, y: -2)
                    .shadow(color: isSelected ? .white : .clear, radius: 0, x: 2, y: 2)
                    .shadow(color: isSelected ? .white : .clear, radius: 0, x: -2, y: -2)
                    .shadow(color: isSelected ? .white : .clear, radius: 0, x: 2, y: -2)
                    .shadow(color: isSelected ? .white : .clear, radius: 0, x: -2, y: 2)
                    // 再加一层外阴影增强立体感
                    .shadow(color: isSelected ? .black.opacity(0.15) : .clear, radius: 4, x: 0, y: 2)
            } else {
                // 降级视图
                VStack {
                    Image(systemName: container.icon)
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.blue)
                        .clipShape(Circle())
                    Text(container.name)
                        .font(.caption)
                        .padding(4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
                }
                .scaleEffect(container.scale)
                .shadow(color: isSelected ? .blue : .clear, radius: 5)
            }
        }
    }
}

// 辅助扩展：Hex Color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
