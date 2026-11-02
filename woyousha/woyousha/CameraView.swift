import SwiftUI
import AVFoundation
import UIKit

/// 只显示 App 内的实时取景，不打开系统相机页面。快门和相册由录入页面提供。
struct CameraView: View {
    let camera: CameraController
    var isActive = true

    var body: some View {
        ZStack {
            CameraPreview(camera: camera)
            if camera.state == .ready {
                VStack {
                    HStack {
                        Spacer()
                        if camera.hasFlash {
                            cameraButton(camera.usesFlash ? "bolt.fill" : "bolt.slash.fill", label: "切换闪光灯") {
                                camera.usesFlash.toggle()
                            }
                            .disabled(camera.isCapturing)
                        }
                        if camera.canSwitchCamera {
                            cameraButton("arrow.triangle.2.circlepath.camera", label: "切换摄像头") { camera.switchCamera() }
                                .disabled(camera.isCapturing)
                        }
                    }
                    Spacer()
                    Text("轻点画面对焦")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.black.opacity(0.4), in: Capsule())
                        .allowsHitTesting(false)
                }
                .padding(12)
            } else {
                VStack(spacing: 14) {
                    if camera.state == .preparing {
                        ProgressView().tint(AppTheme.blue)
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(AppTheme.blue)
                    }
                    Text(camera.message)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.text)
                    if camera.state == .denied {
                        Button("打开设置") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                        .buttonStyle(AppButtonStyle(isPrimary: false))
                    } else if case .failed = camera.state {
                        Button("重试") { camera.retry() }.buttonStyle(AppButtonStyle(isPrimary: false))
                    } else if case .interrupted = camera.state {
                        Button("重试") { camera.retry() }.buttonStyle(AppButtonStyle(isPrimary: false))
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.blueInset)
            }
        }
        .background(AppTheme.cameraBackground)
        .clipShape(RoundedRectangle(cornerRadius: CameraSettings.cornerRadius))
        .overlay { RoundedRectangle(cornerRadius: CameraSettings.cornerRadius).strokeBorder(AppTheme.blue.opacity(0.2), lineWidth: 2) }
        .onAppear { if isActive { camera.setActive(true) } }
        .onChange(of: isActive) { _, active in camera.setActive(active) }
        .onDisappear { camera.setActive(false) }
        .accessibilityLabel("物品拍照取景窗口")
    }

    private func cameraButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct CameraPreview: UIViewRepresentable {
    let camera: CameraController

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.camera = camera
        camera.attach(to: view.previewLayer)
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.isFrontCamera = camera.isFrontCamera
        view.updateConnection()
    }

    static func dismantleUIView(_ view: PreviewView, coordinator: ()) {
        view.camera?.detach(from: view.previewLayer)
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    weak var camera: CameraController?
    var isFrontCamera = false
    private let focusIndicator = CALayer()
    private var focusTimeout: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        focusIndicator.borderColor = UIColor.systemYellow.cgColor
        focusIndicator.borderWidth = 2
        focusIndicator.cornerRadius = 8
        focusIndicator.opacity = 0
        layer.addSublayer(focusIndicator)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(focus(_:))))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateConnection()
    }

    func updateConnection() {
        let angle: CGFloat
        switch window?.windowScene?.interfaceOrientation {
        case .landscapeLeft: angle = 0
        case .landscapeRight: angle = 180
        case .portraitUpsideDown: angle = 270
        default: angle = CameraSettings.portraitRotation
        }
        camera?.rotate(to: angle)
        // 相机停止时不改连接属性；普通表单刷新也不重复设置相同方向和镜像。
        guard camera?.state == .ready else { return }
        if let connection = previewLayer.connection {
            if connection.videoRotationAngle != angle, connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            if connection.isVideoMirroringSupported {
                if connection.automaticallyAdjustsVideoMirroring {
                    connection.automaticallyAdjustsVideoMirroring = false
                }
                if connection.isVideoMirrored != isFrontCamera {
                    connection.isVideoMirrored = isFrontCamera
                }
            }
        }
    }

    @objc private func focus(_ gesture: UITapGestureRecognizer) {
        guard camera?.canCapture == true else { return }
        let point = gesture.location(in: self)
        camera?.focus(at: previewLayer.captureDevicePointConverted(fromLayerPoint: point))
        focusTimeout?.cancel()
        let size = CameraSettings.focusIndicatorSize
        focusIndicator.frame = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
        focusIndicator.opacity = 1
        let timeout = DispatchWorkItem { [weak self] in self?.focusIndicator.opacity = 0 }
        focusTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + CameraSettings.focusIndicatorDuration, execute: timeout)
    }
}
