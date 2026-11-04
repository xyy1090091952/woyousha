import Foundation

/// 每个房间的装修选项集中在这里；存档保存稳定编号，颜色和材质由同一目录提供。
nonisolated enum HouseFloorFinish: String, Codable, CaseIterable {
    case honeyWood, paleWood, walnutWood, creamTile, sageTile, roseTile
    var title: String {
        switch self {
        case .honeyWood: return "蜂蜜木"
        case .paleWood: return "浅橡木"
        case .walnutWood: return "胡桃木"
        case .creamTile: return "奶油砖"
        case .sageTile: return "鼠尾草砖"
        case .roseTile: return "暖粉砖"
        }
    }
    var color: UInt32 {
        switch self {
        case .honeyWood: return OyohaPalette.floor
        case .paleWood: return 0xD9C09B
        case .walnutWood: return 0xA77A58
        case .creamTile: return 0xEAE0C8
        case .sageTile: return 0xB9CEC1
        case .roseTile: return 0xDDBBAA
        }
    }
    var material: IsoMaterial {
        switch self {
        case .honeyWood, .paleWood, .walnutWood: return .wood
        default: return .smooth
        }
    }
}

nonisolated enum HouseWallFinish: String, Codable, CaseIterable {
    case apricot, ivory, sage, rose, mistBlue, warmClay
    var title: String {
        switch self {
        case .apricot: return "奶油杏"
        case .ivory: return "米白"
        case .sage: return "鼠尾草"
        case .rose: return "桃粉"
        case .mistBlue: return "雾蓝"
        case .warmClay: return "暖陶"
        }
    }
    var color: UInt32 {
        switch self {
        case .apricot: return OyohaPalette.wall
        case .ivory: return 0xEDE3D1
        case .sage: return 0xBCCCAF
        case .rose: return 0xE1BEB2
        case .mistBlue: return 0xBDD0D5
        case .warmClay: return 0xD6AC8F
        }
    }
}
