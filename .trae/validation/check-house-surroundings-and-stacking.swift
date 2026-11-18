import AppKit
import SwiftUI
import SwiftData
import ImageIO
import Metal

/// 单独的电脑核验入口，不加入 App、不连接用户数据库和偏好域。
@main @MainActor struct HouseSurroundingsCheck {
    static var count = 0
    static let output="/Users/bytedance/Documents/trae_code/PROJECT_woyousha/DesignPreviews/"
    static func check(_ condition:Bool,_ message:String) {
        guard condition else { fatalError("FAIL: "+message) }
        count += 1
    }
    static func rejects(_ message:String,_ body:() throws -> Void) {
        do { try body() } catch { check(true,message);return }
        fatalError("FAIL 未拦截："+message)
    }
    static func memory() throws -> ModelContainer {
        try ModelContainer(for:Container.self,Item.self,configurations:ModelConfiguration(isStoredInMemoryOnly:true))
    }
    static func seed(_ id:String,_ cell:HouseCell,_ context:ModelContext) -> Container {
        let config=FurnitureConfig.get(byImageName:id)!,size=HouseFurnitureCatalog.furniture(id).footprint
        let item=Container(name:config.name,icon:config.icon,gridX:cell.x,gridY:cell.y,
            gridWidth:size.width,gridDepth:size.depth,isPlaced:true,furnitureImageName:id)
        item.usesGridPlacement=true;context.insert(item);return item
    }
    static func png(_ image:CGImage,_ name:String) {
        let file=URL(fileURLWithPath:output+name+".png")
        let destination=CGImageDestinationCreateWithURL(file as CFURL,"public.png" as CFString,1,nil)!
        CGImageDestinationAddImage(destination,image,nil)
        check(CGImageDestinationFinalize(destination),"图片保存 "+name)
    }
    static func main() async throws {
        setbuf(stdout,nil)
        _=NSApplication.shared;NSApp.setActivationPolicy(.accessory)
        try storageAndUse()
        try proportions()
        try await stackingAndScenes()
        print("PASS: \(count) 项用途、旧存档、叠放、尺度、缓存和外围原生画面核验")
    }
    static func storageAndUse() throws {
        let db=try memory(),context=db.mainContext
        let sofa=seed("shafa",.init(x:5,y:5),context),box=seed("zhixiang",.init(x:9,y:5),context)
        let old=Item(name:"原沙发里的书",quantity:7,container:sofa),fresh=Item(name:"新贴纸")
        context.insert(old);context.insert(fresh);try context.save()
        check(!sofa.canReceiveItems && sofa.appearsInInventory,"旧沙发仍可查看已有贴纸")
        var oldDraft=ItemDraft(item:old);oldDraft.imageData=Data([1,2,3]);oldDraft.name="旧书改名"
        try ItemRepository.save(oldDraft,editing:old,in:context)
        check(old.container?.id==sofa.id,"编辑旧非容器归属可保存名称")
        var newDraft=ItemDraft();newDraft.name="新物品";newDraft.imageData=Data([1]);newDraft.container=sofa
        rejects("信息编辑入口拒绝装饰归属") { try ItemRepository.save(newDraft,editing:nil,in:context) }
        rejects("装饰家具禁止接收新贴纸") {
            _=try ItemTransferRepository.move(ids:[fresh.id],to:sofa,in:context)
        }
        check(fresh.container == nil && old.container?.id == sofa.id,"拒收保持旧关系")
        check(try ItemTransferRepository.move(ids:[old.id,fresh.id],to:box,in:context)==2,"批量收纳")
        check(!sofa.appearsInInventory && box.items?.count==2,"清空旧家具后从收纳列表隐藏")
        let reloaded=try ModelContext(db).fetch(FetchDescriptor<Item>())
        check(reloaded.allSatisfy {$0.container?.id == box.id},"收纳立即保存并可重读")
        rejects("有贴纸的容器不能变成灯") {
            try FurniturePlacementRepository.perform(.style("beikedeng"),on:box,among:[sofa,box],in:context)
        }
        rejects("容器编辑入口不能绕过用途校验") {
            try ContainerRepository.save(name:box.name,furnitureImage:"shafa",editing:box,in:context)
        }
        _=try ItemTransferRepository.move(ids:[old.id],to:nil,in:context)
        check(old.container == nil && old.quantity==7,"旧物品可移出且数量不丢")
        check(FurnitureConfig.get(byImageName:"fanzhuo")!.role == .decorative,"普通餐桌不收纳")
        check(FurnitureConfig.get(byImageName:"study-desk")!.role == .container,"带抽屉书桌可收纳")
        check(HouseCatalogEntry.entries(role:.container).allSatisfy {
            if case .furniture(let id)=$0.source { return HouseFurnitureAttributes.role(id) == .container }
            return false
        },"容器目录只包含容器")
        let decor=HouseCatalogEntry.entries(role:.decorative)
        check(decor.contains {$0.source == .decoration(.flowers)} &&
              decor.contains {$0.source == .furniture("fanzhuo")},"装饰目录同时包含桌子和花瓶")

        if let legacyPath=CommandLine.arguments.dropFirst().first {
            let upgraded=try ModelContainer(for:Container.self,Item.self,
                configurations:ModelConfiguration(url:URL(fileURLWithPath:legacyPath)))
            let furniture=try upgraded.mainContext.fetch(FetchDescriptor<Container>()).first!
            check(furniture.surfaceSupportID == nil && furniture.surfaceU==0.5 && furniture.surfaceV==0.5,
                "真实旧 SwiftData 自动补叠放默认值")
            check(furniture.items?.first?.quantity==7 && furniture.items?.first?.container?.id==furniture.id,
                "旧数据库轻量迁移保留物品关系")
        }
        let original=RoomDecoration(id:"old-flower",kind:.flowers,posX:0,posY:0)
        var json=try JSONSerialization.jsonObject(with:JSONEncoder().encode(original)) as! [String:Any]
        json.removeValue(forKey:"surfaceAttachment");json.removeValue(forKey:"gridX");json.removeValue(forKey:"gridY")
        let decoded=try JSONDecoder().decode(RoomDecoration.self,from:JSONSerialization.data(withJSONObject:json))
        check(decoded.id == original.id && decoded.surfaceAttachment == nil,"旧装饰 JSON 缺新字段仍可读")
        print("PASS: 收纳用途和旧 SwiftData/JSON 兼容")
    }
    static func proportions() throws {
        for config in FurnitureConfig.all {
            let metrics=HouseFurnitureCatalog.furniture(config.id)
            let actual=PixelArtRenderer.spriteBounds(contentBounds:PixelArtRenderer.furnitureBounds(id:config.id,mirrored:false))
            check(abs(actual.minX-metrics.sprite.minX)<0.001 && abs(actual.minY-metrics.sprite.minY)<0.001 &&
                  actual.size==metrics.sprite.size,"图片透明留边与物理尺寸统一 "+config.name)
            check(metrics.size.x>0 && metrics.size.y>0 && metrics.size.z>0,"模型尺寸有效")
        }
        let flower=HouseFurnitureCatalog.decoration(.flowers),kettle=HouseFurnitureCatalog.furniture("electric-kettle")
        check(flower.size.z < 16 && flower.size.x < 10,"花瓶恢复小摆件比例")
        check(kettle.size.x < 10 && kettle.size.z < 7,"水壶恢复小家电比例")
        check(HouseFurnitureCatalog.furniture("double-bed").size.y==50,"大件床的尺寸保留")
        print("PASS: 全目录物理尺寸与图片 bounds 一致")
    }
    static func stackingAndScenes() async throws {
        let db=try memory(),context=db.mainContext,layout=HouseLayout.initial
        let table=seed("fanzhuo",.init(x:5,y:6),context),desk=seed("study-desk",.init(x:8,y:9),context)
        var furniture=[table,desk]
        let suite=UserDefaults(suiteName:"house-stack-check-"+UUID().uuidString)!
        suite.set(try JSONEncoder().encode([RoomDecoration]()),forKey:"roomDecorationPlacements.v1")
        suite.set(try JSONEncoder().encode(layout),forKey:"houseLayout.v1")
        let decorations=RoomDecorationStore(storage:suite),house=HouseLayoutStore(storage:suite)
        let flowerID=try decorations.add(kind:.flowers,containers:furniture,layout:layout)
        var snapshots=HouseStackingRules.snapshots(containers:furniture,decorations:decorations.decorations)
        let flower=snapshots.first {$0.id==flowerID}!
        guard let attachment=HouseStackingRules.firstFree(child:flower,parentID:table.id.uuidString,among:snapshots) else {
            fatalError("FAIL: 餐桌必须能放一个花瓶")
        }
        try decorations.perform(.attach(attachment),id:flowerID,containers:furniture,layout:layout)
        var reopened=RoomDecorationStore(storage:suite)
        check(reopened.decorations.first!.surfaceAttachment==attachment,"桌面附着保存重读")
        snapshots=HouseStackingRules.snapshots(containers:furniture,decorations:decorations.decorations)
        let child=snapshots.first {$0.id==flowerID}!
        rejects("桌沿越界") { try HouseStackingRules.validate(child:child,
            attachment:.init(supportID:table.id.uuidString,u:0,v:0),among:snapshots) }
        rejects("非法和非有限坐标") { try HouseStackingRules.validate(child:child,
            attachment:.init(supportID:table.id.uuidString,u:.nan,v:0.5),among:snapshots) }
        var duplicate=child;duplicate = .init(id:"second",source:child.source,cell:child.cell,attachment:attachment)
        rejects("摆件不能重叠") { try HouseStackingRules.validate(child:duplicate,attachment:attachment,among:snapshots) }
        rejects("桌子不能放在另一桌子上") { try HouseStackingRules.validate(child:snapshots[1],
            attachment:attachment,among:snapshots) }
        let placed=HouseStackingRules.resolve(snapshots),renderedFlower=placed.first {$0.id==flowerID}!
        let parent=placed.first {$0.id==table.id.uuidString}!
        let expectedZ=parent.worldOrigin.z+HouseFurnitureAttributes.surface(parent.source)!.height+0.04
        check(abs(renderedFlower.worldOrigin.z+renderedFlower.metrics.minimum.z-expectedZ)<0.001,"花瓶底部贴在真实桌面")
        let firstOrigin=renderedFlower.worldOrigin
        let oldOccupants=HouseFurnitureCatalog.occupants(containers:furniture,decorations:decorations.decorations)
        check(!oldOccupants.contains {$0.id==flowerID},"桌面花瓶不占地面格")
        try FurniturePlacementRepository.perform(.move(.init(x:6,y:6)),on:table,among:furniture,
            decorations:decorations.decorations,layout:layout,in:context)
        let moved=HouseStackingRules.resolve(HouseStackingRules.snapshots(containers:furniture,decorations:decorations.decorations))
            .first {$0.id==flowerID}!
        check(abs(moved.worldOrigin.x-firstOrigin.x-HouseGridConfig.tile)<0.001,"移动桌子带动花瓶")
        check(moved.attachment==attachment,"移动桌子不改相对位置")
        rejects("转向挤到内置书本时拒绝保存") {
            try FurniturePlacementRepository.perform(.mirror,on:table,among:furniture,
                decorations:decorations.decorations,layout:layout,in:context)
        }
        check(!table.isMirrored,"转向失败保持桌子原状态")
        try FurniturePlacementRepository.perform(.store,on:table,among:furniture,
            decorations:decorations.decorations,layout:layout,in:context)
        check(!HouseStackingRules.resolve(HouseStackingRules.snapshots(containers:furniture,decorations:decorations.decorations))
            .contains {$0.id==flowerID},"收起桌子组合隐藏")
        check(decorations.decorations.first!.isPlaced && decorations.decorations.first!.surfaceAttachment==attachment,
            "隐藏不删除摆件")
        try FurniturePlacementRepository.perform(.place(.init(x:5,y:5)),on:table,among:furniture,
            decorations:decorations.decorations,layout:layout,in:context)
        snapshots=HouseStackingRules.snapshots(containers:furniture,decorations:decorations.decorations)
        check(HouseStackingRules.resolve(snapshots).contains {$0.id==flowerID},"放回桌子摆件恢复")
        let m=HouseSceneMetrics(layout:layout)
        let onTable=HouseStackingRules.resolve(snapshots).first {$0.id==flowerID}!
        let center=m.screen(.init(onTable.worldOrigin.x+onTable.metrics.minimum.x+onTable.metrics.size.x/2,
                                  onTable.worldOrigin.y+onTable.metrics.minimum.y+onTable.metrics.size.y/2,expectedZ))
        let drag=HouseStackingRules.dragAttachment(child:child,screen:center,metrics:m,among:snapshots)
        check(drag?.supportID==table.id.uuidString,"拖动按桌高逆投影找到支撑")
        let probe=IsoPoint(130,172,26),roundTrip=m.worldPoint(m.screen(probe),z:26)
        check(abs(roundTrip.x-probe.x)<0.001 && abs(roundTrip.y-probe.y)<0.001,"投影与逆投影一致")
        var signatureProbe=onTable
        signatureProbe.resolvedOrigin=onTable.worldOrigin.offset(.init(1,0,0))
        check(signatureProbe.renderSignature != onTable.renderSignature,"桌内微调会失效缓存")

        let kettle=seed("electric-kettle",.init(x:4,y:10),context)
        furniture.append(kettle)
        snapshots=HouseStackingRules.snapshots(containers:furniture,decorations:decorations.decorations)
        let kettleSnapshot=snapshots.first {$0.id==kettle.id.uuidString}!
        let kettleAttachment=HouseSurfaceAttachment(supportID:desk.id.uuidString,u:0.8,v:0.78)
        try HouseStackingRules.validate(child:kettleSnapshot,attachment:kettleAttachment,among:snapshots)
        try FurniturePlacementRepository.perform(.attach(kettleAttachment),on:kettle,among:furniture,
            decorations:decorations.decorations,layout:layout,in:context)
        let newContext=ModelContext(db),savedKettle=try newContext.fetch(FetchDescriptor<Container>()).first {$0.id==kettle.id}!
        check(savedKettle.surfaceAttachment==kettleAttachment,"家具小家电也持久保存附着")
        let kettleOrigin=HouseStackingRules.resolve(HouseStackingRules.snapshots(containers:furniture,decorations:decorations.decorations))
            .first {$0.id==kettle.id.uuidString}!.worldOrigin
        try FurniturePlacementRepository.perform(.mirror,on:desk,among:furniture,
            decorations:decorations.decorations,layout:layout,in:context)
        check(HouseStackingRules.resolve(HouseStackingRules.snapshots(containers:furniture,decorations:decorations.decorations))
            .first {$0.id==kettle.id.uuidString}!.worldOrigin != kettleOrigin,"可行转向带动桌面小家电")

        let items=HouseStackingRules.resolve(HouseStackingRules.snapshots(containers:furniture,decorations:decorations.decorations))
        let occupants=HouseFurnitureCatalog.occupants(containers:furniture,decorations:decorations.decorations)
        let sceneMetrics=HouseSceneMetrics(layout:layout,occupants:occupants,ceilingHeight:items.map(\.visualHeight).max()!)
        let job=HouseSceneRenderer.prepare(layout:layout,metrics:sceneMetrics,style:"home1",occupants:occupants,items:items)
        let device=MTLCreateSystemDefaultDevice()!
        let shader="/Users/bytedance/Documents/trae_code/PROJECT_woyousha/woyousha/woyousha/HouseShaders.txt"
        let library=try await device.makeLibrary(source:String(contentsOfFile:shader,encoding:.utf8),options:nil)
        let renderer=HouseMetalRenderer(device:device,library:library)!
        let first=renderer.render(job)
        check(first != nil,"真实 GPU 能够渲染叠放")
        png(first!,"house-tabletop-scene")
        var selected=job;selected.selectedOwners=[2]
        var times:[Double]=[]
        for _ in 0..<12 {
            let start=CFAbsoluteTimeGetCurrent(),selectedImage=renderer.render(selected)
            times.append((CFAbsoluteTimeGetCurrent()-start)*1000)
            check(selectedImage != nil,"选中仍能复用 GPU")
        }
        print("PERF: 叠放场景选中刷新平均 \(times.reduce(0,+)/Double(times.count)) ms，最高 \(times.max()!) ms")
        await snapshot(HomeDecorationView(isPreviewMode:true,houseStore:house,decorationStore:decorations).modelContainer(db),
            name:"house-outside-landscape",width:800,height:720)
        await snapshot(HomeDecorationView(isEditing:true,selectedContainerID:.constant(kettle.id.uuidString),
            houseStore:house,decorationStore:decorations).modelContainer(db),name:"house-tabletop-editor",width:393,height:850)
        await snapshot(HouseCatalogPicker(role:.container){_ in true},name:"house-container-furniture-catalog",width:393,height:740)
        await snapshot(HouseCatalogPicker(role:.decorative){_ in true},name:"house-decorative-furniture-catalog",width:393,height:740)
        try FurniturePlacementRepository.perform(.delete,on:table,among:furniture,
            decorations:decorations.decorations,layout:layout,in:context)
        furniture.removeAll {$0.id==table.id}
        reopened=RoomDecorationStore(storage:suite)
        check(reopened.decorations.contains {$0.id==flowerID},"删除父家具不删除花瓶")
        check(!HouseStackingRules.resolve(HouseStackingRules.snapshots(containers:furniture,decorations:reopened.decorations))
            .contains {$0.id==flowerID},"失去支撑摆件进入待布置")
        try reopened.perform(.place(.init(x:4,y:5)),id:flowerID,containers:furniture,layout:layout)
        check(reopened.decorations.first!.surfaceAttachment == nil,"待布置花瓶能放回地面")
        print("PASS: 桌沿/重叠/非法支撑、父移动/转向/收起/放回/删除、两种存储重读")
    }
    static func pump() { RunLoop.current.run(until:Date().addingTimeInterval(0.02)) }
    static func snapshot<V:View>(_ view:V,name:String,width:Double,height:Double) async {
        let hosting=NSHostingView(rootView:view.environment(\.colorScheme,.light))
        let window=NSWindow(contentRect:.init(x:80,y:80,width:width,height:height),
            styleMask:[.titled],backing:.buffered,defer:false)
        window.title="家园外围与叠放核验";window.contentView=hosting;window.makeKeyAndOrderFront(nil);pump()
        try? await Task.sleep(for:.seconds(1.5))
        hosting.layoutSubtreeIfNeeded()
        let bitmap=hosting.bitmapImageRepForCachingDisplay(in:hosting.bounds)!
        hosting.cacheDisplay(in:hosting.bounds,to:bitmap)
        try! bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output+name+".png"))
        if name=="house-outside-landscape" {
            let coordinates=[(0.02,0.02),(0.98,0.02),(0.02,0.98),(0.98,0.98)]
            for (x,y) in coordinates {
                let color=bitmap.colorAt(x:Int(x*Double(bitmap.pixelsWide)),y:Int(y*Double(bitmap.pixelsHigh)))!
                    .usingColorSpace(.deviceRGB)!
                check(color.greenComponent>color.blueComponent+0.05,"viewport 四角是外围草地或森林")
            }
        }
        check(true,"原生预览 "+name);window.orderOut(nil)
    }
}
