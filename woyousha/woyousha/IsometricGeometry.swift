import Foundation
import CoreGraphics

/// 所有房间和家具共用 2:1 等轴投影：两条水平轴分别向左下、右下倾斜。
/// z 表示高度。这里仅计算 2D 像素，不依赖 3D 引擎或 WebView。
nonisolated struct IsoPoint: Sendable {
    var x: Double
    var y: Double
    var z: Double
    init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
    func offset(_ p: IsoPoint) -> IsoPoint { IsoPoint(x+p.x, y+p.y, z+p.z) }
}

nonisolated struct IsoProjection: Sendable {
    let scale: Double
    let origin: CGPoint

    func project(_ p: IsoPoint) -> CGPoint {
        CGPoint(x: origin.x + (p.x-p.y)*scale, y: origin.y + ((p.x+p.y)*0.5-p.z)*scale)
    }
    // 沿视线靠近观察者的距离，用于遮挡。它与投影的观察方向严格一致。
    func depth(_ p: IsoPoint) -> Double { p.x+p.y+p.z }
}

nonisolated enum IsoColor {
    static func shade(_ color: UInt32, _ factor: Double) -> UInt32 {
        func channel(_ shift: Int) -> UInt32 {
            UInt32(min(255, max(0, (Double((color >> shift) & 255)*factor).rounded())))
        }
        return channel(16)<<16 | channel(8)<<8 | channel(0)
    }
}

nonisolated struct IsoFace: Sendable {
    var points: [IsoPoint]
    let color: UInt32
    let outline: UInt32?
    var material: IsoMaterial = .automatic
    /// 仅用于场景底座消融；家具主体始终保持完整轮廓。
    var dissolvesBelow: Double? = nil
    /// 场景里的物体编号，用于统一遮挡、地面投影和只沿可见主体绘制选中边。
    var renderOwner: Int = 0

    var normal: IsoPoint {
        guard points.count >= 3 else { return .init(0, 0, 1) }
        let a = points[0]
        for i in 1..<(points.count - 1) {
            let b = points[i], c = points[i + 1]
            let ux = b.x-a.x, uy = b.y-a.y, uz = b.z-a.z
            let vx = c.x-a.x, vy = c.y-a.y, vz = c.z-a.z
            let nx = uy*vz-uz*vy, ny = uz*vx-ux*vz, nz = ux*vy-uy*vx
            let length = sqrt(nx*nx+ny*ny+nz*nz)
            guard length > 0.00001 else { continue }
            // 各旧模型的顶点绕行方向不同，统一朝向观察者后再计算受光。
            let sign = nx+ny+nz < 0 ? -1.0 : 1.0
            return .init(nx/length*sign, ny/length*sign, nz/length*sign)
        }
        return .init(0, 0, 1)
    }
}

