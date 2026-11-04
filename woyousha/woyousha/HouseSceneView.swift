import SwiftUI

@MainActor private enum HouseSceneCache {
    static var images: [String:CGImage] = [:]
    static func image(layout: HouseLayout,metrics:HouseSceneMetrics,style:String,occupants:[HouseOccupant]) -> CGImage? {
        let rooms=layout.rooms.map {"\($0.id):\($0.kind.rawValue):\($0.x):\($0.y):\($0.width):\($0.depth)"}.joined(separator:"|")
        let filled=occupants.map {"\($0.cell.x):\($0.cell.y):\($0.footprint.width):\($0.footprint.depth)"}.sorted().joined(separator:"|")
        let key=style+rooms+filled+"\(metrics.minX),\(metrics.minY),\(metrics.maxX),\(metrics.maxY)"
        if let image=images[key] { return image }
        let image=HouseSceneRenderer.render(layout:layout,metrics:metrics,style:style,occupants:occupants)
        if images.count >= 6 { images.removeAll(keepingCapacity:true) }
        images[key]=image
        return image
    }
}

struct HouseSceneView: View {
    let layout: HouseLayout
    let metrics: HouseSceneMetrics
    let style: String
    var occupants: [HouseOccupant] = []
    var body: some View {
        if let image=HouseSceneCache.image(layout:layout,metrics:metrics,style:style,occupants:occupants) {
            Image(decorative:image,scale:1).resizable().interpolation(.none)
                .frame(width:Double(image.width)*metrics.imageFactor,height:Double(image.height)*metrics.imageFactor)
                .frame(width:HouseGridConfig.canvasSize,height:HouseGridConfig.canvasSize)
                .accessibilityHidden(true)
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
