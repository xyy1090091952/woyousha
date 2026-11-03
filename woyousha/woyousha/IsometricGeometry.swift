import Foundation
import CoreGraphics

/// 所有房间和家具共用 2:1 等轴投影：两条水平轴分别向左下、右下倾斜。
/// z 表示高度。这里仅计算 2D 像素，不依赖 3D 引擎或 WebView。
nonisolated struct IsoPoint {
    var x: Double
    var y: Double
    var z: Double
    init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
    func offset(_ p: IsoPoint) -> IsoPoint { IsoPoint(x+p.x, y+p.y, z+p.z) }
}

nonisolated struct IsoProjection {
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

nonisolated struct IsoFace {
    let points: [IsoPoint]
    let color: UInt32
    let outline: UInt32?
}

nonisolated struct IsoMesh {
    var faces: [IsoFace] = []

    mutating func face(_ points: [IsoPoint], _ color: UInt32, outline: UInt32? = nil) {
        faces.append(IsoFace(points: points, color: color, outline: outline))
    }

    /// 三个可见面使用统一光照。每一条边都由真实长宽高投影，不再画“正面矩形”。
    mutating func box(_ x: Double, _ y: Double, _ z: Double, _ w: Double, _ d: Double, _ h: Double,
                      _ color: UInt32, outlined: Bool = true) {
        let edge = outlined ? IsoColor.shade(color, 0.53) : nil
        face([.init(x,y+d,z),.init(x+w,y+d,z),.init(x+w,y+d,z+h),.init(x,y+d,z+h)],
             IsoColor.shade(color,0.94),outline:edge)
        face([.init(x+w,y,z),.init(x+w,y+d,z),.init(x+w,y+d,z+h),.init(x+w,y,z+h)],
             IsoColor.shade(color,0.73),outline:edge)
        face([.init(x,y,z+h),.init(x+w,y,z+h),.init(x+w,y+d,z+h),.init(x,y+d,z+h)],
             IsoColor.shade(color,1.15),outline:edge)
    }

    // 面上细节同样用世界坐标：门缝、书脊、玻璃高光不会偏离家具方向。
    mutating func front(_ x: Double, _ y: Double, _ z: Double, _ w: Double, _ h: Double, _ color: UInt32) {
        face([.init(x,y,z),.init(x+w,y,z),.init(x+w,y,z+h),.init(x,y,z+h)],color)
    }
    mutating func side(_ x: Double, _ y: Double, _ z: Double, _ d: Double, _ h: Double, _ color: UInt32) {
        face([.init(x,y,z),.init(x,y+d,z),.init(x,y+d,z+h),.init(x,y,z+h)],color)
    }
    mutating func top(_ x: Double, _ y: Double, _ z: Double, _ w: Double, _ d: Double, _ color: UInt32) {
        face([.init(x,y,z),.init(x+w,y,z),.init(x+w,y+d,z),.init(x,y+d,z)],color)
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
                let shade = [0.82,0.78,0.73,0.82,0.94,0.95,0.86,0.82][i] * (level==2 ? 1.1:1)
                face([rings[level][i],rings[level][j],rings[level+1][j],rings[level+1][i]],
                     IsoColor.shade(color,shade))
            }
        }
        face(rings[3],IsoColor.shade(color,1.15),outline:IsoColor.shade(color,0.7))
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
                let dx = b.x-a.x, dy = b.y-a.y
                let length = max(0.001,hypot(dx,dy))
                let lighting = 0.88-0.10*dy/length+0.13*dx/length+(level>4 ? 0.08:0)
                face([a,b,rings[level+1][j],rings[level+1][i]],IsoColor.shade(color,lighting))
            }
        }
        face(rings.last!,IsoColor.shade(color,1.15))
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
            let a = (Double(i)+0.5)*2 * .pi / Double(sides)
            let light = 0.86 + 0.16*sin(a)-0.12*cos(a)
            face([bottom[i],bottom[j],top[j],top[i]],IsoColor.shade(color,light))
        }
        face(top,IsoColor.shade(color,1.16),outline:IsoColor.shade(color,0.6))
    }

    /// 沿 y 轴挤出的轮廓，用于贝壳灯、软靠背等有明确剪影的造型。
    mutating func profile(_ points: [(Double,Double)], y: Double, depth: Double, color: UInt32) {
        let front = points.map { IsoPoint($0.0,y+depth,$0.1) }
        let back = points.map { IsoPoint($0.0,y,$0.1) }
        face(front,color,outline:IsoColor.shade(color,0.6))
        for i in points.indices {
            let j = (i+1)%points.count
            face([back[i],back[j],front[j],front[i]],IsoColor.shade(color,0.81))
        }
    }
    mutating func merge(_ other: IsoMesh, at position: IsoPoint = .init(0,0,0)) {
        for face in other.faces {
            faces.append(IsoFace(points: face.points.map { $0.offset(position) }, color: face.color, outline: face.outline))
        }
    }

    func exchangingAxes() -> IsoMesh {
        IsoMesh(faces: faces.map {
            let face = $0
            // 镜像交换两条地面轴后，受光面也要交换；不能直接水平翻转整张图片。
            let liesOnX = face.points.allSatisfy { abs($0.x-face.points[0].x)<0.00001 }
            let liesOnY = face.points.allSatisfy { abs($0.y-face.points[0].y)<0.00001 }
            let factor = liesOnX ? 0.94/0.73 : (liesOnY ? 0.73/0.94 : 1)
            return IsoFace(points:face.points.map { .init($0.y,$0.x,$0.z) },
                           color:IsoColor.shade(face.color,factor),outline:face.outline)
        })
    }
}

