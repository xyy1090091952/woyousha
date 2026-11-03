import Foundation

/// 细分组只决定“用哪个造型文件来画”，以及图标与搜索同义词；不在界面上直接展示。
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

    /// 浮层只显示 6 个 tab：把相近的细分组合并，好比商场把“男装/女装”合成“服饰”一层。
    var tab: FurnitureTab {
        switch self {
        case .bedroom: return .bedroom
        case .livingRoom, .appliances, .lighting: return .livingRoom
        case .study: return .study
        case .kitchen, .bathroom: return .kitchenAndBath
        case .storage: return .storage
        case .childrenAndPets, .outdoor: return .leisure
        }
    }
}

/// 家具目录浮层的 6 个分类 tab。
nonisolated enum FurnitureTab: String, CatalogTab {
    case bedroom, livingRoom, study, kitchenAndBath, storage, leisure

    var id: String { rawValue }
    var title: String {
        switch self {
        case .bedroom: return "卧室"
        case .livingRoom: return "客厅"
        case .study: return "书房"
        case .kitchenAndBath: return "厨卫"
        case .storage: return "收纳"
        case .leisure: return "休闲户外"
        }
    }
    var symbol: String {
        switch self {
        case .bedroom: return "bed.double.fill"
        case .livingRoom: return "sofa.fill"
        case .study: return "books.vertical.fill"
        case .kitchenAndBath: return "fork.knife"
        case .storage: return "archivebox.fill"
        case .leisure: return "leaf.fill"
        }
    }
}

extension FurnitureConfig {
    var tab: FurnitureTab { category.tab }

    /// 搜索同时覆盖名称、tab 名、细分组名与同义词，例如搜“宠物”“灯”依然能找到。
    var catalogSearchText: String {
        ([name, tab.title, category.title] + searchKeywords).joined(separator: " ")
    }
}

/// 家具目录的筛选条件：一个 tab + 搜索词。
typealias FurnitureCatalogQuery = CatalogQuery<FurnitureTab>
