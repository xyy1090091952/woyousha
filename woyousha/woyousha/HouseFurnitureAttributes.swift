import Foundation
import CoreGraphics

/// 用途与“卧室、厨卫”等查找分类分开，所有收纳入口共用这份规则。
nonisolated enum FurnitureRole: String, CaseIterable, Identifiable {
    case container = "容器家具", decorative = "装饰家具"
    var id: String { rawValue }
}

nonisolated struct FurnitureSurface {
    let bounds: CGRect
    let height: Double
    var reserved: [CGRect] = []
    /// 圆桌采用内接矩形，四角也不会悬在圆桌之外。
    func scaled(_ factor: Double) -> Self {
        func scale(_ r: CGRect) -> CGRect {
            .init(x:r.minX*factor,y:r.minY*factor,width:r.width*factor,height:r.height*factor)
        }
        return .init(bounds:scale(bounds),height:height*factor,reserved:reserved.map(scale))
    }
}

nonisolated enum HouseFurnitureAttributes {
    private static let containers: Set<String> = [
        "bingxiang","bingxiang2","yigui","bijia","shujia","dianshigui","dianshigui2","chuwei",
        "beibao","zhixiang","cart","mirror","nightstand","study-desk","shoe-cabinet","dressing-table",
        "suitcase","tatami-bed","blanket-chest","fabric-wardrobe","sliding-wardrobe","clothes-rack",
        "bedside-shelf","console-table","bar-cart","filing-cabinet","wall-bookcase","ladder-bookcase",
        "kitchen-island","kitchen-shelf","chest-freezer","vanity-sink","towel-rack","laundry-hamper",
        "drying-rack","drawer-chest","cube-shelf","sideboard","glass-cabinet","corner-cabinet",
        "floating-cabinet","entry-bench","coat-tree","umbrella-stand","storage-trunk","tool-cabinet",
        "wicker-basket","toy-chest","fish-tank-stand","greenhouse-shelf"
    ]
    static func role(_ id: String) -> FurnitureRole { containers.contains(id) ? .container:.decorative }

    /// 调整模型本身，图片、阴影、占地和 GPU 都会使用相同的真实比例。
    private static let scales: [String:Double] = [
        "beibao":0.55,"suitcase":0.6,"zhixiang":0.6,"lajitong":0.6,"beikedeng":0.5,
        "nightstand":0.75,"dining-chair":0.7,"low-stool":0.7,"office-chair":0.75,
        "printer":0.45,"sewing-machine":0.5,"microwave":0.45,"rice-cooker":0.4,
        "electric-kettle":0.3,"coffee-machine":0.45,"toaster":0.35,"desk-fan":0.5,
        "humidifier":0.45,"robot-vacuum":0.3,"projector":0.4,"kids-chair":0.75,
        "dollhouse":0.55,"wicker-basket":0.65,"umbrella-stand":0.65,"xichengqi":0.7
    ]
    static func scale(_ id: String) -> Double { scales[id] ?? 1 }
    static func scale(_ kind: RoomDecoration.Kind) -> Double {
        switch kind {
        case .flowers: return 0.5
        case .tableLamp: return 0.6
        case .cactus: return 0.55
        case .cushions: return 0.6
        case .teddyBear: return 0.5
        case .aquarium: return 0.65
        case .speaker: return 0.5
        case .petBed: return 0.75
        default: return 1
        }
    }
    static func canSitOnSurface(_ source: HouseSceneItem.Source) -> Bool {
        switch source {
        case .furniture(let id):
            return ["beikedeng","zhixiang","wicker-basket","printer","sewing-machine","microwave",
                    "rice-cooker","electric-kettle","coffee-machine","toaster","desk-fan","humidifier",
                    "projector","dollhouse"].contains(id)
        case .decoration(let kind):
            return [.flowers,.tableLamp,.cactus,.teddyBear,.aquarium,.speaker].contains(kind)
        }
    }
    static func surface(_ source: HouseSceneItem.Source) -> FurnitureSurface? {
        guard case .furniture(let id) = source else { return nil }
        let surface: FurnitureSurface
        switch id {
        case "fanzhuo":
            surface = .init(bounds:.init(x:1,y:1,width:35,height:22),height:22,
                reserved:[.init(x:5,y:6,width:11,height:8),.init(x:21,y:4,width:8,height:8)])
        case "coffee-table":
            surface = .init(bounds:.init(x:1,y:1,width:34,height:21),height:15,
                reserved:[.init(x:6,y:5,width:11,height:8),.init(x:21,y:6,width:9,height:7)])
        case "study-desk":
            surface = .init(bounds:.init(x:0,y:0,width:42,height:23),height:26,
                reserved:[.init(x:5,y:3,width:21,height:16),.init(x:31,y:3,width:9,height:9)])
        case "nightstand":
            surface = .init(bounds:.init(x:1,y:1,width:18,height:15),height:23,
                reserved:[.init(x:5,y:5,width:9,height:4)])
        case "round-coffee-table":
            surface = .init(bounds:.init(x:6,y:6,width:28,height:28),height:17.5,
                reserved:[.init(x:20,y:14,width:9,height:9)])
        case "round-dining-table":
            surface = .init(bounds:.init(x:6,y:6,width:30,height:30),height:31,
                reserved:[.init(x:4,y:15,width:12,height:12),.init(x:25,y:15,width:12,height:12),
                          .init(x:18,y:8,width:9,height:9)])
        case "kitchen-island":
            surface = .init(bounds:.init(x:-1,y:0,width:45,height:33),height:32.6,
                reserved:[.init(x:6,y:3,width:18,height:15),.init(x:29,y:14,width:10,height:12)])
        default: return nil
        }
        return surface.scaled(scale(id))
    }
    static func resized(_ mesh: IsoMesh, by factor: Double) -> IsoMesh {
        guard factor != 1 else { return mesh }
        return IsoMesh(faces:mesh.faces.map { original in
            var face=original
            face.points=face.points.map { .init($0.x*factor,$0.y*factor,$0.z*factor) }
            return face
        })
    }
}

extension FurnitureConfig {
    nonisolated var role: FurnitureRole { HouseFurnitureAttributes.role(id) }
}

extension Container {
    var resolvedStyleID: String { FurnitureConfig.styleID(name:name,icon:icon,savedID:furnitureImageName) }
    var furnitureRole: FurnitureRole { HouseFurnitureAttributes.role(resolvedStyleID) }
    var canReceiveItems: Bool { furnitureRole == .container }
    /// 旧装饰家具的已有物品保留，清空后自然从收纳列表隐藏。
    var appearsInInventory: Bool { canReceiveItems || !(items?.isEmpty ?? true) }
}
