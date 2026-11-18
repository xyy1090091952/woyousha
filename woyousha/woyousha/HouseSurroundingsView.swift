import SwiftUI
import Observation

nonisolated struct HouseTreeSprite: Sendable {
    let image: CGImage
    let bounds: CGRect
}

/// 多个首页实例共用树图，不因点选家具或拖动而重新生成。
@MainActor @Observable final class HouseSurroundingsAssets {
    static let shared = HouseSurroundingsAssets()
    private(set) var trees: [HouseTreeSprite] = []
    private var loading = false
    func prepare() async {
        guard trees.isEmpty,!loading else { return }
        loading=true
        trees=await Task.detached(priority:.utility) {
            (0..<4).compactMap { seed in
                let mesh=HouseYardScene.treeMesh(seed:seed),scale=2.0
                let projection=IsoProjection(scale:scale,origin:.zero)
                let points=mesh.faces.flatMap(\.points).map(projection.project)
                let rect=CGRect(x:floor(points.map(\.x).min()!)-3,y:floor(points.map(\.y).min()!)-3,
                    width:ceil(points.map(\.x).max()!-points.map(\.x).min()!)+6,
                    height:ceil(points.map(\.y).max()!-points.map(\.y).min()!)+6)
                guard let image=IsoRasterizer.render(mesh,width:Int(rect.width),height:Int(rect.height),
                    projection:.init(scale:scale,origin:.init(x:-rect.minX,y:-rect.minY))) else { return nil }
                return HouseTreeSprite(image:image,bounds:rect)
            }
        }.value
        loading=false
    }
}

/// 外围占满 viewport，和宅地共用世界投影。不会扩大房子图片或改变缩放基准。
struct HouseSurroundingsView: View {
    let metrics: HouseSceneMetrics
    let factor: Double
    let offset: CGSize
    let style: String
    @State private var assets=HouseSurroundingsAssets.shared
    var body: some View {
        Canvas { context,size in
            HouseSurroundingsRenderer.draw(context:&context,size:size,metrics:metrics,factor:factor,
                offset:offset,style:style,trees:assets.trees)
        }
        .allowsHitTesting(false).accessibilityHidden(true)
        .task { await assets.prepare() }
    }
}

