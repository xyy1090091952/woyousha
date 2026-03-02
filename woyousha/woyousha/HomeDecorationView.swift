//
//  HomeDecorationView.swift
//  woyousha
//
//  Created by ByteDance on 3/2/26.
//

import SwiftUI
import SwiftData

// Isometric 网格配置
struct IsoGridConfig {
    static let tileWidth: CGFloat = 64
    static let tileHeight: CGFloat = 32
    static let gridSize: Int = 8 // 8x8 网格
    
    // 将网格坐标转换为屏幕坐标
    static func toScreen(gridX: Int, gridY: Int) -> CGPoint {
        let x = CGFloat(gridX - gridY) * (tileWidth / 2)
        let y = CGFloat(gridX + gridY) * (tileHeight / 2)
        return CGPoint(x: x, y: y)
    }
    
    // 将屏幕坐标转换为网格坐标 (逆运算)
    static func toGrid(screenX: CGFloat, screenY: CGFloat) -> (x: Int, y: Int) {
        // screenX = (gx - gy) * w/2
        // screenY = (gx + gy) * h/2
        // gx = (screenX / (w/2) + screenY / (h/2)) / 2
        // gy = (screenY / (h/2) - screenX / (w/2)) / 2
        
        let normalizedX = screenX / (tileWidth / 2)
        let normalizedY = screenY / (tileHeight / 2)
        
        let gx = Int(round((normalizedX + normalizedY) / 2))
        let gy = Int(round((normalizedY - normalizedX) / 2))
        
        return (gx, gy)
    }
}

