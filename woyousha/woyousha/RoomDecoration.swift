import Foundation
import CoreGraphics

/// 装饰物没有物品关系，只保存布置状态。独立 JSON 存储不会改变原 SwiftData 模型。
nonisolated struct RoomDecoration: Identifiable, Codable, Equatable {
    var id: String
    var kind: Kind
    var posX: Double
    var posY: Double
    var scale: Double = 1
    var isMirrored = false
    var zIndex: Int = 0
    // 收起后保留在待布置区，下一次可以放回房间。
    var isPlaced = true
    // Optional 可以读取没有格子字段的旧 JSON，首次升级再安全对齐。
    var gridX: Int? = nil
    var gridY: Int? = nil
    var name: String { kind.title }

    enum Kind: String, Codable, CaseIterable {
        case plant, rug, window, picture, wallShelf, calendar
        case clock, flowers, tableLamp, cactus, cushions, teddyBear, floorMirror, aquarium, speaker, petBed
        var title: String {
            switch self {
            case .plant: return "绿植"
            case .rug: return "地毯"
            case .window: return "窗饰"
            case .picture: return "挂画"
            case .wallShelf: return "装饰置物架"
            case .calendar: return "日历"
            case .clock: return "挂钟"
            case .flowers: return "花瓶鲜花"
            case .tableLamp: return "阅读台灯"
            case .cactus: return "仙人掌"
            case .cushions: return "靠垫"
            case .teddyBear: return "玩偶小熊"
            case .floorMirror: return "穿衣镜"
            case .aquarium: return "鱼缸"
            case .speaker: return "音箱"
            case .petBed: return "宠物窝"
            }
        }
        var isFloorCovering: Bool { self == .rug }
        /// 挂在墙上的装饰不落地，不投地面影子。
        var isWallMounted: Bool {
            switch self {
            case .window, .picture, .wallShelf, .calendar, .clock: return true
            default: return false
            }
        }
    }
}

nonisolated enum DecorationCatalog {
    /// 将原房间中的固定画面元素还原到同一世界位置，首次升级不打乱画面。
    static let defaultAnchors: [(String,RoomDecoration.Kind,IsoPoint)] = [
        ("initial-rug", .rug, .init(88,75,0.25)),
        ("initial-plant", .plant, .init(13,110,3.2)),
        ("initial-window-plant", .plant, .init(6,39,24)),
        ("initial-shelf-plant", .plant, .init(39,4,56.7)),
        ("initial-window", .window, .init(0,51.5,22)),
        ("initial-picture", .picture, .init(84.5,0,31)),
        ("initial-shelf", .wallShelf, .init(28,0,55)),
        ("initial-calendar", .calendar, .init(57,0,30))
    ]
    static var defaults: [RoomDecoration] {
        defaultAnchors.map {
            var item=placed(id:$0.0,kind:$0.1,at:$0.2)
            if item.id=="initial-window-plant" || item.id=="initial-shelf-plant" { item.scale=0.6 }
            return item
        }
    }

    private static func placed(id: String, kind: RoomDecoration.Kind, at point: IsoPoint) -> RoomDecoration {
        let position = PixelArtRenderer.roomProjection.project(point)
        let factor = RoomConfig.roomWidth / Double(PixelArtRenderer.roomWidth)
        let verticalInset = (RoomConfig.roomHeight - Double(PixelArtRenderer.roomHeight)*factor)/2
        return RoomDecoration(id:id, kind:kind, posX:position.x*factor, posY:position.y*factor+verticalInset)
    }
}
