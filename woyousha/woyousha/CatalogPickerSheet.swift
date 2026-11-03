import SwiftUI

/// 目录浮层的分类标签：家具、装饰各自提供标题与图标，共用同一套 tab 外观。
nonisolated protocol CatalogTab: Hashable, Identifiable, CaseIterable where AllCases: RandomAccessCollection {
    var title: String { get }
    var symbol: String { get }
}

/// 分类与搜索在一处取交集；只用于浏览目录，不会写入房间、家具或物品数据。
nonisolated struct CatalogQuery<Tab: Hashable> {
    var tab: Tab?
    var searchText = ""

    var hasFilters: Bool {
        tab != nil || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 空格分隔的多个关键词需同时命中，例如“儿童 收纳”。
    func matchesSearch(_ searchableText: String) -> Bool {
        searchText.split(whereSeparator: \.isWhitespace)
            .allSatisfy { searchableText.localizedStandardContains(String($0)) }
    }

    func matches(tab entryTab: Tab, searchableText: String) -> Bool {
        if let tab, tab != entryTab { return false }
        return matchesSearch(searchableText)
    }
}

/// 目录浮层的尺寸常量，家具与装饰保持完全一致的手感。
enum CatalogPickerStyle {
    static let horizontalPadding: CGFloat = 20
    static let tabSpacing: CGFloat = 8
    static let tabMinHeight: CGFloat = 44
    static let gridMinimumWidth: CGFloat = 95
    static let gridSpacing: CGFloat = 16
    static let thumbnailHeight: CGFloat = 90
    static let cardCornerRadius: CGFloat = 18
    static let emptyMinHeight: CGFloat = 280
    static let topAnchor = "catalog-top"
    static let allTabAnchor = "catalog-tab-all"
}

/// 通用“目录挑选”浮层：顶部横向分类 tab + 搜索 + 网格卡片。
/// 好比商场的楼层导览：tab 是楼层，搜索是直接问店名，两者可以叠加使用。
struct CatalogPickerSheet<Entry: Identifiable, Tab: CatalogTab, Thumbnail: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let itemUnit: String
    let searchPrompt: String
    let entries: [Entry]
    let tabOf: (Entry) -> Tab
    let nameOf: (Entry) -> String
    let searchTextOf: (Entry) -> String
    let isSelected: (Entry) -> Bool
    let dismissOnSelection: Bool
    let thumbnail: (Entry) -> Thumbnail
    let onSelect: (Entry) -> Bool
    @State private var query: CatalogQuery<Tab>
    @State private var selectionFailed = false

    init(title: String, itemUnit: String, searchPrompt: String, entries: [Entry],
         initialQuery: CatalogQuery<Tab> = CatalogQuery(),
         tabOf: @escaping (Entry) -> Tab, nameOf: @escaping (Entry) -> String,
         searchTextOf: @escaping (Entry) -> String,
         isSelected: @escaping (Entry) -> Bool = { _ in false },
         dismissOnSelection: Bool = false,
         @ViewBuilder thumbnail: @escaping (Entry) -> Thumbnail,
         onSelect: @escaping (Entry) -> Bool) {
        self.title = title
        self.itemUnit = itemUnit
        self.searchPrompt = searchPrompt
        self.entries = entries
        self.tabOf = tabOf
        self.nameOf = nameOf
        self.searchTextOf = searchTextOf
        self.isSelected = isSelected
        self.dismissOnSelection = dismissOnSelection
        self.thumbnail = thumbnail
        self.onSelect = onSelect
        _query = State(initialValue: initialQuery)
    }

    /// 先按搜索词过滤，tab 上的数量也跟着搜索结果变化。
    private var searchMatches: [Entry] {
        entries.filter { query.matchesSearch(searchTextOf($0)) }
    }

    private var filteredEntries: [Entry] {
        guard let tab = query.tab else { return searchMatches }
        return searchMatches.filter { tabOf($0) == tab }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filters
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            if filteredEntries.isEmpty {
                                emptyResults.frame(minHeight: CatalogPickerStyle.emptyMinHeight)
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: CatalogPickerStyle.gridMinimumWidth))],
                                          spacing: CatalogPickerStyle.gridSpacing) {
                                    ForEach(filteredEntries) { entry in choice(entry) }
                                }
                            }
                        }
                        .padding(CatalogPickerStyle.horizontalPadding)
                        .id(CatalogPickerStyle.topAnchor)
                    }
                    // 换分类或改搜索词后回到列表顶部，避免停在空白处。
                    .onChange(of: query.tab) { _, _ in proxy.scrollTo(CatalogPickerStyle.topAnchor, anchor: .top) }
                    .onChange(of: query.searchText) { _, _ in proxy.scrollTo(CatalogPickerStyle.topAnchor, anchor: .top) }
                }
            }
            .background(AppTheme.background)
            .foregroundStyle(AppTheme.text)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query.searchText, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: searchPrompt)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
            .alert("没有保存成功", isPresented: $selectionFailed) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text("请再试一次。")
            }
        }
        .tint(AppTheme.accentText)
    }

    /// 分类 tab 固定在列表上方；“全部”在最前，其余按目录顺序排列。
    private var filters: some View {
        let matches = searchMatches
        return VStack(spacing: 6) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CatalogPickerStyle.tabSpacing) {
                        tabChip(nil, title: "全部", symbol: "square.grid.2x2.fill", count: matches.count)
                            .id(CatalogPickerStyle.allTabAnchor)
                        ForEach(Array(Tab.allCases)) { tab in
                            tabChip(tab, title: tab.title, symbol: tab.symbol,
                                    count: matches.filter { tabOf($0) == tab }.count)
                                .id(tab)
                        }
                    }
                    .padding(.horizontal, CatalogPickerStyle.horizontalPadding)
                }
                // 选中靠右的 tab 时自动滚到可见位置，小屏也不会被挡住。
                .onChange(of: query.tab) { _, tab in
                    withAnimation(.snappy) {
                        if let tab { proxy.scrollTo(tab, anchor: .center) }
                        else { proxy.scrollTo(CatalogPickerStyle.allTabAnchor, anchor: .center) }
                    }
                }
            }
            HStack {
                Text("\(filteredEntries.count) \(itemUnit)").font(.caption).foregroundStyle(AppTheme.secondaryText)
                Spacer()
                if query.hasFilters {
                    Button("清除筛选") { query = CatalogQuery() }
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: CatalogPickerStyle.tabMinHeight)
                }
            }
            .padding(.horizontal, CatalogPickerStyle.horizontalPadding)
            .frame(minHeight: CatalogPickerStyle.tabMinHeight)
        }
        .padding(.top, 10)
        .background(AppTheme.background)
        .overlay(alignment: .bottom) { Rectangle().fill(AppTheme.line).frame(height: 1) }
    }

    private func tabChip(_ tab: Tab?, title: String, symbol: String, count: Int) -> some View {
        let selected = query.tab == tab
        return Button {
            query.tab = tab
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 13, weight: .bold))
                Text(title).font(.system(.subheadline, design: .rounded, weight: .heavy))
                Text("\(count)").font(.caption2.weight(.bold)).monospacedDigit()
                    .opacity(selected ? 0.9 : 0.6)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: CatalogPickerStyle.tabMinHeight)
            .foregroundStyle(selected ? AppTheme.onAccent : AppTheme.text)
            .background(selected ? AppTheme.accent : AppTheme.inset, in: Capsule())
            .overlay { Capsule().strokeBorder(selected ? AppTheme.accentEdge : .clear, lineWidth: 2) }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)，\(count) 项")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func choice(_ entry: Entry) -> some View {
        let selected = isSelected(entry)
        return Button {
            if onSelect(entry) {
                if dismissOnSelection { dismiss() }
            } else {
                selectionFailed = true
            }
        } label: {
            VStack(spacing: 10) {
                thumbnail(entry).frame(height: CatalogPickerStyle.thumbnailHeight)
                Text(nameOf(entry))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(minHeight: 32, alignment: .top)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(selected ? AppTheme.inset : AppTheme.surface,
                        in: RoundedRectangle(cornerRadius: CatalogPickerStyle.cardCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: CatalogPickerStyle.cardCornerRadius)
                    .strokeBorder(selected ? AppTheme.accent : AppTheme.line, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var emptyResults: some View {
        ContentUnavailableView {
            Label("没有找到符合条件的结果", systemImage: "magnifyingglass")
        } description: {
            Text("试试其他名称，或清除筛选查看全部。")
        } actions: {
            Button("查看全部") { query = CatalogQuery() }
        }
    }
}
