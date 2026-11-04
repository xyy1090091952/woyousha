import SwiftUI

@MainActor private enum HouseSceneCache {
    static var images: [String:CGImage] = [:]
    static func key(layout: HouseLayout,metrics:HouseSceneMetrics,style:String,occupants:[HouseOccupant],
                    items:[HouseSceneItem],selectedIDs:Set<String>,preview:HousePlacementPreview?) -> String {
        let rooms=layout.rooms.map {"\($0.id):\($0.kind.rawValue):\($0.x):\($0.y):\($0.width):\($0.depth):\($0.floorFinish?.rawValue ?? ""):\($0.wallFinish?.rawValue ?? "")"}.joined(separator:"|")
        let filled=occupants.map {"\($0.cell.x):\($0.cell.y):\($0.footprint.width):\($0.footprint.depth)"}.sorted().joined(separator:"|")
        let objects=items.map {"\($0.id):\($0.source):\($0.cell.x):\($0.cell.y):\($0.mirrored)"}.joined(separator:"|")
        return style+rooms+filled+objects+selectedIDs.sorted().joined(separator:"|")+(preview?.signature ?? "")
            + "\(metrics.minX),\(metrics.minY),\(metrics.maxX),\(metrics.maxY),\(metrics.height)"
    }
    static func insert(_ image:CGImage,for key:String) {
        if images.count >= 4 { images.removeAll(keepingCapacity:true) }
        images[key]=image
    }
}

struct HouseSceneView: View {
    let layout: HouseLayout
    let metrics: HouseSceneMetrics
    let style: String
    var occupants: [HouseOccupant] = []
    var items: [HouseSceneItem] = []
    var selectedIDs: Set<String> = []
    var preview: HousePlacementPreview? = nil
    @State private var lastImage: CGImage?
    @State private var lastGeometry: String?

    private var geometryKey: String {
        "\(metrics.width),\(metrics.height),\(metrics.projection.origin.x),\(metrics.projection.origin.y)"
    }
    var body: some View {
        let key=HouseSceneCache.key(layout:layout,metrics:metrics,style:style,occupants:occupants,
                                   items:items,selectedIDs:selectedIDs,preview:preview)
        let geometry=geometryKey
        Group {
            if let image=HouseSceneCache.images[key] ?? (lastGeometry == geometry ? lastImage:nil) {
                Image(decorative:image,scale:1).resizable().interpolation(.none)
                    .frame(width:Double(image.width)*metrics.imageFactor,height:Double(image.height)*metrics.imageFactor)
                    .frame(width:HouseGridConfig.canvasSize,height:HouseGridConfig.canvasSize)
            } else {
                Color.clear.frame(width:HouseGridConfig.canvasSize,height:HouseGridConfig.canvasSize)
            }
        }
        .accessibilityHidden(true)
        .task(id:key) {
            if let image=HouseSceneCache.images[key] {
                lastImage=image;lastGeometry=geometry
                return
            }
            let job=HouseSceneRenderer.prepare(layout:layout,metrics:metrics,style:style,occupants:occupants,
                                               items:items,selectedIDs:selectedIDs,preview:preview)
            let worker=Task.detached(priority:.userInitiated) { await HouseSceneRenderService.shared.render(job) }
            let image=await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            // 换格、装修或离开页面会取消上一任务；旧画面不能覆盖最新的选择。
            guard !Task.isCancelled,let image else { return }
            HouseSceneCache.insert(image,for:key)
            lastImage=image;lastGeometry=geometry
        }
    }
}

/// 菱形格子的边界和物品占地，直接由保存用的格子坐标绘制。
struct HouseCellsShape: Shape {
    let cells: Set<HouseCell>
    let metrics: HouseSceneMetrics
    func path(in rect: CGRect) -> Path {
        var path=Path()
        let scale=rect.width/HouseGridConfig.canvasSize,tile=HouseGridConfig.tile
        for cell in cells {
            for (i,p) in [IsoPoint(Double(cell.x)*tile,Double(cell.y)*tile,0.3),
                          .init(Double(cell.x+1)*tile,Double(cell.y)*tile,0.3),
                          .init(Double(cell.x+1)*tile,Double(cell.y+1)*tile,0.3),
                          .init(Double(cell.x)*tile,Double(cell.y+1)*tile,0.3)].enumerated() {
                let s=metrics.screen(p),q=CGPoint(x:rect.minX+s.x*scale,y:rect.minY+s.y*scale)
                if i == 0 { path.move(to:q) } else { path.addLine(to:q) }
            }
            path.closeSubpath()
        }
        return path
    }
}

struct HouseGroundMask: Shape {
    let metrics: HouseSceneMetrics
    func path(in rect: CGRect) -> Path {
        let tile=HouseGridConfig.tile,scale=rect.width/HouseGridConfig.canvasSize
        var path=Path()
        for (i,p) in [IsoPoint(Double(metrics.minX)*tile,Double(metrics.minY)*tile,0),
                      .init(Double(metrics.maxX)*tile,Double(metrics.minY)*tile,0),
                      .init(Double(metrics.maxX)*tile,Double(metrics.maxY)*tile,0),
                      .init(Double(metrics.minX)*tile,Double(metrics.maxY)*tile,0)].enumerated() {
            let s=metrics.screen(p),q=CGPoint(x:rect.minX+s.x*scale,y:rect.minY+s.y*scale)
            if i == 0 { path.move(to:q) } else { path.addLine(to:q) }
        }
        path.closeSubpath()
        return path
    }
}

struct HouseSpriteShadow: View {
    let shadow: PixelArtShadow?
    let origin: IsoPoint
    let metrics: HouseSceneMetrics
    var body: some View {
        if let shadow {
            let p=metrics.screen(origin)
            Image(decorative:shadow.image,scale:1).resizable().interpolation(.none)
                .frame(width:shadow.bounds.width*metrics.spriteFactor,height:shadow.bounds.height*metrics.spriteFactor)
                .position(x:p.x+shadow.bounds.midX*metrics.spriteFactor,y:p.y+shadow.bounds.midY*metrics.spriteFactor)
                .allowsHitTesting(false)
        }
    }
}
