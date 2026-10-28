import AVFoundation
import Observation
import UIKit

@MainActor @Observable
final class CameraController {
    enum State { case preparing, ready, denied, unavailable, interrupted, failed }
    private(set) var state: State = .preparing
    private(set) var isCapturing = false
    private(set) var hasFlash = false
    private(set) var canSwitchCamera = false
    var usesFlash = false
    var captureError: String?
    var capturedImage: UIImage?
    private var isActive = false

    // 会话操作放到专用串行队列，界面状态只在主线程更新。
    @ObservationIgnored private lazy var driver = CameraSessionController { [weak self] event in
        Task { @MainActor [weak self] in
            guard let self, self.isActive else { return }
            switch event {
            case .running(let hasFlash, let canSwitch):
                self.state = .ready
                self.isCapturing = false
                self.hasFlash = hasFlash
                self.canSwitchCamera = canSwitch
                if !hasFlash { self.usesFlash = false }
            case .unavailable: self.state = .unavailable
            case .interrupted:
                self.state = .interrupted
                self.isCapturing = false
            case .failed:
                self.state = .failed
                self.isCapturing = false
            case .photo(let data):
                self.isCapturing = false
                if let image = UIImage(data: data) {
                    self.capturedImage = image
                } else {
                    self.captureError = "照片没有生成成功，请再拍一次。"
                }
            case .captureFailed:
                self.isCapturing = false
                self.captureError = "拍照没有完成，请再试一次。"
            }
        }
    }

    var session: AVCaptureSession { driver.session }
    var canCapture: Bool { state == .ready && !isCapturing }

    var message: String {
        switch state {
        case .preparing: return "正在打开相机"
        case .ready: return "让物品完整地出现在画面里"
        case .denied: return "开启相机权限后，就可以给物品拍照。"
        case .unavailable: return "当前设备没有可用相机，可以从相册选照片。"
        case .interrupted: return "相机暂时被其他功能占用，请稍后重试。"
        case .failed: return "相机暂时无法打开，请重试或从相册选择。"
        }
    }

    func start() {
        isActive = true
        state = .preparing
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: driver.start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self, self.isActive else { return }
                    if granted { self.driver.start() } else { self.state = .denied }
                }
            }
        case .denied, .restricted: state = .denied
        @unknown default: state = .denied
        }
    }

    func stop() {
        isActive = false
        isCapturing = false
        driver.stop()
    }

    func capture() {
        guard canCapture else { return }
        isCapturing = true
        driver.capture(usesFlash: usesFlash)
    }

    func switchCamera() {
        guard canCapture, canSwitchCamera else { return }
        state = .preparing
        driver.switchCamera()
    }

    func focus(at point: CGPoint) { driver.focus(at: point) }
    func rotate(to angle: CGFloat) { driver.rotate(to: angle) }
}

