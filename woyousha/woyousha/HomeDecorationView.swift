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
    @State private var candidateAttachment:HouseSurfaceAttachment?
    @State private var dragOrigin:HouseSceneItem?
    @State private var dragProjection:HouseSceneMetrics?
    @State private var notice:String?
    @State private var draftRoom:HouseRoom?
    @State private var roomDragOrigin:HouseCell?
    @State private var isDraggingRoom=false
    @State private var drawerCategory=DrawerCategory.furniture
    @State private var showsFurnitureCatalog=false
    @State private var showsDecorationCatalog=false
    @State private var gridReady=false
    @State private var targetedContainerID:String?

    private enum Mode:String,CaseIterable { case furnish="布置",build="建房" }
    private enum DrawerCategory:String,CaseIterable { case furniture="容器家具",decorations="装饰家具" }

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
        dragProjection ?? .init(layout:displayLayout,occupants:occupants,showsPlot:isEditing && mode == .build,
              ceilingHeight:sceneItems.map(\.visualHeight).max() ?? HouseGridConfig.wallHeight)
    }
    private var displayLayout:HouseLayout {
        if isEditing,mode == .build,let room=draftRoom,draftIssue == nil { return house.layout.replacing(room) }
        return house.layout
    }
    private var sceneItems:[HouseSceneItem] {
        HouseStackingRules.resolve(baseSnapshots.map { original in
            var item=original
            if item.id == draggingContainerID || item.id == draggingDecorationID {
                item.attachment=candidateAttachment
                if let candidate { item.cell=candidate }
            }
            return item
        })
    }
    private var baseSnapshots:[HouseSceneItem] {
        HouseStackingRules.snapshots(containers:containers,decorations:decorations.decorations)
    }
    private var sceneSelection:Set<String> {
        Set([selectedContainerID,selectedDecorationID,targetedContainerID].compactMap {$0})
    }
    private var placementPreview:HousePlacementPreview? {
        guard isEditing,mode == .furnish,
              let item=sceneItems.first(where:{$0.id == selectedContainerID || $0.id == selectedDecorationID}) else { return nil }
        guard item.attachment == nil else { return nil }
        let outdoors:Bool
        if case .furniture(let id)=item.source { outdoors=HouseFurnitureCatalog.outdoors(id) } else { outdoors=false }
        return .init(cell:item.cell,footprint:item.metrics.footprint,
            isValid:placementIssue(cell:item.cell,model:item.metrics,layer:item.layer,id:item.id,outdoors:outdoors) == nil)
    }
    private var selectedContainer:Container? {
        containers.first {$0.isPlaced && $0.id.uuidString == selectedContainerID}
    }
    private var selectedDecoration:RoomDecoration? {
        decorations.decorations.first {$0.isPlaced && $0.id == selectedDecorationID}
    }
    private var inspectorHeight:CGFloat {
        if mode == .build { return 320 }
        let source:HouseSceneItem.Source?
        if let item=selectedContainer { source = .furniture(styleID(item)) }
        else if let item=selectedDecoration { source = .decoration(item.kind) }
        else { source=nil }
        // 多一行桌面入口时预留高度，小屏仍可滚动，按钮不会被固定面板截掉。
        return source.map { HouseFurnitureAttributes.canSitOnSurface($0) } == true ? 312:242
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
                                .frame(height:inspectorHeight)
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
            HouseCatalogPicker(role:.container,roomStyle:currentRoomImage,
                failureMessage:{notice ?? "没有保存成功，请再试一次。"},onSelect:addCatalogEntry)
                .presentationDetents([.medium,.large])
        }
        .sheet(isPresented:$showsDecorationCatalog) {
            HouseCatalogPicker(role:.decorative,roomStyle:currentRoomImage,
                failureMessage:{notice ?? "没有保存成功，请再试一次。"},onSelect:addCatalogEntry)
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
                failureMessage:{notice ?? "没有保存成功，请再试一次。"},
                surfaceOptions:surfaceOptions(id:item.id.uuidString),supportName:supportName(item.surfaceAttachment),
                onGround:{placeStored(item)})
                .id(item.id)
        } else if let item=selectedDecoration {
            DecorationInspector(decoration:item,roomStyle:currentRoomImage,
                onAction:{performDecoration($0,id:item.id)},onClose:{selectedDecorationID=nil},
                surfaceOptions:surfaceOptions(id:item.id),supportName:supportName(item.surfaceAttachment),
                onGround:{placeStoredDecoration(item)}).id(item.id)
        } else { drawer }
    }

    private var canvas:some View {
        GeometryReader { geometry in
            let fit=min(geometry.size.width/800,geometry.size.height/800)*0.96
            let factor=max(0.01,fit*scale)
            ZStack {
                HouseSurroundingsView(metrics:metrics,factor:factor,offset:offset,style:currentRoomImage)
                scene(factor:factor)
                    .frame(width:800,height:800)
                    .scaleEffect(factor)
                    .position(x:geometry.size.width/2+offset.width,y:geometry.size.height/2+offset.height)
            }
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
        // 整次刷新只解析一份快照，避免每件家具都重复读取整屋数据。
        let m=metrics,items=sceneItems
        let byID=Dictionary(uniqueKeysWithValues:items.map {($0.id,$0)})
        let occupied=items.filter {$0.attachment == nil}.map {
            HouseOccupant(id:$0.id,cell:$0.cell,footprint:$0.metrics.footprint,layer:$0.layer)
        }
        return ZStack {
            HouseSceneView(layout:displayLayout,metrics:m,style:currentRoomImage,occupants:occupied,
                           items:items,selectedIDs:sceneSelection,preview:placementPreview)
                .allowsHitTesting(false).zIndex(-1000)
            if isEditing && showsGrid {
                HouseCellsShape(cells:gridCells,metrics:m).stroke(AppTheme.onAccent.opacity(0.18),lineWidth:0.8)
                    .allowsHitTesting(false).zIndex(-870)
            }

            ForEach(containers.filter {byID[$0.id.uuidString] != nil}) { item in
                if let snapshot=byID[item.id.uuidString] { furniture(item,snapshot:snapshot,metrics:m,factor:factor) }
            }
            ForEach(decorations.decorations.filter {byID[$0.id] != nil}) { item in
                if let snapshot=byID[item.id] { decoration(item,snapshot:snapshot,metrics:m,factor:factor) }
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
    private func placementIssue(cell:HouseCell,model:HouseModelMetrics,layer:HousePlacementLayer,id:String,outdoors:Bool=false) -> String? {
        do {
            try HousePlacementRules.validate(cell:cell,footprint:model.footprint,layer:layer,outdoors:outdoors,
                layout:house.layout,occupants:occupants,excluding:id)
            return nil
        } catch { return error.localizedDescription }
    }

    private func furniture(_ item:Container,snapshot:HouseSceneItem,metrics m:HouseSceneMetrics,factor:Double) -> some View {
        let id=styleID(item),model=HouseFurnitureCatalog.furniture(id,mirrored:item.isMirrored)
        let cell=snapshot.cell
        let p=m.screen(snapshot.worldOrigin)
        return ZStack {
            // 主体由统一深度场景显示；透明交互层继续负责点击、拖动与收纳拖放。
            FurnitureView(container:item,isSelected:selectedContainerID == item.id.uuidString,renderFactor:m.spriteFactor,
                showsBody:false,onTargetChanged:{targeted in
                    if targeted { targetedContainerID=item.id.uuidString }
                    else if targetedContainerID == item.id.uuidString { targetedContainerID=nil }
                })
                .position(x:p.x+model.sprite.midX*m.spriteFactor,y:p.y+model.sprite.midY*m.spriteFactor)
                .gesture(isEditing && gridReady && mode == .furnish ? DragGesture(minimumDistance:6)
                    .onChanged { value in
                        updateDrag(id:item.id.uuidString,translation:value.translation,metrics:m,factor:factor,isFurniture:true)
                    }.onEnded { _ in
                        if let attachment=candidateAttachment { _=perform(.attach(attachment),on:item) }
                        else if let candidate { _=perform(.move(candidate),on:item) }
                        finishDrag()
                    }:nil)
                .onTapGesture {
                    selectedContainerID=selectedContainerID == item.id.uuidString ? nil:item.id.uuidString
                    notice=nil
                }
        }
        .frame(width:800,height:800)
        .allowsHitTesting(!isEditing || mode == .furnish)
        .zIndex(Double(cell.x+cell.y+model.footprint.width+model.footprint.depth)+(snapshot.attachment == nil ? 0:200))
    }

    private func decoration(_ item:RoomDecoration,snapshot:HouseSceneItem,metrics m:HouseSceneMetrics,factor:Double) -> some View {
        let model=HouseFurnitureCatalog.decoration(item.kind,mirrored:item.isMirrored)
        let cell=snapshot.cell
        let p=m.screen(snapshot.worldOrigin)
        return ZStack {
            Color.clear
                .frame(width:model.sprite.width*m.spriteFactor,height:model.sprite.height*m.spriteFactor)
                .contentShape(Rectangle()).accessibilityLabel(item.name)
                .position(x:p.x+model.sprite.midX*m.spriteFactor,y:p.y+model.sprite.midY*m.spriteFactor)
                .gesture(isEditing && gridReady && mode == .furnish ? DragGesture(minimumDistance:6)
                    .onChanged { value in
                        updateDrag(id:item.id,translation:value.translation,metrics:m,factor:factor,isFurniture:false)
                    }.onEnded { _ in
                        if let attachment=candidateAttachment { _=performDecoration(.attach(attachment),id:item.id) }
                        else if let candidate { _=performDecoration(.move(candidate),id:item.id) }
                        finishDrag()
                    }:nil)
                .onTapGesture {
                    guard isEditing else { return }
                    selectedDecorationID=selectedDecorationID == item.id ? nil:item.id;notice=nil
                }
        }
        .frame(width:800,height:800)
        .allowsHitTesting(isEditing && mode == .furnish)
        .zIndex(item.kind.isFloorCovering ? -900:Double(cell.x+cell.y+model.footprint.width+model.footprint.depth) + 0.1 +
            (snapshot.attachment == nil ? 0:200))
    }

    private func updateDrag(id:String,translation:CGSize,metrics:HouseSceneMetrics,factor:Double,isFurniture:Bool) {
        if dragOrigin?.id != id {
            dragOrigin=HouseStackingRules.resolve(baseSnapshots).first {$0.id == id}
            dragProjection=metrics
        }
        guard let start=dragOrigin,let m=dragProjection else { return }
        let size=start.metrics
        let anchor=m.screen(.init(start.worldOrigin.x+size.minimum.x+size.size.x/2,
                                 start.worldOrigin.y+size.minimum.y+size.size.y/2,
                                 start.worldOrigin.z+size.minimum.z))
        let screen=CGPoint(x:anchor.x+translation.width/factor,y:anchor.y+translation.height/factor)
        let attachment=HouseStackingRules.dragAttachment(child:start,screen:screen,metrics:m,among:baseSnapshots)
        let next:HouseCell
        if start.attachment == nil && attachment == nil {
            let delta=m.delta(.init(width:translation.width/factor,height:translation.height/factor))
            next = .init(x:start.cell.x+delta.x,y:start.cell.y+delta.y)
        } else {
            let point=m.worldPoint(screen),tile=HouseGridConfig.tile
            next = .init(x:Int((point.x/tile-Double(size.footprint.width)/2).rounded()),
                         y:Int((point.y/tile-Double(size.footprint.depth)/2).rounded()))
        }
        guard candidate != next || candidateAttachment != attachment ||
            (draggingContainerID != id && draggingDecorationID != id) else { return }
        if isFurniture { selectedContainerID=id;draggingContainerID=id }
        else { selectedDecorationID=id;draggingDecorationID=id }
        candidate=next;candidateAttachment=attachment
        var proposed=start;proposed.cell=next;proposed.attachment=attachment;proposed.resolvedOrigin=nil
        do {
            try HouseStackingRules.validatePlacement(proposed,among:baseSnapshots,layout:house.layout)
            notice=attachment == nil ? nil:"松手放到桌面"
        } catch { notice=error.localizedDescription }
    }

    private func finishDrag() {
        // 同一轮发布完整状态，避免出现一帧回到旧格子再跳到桌面的闪动。
        draggingContainerID=nil;draggingDecorationID=nil
        candidate=nil;candidateAttachment=nil;dragOrigin=nil;dragProjection=nil
    }
    private func surfaceOptions(id:String) -> [HouseSurfaceOption] {
        guard let child=baseSnapshots.first(where:{$0.id == id}) else { return [] }
        return HouseStackingRules.destinations(child:child,among:baseSnapshots).map { attachment in
            .init(attachment:attachment,name:supportName(attachment) ?? "桌面")
        }
    }
    private func supportName(_ attachment:HouseSurfaceAttachment?) -> String? {
        guard let attachment else { return nil }
        return containers.first {$0.id.uuidString == attachment.supportID}?.name
    }
    private func awaitingPlacement(placed:Bool,attachment:HouseSurfaceAttachment?,knownIDs:Set<String>) -> Bool {
        !placed || attachment.map { !knownIDs.contains($0.supportID) } == true
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
        let knownIDs=Set(baseSnapshots.map(\.id))
        return VStack(alignment:.leading,spacing:12) {
            Picker("布置类别",selection:$drawerCategory) {
                ForEach(DrawerCategory.allCases,id:\.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            Text("挑选物品放入空格，也可以拖动屋内物品重新布置。").font(.caption).foregroundStyle(AppTheme.secondaryText)
            ScrollView(.horizontal,showsIndicators:false) {
                HStack(spacing:12) {
                    tile(drawerCategory == .furniture ? "添加容器家具":"添加装饰家具","plus") {
                        if drawerCategory == .furniture { showsFurnitureCatalog=true } else { showsDecorationCatalog=true }
                    }
                        ForEach(containers.filter {
                            $0.furnitureRole == (drawerCategory == .furniture ? .container:.decorative) &&
                            awaitingPlacement(placed:$0.isPlaced,attachment:$0.surfaceAttachment,knownIDs:knownIDs)
                        }) { item in
                            Button { placeStored(item) } label: {
                                VStack {
                                    PixelFurnitureView(styleID:styleID(item)).frame(width:70,height:72)
                                    Text(item.name).font(.caption.weight(.bold)).lineLimit(1)
                                }.frame(width:86).padding(8).background(AppTheme.inset,in:RoundedRectangle(cornerRadius:16))
                            }.buttonStyle(.plain)
                        }
                    if drawerCategory == .decorations {
                        ForEach(decorations.decorations.filter {
                            awaitingPlacement(placed:$0.isPlaced,attachment:$0.surfaceAttachment,knownIDs:knownIDs)
                        }) { item in
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
            layout:house.layout,occupants:occupants,excluding:item.id.uuidString) else { notice=HouseRuleError.noSpace.localizedDescription;return }
        _=perform(.place(cell),on:item)
    }
    private func placeStoredDecoration(_ item:RoomDecoration) {
        let model=HouseFurnitureCatalog.decoration(item.kind,mirrored:item.isMirrored),room=house.layout.rooms[0]
        guard let cell=HousePlacementRules.nearest(to:.init(x:room.x+1,y:room.y+1),footprint:model.footprint,
            layer:HouseFurnitureCatalog.layer(for:item.kind),layout:house.layout,occupants:occupants,excluding:item.id)
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
    private func addCatalogEntry(_ source:HouseSceneItem.Source) -> Bool {
        switch source {
        case .furniture(let id): return addFurniture(id)
        case .decoration(let kind): return addDecoration(kind)
        }
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
            if case .delete=action { selectedContainerID=nil }
            else { selectedContainerID=item.isPlaced ? item.id.uuidString:nil }
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
            try FurniturePlacementRepository.synchronizeDimensions(containers,in:modelContext)
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

/// 透明交互层按中央用途规则接收贴纸；装饰家具只参与布置。
struct FurnitureView:View {
    static let didDropItemsNotification=Notification.Name("didDropItemsNotification")
    let container:Container
    let isSelected:Bool
    var renderFactor:Double? = nil
    var showsBody=true
    var onTargetChanged:(Bool)->Void = {_ in}
    @Environment(\.modelContext) private var modelContext
    @State private var isTargeted=false
    @State private var dropError:String?
    var body:some View {
        let id=FurnitureConfig.styleID(name:container.name,icon:container.icon,savedID:container.furnitureImageName)
        let model=HouseFurnitureCatalog.furniture(id,mirrored:container.isMirrored)
        let size=renderFactor.map { CGSize(width:model.sprite.width*$0,height:model.sprite.height*$0) } ?? FurnitureConfig.displaySize(for:container)
        Group {
            if showsBody { PixelFurnitureView(styleID:id,isMirrored:container.isMirrored,showsOutline:isSelected || isTargeted) }
            else { Color.clear }
        }
            .frame(width:size.width,height:size.height)
            .contentShape(Rectangle()).accessibilityLabel(container.name)
            .overlay(alignment:.top) {
                if isTargeted {
                    Text("收进 \(container.name)").font(.caption.weight(.bold)).foregroundStyle(.white)
                        .padding(8).background(AppTheme.accentText,in:Capsule()).fixedSize().offset(y:-36)
                }
            }
            .dropDestination(for:String.self) { strings,_ in
                let ids=Set(strings.flatMap {$0.split(separator:",").compactMap {UUID(uuidString:String($0))}})
                do {
                    guard try ItemTransferRepository.move(ids:ids,to:container,in:modelContext)>0 else { return false }
                    UIImpactFeedbackGenerator(style:.medium).impactOccurred()
                    NotificationCenter.default.post(name:Self.didDropItemsNotification,object:nil)
                    return true
                } catch { dropError=error.localizedDescription;return false }
            } isTargeted: {
                let accepts=$0 && container.canReceiveItems
                isTargeted=accepts;onTargetChanged(accepts)
            }
            .alert("收纳未完成",isPresented:Binding(get:{dropError != nil},set:{if !$0 {dropError=nil}})) {
                Button("知道了",role:.cancel) { dropError=nil }
            } message: { Text(dropError ?? "") }
    }
}

extension Color {
    nonisolated init(hex:String) {
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
