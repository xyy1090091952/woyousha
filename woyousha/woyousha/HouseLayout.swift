import Foundation
import CoreGraphics

/// 家园的实际坐标。一个格子对应固定的世界尺寸，不跟随视角缩放变化。
nonisolated enum HouseGridConfig {
    static let tile = 16.0
    static let plotSize = 24
    static let roomSize = 3...12
    static let wallHeight = 52.0
    static let yardMargin = 3
    static let canvasSize = 800.0
}

nonisolated struct HouseCell: Codable, Hashable {
    var x: Int
    var y: Int
}

nonisolated struct HouseFootprint: Codable, Equatable {
    var width: Int
    var depth: Int
    func cells(at cell: HouseCell) -> Set<HouseCell> {
        guard width > 0, depth > 0, width <= HouseGridConfig.plotSize, depth <= HouseGridConfig.plotSize,
              cell.x >= -HouseGridConfig.plotSize,cell.x <= HouseGridConfig.plotSize,
              cell.y >= -HouseGridConfig.plotSize,cell.y <= HouseGridConfig.plotSize else { return [] }
        return Set((cell.x..<(cell.x+width)).flatMap { x in
            (cell.y..<(cell.y+depth)).map { HouseCell(x:x,y:$0) }
        })
    }
}

nonisolated struct HouseRoom: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var name: String
    var kind: Kind
    var x: Int
    var y: Int
    var width: Int
    var depth: Int
    /// Optional 兼容没有装修字段的旧存档；nil 时继续使用原来的房间配色。
    var floorFinish: HouseFloorFinish? = nil
    var wallFinish: HouseWallFinish? = nil

    enum Kind: String, Codable, CaseIterable {
        case living, bedroom, kitchen, bathroom, study
        var title: String {
            switch self {
            case .living: return "客厅"
            case .bedroom: return "卧室"
            case .kitchen: return "厨房"
            case .bathroom: return "浴室"
            case .study: return "书房"
            }
        }
        var symbol: String {
            switch self {
            case .living: return "sofa.fill"
            case .bedroom: return "bed.double.fill"
            case .kitchen: return "fork.knife"
            case .bathroom: return "shower.fill"
            case .study: return "books.vertical.fill"
            }
        }
    }
    var cell: HouseCell { .init(x:x,y:y) }
    var footprint: HouseFootprint { .init(width:width,depth:depth) }
    var cells: Set<HouseCell> { footprint.cells(at:cell) }
    func contains(_ cells: Set<HouseCell>) -> Bool { !cells.isEmpty && cells.isSubset(of:self.cells) }
}

nonisolated enum HouseRuleError: LocalizedError, Equatable {
    case roomBounds, roomOverlap, disconnected, roomName, outsideRoom, occupied
    case wallOnly, noSpace, lastRoom, roomNotEmpty, fixedSize, damagedSave
    var errorDescription: String? {
        switch self {
        case .roomBounds: return "房间要在宅地内，长和宽为 3～12 格。"
        case .roomOverlap: return "房间重叠了，请移到空地上。"
        case .disconnected: return "房间要贴着已有房间，至少共用两格墙面，才能连接门洞。"
        case .roomName: return "给房间起一个 1～12 字的名字。"
        case .outsideRoom: return "家具要完整放在同一个房间里，不能跨墙或摆出地板。"
        case .occupied: return "这些格子已经被占用，请换一个位置。"
        case .wallOnly: return "这件物品需要靠房间的后侧墙面摆放。"
        case .noSpace: return "没有足够的空格了，可以先扩建房间或收起一些家具。"
        case .lastRoom: return "至少保留一个房间。"
        case .roomNotEmpty: return "先收起或移走这个房间里的家具和装饰，再拆除房间。"
        case .fixedSize: return "家具使用固定格子尺寸，不能自由缩放或调整图层。"
        case .damagedSave: return "家园存档暂时无法读取，已保留原存档。请重新打开后再试。"
        }
    }
}

/// 连接相邻房间的两格门洞。过道仅标记房间连接，不限制家具摆放。
nonisolated struct HouseDoor {
    let vertical: Bool
    let boundary: Int
    let start: Int
    let roomIDs: Set<String>
    var passage: Set<HouseCell> {
        if vertical {
            return Set([boundary-1,boundary].flatMap { x in (start..<(start+2)).map { HouseCell(x:x,y:$0) } })
        }
        return Set([boundary-1,boundary].flatMap { y in (start..<(start+2)).map { HouseCell(x:$0,y:y) } })
    }
}

