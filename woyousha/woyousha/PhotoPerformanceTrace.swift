import Foundation

/// 从快门到照片数据的时间跨越相机队列和主线程，统一使用不会受校时影响的时钟。
nonisolated struct PhotoCaptureTiming: Sendable {
    let startedUptime: TimeInterval
    let milliseconds: Double
    let width: Int
    let height: Int
}

/// 只收集用时和像素尺寸，不持有照片。锁保护后台处理与主线程读取的交界。
nonisolated final class PhotoPerformanceTrace: @unchecked Sendable {
    enum Stage: String, Codable, CaseIterable, Sendable {
        case capture, albumLoad, inputDelivery, workerScheduling, decode, previewDelivery
        case requestCreation, analysisResize, handlerCreation, vision, refinement, composite
        case cutoutDelivery, outline, resultDelivery

        var title: String {
            switch self {
            case .capture: return "拍照与生成照片"
            case .albumLoad: return "从相册读取"
            case .inputDelivery: return "照片交给处理流程"
            case .workerScheduling: return "等待后台任务开始"
            case .decode: return "读取并缩小图片"
            case .previewDelivery: return "原图交给界面"
            case .requestCreation: return "创建主体识别请求"
            case .analysisResize: return "准备轮廓分析图"
            case .handlerCreation: return "创建图片分析环境"
            case .vision: return "识别物品主体"
            case .refinement: return "细化主体边缘"
            case .composite: return "合成透明图与裁剪"
            case .cutoutDelivery: return "抠图结果交给界面"
            case .outline: return "生成圆润白边"
            case .resultDelivery: return "完成结果交给界面"
            }
        }
    }

    struct Entry: Codable, Sendable, Identifiable {
        let stage: Stage
        let milliseconds: Double
        var id: Stage { stage }
    }

    struct PixelSize: Codable, Sendable {
        let width: Int
        let height: Int
        var description: String { "\(width) × \(height) 像素" }
    }

    struct Snapshot: Codable, Sendable {
        let recordedAt: Date
        let entries: [Entry]
        let totalMilliseconds: Double
        let sourceSize: PixelSize?
        let preparedSize: PixelSize?
        let analysisSize: PixelSize?
        let separated: Bool

        /// 剩余时间只能说明尚未计入具体步骤，不能据此认定是主线程或队列阻塞。
        var handoffMilliseconds: Double {
            max(0, totalMilliseconds - entries.reduce(0) { $0 + $1.milliseconds })
        }

        var slowest: Entry? { entries.max { $0.milliseconds < $1.milliseconds } }

        var bottleneckTitle: String? {
            guard let slowest else { return nil }
            return handoffMilliseconds > slowest.milliseconds ? "其他未细分开销" : slowest.stage.title
        }
    }

    private let startedUptime: TimeInterval
    private let lock = NSLock()
    private var durations: [Stage: Double] = [:]
    private var sourceSize: PixelSize?
    private var preparedSize: PixelSize?
    private var analysisSize: PixelSize?

    static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    var elapsedMilliseconds: Double { max(0, (Self.now - startedUptime) * 1000) }

    /// 只在后台流水线开始前调用；此时已记录的仅为拍摄或相册读取。
    func recordInputDelivery() {
        lock.lock()
        defer { lock.unlock() }
        let accounted = durations.values.reduce(0, +)
        durations[.inputDelivery] = max(0, elapsedMilliseconds - accounted)
    }

    init(capture: PhotoCaptureTiming? = nil) {
        startedUptime = capture?.startedUptime ?? Self.now
        if let capture {
            durations[.capture] = capture.milliseconds
            sourceSize = PixelSize(width: capture.width, height: capture.height)
        }
    }

    @discardableResult
    func measure<T>(_ stage: Stage, _ operation: () throws -> T) rethrows -> T {
        let start = Self.now
        defer { record(stage, milliseconds: (Self.now - start) * 1000) }
        return try operation()
    }

    func record(_ stage: Stage, milliseconds: Double) {
        lock.lock()
        defer { lock.unlock() }
        durations[stage, default: 0] += max(0, milliseconds)
    }

    func setPreparedSize(width: Int, height: Int) {
        lock.lock()
        defer { lock.unlock() }
        preparedSize = PixelSize(width: width, height: height)
    }

    func setAnalysisSize(width: Int, height: Int) {
        lock.lock()
        defer { lock.unlock() }
        analysisSize = PixelSize(width: width, height: height)
    }

    func snapshot(separated: Bool) -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        let entries = Stage.allCases.compactMap { stage in
            durations[stage].map { Entry(stage: stage, milliseconds: $0) }
        }
        return Snapshot(recordedAt: Date(), entries: entries,
                        totalMilliseconds: max(0, (Self.now - startedUptime) * 1000),
                        sourceSize: sourceSize, preparedSize: preparedSize,
                        analysisSize: analysisSize, separated: separated)
    }
}

/// 仅保存最近一次完成的数据；过期/取消的照片由编辑模型拦截，不能覆盖它。
@MainActor
enum PhotoPerformanceStore {
    private static let storageKey = "photoProcessing.latestPerformance.v1"

    static func save(_ snapshot: PhotoPerformanceTrace.Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func load() -> PhotoPerformanceTrace.Snapshot? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(PhotoPerformanceTrace.Snapshot.self, from: data)
    }
}
