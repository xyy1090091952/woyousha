import Foundation
import CoreGraphics
import Metal
import simd

/// 后台串行渲染服务：SwiftData 不进入 GPU 线程，旧帧由页面的任务版本检查拦截。
actor HouseSceneRenderService {
    static let shared = HouseSceneRenderService()
    private var renderer: HouseMetalRenderer?
    private var hasPreparedDevice = false

    func render(_ job: HouseRenderJob) -> CGImage? {
        guard !Task.isCancelled else { return nil }
        if !hasPreparedDevice {
            hasPreparedDevice = true
            renderer = HouseMetalRenderer()
        }
        if let image = renderer?.render(job) { return image }
        // 不支持 Metal 或发生绘制失败时，继续使用原有软件绘图。
        return job.render(cancellable: true)
    }
}

/// GPU 只替换绘图路径，沿用世界坐标、材质色阶、深度遮挡和选中白边的规则。
/// 缓冲结构与 HouseShaders.txt 中的 Metal 源码一一对应，使用 16 字节对齐的四维向量。
nonisolated final class HouseMetalRenderer {
    private struct Vertex {
        var point: SIMD4<Float>
        var normal: SIMD4<Float>
        var palette: SIMD4<UInt32>
        var grain: SIMD4<Float>
        var speck: SIMD4<Float>
        var details: SIMD4<Float>
        var ids: SIMD4<UInt32>
    }
    private struct Uniforms {
        var projection: SIMD4<Float>
        var viewport: SIMD4<Float>
        var object: SIMD4<Float> = .zero
        var shadow: SIMD4<Float>
        var lighting: SIMD4<Float>
        var occlusion: SIMD4<Float>
        var shadowTreatment: SIMD4<Float>
        var radii: SIMD4<UInt32>
        var colors: SIMD4<UInt32>
        var preview: SIMD4<Float> = .zero
        var state: SIMD4<UInt32> = .zero
    }
    private struct Geometry {
        let buffer: MTLBuffer
        let count: Int
    }
    private struct Snapshot {
        let colors: MTLTexture
        let metadata: MTLTexture
        let shadow: MTLTexture
    }
    private enum Limits {
        static let geometryCacheCount = 48
        static let snapshotCacheCount = 2
        static let maximumDimension = 4096
    }

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let surfacePipeline: MTLRenderPipelineState
    private let shadowPipeline: MTLRenderPipelineState
    private let finishPipeline: MTLComputePipelineState
    private let depthState: MTLDepthStencilState
    private var geometryCache: [String: Geometry] = [:]
    private var geometryOrder: [String] = []
    private var snapshots: [String: Snapshot] = [:]
    private var snapshotOrder: [String] = []

    /// 可注入同一份 shader 供 Mac 核验；App 在后台首次编译并复用结果。
    init?(device: MTLDevice? = MTLCreateSystemDefaultDevice(), library: MTLLibrary? = nil) {
        guard let device, let queue = device.makeCommandQueue(),
              let library = library ?? Self.loadLibrary(device),
              let vertex = library.makeFunction(name: "houseVertex"),
              let fragment = library.makeFunction(name: "houseSurface"),
              let shadowVertex = library.makeFunction(name: "houseShadowVertex"),
              let shadowFragment = library.makeFunction(name: "houseShadow"),
              let finish = library.makeFunction(name: "houseFinish") else { return nil }
        let surface = MTLRenderPipelineDescriptor()
        surface.vertexFunction = vertex
        surface.fragmentFunction = fragment
        surface.colorAttachments[0].pixelFormat = .rgba8Unorm
        surface.colorAttachments[1].pixelFormat = .rgba32Float
        surface.depthAttachmentPixelFormat = .depth32Float
        let shadow = MTLRenderPipelineDescriptor()
        shadow.vertexFunction = shadowVertex
        shadow.fragmentFunction = shadowFragment
        shadow.colorAttachments[0].pixelFormat = .r8Unorm
        shadow.colorAttachments[0].isBlendingEnabled = true
        shadow.colorAttachments[0].rgbBlendOperation = .max
        shadow.colorAttachments[0].alphaBlendOperation = .max
        shadow.colorAttachments[0].sourceRGBBlendFactor = .one
        shadow.colorAttachments[0].destinationRGBBlendFactor = .one
        let depth = MTLDepthStencilDescriptor()
        depth.depthCompareFunction = .lessEqual
        depth.isDepthWriteEnabled = true
        do {
            surfacePipeline = try device.makeRenderPipelineState(descriptor: surface)
            shadowPipeline = try device.makeRenderPipelineState(descriptor: shadow)
            finishPipeline = try device.makeComputePipelineState(function: finish)
        } catch { return nil }
        guard let depthState = device.makeDepthStencilState(descriptor: depth) else { return nil }
        self.device = device
        self.queue = queue
        self.depthState = depthState
    }

    private static func loadLibrary(_ device: MTLDevice) -> MTLLibrary? {
        if let library = device.makeDefaultLibrary(), library.makeFunction(name: "houseVertex") != nil {
            return library
        }
        // 源码随 App 打包，系统 GPU 编译器可直接加载，不依赖开发机额外下载工具链。
        guard let url = Bundle.main.url(forResource: "HouseShaders", withExtension: "txt"),
              let source = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return try? device.makeLibrary(source: source, options: nil)
    }

    func render(_ job: HouseRenderJob) -> CGImage? {
        let m = job.metrics
        guard !Task.isCancelled, m.width > 0, m.height > 0,
              m.width <= Limits.maximumDimension, m.height <= Limits.maximumDimension,
              !job.geometry.isEmpty, let command = queue.makeCommandBuffer() else { return nil }
        var uniforms = makeUniforms(job)
        let snapshot: Snapshot
        if let cached = snapshots[job.baseKey] {
            snapshot = cached
        } else {
            guard let fresh = drawScene(job, uniforms: uniforms, command: command) else { return nil }
            snapshot = fresh
        }
        guard !Task.isCancelled,
              let output = texture(.rgba8Unorm, width: m.width, height: m.height,
                                   usage: [.shaderWrite], shared: true),
              let encoder = command.makeComputeCommandEncoder() else { return nil }
        let ownerCount = max(job.geometry.map(\.owner).max() ?? 1, 1) + 1
        var ownerFlags = [UInt32](repeating: 0, count: ownerCount)
        for owner in job.selectedOwners where owner >= 0 && owner < ownerCount { ownerFlags[owner] |= 1 }
        for owner in job.shadowReceivers where owner >= 0 && owner < ownerCount { ownerFlags[owner] |= 2 }
        guard let flags = ownerFlags.withUnsafeBytes({
            device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
        }) else { encoder.endEncoding(); return nil }
        uniforms.state.z = UInt32(ownerCount)
        uniforms.state.w = UInt32(job.selectedOwners.count)
        encoder.setComputePipelineState(finishPipeline)
        encoder.setTexture(snapshot.colors, index: 0)
        encoder.setTexture(snapshot.metadata, index: 1)
        encoder.setTexture(snapshot.shadow, index: 2)
        encoder.setTexture(output, index: 3)
        encoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setBuffer(flags, offset: 0, index: 1)
        let threadWidth = finishPipeline.threadExecutionWidth
        let threadHeight = min(8, finishPipeline.maxTotalThreadsPerThreadgroup / threadWidth)
        encoder.dispatchThreads(.init(width: m.width, height: m.height, depth: 1),
                                threadsPerThreadgroup: .init(width: threadWidth, height: threadHeight, depth: 1))
        encoder.endEncoding()
        command.commit()
        // 在后台等待 GPU；主线程只接收完成后的图像，不阻塞触摸和表单。
        command.waitUntilCompleted()
        guard command.status == .completed, !Task.isCancelled else { return nil }
        remember(snapshot, key: job.baseKey)
        var pixels = [UInt8](repeating: 0, count: m.width * m.height * 4)
        pixels.withUnsafeMutableBytes {
            output.getBytes($0.baseAddress!, bytesPerRow: m.width * 4,
                            from: .init(origin: .init(x: 0,y: 0,z: 0),
                                        size: .init(width: m.width,height: m.height,depth: 1)), mipmapLevel: 0)
        }
        return IsoRasterizer.image(pixels, width: m.width, height: m.height)
    }

    private func drawScene(_ job: HouseRenderJob, uniforms: Uniforms, command: MTLCommandBuffer) -> Snapshot? {
        let width = job.metrics.width, height = job.metrics.height
        guard let colors = texture(.rgba8Unorm, width: width, height: height),
              let metadata = texture(.rgba32Float, width: width, height: height),
              let depth = texture(.depth32Float, width: width, height: height, usage: [.renderTarget]),
              let shadow = texture(.r8Unorm, width: width, height: height) else { return nil }
        let pass = MTLRenderPassDescriptor()
        for (index, texture) in [colors, metadata].enumerated() {
            pass.colorAttachments[index].texture = texture
            pass.colorAttachments[index].loadAction = .clear
            pass.colorAttachments[index].storeAction = .store
        }
        pass.colorAttachments[0].clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        pass.colorAttachments[1].clearColor = .init(red: -1e20, green: 0, blue: 0, alpha: 0)
        pass.depthAttachment.texture = depth
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.storeAction = .dontCare
        pass.depthAttachment.clearDepth = 1
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return nil }
        encoder.setRenderPipelineState(surfacePipeline)
        encoder.setDepthStencilState(depthState)
        encoder.setCullMode(.none)
        for batch in job.geometry {
            guard !Task.isCancelled, let geometry = geometry(for: batch) else {
                encoder.endEncoding(); return nil
            }
            var u = uniforms
            u.object = .init(Float(batch.origin.x), Float(batch.origin.y), Float(batch.origin.z), Float(batch.owner))
            encoder.setVertexBuffer(geometry.buffer, offset: 0, index: 0)
            encoder.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: geometry.count)
        }
        encoder.endEncoding()
        let shadowPass = MTLRenderPassDescriptor()
        shadowPass.colorAttachments[0].texture = shadow
        shadowPass.colorAttachments[0].loadAction = .clear
        shadowPass.colorAttachments[0].storeAction = .store
        guard let caster = command.makeRenderCommandEncoder(descriptor: shadowPass) else { return nil }
        caster.setRenderPipelineState(shadowPipeline)
        for mode: UInt32 in [0,1] {
            for batch in job.geometry where !job.shadowReceivers.contains(batch.owner) {
                guard !Task.isCancelled, let geometry = geometry(for: batch) else {
                    caster.endEncoding(); return nil
                }
                var u = uniforms
                u.object = .init(Float(batch.origin.x), Float(batch.origin.y), Float(batch.origin.z), Float(batch.owner))
                u.state.w = mode
                caster.setVertexBuffer(geometry.buffer, offset: 0, index: 0)
                caster.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 1)
                caster.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: geometry.count)
            }
        }
        caster.endEncoding()
        return .init(colors: colors, metadata: metadata, shadow: shadow)
    }

    private func geometry(for batch: HouseGeometryBatch) -> Geometry? {
        if let cached = geometryCache[batch.key] { return cached }
        var vertices: [Vertex] = []
        for face in batch.mesh.faces {
            let points = face.points
            guard points.count >= 3 else { continue }
            let normal = face.normal
            let material = face.material == .automatic ? IsoMaterial.inferred(from: face.color) : face.material
            let treatment = IsoPixelStyle.surfaceTreatment(material)
            let light = IsoPixelStyle.lighting(normal)
                + (material == .plaster ? (1-abs(normal.z))*IsoPixelStyle.plasterLightLift : 0)
            let litColor = IsoPixelStyle.ramp(face.color)[IsoPixelStyle.shadeIndex(light)]
            let ramp = IsoPixelStyle.surfaceRamp(litColor, treatment: treatment)
            let palette = SIMD4<UInt32>(ramp[0], ramp[min(1,ramp.count-1)],
                                       ramp[min(2,ramp.count-1)], ramp[min(3,ramp.count-1)])
            let alongX = points.map(\.x).max()! - points.map(\.x).min()!
                >= points.map(\.y).max()! - points.map(\.y).min()!
            let value = Vertex(point: .zero,
                normal: .init(Float(normal.x),Float(normal.y),Float(normal.z),alongX ? 1:0),
                palette: palette,
                grain: .init(Float(treatment.scaleU),Float(treatment.scaleV),
                             Float(treatment.grainStrength),Float(treatment.ditherStrength)),
                speck: .init(Float(treatment.singleGrainStrength),Float(treatment.speckChance),
                             Float(treatment.speckDarkness),Float(treatment.speckScale)),
                details: .init(Float(points.map(\.z).min()!),Float(face.dissolvesBelow ?? -1e20),
                               Float(face.renderOwner),Float(points.map(\.z).max()!)),
                ids: .init(face.color & 0xFFFFFF,UInt32(ramp.count),0,0))
            // 采用原来的多边形剖分，凹面和镜像家具继续保持正确结构。
            let projection = IsoProjection(scale: 1, origin: .zero)
            for triangle in IsoPolygonTriangulator.triangles(points.map(projection.project)) {
                for index in [triangle.0,triangle.1,triangle.2] {
                    var vertex = value
                    let point = points[index]
                    vertex.point = .init(Float(point.x),Float(point.y),Float(point.z),1)
                    vertices.append(vertex)
                }
            }
        }
        guard !vertices.isEmpty, let buffer = vertices.withUnsafeBytes({
            device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)
        }) else { return nil }
        let geometry = Geometry(buffer: buffer, count: vertices.count)
        geometryCache[batch.key] = geometry
        geometryOrder.append(batch.key)
        if geometryOrder.count > Limits.geometryCacheCount {
            geometryCache.removeValue(forKey: geometryOrder.removeFirst())
        }
        return geometry
    }

    private func makeUniforms(_ job: HouseRenderJob) -> Uniforms {
        let m = job.metrics
        let range = Float(HouseGridConfig.plotSize * 6) * Float(HouseGridConfig.tile)
        let litPreview = IsoPixelStyle.ramp(0xBBD89A)[IsoPixelStyle.shadeIndex(IsoPixelStyle.lighting(.init(0,0,1)))]
        let invalidPreview = IsoPixelStyle.ramp(0xE6AC9E)[IsoPixelStyle.shadeIndex(IsoPixelStyle.lighting(.init(0,0,1)))]
        var u = Uniforms(
            projection: .init(Float(m.projection.scale),Float(m.projection.origin.x),Float(m.projection.origin.y),0),
            viewport: .init(Float(m.width),Float(m.height),-range/2,range),
            shadow: .init(Float(IsoPixelStyle.shadowDirectionX),Float(IsoPixelStyle.shadowDirectionY),
                          Float(IsoPixelStyle.contactHeight),0),
            lighting: .init(Float(IsoPixelStyle.depthEdgeThreshold),Float(IsoPixelStyle.silhouetteTint),
                            Float(IsoPixelStyle.rimTint),Float(IsoPixelStyle.occlusionStrength)),
            occlusion: .init(Float(IsoPixelStyle.occlusionBias),Float(IsoPixelStyle.occlusionRange),
                             Float(IsoPixelStyle.occlusionSteps),Float(ceil(PixelArtRenderer.selectionOutlineRadius))),
            shadowTreatment: .init(Float(IsoPixelStyle.shadowOpacity),Float(IsoPixelStyle.contactOpacity),
                                   Float(IsoPixelStyle.shadowEdgeDither),0),
            radii: .init(UInt32(IsoPixelStyle.occlusionRadii[0]),UInt32(IsoPixelStyle.occlusionRadii[1]),
                         UInt32(IsoPixelStyle.occlusionRadii[2]),UInt32(IsoPixelStyle.occlusionRadii.count)),
            colors: .init(IsoPixelStyle.cool,IsoPixelStyle.warm,litPreview,invalidPreview))
        if let preview = job.preview {
            let tile = Float(HouseGridConfig.tile)
            u.preview = .init(Float(preview.cell.x)*tile,Float(preview.cell.y)*tile,
                              Float(preview.footprint.width)*tile,Float(preview.footprint.depth)*tile)
            u.state.x = 1
            u.state.y = preview.isValid ? 1:0
        }
        return u
    }

    private func texture(_ format: MTLPixelFormat, width: Int, height: Int,
                         usage: MTLTextureUsage = [.renderTarget,.shaderRead], shared: Bool = false) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height,
                                                                 mipmapped: false)
        descriptor.usage = usage
        descriptor.storageMode = shared ? .shared:.private
        return device.makeTexture(descriptor: descriptor)
    }

    private func remember(_ snapshot: Snapshot, key: String) {
        snapshots[key] = snapshot
        snapshotOrder.removeAll { $0 == key }
        snapshotOrder.append(key)
        if snapshotOrder.count > Limits.snapshotCacheCount { snapshots.removeValue(forKey: snapshotOrder.removeFirst()) }
    }
}
