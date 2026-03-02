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
    
    // 接收外部传入的编辑状态绑定 (可选)
    // 如果作为独立页面，使用内部 isEditing
    // 如果作为组件嵌入，可以通过 Binding 控制（这里简化处理，组件嵌入时默认不可编辑，点击按钮跳转到全屏编辑）
    
    var body: some View {
        ZStack {
            // 背景色 (预览模式下可能不需要背景，或者使用透明背景)
            if !isPreviewMode {
                Color(hex: "F2F2F7").ignoresSafeArea()
            } else {
                Color.clear
            }
            
            // Isometric 画布
            GeometryReader { geo in
                ZStack {
                    // 1. 绘制网格地板
                    gridLayer
                    
                    // 2. 绘制已放置的家具
                    furnitureLayer
                    
                    // 3. 绘制正在拖拽的家具 (幽灵图)
                    if draggingContainer != nil {
                        // 计算当前拖拽位置对应的网格坐标
                        // 这里需要把全局拖拽坐标转换为相对于画布的坐标
                        // 暂时简化处理，直接显示跟随手指
                    }
                }
                // 初始位置调整：预览模式下可能需要不同的初始偏移
                .offset(x: geo.size.width / 2 + offset.width, y: geo.size.height / (isPreviewMode ? 3 : 4) + offset.height)
                .scaleEffect(scale)
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
            }
            .allowsHitTesting(!isPreviewMode || true) // 预览模式下是否允许拖拽画布？允许吧，体验好一点
            
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
                        withAnimation {
                            isEditing.toggle()
                        }
                    }
                }
            }
        }
        .onAppear {
            // 预览模式下默认缩放小一点？或者自动适应
            if isPreviewMode {
                scale = 0.8
                lastScale = 0.8
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
            FurnitureView(container: container)
                .position(IsoGridConfig.toScreen(gridX: container.gridX, gridY: container.gridY))
                .zIndex(Double(container.gridX + container.gridY)) // 简单的深度排序
                .onTapGesture {
                    // 仅在编辑模式下允许交互
                    if isEditing {
                        // 点击家具，可以弹窗编辑或收回
                        withAnimation {
                            container.isPlaced = false
                        }
                    }
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
                Image(config.imageName)
                    .resizable()
                    .scaledToFit()
                    // 动态计算宽度：基于网格宽度
                    // 假设图片是按照标准比例制作的，我们主要控制底座宽度匹配网格
                    // 网格总宽度 = (gridX + gridY) * tileWidth? 不对，是投影宽度
                    // 简单起见，我们设定 1x1 的家具图片宽度约为 tileWidth * 1.5 (考虑高度)
                    // 更好的方式是直接指定 frame width
                    .frame(width: IsoGridConfig.tileWidth * CGFloat(max(config.width, config.depth)) * 1.5)
                    // 调整垂直偏移，让底座对齐网格中心
                    .offset(y: -IsoGridConfig.tileHeight * 0.8)
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
