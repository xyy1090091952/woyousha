import SwiftUI
import AVFoundation

/// 原生自定义相机，拍照完成回调只传递一次照片，取消不会重新处理旧图。
struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var camera = CameraController()
    let onCapture: (UIImage) -> Void
    let onChooseLibrary: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                cameraButton("xmark", label: "关闭相机") { dismiss() }
                Spacer()
                Text("给物品拍张照")
                    .font(.system(.headline, design: .rounded))
                Spacer()
                cameraButton(camera.usesFlash ? "bolt.fill" : "bolt.slash", label: camera.usesFlash ? "关闭闪光灯" : "开启闪光灯") {
                    camera.usesFlash.toggle()
                }
                .disabled(!camera.hasFlash || !camera.canCapture)
                .opacity(camera.hasFlash ? 1 : 0.3)
            }
            .padding(.horizontal, 20)

            ZStack {
                CameraPreview(session: camera.session, onFocus: camera.focus, onRotate: camera.rotate)
                if camera.state == .ready {
                    // 轻量取景框，不遮住主体。
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [18, 12]))
                        .padding(30)
                        .allowsHitTesting(false)
                    VStack {
                        Spacer()
                        Text("轻点画面对焦")
                            .font(.caption)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.35), in: Capsule())
                            .padding(.bottom, 20)
                    }
                    .allowsHitTesting(false)
                } else {
                    cameraStatus
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity)

            Text(camera.state == .ready ? "拍完后，自动制作物品贴纸" : "也可以使用已有照片")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))

            HStack {
                cameraButton("photo.on.rectangle", label: "从相册选择") { onChooseLibrary() }
                    .disabled(camera.isCapturing)
                Spacer()
                Button { camera.capture() } label: {
                    ZStack {
                        Circle().strokeBorder(.white, lineWidth: 3)
                            .frame(width: 80, height: 80)
                        Circle().fill(.white)
                            .frame(width: 64, height: 64)
                        if camera.isCapturing { ProgressView().tint(AppTheme.cameraBackground) }
                    }
                }
                .disabled(!camera.canCapture)
                .opacity(camera.canCapture || camera.isCapturing ? 1 : 0.35)
                .accessibilityLabel("拍照")
                Spacer()
                cameraButton("arrow.triangle.2.circlepath.camera", label: "切换前后摄像头") { camera.switchCamera() }
                    .disabled(!camera.canSwitchCamera || !camera.canCapture)
                    .opacity(camera.canSwitchCamera ? 1 : 0.3)
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 20)
        }
        .padding(.top, 12)
        .foregroundStyle(.white)
        .background(AppTheme.cameraBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { camera.start() } else { camera.stop() }
        }
        .onChange(of: camera.capturedImage) { _, image in
            if let image { onCapture(image) }
        }
        .alert("拍照未完成", isPresented: Binding(
            get: { camera.captureError != nil },
            set: { if !$0 { camera.captureError = nil } }
        )) {
            Button("知道了", role: .cancel) { camera.captureError = nil }
        } message: { Text(camera.captureError ?? "") }
    }

    private var cameraStatus: some View {
        VStack(spacing: 18) {
            if camera.state == .preparing {
                ProgressView().tint(.white)
            } else {
                Image(systemName: camera.state == .denied ? "camera.badge.ellipsis" : "camera")
                    .font(.system(size: 36, weight: .light))
            }
            Text(camera.message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            if camera.state == .denied {
                Button("去设置开启相机") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .buttonStyle(.bordered)
            } else if camera.state == .failed || camera.state == .interrupted {
                Button("重新打开") { camera.start() }.buttonStyle(.bordered)
            }
            if camera.state != .preparing {
                Button("从相册选择") { onChooseLibrary() }.buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.cameraBackground)
    }

    private func cameraButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.1), in: Circle())
        }
        .accessibilityLabel(label)
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let onFocus: (CGPoint) -> Void
    let onRotate: (CGFloat) -> Void

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onFocus = onFocus
        view.onRotate = onRotate
        return view
    }

    func updateUIView(_ view: CameraPreviewView, context: Context) { view.setNeedsLayout() }
}

private final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var onFocus: ((CGPoint) -> Void)?
    var onRotate: ((CGFloat) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(focus(_:))))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let angle: CGFloat
        switch window?.windowScene?.interfaceOrientation {
        case .landscapeLeft: angle = 0
        case .landscapeRight: angle = 180
        case .portraitUpsideDown: angle = 270
        default: angle = 90
        }
        if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
        onRotate?(angle)
    }

    @objc private func focus(_ gesture: UITapGestureRecognizer) {
        onFocus?(previewLayer.captureDevicePointConverted(fromLayerPoint: gesture.location(in: self)))
    }
}
