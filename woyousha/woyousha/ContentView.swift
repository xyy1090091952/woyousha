//
//  ContentView.swift
//  woyousha
//
//  Created by ByteDance on 2/27/26.
//

import SwiftUI
import SwiftData

// 容器过滤状态枚举
enum ContainerFilter: Equatable {
    case all // 全部
    case unclassified // 未分类
    case specific(Container) // 具体容器
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    // 查询所有容器
    @Query(sort: \Container.createdDate) private var containers: [Container]
    
    // 查询所有物品
    @Query(sort: \Item.createdDate, order: .reverse) private var allItems: [Item]
    
    // 当前选中的过滤器状态 (默认为全部)
    @State private var selectedFilter: ContainerFilter = .all
    
    // 是否处于编辑模式
    @State private var isEditing = false
    
    // 选中的物品（用于批量操作）
    @State private var selectedItems: Set<Item> = []
    
    // 控制添加页面的显示
    @State private var showAddSheet = false
    
    // 控制添加容器页面的显示
    @State private var showAddContainerSheet = false
    
    // 控制编辑容器页面的显示
    @State private var showEditContainerSheet = false
    
    // 正在拖拽的物品 ID 集合
    @State private var draggingItems: Set<String> = []
    // 当前拖拽的位置（相对于整个屏幕）
    @State private var dragLocation: CGPoint = .zero
    // 垃圾桶区域是否处于高亮状态（准备删除）
    @State private var isTrashBinActive = false
    
    // 垃圾桶的高度阈值（屏幕底部多少像素算作垃圾桶区域）
    private let trashBinHeight: CGFloat = 120
    
    // 网格布局
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                DotGridBackground(spacing: 20, dotColor: .gray.opacity(0.3))
                
