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
    
    var createdDate: Date
    var updatedDate: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "cube.box",
        type: String = "furniture",
        createdDate: Date = Date(),
        updatedDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.type = type
        self.createdDate = createdDate
        self.updatedDate = updatedDate
    }
}