/// 队列是所有可变会话状态的唯一入口；unchecked Sendable 仅用于这个队列封装。
nonisolated final class CameraSessionController: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    enum Event {
        case running(hasFlash: Bool, canSwitch: Bool)
        case unavailable, interrupted, failed, captureFailed
        case photo(Data)
    }

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.woyousha.camera.session")
    private let output = AVCapturePhotoOutput()
    private let onEvent: @Sendable (Event) -> Void
    private var input: AVCaptureDeviceInput?
    private var shouldRun = false
    private var isConfigured = false
    private var captureID: Int64?
    private var photoData: Data?
    private var rotationAngle: CGFloat = 90
    private var observers: [NSObjectProtocol] = []

    init(onEvent: @escaping @Sendable (Event) -> Void) {
        self.onEvent = onEvent
        super.init()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.queue.async {
                guard self.shouldRun else { return }
                self.captureID = nil
                self.photoData = nil
                self.onEvent(.interrupted)
            }
        })
        observers.append(center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.queue.async {
                guard self.shouldRun else { return }
                self.captureID = nil
                self.photoData = nil
                if !self.session.isRunning { self.session.startRunning() }
                self.publishRunningState()
            }
        })
        observers.append(center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) { [weak self] notification in
            guard let self else { return }
            let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
            self.queue.async {
                guard self.shouldRun else { return }
                self.captureID = nil
                self.photoData = nil
                if error?.code == .mediaServicesWereReset {
                    self.session.startRunning()
                    self.publishRunningState()
                } else {
                    self.onEvent(.failed)
                }
            }
        })
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    func start() {
        queue.async {
            self.shouldRun = true
            if !self.isConfigured {
                guard self.configure() else { return }
            }
            if !self.session.isRunning { self.session.startRunning() }
            self.publishRunningState()
        }
    }

    func stop() {
        queue.async {
            self.shouldRun = false
            self.captureID = nil
            self.photoData = nil
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func configure() -> Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video) else {
            onEvent(.unavailable)
            return false
        }
        do {
            let newInput = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            if session.canSetSessionPreset(.photo) { session.sessionPreset = .photo }
            guard session.canAddInput(newInput) else { onEvent(.failed); return false }
            session.addInput(newInput)
            guard session.canAddOutput(output) else {
                session.removeInput(newInput)
                onEvent(.failed)
                return false
            }
            session.addOutput(output)
            input = newInput
            isConfigured = true
            return true
        } catch {
            onEvent(.failed)
            return false
        }
    }

    func switchCamera() {
        queue.async {
            guard self.shouldRun else { return }
            guard self.captureID == nil, let oldInput = self.input else {
                self.publishRunningState()
                return
            }
            let position: AVCaptureDevice.Position = oldInput.device.position == .back ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let newInput = try? AVCaptureDeviceInput(device: device) else {
                self.publishRunningState()
                return
            }
            self.session.beginConfiguration()
            self.session.removeInput(oldInput)
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.input = newInput
            } else {
                self.session.addInput(oldInput)
            }
            self.session.commitConfiguration()
            self.publishRunningState()
        }
    }

    func capture(usesFlash: Bool) {
        queue.async {
            guard self.shouldRun, self.session.isRunning, !self.session.isInterrupted, self.captureID == nil else {
                self.onEvent(.captureFailed)
                return
            }
            let settings = AVCapturePhotoSettings()
            if self.input?.device.hasFlash == true {
                let flashMode: AVCaptureDevice.FlashMode = usesFlash ? .on : .off
                if self.output.supportedFlashModes.contains(flashMode) { settings.flashMode = flashMode }
            }
            // 输出方向与预览一致；自拍预览可镜像，但保存的文字不会被反写。
            if let connection = self.output.connection(with: .video),
               connection.isVideoRotationAngleSupported(self.rotationAngle) {
                connection.videoRotationAngle = self.rotationAngle
            }
            self.captureID = settings.uniqueID
            self.photoData = nil
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = error == nil ? photo.fileDataRepresentation() : nil
        let id = photo.resolvedSettings.uniqueID
        queue.async {
            guard self.captureID == id else { return }
            self.photoData = data
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        let id = resolvedSettings.uniqueID
        let succeeded = error == nil
        queue.async {
            guard self.captureID == id else { return }
            let data = self.photoData
            self.captureID = nil
            self.photoData = nil
            guard self.shouldRun else { return }
            if succeeded, let data { self.onEvent(.photo(data)) }
            else { self.onEvent(.captureFailed) }
        }
    }

    func focus(at point: CGPoint) {
        queue.async {
            guard let device = self.input?.device else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .continuousAutoExposure
                }
            } catch { /* 点击对焦失败不影响拍照。 */ }
        }
    }

    func rotate(to angle: CGFloat) {
        queue.async { self.rotationAngle = angle }
    }

    private func publishRunningState() {
        guard shouldRun else { return }
        guard session.isRunning && !session.isInterrupted else {
            onEvent(session.isInterrupted ? .interrupted : .failed)
            return
        }
        let position: AVCaptureDevice.Position = input?.device.position == .back ? .front : .back
        let canSwitch = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) != nil
        onEvent(.running(hasFlash: input?.device.hasFlash == true, canSwitch: canSwitch))
    }
}
