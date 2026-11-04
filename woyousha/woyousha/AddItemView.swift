import SwiftUI
import SwiftData
import PhotosUI

/// 新建分成拍摄和信息两页；整个流程共用一份草稿，返回重拍不会丢失已填内容。
struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var editor: ItemEditorModel
    @State private var camera = CameraController()
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showsDetails: Bool
    @State private var isRetakingForEdit = false
    @State private var hasLoadedInitialImage = false
    private let initialImage: UIImage?
    private let isEditing: Bool
    private let onSaved: (() -> Void)?

    init(itemToEdit: Item? = nil, initialImage: UIImage? = nil, onSaved: (() -> Void)? = nil) {
        isEditing = itemToEdit != nil
        self.initialImage = initialImage
        self.onSaved = onSaved
        _showsDetails = State(initialValue: initialImage != nil)
        // 新物品始终进入未分类；编辑旧物品沿用它原来的归属。
        _editor = State(initialValue: ItemEditorModel(item: itemToEdit))
    }

    var body: some View {
        NavigationStack {
            Group {
                if isEditing {
                    details.navigationDestination(isPresented: $isRetakingForEdit) { capturePage }
                }
                else {
                    capturePage
                        .navigationDestination(isPresented: $showsDetails) { details }
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photosPickerItem, matching: .images)
            .onChange(of: photosPickerItem) { _, selection in
                guard let selection else { return }
                camera.setActive(false)
                editor.selectPhoto(selection)
                if isEditing { isRetakingForEdit = false }
                else { showsDetails = true }
            }
            .onChange(of: camera.photo?.id) { _, _ in
                guard let photo = camera.consumePhoto() else { return }
                camera.setActive(false)
                editor.selectCameraData(photo.data, captureTiming: photo.timing)
                if isEditing { isRetakingForEdit = false }
                else { showsDetails = true }
            }
            .onChange(of: showsDetails) { _, _ in updateCamera() }
            .onChange(of: isRetakingForEdit) { _, _ in updateCamera() }
            .onChange(of: showPhotoPicker) { _, _ in updateCamera() }
            .onChange(of: scenePhase) { _, phase in
                // 权限弹窗导致的 inactive 不启停会话，避免授权过程互相打断。
                if phase != .inactive { updateCamera() }
            }
            .alert("暂时没有完成", isPresented: Binding(
                get: { editor.errorMessage != nil },
                set: { if !$0 { editor.errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) { editor.errorMessage = nil }
            } message: { Text(editor.errorMessage ?? "") }
            .alert("拍摄未完成", isPresented: Binding(
                get: { camera.captureError != nil },
                set: { if !$0 { camera.captureError = nil } }
            )) {
                Button("知道了", role: .cancel) { camera.captureError = nil }
            } message: { Text(camera.captureError ?? "") }
        }
        .tint(AppTheme.accentText)
        .interactiveDismissDisabled(editor.isSaving || camera.isCapturing)
        .task {
            guard !hasLoadedInitialImage else { return }
            hasLoadedInitialImage = true
            if let initialImage { editor.selectCameraImage(initialImage) }
        }
        .onDisappear {
            // 仅在整个录入窗口关闭时取消抠图；进入信息页仍继续处理同一张照片。
            camera.setActive(false)
            editor.cancelPhotoTask()
        }
    }

    private var capturePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("先给它拍张照")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("让物品完整入镜，拍好后再记下名字。")
                        .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                }
                CameraView(camera: camera, isActive: isOnCapturePage && !showPhotoPicker)
                    .aspectRatio(camera.photoAspectRatio, contentMode: .fit)
                    .frame(maxWidth: CameraSettings.maximumPreviewWidth)
                    .frame(maxWidth: .infinity)
                Text("照片会自动做成物品贴纸")
                    .font(.caption).foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity)
            }
            .padding(AppTheme.Layout.pagePadding)
        }
        .background(AppTheme.background)
        .foregroundStyle(AppTheme.text)
        .navigationTitle(isEditing ? "更换物品照片" : "添加物品 · 拍照")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbar { cancelButton }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 12) {
                Button { camera.capture() } label: {
                    HStack(spacing: 8) {
                        if camera.isCapturing { ProgressView().tint(AppTheme.onAccent) }
                        else { Image(systemName: "camera.fill") }
                        Text(camera.isCapturing ? "拍摄中…" : camera.shutterTitle)
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle())
                .disabled(!camera.canUseShutter)
                HStack {
                    Button { pickPhoto() } label: {
                        Label("从相册选", systemImage: "photo.on.rectangle")
                    }
                    Spacer()
                    Button(isEditing ? "返回信息" : "跳过拍照") {
                        if isEditing { isRetakingForEdit = false }
                        else { showsDetails = true }
                    }
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
                .disabled(camera.isCapturing)
            }
            .padding(.horizontal, AppTheme.Layout.pagePadding)
            .padding(.vertical, 12)
            .background(AppTheme.surface)
        }
        .onAppear { updateCamera() }
        .onDisappear { camera.setActive(false) }
    }

    private var details: some View {
        ItemInformationPage(editor: editor, isEditing: isEditing,
            onRetake: {
                if isEditing { isRetakingForEdit = true }
                else { showsDetails = false }
            },
            onPickPhoto: pickPhoto, onSave: save)
            .toolbar { cancelButton }
    }

    @ToolbarContentBuilder private var cancelButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("取消") { dismiss() }.disabled(editor.isSaving || camera.isCapturing)
        }
    }

    private func updateCamera() {
        let active = isOnCapturePage && !showPhotoPicker && scenePhase == .active
        if active, camera.state == .denied || camera.state == .restricted { camera.retry() }
        else { camera.setActive(active) }
    }

    private var isOnCapturePage: Bool { isEditing ? isRetakingForEdit : !showsDetails }

    private func pickPhoto() {
        camera.setActive(false)
        photosPickerItem = nil
        showPhotoPicker = true
    }

    private func save() {
        Task {
            if await editor.save(in: modelContext) {
                onSaved?()
                dismiss()
            }
        }
    }
}

#Preview {
    AddItemView()
        .modelContainer(for: [Item.self, Container.self], inMemory: true)
}
