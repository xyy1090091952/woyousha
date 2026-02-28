//
//  Item.swift
//  woyousha
//
//  Created by ByteDance on 2/27/26.
//

import Foundation
import SwiftData

// 定义分类枚举
enum Category: String, CaseIterable, Codable {
    case clothes = "衣服"
    case tools = "工具"
    case medicine = "药品"
    case books = "书籍"
    case food = "食品"
    case digital = "数码"
    case other = "其他"
}

// @Model 是 SwiftData 的核心标记，告诉系统这个类需要被存储到数据库中
// 类似于 Web 开发中的 ORM 模型定义 (比如 TypeORM 的 @Entity)
@Model
final class Item {
    // 唯一标识符
    var id: UUID
    
    // 物品的图片数据
    // 使用 Data 类型存储图片二进制数据，加问号 ? 表示这个字段是可选的（可以没有图片）
    // @Attribute(.externalStorage) 告诉系统如果图片很大，尽量存在外部文件中，不要把数据库撑爆
    @Attribute(.externalStorage) var imageData: Data?
    
    // 物品名称/描述 (例如：棕色羽绒服)
    var name: String
    
    // 物品分类 (例如：衣服、工具、药品)
    // 存储时使用 rawValue (String)，但在代码逻辑中使用枚举类型
    // 注意：SwiftData 默认支持 Codable 枚举，但为了简单起见，我们也可以存 String
    // 为了更严格的类型安全，我们这里存 String，通过计算属性转换为枚举
    var categoryRawValue: String
    
    // 计算属性：方便代码中直接使用枚举
    var category: Category {
        get { Category(rawValue: categoryRawValue) ?? .other }
        set { categoryRawValue = newValue.rawValue }
    }
    
    // 数量 (例如：1)
    var quantity: Int
    
    // 位置 (例如：衣柜第二层)
    var location: String
    
    // 录入时间，自动设置为当前时间
    var createdDate: Date
    
    // 更新时间，记录最后一次修改的时间
    var updatedDate: Date
    
    // 过期时间/耐久度 (可选，因为不是所有东西都会过期)
    var expirationDate: Date?
    
    // 备注信息
    var note: String
    
    // 所属容器
    // 自动通过 Container 中的 inverse 建立双向关系，Item 端通常不需要重复显式定义
    var container: Container?
    
    // 初始化方法，类似于 JavaScript class 的 constructor
    // 我们为很多参数提供了默认值，这样创建物品时就不需要每次都填所有信息
    init(
        id: UUID = UUID(),
        name: String = "新物品",
        imageData: Data? = nil,
        category: Category = .other, // 默认分类改为枚举
        quantity: Int = 1,
        location: String = "未指定位置",
        createdDate: Date = Date(),
        updatedDate: Date = Date(), // 默认更新时间也是当前时间
        expirationDate: Date? = nil,
        note: String = "",
        container: Container? = nil
    ) {
        self.id = id
        self.name = name
        self.imageData = imageData
        self.categoryRawValue = category.rawValue // 存储 rawValue
        self.quantity = quantity
        self.location = location
        self.createdDate = createdDate
        self.updatedDate = updatedDate
        self.expirationDate = expirationDate
        self.note = note
        self.container = container
    }
}
