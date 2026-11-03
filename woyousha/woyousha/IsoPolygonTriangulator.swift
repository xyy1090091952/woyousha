import CoreGraphics

/// 主体和投影共用面片剖分。凹形轮廓不能直接连到第一个顶点，否则会填满缺口。
/// 返回原数组的下标，光照、深度和世界坐标纹理仍对应原来的模型顶点。
nonisolated enum IsoPolygonTriangulator {
    private static let epsilon = 0.000001

    static func triangles(_ points: [CGPoint]) -> [(Int, Int, Int)] {
        guard points.count >= 3 else { return [] }
        func cross(_ a: Int, _ b: Int, _ c: Int) -> Double {
            (points[b].x-points[a].x)*(points[c].y-points[a].y)
                - (points[b].y-points[a].y)*(points[c].x-points[a].x)
        }
        var ring: [Int] = []
        for i in points.indices {
            if let last = ring.last,
               hypot(points[i].x-points[last].x, points[i].y-points[last].y) < epsilon { continue }
            ring.append(i)
        }
        if ring.count > 1, let first = ring.first, let last = ring.last,
           hypot(points[first].x-points[last].x, points[first].y-points[last].y) < epsilon {
            ring.removeLast()
        }
        // 圆角模型有重复、共线的分段，先清理，防止剖分卡在零面积的“耳朵”上。
        var removed = true
        while ring.count > 3 && removed {
            removed = false
            for i in ring.indices {
                let a = ring[(i+ring.count-1)%ring.count], b = ring[i], c = ring[(i+1)%ring.count]
                if abs(cross(a,b,c)) < epsilon {
                    ring.remove(at:i)
                    removed = true
                    break
                }
            }
        }
        guard ring.count >= 3 else { return [] }
        let area = ring.indices.reduce(0.0) { sum, i in
            let a = points[ring[i]], b = points[ring[(i+1)%ring.count]]
            return sum+a.x*b.y-a.y*b.x
        }
        guard abs(area) > epsilon else { return [] }
        let direction = area > 0 ? 1.0 : -1.0
        // 绝大多数面是凸四边形或圆面，保留快速路径，避免增加每次绘图的开销。
        let convex = ring.indices.allSatisfy {
            cross(ring[($0+ring.count-1)%ring.count],ring[$0],ring[($0+1)%ring.count])*direction >= -epsilon
        }
        if convex {
            return (1..<(ring.count-1)).map { (ring[0],ring[$0],ring[$0+1]) }
        }
        var result: [(Int,Int,Int)] = []
        while ring.count > 3 {
            var clipped = false
            for i in ring.indices {
                let a = ring[(i+ring.count-1)%ring.count], b = ring[i], c = ring[(i+1)%ring.count]
                guard cross(a,b,c)*direction > epsilon else { continue }
                let occupied = ring.contains { p in
                    p != a && p != b && p != c
                        && cross(a,b,p)*direction >= -epsilon
                        && cross(b,c,p)*direction >= -epsilon
                        && cross(c,a,p)*direction >= -epsilon
                }
                guard !occupied else { continue }
                result.append((a,b,c))
                ring.remove(at:i)
                clipped = true
                break
            }
            // 无效或自交轮廓不回退到扇形，避免生成跨越轮廓的大块错误面。
            guard clipped else { return [] }
        }
        result.append((ring[0],ring[1],ring[2]))
        return result
    }
}
