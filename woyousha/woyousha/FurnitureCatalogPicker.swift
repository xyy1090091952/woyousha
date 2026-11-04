import SwiftUI

/// 编辑容器、装修换造型、添加家具共用此抽屉，筛选不修改当前选中家具。
struct FurnitureCatalogPicker: View {
    var selectedStyleID: String? = nil
    var title = "选择家具造型"
    var dismissOnSelection = false
    var initialQuery = FurnitureCatalogQuery()
    var failureMessage: () -> String
    let onSelect: (String) -> Bool

    /// 初始条件也供原生预览使用，不会写入用户偏好或改变房间数据。
    init(selectedStyleID: String? = nil, title: String = "选择家具造型",
         dismissOnSelection: Bool = false, initialQuery: FurnitureCatalogQuery = FurnitureCatalogQuery(),
         failureMessage: @escaping () -> String = { "请再试一次。" },
         onSelect: @escaping (String) -> Bool) {
        self.selectedStyleID = selectedStyleID
        self.title = title
        self.dismissOnSelection = dismissOnSelection
        self.initialQuery = initialQuery
        self.failureMessage = failureMessage
        self.onSelect = onSelect
    }

    var body: some View {
        CatalogPickerSheet(
            title: title, itemUnit: "款家具", searchPrompt: "搜索名称或用途，如露营、晾衣",
            entries: FurnitureConfig.all, initialQuery: initialQuery,
            tabOf: \.tab, nameOf: \.name, searchTextOf: \.catalogSearchText,
            isSelected: { $0.imageName == selectedStyleID },
            dismissOnSelection: dismissOnSelection,
            failureMessage: failureMessage,
            thumbnail: { PixelFurnitureView(styleID: $0.imageName) },
            onSelect: { onSelect($0.imageName) }
        )
    }
}

#Preview {
    FurnitureCatalogPicker { _ in true }
}

#Preview("卧室") {
    FurnitureCatalogPicker(initialQuery: FurnitureCatalogQuery(tab: .bedroom)) { _ in true }
}

#Preview("无结果") {
    FurnitureCatalogPicker(initialQuery: FurnitureCatalogQuery(tab: .study, searchText: "浴缸")) { _ in true }
}