nonisolated struct IsoMesh: Sendable {
    var faces: [IsoFace] = []

    mutating func face(_ points: [IsoPoint], _ color: UInt32, outline: UInt32? = nil,
                       material: IsoMaterial = .automatic) {
        faces.append(IsoFace(points: points, color: color, outline: outline, material: material))
    }

    /// 三个可见面使用统一光照。每一条边都由真实长宽高投影，不再画“正面矩形”。
    mutating func box(_ x: Double, _ y: Double, _ z: Double, _ w: Double, _ d: Double, _ h: Double,
                      _ color: UInt32, outlined: Bool = true, material: IsoMaterial = .automatic) {
        let edge = outlined ? IsoColor.shade(color, 0.53) : nil
        face([.init(x,y+d,z),.init(x+w,y+d,z),.init(x+w,y+d,z+h),.init(x,y+d,z+h)],
             color,outline:edge,material:material)
        face([.init(x+w,y,z),.init(x+w,y+d,z),.init(x+w,y+d,z+h),.init(x+w,y,z+h)],
             color,outline:edge,material:material)
        face([.init(x,y,z+h),.init(x+w,y,z+h),.init(x+w,y+d,z+h),.init(x,y+d,z+h)],
             color,outline:edge,material:material)
    }

    // 面上细节同样用世界坐标：门缝、书脊、玻璃高光不会偏离家具方向。
    mutating func front(_ x: Double, _ y: Double, _ z: Double, _ w: Double, _ h: Double, _ color: UInt32) {
        face([.init(x,y,z),.init(x+w,y,z),.init(x+w,y,z+h),.init(x,y,z+h)],color)
    }
    mutating func side(_ x: Double, _ y: Double, _ z: Double, _ d: Double, _ h: Double, _ color: UInt32) {
        face([.init(x,y,z),.init(x,y+d,z),.init(x,y+d,z+h),.init(x,y,z+h)],color)
    }
    mutating func top(_ x: Double, _ y: Double, _ z: Double, _ w: Double, _ d: Double, _ color: UInt32,
                      material: IsoMaterial = .automatic) {
        face([.init(x,y,z),.init(x+w,y,z),.init(x+w,y+d,z),.init(x,y+d,z)],color,material:material)
    }

    /// 像素风软体边缘：倒角立方体用于坐垫、包体，不用普通方块冒充所有家具。
    mutating func beveledBox(_ x: Double, _ y: Double, _ z: Double, _ w: Double, _ d: Double, _ h: Double,
                             bevel: Double, color: UInt32) {
        let b = min(bevel, min(w,d,h) * 0.35)
        func ring(_ inset: Double, _ height: Double) -> [IsoPoint] {
            let cut = max(0.3, b - inset)
            return [
                .init(x+inset+cut,y+inset,height), .init(x+w-inset-cut,y+inset,height),
                .init(x+w-inset,y+inset+cut,height), .init(x+w-inset,y+d-inset-cut,height),
                .init(x+w-inset-cut,y+d-inset,height), .init(x+inset+cut,y+d-inset,height),
                .init(x+inset,y+d-inset-cut,height), .init(x+inset,y+inset+cut,height)
            ]
        }
        let rings = [ring(b*0.55,z), ring(0,z+b), ring(0,z+h-b), ring(b*0.55,z+h)]
        for level in 0..<3 {
            for i in 0..<8 {
                let j = (i+1)%8
                face([rings[level][i],rings[level][j],rings[level+1][j],rings[level+1][i]],
                     color)
            }
        }
        face(rings[3],color,outline:IsoColor.shade(color,0.7))
    }

    /// 圆润的玩具家具：横向圆角和上下软边分开控制，最终仍输出清晰像素边缘。
    mutating func roundedBox(_ x: Double, _ y: Double, _ z: Double, _ w: Double, _ d: Double, _ h: Double,
                             radius: Double, color: UInt32) {
        let r = min(radius, min(w,d)*0.45)
        let soft = min(r, h*0.45)
        let heights = [z,z+soft*0.25,z+soft*0.65,z+soft,z+h-soft,z+h-soft*0.65,z+h-soft*0.25,z+h]
        let insets = [soft*0.65,soft*0.25,soft*0.06,0,0,soft*0.06,soft*0.25,soft*0.65]
        var rings: [[IsoPoint]] = []
        for (height, inset) in zip(heights,insets) {
            let corner = max(0.1,r-inset)
            let centers = [(x+w-inset-corner,y+inset+corner),
                           (x+w-inset-corner,y+d-inset-corner),
                           (x+inset+corner,y+d-inset-corner),
                           (x+inset+corner,y+inset+corner)]
            var ring: [IsoPoint] = []
            for i in 0..<4 {
                for step in 0...4 {
                    let a = (-Double.pi/2)+Double(i)*(.pi/2)+Double(step)*(.pi/8)
                    ring.append(.init(centers[i].0+cos(a)*corner,centers[i].1+sin(a)*corner,height))
                }
            }
            rings.append(ring)
        }
        for level in 0..<(rings.count-1) {
            for i in rings[level].indices {
                let j = (i+1)%rings[level].count
                let a = rings[level][i], b = rings[level][j]
                face([a,b,rings[level+1][j],rings[level+1][i]],color)
            }
        }
        face(rings.last!,color)
    }

    /// 多边形圆台：杯子、垃圾桶、灯座和植物叶片共用，所有曲线最后仍栅格化为像素。
    mutating func cylinder(_ x: Double, _ y: Double, _ z: Double, radius: Double, height: Double,
                           color: UInt32, topRadius: Double? = nil, sides: Int = 12) {
        let upper = topRadius ?? radius
        var bottom: [IsoPoint] = [], top: [IsoPoint] = []
        for i in 0..<sides {
            let a = Double(i)*2 * .pi / Double(sides)
            bottom.append(.init(x+cos(a)*radius,y+sin(a)*radius,z))
            top.append(.init(x+cos(a)*upper,y+sin(a)*upper,z+height))
        }
        for i in 0..<sides {
            let j = (i+1)%sides
            face([bottom[i],bottom[j],top[j],top[i]],color)
        }
        face(top,color,outline:IsoColor.shade(color,0.6))
    }

    /// 沿 y 轴挤出的轮廓，用于贝壳灯、软靠背等有明确剪影的造型。
    mutating func profile(_ points: [(Double,Double)], y: Double, depth: Double, color: UInt32) {
        let front = points.map { IsoPoint($0.0,y+depth,$0.1) }
        let back = points.map { IsoPoint($0.0,y,$0.1) }
        face(front,color,outline:IsoColor.shade(color,0.6))
        for i in points.indices {
            let j = (i+1)%points.count
            face([back[i],back[j],front[j],front[i]],color)
        }
    }
    /// 沿 x 轴挤出 y/z 侧轮廓，给斜靠背、脚托、摇椅底架真实厚度。
    mutating func sideProfile(_ points: [(Double,Double)], x: Double, width: Double, color: UInt32) {
        let left = points.map { IsoPoint(x,$0.0,$0.1) }
        let right = points.map { IsoPoint(x+width,$0.0,$0.1) }
        face(left,color)
        face(right,color)
        for i in points.indices {
            let j = (i+1)%points.count
            face([left[i],left[j],right[j],right[i]],color)
        }
    }
    mutating func merge(_ other: IsoMesh, at position: IsoPoint = .init(0,0,0)) {
        for var face in other.faces {
            face.points = face.points.map { $0.offset(position) }
            if let fade = face.dissolvesBelow { face.dissolvesBelow = fade + position.z }
            faces.append(face)
        }
    }

    func exchangingAxes() -> IsoMesh {
        IsoMesh(faces: faces.map {
            var face = $0
            // 镜像后重新按面朝向受光，材质本色保持不变。
            face.points = face.points.map { .init($0.y,$0.x,$0.z) }
            return face
        })
    }
}

