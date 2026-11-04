import Foundation
import Observation

/// 装饰物状态与存储共用一处。编码失败保持旧状态，避免首页与装修页面显示不一致。
@MainActor @Observable
final class RoomDecorationStore {
    static let shared = RoomDecorationStore()
    private(set) var decorations: [RoomDecoration]
    private(set) var loadIssue: String?
    private let storage: UserDefaults
    private let storageKey = "roomDecorationPlacements.v1"

    enum Action {
        case move(HouseCell), place(HouseCell), mirror, store, delete
    }

    init(storage: UserDefaults = .standard) {
        self.storage = storage
        if let data = storage.data(forKey: storageKey) {
            if let saved = try? JSONDecoder().decode([RoomDecoration].self, from:data) {
                // 收起也是一种有效状态，旧版仓库里的装饰继续保留。
                decorations = saved
            } else {
                decorations = []
                loadIssue = HouseRuleError.damagedSave.localizedDescription
            }
        } else {
            decorations = DecorationCatalog.defaults
        }
    }

    func perform(_ action: Action, id: String, containers: [Container] = [],
                 layout: HouseLayout? = nil) throws {
        let layout=layout ?? HouseLayoutStore.shared.layout
        try layout.validate()
        guard let index = decorations.firstIndex(where: { $0.id == id }) else { return }
        var updated = decorations
        switch action {
        case .move(let cell),.place(let cell):
            updated[index].gridX=cell.x;updated[index].gridY=cell.y
            updated[index].isPlaced=true
        case .mirror: updated[index].isMirrored.toggle()
        case .store: updated[index].isPlaced=false
        case .delete: updated.remove(at: index)
        }
        if let target=updated.first(where:{$0.id == id}),target.isPlaced {
            guard let x=target.gridX,let y=target.gridY else { throw HouseRuleError.noSpace }
            let model=HouseFurnitureCatalog.decoration(target.kind,mirrored:target.isMirrored)
            try HousePlacementRules.validate(cell:.init(x:x,y:y),footprint:model.footprint,
                layer:HouseFurnitureCatalog.layer(for:target.kind),layout:layout,
                occupants:HouseFurnitureCatalog.occupants(containers:containers,decorations:decorations),excluding:id)
        }
        if let index=updated.firstIndex(where:{$0.id == id}) { updated[index].scale=1 }
        try commit(updated)
    }

    func add(kind: RoomDecoration.Kind, containers: [Container] = [],
             layout: HouseLayout? = nil) throws -> String {
        let layout=layout ?? HouseLayoutStore.shared.layout
        try layout.validate()
        var updated = decorations
        let id = UUID().uuidString
        let model=HouseFurnitureCatalog.decoration(kind)
        let room=layout.rooms[0]
        guard let cell=HousePlacementRules.nearest(to:.init(x:room.x+2,y:room.y+2),footprint:model.footprint,
            layer:HouseFurnitureCatalog.layer(for:kind),layout:layout,
            occupants:HouseFurnitureCatalog.occupants(containers:containers,decorations:decorations)) else { throw HouseRuleError.noSpace }
        var target=RoomDecoration(id:id,kind:kind,posX:0,posY:0)
        target.gridX=cell.x;target.gridY=cell.y
        updated.append(target)
        try commit(updated)
        return id
    }

    /// 与家具升级分开提交，每件装饰带自己的完成标记，重试不会反复改变已对齐的物品。
    func adoptGrid(containers:[Container],layout:HouseLayout) throws -> Int {
        var updated=decorations,stored=0
        guard updated.contains(where:{$0.gridX == nil || $0.gridY == nil}) else { return 0 }
        if storage.data(forKey:"homeDecorationStickerBackup.v1") == nil {
            storage.set(try JSONEncoder().encode(updated),forKey:"homeDecorationStickerBackup.v1")
        }
        for i in updated.indices where updated[i].gridX == nil || updated[i].gridY == nil {
            let target=updated[i],model=HouseFurnitureCatalog.decoration(target.kind,mirrored:target.isMirrored)
            if !target.isPlaced {
                updated[i].gridX=0;updated[i].gridY=0;updated[i].scale=1
                continue
            }
            let desired=FurniturePlacementRepository.legacyCell(x:target.posX,y:target.posY,layout:layout)
            let occupants=HouseFurnitureCatalog.occupants(containers:containers,decorations:updated)
            if let cell=HousePlacementRules.nearest(to:desired,footprint:model.footprint,
                layer:HouseFurnitureCatalog.layer(for:target.kind),layout:layout,occupants:occupants,excluding:target.id) {
                updated[i].gridX=cell.x;updated[i].gridY=cell.y
            } else {
                updated[i].gridX=0;updated[i].gridY=0
                updated[i].isPlaced=false;stored+=1
            }
            updated[i].scale=1
        }
        try commit(updated)
        return stored
    }

    /// 先编码保存，再发布界面状态；失败时不会出现“画面已删除、重开又回来”的状态分叉。
    private func commit(_ updated: [RoomDecoration]) throws {
        guard loadIssue == nil else { throw HouseRuleError.damagedSave }
        let data = try JSONEncoder().encode(updated)
        storage.set(data, forKey: storageKey)
        decorations = updated
    }
}