struct HomeDecorationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // 查询所有容器
    @Query private var containers: [Container]
    
    // 是否处于预览模式 (如果为 true，则不显示导航栏，作为组件嵌入)
    var isPreviewMode: Bool = false
    
    // 视图状态
    @State private var offset: CGSize = .zero // 画布偏移
    @State private var lastOffset: CGSize = .zero
    @State private var scale: CGFloat = 1.0 // 缩放
    @State private var lastScale: CGFloat = 1.0
    
    // 拖拽状态
    @State private var draggingContainer: Container?
    @State private var dragOffset: CGSize = .zero
    
    // 编辑模式状态
    @State private var isEditing = false
    
    // 选中的容器 ID (用于联动)
    @Binding var selectedContainerID: String?
    
    // 初始化时允许设置是否直接进入编辑模式
    init(isPreviewMode: Bool = false, isEditing: Bool = false, selectedContainerID: Binding<String?> = .constant(nil)) {
        self.isPreviewMode = isPreviewMode
        _isEditing = State(initialValue: isEditing)
        self._selectedContainerID = selectedContainerID
    }
    
    // 接收外部传入的编辑状态绑定 (可选)
    // 如果作为独立页面，使用内部 isEditing
    // 如果作为组件嵌入，可以通过 Binding 控制（这里简化处理，组件嵌入时默认不可编辑，点击按钮跳转到全屏编辑）
    
    // 墙壁和地板的纹理状态 (暂时硬编码，后续可从数据模型加载)
    @State private var floorTexture: String = "green"
    @State private var wallTexture: String = "light_yellow"
    
    var body: some View {
        ZStack {
            // 背景色 (预览模式下可能不需要背景，或者使用透明背景)
            if !isPreviewMode {
                Color(hex: "F2F2F7").ignoresSafeArea()
            } else {
                Color.clear
                    // 如果在预览模式下需要通顶，这里也可以加 ignoresSafeArea，但主要依赖外层容器
            }
            
            // Isometric 画布
            GeometryReader { geo in
                ZStack {
                    // 0. 绘制背景层 (地面 + 墙壁)
                    // 需要在网格层之前绘制
                    roomStructureLayer
                    
                    // 1. 绘制网格地板
                    gridLayer
                    
                    // 1.5 拖拽高亮提示层 (显示在网格之上，家具之下)
                    dropHighlightLayer
                    
                    // 2. 绘制已放置的家具
                    furnitureLayer
                    
                    // 3. 绘制正在拖拽的家具 (幽灵图)
                    if let container = draggingContainer {
                        let originalPos = IsoGridConfig.toScreen(gridX: container.gridX, gridY: container.gridY)
                        FurnitureView(container: container, isSelected: false) // 拖拽时不显示选中态
                            .position(x: originalPos.x + dragOffset.width, y: originalPos.y + dragOffset.height)
                            .zIndex(100) // 确保拖拽时在最上层
                    }
                }
                // 初始位置调整：预览模式下可能需要不同的初始偏移
                // 预览模式下，为了避免顶部被切割，将中心点进一步下移
                // 之前的 2.5 可能不够，改为 2.2 或者 2.0，数值越小越靠下
                // 由于现在 ignoreSafeArea 了，可能需要稍微上移一点点补偿？或者保持 2.0 观察效果
                .offset(x: geo.size.width / 2 + offset.width, y: geo.size.height / (isPreviewMode ? 2.0 : 4) + offset.height)
                .scaleEffect(scale)
            }
            // 将手势添加到外层，并设置内容形状以确保空白区域也可点击
            .contentShape(Rectangle())
            .gesture(
                // 预览模式下可能禁用手势，或者允许简单的查看
                SimultaneousGesture(
                    // 拖拽画布
                    DragGesture()
                        .onChanged { value in
                            if draggingContainer == nil {
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        },
                    // 缩放画布
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                )
            )
            
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
                            // 如果是完成装修，直接关闭页面
                            dismiss()
                        } else {
                            // 如果是进入装修 (目前应该不会用到，因为进来就是装修模式)
                            withAnimation {
                                isEditing.toggle()
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            // 预览模式下默认缩放小一点？或者自动适应
            if isPreviewMode {
                scale = 0.7 // 稍微再缩小一点，以适应墙壁高度
                lastScale = 0.7
            }
        }
    }
    
    // 房间结构层 (墙壁 + 地面)
    var roomStructureLayer: some View {
        ZStack {
            // 1. 地面 (Floor)
            // 修复平铺问题：
            // 1. 先用 Rectangle 填充 ImagePaint (这会产生平铺纹理)
            // 2. 对 Rectangle 进行 3D 变换
            // 3. 最后用 mask 裁剪
            Rectangle()
                .fill(ImagePaint(image: Image(floorTexture), scale: 0.5))
                .frame(width: 1000, height: 1000) // 足够大的画布以容纳旋转后的内容
                .rotationEffect(.degrees(45))
                .scaleEffect(x: 1.0, y: 0.5)
                .position(x: IsoGridConfig.toScreen(gridX: IsoGridConfig.gridSize/2, gridY: IsoGridConfig.gridSize/2).x,
                          y: IsoGridConfig.toScreen(gridX: IsoGridConfig.gridSize/2, gridY: IsoGridConfig.gridSize/2).y)
                .mask(
                    Path { path in
                        let top = IsoGridConfig.toScreen(gridX: 0, gridY: 0)
                        let right = IsoGridConfig.toScreen(gridX: IsoGridConfig.gridSize, gridY: 0)
                        let bottom = IsoGridConfig.toScreen(gridX: IsoGridConfig.gridSize, gridY: IsoGridConfig.gridSize)
                        let left = IsoGridConfig.toScreen(gridX: 0, gridY: IsoGridConfig.gridSize)
                        
                        path.move(to: top)
                        path.addLine(to: right)
                        path.addLine(to: bottom)
                        path.addLine(to: left)
                        path.closeSubpath()
                    }
                )
            
            // 2. 左后墙 (Left Wall) - 对应 gridY 变化，屏幕上向左下延伸
            Rectangle()
                .fill(ImagePaint(image: Image(wallTexture), scale: 0.5))
                .frame(width: 800, height: 800)
                // 变换矩阵：Left Wall 斜率为 -0.5
                .projectionEffect(.init(CGAffineTransform(a: 1, b: -0.5, c: 0, d: 1, tx: 0, ty: 0)))
                // 调整位置：左墙中心大概在左侧
                .position(x: -200, y: 0) 
                .mask(
                    Path { path in
                        let wallHeight: CGFloat = 200
                        let p1 = IsoGridConfig.toScreen(gridX: 0, gridY: 0)
                        let p2 = IsoGridConfig.toScreen(gridX: 0, gridY: IsoGridConfig.gridSize)
                        
                        path.move(to: p1)
                        path.addLine(to: p2)
                        path.addLine(to: CGPoint(x: p2.x, y: p2.y - wallHeight))
                        path.addLine(to: CGPoint(x: p1.x, y: p1.y - wallHeight))
                        path.closeSubpath()
                    }
                )
                .overlay(
                    Path { path in
                        let wallHeight: CGFloat = 200
                        let p1 = IsoGridConfig.toScreen(gridX: 0, gridY: 0)
                        let p2 = IsoGridConfig.toScreen(gridX: 0, gridY: IsoGridConfig.gridSize)
                        
                        path.move(to: p1)
                        path.addLine(to: p2)
                        path.addLine(to: CGPoint(x: p2.x, y: p2.y - wallHeight))
                        path.addLine(to: CGPoint(x: p1.x, y: p1.y - wallHeight))
                        path.closeSubpath()
                    }
                    .fill(Color.black.opacity(0.1))
                )

            
            // 3. 右后墙 (Right Wall) - 对应 gridX 变化，屏幕上向右下延伸
            Rectangle()
                .fill(ImagePaint(image: Image(wallTexture), scale: 0.5))
                .frame(width: 800, height: 800)
                // 变换矩阵：Right Wall 斜率为 0.5
                .projectionEffect(.init(CGAffineTransform(a: 1, b: 0.5, c: 0, d: 1, tx: 0, ty: 0)))
                .position(x: 200, y: 0)
                .mask(
                    Path { path in
                        let wallHeight: CGFloat = 200
                        let p1 = IsoGridConfig.toScreen(gridX: 0, gridY: 0)
                        let p2 = IsoGridConfig.toScreen(gridX: IsoGridConfig.gridSize, gridY: 0)
                        
                        path.move(to: p1)
                        path.addLine(to: p2)
                        path.addLine(to: CGPoint(x: p2.x, y: p2.y - wallHeight))
                        path.addLine(to: CGPoint(x: p1.x, y: p1.y - wallHeight))
                        path.closeSubpath()
                    }
                )
                .overlay(
                    Path { path in
                        let wallHeight: CGFloat = 200
                        let p1 = IsoGridConfig.toScreen(gridX: 0, gridY: 0)
                        let p2 = IsoGridConfig.toScreen(gridX: IsoGridConfig.gridSize, gridY: 0)
                        
                        path.move(to: p1)
                        path.addLine(to: p2)
                        path.addLine(to: CGPoint(x: p2.x, y: p2.y - wallHeight))
                        path.addLine(to: CGPoint(x: p1.x, y: p1.y - wallHeight))
                        path.closeSubpath()
                    }
                    .fill(Color.white.opacity(0.05))
                )
        }
    }
    
    // 计算当前拖拽对应的目标网格坐标
    private var currentDragGridPos: (x: Int, y: Int)? {
        guard let container = draggingContainer else { return nil }
        
        let currentPos = IsoGridConfig.toScreen(gridX: container.gridX, gridY: container.gridY)
        let finalPos = CGPoint(x: currentPos.x + dragOffset.width, y: currentPos.y + dragOffset.height)
        
        let (newX, newY) = IsoGridConfig.toGrid(screenX: finalPos.x, screenY: finalPos.y)
        
        // 边界限制
        let clampedX = max(0, min(IsoGridConfig.gridSize - 1, newX))
        let clampedY = max(0, min(IsoGridConfig.gridSize - 1, newY))
        
        return (clampedX, clampedY)
    }
    
    // 拖拽高亮层
    var dropHighlightLayer: some View {
        Group {
            if let container = draggingContainer {
                // 获取当前拖拽的家具配置
                let config = FurnitureConfig.get(byImageName: container.furnitureImageName ?? "") ?? 
                             FurnitureConfig.all.first(where: { container.name.contains($0.name) })
                
                if let config = config, let (baseX, baseY) = currentDragGridPos {
                    // 绘制每个占据的格子
                    ForEach(0..<config.width, id: \.self) { dx in
                        ForEach(0..<config.depth, id: \.self) { dy in
                            let targetX = baseX + dx
                            let targetY = baseY + dy
                            
                            // 只绘制在网格范围内的
                            if targetX < IsoGridConfig.gridSize && targetY < IsoGridConfig.gridSize {
                                ZStack {
                                    Path { path in
                                        let center = IsoGridConfig.toScreen(gridX: targetX, gridY: targetY)
                                        let w = IsoGridConfig.tileWidth
                                        let h = IsoGridConfig.tileHeight
                                        
                                        path.move(to: CGPoint(x: center.x, y: center.y - h/2))
                                        path.addLine(to: CGPoint(x: center.x + w/2, y: center.y))
                                        path.addLine(to: CGPoint(x: center.x, y: center.y + h/2))
                                        path.addLine(to: CGPoint(x: center.x - w/2, y: center.y))
                                        path.closeSubpath()
                                    }
                                    .fill(Color.green.opacity(0.4))
                                    
                                    Path { path in
                                        let center = IsoGridConfig.toScreen(gridX: targetX, gridY: targetY)
                                        let w = IsoGridConfig.tileWidth
                                        let h = IsoGridConfig.tileHeight
                                        
                                        path.move(to: CGPoint(x: center.x, y: center.y - h/2))
                                        path.addLine(to: CGPoint(x: center.x + w/2, y: center.y))
                                        path.addLine(to: CGPoint(x: center.x, y: center.y + h/2))
                                        path.addLine(to: CGPoint(x: center.x - w/2, y: center.y))
                                        path.closeSubpath()
                                    }
                                    .stroke(Color.green, lineWidth: 2)
                                }
                            }
                        }
                    }
                    
                    // 显示尺寸提示文字 (可选)
                    let center = IsoGridConfig.toScreen(gridX: baseX, gridY: baseY)
                    Text("\(config.width)x\(config.depth)")
                        .font(.caption)
                        .padding(4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
                        .position(x: center.x, y: center.y - IsoGridConfig.tileHeight)
                }
            }
        }
    }
    
    // 网格层 (编辑模式下显示网格线，非编辑模式下可能隐藏或淡化)
    var gridLayer: some View {
        ZStack {
            // 绘制 8x8 的菱形网格
            ForEach(0..<IsoGridConfig.gridSize, id: \.self) { x in
                ForEach(0..<IsoGridConfig.gridSize, id: \.self) { y in
                    Path { path in
                        let center = IsoGridConfig.toScreen(gridX: x, gridY: y)
                        let w = IsoGridConfig.tileWidth
                        let h = IsoGridConfig.tileHeight
                        
                        path.move(to: CGPoint(x: center.x, y: center.y - h/2)) // Top
                        path.addLine(to: CGPoint(x: center.x + w/2, y: center.y)) // Right
                        path.addLine(to: CGPoint(x: center.x, y: center.y + h/2)) // Bottom
                        path.addLine(to: CGPoint(x: center.x - w/2, y: center.y)) // Left
                        path.closeSubpath()
                    }
                    .stroke(isEditing ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 1) // 仅编辑时显示网格线
                    // .fill(Color.white.opacity(0.5)) // 可以填充颜色做地板
                }
            }
        }
    }
    
    // 家具层
    var furnitureLayer: some View {
        ForEach(containers.filter { $0.isPlaced }) { container in
            let view = FurnitureView(container: container, isSelected: selectedContainerID == container.id.uuidString)
                .opacity(draggingContainer?.id == container.id ? 0 : 1) // 拖拽时隐藏原位置家具
                .position(IsoGridConfig.toScreen(gridX: container.gridX, gridY: container.gridY))
                .zIndex(Double(container.gridX + container.gridY)) // 简单的深度排序
                .onTapGesture {
                    // 1. 编辑模式下：点击进入编辑/收回
                    if isEditing {
                         // 点击家具，可以弹窗编辑或收回
                         withAnimation {
                             container.isPlaced = false
                         }
                    } 
                    // 2. 预览模式下：点击选中容器，并通知外部
                    else {
                        withAnimation {
                            // 点击切换选中状态
                            if selectedContainerID == container.id.uuidString {
                                selectedContainerID = nil
                            } else {
                                selectedContainerID = container.id.uuidString
                            }
                        }
                    }
                }
            
            // 仅在编辑模式下添加拖拽手势
            if isEditing {
                view.gesture(
                    DragGesture()
                        .onChanged { value in
                            // 开始拖拽或更新拖拽位置
                            if draggingContainer == nil {
                                draggingContainer = container
                            }
                            // 更新偏移量
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            // 拖拽结束，计算新位置
                            if let dragging = draggingContainer, dragging.id == container.id {
                                let currentPos = IsoGridConfig.toScreen(gridX: container.gridX, gridY: container.gridY)
                                let finalPos = CGPoint(x: currentPos.x + value.translation.width, y: currentPos.y + value.translation.height)
                                
                                // 转换回网格坐标
                                let (newX, newY) = IsoGridConfig.toGrid(screenX: finalPos.x, screenY: finalPos.y)
                                
                                // 边界检查 (0...7)
                                let clampedX = max(0, min(IsoGridConfig.gridSize - 1, newX))
                                let clampedY = max(0, min(IsoGridConfig.gridSize - 1, newY))
                                
                                // 更新位置
                                withAnimation {
                                    container.gridX = clampedX
                                    container.gridY = clampedY
                                }
                            }
                            
                            // 重置拖拽状态
                            draggingContainer = nil
                            dragOffset = .zero
                        }
                )
            } else {
                view
            }
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
                    // 筛选出未放置的容器
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
                                // 点击自动放置到第一个空位 (简化逻辑：先固定放 0,0)
                                withAnimation {
                                    container.isPlaced = true
                                    container.gridX = Int.random(in: 0...4)
                                    container.gridY = Int.random(in: 0...4)
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
}

// 单个家具视图
struct FurnitureView: View {
    let container: Container
    var isSelected: Bool = false // 是否选中 (用于高亮)
    
    // 动态计算家具图片
    var furnitureConfig: FurnitureConfig? {
        // 如果有显式设置的图片，优先使用
        if let imageName = container.furnitureImageName,
           let config = FurnitureConfig.get(byImageName: imageName) {
            return config
        }
        
        // 否则根据容器名称尝试自动匹配 (简单规则)
        // 遍历所有预设配置，看容器名字里是否包含关键词
        return FurnitureConfig.all.first { config in
            container.name.contains(config.name)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let config = furnitureConfig {
                // 使用图片素材渲染
                // 解决悬浮问题：使用 overlay + bottom alignment 技巧
                // 主体是一个不可见的锚点视图 (0x0)，将图片作为覆盖层向上绘制
                Color.clear
                    .frame(width: 0, height: 0)
                    .overlay(alignment: .bottom) {
                        Image(config.imageName)
                            .resizable()
                            .scaledToFit()
                            // 动态计算宽度
                            .frame(width: IsoGridConfig.tileWidth * CGFloat(max(config.width, config.depth)) * config.scale)
                            // 额外的垂直微调 (offsetY)
                            .offset(y: config.offsetY)
                            // 确保图片可以超出锚点范围显示
                            .fixedSize() 
                            // 选中高亮效果：使用多重阴影模拟描边，紧贴图片轮廓
                            .shadow(color: isSelected ? .yellow : .clear, radius: 0, x: 1, y: 1)
                            .shadow(color: isSelected ? .yellow : .clear, radius: 0, x: -1, y: -1)
                            .shadow(color: isSelected ? .yellow : .clear, radius: 0, x: 1, y: -1)
                            .shadow(color: isSelected ? .yellow : .clear, radius: 0, x: -1, y: 1)
                            // 再叠加一层模糊阴影增加发光感
                            .shadow(color: isSelected ? .yellow.opacity(0.5) : .clear, radius: 4, x: 0, y: 0)
                            .overlay {
                                if isSelected {
                                    // 叠加一个微弱的黄色光晕，增强可见性
                                    Image(config.imageName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: IsoGridConfig.tileWidth * CGFloat(max(config.width, config.depth)) * config.scale)
                                        .offset(y: config.offsetY)
                                        .fixedSize()
                                        .blendMode(.overlay)
                                        .opacity(0.3)
                                }
                            }
                    }
            } else {
                // 降级渲染：原来的蓝盒子
                fallbackView
            }
        }
    }
    
    var fallbackView: some View {
        ZStack {
            // 模拟一个立体的方块
            // 顶面
            Path { path in
                path.move(to: CGPoint(x: 0, y: -40))
                path.addLine(to: CGPoint(x: 32, y: -24))
                path.addLine(to: CGPoint(x: 0, y: -8))
                path.addLine(to: CGPoint(x: -32, y: -24))
            }
            .fill(Color.blue.opacity(0.8))
            
            // 右面
            Path { path in
                path.move(to: CGPoint(x: 32, y: -24))
                path.addLine(to: CGPoint(x: 32, y: 24)) // 高度 48
                path.addLine(to: CGPoint(x: 0, y: 40))
                path.addLine(to: CGPoint(x: 0, y: -8))
            }
            .fill(Color.blue.opacity(0.6))
            
            // 左面
            Path { path in
                path.move(to: CGPoint(x: -32, y: -24))
                path.addLine(to: CGPoint(x: -32, y: 24))
                path.addLine(to: CGPoint(x: 0, y: 40))
                path.addLine(to: CGPoint(x: 0, y: -8))
            }
            .fill(Color.blue.opacity(0.4))
            
            // 图标
            Image(systemName: container.icon)
                .foregroundStyle(.white)
                .offset(y: -10)
        }
        // 调整偏移，让底座中心对齐 (0,0)
        .offset(y: -IsoGridConfig.tileHeight)
    }
}

#Preview {
    HomeDecorationView()
        .modelContainer(for: Container.self, inMemory: true)
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
