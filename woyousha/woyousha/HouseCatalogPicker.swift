import SwiftUI

/// 共用目录保留两种原有存储来源，不迁移或删除旧装饰。
nonisolated struct HouseCatalogEntry: Identifiable {
    let source: HouseSceneItem.Source
    let name: String
    let tab: FurnitureTab
    let searchText: String
    var id: String { String(describing:source) }
    static func entries(role: FurnitureRole) -> [Self] {
        let furniture=FurnitureConfig.all.filter {$0.role == role}.map {
            Self(source:.furniture($0.id),name:$0.name,tab:$0.tab,searchText:$0.catalogSearchText)
        }
        guard role == .decorative else { return furniture }
        return furniture + RoomDecoration.Kind.allCases.map {
            Self(source:.decoration($0),name:$0.title,tab:.livingRoom,searchText:$0.catalogSearchText)
        }
    }
}

struct HouseCatalogPicker: View {
    let role: FurnitureRole
    var roomStyle = "home1"
    var failureMessage: () -> String = { "没有保存成功，请重试。" }
    let onSelect: (HouseSceneItem.Source) -> Bool
    var body: some View {
        CatalogPickerSheet(title:"添加"+role.rawValue,itemUnit:"款",searchPrompt:"搜索名称，如花瓶、台灯、桌子",
            entries:HouseCatalogEntry.entries(role:role),initialQuery:FurnitureCatalogQuery(),
            tabOf:\.tab,nameOf:\.name,searchTextOf:\.searchText,dismissOnSelection:true,failureMessage:failureMessage,
            thumbnail:{ entry in
                Group {
                    switch entry.source {
                    case .furniture(let id): PixelFurnitureView(styleID:id)
                    case .decoration(let kind): PixelDecorationView(kind:kind,roomStyle:roomStyle)
                    }
                }
            },onSelect:{onSelect($0.source)})
    }
}
