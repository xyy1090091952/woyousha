//
//  Container.swift
//  woyousha
//
//  Created by ByteDance on 2/28/26.
//

import Foundation
import SwiftData

@Model
final class Container {
    var id: UUID
    var name: String
    var icon: String // SF Symbol name or custom icon name
    var type: String // e.g., "furniture", "box", "bag"
    
    // Relationship to items
    // inverse relationship is defined in Item
    @Relationship(deleteRule: .nullify, inverse: \Item.container)
    var items: [Item]? = []
    
    // Grid Placement Properties
    // 使用 Optional 因为旧数据可能没有这些字段
    var gridX: Int = 0
    var gridY: Int = 0
    // 占地大小，例如 1x1, 2x1 (宽x深)
    var gridWidth: Int = 1
    var gridDepth: Int = 1
    // 是否已放置在“家”中
    var isPlaced: Bool = false
    // 关联的家具图片名称 (如果是自定义图片)
    var furnitureImageName: String?
    
    // Free Placement Properties (Sticker Mode)
    var posX: Double = 0.0 // 屏幕/图片相对坐标 X
    var posY: Double = 0.0 // 屏幕/图片相对坐标 Y
    var scale: Double = 1.0 // 缩放比例
    var isMirrored: Bool = false // 是否水平镜像
    var zIndex: Int = 0 // 层级顺序
    
    var createdDate: Date
    var updatedDate: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "cube.box",
        type: String = "furniture",
        gridX: Int = 0,
        gridY: Int = 0,
        gridWidth: Int = 1,
        gridDepth: Int = 1,
        isPlaced: Bool = false,
        furnitureImageName: String? = nil,
        posX: Double = 0.0,
        posY: Double = 0.0,
        scale: Double = 1.0,
        isMirrored: Bool = false,
        zIndex: Int = 0,
        createdDate: Date = Date(),
        updatedDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.type = type
        self.gridX = gridX
        self.gridY = gridY
        self.gridWidth = gridWidth
        self.gridDepth = gridDepth
        self.isPlaced = isPlaced
        self.furnitureImageName = furnitureImageName
        self.posX = posX
        self.posY = posY
        self.scale = scale
        self.isMirrored = isMirrored
        self.zIndex = zIndex
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }
}