/// 软件像素画布。深度缓冲只负责 2D 多边形的遮挡，避免书架隔板/沙发扶手穿透。
/// 小尺寸图片仅生成一次并缓存；拖拽时不会重复栅格化。
/// 流程分两步：先栅格化出“面颜色 + 深度”，再统一套 IsoPixelStyle（颗粒、凹角变暗、调色）。
nonisolated enum IsoRasterizer {
    static func render(_ mesh: IsoMesh, width: Int, height: Int, projection: IsoProjection) -> CGImage? {
        let count = width*height
        var colors = [UInt32](repeating: 0, count: count)
        var depths = [Double](repeating: -.infinity, count: count)
        // 颗粒种子按面颜色区分：同色的大平面颗粒连续；0 表示描边像素，不加颗粒。
        var seeds = [UInt32](repeating: 0, count: count)

        func write(_ x: Int, _ y: Int, _ depth: Double, _ color: UInt32, seed: UInt32) {
            guard x >= 0, y >= 0, x < width, y < height else { return }
            let index = y*width+x
            guard depth >= depths[index]-0.00001 else { return }
            depths[index] = depth
            colors[index] = color
            seeds[index] = seed
        }

        for face in mesh.faces {
            let p = face.points.map(projection.project)
            let d = face.points.map(projection.depth)
            guard p.count >= 3 else { continue }
            let seed = (face.color & 0xFFFFFF) | 0x0100_0000
            for i in 1..<(p.count-1) {
                let a=p[0], b=p[i], c=p[i+1]
                let denominator=(b.y-c.y)*(a.x-c.x)+(c.x-b.x)*(a.y-c.y)
                guard abs(denominator)>0.00001 else { continue }
                let x0=max(0,Int(floor(min(a.x,b.x,c.x))))
                let x1=min(width-1,Int(ceil(max(a.x,b.x,c.x))))
                let y0=max(0,Int(floor(min(a.y,b.y,c.y))))
                let y1=min(height-1,Int(ceil(max(a.y,b.y,c.y))))
                guard x0<=x1, y0<=y1 else { continue }
                for y in y0...y1 {
                    for x in x0...x1 {
                        let px=Double(x)+0.5, py=Double(y)+0.5
                        let u=((b.y-c.y)*(px-c.x)+(c.x-b.x)*(py-c.y))/denominator
                        let v=((c.y-a.y)*(px-c.x)+(a.x-c.x)*(py-c.y))/denominator
                        let w=1-u-v
                        if min(u,v,w)>=(-0.00001) {
                            write(x,y,u*d[0]+v*d[i]+w*d[i+1],face.color,seed:seed)
                        }
                    }
                }
            }
            if let outline=face.outline {
                // 描边只比面色暗一点，靠明暗分面表达形体，而不是卡通黑线。
                let edge = IsoPixelStyle.mix(face.color, outline, IsoPixelStyle.outlineStrength)
                for i in p.indices {
                    let j=(i+1)%p.count
                    let steps=max(1,Int(ceil(max(abs(p[j].x-p[i].x),abs(p[j].y-p[i].y)))))
                    for step in 0...steps {
                        let t=Double(step)/Double(steps)
                        write(Int((p[i].x+(p[j].x-p[i].x)*t).rounded()),
                              Int((p[i].y+(p[j].y-p[i].y)*t).rounded()),
                              d[i]+(d[j]-d[i])*t+0.04,edge,seed:0)
                    }
                }
            }
        }

        // 第二步：逐像素套风格。亮度系数 = 凹角遮蔽 × 表面颗粒，再统一调色。
        var pixels = [UInt8](repeating: 0, count: count*4)
        for y in 0..<height {
            for x in 0..<width {
                let index = y*width+x
                guard depths[index] > -.infinity else { continue }
                let occlusion = IsoPixelStyle.occlusionFactor(
                    occlusionAmount(x, y, depths: depths, width: width, height: height,
                                    scale: projection.scale), x, y)
                let grain = seeds[index] == 0 ? 1 : IsoPixelStyle.grain(x, y, seed: seeds[index])
                let (r,g,b) = IsoPixelStyle.grade(colors[index], occlusion*grain)
                pixels[index*4] = r
                pixels[index*4+1] = g
                pixels[index*4+2] = b
                pixels[index*4+3] = 255
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

    /// 地面软影单独成一张同尺寸透明图，垫在家具图下面：
    /// 选中白边只根据家具本体生成，不会把影子也描进去。
    static func groundShadow(_ mesh: IsoMesh, width: Int, height: Int, projection: IsoProjection) -> CGImage? {
        let points = mesh.faces.flatMap(\.points)
        guard let ground = points.map(\.z).min() else { return nil }
        let base = points.filter { $0.z <= ground+IsoPixelStyle.shadowFootprintHeight }
        guard let minX = base.map(\.x).min(), let maxX = base.map(\.x).max(),
              let minY = base.map(\.y).min(), let maxY = base.map(\.y).max() else { return nil }
        var pixels = [UInt8](repeating: 0, count: width*height*4)
        let shadowColor = IsoPixelStyle.shadowColor
        let s = projection.scale
        for py in 0..<height {
            for px in 0..<width {
                // 屏幕点反投影到 z=ground 的地面上，得到世界坐标，再按占地矩形算远近。
                let difference = (Double(px)+0.5-projection.origin.x)/s
                let sum = 2*((Double(py)+0.5-projection.origin.y)/s+ground)
                let wx = (sum+difference)*0.5-IsoPixelStyle.shadowOffsetX
                let wy = (sum-difference)*0.5-IsoPixelStyle.shadowOffsetY
                let distance = IsoPixelStyle.signedDistance(x:wx,y:wy,minX:minX,minY:minY,maxX:maxX,maxY:maxY)
                // 离画布边越近越淡，到最外一圈完全透明。
                let edge = Double(min(px, py, width-1-px, height-1-py))
                let fade = min(1, edge/IsoPixelStyle.shadowEdgeFade)
                let alpha = IsoPixelStyle.shadowAlpha(distance:distance,px,py)*fade
                guard alpha > 0 else { continue }
                // 画布是预乘透明度格式，颜色要先乘以 alpha。
                let index = (py*width+px)*4
                pixels[index] = UInt8((Double((shadowColor>>16)&255)*alpha).rounded())
                pixels[index+1] = UInt8((Double((shadowColor>>8)&255)*alpha).rounded())
                pixels[index+2] = UInt8((Double(shadowColor&255)*alpha).rounded())
                pixels[index+3] = UInt8((255*alpha).rounded())
            }
        }
        return image(pixels, width: width, height: height)
    }

    private static func image(_ pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider=CGDataProvider(data:Data(pixels) as CFData) else { return nil }
        return CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,
                       space:CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent)
    }
}
