import Foundation
import Observation

/// 房型独立于家具与收纳物品。先完整编码，再发布新状态；损坏存档不被默认房覆盖。
@MainActor @Observable
final class HouseLayoutStore {
    static let shared = HouseLayoutStore()
    private(set) var layout: HouseLayout
    private(set) var loadIssue: String?
    private let storage: UserDefaults
    private let key = "houseLayout.v1"

    init(storage: UserDefaults = .standard) {
        self.storage=storage
        if let data=storage.data(forKey:key) {
            if let saved=try? JSONDecoder().decode(HouseLayout.self,from:data), (try? saved.validate()) != nil {
                layout=saved
            } else {
                layout = .initial
                loadIssue=HouseRuleError.damagedSave.localizedDescription
            }
        } else { layout = .initial }
    }

    func check(_ room: HouseRoom, occupants: [HouseOccupant]) throws {
        if let old=layout.rooms.first(where:{$0.id == room.id}),
           (old.x != room.x || old.y != room.y),
           occupants.contains(where:{!$0.cells.isDisjoint(with:old.cells)}) { throw HouseRuleError.roomNotEmpty }
        let proposed=layout.replacing(room)
        try proposed.validate()
        for item in occupants {
            // 原本在室内的物品不能因改房型变成露天物品；院子里的物品也不能被新房吞掉。
            let wasInside=layout.rooms.contains { $0.contains(item.cells) }
            let nowInside=proposed.rooms.contains { $0.contains(item.cells) }
            guard wasInside == nowInside else { throw HouseRuleError.roomNotEmpty }
            if item.layer != .covering && !item.cells.isDisjoint(with:proposed.passageCells) { throw HouseRuleError.doorway }
            if item.layer == .wall {
                guard let owner=proposed.rooms.first(where:{$0.contains(item.cells)}),
                      item.cell.x == owner.x || item.cell.y == owner.y else { throw HouseRuleError.wallOnly }
            }
        }
    }

    func save(_ room: HouseRoom, occupants: [HouseOccupant]) throws {
        try check(room,occupants:occupants)
        try commit(layout.replacing(room))
    }

    func remove(id: String, occupants: [HouseOccupant]) throws {
        guard layout.rooms.count > 1 else { throw HouseRuleError.lastRoom }
        guard let room=layout.rooms.first(where:{$0.id == id}) else { return }
        guard !occupants.contains(where:{ !$0.cells.isDisjoint(with:room.cells) }) else { throw HouseRuleError.roomNotEmpty }
        var updated=layout
        updated.rooms.removeAll { $0.id == id }
        try updated.validate()
        try commit(updated)
    }

    func suggestedRoom(kind: HouseRoom.Kind = .bedroom) -> HouseRoom {
        var draft=HouseRoom(name:kind.title,kind:kind,x:12,y:4,width:5,depth:5)
        for y in 0..<HouseGridConfig.plotSize {
            for x in 0..<HouseGridConfig.plotSize {
                draft.x=x;draft.y=y
                if (try? layout.replacing(draft).validate()) != nil { return draft }
            }
        }
        return draft
    }

    private func commit(_ updated: HouseLayout) throws {
        guard loadIssue == nil else { throw HouseRuleError.damagedSave }
        try updated.validate()
        let data=try JSONEncoder().encode(updated)
        storage.set(data,forKey:key)
        layout=updated
    }
}
