//
//  StickerGridItemView.swift
//  woyousha
//
//  Created by ByteDance on 2/27/26.
//

import SwiftUI

struct StickerGridItemView: View {
    let item: Item
    // 增加一个可选的 height 参数，如果未提供则使用默认值
    // 将 height 改为 let，确保视图更新时正确处理
    let height: CGFloat
    
    init(item: Item, height: CGFloat = 120) {
        self.item = item
        self.height = height
    }
    
    // 随机旋转角度 (-3 ~ 3 度)，模拟手贴的自然感
    // 注意：每次视图刷新可能会重新计算，最好是基于 item 的某个属性固定，或者在 onAppear 中设置
    // 为了简单起见，这里先固定为 0，或者基于 id 的 hash
    var rotationAngle: Double {
        // 基于 item.name 和 quantity 的 hash 生成一个伪随机角度，保证每次渲染一致
        let hash = (abs(item.name.hashValue) + item.quantity) % 7 - 3 // -3 到 3
        return Double(hash)
    }
    
    // 计算优化后的显示尺寸，使不同宽高比的图片视觉面积接近
    private func calculateDisplayHeight(for image: UIImage) -> CGFloat {
        let aspectRatio = image.size.width / image.size.height
        var displayHeight = height
        
        // 如果是横长图片 (宽 > 高)，适当减小显示高度
        // 使得视觉面积 (area = width * height) 与正方形图片接近
        // 正方形: h*h, 横长: w*h = ratio*h*h
        // 令 ratio*h'*h' = h*h -> h' = h / sqrt(ratio)
        if aspectRatio > 1.0 {
            // 使用 0.6 次方而不是 0.5 (sqrt)，让惩罚稍微轻一点，避免过小
            let scaleFactor = pow(aspectRatio, 0.6)
            displayHeight = height / scaleFactor
            // 设置一个最小高度下限，防止过扁
            displayHeight = max(displayHeight, height * 0.5)
        }
        
        // 如果是竖长图片 (高 > 宽)，通常不需要额外处理，或者可以稍微放大一点点
        // 但受限于网格布局的行高，我们保持 height 不变，宽度会自动变窄
        
        return displayHeight
    }
    
    // 提取 Loading Overlay 以复用
    private var loadingOverlay: some View {
        Group {
            if item.aiStatus == .processing || item.aiStatus == .pending {
                ProgressView()
                    .controlSize(.regular)
                    .tint(Color(white: 0.3)) // 深灰色，与文字一致
                    .shadow(color: .white, radius: 0, x: 1, y: 1) // 白色描边模拟
                    .shadow(color: .white, radius: 0, x: -1, y: -1)
                    .shadow(color: .white, radius: 0, x: 1, y: -1)
                    .shadow(color: .white, radius: 0, x: -1, y: 1)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: -10) { // 负间距，让文字稍微往上贴一点，更有贴纸感
            // 图片区域
            ZStack(alignment: .topTrailing) {
                // 1. 优先尝试显示缩略图
                if let thumbnailData = item.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                    let displayHeight = calculateDisplayHeight(for: uiImage)
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: displayHeight)
                        .id("thumb-\(item.id)-\(height)")
                        .shadow(color: .black.opacity(0.15), radius: 3, x: 2, y: 3)
                        .overlay {
                            loadingOverlay
                        }
                } 
                // 2. 如果没有缩略图，但有原图，判断是否正在迁移中 (即是否应该等待缩略图生成)
                // 这里的逻辑是：为了防止内存爆炸，我们不再轻易加载原图。
                // 如果有原图但没缩略图，我们显示一个"加载中/生成中"的占位符，等待后台迁移任务完成。
                // 除非原图本身就很小 (比如 < 100KB)，但我们很难在不加载 Data 的情况下知道大小。
                // 所以稳妥起见，我们显示占位符。
                else if item.imageData != nil {
                    // 显示"生成中"占位符
                    ZStack {
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: height * 0.5)
                            .foregroundStyle(.gray.opacity(0.3))
                        
                        ProgressView()
                            .controlSize(.small)
                            .padding(.top, 30)
                    }
                    .frame(height: height) // 保持高度占位
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.5))
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    )
                    .id("generating-\(item.id)")
                }
                // 3. 既没缩略图也没原图 (纯文本物品)
                else {
                    // 无图时的占位符，做成贴纸样式
                    Image(systemName: "cube.box.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(height: height * 0.66) // 占位符高度也相应调整
                        .padding(height * 0.16)
                        .foregroundStyle(.gray.opacity(0.5))
                        .background(
                            Circle()
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                        )
                        .id("placeholder-\(item.id)-\(height)")
                }
                
                // 数量显示：数量大于等于 2 时显示，格式为「xN」
                // 样式与名称一致：深灰字 + 白色粗描边 + 阴影
                if item.quantity >= 2 {
                    let text = "x\(item.quantity)"
                    Text(text)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(white: 0.3))
                        // 使用 shadow 模拟白色描边，避免多层 Text 导致布局不一致
                        .shadow(color: .white, radius: 0, x: 1.5, y: 1.5)
                        .shadow(color: .white, radius: 0, x: -1.5, y: -1.5)
                        .shadow(color: .white, radius: 0, x: 1.5, y: -1.5)
                        .shadow(color: .white, radius: 0, x: -1.5, y: 1.5)
                        .shadow(color: .white, radius: 1, x: 0, y: 0) // 增加一点柔和度
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 1, y: 1) // 投影
                        .padding(6)
                        .offset(x: 5, y: -5)
                }
            }
            .zIndex(1) // 确保图片在文字上方 (如果需要文字压图则改小)
            
            // 文字区域 (贴纸风格：深灰字 + 白色粗描边 + 阴影)
            // 使用单个 Text + 多个 Shadow 模拟描边，彻底解决多行文字布局不一致的问题
            Text(item.aiStatus == .processing || item.aiStatus == .pending ? "识别中..." : item.name)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(item.aiStatus == .failed ? Color.orange : Color(white: 0.3))
                // 使用 shadow 模拟白色描边
                .shadow(color: .white, radius: 0, x: 1.5, y: 1.5)
                .shadow(color: .white, radius: 0, x: -1.5, y: -1.5)
                .shadow(color: .white, radius: 0, x: 1.5, y: -1.5)
                .shadow(color: .white, radius: 0, x: -1.5, y: 1.5)
                .shadow(color: .white, radius: 1, x: 0, y: 0) // 增加一点柔和度
                .shadow(color: .black.opacity(0.1), radius: 2, x: 1, y: 1) // 投影
                .opacity((item.aiStatus == .processing || item.aiStatus == .pending) ? 0.6 : 1.0)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .zIndex(2) // 文字层级
        }
        .rotationEffect(.degrees(rotationAngle)) // 应用随机旋转
        .padding(8) // 减小默认内边距，使贴纸排列更紧凑
        // 移除 drawingGroup() 以修复缩放后的渲染问题（图片不更新、文字错乱）
        // .drawingGroup()
    }
}

#Preview {
    let item = Item(name: "可爱的汉堡", category: .food)
    return StickerGridItemView(item: item)
}