nonisolated struct HouseLayout: Codable, Equatable {
    var version = 1
    var rooms: [HouseRoom]
    static let initial = HouseLayout(rooms:[
        HouseRoom(id:"initial-living",name:"客厅",kind:.living,x:4,y:4,width:8,depth:8)
    ])
    // 仅用于预览，不替换用户的家。
    static let example = HouseLayout(rooms:initial.rooms+[
        HouseRoom(id:"bedroom-one",name:"主卧",kind:.bedroom,x:12,y:4,width:5,depth:5),
        HouseRoom(id:"bedroom-two",name:"次卧",kind:.bedroom,x:12,y:9,width:5,depth:5),
        HouseRoom(id:"bedroom-three",name:"小卧室",kind:.bedroom,x:4,y:12,width:8,depth:5)
    ])
    var floorCells: Set<HouseCell> { rooms.reduce(into:Set<HouseCell>()) { $0.formUnion($1.cells) } }
    var doors: [HouseDoor] {
        var result: [HouseDoor] = []
        for i in rooms.indices {
            for j in rooms.indices where j > i {
                let a=rooms[i], b=rooms[j], ids=Set([a.id,b.id])
                let y0=max(a.y,b.y), y1=min(a.y+a.depth,b.y+b.depth)
                let x0=max(a.x,b.x), x1=min(a.x+a.width,b.x+b.width)
                if y1-y0 >= 2 && (a.x+a.width == b.x || b.x+b.width == a.x) {
                    result.append(.init(vertical:true,boundary:max(a.x,b.x),start:y0+(y1-y0-2)/2,roomIDs:ids))
                }
                if x1-x0 >= 2 && (a.y+a.depth == b.y || b.y+b.depth == a.y) {
                    result.append(.init(vertical:false,boundary:max(a.y,b.y),start:x0+(x1-x0-2)/2,roomIDs:ids))
                }
            }
        }
        return result
    }
    var passageCells: Set<HouseCell> { doors.reduce(into:Set<HouseCell>()) { $0.formUnion($1.passage) } }

    func validate() throws {
        guard version == 1, !rooms.isEmpty, rooms.count <= 64,
              Set(rooms.map(\.id)).count == rooms.count else { throw HouseRuleError.damagedSave }
        var all=Set<HouseCell>()
        for room in rooms {
            guard !room.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty, room.name.count <= 12 else { throw HouseRuleError.roomName }
            guard HouseGridConfig.roomSize.contains(room.width),HouseGridConfig.roomSize.contains(room.depth),
                  room.x >= 0,room.y >= 0,room.x <= HouseGridConfig.plotSize,room.y <= HouseGridConfig.plotSize,
                  room.x+room.width <= HouseGridConfig.plotSize,
                  room.y+room.depth <= HouseGridConfig.plotSize else { throw HouseRuleError.roomBounds }
            guard all.isDisjoint(with:room.cells) else { throw HouseRuleError.roomOverlap }
            all.formUnion(room.cells)
        }
        var visited=Set([rooms[0].id])
        var changed=true
        while changed {
            changed=false
            for door in doors where !visited.isDisjoint(with:door.roomIDs) {
                let count=visited.count
                visited.formUnion(door.roomIDs)
                if count != visited.count { changed=true }
            }
        }
        guard visited.count == rooms.count else { throw HouseRuleError.disconnected }
    }

    func replacing(_ room: HouseRoom) -> HouseLayout {
        var result=self
        if let i=result.rooms.firstIndex(where:{$0.id == room.id}) { result.rooms[i]=room }
        else { result.rooms.append(room) }
        return result
    }
}

nonisolated enum HousePlacementLayer { case floor, wall, covering }
nonisolated struct HouseOccupant {
    let id: String
    let cell: HouseCell
    let footprint: HouseFootprint
    let layer: HousePlacementLayer
    var cells: Set<HouseCell> { footprint.cells(at:cell) }
}

/// 同一规则用于拖动预览、保存、转向和扩建，界面上的绿格与实际保存保持一致。
nonisolated enum HousePlacementRules {
    static func validate(cell: HouseCell, footprint: HouseFootprint, layer: HousePlacementLayer,
                         outdoors: Bool = false, layout: HouseLayout, occupants: [HouseOccupant],
                         excluding id: String? = nil) throws {
        let cells=footprint.cells(at:cell)
        guard !cells.isEmpty, cells.allSatisfy({$0.x >= 0 && $0.y >= 0 && $0.x < HouseGridConfig.plotSize && $0.y < HouseGridConfig.plotSize})
        else { throw HouseRuleError.outsideRoom }
        let room=layout.rooms.first { $0.contains(cells) }
        let inYard=outdoors && cells.isDisjoint(with:layout.floorCells)
        guard room != nil || inYard else { throw HouseRuleError.outsideRoom }
        if layer == .wall {
            guard let room,cell.x == room.x || cell.y == room.y else { throw HouseRuleError.wallOnly }
        }
        guard !occupants.contains(where:{$0.id != id && $0.layer == layer && !cells.isDisjoint(with:$0.cells)})
        else { throw HouseRuleError.occupied }
    }

    static func nearest(to desired: HouseCell, footprint: HouseFootprint, layer: HousePlacementLayer,
                        outdoors: Bool = false, layout: HouseLayout, occupants: [HouseOccupant],
                        excluding id: String? = nil) -> HouseCell? {
        let candidates=(0..<HouseGridConfig.plotSize).flatMap { x in
            (0..<HouseGridConfig.plotSize).map { HouseCell(x:x,y:$0) }
        }.sorted {
            let a=abs($0.x-desired.x)+abs($0.y-desired.y),b=abs($1.x-desired.x)+abs($1.y-desired.y)
            return a == b ? ($0.y == $1.y ? $0.x < $1.x : $0.y < $1.y) : a < b
        }
        return candidates.first { (try? validate(cell:$0,footprint:footprint,layer:layer,outdoors:outdoors,
                                               layout:layout,occupants:occupants,excluding:id)) != nil }
    }
}
