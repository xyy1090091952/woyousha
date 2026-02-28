//
//  DragPreviewView.swift
//  woyousha
//
//  Created by ByteDance on 2/28/26.
//

import SwiftUI

struct DragPreviewView: View {
    let items: [Item]
    
    var body: some View {
        ZStack {
            if items.isEmpty {
                EmptyView()
            } else {
                // 单个或多个物品预览
                // 使用 ZStack 将它们居中对齐，以便 DragGesture 获取中心点
                if items.count == 1 {
                    singleItemPreview(items[0])
                } else {
                    multiItemPreview
                }
            }
        }
    }
    
    @ViewBuilder
    private func singleItemPreview(_ item: Item) -> some View {
        // 关键修复：
        // 1. 移除 .background(Color.clear) —— 显式的 clear 背景也会被系统识别为有形状
        // 2. 移除固定 width/height —— 让图片保持原始比例，使用 scaledToFit 和 maxWidth/maxHeight 限制大小
        // 3. 确保 Image 本身就是最终渲染的内容
        if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 100, maxHeight: 100) // 使用 maxWidth/Height 而不是固定尺寸，避免长方形图片两侧出现透明填充
        } else {
            Image(systemName: "cube.box.fill")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 80, maxHeight: 80)
                .foregroundStyle(.gray.opacity(0.5))
        }
    }
    
    private var multiItemPreview: some View {
        ZStack(alignment: .center) {
            // 显示前 3 个物品，做成堆叠效果
            let previewItems = Array(items.prefix(3))
            
            // 注意：因为 ZStack 是从后往前渲染，所以我们需要先渲染底部的（index 2, 1），最后渲染顶部的（index 0）
            // previewItems 的顺序是 [顶层, 第二层, 第三层]
            // 所以我们需要反向遍历：2 -> 1 -> 0
            
            ForEach(Array(previewItems.enumerated().reversed()), id: \.element.id) { index, item in
                singleItemPreview(item)
                    // 稍微旋转错开
                    .rotationEffect(.degrees(Double(index) * 5.0 - 5.0)) 
                    .offset(x: CGFloat(index) * 4, y: CGFloat(index) * 4)
            }
            
            // 数量角标
            if items.count > 1 {
                Text("\(items.count)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.red)) // 改为红色，模仿系统
                    .offset(x: 40, y: -40) // 右上角，稍微收一点，确保在框内
                    .shadow(radius: 2)
                    .zIndex(100) // 确保角标在最上层
            }
        }
        // 关键修复：
        // 1. 移除固定的 frame(width: 130, height: 130)，因为这会强制一个矩形区域，导致系统显示边框
        // 2. 使用 padding(20) 来确保角标和旋转部分不被裁剪，同时又不强制矩形
        // 3. 使用 drawingGroup() 将多层视图合成为单层绘制，这有助于系统正确识别透明度遮罩，从而消除矩形边框
        .padding(20)
        .drawingGroup()
    }
}
