import AVFoundation
import Foundation
import OSLog

/// 相机所有可变状态由这一条串行队列管理。主线程只绑定预览层，不操作输入/输出。
/// unchecked Sendable 的边界只包住这个队列封装，AVFoundation 对象不传给图片处理任务。
nonisolated final class CameraSessionDriver: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    enum Event: Sendable {
        case ready(hasFlash: Bool, canSwitch: Bool, isFront: Bool, sensorAspectRatio: CGFloat)
        case interrupted(String), failed(String), photo(Data, PhotoCaptureTiming), captureFailed(String)
    }

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.woyousha.camera.session", qos: .userInitiated)
    private let photoOutput = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput?
    private var configured = false
    private var wantsRunning = false
    private var generation = UUID()
    private var captureID: Int64?
    private var captureStartedUptime: TimeInterval?
    private var capturedData: Data?
    private var rotationAngle: CGFloat = CameraSettings.portraitRotation
    private var captureTimeout: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []
    private let onEvent: @Sendable (Event, UUID) -> Void
    private let logger = Logger(subsystem: "com.OGS.woyousha", category: "EmbeddedCamera")

    init(onEvent: @escaping @Sendable (Event, UUID) -> Void) {
        self.onEvent = onEvent
        super.init()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.queue.async {
                guard self.wantsRunning else { return }
                self.clearCapture()
                self.report(.interrupted("相机暂时被占用，请结束其他拍摄或视频通话后重试。"))
                self.logger.notice("Capture session interrupted")
            }
        })
        observers.append(center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.queue.async {
                guard self.wantsRunning else { return }
                self.beginStreaming()
            }
        })
        observers.append(center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) { [weak self] notification in
            guard let self else { return }
            let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
            let wasReset = error?.code == .mediaServicesWereReset
            let reason = error?.localizedDescription ?? "未知相机错误"
            self.queue.async {
                guard self.wantsRunning else { return }
                self.clearCapture()
                self.logger.error("Capture session error: \(reason, privacy: .public)")
                if wasReset { self.beginStreaming() }
                else { self.fail("相机暂时无法取景，请点“重试”。") }
            }
        })
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        captureTimeout?.cancel()
    }

    func setRunning(_ running: Bool, generation: UUID) {
        queue.async {
            self.generation = generation
            self.wantsRunning = running
            self.clearCapture()
            if running {
                guard self.configured || self.configure() else { return }
                self.beginStreaming()
            } else {
                if self.session.isRunning { self.session.stopRunning() }
                self.logger.info("Capture session stopped")
            }
        }
    }

    private func configure() -> Bool {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            fail("这台设备没有可用相机，可以从相册选择照片。")
            return false
        }
        do {
            let newInput = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            if session.canSetSessionPreset(.photo) { session.sessionPreset = .photo }
            guard session.canAddInput(newInput) else { fail("无法连接摄像头，请重试。"); return false }
            session.addInput(newInput)
            guard session.canAddOutput(photoOutput) else {
                session.removeInput(newInput)
                fail("无法配置相机输出，请重试。")
                return false
            }
            session.addOutput(photoOutput)
            input = newInput
            configured = true
            logger.info("Camera configured with photo output and native preview")
            return true
        } catch {
            logger.error("Camera input error: \(error.localizedDescription, privacy: .public)")
            fail("摄像头连接失败，请重试。")
            return false
        }
    }

    private func beginStreaming() {
        if !session.isRunning { session.startRunning() }
        if session.isInterrupted {
            report(.interrupted("相机暂时被其他功能占用，请稍后重试。"))
            return
        }
        guard session.isRunning, let connection = photoOutput.connection(with: .video), connection.isEnabled else {
            fail("相机还无法拍照，请在 iPhone 上直接打开后重试。")
            return
        }
        publishReady()
        logger.info("Session running and photo output connection enabled")
    }

    private func publishReady() {
        let opposite: AVCaptureDevice.Position = input?.device.position == .back ? .front : .back
        // 当前拍摄设置未覆盖 maxPhotoDimensions，系统使用格式支持的最小照片尺寸。
        // 读取同一份尺寸来决定取景比例，不把视频预览的宽高比误当作照片比例。
        let dimensions = input?.device.activeFormat.supportedMaxPhotoDimensions.min {
            Int64($0.width) * Int64($0.height) < Int64($1.width) * Int64($1.height)
        }
        let sensorAspectRatio: CGFloat
        if let dimensions, dimensions.width > 0, dimensions.height > 0 {
            sensorAspectRatio = CGFloat(dimensions.width) / CGFloat(dimensions.height)
        } else {
            sensorAspectRatio = CameraSettings.landscapePhotoAspectRatio
        }
        report(.ready(
            hasFlash: input?.device.hasFlash == true,
            canSwitch: AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: opposite) != nil,
            isFront: input?.device.position == .front,
            sensorAspectRatio: sensorAspectRatio
        ))
    }

    func capture(flash: Bool, generation: UUID, startedUptime: TimeInterval) {
        queue.async { [self] in
            guard self.generation == generation else { return }
            guard self.wantsRunning,
                  self.session.isRunning, !self.session.isInterrupted, self.captureID == nil else {
                self.report(.captureFailed("相机还没有准备好，请稍后再拍。"))
                return
            }
            let settings: AVCapturePhotoSettings
            if self.photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            } else {
                settings = AVCapturePhotoSettings()
            }
            // 物品贴纸最终只需 1024px，优先快速响应，减少拍后多帧画质处理的等待。
            settings.photoQualityPrioritization = .speed
            let mode: AVCaptureDevice.FlashMode = flash ? .on : .off
            if self.input?.device.hasFlash == true, self.photoOutput.supportedFlashModes.contains(mode) {
                settings.flashMode = mode
            }
            if let connection = self.photoOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(self.rotationAngle) {
                    connection.videoRotationAngle = self.rotationAngle
                }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = self.input?.device.position == .front
                }
            }
            self.captureID = settings.uniqueID
            self.captureStartedUptime = startedUptime
            self.capturedData = nil
            self.photoOutput.capturePhoto(with: settings, delegate: self)
            self.logger.info("Custom shutter requested photo")
            let id = settings.uniqueID
            let timeout = DispatchWorkItem { [weak self] in
                guard let self, self.captureID == id else { return }
                self.clearCapture()
                self.report(.captureFailed("拍照没有完成，请重新拍摄。"))
            }
            self.captureTimeout = timeout
            self.queue.asyncAfter(deadline: .now() + CameraSettings.captureTimeout, execute: timeout)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let id = photo.resolvedSettings.uniqueID
        let data = error == nil ? photo.fileDataRepresentation() : nil
        queue.async {
            guard self.captureID == id else { return }
            self.capturedData = data
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        let id = resolvedSettings.uniqueID
        let succeeded = error == nil
        // 只把数值带进队列，不跨线程捕获 AVFoundation 的可变设置对象。
        let width = Int(resolvedSettings.photoDimensions.width)
        let height = Int(resolvedSettings.photoDimensions.height)
        queue.async {
            guard self.captureID == id else { return }
            let data = self.capturedData
            let started = self.captureStartedUptime ?? PhotoPerformanceTrace.now
            let timing = PhotoCaptureTiming(
                startedUptime: started,
                milliseconds: (PhotoPerformanceTrace.now - started) * 1000,
                width: width, height: height
            )
            self.clearCapture()
            guard self.wantsRunning else { return }
            if succeeded, let data {
                self.report(.photo(data, timing))
                self.logger.info("Photo data delivered to editor")
            } else {
                self.report(.captureFailed("照片没有生成成功，请再拍一次。"))
            }
        }
    }

    func switchCamera(generation: UUID) {
        queue.async {
            guard self.generation == generation, self.wantsRunning, self.captureID == nil,
                  let oldInput = self.input else { return }
            let position: AVCaptureDevice.Position = oldInput.device.position == .back ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let newInput = try? AVCaptureDeviceInput(device: device) else { self.publishReady(); return }
            self.session.beginConfiguration()
            self.session.removeInput(oldInput)
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.input = newInput
            } else { self.session.addInput(oldInput) }
            self.session.commitConfiguration()
            self.beginStreaming()
        }
    }

    func focus(at point: CGPoint) {
        queue.async {
            guard self.wantsRunning, let device = self.input?.device else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .continuousAutoExposure
                }
            } catch { self.logger.notice("Tap focus unavailable: \(error.localizedDescription, privacy: .public)") }
        }
    }

    func rotate(to angle: CGFloat) { queue.async { self.rotationAngle = angle } }

    private func clearCapture() {
        captureTimeout?.cancel()
        captureTimeout = nil
        captureID = nil
        captureStartedUptime = nil
        capturedData = nil
    }

    private func fail(_ message: String) {
        report(.failed(message))
        wantsRunning = false
        clearCapture()
        if session.isRunning { session.stopRunning() }
    }

    private func report(_ event: Event) { onEvent(event, generation) }
}
