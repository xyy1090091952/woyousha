import Foundation

/// 分类只用于目录查找，不写入容器模型，也不改变已有房间布置。
nonisolated enum FurnitureCategory: String, CaseIterable, Identifiable {
    case bedroom, livingRoom, study, kitchen, bathroom
    case storage, appliances, childrenAndPets, outdoor, lighting

    var id: String { rawValue }
    var title: String {
        switch self {
        case .bedroom: return "卧室"
        case .livingRoom: return "客厅"
        case .study: return "书房办公"
        case .kitchen: return "厨房餐厅"
        case .bathroom: return "卫浴洗护"
        case .storage: return "收纳"
        case .appliances: return "家电影音"
        case .childrenAndPets: return "儿童宠物"
        case .outdoor: return "阳台户外"
        case .lighting: return "灯具"
        }
    }
}

/// 搜索、分类和新增条件在一处取交集，所有造型选择入口保持相同结果。
nonisolated struct FurnitureCatalogQuery {
    var category: FurnitureCategory?
    var onlyNew = false
    var searchText = ""

    var hasFilters: Bool {
        category != nil || onlyNew || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func matches(_ config: FurnitureConfig) -> Bool {
        if let category, config.category != category { return false }
        if onlyNew && !config.isNew { return false }
        let tokens = searchText.split(whereSeparator: \.isWhitespace)
        let text = ([config.name, config.category.title] + config.searchKeywords).joined(separator: " ")
        return tokens.allSatisfy { text.localizedStandardContains(String($0)) }
    }
}
