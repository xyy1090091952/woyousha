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
nonisolated enum IsoRasterizer {
    static func render(_ mesh: IsoMesh, width: Int, height: Int, projection: IsoProjection) -> CGImage? {
        var pixels = [UInt8](repeating: 0, count: width*height*4)
        var depths = [Double](repeating: -.infinity, count: width*height)

        func write(_ x: Int, _ y: Int, _ depth: Double, _ color: UInt32) {
            guard x >= 0, y >= 0, x < width, y < height else { return }
            let index = y*width+x
            guard depth >= depths[index]-0.00001 else { return }
            depths[index] = depth
            pixels[index*4] = UInt8((color>>16)&255)
            pixels[index*4+1] = UInt8((color>>8)&255)
            pixels[index*4+2] = UInt8(color&255)
            pixels[index*4+3] = 255
        }

        for face in mesh.faces {
            let p = face.points.map(projection.project)
            let d = face.points.map(projection.depth)
            guard p.count >= 3 else { continue }
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
                            write(x,y,u*d[0]+v*d[i]+w*d[i+1],face.color)
                        }
                    }
                }
            }
            if let outline=face.outline {
                for i in p.indices {
                    let j=(i+1)%p.count
                    let steps=max(1,Int(ceil(max(abs(p[j].x-p[i].x),abs(p[j].y-p[i].y)))))
                    for step in 0...steps {
                        let t=Double(step)/Double(steps)
                        write(Int((p[i].x+(p[j].x-p[i].x)*t).rounded()),
                              Int((p[i].y+(p[j].y-p[i].y)*t).rounded()),
                              d[i]+(d[j]-d[i])*t+0.04,outline)
                    }
                }
            }
        }
        let data=Data(pixels)
        guard let provider=CGDataProvider(data:data as CFData) else { return nil }
        return CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,
                       space:CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent)
    }
}
