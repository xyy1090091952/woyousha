import SwiftUI
import SwiftData

extension NSNotification.Name {
    static let resetHomeView = NSNotification.Name("ResetHomeView")
}

/// 首页与装修页共用同一个家园；房型和物品格子来自各自唯一的存储入口。
@MainActor
struct HomeDecorationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort:\Container.createdDate) private var containers:[Container]
    var isPreviewMode:Bool
    @Binding var selectedContainerID:String?
    @State private var isEditing:Bool
    @State private var house=HouseLayoutStore.shared
    @State private var decorations=RoomDecorationStore.shared
    @AppStorage("currentRoomImage") private var currentRoomImage="home1"
    @AppStorage("homeViewScale") private var storedScale=1.0
    @AppStorage("homeViewOffsetX") private var storedOffsetX=0.0
    @AppStorage("homeViewOffsetY") private var storedOffsetY=0.0
    @State private var scale:CGFloat=1
    @State private var lastScale:CGFloat=1
    @State private var offset:CGSize = .zero
    @State private var lastOffset:CGSize = .zero
    @State private var mode=Mode.furnish
    @State private var showsGrid=true
    @State private var selectedDecorationID:String?
    @State private var draggingContainerID:String?
    @State private var draggingDecorationID:String?
    @State private var candidate:HouseCell?
    @State private var notice:String?
    @State private var draftRoom:HouseRoom?
    @State private var roomDragOrigin:HouseCell?
    @State private var isDraggingRoom=false
    @State private var drawerCategory=DrawerCategory.furniture
    @State private var showsFurnitureCatalog=false
    @State private var showsDecorationCatalog=false
    @State private var gridReady=false

    private enum Mode:String,CaseIterable { case furnish="布置",build="建房" }
    private enum DrawerCategory:String,CaseIterable { case furniture="家具",decorations="装饰" }

    /// 可注入独立存档用于原生预览，正式页面仍使用同一份家园。
    init(isPreviewMode:Bool=false,isEditing:Bool=false,selectedContainerID:Binding<String?> = .constant(nil),
         houseStore:HouseLayoutStore? = nil,decorationStore:RoomDecorationStore? = nil) {
        self.isPreviewMode=isPreviewMode
        _isEditing=State(initialValue:isEditing)
        _selectedContainerID=selectedContainerID
        _house=State(initialValue:houseStore ?? .shared)
        _decorations=State(initialValue:decorationStore ?? .shared)
    }
    private var occupants:[HouseOccupant] {
        HouseFurnitureCatalog.occupants(containers:containers,decorations:decorations.decorations)
    }
    private var metrics:HouseSceneMetrics {
        .init(layout:house.layout,occupants:occupants,showsPlot:isEditing && mode == .build)
    }
    private var selectedContainer:Container? {
        containers.first {$0.isPlaced && $0.id.uuidString == selectedContainerID}
    }
    private var selectedDecoration:RoomDecoration? {
        decorations.decorations.first {$0.isPlaced && $0.id == selectedDecorationID}
    }
    private var draftIssue:String? {
        guard let room=draftRoom else { return nil }
        do { try house.check(room,occupants:occupants);return nil }
        catch { return error.localizedDescription }
    }

    var body:some View {
        Group {
            if isPreviewMode { canvas }
            else {
                VStack(spacing:0) {
                    if isEditing { controls }
                    canvas.clipped().overlay(alignment:.bottomTrailing) {
                        Button { resetViewport() } label: { Image(systemName:"scope") }
                            .buttonStyle(ToyIconButtonStyle()).padding(12).accessibilityLabel("查看整个家")
                    }
                }
                .background(AppTheme.background)
                .safeAreaInset(edge:.bottom,spacing:0) {
                    if isEditing {
                        VStack(spacing:0) {
                            Text(notice ?? "格子摆放 · 两指缩放视角 · 修改成功后自动保存")
                                .font(.caption).foregroundStyle(notice == nil ? AppTheme.secondaryText:AppTheme.accentText)
                                .frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,16).padding(.vertical,8)
                            ScrollView { inspector }.disabled(!gridReady)
                                .frame(height:mode == .build ? 264:242)
                        }.background(AppTheme.surface)
                    }
                }
                .navigationTitle(isEditing ? "打造我的家":"我的小天地")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement:.topBarLeading) { Button("返回") { dismiss() } }
                    ToolbarItem(placement:.topBarTrailing) {
                        Button(isEditing ? "完成":"装修") {
                            if isEditing {
                                if draftRoom != nil { saveRoom() }
                                if draftRoom == nil { dismiss() }
                            } else { isEditing=true }
                        }.fontWeight(.bold)
                    }
                }
            }
        }
        .tint(AppTheme.accentText)
        .onAppear { prepareHouse() }
        .onChange(of:selectedContainerID) { _,id in if id != nil { selectedDecorationID=nil } }
        .onChange(of:selectedDecorationID) { _,id in if id != nil { selectedContainerID=nil } }
        .onChange(of:mode) { _,_ in
            selectedContainerID=nil;selectedDecorationID=nil;draftRoom=nil;candidate=nil
            resetViewport()
        }
        .onReceive(NotificationCenter.default.publisher(for:.resetHomeView)) { _ in resetViewport() }
        .sheet(isPresented:$showsFurnitureCatalog) {
            FurnitureCatalogPicker(title:"添加家具",dismissOnSelection:true,
                failureMessage:{notice ?? "没有保存成功，请再试一次。"},onSelect:addFurniture)
                .presentationDetents([.medium,.large])
        }
        .sheet(isPresented:$showsDecorationCatalog) {
            DecorationCatalogPicker(roomStyle:currentRoomImage,
                failureMessage:{notice ?? "没有保存成功，请再试一次。"},onSelect:addDecoration)
                .presentationDetents([.medium,.large])
        }
    }

    private var controls:some View {
        VStack(spacing:8) {
            Picker("装修玩法",selection:$mode) {
                ForEach(Mode.allCases,id:\.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            HStack {
                Menu {
                    Button("阳光木屋") { currentRoomImage="home1" }
                    Button("森林小屋") { currentRoomImage="home2" }
                } label: { Label(currentRoomImage == "home1" ? "阳光木屋":"森林小屋",systemImage:"paintpalette") }
                Spacer()
                Text("\(house.layout.rooms.count) 个房间").font(.caption).foregroundStyle(AppTheme.secondaryText)
                Button { showsGrid.toggle() } label: {
                    Image(systemName:showsGrid ? "square.grid.3x3.fill":"square.grid.3x3")
                        .frame(width:44,height:44)
                }.accessibilityLabel(showsGrid ? "隐藏格子":"显示格子")
            }.font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal,16).padding(.top,8).background(AppTheme.background).disabled(!gridReady)
    }

    @ViewBuilder private var inspector:some View {
        if mode == .build {
            HouseBuildPanel(draft:$draftRoom,roomCount:house.layout.rooms.count,issue:draftIssue,
                isExisting:draftRoom.map { draft in house.layout.rooms.contains {$0.id == draft.id} } ?? false,
                onNew:{draftRoom=house.suggestedRoom();notice=nil},onSave:saveRoom,onDelete:deleteRoom)
        } else if let item=selectedContainer {
            FurnitureInspector(container:item,onAction:{perform($0,on:item)},onClose:{selectedContainerID=nil},
                failureMessage:{notice ?? "没有保存成功，请再试一次。"})
                .id(item.id)
        } else if let item=selectedDecoration {
            DecorationInspector(decoration:item,roomStyle:currentRoomImage,
                onAction:{performDecoration($0,id:item.id)},onClose:{selectedDecorationID=nil}).id(item.id)
        } else { drawer }
    }

    private var canvas:some View {
        GeometryReader { geometry in
            let fit=min(geometry.size.width/800,geometry.size.height/800)*0.96
            let factor=max(0.01,fit*scale)
            scene(factor:factor)
                .frame(width:800,height:800)
                .scaleEffect(factor)
                .position(x:geometry.size.width/2+offset.width,y:geometry.size.height/2+offset.height)
        }
        .contentShape(Rectangle())
        .gesture(SimultaneousGesture(
            DragGesture(minimumDistance:12)
                .onChanged { value in
                    guard !isMovingObject else { return }
                    offset = .init(width:lastOffset.width+value.translation.width,height:lastOffset.height+value.translation.height)
                }
                .onEnded { _ in
                    guard !isMovingObject else { return }
                    lastOffset=offset
                    storedOffsetX=offset.width;storedOffsetY=offset.height
                },
            MagnificationGesture()
                .onChanged { value in
                    guard !isMovingObject else { return }
                    scale=min(max(lastScale*value,RoomConfig.zoomRange.lowerBound),RoomConfig.zoomRange.upperBound)
                }.onEnded { _ in lastScale=scale;storedScale=scale }
        ))
    }
    private var isMovingObject:Bool { draggingContainerID != nil || draggingDecorationID != nil || isDraggingRoom }

    private func scene(factor:Double) -> some View {
        let m=metrics
        return ZStack {
            HouseSceneView(layout:house.layout,metrics:m,style:currentRoomImage,occupants:occupants).zIndex(-1000)
            if isEditing && showsGrid {
                HouseCellsShape(cells:gridCells,metrics:m).stroke(AppTheme.onAccent.opacity(0.18),lineWidth:0.8)
                    .allowsHitTesting(false).zIndex(-870)
                HouseCellsShape(cells:house.layout.passageCells,metrics:m).fill(Color.white.opacity(0.25))
                    .allowsHitTesting(false).zIndex(-860)
            }
            ZStack {
                ForEach(containers.filter {$0.isPlaced && $0.usesGridPlacement}) { item in
                    let id=styleID(item),model=HouseFurnitureCatalog.furniture(id,mirrored:item.isMirrored)
                    let cell=furnitureCell(item),origin=model.origin(at:cell,wall:HouseFurnitureCatalog.layer(for:id) == .wall)
                    HouseSpriteShadow(shadow:HouseFurnitureCatalog.shadow(id:id,mirrored:item.isMirrored),origin:origin,metrics:m)
                }
                ForEach(decorations.decorations.filter {$0.isPlaced && $0.gridX != nil}) { item in
                    let model=HouseFurnitureCatalog.decoration(item.kind,mirrored:item.isMirrored)
                    HouseSpriteShadow(shadow:HouseFurnitureCatalog.shadow(kind:item.kind,style:currentRoomImage,mirrored:item.isMirrored),
                        origin:model.origin(at:decorationCell(item),wall:item.kind.isWallMounted),metrics:m)
                }
            }.frame(width:800,height:800).clipShape(HouseGroundMask(metrics:m)).allowsHitTesting(false).zIndex(-880)

            ForEach(containers.filter {$0.isPlaced && $0.usesGridPlacement}) { item in
                furniture(item,metrics:m,factor:factor)
            }
            ForEach(decorations.decorations.filter {$0.isPlaced && $0.gridX != nil}) { item in
                decoration(item,metrics:m,factor:factor)
            }
            if mode == .build && isEditing {
                ForEach(house.layout.rooms) { room in
                    Button { draftRoom=room;notice=nil } label: {
                        ZStack {
                            // 整块房间地板都能点选，房名保持手机上的可读字号。
                            HouseCellsShape(cells:room.cells,metrics:m).fill(Color.clear)
                            Label(room.name,systemImage:room.kind.symbol)
                                .font(.system(size:12/factor,weight:.bold,design:.rounded))
                                .padding(.horizontal,8/factor).padding(.vertical,5/factor)
                                .foregroundStyle(AppTheme.onAccent).background(AppTheme.accent,in:Capsule())
                                .position(m.screen(.init((Double(room.x)+Double(room.width)/2)*HouseGridConfig.tile,
                                                        (Double(room.y)+Double(room.depth)/2)*HouseGridConfig.tile,0)))
                        }.frame(width:800,height:800)
                    }
                    .buttonStyle(.plain)
                    .contentShape(HouseCellsShape(cells:room.cells,metrics:m))
                    .accessibilityLabel("编辑\(room.name)")
                    .zIndex(1800)
                }
                roomDraft(metrics:m,factor:factor)
            }
        }
        .frame(width:800,height:800)
    }

    private var gridCells:Set<HouseCell> {
        if mode == .build || selectedContainer.map({HouseFurnitureCatalog.outdoors(styleID($0))}) == true {
            let m=metrics
            return Set((m.minX..<m.maxX).flatMap { x in (m.minY..<m.maxY).map { HouseCell(x:x,y:$0) } })
        }
        return house.layout.floorCells
    }
    private func styleID(_ item:Container) -> String {
        FurnitureConfig.styleID(name:item.name,icon:item.icon,savedID:item.furnitureImageName)
    }
    private func furnitureCell(_ item:Container) -> HouseCell {
        draggingContainerID == item.id.uuidString ? (candidate ?? .init(x:item.gridX,y:item.gridY)):.init(x:item.gridX,y:item.gridY)
    }
    private func decorationCell(_ item:RoomDecoration) -> HouseCell {
        draggingDecorationID == item.id ? (candidate ?? .init(x:item.gridX ?? 0,y:item.gridY ?? 0)):.init(x:item.gridX ?? 0,y:item.gridY ?? 0)
    }
    private func placementIssue(cell:HouseCell,model:HouseModelMetrics,layer:HousePlacementLayer,id:String,outdoors:Bool=false) -> String? {
        do {
            try HousePlacementRules.validate(cell:cell,footprint:model.footprint,layer:layer,outdoors:outdoors,
                layout:house.layout,occupants:occupants,excluding:id)
            return nil
        } catch { return error.localizedDescription }
    }

    private func furniture(_ item:Container,metrics m:HouseSceneMetrics,factor:Double) -> some View {
        let id=styleID(item),model=HouseFurnitureCatalog.furniture(id,mirrored:item.isMirrored)
        let cell=furnitureCell(item),layer=HouseFurnitureCatalog.layer(for:id)
        let p=m.screen(model.origin(at:cell,wall:layer == .wall))
        let issue=placementIssue(cell:cell,model:model,layer:layer,id:item.id.uuidString,outdoors:HouseFurnitureCatalog.outdoors(id))
        return ZStack {
            if selectedContainerID == item.id.uuidString && isEditing && mode == .furnish {
                HouseCellsShape(cells:model.footprint.cells(at:cell),metrics:m)
                    .fill((issue == nil ? Color.green:Color.red).opacity(0.23)).allowsHitTesting(false)
            }
            FurnitureView(container:item,isSelected:selectedContainerID == item.id.uuidString,renderFactor:m.spriteFactor)
                .position(x:p.x+model.sprite.midX*m.spriteFactor,y:p.y+model.sprite.midY*m.spriteFactor)
                .gesture(isEditing && gridReady && mode == .furnish ? DragGesture(minimumDistance:6)
                    .onChanged { value in
                        selectedContainerID=item.id.uuidString
                        draggingContainerID=item.id.uuidString
                        let delta=m.delta(.init(width:value.translation.width/factor,height:value.translation.height/factor))
                        candidate = .init(x:item.gridX+delta.x,y:item.gridY+delta.y)
                        notice=placementIssue(cell:candidate!,model:model,layer:layer,id:item.id.uuidString,outdoors:HouseFurnitureCatalog.outdoors(id))
                    }.onEnded { _ in
                        if let candidate { _=perform(.move(candidate),on:item) }
                        self.candidate=nil
                        DispatchQueue.main.async { draggingContainerID=nil }
                    }:nil)
                .onTapGesture {
                    selectedContainerID=selectedContainerID == item.id.uuidString ? nil:item.id.uuidString
                    notice=nil
                }
        }
        .frame(width:800,height:800)
        .allowsHitTesting(!isEditing || mode == .furnish)
        .zIndex(Double(cell.x+cell.y+model.footprint.width+model.footprint.depth))
    }

    private func decoration(_ item:RoomDecoration,metrics m:HouseSceneMetrics,factor:Double) -> some View {
        let model=HouseFurnitureCatalog.decoration(item.kind,mirrored:item.isMirrored)
        let cell=decorationCell(item),layer=HouseFurnitureCatalog.layer(for:item.kind)
        let p=m.screen(model.origin(at:cell,wall:item.kind.isWallMounted))
        let issue=placementIssue(cell:cell,model:model,layer:layer,id:item.id)
        return ZStack {
            if selectedDecorationID == item.id && isEditing {
                HouseCellsShape(cells:model.footprint.cells(at:cell),metrics:m)
                    .fill((issue == nil ? Color.green:Color.red).opacity(0.23)).allowsHitTesting(false)
            }
            PixelDecorationView(kind:item.kind,roomStyle:currentRoomImage,mirrored:item.isMirrored,
                                showsOutline:selectedDecorationID == item.id)
                .frame(width:model.sprite.width*m.spriteFactor,height:model.sprite.height*m.spriteFactor)
                .position(x:p.x+model.sprite.midX*m.spriteFactor,y:p.y+model.sprite.midY*m.spriteFactor)
                .gesture(isEditing && gridReady && mode == .furnish ? DragGesture(minimumDistance:6)
                    .onChanged { value in
                        selectedDecorationID=item.id;draggingDecorationID=item.id
                        let delta=m.delta(.init(width:value.translation.width/factor,height:value.translation.height/factor))
                        candidate = .init(x:(item.gridX ?? 0)+delta.x,y:(item.gridY ?? 0)+delta.y)
                        notice=placementIssue(cell:candidate!,model:model,layer:layer,id:item.id)
                    }.onEnded { _ in
                        if let candidate { _=performDecoration(.move(candidate),id:item.id) }
                        self.candidate=nil
                        DispatchQueue.main.async { draggingDecorationID=nil }
                    }:nil)
                .onTapGesture {
                    guard isEditing else { return }
                    selectedDecorationID=selectedDecorationID == item.id ? nil:item.id;notice=nil
                }
        }
        .frame(width:800,height:800)
        .allowsHitTesting(isEditing && mode == .furnish)
        .zIndex(item.kind.isFloorCovering ? -900:Double(cell.x+cell.y+model.footprint.width+model.footprint.depth)+0.1)
    }

    @ViewBuilder private func roomDraft(metrics m:HouseSceneMetrics,factor:Double) -> some View {
        if let room=draftRoom {
            let valid=draftIssue == nil
            HouseCellsShape(cells:room.cells,metrics:m)
                .fill((valid ? Color.green:Color.red).opacity(0.28))
                .overlay { HouseCellsShape(cells:room.cells,metrics:m).stroke(valid ? Color.green:Color.red,lineWidth:2) }
                .contentShape(HouseCellsShape(cells:room.cells,metrics:m))
                .gesture(DragGesture(minimumDistance:6)
                    .onChanged { value in
                        if roomDragOrigin == nil { roomDragOrigin=room.cell }
                        isDraggingRoom=true
                        let delta=m.delta(.init(width:value.translation.width/factor,height:value.translation.height/factor))
                        var changed=room
                        changed.x=(roomDragOrigin?.x ?? room.x)+delta.x
                        changed.y=(roomDragOrigin?.y ?? room.y)+delta.y
                        draftRoom=changed
                    }.onEnded { _ in
                        roomDragOrigin=nil
                        DispatchQueue.main.async { isDraggingRoom=false }
                    })
                .zIndex(1900)
        }
    }

    private var drawer:some View {
        VStack(alignment:.leading,spacing:12) {
            Picker("布置类别",selection:$drawerCategory) {
                ForEach(DrawerCategory.allCases,id:\.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            Text("挑选物品放入空格，也可以拖动屋内物品重新布置。").font(.caption).foregroundStyle(AppTheme.secondaryText)
            ScrollView(.horizontal,showsIndicators:false) {
                HStack(spacing:12) {
                    if drawerCategory == .furniture {
                        tile("添加家具","plus") { showsFurnitureCatalog=true }
                        ForEach(containers.filter {!$0.isPlaced}) { item in
                            Button { placeStored(item) } label: {
                                VStack {
                                    PixelFurnitureView(styleID:styleID(item)).frame(width:70,height:72)
                                    Text(item.name).font(.caption.weight(.bold)).lineLimit(1)
                                }.frame(width:86).padding(8).background(AppTheme.inset,in:RoundedRectangle(cornerRadius:16))
                            }.buttonStyle(.plain)
                        }
                    } else {
                        tile("添加装饰","plus") { showsDecorationCatalog=true }
                        ForEach(decorations.decorations.filter {!$0.isPlaced}) { item in
                            Button { placeStoredDecoration(item) } label: {
                                VStack {
                                    PixelDecorationView(kind:item.kind,roomStyle:currentRoomImage).frame(width:70,height:72)
                                    Text(item.name).font(.caption.weight(.bold))
                                }.frame(width:86).padding(8).background(AppTheme.inset,in:RoundedRectangle(cornerRadius:16))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }.padding(16).foregroundStyle(AppTheme.text)
    }
    private func tile(_ title:String,_ symbol:String,action:@escaping ()->Void) -> some View {
        Button(action:action) {
            VStack {
                Image(systemName:symbol).font(.system(size:26,weight:.bold)).frame(width:70,height:72)
                Text(title).font(.caption.weight(.bold))
            }.frame(width:86).padding(8).background(AppTheme.inset,in:RoundedRectangle(cornerRadius:16))
        }.buttonStyle(.plain)
    }
    private func placeStored(_ item:Container) {
        let id=styleID(item),model=HouseFurnitureCatalog.furniture(id,mirrored:item.isMirrored),room=house.layout.rooms[0]
        guard let cell=HousePlacementRules.nearest(to:.init(x:room.x+1,y:room.y+1),footprint:model.footprint,
            layer:HouseFurnitureCatalog.layer(for:id),outdoors:HouseFurnitureCatalog.outdoors(id),
            layout:house.layout,occupants:occupants) else { notice=HouseRuleError.noSpace.localizedDescription;return }
        _=perform(.place(cell),on:item)
    }
    private func placeStoredDecoration(_ item:RoomDecoration) {
        let model=HouseFurnitureCatalog.decoration(item.kind,mirrored:item.isMirrored),room=house.layout.rooms[0]
        guard let cell=HousePlacementRules.nearest(to:.init(x:room.x+1,y:room.y+1),footprint:model.footprint,
            layer:HouseFurnitureCatalog.layer(for:item.kind),layout:house.layout,occupants:occupants)
        else { notice=HouseRuleError.noSpace.localizedDescription;return }
        _=performDecoration(.place(cell),id:item.id)
    }
    private func addFurniture(_ id:String) -> Bool {
        do {
            let item=try FurniturePlacementRepository.add(styleID:id,among:containers,decorations:decorations.decorations,
                layout:house.layout,in:modelContext)
            selectedContainerID=item.id.uuidString;notice="家具已放进空格。"
            return true
        } catch { notice=error.localizedDescription;return false }
    }
    private func addDecoration(_ kind:RoomDecoration.Kind) -> Bool {
        do {
            selectedDecorationID=try decorations.add(kind:kind,containers:containers,layout:house.layout)
            notice="装饰已放进空格。";return true
        } catch { notice=error.localizedDescription;return false }
    }
    @discardableResult private func perform(_ action:FurniturePlacementRepository.Action,on item:Container) -> Bool {
        do {
            try FurniturePlacementRepository.perform(action,on:item,among:containers,decorations:decorations.decorations,
                layout:house.layout,in:modelContext)
            selectedContainerID=item.isPlaced ? item.id.uuidString:nil
            notice="已保存。";UIImpactFeedbackGenerator(style:.light).impactOccurred()
            return true
        } catch { notice=error.localizedDescription;return false }
    }
    @discardableResult private func performDecoration(_ action:RoomDecorationStore.Action,id:String) -> Bool {
        do {
            try decorations.perform(action,id:id,containers:containers,layout:house.layout)
            selectedDecorationID=decorations.decorations.first {$0.id == id && $0.isPlaced}?.id
            notice="已保存。";return true
        } catch { notice=error.localizedDescription;return false }
    }
    private func saveRoom() {
        guard let room=draftRoom else { return }
        do { try house.save(room,occupants:occupants);draftRoom=nil;notice="房间已保存，相邻门洞已连接。" }
        catch { notice=error.localizedDescription }
    }
    private func deleteRoom() {
        guard let room=draftRoom else { return }
        do { try house.remove(id:room.id,occupants:occupants);draftRoom=nil;notice="房间已拆除。" }
        catch { notice=error.localizedDescription }
    }
    private func prepareHouse() {
        restoreViewport()
        guard house.loadIssue == nil else { notice=house.loadIssue;return }
        guard decorations.loadIssue == nil else { notice=decorations.loadIssue;return }
        do {
            let count=try FurniturePlacementRepository.adoptGrid(among:containers,layout:house.layout,in:modelContext)
                + decorations.adoptGrid(containers:containers,layout:house.layout)
            gridReady=true
            if count > 0 { notice="旧摆放已对齐格子，\(count) 件空间不足的物品放入待布置区。" }
        } catch { notice="格子布局准备未完成：\(error.localizedDescription)" }
    }
    private func resetViewport() {
        scale=1;lastScale=1;offset = .zero;lastOffset = .zero
        storedScale=1;storedOffsetX=0;storedOffsetY=0
    }
    private func restoreViewport() {
        scale=storedScale.isFinite ? min(max(storedScale,RoomConfig.zoomRange.lowerBound),RoomConfig.zoomRange.upperBound):1
        lastScale=scale
        offset = .init(width:storedOffsetX.isFinite ? storedOffsetX:0,height:storedOffsetY.isFinite ? storedOffsetY:0)
        lastOffset=offset
    }
}

/// 家具继续是收纳容器。格子编辑只改变摆放，不改变物品归属或删除容器。
struct FurnitureView:View {
    static let didDropItemsNotification=Notification.Name("didDropItemsNotification")
    let container:Container
    let isSelected:Bool
    var renderFactor:Double? = nil
    @Environment(\.modelContext) private var modelContext
    @State private var isTargeted=false
    @State private var dropError:String?
    var body:some View {
        let id=FurnitureConfig.styleID(name:container.name,icon:container.icon,savedID:container.furnitureImageName)
        let oldSize=FurnitureConfig.displaySize(for:container)
        let model=HouseFurnitureCatalog.furniture(id,mirrored:container.isMirrored)
        let size=renderFactor.map { CGSize(width:model.sprite.width*$0,height:model.sprite.height*$0) } ?? oldSize
        PixelFurnitureView(styleID:id,isMirrored:container.isMirrored,showsOutline:isSelected || isTargeted)
            .frame(width:size.width,height:size.height).contentShape(Rectangle()).accessibilityLabel(container.name)
            .overlay(alignment:.top) {
                if isTargeted {
                    Text("收进 \(container.name)").font(.caption.weight(.bold)).foregroundStyle(.white)
                        .padding(8).background(AppTheme.accentText,in:Capsule()).fixedSize().offset(y:-36)
                }
            }
            .dropDestination(for:String.self) { strings,_ in
                let ids=Set(strings.flatMap {$0.split(separator:",").compactMap {UUID(uuidString:String($0))}})
                guard !ids.isEmpty else { return false }
                do {
                    try modelContext.save()
                    for id in ids {
                        let descriptor=FetchDescriptor<Item>(predicate:#Predicate {$0.id == id})
                        if let item=try modelContext.fetch(descriptor).first { item.container=container;item.updatedDate=Date() }
                    }
                    do { try modelContext.save() } catch { modelContext.rollback();throw error }
                    UIImpactFeedbackGenerator(style:.medium).impactOccurred()
                    NotificationCenter.default.post(name:Self.didDropItemsNotification,object:nil)
                    return true
                } catch { dropError="没有收纳成功，请再试一次。";return false }
            } isTargeted: { isTargeted=$0 }
            .alert("收纳未完成",isPresented:Binding(get:{dropError != nil},set:{if !$0 {dropError=nil}})) {
                Button("知道了",role:.cancel) { dropError=nil }
            } message: { Text(dropError ?? "") }
    }
}

extension Color {
    init(hex:String) {
        let hex=hex.trimmingCharacters(in:CharacterSet.alphanumerics.inverted)
        var value:UInt64=0
        Scanner(string:hex).scanHexInt64(&value)
        let a,r,g,b:UInt64
        switch hex.count {
        case 3: (a,r,g,b)=(255,(value>>8)*17,(value>>4&15)*17,(value&15)*17)
        case 8: (a,r,g,b)=(value>>24,value>>16&255,value>>8&255,value&255)
        default: (a,r,g,b)=(255,value>>16&255,value>>8&255,value&255)
        }
        self.init(.sRGB,red:Double(r)/255,green:Double(g)/255,blue:Double(b)/255,opacity:Double(a)/255)
    }
}
