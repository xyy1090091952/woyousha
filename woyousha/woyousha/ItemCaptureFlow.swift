import SwiftUI
import PhotosUI

/// 首页录入顺序：相机 → 使用照片 → 填写信息。整个流程共用一个全屏窗口。
/// 不先展示空表单再叠加相机，避免多层弹窗转场和草稿被重复创建。
struct ItemCaptureFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let defaultContainer: Container?
    @State private var access = CameraController()
    @State private var stage: Stage = .preparing
    @State private var capturedImage: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showLibrary = false
    @State private var errorMessage: String?

    private enum Stage { case preparing, camera, fallback, loadingPhoto, editor }

    var body: some View {
        ZStack {
            switch stage {
            case .camera:
                CameraView(onCapture: { image in
                    capturedImage = image
                    stage = .editor
                }, onCancel: {
                    dismiss()
                }, onError: { message in
                    errorMessage = message
                    stage = .fallback
                })
                .ignoresSafeArea()
            case .editor:
                AddItemView(defaultContainer: defaultContainer, initialImage: capturedImage)
            case .preparing, .loadingPhoto:
                VStack(spacing: 18) {
                    ProgressView().tint(AppTheme.accent)
                    Text(stage == .preparing ? "正在打开相机…" : "正在读取照片…")
                        .font(.system(.headline, design: .rounded))
                    Button("取消") { dismiss() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background)
            case .fallback:
                VStack(spacing: 22) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.blue)
                    Text(access.errorMessage.isEmpty ? "暂时无法拍照" : access.errorMessage)
                        .multilineTextAlignment(.center)
                    if access.accessError == .denied {
                        Button("打开相机权限") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }.buttonStyle(AppButtonStyle())
                    }
                    Button("从相册选") { showLibrary = true }.buttonStyle(AppButtonStyle())
                    Button("先填写信息") { stage = .editor }.buttonStyle(AppButtonStyle(isPrimary: false))
                    Button("取消") { dismiss() }
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background)
            }
        }
        .tint(AppTheme.accent)
        .task { await openCamera() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, stage == .fallback, access.accessError == .denied {
                Task { await openCamera() }
            }
        }
        .photosPicker(isPresented: $showLibrary, selection: $pickerItem, matching: .images)
        .task(id: pickerItem) {
            guard let pickerItem else { return }
            stage = .loadingPhoto
            do {
                guard let data = try await pickerItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { throw PhotoError.unreadable }
                guard !Task.isCancelled else { return }
                capturedImage = image
                stage = .editor
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = "没有读到照片，请重新选择。"
                stage = .fallback
            }
        }
        .alert("暂时没有完成", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func openCamera() async {
        guard stage == .preparing || stage == .fallback else { return }
        let authorized = await access.prepare()
        guard !Task.isCancelled else { return }
        stage = authorized ? .camera : .fallback
    }

    private enum PhotoError: Error { case unreadable }
}
