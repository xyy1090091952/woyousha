import Foundation
import CoreGraphics

/// 影子使用独立画布和世界原点。高家具的长投影不会撑大家具图片，也不会被留边裁断。
nonisolated struct PixelArtShadow {
    let image: CGImage
    /// 相对模型原点的像素范围，用于将影子与主体对齐。
    let bounds: CGRect
}

nonisolated enum IsoShadowRenderer {
    static func render(_ mesh: IsoMesh, scale: Double, groundPlane: Double? = nil) -> PixelArtShadow? {
        let points = mesh.faces.flatMap(\.points)
        guard let minimum = points.map(\.z).min() else { return nil }
        let ground = groundPlane ?? minimum
        let projection = IsoProjection(scale:scale,origin:.zero)
        func projected(_ point: IsoPoint) -> CGPoint {
            let height = max(0,point.z-ground)
            return projection.project(.init(point.x+height*IsoPixelStyle.shadowDirectionX,
                                            point.y+height*IsoPixelStyle.shadowDirectionY,ground))
        }
        let silhouettes = mesh.faces.map { $0.points.map(projected) }
        let all = silhouettes.flatMap { $0 }
        guard let left = all.map(\.x).min(),let right = all.map(\.x).max(),
              let top = all.map(\.y).min(),let bottom = all.map(\.y).max() else { return nil }
        let padding = IsoPixelStyle.shadowPadding
        let bounds = CGRect(x:floor(left-padding),y:floor(top-padding),
                            width:ceil(right+padding)-floor(left-padding),
                            height:ceil(bottom+padding)-floor(top-padding))
        let width = Int(bounds.width),height = Int(bounds.height)
        guard width > 0,height > 0 else { return nil }
        var mask = [UInt8](repeating:0,count:width*height)

        func fill(_ polygon: [CGPoint], value: UInt8) {
            guard polygon.count >= 3 else { return }
            let p = polygon.map { CGPoint(x:$0.x-bounds.minX,y:$0.y-bounds.minY) }
            for (ia,ib,ic) in IsoPolygonTriangulator.triangles(p) {
                let a=p[ia],b=p[ib],c=p[ic]
                let denom=(b.y-c.y)*(a.x-c.x)+(c.x-b.x)*(a.y-c.y)
                guard abs(denom)>0.00001 else { continue }
                let x0=max(0,Int(floor(min(a.x,b.x,c.x)))),x1=min(width-1,Int(ceil(max(a.x,b.x,c.x))))
                let y0=max(0,Int(floor(min(a.y,b.y,c.y)))),y1=min(height-1,Int(ceil(max(a.y,b.y,c.y))))
                guard x0<=x1,y0<=y1 else { continue }
                for y in y0...y1 {
                    for x in x0...x1 {
                        let px=Double(x)+0.5,py=Double(y)+0.5
                        let u=((b.y-c.y)*(px-c.x)+(c.x-b.x)*(py-c.y))/denom
                        let v=((c.y-a.y)*(px-c.x)+(a.x-c.x)*(py-c.y))/denom
                        if min(u,v,1-u-v)>=(-0.00001) { mask[y*width+x]=max(mask[y*width+x],value) }
                    }
                }
            }
        }
        for silhouette in silhouettes { fill(silhouette,value:1) }
        // 真实脚底附近的面覆盖更深的接触影，桌子的四条腿不会变成一个圆斑。
        for face in mesh.faces where face.points.allSatisfy({ $0.z <= ground+IsoPixelStyle.contactHeight }) {
            fill(face.points.map { projection.project(.init($0.x,$0.y,ground)) },value:2)
        }
        var pixels = [UInt8](repeating:0,count:width*height*4)
        for y in 1..<(height-1) {
            for x in 1..<(width-1) {
                let i=y*width+x,value=mask[i]
                guard value>0 else { continue }
                let boundary = mask[i-1]==0 || mask[i+1]==0 || mask[i-width]==0 || mask[i+width]==0
                if boundary && IsoPixelStyle.dither(x+Int(bounds.minX),y+Int(bounds.minY)) < IsoPixelStyle.shadowEdgeDither { continue }
                let alpha=value==2 ? IsoPixelStyle.contactOpacity : IsoPixelStyle.shadowOpacity
                let color=IsoPixelStyle.cool
                pixels[i*4]=UInt8((Double((color>>16)&255)*alpha).rounded())
                pixels[i*4+1]=UInt8((Double((color>>8)&255)*alpha).rounded())
                pixels[i*4+2]=UInt8((Double(color&255)*alpha).rounded())
                pixels[i*4+3]=UInt8((255*alpha).rounded())
            }
        }
        guard let image=IsoRasterizer.image(pixels,width:width,height:height) else { return nil }
        return PixelArtShadow(image:image,bounds:bounds)
    }
}
