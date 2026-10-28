import AVFoundation
import Observation
import UIKit

/// 页面唯一的相机状态来源。每次启停带版本号，退出后的旧回调不会覆盖新页面。
@MainActor @Observable
final class CameraController {
    enum State: Equatable {
        case preparing, ready, paused, denied, restricted, unavailable
        case interrupted(String), failed(String)
    }
    struct Photo {
        let id = UUID()
        let data: Data
    }
    private(set) var state: State = .paused
    private(set) var isCapturing = false
    private(set) var hasFlash = false
    private(set) var canSwitchCamera = false
    private(set) var isFrontCamera = false
    private(set) var photo: Photo?
    var usesFlash = false
    var captureError: String?

    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var permissionTask: Task<Void, Never>?
    @ObservationIgnored private var startupWatchdog: Task<Void, Never>?
    @ObservationIgnored private weak var previewLayer: AVCaptureVideoPreviewLayer?
    @ObservationIgnored private var rotationAngle: CGFloat = CameraSettings.portraitRotation
    @ObservationIgnored private lazy var driver = CameraSessionDriver { [weak self] event, generation in
        Task { @MainActor [weak self] in
            guard let self, self.isActive, self.generation == generation else { return }
            switch event {
            case .ready(let hasFlash, let canSwitch, let isFront):
                self.startupWatchdog?.cancel()
                self.hasFlash = hasFlash
                self.canSwitchCamera = canSwitch
                self.isFrontCamera = isFront
                if !hasFlash { self.usesFlash = false }
                self.state = .ready
            case .interrupted(let message):
                self.startupWatchdog?.cancel()
                self.state = .interrupted(message)
                self.isCapturing = false
            case .failed(let message):
                self.startupWatchdog?.cancel()
                self.state = .failed(message)
                self.isCapturing = false
            case .photo(let data):
                self.isCapturing = false
                // 不在主线程展开大照片，交给录入流水线做缩略解码。
                self.photo = Photo(data: data)
            case .captureFailed(let message):
                self.isCapturing = false
                self.captureError = message
            }
        }
    }

    var canCapture: Bool { isActive && state == .ready && !isCapturing }
    var canUseShutter: Bool {
        guard !isCapturing else { return false }
        switch state {
        case .ready, .paused, .failed, .interrupted, .denied: return true
        default: return false
        }
    }
    var shutterTitle: String {
        switch state {
        case .denied: return "开启相机"
        case .failed, .interrupted, .paused: return "重试相机"
        case .preparing: return "连接中…"
        default: return "拍一张"
        }
    }
    var message: String {
        switch state {
        case .preparing: return "正在连接摄像头…"
        case .ready: return "轻点画面对焦，让物品完整入镜"
        case .paused: return "相机已暂停"
        case .denied: return "开启相机权限，就可以在这里拍照"
        case .restricted: return "系统限制了相机使用"
        case .unavailable: return "当前设备没有可用相机"
        case .interrupted(let message), .failed(let message): return message
        }
    }

    func attach(to layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        layer.videoGravity = .resizeAspectFill
        layer.session = driver.session
    }

    func detach(from layer: AVCaptureVideoPreviewLayer) {
        if previewLayer === layer { previewLayer = nil }
        layer.session = nil
    }

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        generation = UUID()
        permissionTask?.cancel()
        startupWatchdog?.cancel()
        if !active {
            isCapturing = false
            state = .paused
            driver.setRunning(false, generation: generation)
            return
        }
        state = .preparing
        let requestGeneration = generation
        permissionTask = Task { [weak self] in
            guard let self else { return }
            let authorized: Bool
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: authorized = true
            case .notDetermined: authorized = await AVCaptureDevice.requestAccess(for: .video)
            case .restricted:
                self.state = .restricted
                return
            default: authorized = false
            }
            guard !Task.isCancelled, self.isActive, self.generation == requestGeneration else { return }
            guard authorized else { self.state = .denied; return }
            let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
            guard !discovery.devices.isEmpty else { self.state = .unavailable; return }
            self.driver.setRunning(true, generation: requestGeneration)
            // 这个超时在主线程计时，不等待视频帧，也不会被后台 startRunning 阻塞。
            self.startupWatchdog = Task { [weak self] in
                try? await Task.sleep(for: .seconds(CameraSettings.startupTimeout))
                guard !Task.isCancelled, let self, self.isActive,
                      self.generation == requestGeneration, self.state == .preparing else { return }
                self.state = .failed("相机没有成功连接。若正在使用 iPhone 镜像，请退出镜像，在手机上重试。")
                self.generation = UUID()
                self.driver.setRunning(false,generation:self.generation)
            }
        }
    }

    func retry() {
        setActive(false)
        setActive(true)
    }

    func capture() {
        guard canCapture else {
            if state == .denied {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            } else if canUseShutter { retry() }
            return
        }
        isCapturing = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        driver.capture(flash: usesFlash, generation: generation)
    }

    func consumePhoto() -> Data? {
        defer { photo = nil }
        return photo?.data
    }

    func switchCamera() {
        guard canCapture, canSwitchCamera else { return }
        state = .preparing
        driver.switchCamera(generation: generation)
    }

    func focus(at point: CGPoint) {
        guard canCapture else { return }
        driver.focus(at: point)
    }

    func rotate(to angle: CGFloat) {
        guard rotationAngle != angle else { return }
        rotationAngle = angle
        driver.rotate(to: angle)
    }
}
