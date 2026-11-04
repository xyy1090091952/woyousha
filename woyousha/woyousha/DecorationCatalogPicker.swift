import SwiftUI

/// 装饰物与家具共用同一套目录浮层：顶部分类 tab + 搜索 + 网格，轻点即放入房间。
struct DecorationCatalogPicker: View {
    var roomStyle = "home1"
    var dismissOnSelection = true
    var initialQuery = CatalogQuery<DecorationTab>()
    var failureMessage: () -> String = { "请再试一次。" }
    let onSelect: (RoomDecoration.Kind) -> Bool

    var body: some View {
        CatalogPickerSheet(
            title: "添加装饰", itemUnit: "种装饰", searchPrompt: "搜索名称或用途，如台灯、相框",
            entries: RoomDecoration.Kind.allCases, initialQuery: initialQuery,
            tabOf: \.tab, nameOf: \.title, searchTextOf: \.catalogSearchText,
            dismissOnSelection: dismissOnSelection,
            failureMessage: failureMessage,
            thumbnail: { PixelDecorationView(kind: $0, roomStyle: roomStyle) },
            onSelect: onSelect
        )
    }
}

#Preview {
    DecorationCatalogPicker { _ in true }
}

#Preview("墙面装饰") {
    DecorationCatalogPicker(initialQuery: CatalogQuery(tab: .wall)) { _ in true }
}
