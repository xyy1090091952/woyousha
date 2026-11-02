//
//  FurnitureConfig.swift
//  woyousha
//
//  Created by ByteDance on 3/2/26.
//

import Foundation

// 家具配置结构体
struct FurnitureConfig: Identifiable {
    var id: String { imageName }
    let name: String
    let icon: String // SF Symbol
    let imageName: String // 兼容旧数据的造型 ID；目前由 PixelArtRenderer 生成，不再读取 Assets
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
        FurnitureConfig(name: "书架", icon: "books.vertical", imageName: "bijia", width: 1, depth: 1, scale: 0.9, offsetY: 0),
        FurnitureConfig(name: "电视柜", icon: "tv", imageName: "dianshigui", width: 2, depth: 1, scale: 0.9, offsetY: 0),
        FurnitureConfig(name: "背包", icon: "backpack", imageName: "beibao", width: 1, depth: 1, scale: 0.8, offsetY: 10),
        
        // 新增家具
        FurnitureConfig(name: "单人沙发", icon: "chair.lounge", imageName: "shafayi", width: 1, depth: 1, scale: 0.85, offsetY: 0),
        FurnitureConfig(name: "贝壳灯", icon: "lamp.table", imageName: "beikedeng", width: 1, depth: 1, scale: 0.8, offsetY: 5),
        FurnitureConfig(name: "垃圾桶", icon: "trash", imageName: "lajitong", width: 1, depth: 1, scale: 0.7, offsetY: 10),
        FurnitureConfig(name: "窗户", icon: "window.vertical.closed", imageName: "chuanghu", width: 1, depth: 1, scale: 1.0, offsetY: -20), // 尝试放在墙边
        FurnitureConfig(name: "大书架", icon: "books.vertical.fill", imageName: "shujia", width: 2, depth: 1, scale: 0.95, offsetY: 0),
        FurnitureConfig(name: "厨卫柜", icon: "cabinet", imageName: "chuwei", width: 2, depth: 1, scale: 0.9, offsetY: 0),
        FurnitureConfig(name: "木材堆", icon: "square.stack.3d.down.right", imageName: "mucai", width: 1, depth: 1, scale: 0.8, offsetY: 0),
        FurnitureConfig(name: "吸尘器", icon: "fan", imageName: "xichengqi", width: 1, depth: 1, scale: 0.8, offsetY: 0),
        FurnitureConfig(name: "大冰箱", icon: "refrigerator.fill", imageName: "bingxiang2", width: 1, depth: 1, scale: 0.9, offsetY: 0),
        FurnitureConfig(name: "纸箱", icon: "archivebox", imageName: "zhixiang", width: 1, depth: 1, scale: 0.8, offsetY: 5),
        FurnitureConfig(name: "电视", icon: "tv.fill", imageName: "dianshi", width: 1, depth: 1, scale: 0.9, offsetY: 0),
        FurnitureConfig(name: "大电视柜", icon: "cabinet.fill", imageName: "dianshigui2", width: 2, depth: 1, scale: 0.9, offsetY: 0),
        // 默认容器也有正式造型，防止“镜柜、推车”落到默认纸箱模型。
        FurnitureConfig(name: "小推车", icon: "cart", imageName: "cart", width: 1, depth: 1),
        FurnitureConfig(name: "镜柜", icon: "cabinet", imageName: "mirror", width: 1, depth: 1),
        FurnitureConfig(name: "墙壁", icon: "rectangle.split.3x1", imageName: "wall-panel", width: 2, depth: 1),
        FurnitureConfig(name: "落地灯", icon: "lamp.floor", imageName: "floor-lamp", width: 1, depth: 1),
        // 日常起居、学习、厨卫与出行；每个编号都有独立的等轴几何模型。
        FurnitureConfig(name: "双人床", icon: "bed.double", imageName: "double-bed", width: 2, depth: 2),
        FurnitureConfig(name: "床头柜", icon: "cabinet", imageName: "nightstand", width: 1, depth: 1),
        FurnitureConfig(name: "书桌", icon: "desktopcomputer", imageName: "study-desk", width: 2, depth: 1),
        FurnitureConfig(name: "餐椅", icon: "chair", imageName: "dining-chair", width: 1, depth: 1),
        FurnitureConfig(name: "茶几", icon: "table.furniture", imageName: "coffee-table", width: 2, depth: 1),
        FurnitureConfig(name: "鞋柜", icon: "cabinet", imageName: "shoe-cabinet", width: 2, depth: 1),
        FurnitureConfig(name: "梳妆台", icon: "sparkles", imageName: "dressing-table", width: 2, depth: 1),
        FurnitureConfig(name: "洗衣机", icon: "washer", imageName: "washing-machine", width: 1, depth: 1),
        FurnitureConfig(name: "烤箱灶台", icon: "oven", imageName: "oven-stove", width: 1, depth: 1),
        FurnitureConfig(name: "空调", icon: "air.conditioner.horizontal", imageName: "air-conditioner", width: 2, depth: 1),
        FurnitureConfig(name: "行李箱", icon: "suitcase.rolling", imageName: "suitcase", width: 1, depth: 1)
    ]
    
    // 根据名称获取配置
    static func get(byImageName imageName: String) -> FurnitureConfig? {
        return all.first { $0.imageName == imageName }
    }

    /// 用户明确选择的造型优先；自动造型按名称与图标匹配，失效编号退回自动选择。
    static func styleID(name: String, icon: String, savedID: String?) -> String {
        if let savedID, get(byImageName: savedID) != nil { return savedID }
        let aliases = [
            ("镜柜","mirror"),("镜子","mirror"),("厨房柜","chuwei"),("墙壁","wall-panel"),
            ("书包","beibao"),("小推车","cart"),("推车","cart"),("床头柜","nightstand"),
            ("双人床","double-bed"),("床铺","double-bed"),("电脑桌","study-desk"),("办公桌","study-desk"),
            ("洗衣","washing-machine"),("烤箱","oven-stove"),("灶台","oven-stove"),("旅行箱","suitcase")
        ]
        if let alias = aliases.first(where: { name.contains($0.0) }) { return alias.1 }
        if let match = all.sorted(by: { $0.name.count > $1.name.count }).first(where: { name.contains($0.name) }) {
            return match.imageName
        }
        if icon.contains("refrigerator") { return "bingxiang" }
        if icon.contains("washer") { return "washing-machine" }
        if icon.contains("oven") { return "oven-stove" }
        if icon.contains("air.conditioner") { return "air-conditioner" }
        if icon.contains("suitcase") { return "suitcase" }
        if icon.contains("bed.") { return "double-bed" }
        if icon.contains("desktopcomputer") { return "study-desk" }
        if icon.contains("mirror") { return "mirror" }
        if icon.contains("cabinet") { return "chuwei" }
        if icon.contains("cart") { return "cart" }
        if icon.contains("backpack") || icon.contains("bag") { return "beibao" }
        if icon.contains("book") { return "bijia" }
        if icon.contains("sofa") { return "shafa" }
        if icon.contains("chair") { return "shafayi" }
        if icon.contains("wall") { return "wall-panel" }
        if icon.contains("window") { return "chuanghu" }
        if icon.contains("hanger") || icon.contains("door") { return "yigui" }
        if icon.contains("lamp") { return "floor-lamp" }
        return "zhixiang"
    }
}