                VStack(spacing: 0) {
                    // 1. 顶部区域：家/房间视图 + 编辑按钮
                    homeHeaderView
                    
                    // 2. 容器选择列表
                    containerListView
                    
                    // 3. 物品网格
                    itemsGridView
                }
            }
            .navigationBarHidden(true) // 隐藏默认导航栏，使用自定义头部
            .onAppear {
                initializeDefaultContainers()
            }
            .sheet(isPresented: $showAddSheet) {
                // 如果当前选中的是具体容器，则默认选中该容器
                if case .specific(let container) = selectedFilter {
                    AddItemView(defaultContainer: container)
                } else {
                    AddItemView()
                }
            }
            .sheet(isPresented: $showAddContainerSheet) {
                ContainerEditView()
            }
            .sheet(isPresented: $showEditContainerSheet) {
                if case .specific(let container) = selectedFilter {
                    ContainerEditView(containerToEdit: container) {
                        // 容器删除后的回调：重置选中状态
                        selectedFilter = .all
                    }
                }
            }
            // 底部垃圾桶区域（仅在拖拽时显示，或者在编辑模式下显示）
            .overlay(alignment: .bottom) {
                // 当处于编辑模式，或者正在拖拽物品时显示垃圾桶
                if isEditing || !draggingItems.isEmpty {
                    trashBinView
                }
            }
        }
    }
    
    // MARK: - Views
    
    private var homeHeaderView: some View {
        ZStack(alignment: .top) {
            // 家的模拟图 (占位)
            // 使用 Color 作为背景，并让它忽略安全区域
            // 内容（图标和文字）单独放置，保持在安全区域内
            
            // 1. 内容层
            Rectangle()
                .fill(Color.clear) // 透明，只用于占位和布局
                .frame(height: 200)
                .overlay {
                    Image(systemName: "house.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray.opacity(0.3))
                    Text("我的家")
                        .font(.headline)
                        .foregroundStyle(.gray)
                        .offset(y: 40)
                }
            
            // 顶部按钮栏
            HStack {
                // 添加按钮 (左侧)
                if !isEditing {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Capsule())
                            .shadow(radius: 2)
                    }
                    .transition(.opacity)
                }
                
                Spacer()
                
                // 编辑按钮 (右侧)
                Button(action: {
                    withAnimation {
                        isEditing.toggle()
                        selectedItems.removeAll()
                    }
                }) {
                    Text(isEditing ? "完成" : "编辑")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.8))
                        .clipShape(Capsule())
                        .shadow(radius: 2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16) // 恢复正常的顶部间距
        }
        // 2. 背景层：单独设置背景色并延伸到安全区域
        .background(
            Color.gray.opacity(0.1)
                .ignoresSafeArea(edges: .top)
        )
    }
    
    private var containerListView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // "全部" 容器
                VStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .foregroundStyle(selectedFilter == .all ? .white : .gray)
                        .background(selectedFilter == .all ? Color.blue : Color.gray.opacity(0.1))
                        .clipShape(Circle())
                    
                    Text("全部")
                        .font(.caption)
                        .fontWeight(selectedFilter == .all ? .bold : .regular)
                        .foregroundStyle(selectedFilter == .all ? .black : .gray)
                }
                .onTapGesture {
                    withAnimation {
                        selectedFilter = .all
                    }
                }
                
                // "未分类" 容器
                VStack(spacing: 4) {
                    Image(systemName: "questionmark.square.dashed")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .foregroundStyle(selectedFilter == .unclassified ? .white : .gray)
                        .background(selectedFilter == .unclassified ? Color.blue : Color.gray.opacity(0.1))
                        .clipShape(Circle())
                    
                    Text("未分类")
                        .font(.caption)
                        .fontWeight(selectedFilter == .unclassified ? .bold : .regular)
                        .foregroundStyle(selectedFilter == .unclassified ? .black : .gray)
                }
                .onTapGesture {
                    withAnimation {
                        selectedFilter = .unclassified
                    }
                }
                .dropDestination(for: String.self) { items, location in
                    var idsToProcess = Set(items)
                    if !selectedItems.isEmpty {
                        let selectedIds = Set(selectedItems.map { $0.id.uuidString })
                        if !idsToProcess.isDisjoint(with: selectedIds) {
                            idsToProcess.formUnion(selectedIds)
                        }
                    }
                    
                    for id in idsToProcess {
                        if let item = allItems.first(where: { $0.id.uuidString == id }) {
                            withAnimation {
                                item.container = nil // 移出容器
                                item.updatedDate = Date()
                            }
                        }
                    }
                    selectedItems.removeAll()
                    return true
                } isTargeted: { _ in }
                
                // 现有容器列表
                ForEach(containers) { container in
                    ContainerTabItem(
                        container: container,
                        isSelected: selectedFilter == .specific(container)
                    ) { items in
                        // 处理 Drop 逻辑
                        var idsToProcess = Set(items)
                        
                        // 如果拖拽的物品在选中列表中，则同时处理所有选中的物品
                        if !selectedItems.isEmpty {
                            let selectedIds = Set(selectedItems.map { $0.id.uuidString })
                            if !idsToProcess.isDisjoint(with: selectedIds) {
                                idsToProcess.formUnion(selectedIds)
                            }
                        }
                        
                        for id in idsToProcess {
                            if let item = allItems.first(where: { $0.id.uuidString == id }) {
                                // 移动物品到该容器
                                withAnimation {
                                    item.container = container
                                    item.updatedDate = Date()
                                }
                            }
                        }
                        
                        // 操作完成后清空选中状态
                        selectedItems.removeAll()
                        return true
                    }
                    .onTapGesture {
                        withAnimation {
                            selectedFilter = .specific(container)
                        }
                    }
                    // 长按编辑容器
                    .onLongPressGesture {
                        selectedFilter = .specific(container)
                        showEditContainerSheet = true
                    }
                }
                
                // 添加容器按钮
                Button(action: { showAddContainerSheet = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .foregroundStyle(.gray)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                        
                        Text("添加")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.white.opacity(0.5))
        // 防止 tooltip 被 ScrollView 裁剪
        .scrollClipDisabled()
    }
    
    private var itemsGridView: some View {
        ScrollView {
            let filteredItems = currentItems.sorted { $0.createdDate > $1.createdDate }
            
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(filteredItems) { item in
                        // 如果在编辑模式，拦截点击事件用于选择
                        // 如果在浏览模式，使用 NavigationLink 进行跳转
                        if isEditing {
                            ItemGridCell(
                                item: item,
                                isEditing: isEditing,
                                isSelected: selectedItems.contains(item)
                            )
                            .opacity(draggingItems.contains(item.id.uuidString) ? 0.3 : 1.0) // 幽灵占位效果
                            .onTapGesture {
                                toggleSelection(item)
                            }
                            // 支持拖拽 (自定义，移除系统背景和阴影)
                            .customDraggable(
                                itemProvider: { NSItemProvider(object: item.id.uuidString as NSString) },
                                onDragStart: {
                                    // 立即设置拖拽状态，这会触发 scrollDisabled
                                    DispatchQueue.main.async {
                                        if selectedItems.contains(item) {
                                            draggingItems = Set(selectedItems.map { $0.id.uuidString })
                                        } else {
                                            draggingItems = [item.id.uuidString]
                                        }
                                    }
                                },
                                onDragEnd: {
                                    draggingItems.removeAll()
                                    isTrashBinActive = false // 确保松手后重置状态
                                },
                                onDragMove: { location in
                                    // 检查是否进入垃圾桶区域
                                    // 这里使用简单的 Y 坐标判断，假设垃圾桶在底部 120pt 区域
                                    // 注意：location 是相对于 window 的坐标
                                    if let window = UIApplication.shared.connectedScenes
                                        .compactMap({ $0 as? UIWindowScene })
                                        .flatMap({ $0.windows })
                                        .first(where: { $0.isKeyWindow }) {
                                        let screenHeight = window.bounds.height
                                        let isInTrashArea = location.y > (screenHeight - trashBinHeight)
                                        
                                        // 只有状态改变时才更新，减少 SwiftUI 刷新
                                        if isTrashBinActive != isInTrashArea {
                                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                                isTrashBinActive = isInTrashArea
                                            }
                                        }
                                    }
                                }
                            ) {
                                // 拖拽预览
                                if selectedItems.contains(item) && selectedItems.count > 1 {
                                    // 如果拖动的是已选中的物品，且选中了多个，显示堆叠预览
                                    DragPreviewView(items: Array(selectedItems))
                                } else {
                                    // 否则显示单个预览
                                    DragPreviewView(items: [item])
                                }
                            }
                        } else {
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                ItemGridCell(
                                    item: item,
                                    isEditing: isEditing,
                                    isSelected: selectedItems.contains(item)
                                )
                            }
                            .opacity(draggingItems.contains(item.id.uuidString) ? 0.3 : 1.0) // 幽灵占位效果
                            // 支持拖拽 (自定义，移除系统背景和阴影)
                            .customDraggable(
                                itemProvider: { NSItemProvider(object: item.id.uuidString as NSString) },
                                onDragStart: {
                                    // 立即设置拖拽状态，这会触发 scrollDisabled
                                    DispatchQueue.main.async {
                                        if selectedItems.contains(item) {
                                            draggingItems = Set(selectedItems.map { $0.id.uuidString })
                                        } else {
                                            draggingItems = [item.id.uuidString]
                                        }
                                    }
                                },
                                onDragEnd: {
                                    draggingItems.removeAll()
                                    isTrashBinActive = false
                                },
                                onDragMove: { location in
                                    // 检查是否进入垃圾桶区域
                                    if let window = UIApplication.shared.connectedScenes
                                        .compactMap({ $0 as? UIWindowScene })
                                        .flatMap({ $0.windows })
                                        .first(where: { $0.isKeyWindow }) {
                                        let screenHeight = window.bounds.height
                                        let isInTrashArea = location.y > (screenHeight - trashBinHeight)
                                        
                                        if isTrashBinActive != isInTrashArea {
                                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                                isTrashBinActive = isInTrashArea
                                            }
                                        }
                                    }
                                }
                            ) {
                                DragPreviewView(items: [item])
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, isEditing ? 80 : 0) // 给垃圾桶留位置
            }
        }
        // 拖拽时禁用滚动，防止列表滑动到最底部
        .scrollDisabled(!draggingItems.isEmpty)
        // 关键：通过监听拖拽手势来主动阻止 ScrollView 的滚动事件
        // 这是一个更底层的 Hack，防止在 draggingItems 状态更新前 ScrollView 就已经开始滚动
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    // 这里不需要做任何事，主要是为了捕获触摸事件，
                    // 让 ScrollView 认为有手势在处理，从而可能阻止它的滚动。
                    // 配合 scrollDisabled 使用效果更好。
                }
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.box")
                .font(.system(size: 50))
                .foregroundStyle(.gray.opacity(0.3))
            
            Group {
                switch selectedFilter {
                case .all:
                    Text("还没有任何物品")
                case .unclassified:
                    Text("所有物品都已分类")
                case .specific(let container):
                    Text("\(container.name) 是空的")
                }
            }
            .foregroundStyle(.gray)
        }
        .padding(.top, 50)
        .frame(maxWidth: .infinity)
    }
    
    private var trashBinView: some View {
        GeometryReader { geo in
            VStack {
                Spacer()
                ZStack {
                    // 背景
                    Rectangle()
                        .fill(isTrashBinActive ? .ultraThinMaterial : .regularMaterial)
                        .opacity(isTrashBinActive ? 1.0 : 0.8) // 默认半透明
                        .ignoresSafeArea()
                        .frame(height: isTrashBinActive ? 180 : 80) // 恢复默认高度
                        .background(
                            isTrashBinActive ? Color.red.opacity(0.1) : Color.clear
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isTrashBinActive)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: isTrashBinActive ? 40 : 24))
                            .foregroundStyle(isTrashBinActive ? .red : .gray)
                            .scaleEffect(isTrashBinActive ? 1.2 : 1.0)
                        
                        if isTrashBinActive {
                            Text("松手删除")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .fontWeight(.bold)
                                .transition(.opacity.combined(with: .scale))
                        } else {
                            Text("拖拽到这里删除")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                                .transition(.opacity)
                        }
                    }
                    .offset(y: isTrashBinActive ? -10 : 0) // 恢复默认位置
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTrashBinActive)
                }
                .frame(maxWidth: .infinity)
                // 确保 dropDestination 覆盖整个区域
                .dropDestination(for: String.self) { items, location in
                    // 删除逻辑
                    handleDelete(items: items)
                    return true
                } isTargeted: { targeted in
                    // 系统自带的 targeted 状态，也可以用来辅助
                    withAnimation {
                        isTrashBinActive = targeted
                    }
                }
            }
        }
        // 确保不阻挡底部的点击（如果没有背景色的话），但在拖拽时需要阻挡
        .allowsHitTesting(isEditing || !draggingItems.isEmpty)
    }
    
    // 抽离删除逻辑
    private func handleDelete(items: [String]) {
        var idsToProcess = Set(items)
        
        // 如果拖拽的物品在选中列表中，则同时处理所有选中的物品
        if !selectedItems.isEmpty {
            let selectedIds = Set(selectedItems.map { $0.id.uuidString })
            if !idsToProcess.isDisjoint(with: selectedIds) {
                idsToProcess.formUnion(selectedIds)
            }
        }
        
        // 执行删除
        withAnimation {
            for id in idsToProcess {
                if let item = allItems.first(where: { $0.id.uuidString == id }) {
                    modelContext.delete(item)
                }
            }
            selectedItems.removeAll()
            draggingItems.removeAll()
            isTrashBinActive = false
        }
    }
    
    // MARK: - Logic
    
    private var currentItems: [Item] {
        switch selectedFilter {
        case .all:
            return allItems
        case .unclassified:
            return allItems.filter { $0.container == nil }
        case .specific(let container):
            return container.items ?? []
        }
    }
    
    private func initializeDefaultContainers() {
        if containers.isEmpty {
            let defaults = [
                ("小推车", "cart"),
                ("厨房柜", "cabinet"),
                ("冰箱", "refrigerator"),
                ("镜柜", "mirror.side.left"), // 近似图标
                ("背包", "backpack"),
                ("墙壁", "wall.art.top") // 近似图标
            ]
            
            for (name, icon) in defaults {
                let container = Container(name: name, icon: icon)
                modelContext.insert(container)
            }
            
            // 自动选中第一个
            try? modelContext.save()
            
            // 默认选中第一个容器
            if let first = containers.first {
                selectedFilter = .specific(first)
            }
        }
        
        // 如果没有选中任何容器，且有容器存在，默认选中第一个
        // 只有在 selectedFilter 为 .all 的情况下（初始值），才考虑是否需要自动选中第一个
        // 但既然用户要求增加“全部”分类，那么默认选中“全部”或者“第一个”都可以
        // 这里我们修改逻辑：如果是首次启动（containers不为空但filter是all），我们保持all或者设为first？
        // 实际上，PRD 里说默认有一个家，所以“全部”作为默认视图也是合理的。
    }
    
    private func toggleSelection(_ item: Item) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
    }
    
    private func deleteItem(_ item: Item) {
        withAnimation {
            modelContext.delete(item)
        }
    }
}