/// 软件像素画布。深度缓冲只负责 2D 多边形的遮挡，避免书架隔板/沙发扶手穿透。
/// 小尺寸图片由调用方缓存；家园格子、装修或选择状态变化时重新合成深度图。
/// 世界坐标纹理 → 五档色阶 → 深度遮挡与边缘光；不再对所有材质统一撒噪点。
nonisolated enum IsoRasterizer {
    static func render(_ mesh: IsoMesh, width: Int, height: Int, projection: IsoProjection,
                       selectedOwners: Set<Int> = [], shadow: PixelArtShadow? = nil,
                       shadowReceivers: Set<Int> = [], cancellable: Bool = false) -> CGImage? {
        if cancellable && Task.isCancelled { return nil }
        let count = width*height
        var colors = [UInt32](repeating: 0, count: count)
        var depths = [Double](repeating: -.infinity, count: count)
        var slopesX = [Double](repeating: 0, count: count)
        var slopesY = [Double](repeating: 0, count: count)
        var owners = [Int](repeating: 0, count: count)

        func write(_ x: Int, _ y: Int, _ depth: Double, _ color: UInt32, dx: Double, dy: Double, owner: Int) {
            guard x >= 0, y >= 0, x < width, y < height else { return }
            let index = y*width+x
            guard depth >= depths[index]-0.00001 else { return }
            depths[index] = depth
            colors[index] = color
            slopesX[index] = dx
            slopesY[index] = dy
            owners[index] = owner
        }

        for face in mesh.faces {
            if cancellable && Task.isCancelled { return nil }
            let p = face.points.map(projection.project)
            let d = face.points.map(projection.depth)
            guard p.count >= 3 else { continue }
            let normal = face.normal
            let material = face.material == .automatic ? IsoMaterial.inferred(from: face.color) : face.material
            let base = IsoPixelStyle.lighting(normal)
                + (material == .plaster ? (1-abs(normal.z))*IsoPixelStyle.plasterLightLift : 0)
            // 受光决定整块面的明暗；抖动只在材质的相近色之间变化。
            let treatment = IsoPixelStyle.surfaceTreatment(material)
            let litColor = IsoPixelStyle.ramp(face.color)[IsoPixelStyle.shadeIndex(base)]
            let ramp = IsoPixelStyle.surfaceRamp(litColor,treatment:treatment)
            let seed = face.color & 0xFFFFFF
            let floorZ = face.points.map(\.z).min() ?? 0
            let xs = face.points.map(\.x), ys = face.points.map(\.y)
            let grainAlongX = (xs.max()! - xs.min()!) >= (ys.max()! - ys.min()!)
            for (ia,ib,ic) in IsoPolygonTriangulator.triangles(p) {
                let a=p[ia], b=p[ib], c=p[ic]
                let denominator=(b.y-c.y)*(a.x-c.x)+(c.x-b.x)*(a.y-c.y)
                guard abs(denominator)>0.00001 else { continue }
                let dx = ((b.y-c.y)*(d[ia]-d[ic])+(c.y-a.y)*(d[ib]-d[ic]))/denominator
                let dy = ((c.x-b.x)*(d[ia]-d[ic])+(a.x-c.x)*(d[ib]-d[ic]))/denominator
                let x0=max(0,Int(floor(min(a.x,b.x,c.x))))
                let x1=min(width-1,Int(ceil(max(a.x,b.x,c.x))))
                let y0=max(0,Int(floor(min(a.y,b.y,c.y))))
                let y1=min(height-1,Int(ceil(max(a.y,b.y,c.y))))
                guard x0<=x1, y0<=y1 else { continue }
                for y in y0...y1 {
                    if cancellable && Task.isCancelled { return nil }
                    for x in x0...x1 {
                        let px=Double(x)+0.5, py=Double(y)+0.5
                        let u=((b.y-c.y)*(px-c.x)+(c.x-b.x)*(py-c.y))/denominator
                        let v=((c.y-a.y)*(px-c.x)+(a.x-c.x)*(py-c.y))/denominator
                        let w=1-u-v
                        if min(u,v,w)>=(-0.00001) {
                            let worldA = face.points[ia], worldB = face.points[ib], worldC = face.points[ic]
                            let wx = u*worldA.x+v*worldB.x+w*worldC.x
                            let wy = u*worldA.y+v*worldB.y+w*worldC.y
                            let wz = u*worldA.z+v*worldB.z+w*worldC.z
                            if let fade = face.dissolvesBelow, wz < fade {
                                let keep = max(0, (wz-floorZ)/max(0.001,fade-floorZ))
                                if IsoPixelStyle.hash(x,y,seed) > keep { continue }
                            }
                            let tu: Double, tv: Double
                            if abs(normal.z) > 0.65 {
                                tu = grainAlongX ? wx : wy
                                tv = grainAlongX ? wy : wx
                            } else {
                                tu = abs(normal.x) > abs(normal.y) ? wy : wx
                                tv = wz
                            }
                            let texture = IsoPixelStyle.texture(treatment,u:tu,v:tv,seed:seed)
                            let tone = texture*Double(ramp.count)+(IsoPixelStyle.dither(x,y)-0.5)*treatment.ditherStrength
                            let level = Int(min(Double(ramp.count-1),max(0,floor(tone))))
                            write(x,y,u*d[ia]+v*d[ib]+w*d[ic],ramp[level],dx:dx,dy:dy,owner:face.renderOwner)
                        }
                    }
                }
            }
            // 不逐个多边形画边框；在完整深度图上处理轮廓，避免圆面出现一圈圈接缝。
        }

        // 凹角染紫，左上遮挡边补暖光；只改物体自己的像素，透明背景不会出现光晕。
        var pixels = [UInt8](repeating: 0, count: count*4)
        for y in 0..<height {
            if cancellable && Task.isCancelled { return nil }
            for x in 0..<width {
                let index = y*width+x
                guard depths[index] > -.infinity else { continue }
                let amount = occlusionAmount(x,y,depths:depths,width:width,height:height,scale:projection.scale)
                let ao = IsoPixelStyle.occlusionTint(amount)
                var color = IsoPixelStyle.mix(colors[index],IsoPixelStyle.cool,ao)
                let neighbors = [(x-1,y,-slopesX[index]),(x,y-1,-slopesY[index]),
                                 (x+1,y,slopesX[index]),(x,y+1,slopesY[index])]
                var boundary = false, rim = false, behind = false
                for (k, neighbor) in neighbors.enumerated() {
                    let (nx,ny,slope) = neighbor
                    guard nx >= 0,ny >= 0,nx < width,ny < height else { boundary = true; continue }
                    let depth = depths[ny*width+nx]
                    if !depth.isFinite { boundary = true; continue }
                    let jump = (depth-depths[index]-slope)*projection.scale
                    if k < 2 && jump < -IsoPixelStyle.depthEdgeThreshold { rim = true }
                    if k >= 2 && jump > IsoPixelStyle.depthEdgeThreshold { behind = true }
                }
                if boundary || behind { color = IsoPixelStyle.mix(color,IsoPixelStyle.cool,IsoPixelStyle.silhouetteTint) }
                else if rim { color = IsoPixelStyle.mix(color,IsoPixelStyle.warm,IsoPixelStyle.rimTint) }
                pixels[index*4] = UInt8((color>>16)&255)
                pixels[index*4+1] = UInt8((color>>8)&255)
                pixels[index*4+2] = UInt8(color&255)
                pixels[index*4+3] = 255
            }
        }
        // 投影只落在深度图里实际露出的地面/地毯上，不盖住前方墙壁和家具。
        if let shadow, let data=shadow.image.dataProvider?.data {
            let bytes=[UInt8](data as Data)
            let offsetX=projection.origin.x+shadow.bounds.minX
            let offsetY=projection.origin.y+shadow.bounds.minY
            for y in 0..<height {
                if cancellable && Task.isCancelled { return nil }
                let sy=Int(floor(Double(y)+0.5-offsetY))
                guard sy >= 0,sy < shadow.image.height else { continue }
                for x in 0..<width {
                    let index=y*width+x
                    guard pixels[index*4+3] != 0,shadowReceivers.contains(owners[index]) else { continue }
                    let sx=Int(floor(Double(x)+0.5-offsetX))
                    guard sx >= 0,sx < shadow.image.width else { continue }
                    let source=(sy*shadow.image.width+sx)*4
                    let alpha=Double(bytes[source+3])/255
                    guard alpha > 0 else { continue }
                    for c in 0..<3 {
                        pixels[index*4+c]=UInt8(min(255,Double(bytes[source+c])+Double(pixels[index*4+c])*(1-alpha)).rounded())
                    }
                }
            }
        }
        if !selectedOwners.isEmpty {
            // 只扩张选中物体的可见像素；前方墙体比轮廓更近时，白边也被墙体挡住。
            let radius=Int(ceil(PixelArtRenderer.selectionOutlineRadius))
            var outline=Set<Int>()
            for y in 0..<height {
                if cancellable && Task.isCancelled { return nil }
                for x in 0..<width {
                    let source=y*width+x
                    guard selectedOwners.contains(owners[source]),pixels[source*4+3] != 0 else { continue }
                    let boundary=[(x-1,y),(x+1,y),(x,y-1),(x,y+1)].contains { nx,ny in
                        nx < 0 || ny < 0 || nx >= width || ny >= height || owners[ny*width+nx] != owners[source]
                    }
                    guard boundary else { continue }
                    for dy in -radius...radius {
                        for dx in -radius...radius where dx*dx+dy*dy <= radius*radius {
                            let nx=x+dx,ny=y+dy
                            guard nx >= 0,ny >= 0,nx < width,ny < height else { continue }
                            let target=ny*width+nx
                            guard !selectedOwners.contains(owners[target]) else { continue }
                            let borderDepth=depths[source]+Double(dx)*slopesX[source]+Double(dy)*slopesY[source]
                            guard !depths[target].isFinite || depths[target] <= borderDepth+0.00001 else { continue }
                            outline.insert(target)
                        }
                    }
                }
            }
            for index in outline {
                for c in 0..<4 { pixels[index*4+c]=255 }
            }
        }
        return image(pixels, width: width, height: height)
    }

    /// 凹角遮蔽量（0~1）。取上下、左右、两条对角线上成对的邻居：
    /// 平面上两侧深度一高一低，平均值等于自己；凹角（墙脚、家具与地面交界）两侧都更靠前，平均值偏高。
    /// 凸角平均值偏低，不会变暗。差太多的视为前方的独立物体，不把后面的墙压黑。
    private static func occlusionAmount(_ x: Int, _ y: Int, depths: [Double],
                                        width: Int, height: Int, scale: Double) -> Double {
        let center = depths[y*width+x]
        let directions = [(1,0),(0,1),(1,1),(1,-1)]
        var total = 0.0, samples = 0
        for radius in IsoPixelStyle.occlusionRadii {
            for (dx,dy) in directions {
                let ax = x+dx*radius, ay = y+dy*radius, bx = x-dx*radius, by = y-dy*radius
                guard ax >= 0, ay >= 0, bx >= 0, by >= 0,
                      ax < width, ay < height, bx < width, by < height else { continue }
                let a = depths[ay*width+ax], b = depths[by*width+bx]
                guard a > -.infinity, b > -.infinity else { continue }
                samples += 1
                let deviation = (a+b)*0.5-center
                guard deviation < IsoPixelStyle.occlusionRange else { continue }
                // 换算成“每像素的弯折程度”，与画布缩放无关：直角墙脚约为 1.5。
                let bend = deviation*scale/Double(radius)
                total += min(1, max(0, bend-IsoPixelStyle.occlusionBias))
            }
        }
        return samples == 0 ? 0 : total/Double(samples)
    }

    static func image(_ pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider=CGDataProvider(data:Data(pixels) as CFData) else { return nil }
        return CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,
                       space:CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent)
    }
}
