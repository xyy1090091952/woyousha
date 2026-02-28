//
//  StickerGridItemView.swift
//  woyousha
//
//  Created by ByteDance on 2/27/26.
//

import SwiftUI

struct StickerGridItemView: View {
    let item: Item
    
    // 随机旋转角度 (-3 ~ 3 度)，模拟手贴的自然感
    // 注意：每次视图刷新可能会重新计算，最好是基于 item 的某个属性固定，或者在 onAppear 中设置
    // 为了简单起见，这里先固定为 0，或者基于 id 的 hash
    var rotationAngle: Double {
        // 基于 item.name 和 quantity 的 hash 生成一个伪随机角度，保证每次渲染一致
        let hash = (abs(item.name.hashValue) + item.quantity) % 7 - 3 // -3 到 3
        return Double(hash)
    }
    
    var body: some View {
        VStack(spacing: -10) { // 负间距，让文字稍微往上贴一点，更有贴纸感
            // 图片区域
            if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120) // 贴纸高度
                    // 贴纸阴影：模拟微微翘起的效果
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 2, y: 3)
                    .zIndex(1) // 确保图片在文字上方 (如果需要文字压图则改小)
            } else {
                // 无图时的占位符，做成贴纸样式
                Image(systemName: "cube.box.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .padding(20)
                    .foregroundStyle(.gray.opacity(0.5))
                    .background(
                        Circle()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                    )
                    .zIndex(1)
            }
            
            // 文字区域 (贴纸风格：深灰字 + 白色粗描边 + 阴影)
            ZStack {
                // 1. 描边层 (White Stroke)
                // 通过叠加多个偏移的白色文字来模拟粗描边
                // 增加 offset 到 2.5，让描边更粗
                // 增加更多的角度覆盖，防止描边出现锯齿或空隙
                Group {
                    // 外圈
                    Text(item.name).offset(x: 2.5, y: 0)
                    Text(item.name).offset(x: -2.5, y: 0)
                    Text(item.name).offset(x: 0, y: 2.5)
                    Text(item.name).offset(x: 0, y: -2.5)
                    
                    Text(item.name).offset(x: 1.8, y: 1.8)
                    Text(item.name).offset(x: -1.8, y: -1.8)
                    Text(item.name).offset(x: 1.8, y: -1.8)
                    Text(item.name).offset(x: -1.8, y: 1.8)
                    
                    // 内圈 (填补空隙)
                    Text(item.name).offset(x: 1.2, y: 0)
                    Text(item.name).offset(x: -1.2, y: 0)
                    Text(item.name).offset(x: 0, y: 1.2)
                    Text(item.name).offset(x: 0, y: -1.2)
                    
                    Text(item.name) // 中间填充
                }
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                // 调整投影：透明度从 0.2 降到 0.1，更淡一些
                .shadow(color: .black.opacity(0.1), radius: 2, x: 1, y: 1)
                
                // 2. 顶层：文字本体 (深灰色)
                Text(item.name)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundStyle(Color(white: 0.3))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .zIndex(2) // 文字层级
        }
        .rotationEffect(.degrees(rotationAngle)) // 应用随机旋转
        .padding()
    }
}

#Preview {
    let item = Item(name: "可爱的汉堡", category: .food)
    return StickerGridItemView(item: item)
}
