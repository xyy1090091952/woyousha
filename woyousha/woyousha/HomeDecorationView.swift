import SwiftUI
import SwiftData

extension NSNotification.Name {
    static let resetHomeView = NSNotification.Name("ResetHomeView")
}

struct HomeDecorationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Container.zIndex) private var containers: [Container]
    var isPreviewMode: Bool
    @Binding var selectedContainerID: String?

    @AppStorage("homeViewOffsetX") private var storedOffsetX = 0.0
    @AppStorage("homeViewOffsetY") private var storedOffsetY = 0.0
    @AppStorage("homeViewScale") private var storedScale = 1.0
    @AppStorage("currentRoomImage") private var currentRoomImage = "home1"
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var isEditing: Bool
    @State private var draggingContainerID: String?
    @State private var dragOffset: CGSize = .zero
    @State private var previewScale: Double?
    @State private var errorMessage: String?
    @State private var decorationStore = RoomDecorationStore.shared
    @State private var selectedDecorationID: String?
    @State private var draggingDecorationID: String?
    @State private var decorationDragOffset: CGSize = .zero
    @State private var decorationScalePreview: Double?
    @State private var drawerCategory = DrawerCategory.furniture
    @State private var showsFurnitureCatalog = false
    @State private var showsDecorationCatalog = false

    private enum DrawerCategory: String, CaseIterable {
        case furniture = "家具"
        case decorations = "装饰物"
    }

    init(isPreviewMode: Bool = false, isEditing: Bool = false, selectedContainerID: Binding<String?> = .constant(nil)) {
        self.isPreviewMode = isPreviewMode
        _isEditing = State(initialValue: isEditing)
        _selectedContainerID = selectedContainerID
    }

    private var selectedContainer: Container? {
        containers.first { $0.id.uuidString == selectedContainerID && $0.isPlaced }
    }
    private var selectedDecoration: RoomDecoration? {
        decorationStore.decorations.first { $0.id == selectedDecorationID && $0.isPlaced }
    }

    var body: some View {
        Group {
            if isPreviewMode {
                canvas
            } else {
                VStack(spacing: 0) {
                    if isEditing {
                        Picker("房间风格", selection: $currentRoomImage) {
                            Text("阳光木屋").tag("home1")
                            Text("森林小屋").tag("home2")
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    canvas
                        .clipped()
                        .overlay(alignment: .bottomTrailing) {
                            Button { resetViewport() } label: {
                                Image(systemName: "scope")
                            }
                            .buttonStyle(ToyIconButtonStyle())
                            .padding(16)
                            .accessibilityLabel("房间视角复位")
                        }
                }
                .background(AppTheme.background)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if isEditing {
                        ScrollView {
                            if let decoration = selectedDecoration {
                                DecorationInspector(decoration:decoration,roomStyle:currentRoomImage,
                                    onAction:{ performDecoration($0,id:decoration.id) },
                                    onPreviewScale:{ decorationScalePreview=$0 },
                                    onClose:{ selectedDecorationID=nil })
                                    .id(decoration.id)
                            } else if let container = selectedContainer {
                                FurnitureInspector(container: container, onAction: { action in
                                    perform(action, on: container)
                                }, onPreviewScale: { previewScale = $0 }, onClose: {
                                    selectedContainerID = nil
                                })
                                .id(container.id)
                            } else {
                                furnitureDrawer
                            }
                        }
                        .frame(height: RoomConfig.inspectorHeight)
                        .background(AppTheme.surface)
                    }
                }
                .navigationTitle(isEditing ? "布置小房间" : "我的小天地")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("返回") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isEditing ? "完成" : "装修") {
                            if isEditing { dismiss() } else { isEditing = true }
                        }
                        .fontWeight(.bold)
                    }
                }
                .toolbarBackground(AppTheme.background, for: .navigationBar)
            }
        }
        .tint(AppTheme.accent)
        .onAppear { restoreViewport() }
        .onChange(of: selectedContainerID) { _, id in
            previewScale = nil
            if id != nil { selectedDecorationID = nil }
        }
        .onChange(of: selectedDecorationID) { _, id in
            decorationScalePreview = nil
            if id != nil { selectedContainerID = nil }
        }
        .onReceive(NotificationCenter.default.publisher(for: .resetHomeView)) { _ in resetViewport() }
        .sheet(isPresented: $showsFurnitureCatalog) {
            FurnitureCatalogPicker(title: "添加家具", dismissOnSelection: true, onSelect: addFurniture)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showsDecorationCatalog) {
            DecorationCatalogPicker(roomStyle: currentRoomImage, onSelect: addDecoration)
                .presentationDetents([.medium, .large])
        }
        .alert("布置没有保存", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var canvas: some View {
        GeometryReader { geo in
            let fitScale = min(geo.size.width / RoomConfig.roomWidth, geo.size.height / RoomConfig.roomHeight) * 0.96
            let effectiveScale = max(0.01, fitScale * scale)
            ZStack {
                PixelRoomView(styleID: currentRoomImage)
                    .frame(width: RoomConfig.roomWidth, height: RoomConfig.roomHeight)
                    .position(x: RoomConfig.roomWidth / 2, y: RoomConfig.roomHeight / 2)
                    .zIndex(-1000)

                ForEach(containers.filter(\.isPlaced)) { container in
                    FurnitureView(container: container,
                                  isSelected: selectedContainerID == container.id.uuidString,
                                  previewScale: selectedContainerID == container.id.uuidString ? previewScale : nil,
                                  showsShadow: false)
                        .position(
                            x: container.posX + (draggingContainerID == container.id.uuidString ? dragOffset.width / effectiveScale : 0),
                            y: container.posY + (draggingContainerID == container.id.uuidString ? dragOffset.height / effectiveScale : 0)
                        )
                        .zIndex(Double(container.zIndex))
                        .gesture(
                            isEditing && selectedContainerID == container.id.uuidString ?
                            DragGesture(minimumDistance: 3)
                                .onChanged { value in
                                    draggingContainerID = container.id.uuidString
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    perform(.move(CGPoint(
                                        x: container.posX + value.translation.width / effectiveScale,
                                        y: container.posY + value.translation.height / effectiveScale
                                    )), on: container)
                                    dragOffset = .zero
                                    // 画布手势完成后再释放拖拽标记，防止同一次触摸也平移房间。
                                    DispatchQueue.main.async { draggingContainerID = nil }
                                } : nil
                        )
                        .onTapGesture {
                            selectedContainerID = selectedContainerID == container.id.uuidString ? nil : container.id.uuidString
                        }
                }
                ForEach(decorationStore.decorations.filter(\.isPlaced)) { decoration in
                    DecorationPlacementView(decoration:decoration,roomStyle:currentRoomImage,
                        isSelected:isEditing && selectedDecorationID==decoration.id,
                        scaleOverride:selectedDecorationID==decoration.id ? decorationScalePreview:nil)
                        .position(
                            x:decoration.posX+(draggingDecorationID==decoration.id ? decorationDragOffset.width/effectiveScale:0),
                            y:decoration.posY+(draggingDecorationID==decoration.id ? decorationDragOffset.height/effectiveScale:0))
                        .zIndex(decoration.kind.isFloorCovering ? -950:Double(decoration.zIndex))
                        .gesture(
                            isEditing && selectedDecorationID==decoration.id ?
                            DragGesture(minimumDistance:3)
                                .onChanged { value in
                                    draggingDecorationID=decoration.id
                                    decorationDragOffset=value.translation
                                }
                                .onEnded { value in
                                    _=performDecoration(.move(
                                        decoration.posX+value.translation.width/effectiveScale,
                                        decoration.posY+value.translation.height/effectiveScale),id:decoration.id)
                                    decorationDragOffset = .zero
                                    DispatchQueue.main.async { draggingDecorationID=nil }
                                }:nil
                        )
                        .onTapGesture {
                            guard isEditing else { return }
                            selectedContainerID=nil
                            selectedDecorationID=selectedDecorationID==decoration.id ? nil:decoration.id
                        }
                        .allowsHitTesting(isEditing)
                }

                // 影子先画在地板上，再由所有家具主体遮住；不会跨层盖黑前方的家具。
                ZStack {
                    ForEach(containers.filter(\.isPlaced)) { container in
                        PixelFurnitureShadowView(
                            styleID: FurnitureConfig.styleID(name:container.name,icon:container.icon,savedID:container.furnitureImageName),
                            mirrored:container.isMirrored,
                            scale:selectedContainerID == container.id.uuidString ? (previewScale ?? container.scale) : container.scale)
                            .position(x:container.posX+(draggingContainerID == container.id.uuidString ? dragOffset.width/effectiveScale : 0),
                                      y:container.posY+(draggingContainerID == container.id.uuidString ? dragOffset.height/effectiveScale : 0))
                    }
                    ForEach(decorationStore.decorations.filter(\.isPlaced)) { decoration in
                        PixelDecorationShadowView(decoration:decoration,roomStyle:currentRoomImage,
                            scaleOverride:selectedDecorationID == decoration.id ? decorationScalePreview : nil)
                            .position(x:decoration.posX+(draggingDecorationID == decoration.id ? decorationDragOffset.width/effectiveScale : 0),
                                      y:decoration.posY+(draggingDecorationID == decoration.id ? decorationDragOffset.height/effectiveScale : 0))
                    }
                }
                .frame(width:RoomConfig.roomWidth,height:RoomConfig.roomHeight)
                .clipShape(RoomFloorShadowMask())
                .allowsHitTesting(false)
                .zIndex(-940)
            }
            .frame(width: RoomConfig.roomWidth, height: RoomConfig.roomHeight)
            .scaleEffect(effectiveScale)
            .position(x: geo.size.width / 2 + offset.width, y: geo.size.height / 2 + offset.height)
        }
        .contentShape(Rectangle())
        .gesture(
            SimultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        guard draggingContainerID == nil && draggingDecorationID == nil else { return }
                        offset = CGSize(width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height)
                    }
                    .onEnded { _ in
                        guard draggingContainerID == nil && draggingDecorationID == nil else { return }
                        lastOffset = offset
                        storedOffsetX = offset.width
                        storedOffsetY = offset.height
                    },
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(max(lastScale * value, RoomConfig.zoomRange.lowerBound), RoomConfig.zoomRange.upperBound)
                    }
                    .onEnded { _ in lastScale = scale; storedScale = scale }
            )
        )
    }

    private var furnitureDrawer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("布置类别",selection:$drawerCategory) {
                ForEach(DrawerCategory.allCases,id:\.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            HStack {
                Text(drawerCategory == .furniture ? "待布置的家具":"装饰物")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                Spacer()
                Text(drawerCategory == .furniture ? "轻点放入房间" : "按分类挑选装饰")
                    .font(.caption).foregroundStyle(AppTheme.secondaryText)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if drawerCategory == .decorations {
                        decorationTiles
                    } else {
                        furnitureTiles
                    }
                }
            }
        }
        .padding(16)
        .foregroundStyle(AppTheme.text)
        .background(AppTheme.surface)
        .overlay(alignment: .top) { Rectangle().fill(AppTheme.line).frame(height: 2) }
    }

    @ViewBuilder
    private var furnitureTiles: some View {
        addTile(title: "添加家具") { showsFurnitureCatalog = true }
        let unplaced = containers.filter { !$0.isPlaced }
        if unplaced.isEmpty {
            Text("添加新家具，或轻点房间里的家具调整。")
                .font(.subheadline).foregroundStyle(AppTheme.secondaryText).padding(.vertical, 24)
        }
        ForEach(unplaced) { container in
            Button { perform(.place(RoomConfig.initialFurniturePosition), on: container) } label: {
                VStack(spacing: 6) {
                    PixelFurnitureView(styleID: FurnitureConfig.styleID(name: container.name, icon: container.icon, savedID: container.furnitureImageName))
                        .frame(width: 68, height: 70)
                    Text(container.name).font(.caption.weight(.bold)).lineLimit(1)
                }
                .frame(width: 84)
                .padding(8)
                .background(AppTheme.inset, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
        }
    }

    /// 与家具同一种入口：先点“添加装饰”打开带分类 tab 的目录浮层，再挑选放入房间。
    @ViewBuilder
    private var decorationTiles: some View {
        addTile(title: "添加装饰") { showsDecorationCatalog = true }
        Text("挑选后会放进房间，轻点房间里的装饰可调整。")
            .font(.subheadline).foregroundStyle(AppTheme.secondaryText).padding(.vertical, 24)
    }

    /// 抽屉里的“＋”入口，家具和装饰共用同一外观。
    private func addTile(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold))
                    .frame(width: 68, height: 70)
                Text(title).font(.caption.weight(.bold))
            }
            .frame(width: 84)
            .padding(8)
            .foregroundStyle(AppTheme.accentText)
            .background(AppTheme.inset, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    /// 目录浮层回调：保存成功才关闭浮层并选中新装饰；失败时浮层内提示重试。
    private func addDecoration(kind: RoomDecoration.Kind) -> Bool {
        do {
            let addedID = try decorationStore.add(kind: kind, furnitureLayers: containers.filter(\.isPlaced).map(\.zIndex))
            selectedContainerID = nil
            selectedDecorationID = addedID
            return true
        } catch {
            return false
        }
    }

    private func addFurniture(styleID: String) -> Bool {
        do {
            let added = try FurniturePlacementRepository.add(
                styleID: styleID, among: containers,
                decorationLayers: decorationStore.decorations.filter { !$0.kind.isFloorCovering }.map(\.zIndex),
                in: modelContext
            )
            selectedDecorationID = nil
            selectedContainerID = added.id.uuidString
            return true
        } catch {
            // 目录抽屉显示保存失败提示，并保留当前位置供用户重试。
            return false
        }
    }

    @discardableResult
    private func perform(_ action: FurniturePlacementRepository.Action, on container: Container) -> Bool {
        do {
            try FurniturePlacementRepository.perform(action, on: container, among: containers, in: modelContext)
            selectedDecorationID = nil
            if container.isPlaced { selectedContainerID = container.id.uuidString }
            else { selectedContainerID = nil }
            return true
        } catch {
            previewScale = nil
            errorMessage = "修改没有保存成功，请再试一次。"
            return false
        }
    }

    @discardableResult
    private func performDecoration(_ action:RoomDecorationStore.Action,id:String) -> Bool {
        do {
            try decorationStore.perform(action,id:id,furnitureLayers:containers.filter(\.isPlaced).map(\.zIndex))
            let decoration=decorationStore.decorations.first { $0.id==id }
            selectedDecorationID=decoration?.isPlaced == true ? id:nil
            if decoration == nil {
                decorationScalePreview = nil
                draggingDecorationID = nil
                decorationDragOffset = .zero
            }
            if selectedDecorationID != nil { selectedContainerID=nil }
            return true
        } catch {
            decorationScalePreview=nil
            errorMessage="装饰物位置没有保存成功，请重试。"
            return false
        }
    }

    private func resetViewport() {
        scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
        storedScale = 1; storedOffsetX = 0; storedOffsetY = 0
    }

    private func restoreViewport() {
        scale = storedScale.isFinite ? min(max(storedScale, RoomConfig.zoomRange.lowerBound), RoomConfig.zoomRange.upperBound) : 1
        lastScale = scale
        offset = CGSize(width: storedOffsetX.isFinite ? storedOffsetX : 0,
                        height: storedOffsetY.isFinite ? storedOffsetY : 0)
        lastOffset = offset
    }
}

