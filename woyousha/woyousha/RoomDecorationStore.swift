import Foundation
import Observation

/// 装饰物状态与存储共用一处。保存失败恢复旧状态，避免首页与装修页面显示不一致。
@MainActor @Observable
final class RoomDecorationStore {
    static let shared = RoomDecorationStore()
    private(set) var decorations: [RoomDecoration]
    private let storage: UserDefaults
    private let storageKey = "roomDecorationPlacements.v1"

    enum Action {
        case move(Double, Double), scale(Double), mirror, forward, backward, store, place
    }

    init(storage: UserDefaults = .standard) {
        self.storage = storage
        if let data = storage.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([RoomDecoration].self, from:data) {
            decorations = saved
        } else {
            decorations = DecorationCatalog.defaults
        }
    }

    func perform(_ action: Action, id: String, furnitureLayers: [Int] = []) throws {
        guard let index = decorations.firstIndex(where: { $0.id == id }) else { return }
        let previous = decorations
        switch action {
        case .move(let x, let y):
            decorations[index].posX = RoomConfig.snap(x)
            decorations[index].posY = RoomConfig.snap(y)
        case .scale(let value):
            guard value.isFinite else { return }
            decorations[index].scale = min(max(value,RoomConfig.furnitureRange.lowerBound),RoomConfig.furnitureRange.upperBound)
        case .mirror: decorations[index].isMirrored.toggle()
        case .store: decorations[index].isPlaced = false
        case .place: decorations[index].isPlaced = true
        case .forward:
            decorations[index].zIndex = (decorations.map(\.zIndex)+furnitureLayers).max().map { $0+1 } ?? 0
        case .backward:
            let layers = decorations.filter { !$0.kind.isFloorCovering }.map(\.zIndex)+furnitureLayers
            decorations[index].zIndex = max(-900,(layers.min() ?? 0)-1)
        }
        do { storage.set(try JSONEncoder().encode(decorations),forKey:storageKey) }
        catch { decorations = previous; throw error }
    }

    func add(kind: RoomDecoration.Kind) throws -> String {
        let previous = decorations
        let id = UUID().uuidString
        decorations.append(RoomDecoration(id:id,kind:kind,posX:400,posY:460))
        do { storage.set(try JSONEncoder().encode(decorations),forKey:storageKey) }
        catch { decorations = previous; throw error }
        return id
    }
}
