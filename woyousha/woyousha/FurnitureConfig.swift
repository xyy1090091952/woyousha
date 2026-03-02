//
//  FurnitureConfig.swift
//  woyousha
//
//  Created by ByteDance on 3/2/26.
//

import Foundation

// 家具配置结构体
struct FurnitureConfig {
    let name: String
    let icon: String // SF Symbol
    let imageName: String // Assets image name
    let width: Int // 占地宽度 (网格数)
    let depth: Int // 占地深度 (网格数)
    
    // 新增视觉调整参数
    var scale: CGFloat = 1.0 // 默认缩放比例
    var offsetY: CGFloat = 0.0 // 默认垂直偏移
    
    // 初始化方法
    init(name: String, icon: String, imageName: String, width: Int, depth: Int, scale: CGFloat = 1.0, offsetY: CGFloat = 0.0) {
        self.name = name
        self.icon = icon
        self.imageName = imageName
        self.width = width
        self.depth = depth
        self.scale = scale
        self.offsetY = offsetY
    }
    
    // 预设家具列表
    static let all: [FurnitureConfig] = [
        FurnitureConfig(name: "冰箱", icon: "refrigerator", imageName: "bingxiang", width: 1, depth: 1, scale: 0.9, offsetY: 0),
        FurnitureConfig(name: "衣柜", icon: "door.left.hand.closed", imageName: "yigui", width: 2, depth: 1, scale: 0.95, offsetY: 0),
        FurnitureConfig(name: "沙发", icon: "sofa", imageName: "shafa", width: 2, depth: 1, scale: 0.9, offsetY: 0),
        FurnitureConfig(name: "餐桌", icon: "table.furniture", imageName: "fanzhuo", width: 2, depth: 2, scale: 0.85, offsetY: 0),
        FurnitureConfig(name: "书架", icon: "books.vertical", imageName: "bijia", width: 1, depth: 1, scale: 0.9, offsetY: 0), // "bijia" 可能是 "shujia" 的拼写错误，或者 "笔架"? 暂且当书架用
        FurnitureConfig(name: "电视柜", icon: "tv", imageName: "dianshigui", width: 2, depth: 1, scale: 0.9, offsetY: 0),
        FurnitureConfig(name: "背包", icon: "backpack", imageName: "beibao", width: 1, depth: 1, scale: 0.8, offsetY: 10)
    ]
    
    // 根据名称获取配置
    static func get(byImageName imageName: String) -> FurnitureConfig? {
        return all.first { $0.imageName == imageName }
    }
}
