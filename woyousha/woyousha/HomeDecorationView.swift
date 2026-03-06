import SwiftUI
import SwiftData

// Notification Name Extension
extension NSNotification.Name {
    static let resetHomeView = NSNotification.Name("ResetHomeView")
}

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
    // 使用 @AppStorage 保存视图状态，确保重启后恢复位置和缩放
    @AppStorage("homeViewOffsetX") private var storedOffsetX: Double = 0.0
    @AppStorage("homeViewOffsetY") private var storedOffsetY: Double = 0.0
    @AppStorage("homeViewScale") private var storedScale: Double = 1.0
    
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
        if isPreviewMode {
            contentView
        } else {
            contentView
                .navigationTitle(isEditing ? "装修模式" : "我的家")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
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
    }
    
    var contentView: some View {
        ZStack {
            // 背景色
            if !isPreviewMode {
                Color(hex: "F2F2F7").ignoresSafeArea()
            } else {
                Color.clear.ignoresSafeArea() // 确保背景色忽略安全区域，以便填满整个区域
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
                        // 点击背景取消选中的逻辑已合并到外层手势中
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
                        .scaleEffect(1/scale) // 关键修复：先抵消缩放
                        .position(getMenuPosition(for: container)) // 再设置位置，确保位置计算不受缩放影响
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
                    DragGesture(minimumDistance: 0) // 设置为 0 实现无延迟拖拽
                        .onChanged { value in
                            // 如果没有选中家具在拖拽，则拖拽画布
                            if draggingContainerID == nil {
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { value in
                            if draggingContainerID == nil {
                                // 判断是否是微小移动（点击）
                                if abs(value.translation.width) < 5 && abs(value.translation.height) < 5 {
                                    // 视为点击：取消选中
                                    if isEditing {
                                        withAnimation {
                                            selectedContainerID = nil
                                        }
                                    }
                                    // 恢复位置，避免微小抖动
                                    offset = lastOffset
                                } else {
                                    // 确认拖拽，更新最后位置
                                    lastOffset = offset
                                    
                                    // 保存新的偏移量
                                    storedOffsetX = Double(offset.width)
                                    storedOffsetY = Double(offset.height)
                                }
                            }
                        },
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = scale
                            
                            // 保存新的缩放比例
                            storedScale = Double(scale)
                        }
                )
            )
            
            // 监听复位通知
            .onReceive(NotificationCenter.default.publisher(for: .resetHomeView)) { _ in
                withAnimation {
                    scale = 1.0
                    lastScale = 1.0
                    offset = .zero
                    lastOffset = .zero
                    
                    // 复位存储的状态
                    storedScale = 1.0
                    storedOffsetX = 0.0
                    storedOffsetY = 0.0
                }
            }
            
            // 定位复位按钮 (仅在编辑模式显示，因为预览模式的复位按钮在 ContentView 中处理了)
            if isEditing {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                                
                                // 复位存储的状态
                                storedScale = 1.0
                                storedOffsetX = 0.0
                                storedOffsetY = 0.0
                            }
                        }) {
                            Image(systemName: "scope")
                                .font(.title2)
                                .foregroundStyle(.primary)
                                .padding(12)
                                .background(.regularMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 180)
                    }
                }
            }
            
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
            if isEditing && !isPreviewMode {
                VStack {
                    Spacer()
                    furnitureDrawer
                        .transition(.move(edge: .bottom))
                }
            }
        }
        .onAppear {
            if isPreviewMode {
                // 如果存储了状态，则恢复；否则使用默认值
                if storedScale != 0 {
                    scale = storedScale
                    lastScale = storedScale
                    offset = CGSize(width: storedOffsetX, height: storedOffsetY)
                    lastOffset = offset
                } else {
                    scale = 0.5 // 预览模式缩小适应
                    lastScale = 0.5
                }
            } else {
                // 编辑模式也恢复状态
                if storedScale != 0 {
                    scale = storedScale
                    lastScale = storedScale
                    offset = CGSize(width: storedOffsetX, height: storedOffsetY)
                    lastOffset = offset
                }
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
                // 优化后的手势：只有当家具被选中时才启用拖拽，否则允许点击穿透
                .gesture(
                    // 仅当编辑模式且已选中该家具时，启用 DragGesture
                    (isEditing && selectedContainerID == container.id.uuidString) ?
                    DragGesture(minimumDistance: 0) // 零延迟拖拽
                        .onChanged { value in
                            if draggingContainerID == nil {
                                draggingContainerID = container.id.uuidString
                            }
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            if draggingContainerID == container.id.uuidString {
                                // 结算位移
                                container.posX += value.translation.width / scale
                                container.posY += value.translation.height / scale
                            }
                            
                            // 重置状态
                            draggingContainerID = nil
                            dragOffset = .zero
                        }
                    : nil
                )
                // 非编辑模式或未选中状态下的点击逻辑
                .onTapGesture {
                    if isEditing {
                        // 编辑模式：点击切换选中状态
                        withAnimation {
                            selectedContainerID = (selectedContainerID == container.id.uuidString) ? nil : container.id.uuidString
                        }
                    } else {
                        // 非编辑模式：也可以有简单的选中反馈，或者不做任何事
                        withAnimation {
                            selectedContainerID = (selectedContainerID == container.id.uuidString) ? nil : container.id.uuidString
                        }
                    }
                }
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
    
    // 动态计算气泡菜单位置，使其始终贴合家具顶部
    func getMenuPosition(for container: Container) -> CGPoint {
        // 1. 获取家具配置
        let config: FurnitureConfig
        if let imageName = container.furnitureImageName,
           let c = FurnitureConfig.get(byImageName: imageName) {
            config = c
        } else {
            config = FurnitureConfig.all.first { container.name.contains($0.name) } ?? FurnitureConfig.all[0]
        }
        
        // 2. 计算家具在画布坐标系中的高度
        // FurnitureView 中的逻辑：width = RoomConfig.tileWidth * max(w, d) * config.scale * container.scale
        // 假设图片大致是方形，高度近似等于宽度（或者略小，取决于等轴测视角）
        // 这里我们使用宽度的一半作为“半径”估算，再加上一些余量
        let furnitureSize = RoomConfig.tileWidth * CGFloat(max(config.width, config.depth)) * config.scale * container.scale
        let furnitureRadius = furnitureSize / 2
        
        // 3. 计算菜单的偏移量
        // 菜单自身的高度约为 100pt (按钮行 + 滑块行 + Padding)
        // 我们希望菜单底部距离家具顶部有一定的间距 (例如 10pt)
        // 菜单视觉高度的一半（因为 anchor 是 center）约为 50pt
        // 另外需要加上 padding
        
        // 目标：菜单视觉中心 Y = 家具视觉顶部 Y - (菜单视觉高度/2 + 间距)
        // 家具视觉顶部 Y (相对于家具中心) = -furnitureRadius * scale
        // 菜单视觉中心 Y (相对于家具中心) = -furnitureRadius * scale - (50 + 10)
        
        // 转换为画布坐标系 (除以 scale)
        // 菜单中心 Y (画布) = container.posY - furnitureRadius - 60 / scale
        
        // 修正逻辑：由于我们现在是先 scaleEffect(1/scale) 再 position
        // 这意味着 position 设置的是菜单的中心点（在 ZStack 坐标系中）
        // 菜单自身的视觉大小是固定的（不随 scale 变化）
        // 但是家具的大小是随 scale 变化的（在 ZStack 中被放大）
        // 所以，家具的视觉顶部距离中心是 furnitureRadius * scale
        // 菜单的视觉高度的一半是 50
        // 我们希望菜单底部距离家具顶部 10pt
        // 所以菜单中心 Y = 家具中心 Y - 家具视觉半径 - 菜单半高 - 间距
        // MenuCenterY = (container.posY * scale) - (furnitureRadius * scale) - 50 - 10
        // 但是，position 需要的是 ZStack 内部坐标系的值
        // 而 ZStack 本身被 scale 了。
        // 如果我们在 ZStack 内部放置一个点 (x, y)，它会被渲染在 (x * scale, y * scale)
        // 所以我们需要反推 position 的 y 值：
        // (y * scale) = (container.posY * scale) - (furnitureRadius * scale) - 60
        // y = container.posY - furnitureRadius - 60 / scale
        
        // 等等，之前的逻辑似乎是对的？那为什么会偏？
        // 可能是因为 scaleEffect(1/scale) 的 anchor 问题
        // 如果我们先 scaleEffect(1/scale)，菜单本身变成了原始大小
        // 然后 position 把它放到指定位置。
        // 这个位置是在 ZStack 坐标系中的。
        // ZStack 渲染时，会把这个位置放大 scale 倍。
        // 所以最终屏幕上的位置是 position * scale。
        // 我们希望屏幕上的位置是：家具屏幕位置 - 家具屏幕半径 - 60
        // (pos * scale) = (container.posY * scale) - (furnitureRadius * scale) - 60
        // pos = container.posY - furnitureRadius - 60 / scale
        
        // 结论：公式本身没错。
        // 问题可能出在之前 scaleEffect 是在 position 之后，导致它是以全屏为 anchor 缩放的。
        // 现在交换了顺序，应该就正常了。
        
        return CGPoint(
            x: container.posX,
            y: container.posY - furnitureRadius - 60 / scale
        )
    }
}

// 气泡菜单组件
struct FurnitureBubbleMenu: View {
    let container: Container
    var onBringToFront: () -> Void
    var onSendToBack: () -> Void
    var onDelete: () -> Void
    
    // 状态：是否显示造型选择器
    @State private var showStyleSelector = false
    
    var body: some View {
        VStack(spacing: 8) {
            // 显示容器名称
            Text(container.name)
                .font(.headline)
                .padding(.bottom, 4)
            
            // 1. 功能按钮行
            HStack(spacing: 16) {
                // 更换造型
                Button(action: {
                    withAnimation {
                        showStyleSelector.toggle()
                    }
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: "swatchpalette.fill")
                            .font(.system(size: 14))
                        Text("造型")
                            .font(.system(size: 10))
                    }
                    .frame(width: 36)
                }
                .foregroundStyle(.primary)
                
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
            
            if showStyleSelector {
                Divider()
                
                // 造型选择器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // 遍历所有可能的家具配置，找到名称匹配的作为候选
                        // 简单的逻辑：列出所有家具配置供选择（或者根据名称过滤）
                        // 这里为了演示，我们列出所有家具
                        ForEach(FurnitureConfig.all) { config in
                            Image(config.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .padding(4)
                                .background(container.furnitureImageName == config.imageName ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture {
                                    withAnimation {
                                        container.furnitureImageName = config.imageName
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 50)
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
        .frame(width: 300) // 增加宽度以容纳更多按钮
    }
}

import UniformTypeIdentifiers

// 单个家具视图
struct FurnitureView: View {
    let container: Container
    let isSelected: Bool
    // 添加绑定以更新选中的物品状态
    // 注意：这里我们无法直接访问 ContentView 的 selectedItems 状态，因为它们是解耦的。
    // 但是我们可以通过 NotificationCenter 发送通知，或者传入一个闭包。
    // 鉴于架构解耦，使用 NotificationCenter 是比较轻量的方式，
    // 或者我们假设 ContentView 会监听 draggingItems 的变化并自动清除选中态？
    // 实际上 ContentView 的 onDragEnd 已经处理了 draggingItems.removeAll()
    // 但 selectedItems 没有被清空。
    
    // 我们可以定义一个通知名称
    static let didDropItemsNotification = Notification.Name("didDropItemsNotification")
    
    @Environment(\.modelContext) private var modelContext
    @State private var isTargeted = false
    
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
                    .shadow(color: (isSelected || isTargeted) ? .white : .clear, radius: 0, x: 2, y: 0)
                    .shadow(color: (isSelected || isTargeted) ? .white : .clear, radius: 0, x: -2, y: 0)
                    .shadow(color: (isSelected || isTargeted) ? .white : .clear, radius: 0, x: 0, y: 2)
                    .shadow(color: (isSelected || isTargeted) ? .white : .clear, radius: 0, x: 0, y: -2)
                    .shadow(color: (isSelected || isTargeted) ? .white : .clear, radius: 0, x: 2, y: 2)
                    .shadow(color: (isSelected || isTargeted) ? .white : .clear, radius: 0, x: -2, y: -2)
                    .shadow(color: (isSelected || isTargeted) ? .white : .clear, radius: 0, x: 2, y: -2)
                    .shadow(color: (isSelected || isTargeted) ? .white : .clear, radius: 0, x: -2, y: 2)
                    // 再加一层外阴影增强立体感
                    .shadow(color: (isSelected || isTargeted) ? .black.opacity(0.15) : .clear, radius: 4, x: 0, y: 2)
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
                .shadow(color: (isSelected || isTargeted) ? .blue : .clear, radius: 5)
            }
        }
        // 高亮时的 Tooltip
        .overlay(alignment: .top) {
            if isTargeted {
                Text("移动到 \(container.name)")
                    .font(.system(size: 12, weight: .bold)) // 统一字号
                    .foregroundStyle(.white) // 统一白色文字
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.8)) // 统一深色背景
                            .shadow(radius: 2)
                    )
                    .lineLimit(1) // 强制单行
                    .fixedSize() // 强制适应内容大小
                    .offset(y: -50) // 向上偏移更多
                    .zIndex(999) // 确保在最上层
                    .transition(.opacity)
            }
        }
        // 支持 Drop 操作
        .dropDestination(for: String.self) { items, location in
            // items 是 UUID 字符串数组
            // 注意：我们之前修改了 customDraggable 传递逻辑，可能会传递 "id1,id2,id3" 这样的字符串
            // 所以我们需要先拆分
            Task {
                var droppedCount = 0
                for itemString in items {
                    // 尝试按逗号拆分，处理多选情况
                    let uuidStrings = itemString.split(separator: ",").map { String($0) }
                    
                    for uuidString in uuidStrings {
                        if let uuid = UUID(uuidString: uuidString) {
                            await MainActor.run {
                                let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == uuid })
                                if let item = try? modelContext.fetch(descriptor).first {
                                    // 移动 Item 到当前 Container
                                    item.container = container
                                    droppedCount += 1
                                }
                            }
                        }
                    }
                }
                
                // 如果有移动，保存上下文
                if droppedCount > 0 {
                    await MainActor.run {
                        try? modelContext.save()
                        // 震动反馈
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        // 发送通知，告知 ContentView 清空选中状态
                        NotificationCenter.default.post(name: FurnitureView.didDropItemsNotification, object: nil)
                    }
                }
            }
            return true
        } isTargeted: { targeted in
            withAnimation {
                isTargeted = targeted
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
