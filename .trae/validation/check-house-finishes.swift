import AppKit
import SwiftUI
import SwiftData
import ImageIO

/// 使用内存数据库和独立偏好域，核验家园规则、装修与像素遮挡，不读取用户存档。
@main @MainActor struct HouseFinishesCheck {
    static var count=0
    static let output="/Users/bytedance/Documents/trae_code/PROJECT_woyousha/DesignPreviews/"
    static func check(_ result:Bool,_ message:String) {
        guard result else { fatalError("FAIL: "+message) }
        count += 1
    }
    static func rejected(_ error:HouseRuleError,_ body:() throws -> Void) {
        do { try body();fatalError("应拦截："+error.localizedDescription) }
        catch let actual { check(actual as? HouseRuleError == error,"错误规则："+actual.localizedDescription) }
    }
    static func defaults() -> UserDefaults { UserDefaults(suiteName:"house-finishes-check-"+UUID().uuidString)! }
    static func memory() throws -> ModelContainer {
        try ModelContainer(for:Container.self,Item.self,configurations:ModelConfiguration(isStoredInMemoryOnly:true))
    }
    static func bytes(_ image:CGImage) -> [UInt8] { [UInt8](image.dataProvider!.data! as Data) }
    nonisolated static func renderAndThread(_ job:HouseRenderJob) -> (CGImage?,Bool) {
        // 在线程同步函数里读取线程信息，兼容 Swift 6 的异步检查。
        (job.render(cancellable:true),Thread.isMainThread)
    }
    static func png(_ image:CGImage,_ name:String) {
        let destination=CGImageDestinationCreateWithURL(URL(fileURLWithPath:output+name+".png") as CFURL,
            "public.png" as CFString,1,nil)!
        CGImageDestinationAddImage(destination,image,nil)
        check(CGImageDestinationFinalize(destination),"保存预览："+name)
    }
    static func seed(_ id:String,_ cell:HouseCell,_ context:ModelContext,mirrored:Bool=false) -> Container {
        let config=FurnitureConfig.get(byImageName:id)!
        let metrics=HouseFurnitureCatalog.furniture(id,mirrored:mirrored)
        let item=Container(name:config.name,icon:config.icon,gridX:cell.x,gridY:cell.y,
            gridWidth:metrics.footprint.width,gridDepth:metrics.footprint.depth,isPlaced:true,
            furnitureImageName:id,isMirrored:mirrored)
        item.usesGridPlacement=true
        context.insert(item)
        return item
    }
    static func main() async throws {
        setbuf(stdout,nil)
        _=NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        try rulesAndStorage()
        depthAndSelection()
        try await scenesAndPreviews()
        print("PASS: \(count) 项新规则、装修存档、物品关系、像素遮挡及原生预览核验")
    }
    static func rulesAndStorage() throws {
        let initial=HouseLayout.initial,example=HouseLayout.example
        try initial.validate();try example.validate()
        let unit=HouseFootprint(width:1,depth:1)
        for cell in example.passageCells {
            try HousePlacementRules.validate(cell:cell,footprint:unit,layer:.floor,layout:example,occupants:[])
            check(true,"门洞两侧格子允许摆放")
        }
        let blocked=HouseOccupant(id:"door-block",cell:.init(x:11,y:5),
            footprint:.init(width:1,depth:2),layer:.floor)
        let layoutDefaults=defaults(),store=HouseLayoutStore(storage:layoutDefaults)
        try store.save(example.rooms[1],occupants:[blocked])
        check(store.layout.rooms.count==2,"家具在新门洞旁仍可扩建")
        rejected(.occupied) {
            try HousePlacementRules.validate(cell:blocked.cell,footprint:unit,layer:.floor,layout:example,occupants:[blocked])
        }
        rejected(.outsideRoom) {
            try HousePlacementRules.validate(cell:.init(x:11,y:7),footprint:.init(width:2,depth:1),
                layer:.floor,layout:example,occupants:[])
        }
        try HousePlacementRules.validate(cell:blocked.cell,footprint:unit,layer:.covering,layout:example,occupants:[blocked])
        check(true,"地毯继续可铺在家具下")
        rejected(.roomOverlap) { try store.save(HouseRoom(name:"重叠",kind:.bedroom,x:5,y:5,width:4,depth:4),occupants:[]) }
        rejected(.disconnected) { try store.save(HouseRoom(name:"孤立",kind:.bedroom,x:20,y:20,width:3,depth:3),occupants:[]) }

        // 明确移除 JSON 的新字段，证明历史存档采用默认装修。
        var old=try JSONSerialization.jsonObject(with:JSONEncoder().encode(example)) as! [String:Any]
        var oldRooms=old["rooms"] as! [[String:Any]]
        for i in oldRooms.indices { oldRooms[i].removeValue(forKey:"floorFinish");oldRooms[i].removeValue(forKey:"wallFinish") }
        old["rooms"]=oldRooms
        let decoded=try JSONDecoder().decode(HouseLayout.self,from:JSONSerialization.data(withJSONObject:old))
        check(decoded==example,"缺装修字段的旧房型可读且配色默认")

        let savedBefore=layoutDefaults.data(forKey:"houseLayout.v1")
        var draft:HouseRoom?=store.layout.rooms[0]
        draft?.floorFinish = .walnutWood;draft?.wallFinish = .mistBlue
        try store.check(draft!,occupants:[blocked])
        check(layoutDefaults.data(forKey:"houseLayout.v1")==savedBefore,"预览装修不写正式存档")
        draft=nil
        check(store.layout.rooms[0].floorFinish==nil,"取消草稿保持装修")

        let db=try memory(),context=db.mainContext
        let container=seed("shafa",.init(x:5,y:5),context)
        let owned=Item(name:"沙发里的书",quantity:7,container:container)
        context.insert(owned);try context.save()
        let oldCell=HouseCell(x:container.gridX,y:container.gridY),oldID=container.id
        var living=store.layout.rooms[0]
        living.floorFinish = .paleWood;living.wallFinish = .rose
        let occupants=HouseFurnitureCatalog.occupants(containers:[container],decorations:[])
        try store.save(living,occupants:occupants)
        var bedroom=store.layout.rooms[1]
        bedroom.floorFinish = .sageTile;bedroom.wallFinish = .ivory
        try store.save(bedroom,occupants:occupants)
        let reopened=HouseLayoutStore(storage:layoutDefaults)
        check(reopened.layout==store.layout,"每房装修保存后重读一致")
        check(reopened.layout.rooms[0].floorFinish == .paleWood && reopened.layout.rooms[1].floorFinish == .sageTile,
              "不同房间可保存不同地板")
        check(HouseCell(x:container.gridX,y:container.gridY)==oldCell && container.id==oldID &&
              owned.container?.id==oldID && owned.quantity==7,"装修不改家具位置与物品关系")
        try FurniturePlacementRepository.perform(.store,on:container,among:[container],layout:store.layout,in:context)
        let reloaded=try ModelContext(db).fetch(FetchDescriptor<Container>()).first!
        check(!reloaded.isPlaced && reloaded.items?.first?.quantity==7,"收起家具后物品保留")
        for finish in HouseFloorFinish.allCases {
            var room=living;room.floorFinish=finish
            check(try JSONDecoder().decode(HouseRoom.self,from:JSONEncoder().encode(room))==room,"地板稳定编号可保存")
        }
        for finish in HouseWallFinish.allCases {
            var room=living;room.wallFinish=finish
            check(try JSONDecoder().decode(HouseRoom.self,from:JSONEncoder().encode(room))==room,"墙面稳定编号可保存")
        }
        print("PASS: 过道允许、重叠跨墙拦截、旧 JSON、取消与装修重读、物品保留")
    }
    static func depthAndSelection() {
        let p=IsoProjection(scale:2,origin:.init(x:160,y:100)),w=470,h=330
        var floor=IsoMesh();floor.top(60,0,0,100,90,0xD9C09B,material:.wood)
        floor.faces[0].renderOwner=1
        var wall=IsoMesh();wall.box(100,10,0,1.6,70,32,0xE1BEB2,material:.plaster)
        var back=IsoMesh();back.roundedBox(80,25,0.2,16,25,45,radius:3,color:0x579991)
        for i in back.faces.indices { back.faces[i].renderOwner=2 }
        var front=IsoMesh();front.roundedBox(104,40,0.2,16,25,45,radius:3,color:0xD9954D)
        for i in front.faces.indices { front.faces[i].renderOwner=3 }
        var mesh=floor;mesh.merge(wall);mesh.merge(back);mesh.merge(front)
        let plain=IsoRasterizer.render(mesh,width:w,height:h,projection:p)!
        let selected=IsoRasterizer.render(mesh,width:w,height:h,projection:p,selectedOwners:[2])!
        var reversed=IsoMesh(faces:mesh.faces.reversed())
        check(bytes(plain)==bytes(IsoRasterizer.render(reversed,width:w,height:h,projection:p)!),
              "几何顺序不影响前后遮挡")
        reversed=floor;reversed.merge(wall)
        let onlyWall=IsoRasterizer.render(reversed,width:w,height:h,projection:p)!
        reversed.merge(back)
        let wallAndBack=IsoRasterizer.render(reversed,width:w,height:h,projection:p)!
        let selectedBack=IsoRasterizer.render(reversed,width:w,height:h,projection:p,selectedOwners:[2])!
        reversed=floor;reversed.merge(back);reversed.merge(front)
        let onlyFurniture=IsoRasterizer.render(reversed,width:w,height:h,projection:p)!
        func sample(_ image:CGImage,_ point:IsoPoint) -> [UInt8] {
            let s=p.project(point),index=(Int(s.y)*w+Int(s.x))*4
            return Array(bytes(image)[index..<(index+4)])
        }
        // 同一条视线：墙后的椅子下半截由墙遮住，墙前的椅子可以遮住墙。
        let backPoint=IsoPoint(96,40,8),frontPoint=IsoPoint(120,50,37)
        check(sample(wallAndBack,backPoint)==sample(onlyWall,backPoint),"墙挡住后方家具")
        check(sample(selectedBack,backPoint)==sample(wallAndBack,backPoint),"选中白边不穿过前墙")
        check(sample(plain,frontPoint)==sample(onlyFurniture,frontPoint),"前方家具挡住墙")
        check(sample(selected,.init(90,50,43)) != [0,0,0,0],"墙后家具高出墙的部分仍可见")

        let shadow=IsoShadowRenderer.render(mesh,scale:p.scale,groundPlane:0)
        let shaded=IsoRasterizer.render(mesh,width:w,height:h,projection:p,shadow:shadow,shadowReceivers:[1])!
        check(sample(shaded,backPoint)==sample(plain,backPoint) &&
              sample(shaded,frontPoint)==sample(plain,frontPoint),"投影不涂黑墙体与前方家具")
        check(bytes(shaded) != bytes(plain),"地面确实接收到投影")
        png(selected,"house-wall-depth-check")
        print("PASS: 墙前后、独立于绘制顺序、可见选中边与地面投影")
    }
    static func scenesAndPreviews() async throws {
        var layout=HouseLayout.example
        layout.rooms[0].floorFinish = .paleWood;layout.rooms[0].wallFinish = .rose
        layout.rooms[1].floorFinish = .walnutWood;layout.rooms[1].wallFinish = .mistBlue
        layout.rooms[2].floorFinish = .creamTile;layout.rooms[2].wallFinish = .sage
        layout.rooms[3].floorFinish = .honeyWood;layout.rooms[3].wallFinish = .ivory
        let db=try memory(),context=db.mainContext
        var samples=[Container]()
        for (id,desired) in [("shafa",HouseCell(x:8,y:7)),("coffee-table",.init(x:7,y:9)),
                             ("bijia",.init(x:4,y:4)),("double-bed",.init(x:13,y:4)),
                             ("single-bed",.init(x:13,y:10)),("study-desk",.init(x:5,y:13))] {
            let model=HouseFurnitureCatalog.furniture(id)
            let occupied=HouseFurnitureCatalog.occupants(containers:samples,decorations:[])
            if let cell=HousePlacementRules.nearest(to:desired,footprint:model.footprint,
                layer:HouseFurnitureCatalog.layer(for:id),layout:layout,occupants:occupied) {
                samples.append(seed(id,cell,context))
            }
        }
        try context.save()
        let items=samples.map { HouseSceneItem(id:$0.id.uuidString,source:.furniture($0.furnitureImageName!),
            cell:.init(x:$0.gridX,y:$0.gridY),mirrored:$0.isMirrored) }
        let occupants=HouseFurnitureCatalog.occupants(containers:samples,decorations:[])
        let m=HouseSceneMetrics(layout:layout,occupants:occupants,ceilingHeight:items.map(\.visualHeight).max()!)
        var elapsed=[Double]()
        var expected:CGImage?
        for _ in 0..<3 {
            let start=CFAbsoluteTimeGetCurrent()
            let image=HouseSceneRenderer.render(layout:layout,metrics:m,style:"home1",occupants:occupants,items:items)!
            elapsed.append((CFAbsoluteTimeGetCurrent()-start)*1000)
            if elapsed.count==1 { png(image,"house-new-finishes-scene");expected=image }
        }
        print("PERF: \(m.width)×\(m.height)，\(items.count) 件家具；全场渲染毫秒：\(elapsed)")
        let prepareStart=CFAbsoluteTimeGetCurrent()
        let job=HouseSceneRenderer.prepare(layout:layout,metrics:m,style:"home1",occupants:occupants,items:items)
        print("PERF: 主线程只准备几何 \((CFAbsoluteTimeGetCurrent()-prepareStart)*1000) ms")
        let background=await Task.detached { renderAndThread(job) }.value
        check(!background.1 && background.0 != nil,"重绘在后台线程执行")
        check(bytes(background.0!)==bytes(expected!),"后台与同步绘图逐像素一致")
        // 该任务继承主线程，创建后立即取消，尚未开始绘图时就应返回 nil。
        let cancelled=Task { job.render(cancellable:true) }
        cancelled.cancel()
        check(await cancelled.value==nil,"取消的旧任务不返回过期画面")
        let flipped=items.map { HouseSceneItem(id:$0.id,source:$0.source,cell:$0.cell,mirrored:!$0.mirrored) }
        for item in flipped {
            let points=item.worldMesh(style:"home1",owner:2).faces.flatMap(\.points)
            let x0=points.map(\.x).min()!,x1=points.map(\.x).max()!
            let y0=points.map(\.y).min()!,y1=points.map(\.y).max()!
            check(x0 >= Double(item.cell.x)*16-0.001 && x1 <= Double(item.cell.x+item.metrics.footprint.width)*16+0.001 &&
                  y0 >= Double(item.cell.y)*16-0.001 && y1 <= Double(item.cell.y+item.metrics.footprint.depth)*16+0.001,
                  "镜像主体仍在同一候选格范围")
        }
        let d=defaults()
        d.set(try JSONEncoder().encode(layout),forKey:"houseLayout.v1")
        d.set(try JSONEncoder().encode([RoomDecoration]()),forKey:"roomDecorationPlacements.v1")
        let house=HouseLayoutStore(storage:d),decor=RoomDecorationStore(storage:d)
        await snapshot(HomeDecorationView(isPreviewMode:true,houseStore:house,decorationStore:decor)
            .modelContainer(db),name:"house-new-finishes-home",width:800,height:720)
        await snapshot(HomeDecorationView(isEditing:true,selectedContainerID:.constant(samples[0].id.uuidString),
            houseStore:house,decorationStore:decor).modelContainer(db),name:"house-new-finishes-editor",height:820)
        await snapshot(HouseFinishPicker(draft:.constant(layout.rooms[0])),name:"house-room-finish-picker",height:690)
        await snapshot(HouseBuildPanel(draft:.constant(layout.rooms[0]),roomCount:4,issue:nil,isExisting:true,
            onNew:{},onSave:{},onDelete:{}),name:"house-room-finish-panel",height:330)
        await snapshot(VStack(spacing:20) {
            StickerDeleteZone(isActive:false)
            StickerDeleteZone(isActive:true)
        }.background(AppTheme.background),name:"sticker-delete-brand-light",height:280)
        await snapshot(VStack(spacing:20) {
            StickerDeleteZone(isActive:false)
            StickerDeleteZone(isActive:true)
        }.background(AppTheme.background),name:"sticker-delete-brand-dark",height:280,scheme:.dark)
    }
    static func pumpInitialLayout() {
        RunLoop.current.run(until:Date().addingTimeInterval(0.02))
    }
    static func snapshot<V:View>(_ view:V,name:String,width:Double=393,height:Double,scheme:ColorScheme = .light) async {
        // 对可交互控件使用实际 NSHostingView；ImageRenderer 不支持部分拖放和输入控件。
        let hosting=NSHostingView(rootView:view.environment(\.colorScheme,scheme))
        let window=NSWindow(contentRect:.init(x:80,y:80,width:width,height:height),
            styleMask:[.titled],backing:.buffered,defer:false)
        window.title="家园 · 原生电脑核验";window.contentView=hosting
        window.makeKeyAndOrderFront(nil)
        pumpInitialLayout()
        // 异步等待，让 SwiftUI 的绘图任务和结果回填有机会在主线程执行。
        try? await Task.sleep(nanoseconds:1_600_000_000)
        hosting.layoutSubtreeIfNeeded()
        let bitmap=hosting.bitmapImageRepForCachingDisplay(in:hosting.bounds)!
        hosting.cacheDisplay(in:hosting.bounds,to:bitmap)
        if name=="house-new-finishes-home" || name=="house-new-finishes-editor" {
            var painted=0
            for y in 0..<20 {
                for x in 0..<20 {
                    let px=Int(Double(bitmap.pixelsWide)*(0.2+Double(x)*0.6/20))
                    let py=Int(Double(bitmap.pixelsHigh)*(0.35+Double(y)*0.3/20))
                    if let color=bitmap.colorAt(x:px,y:py)?.usingColorSpace(.deviceRGB),
                       color.redComponent<0.8 || color.greenComponent<0.8 || color.blueComponent<0.8 { painted += 1 }
                }
            }
            check(painted>20,"后台图已显示，场景不是空白："+name)
        }
        try! bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output+name+".png"))
        check(true,"原生预览："+name)
        window.orderOut(nil)
    }
}
