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
    
    var body: some View {
        VStack(spacing: -10) { // 负间距，让文字稍微往上贴一点，更有贴纸感
            // 图片区域
            ZStack(alignment: .topTrailing) {
                if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                    let displayHeight = calculateDisplayHeight(for: uiImage)
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        // 使用 frame(width:height:) 约束，但只约束高度，宽度自适应
                        // 注意：这里我们只设置高度，让宽度自适应，但高度是经过计算的
                        // 或者更稳妥地，使用 frame(width:height:) 如果我们确信比例
                        .frame(height: displayHeight)
                        // 强制 Image 在 height 变化时刷新
                        .id("image-\(item.id)-\(height)")
                        // 贴纸阴影：模拟微微翘起的效果
                        .shadow(color: .black.opacity(0.15), radius: 3, x: 2, y: 3)
                } else {
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
                        // 强制占位符在 height 变化时刷新
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
            Text(item.name)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(Color(white: 0.3))
                // 使用 shadow 模拟白色描边
                .shadow(color: .white, radius: 0, x: 1.5, y: 1.5)
                .shadow(color: .white, radius: 0, x: -1.5, y: -1.5)
                .shadow(color: .white, radius: 0, x: 1.5, y: -1.5)
                .shadow(color: .white, radius: 0, x: -1.5, y: 1.5)
                .shadow(color: .white, radius: 1, x: 0, y: 0) // 增加一点柔和度
                .shadow(color: .black.opacity(0.1), radius: 2, x: 1, y: 1) // 投影
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .zIndex(2) // 文字层级
        }
        .rotationEffect(.degrees(rotationAngle)) // 应用随机旋转
        .padding()
        // 移除 drawingGroup() 以修复缩放后的渲染问题（图片不更新、文字错乱）
        // .drawingGroup()
    }
}

#Preview {
    let item = Item(name: "可爱的汉堡", category: .food)
    return StickerGridItemView(item: item)
}
