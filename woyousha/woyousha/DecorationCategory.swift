import Foundation

/// 装饰物目录浮层的 4 个分类 tab；只用于浏览，不写入已保存的装饰 JSON。
nonisolated enum DecorationTab: String, CatalogTab {
    case plants, wall, softGoods, ornaments

    var id: String { rawValue }
    var title: String {
        switch self {
        case .plants: return "绿植花艺"
        case .wall: return "墙面装饰"
        case .softGoods: return "软装布艺"
        case .ornaments: return "家居摆件"
        }
    }
    var symbol: String {
        switch self {
        case .plants: return "leaf.fill"
        case .wall: return "photo.artframe"
        case .softGoods: return "teddybear.fill"
        case .ornaments: return "lamp.table.fill"
        }
    }
}

extension RoomDecoration.Kind: Identifiable {
    nonisolated var id: String { rawValue }

    nonisolated var tab: DecorationTab {
        switch self {
        case .plant, .cactus, .flowers: return .plants
        case .window, .picture, .wallShelf, .calendar, .clock: return .wall
        case .rug, .cushions, .teddyBear, .petBed: return .softGoods
        case .tableLamp, .floorMirror, .aquarium, .speaker: return .ornaments
        }
    }

    /// 搜索同义词：用户常用的叫法也能搜到，例如“窗帘”“相框”“台灯”。
    nonisolated var searchKeywords: [String] {
        switch self {
        case .plant: return ["盆栽", "植物", "绿萝"]
        case .rug: return ["地垫", "毯子"]
        case .window: return ["窗户", "窗帘"]
        case .picture: return ["装饰画", "相框", "画框"]
        case .wallShelf: return ["隔板", "壁架", "置物架"]
        case .calendar: return ["月历", "挂历"]
        case .clock: return ["时钟", "钟表"]
        case .flowers: return ["花", "插花", "花束"]
        case .tableLamp: return ["台灯", "灯", "照明"]
        case .cactus: return ["多肉", "植物"]
        case .cushions: return ["抱枕", "枕头"]
        case .teddyBear: return ["玩偶", "公仔", "毛绒"]
        case .floorMirror: return ["镜子", "落地镜"]
        case .aquarium: return ["鱼", "水族"]
        case .speaker: return ["音响", "蓝牙"]
        case .petBed: return ["猫窝", "狗窝", "宠物"]
        }
    }

    nonisolated var catalogSearchText: String {
        ([title, tab.title] + searchKeywords).joined(separator: " ")
    }
}
