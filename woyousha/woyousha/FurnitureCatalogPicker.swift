import SwiftUI

/// 编辑容器、装修换造型、添加家具共用此抽屉，筛选不修改当前选中家具。
struct FurnitureCatalogPicker: View {
    @Environment(\.dismiss) private var dismiss
    var selectedStyleID: String? = nil
    var title = "选择家具造型"
    var dismissOnSelection = false
    let onSelect: (String) -> Bool
    @State private var query = FurnitureCatalogQuery()
    @State private var selectionFailed = false

    /// 初始条件也供原生预览使用，不会写入用户偏好或改变房间数据。
    init(selectedStyleID: String? = nil, title: String = "选择家具造型",
         dismissOnSelection: Bool = false, initialQuery: FurnitureCatalogQuery = FurnitureCatalogQuery(),
         onSelect: @escaping (String) -> Bool) {
        self.selectedStyleID = selectedStyleID
        self.title = title
        self.dismissOnSelection = dismissOnSelection
        self.onSelect = onSelect
        _query = State(initialValue: initialQuery)
    }

    private var filteredCatalog: [FurnitureConfig] {
        FurnitureConfig.all.filter(query.matches)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filters
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            if filteredCatalog.isEmpty {
                                emptyResults.frame(minHeight: 280)
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 95))], spacing: 16) {
                                    ForEach(filteredCatalog) { config in furnitureChoice(config) }
                                }
                            }
                        }
                        .padding(20)
                        .id("catalog-top")
                    }
                    .onChange(of: query.category) { _, _ in proxy.scrollTo("catalog-top", anchor: .top) }
                    .onChange(of: query.onlyNew) { _, _ in proxy.scrollTo("catalog-top", anchor: .top) }
                    .onChange(of: query.searchText) { _, _ in proxy.scrollTo("catalog-top", anchor: .top) }
                }
            }
            .background(AppTheme.background)
            .foregroundStyle(AppTheme.text)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query.searchText, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "搜索名称或用途，如露营、晾衣")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .alert("没有保存成功", isPresented: $selectionFailed) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text("请再试一次。")
            }
        }
        .tint(AppTheme.accent)
    }

    /// 筛选固定在列表上方，小浮层里也能随时换分类与清除条件。
    private var filters: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Menu {
                    Picker("家具分类", selection: $query.category) {
                        Text("全部（\(FurnitureConfig.all.count)）").tag(Optional<FurnitureCategory>.none)
                        ForEach(FurnitureCategory.allCases) { category in
                            let count = FurnitureConfig.all.filter { $0.category == category }.count
                            Text("\(category.title)（\(count)）").tag(Optional(category))
                        }
                    }
                } label: {
                    Label(query.category?.title ?? "全部分类", systemImage: "line.3.horizontal.decrease")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(AppTheme.text)
                        .background(AppTheme.inset, in: RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityLabel("家具分类")
                .accessibilityValue(query.category?.title ?? "全部")

                Toggle(isOn: $query.onlyNew) {
                    Text("只看新增").font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .accessibilityLabel("只显示这次新增的一百种家具")
            }
            HStack {
                Text("\(filteredCatalog.count) 款家具").font(.caption).foregroundStyle(AppTheme.secondaryText)
                Spacer()
                if query.hasFilters {
                    Button("清除筛选") { query = FurnitureCatalogQuery() }
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: 44)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(AppTheme.background)
        .overlay(alignment: .bottom) { Rectangle().fill(AppTheme.line).frame(height: 1) }
    }

    private func furnitureChoice(_ config: FurnitureConfig) -> some View {
        Button {
            if onSelect(config.imageName) {
                if dismissOnSelection { dismiss() }
            } else {
                selectionFailed = true
            }
        } label: {
            VStack(spacing: 10) {
                PixelFurnitureView(styleID: config.imageName).frame(height: 90)
                Text(config.name)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .lineLimit(2)
                    .frame(minHeight: 32, alignment: .top)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(selectedStyleID == config.imageName ? AppTheme.inset : AppTheme.surface,
                        in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(selectedStyleID == config.imageName ? AppTheme.accent : AppTheme.line, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedStyleID == config.imageName ? .isSelected : [])
    }

    private var emptyResults: some View {
        ContentUnavailableView {
            Label("没有符合条件的家具", systemImage: "magnifyingglass")
        } description: {
            Text("试试其他名称，或清除筛选查看全部。")
        } actions: {
            Button("查看全部家具") { query = FurnitureCatalogQuery() }
        }
        .allowsHitTesting(true)
    }
}

#Preview {
    FurnitureCatalogPicker { _ in true }
}

#Preview("卧室 · 新增") {
    FurnitureCatalogPicker(initialQuery: FurnitureCatalogQuery(category: .bedroom, onlyNew: true)) { _ in true }
}

#Preview("无结果") {
    FurnitureCatalogPicker(initialQuery: FurnitureCatalogQuery(category: .lighting, onlyNew: true)) { _ in true }
}
