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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
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
    
    // 状态更新标志位，防止循环触发
    @State private var isUpdatingFromFilter = false
    @State private var isUpdatingFromContainerID = false
    
    // 垃圾桶的高度阈值（屏幕底部多少像素算作垃圾桶区域）
    private let trashBinHeight: CGFloat = 120
    
    // UserDefaults Key
    private let hasInitializedKey = "hasInitializedDefaultContainers"
    
    // 网格布局状态
    // 使用 @AppStorage 持久化存储列数设置
    @AppStorage("gridColumnCount") private var gridColumnCount: Int = 2
    @State private var baseColumnCount: CGFloat = 2.0
    // 用于在缩放过程中记录精确的列数计算结果
    @State private var preciseColumnCount: CGFloat = 2.0
    // 是否正在缩放 (用于防止误触)
    @State private var isScaling = false
    
    var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: gridColumnCount)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                AppTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 1. 顶部区域：家/房间视图 + 编辑按钮
                    homeHeaderView
                    
                    // 2. 容器选择列表
                    containerListView
                    inventoryHeading
                    
                    // 3. 物品网格
                    itemsGridView
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                initializeDefaultContainers()
                // 同步 baseColumnCount 与 gridColumnCount
                baseColumnCount = CGFloat(gridColumnCount)
                preciseColumnCount = CGFloat(gridColumnCount)
            }
            // 监听拖拽完成通知，清空选中状态
            .onReceive(NotificationCenter.default.publisher(for: FurnitureView.didDropItemsNotification)) { _ in
                withAnimation {
                    selectedItems.removeAll()
                    draggingItems.removeAll() // 确保拖拽状态也清除
                }
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
            .onChange(of: selectedFilter) { oldFilter, newValue in
                // 防止循环触发
                guard !isUpdatingFromContainerID else { return }
                
                isUpdatingFromFilter = true
                defer { isUpdatingFromFilter = false }
                
                // 反向联动：当用户在列表点击容器时，更新 selectedContainerID 以高亮家具
                if case .specific(let container) = newValue {
                    withAnimation {
                        selectedContainerID = container.id.uuidString
                    }
                } else if newValue == .all {
                    // 只有当明确切换到“全部”时，才取消家具高亮
                    withAnimation {
                        selectedContainerID = nil
                    }
                } else if newValue == .unclassified {
                    // 切换到“未分类”时，也取消家具高亮，因为未分类没有对应的家具实体
                    withAnimation {
                        selectedContainerID = nil
                    }
                }
            }
            .onChange(of: selectedContainerID) { _, newValue in
                // 防止循环触发
                guard !isUpdatingFromFilter else { return }
                
                isUpdatingFromContainerID = true
                defer { isUpdatingFromContainerID = false }
                
                // 仅当 selectedContainerID 变为 nil 时，需要判断是否是被动变动
                // 如果是从 specific -> unclassified 过程中，selectedContainerID 会被置空
                // 此时不应该触发 selectedFilter = .all
                
                if let id = newValue,
                   let container = containers.first(where: { $0.id.uuidString == id }) {
                    withAnimation {
                        selectedFilter = .specific(container)
                    }
                } else if newValue == nil {
                     // 只有当前已经在 .specific 状态下，且不是因为切换到其他 tab 导致的置空，才重置为 .all
                     // 但这里很难区分是用户点击家具取消选中，还是因为 filter 变了导致 id 置空
                     
                     // 解决方案：我们只处理“用户点击家具取消选中”的情况。
                     // 如果是因为 filter 变化导致的 id 置空，在 filter 的 onChange 里已经处理了逻辑。
                     // 但是这两个 onChange 是相互独立的。
                     
                     // 简单策略：如果当前是 specific 状态，且 id 变为空，说明可能是用户取消了选中，此时切回 all 是合理的。
                     // 但如果当前是 unclassified，id 变为空（本来就是空），则不应切回 all。
                     
                     if case .specific = selectedFilter {
                         withAnimation {
                             selectedFilter = .all
                         }
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
        .tint(AppTheme.accent)
    }
    
    // 装修模式的全屏覆盖
    @State private var showDecorationSheet = false
    
    // 选中的容器 ID (用于联动)
    @State private var selectedContainerID: String?

    // 家的预览高度状态
    @State private var homeHeaderHeight: CGFloat = 320
    private let maxHeaderHeight: CGFloat = 320
    private let minHeaderHeight: CGFloat = 170
    
    // MARK: - Views
    
    private var homeHeaderView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                StorageBuddy().frame(width: 42, height: 42).padding(.trailing, 4)
                VStack(alignment: .leading, spacing: 3) {
                    Text("我的小天地")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(AppTheme.text)
                    Text("\(allItems.count) 件物品 · \(containers.count) 个容器")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer(minLength: 4)
                if !isEditing {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(ToyIconButtonStyle(isPrimary: true))
                    .accessibilityLabel("拍照添加物品")
                    .transition(.opacity)
                }
                Button(action: {
                    withAnimation {
                        isEditing.toggle()
                        selectedItems.removeAll()
                    }
                }) {
                    Image(systemName: isEditing ? "checkmark" : "checklist")
                }
                .buttonStyle(ToyIconButtonStyle())
                .accessibilityLabel(isEditing ? "完成编辑" : "编辑物品")
            }
            .padding(.horizontal, AppTheme.Layout.pagePadding)
            .padding(.vertical, 12)
            HomeDecorationView(isPreviewMode: true, selectedContainerID: $selectedContainerID)
                .frame(height: homeHeaderHeight)
                // 画布内容随抽屉收起一起裁剪，避免房间穿到物品列表上。
                .clipped()
                .overlay(alignment: .bottomTrailing) { homeHeaderButtonGroup }
                .overlay(alignment: .bottomLeading) {
                    Button { showDecorationSheet = true } label: {
                        Label("布置房间", systemImage: "paintbrush.pointed.fill")
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(ToyIconButtonStyle())
                    .padding(.leading, 20).padding(.bottom, 38)
                }
        }
        .background(AppTheme.blueInset.ignoresSafeArea(edges: .top))
        // 确保 ZIndex 正确，避免被 containerListView 覆盖时出现背景穿透
        .zIndex(0)
        // 全屏装修模式
        .fullScreenCover(isPresented: $showDecorationSheet) {
            NavigationStack {
                // 直接进入编辑模式，并传递选中状态绑定，确保可以交互
                HomeDecorationView(isPreviewMode: false, isEditing: true, selectedContainerID: $selectedContainerID)
            }
        }
    }

    private var homeHeaderButtonGroup: some View {
        let buttonSize: CGFloat = 44
        let spacing: CGFloat = 8
        
        return VStack(spacing: spacing) {
            // 上方按钮：执行复位 (原定位按钮的位置)
            circleIconButton(
                systemName: "scope",
                buttonSize: buttonSize
            ) {
                NotificationCenter.default.post(name: .resetHomeView, object: nil)
            }
            .accessibilityLabel("房间视角复位")
            
            // 下方按钮：执行缩放 (原缩放按钮的位置)
            Button(action: {
                // 使用 DispatchQueue.main.async 延迟执行动画，避免在点击事件处理过程中直接触发布局更新
                // 这有助于断开点击反馈动画与布局动画之间的耦合
                DispatchQueue.main.async {
                    let nextHeight = (homeHeaderHeight == maxHeaderHeight) ? minHeaderHeight : maxHeaderHeight
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                        homeHeaderHeight = nextHeight
                    }
                }
            }) {
                Image(systemName: homeHeaderHeight == maxHeaderHeight ? "chevron.up" : "chevron.down")
                .frame(width: buttonSize, height: buttonSize)
            }
            .buttonStyle(ToyIconButtonStyle())
            .accessibilityLabel(homeHeaderHeight == maxHeaderHeight ? "收起小房间" : "展开小房间")
        }
        .padding(.trailing, 16)
        .padding(.bottom, 36)
    }
    
    // 封装圆形图标按钮
    private func circleIconButton(systemName: String, buttonSize: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
            .frame(width: buttonSize, height: buttonSize)
        }
        .buttonStyle(ToyIconButtonStyle())
    }
    
    private var containerListView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "全部" 容器
                allContainerButton
                
                // "未分类" 容器
                unclassifiedContainerButton
                
                // 现有容器列表
                ForEach(containers) { container in
                    ContainerTabItem(
                        container: container,
                        isSelected: selectedFilter == .specific(container)
                    ) { items in
                        // 处理 Drop 逻辑
                        handleDrop(items: items, to: container)
                        return true
                    }
                    .onTapGesture {
                        withAnimation {
                            selectedFilter = .specific(container)
                        }
                    }
                    .onLongPressGesture {
                        selectedFilter = .specific(container)
                        showEditContainerSheet = true
                    }
                }
                
                // 添加容器按钮
                addContainerButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16) // 增加一点垂直内边距，适应大圆角
        }
        .background(
            AppTheme.surface
                .clipShape(
                    .rect(
                        topLeadingRadius: 30,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 30
                    )
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: -4) // 添加一点向上阴影增强层次感
        )
        .scrollClipDisabled()
        .padding(.top, -24) // 向上偏移覆盖 Header，形成抽屉效果
    }
    
    // 拆分出单独的视图组件，解决 ViewBuilder 过于复杂的问题
    private var allContainerButton: some View {
        VStack(spacing: 4) {
            ContainerBadge(symbol: "square.grid.2x2.fill", isSelected: selectedFilter == .all)
            
            Text("全部")
                .font(.caption)
                .fontWeight(selectedFilter == .all ? .bold : .regular)
                .foregroundStyle(selectedFilter == .all ? AppTheme.text : AppTheme.secondaryText)
        }
        .onTapGesture {
            withAnimation {
                selectedFilter = .all
            }
        }
    }
    
    private var unclassifiedContainerButton: some View {
        VStack(spacing: 4) {
            ContainerBadge(symbol: "tray.fill", isSelected: selectedFilter == .unclassified)
            
            Text("未分类")
                .font(.caption)
                .fontWeight(selectedFilter == .unclassified ? .bold : .regular)
                .foregroundStyle(selectedFilter == .unclassified ? AppTheme.text : AppTheme.secondaryText)
        }
        .onTapGesture {
            withAnimation {
                selectedFilter = .unclassified
            }
        }
        .dropDestination(for: String.self) { items, location in
            handleDrop(items: items, to: nil)
            return true
        } isTargeted: { _ in }
    }
    
    private var addContainerButton: some View {
        Button(action: { showAddContainerSheet = true }) {
            VStack(spacing: 4) {
                ContainerBadge(symbol: "plus")
                
                Text("添加")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }
    
    // 处理拖拽放置逻辑
    private func handleDrop(items: [String], to targetContainer: Container?) {
        var idsToProcess = Set(items.flatMap { $0.split(separator: ",").map(String.init) })
        
        // 如果拖拽的物品在选中列表中，则同时处理所有选中的物品
        if !selectedItems.isEmpty {
            let selectedIds = Set(selectedItems.map { $0.id.uuidString })
            if !idsToProcess.isDisjoint(with: selectedIds) {
                idsToProcess.formUnion(selectedIds)
            }
        }
        
        var movedCount = 0
        for id in idsToProcess {
            if let item = allItems.first(where: { $0.id.uuidString == id }) {
                withAnimation {
                    item.container = targetContainer
                    item.updatedDate = Date()
                }
                movedCount += 1
            }
        }
        
        // 如果有移动，触发震动反馈
        if movedCount > 0 {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
        
        // 操作完成后清空选中状态
        selectedItems.removeAll()
        // 确保拖拽状态也清除 (虽然 onDragEnd 也会清除，但这里是 Drop 成功的回调，双重保险)
        draggingItems.removeAll()
    }
    
    // 计算动态高度
    private var dynamicItemHeight: CGFloat {
        // 根据列数计算高度
        // 调整高度计算公式，使贴纸整体稍微变小
        // 2列 -> 160 (原180)
        // 3列 -> 132 (原150)
        // 4列 -> 104 (原120)
        // 5列 -> 76 (原90)
        // 公式：160 - (列数 - 2) * 28
        let height = 160.0 - CGFloat(gridColumnCount - 2) * 28.0
        return max(height, 60.0) // 最小高度 60
    }
    
    private var inventoryHeading: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(isEditing ? "已选 \(selectedItems.count) 件" : "物品贴纸")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(AppTheme.text)
            Spacer()
            Text(isEditing ? "拖进容器即可收纳" : "\(currentItems.count) 件 · 双指缩放")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.horizontal, AppTheme.Layout.pagePadding)
        .padding(.vertical, 12)
        .background(AppTheme.background)
    }

    private var itemsGridView: some View {
        ScrollView {
            let filteredItems = currentItems.sorted { $0.createdDate > $1.createdDate }
            
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(filteredItems) { item in
                        // 如果在编辑模式，拦截点击事件用于选择
                        // 如果在浏览模式，使用 NavigationLink 进行跳转
                        if isEditing {
                            ItemGridCell(
                                item: item,
                                isEditing: isEditing,
                                isSelected: selectedItems.contains(item),
                                itemHeight: dynamicItemHeight
                            )
                            .opacity(draggingItems.contains(item.id.uuidString) ? 0.3 : 1.0) // 幽灵占位效果
                            .onTapGesture {
                                toggleSelection(item)
                            }
                            // 支持拖拽 (自定义，移除系统背景和阴影)
                            .customDraggable(
                                itemProvider: {
                                    // 检查是否在多选中，如果是，则提供所有选中物品的 ID
                                    if selectedItems.contains(item) {
                                        // 我们修改策略：传递所有 ID 的 JSON 数组字符串
                                        // 我们可以把所有 ID 拼成一个字符串 "id1,id2,id3"
                                        let allIDs = selectedItems.map { $0.id.uuidString }.joined(separator: ",")
                                        return NSItemProvider(object: allIDs as NSString)
                                    } else {
                                        return NSItemProvider(object: item.id.uuidString as NSString)
                                    }
                                },
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
                            // 浏览模式
                            // 直接使用 NavigationLink，并在缩放时禁用
                            NavigationLink {
                                ItemDetailView(item: item)
                            } label: {
                                ItemGridCell(
                                    item: item,
                                    isEditing: isEditing,
                                    isSelected: selectedItems.contains(item),
                                    itemHeight: dynamicItemHeight
                                )
                            }
                            // 关键：缩放时禁用跳转，防止误触
                            .disabled(isScaling)
                            .opacity(draggingItems.contains(item.id.uuidString) ? 0.3 : 1.0) // 幽灵占位效果
                            // 支持拖拽 (自定义，移除系统背景和阴影)
                            .customDraggable(
                                itemProvider: {
                                    if selectedItems.contains(item) {
                                        let allIDs = selectedItems.map { $0.id.uuidString }.joined(separator: ",")
                                        return NSItemProvider(object: allIDs as NSString)
                                    } else {
                                        return NSItemProvider(object: item.id.uuidString as NSString)
                                    }
                                },
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
                    // 强制在列数变化时重建整个 Cell，解决图片大小不更新的问题
                    .id(gridColumnCount)
                }
                .padding(20)
                .padding(.bottom, isEditing ? 80 : 0) // 给垃圾桶留位置
                // 双指缩放手势
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            // 开始缩放
                            isScaling = true
                            
                            // value > 1 (放大) -> 列数减少 (物品变大)
                            // value < 1 (缩小) -> 列数增加 (物品变小)
                            let newCount = baseColumnCount / value
                            // 记录精确计算值
                            preciseColumnCount = newCount
                            
                            let clampedCount = min(max(Int(round(newCount)), 2), 5)
                            
                            if gridColumnCount != clampedCount {
                                // 移除 withAnimation，避免与 .id(gridColumnCount) 强制重建产生冲突
                                // 导致 Invalid sample AnimatablePair 错误
                                gridColumnCount = clampedCount
                            }
                        }
                        .onEnded { _ in // 忽略 onEnded 传入的 value，使用 onChanged 中记录的 preciseColumnCount
                            // 关键修正：直接使用 onChanged 中计算并记录的精确值
                            // 避免 onEnded 中 value 可能存在的误差或不一致问题
                            // 同时限制 baseColumnCount 在合理范围内 (2~5)
                            baseColumnCount = min(max(preciseColumnCount, 2.0), 5.0)
                            
                            // 延迟恢复点击，防止松手瞬间误触
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                isScaling = false
                            }
                        }
                )
            }
        }
        .background(
            ZStack {
                AppTheme.background
            }
        )
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
        VStack(spacing: 16) {
            StorageBuddy().frame(width: 72, height: 72).padding(.bottom, 8)
            
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
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(AppTheme.secondaryText)
            Button { showAddSheet = true } label: {
                Label("添加一件物品", systemImage: "plus")
            }
            .buttonStyle(AppButtonStyle())
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
        var itemsToDelete: Set<Item> = []
        var allUUIDs: Set<UUID> = []
        
        // 1. 解析所有拖拽过来的 ID
        // 注意：由于 customDraggable 可能会将多个 ID 拼成一个字符串 ("id1,id2")，
        // 我们需要先进行拆分
        for itemString in items {
            let ids = itemString.split(separator: ",").map { String($0) }
            for idStr in ids {
                if let uuid = UUID(uuidString: idStr) {
                    allUUIDs.insert(uuid)
                }
            }
        }
        
        // 2. 根据解析出的 ID 查找对应的 Item 对象
        // 遍历 allItems 查找匹配的 Item (虽然效率不是最优，但对于本地数据通常足够快)
        // 或者使用 FetchDescriptor 按 ID 查询
        for item in allItems {
            if allUUIDs.contains(item.id) {
                itemsToDelete.insert(item)
            }
        }
        
        // 3. 执行删除
        withAnimation {
            for item in itemsToDelete {
                modelContext.delete(item)
            }
            // 清理状态
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
        do {
            try ItemRepository.clearDisabledRecognition(in: allItems, context: modelContext)
        } catch {
            print("旧识别状态清理失败，下次进入时重试：\(error.localizedDescription)")
        }
        
        // 使用 UserDefaults 来检查是否已经初始化过
        let hasInitialized = UserDefaults.standard.bool(forKey: hasInitializedKey)
        
        if !hasInitialized && containers.isEmpty {
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
            
            try? modelContext.save()
            
            // 标记为已初始化
            UserDefaults.standard.set(true, forKey: hasInitializedKey)
        }
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
            ContainerBadge(furnitureID: FurnitureConfig.styleID(name: container.name, icon: container.icon, savedID: container.furnitureImageName), isSelected: isSelected)
                // 拖拽高亮效果
                .scaleEffect(isTargeted ? 1.2 : 1.0)
                .animation(.spring, value: isTargeted)
            
            Text(container.name)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(isSelected ? AppTheme.text : AppTheme.secondaryText)
                .lineLimit(1)
                .frame(width: 64)
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
            // 解析可能的 ID 列表字符串
            var allItems: [String] = []
            for itemString in items {
                let ids = itemString.split(separator: ",").map { String($0) }
                allItems.append(contentsOf: ids)
            }
            
            return onDrop(allItems)
        } isTargeted: { targeted in
            withAnimation {
                isTargeted = targeted
            }
        }
    }
}

private struct NoButtonFeedbackStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

struct ItemGridCell: View {
    let item: Item
    let isEditing: Bool
    let isSelected: Bool
    // 接收动态高度
    var itemHeight: CGFloat = 120
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            StickerGridItemView(item: item, height: itemHeight)
                // 移除 isEditing 的透明度变化，保持原样
                .opacity(1.0)
            
            if isEditing {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.secondaryText)
                    .background(Circle().fill(AppTheme.surface))
                    .padding(8)
            }
        }
        .scaleEffect(isSelected ? 0.95 : 1.0)
        .animation(.spring, value: isSelected)
    }
}
