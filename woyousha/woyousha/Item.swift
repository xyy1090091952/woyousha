//
//  Item.swift
//  woyousha
//
//  Created by ByteDance on 2/27/26.
//

import Foundation
import SwiftData

// @Model 是 SwiftData 的核心标记，告诉系统这个类需要被存储到数据库中
// 类似于 Web 开发中的 ORM 模型定义 (比如 TypeORM 的 @Entity)
@Model
final class Item {
    // 物品的图片数据
    // 使用 Data 类型存储图片二进制数据，加问号 ? 表示这个字段是可选的（可以没有图片）
    // @Attribute(.externalStorage) 告诉系统如果图片很大，尽量存在外部文件中，不要把数据库撑爆
    @Attribute(.externalStorage) var imageData: Data?
    
    // 物品名称/描述 (例如：棕色羽绒服)
    var name: String
    
    // 物品分类 (例如：衣服、工具、药品)
    // 后续我们可以把它升级为枚举(Enum)类型，现在先用字符串方便理解
    var category: String
    
    // 数量 (例如：1)
    var quantity: Int
    
    // 位置 (例如：衣柜第二层)
    var location: String
    
    // 录入时间，自动设置为当前时间
    var createdDate: Date
    
    // 过期时间/耐久度 (可选，因为不是所有东西都会过期)
    var expirationDate: Date?
    
    // 备注信息
    var note: String
    
    // 初始化方法，类似于 JavaScript class 的 constructor
    // 我们为很多参数提供了默认值，这样创建物品时就不需要每次都填所有信息
    init(
        name: String = "新物品",
        imageData: Data? = nil,
        category: String = "未分类",
        quantity: Int = 1,
        location: String = "未指定位置",
        createdDate: Date = Date(),
        expirationDate: Date? = nil,
        note: String = ""
    ) {
        self.name = name
        self.imageData = imageData
        self.category = category
        self.quantity = quantity
        self.location = location
        self.createdDate = createdDate
        self.expirationDate = expirationDate
        self.note = note
    }
}