// MARK: - Subviews

struct ContainerTabItem: View {
    let container: Container
    let isSelected: Bool
    
    // 增加拖拽目标状态检测 (注意：这个状态需要从外部传入或者通过 .dropDestination 的回调来更新)
    // 但是 .dropDestination 的 isTargeted 回调是在父视图的闭包里
    // 我们可以通过 Environment 或者 Binding 传递，或者直接把 .dropDestination 写在 ContainerTabItem 内部？
    // 之前是写在 ContentView 的 ForEach 里的。
    // 为了简单起见，我们可以在 ContentView 中使用 .onDrop 或者 .dropDestination 的 isTargeted 闭包来控制一个 State，
    // 但由于有多个容器，我们需要知道哪个容器被 Target。
    
    // 更好的方法：将 ContainerTabItem 改造为包含 Drop 逻辑的 View，
    // 这样它就可以拥有自己的 isTargeted 状态。
    
    // 由于我们已经在 ContentView 中定义了 Drop 逻辑，我们需要把那部分逻辑传进来，或者在这里重新定义。
    // 鉴于删除和移动逻辑都在 ContentView，传一个闭包进来比较好。
    
    var onDrop: ([String]) -> Bool
    
    @State private var isTargeted = false
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: container.icon)
                .font(.title2)
                .frame(width: 44, height: 44)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
                .clipShape(Circle())
                // 拖拽高亮效果
                .scaleEffect(isTargeted ? 1.2 : 1.0)
                .animation(.spring, value: isTargeted)
            
            Text(container.name)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(isSelected ? .black : .gray)
        }
        .overlay(alignment: .top) {
            if isTargeted {
                Text("移动到 \(container.name)")
                    .font(.system(size: 12, weight: .bold)) // 使用固定字号，更清晰
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.8))
                            .shadow(radius: 2)
                    )
                    .lineLimit(1) // 强制单行
                    .fixedSize() // 强制适应内容大小
                    .offset(y: -50) // 向上偏移更多，避免遮挡图标
                    .zIndex(999) // 确保在最上层
            }
        }
        // 在这里处理 Drop，以便更新 isTargeted 状态
        .dropDestination(for: String.self) { items, location in
            return onDrop(items)
        } isTargeted: { targeted in
            withAnimation {
                isTargeted = targeted
            }
        }
    }
}

struct ItemGridCell: View {
    let item: Item
    let isEditing: Bool
    let isSelected: Bool
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            StickerGridItemView(item: item)
                // 移除 isEditing 的透明度变化，保持原样
                .opacity(1.0)
            
            if isEditing {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .gray)
                    .background(Circle().fill(.white))
                    .padding(8)
            }
        }
        .scaleEffect(isSelected ? 0.95 : 1.0)
        .animation(.spring, value: isSelected)
    }
}