nonisolated enum HouseSurroundingsRenderer {
    static let riverDistance = 3.8
    static let riverHalfWidth = 0.85
    static let treeSpacing = 2
    static func riverY(_ x:Double, metrics:HouseSceneMetrics) -> Double {
        Double(metrics.maxY)+riverDistance+sin(x*0.19)*0.55+sin(x*0.47)*0.25
    }
    static func draw(context:inout GraphicsContext,size:CGSize,metrics:HouseSceneMetrics,factor:Double,
                     offset:CGSize,style:String,trees:[HouseTreeSprite]) {
        let tile=HouseGridConfig.tile
        func screen(_ x:Double,_ y:Double,_ z:Double = -6) -> CGPoint {
            let p=metrics.screen(.init(x*tile,y*tile,z))
            return .init(x:(p.x-400)*factor+size.width/2+offset.width,
                         y:(p.y-400)*factor+size.height/2+offset.height)
        }
        func polygon(_ points:[CGPoint]) -> Path {
            var path=Path();path.addLines(points);path.closeSubpath();return path
        }
        let lawn=Color(hex:style == "home2" ? "A3BA7D":"B2C38D")
        context.fill(Path(CGRect(origin:.zero,size:size)),with:.color(lawn))
        let corners=[CGPoint.zero,.init(x:size.width,y:0),.init(x:0,y:size.height),.init(x:size.width,y:size.height)]
            .map { p in metrics.worldPoint(.init(x:(p.x-size.width/2-offset.width)/factor+400,
                                                 y:(p.y-size.height/2-offset.height)/factor+400),z:-6) }
        // 只绘制可见范围，限制工作量；极远平移也会先填草地，不露出白底。
        let lowX=max(-120,min(120,Int(floor(corners.map(\.x).min()!/tile))-6))
        let lowY=max(-120,min(120,Int(floor(corners.map(\.y).min()!/tile))-6))
        let highX=min(lowX+80,Int(ceil(corners.map(\.x).max()!/tile))+6)
        let highY=min(lowY+80,Int(ceil(corners.map(\.y).max()!/tile))+6)
        guard highX>lowX,highY>lowY else { return }
        for y in stride(from:lowY,to:highY,by:2) { for x in stride(from:lowX,to:highX,by:2) {
            let hash=IsoPixelStyle.hash(x,y,67)
            if hash>0.55 {
                context.fill(polygon([screen(Double(x),Double(y)),screen(Double(x+2),Double(y)),
                    screen(Double(x+2),Double(y+2)),screen(Double(x),Double(y+2))]),
                    with:.color((hash>0.8 ? Color(hex:"99B778"):Color(hex:"C0CD98")).opacity(0.28)))
            }
        }}
        // 河流始终位于凸起地块之外，随房型范围调整，贯穿外围世界。
        for x in lowX..<highX {
            let a=Double(x),b=a+1,ya=riverY(a,metrics:metrics),yb=riverY(b,metrics:metrics)
            for (half,color) in [(riverHalfWidth+0.3,Color(hex:"D8CDA6")),(riverHalfWidth,Color(hex:"7DC5C7"))] {
                context.fill(polygon([screen(a,ya-half),screen(b,yb-half),screen(b,yb+half),screen(a,ya+half)]),
                             with:.color(color))
            }
            if x.isMultiple(of:2) {
                var ripple=Path();ripple.move(to:screen(a+0.2,ya));ripple.addLine(to:screen(a+0.7,yb))
                context.stroke(ripple,with:.color(Color(hex:"BEE7DD")),lineWidth:max(0.6,factor))
            }
        }
        let candidates=(lowY..<highY).filter {$0.isMultiple(of:treeSpacing)}.flatMap { y in
            (lowX..<highX).filter {$0.isMultiple(of:treeSpacing)}.compactMap { x -> HouseCell? in
                guard x < metrics.minX-2 || x >= metrics.maxX+2 || y < metrics.minY-2 || y >= metrics.maxY+2,
                      abs(Double(y)-riverY(Double(x),metrics:metrics))>2,
                      IsoPixelStyle.hash(x,y,31)>0.32 else { return nil }
                let p=screen(Double(x)+0.8,Double(y)+0.8),s=metrics.worldFactor*factor
                guard p.x > -20*s,p.x < size.width+20*s,
                      p.y > -10*s,p.y < size.height+55*s else { return nil }
                return .init(x:x,y:y)
            }
        }.sorted {$0.x+$0.y < $1.x+$1.y}
        // 先裁掉屏幕外树木，再限制数量，避免远处树木耗尽预算让可见森林空白。
        let visible=candidates.count<=150 ? candidates:Array(candidates.sorted {
            let a=screen(Double($0.x),Double($0.y)),b=screen(Double($1.x),Double($1.y))
            return hypot(a.x-size.width/2,a.y-size.height/2)<hypot(b.x-size.width/2,b.y-size.height/2)
        }.prefix(150)).sorted {$0.x+$0.y < $1.x+$1.y}
        for cell in visible {
            let p=screen(Double(cell.x)+0.8,Double(cell.y)+0.8)
            let spriteScale=metrics.worldFactor*factor/2
            let shadow=CGRect(x:p.x-9*spriteScale,y:p.y-3*spriteScale,width:26*spriteScale,height:10*spriteScale)
            context.fill(Path(ellipseIn:shadow),with:.color(Color(hex:"4D6E42").opacity(0.13)))
            guard !trees.isEmpty else { continue }
            let seed=Int(IsoPixelStyle.hash(cell.x,cell.y,23)*Double(trees.count))%trees.count
            let tree=trees[seed],rect=tree.bounds
            context.draw(Image(decorative:tree.image,scale:1),in:.init(
                x:p.x+rect.minX*spriteScale,y:p.y+rect.minY*spriteScale,
                width:rect.width*spriteScale,height:rect.height*spriteScale))
        }
    }
}