/// 家具只负责展示与接收物品，装修控制面板位于画布外，不遮挡拖拽目标。
struct FurnitureView: View {
    static let didDropItemsNotification = Notification.Name("didDropItemsNotification")
    let container: Container
    let isSelected: Bool
    var previewScale: Double?
    var showsShadow = true
    @Environment(\.modelContext) private var modelContext
    @State private var isTargeted = false
    @State private var dropError: String?

    var body: some View {
        let styleID = FurnitureConfig.styleID(name: container.name, icon: container.icon, savedID: container.furnitureImageName)
        let size = FurnitureConfig.displaySize(for: container, scaleOverride: previewScale)
        PixelFurnitureView(styleID: styleID, isMirrored: container.isMirrored,
                           showsOutline: isSelected || isTargeted, showsShadow: showsShadow)
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .accessibilityLabel(container.name)
            .overlay(alignment: .top) {
                if isTargeted {
                    Text("收进 \(container.name)")
                        .font(.caption.weight(.bold)).foregroundStyle(.white)
                        .padding(8).background(AppTheme.accentText, in: Capsule())
                        .fixedSize().offset(y: -36)
                }
            }
            .dropDestination(for: String.self) { strings, _ in
                let ids = Set(strings.flatMap { $0.split(separator: ",").compactMap { UUID(uuidString: String($0)) } })
                guard !ids.isEmpty else { return false }
                do {
                    try modelContext.save()
                    for id in ids {
                        let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })
                        if let item = try modelContext.fetch(descriptor).first {
                            item.container = container
                            item.updatedDate = Date()
                        }
                    }
                    do { try modelContext.save() } catch { modelContext.rollback(); throw error }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    NotificationCenter.default.post(name: Self.didDropItemsNotification, object: nil)
                    return true
                } catch {
                    dropError = "没有收纳成功，请再试一次。"
                    return false
                }
            } isTargeted: { isTargeted = $0 }
            .alert("收纳未完成", isPresented: Binding(
                get: { dropError != nil },
                set: { if !$0 { dropError = nil } }
            )) {
                Button("知道了", role: .cancel) { dropError = nil }
            } message: { Text(dropError ?? "") }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a,r,g,b) = (255,(value>>8)*17,(value>>4&15)*17,(value&15)*17)
        case 8: (a,r,g,b) = (value>>24,value>>16&255,value>>8&255,value&255)
        default: (a,r,g,b) = (255,value>>16&255,value>>8&255,value&255)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
