import SwiftUI
import SwiftData
import PhotosUI

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Container.createdDate) private var containers: [Container]
    @State private var editor: ItemEditorModel
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var isCameraMode: Bool
    @State private var hasCreatedCameraPreview: Bool
    @State private var showPhotoPicker = false
    @State private var camera = CameraController()
    @State private var hasLoadedInitialImage = false
    #if DEBUG
    @State private var showPhotoTiming = false
    #endif
    private let initialImage: UIImage?
    private let isEditing: Bool

    init(defaultContainer: Container? = nil, itemToEdit: Item? = nil, initialImage: UIImage? = nil) {
        isEditing = itemToEdit != nil
        self.initialImage = initialImage
        let startsWithCamera = itemToEdit == nil && initialImage == nil
        _isCameraMode = State(initialValue: startsWithCamera)
        _hasCreatedCameraPreview = State(initialValue: startsWithCamera)
        _editor = State(initialValue: ItemEditorModel(item: itemToEdit, defaultContainer: defaultContainer))
    }

    var body: some View {
        @Bindable var editor = editor
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isEditing ? "让物品信息更完整" : "收好生活里的小东西")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.text)
                        Text("拍张照片，记下它放在哪里。")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    photoSection
                    AppSection("这是什么") {
                        TextField("物品名称，例如：蓝色保温杯", text: $editor.draft.name)
                            .font(.body)
                            .submitLabel(.done)
                            .padding(14)
                            .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 14))
                            .accessibilityLabel("物品名称")
                        Picker("分类", selection: $editor.draft.category) {
                            ForEach(Category.allCases, id: \.self) { category in
                                Label(category.rawValue, systemImage: category.symbol).tag(category)
                            }
                        }
                    }
                    AppSection("放在哪里") {
                        Picker("存放容器", selection: $editor.draft.container) {
                            Text("未分类").tag(Optional<Container>.none)
                            ForEach(containers) { container in
                                Text(container.name).tag(Optional(container))
                            }
                        }
                        Divider().overlay(AppTheme.line)
                        TextField("具体位置，例如：第二层", text: $editor.draft.location)
                            .accessibilityLabel("具体位置")
                        Divider().overlay(AppTheme.line)
                        Stepper(value: $editor.draft.quantity, in: AppTheme.Layout.quantityRange) {
                            HStack {
                                Text("数量")
                                Spacer()
                                Text("\(editor.draft.quantity)")
                                    .monospacedDigit()
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    AppSection("小备注") {
                        TextField("颜色、用途，或其他想记住的事（选填）", text: $editor.draft.note, axis: .vertical)
                            .lineLimit(3...6)
                            .accessibilityLabel("备注")
                    }
                }
                .padding(AppTheme.Layout.pagePadding)
                .disabled(editor.isSaving)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background)
            .foregroundStyle(AppTheme.text)
            .navigationTitle(isEditing ? "编辑物品" : "添加物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        camera.setActive(false)
                        dismiss()
                    }.disabled(editor.isSaving)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    Button {
                        camera.setActive(false)
                        Task {
                            if await editor.save(in: modelContext) { dismiss() }
                            else if isCameraMode { camera.setActive(true) }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if editor.isSaving { ProgressView().tint(AppTheme.onAccent) }
                            Text(editor.isSaving ? "正在保存…" : (isEditing ? "保存修改" : "收好这件物品"))
                            if !editor.isSaving { Image(systemName: "checkmark") }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppButtonStyle())
                    .disabled(!editor.canSave || camera.isCapturing)
                    if editor.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("填写物品名称后就可以保存")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .padding(.horizontal, AppTheme.Layout.pagePadding)
                .padding(.vertical, 12)
                .background(AppTheme.surface)
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photosPickerItem, matching: .images)
            .onChange(of: photosPickerItem) { _, selection in
                guard selection != nil else { return }
                isCameraMode = false
                camera.setActive(false)
                editor.selectPhoto(selection)
            }
            .onChange(of: showPhotoPicker) { _, isPresented in
                if !isPresented, isCameraMode, scenePhase == .active { camera.setActive(true) }
            }
            .onChange(of: isCameraMode) { _, isActive in
                if isActive { hasCreatedCameraPreview = true }
            }
            .onChange(of: camera.photo?.id) { _, _ in
                guard let photo = camera.consumePhoto() else { return }
                // 拍摄结果原位替换取景，只启动一次本地抠图，不另开系统确认页面。
                isCameraMode = false
                camera.setActive(false)
                editor.selectCameraData(photo.data, captureTiming: photo.timing)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { camera.setActive(false) }
                else if phase == .active, isCameraMode, !showPhotoPicker, !editor.isSaving {
                    if camera.state == .denied || camera.state == .restricted { camera.retry() }
                    else { camera.setActive(true) }
                }
                // 权限弹窗导致的 inactive 不停止会话，避免授权时启停互相打断。
            }
            .onDisappear {
                camera.setActive(false)
                editor.cancelPhotoTask()
            }
            .alert("暂时没有完成", isPresented: Binding(
                get: { editor.errorMessage != nil },
                set: { if !$0 { editor.errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) { editor.errorMessage = nil }
            } message: {
                Text(editor.errorMessage ?? "")
            }
            .alert("拍摄未完成", isPresented: Binding(
                get: { camera.captureError != nil },
                set: { if !$0 { camera.captureError = nil } }
            )) {
                Button("知道了", role: .cancel) { camera.captureError = nil }
            } message: { Text(camera.captureError ?? "") }
        }
        .tint(AppTheme.accent)
        #if DEBUG
        .sheet(isPresented: $showPhotoTiming) {
            if let performance = editor.lastPhotoPerformance {
                PhotoProcessingTimingView(snapshot: performance)
            }
        }
        #endif
        .interactiveDismissDisabled(editor.isSaving)
        .task {
            // 从拍摄流程进入时仅处理一次照片，表单刷新不重新抠图。
            guard !hasLoadedInitialImage else { return }
            hasLoadedInitialImage = true
            if let initialImage { editor.selectCameraImage(initialImage) }
        }
    }

    private var usesCameraSizedStage: Bool { isCameraMode || hasCreatedCameraPreview }

    @ViewBuilder
    private var photoStage: some View {
        if usesCameraSizedStage {
            // 同一份照片比例贯穿取景和处理结果。宽度随手机变化，平板上限制最大宽度。
            photoStageContent
                .aspectRatio(camera.photoAspectRatio, contentMode: .fit)
                .frame(maxWidth: CameraSettings.maximumPreviewWidth)
                .frame(maxWidth: .infinity)
        } else {
            photoStageContent.frame(height: AppTheme.Layout.photoHeight)
        }
    }

    private var photoStageContent: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            ZStack {
                if isCameraMode || hasCreatedCameraPreview {
                    // 拍完只隐藏取景，保留 UIView/预览层的身份；后台停止相机，
                    // 避免在贴纸回填的关键路径上同步拆除 AVCaptureVideoPreviewLayer。
                    CameraView(camera: camera, isActive: isCameraMode)
                        .frame(height: height)
                        .opacity(isCameraMode ? 1 : 0)
                        .allowsHitTesting(isCameraMode)
                        .accessibilityHidden(!isCameraMode)
                }
                if !isCameraMode {
                    ItemPhotoStage(image: editor.image, height: height)
                }
            }
                .frame(width: geometry.size.width, height: height)
                .overlay(alignment: .bottom) {
                    if editor.isProcessing {
                        VStack(spacing: 8) {
                            HStack(spacing: 10) {
                                ProgressView().tint(AppTheme.accent)
                                Text(editor.photoMessage).font(.subheadline.weight(.semibold))
                            }
                            if editor.processingIsTakingLong {
                                Text("处理还在进行，你可以先填写下面的信息")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                                if editor.canKeepOriginalPhoto {
                                    Button("先用原图") { editor.keepOriginalPhoto() }
                                        .font(.subheadline.weight(.semibold))
                                        .frame(minHeight: 44)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                        .padding(10)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if editor.image != nil && !isCameraMode {
                        Button {
                            editor.removePhoto()
                            photosPickerItem = nil
                            isCameraMode = true
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.secondaryText)
                                .frame(width: 44, height: 44)
                                .background(AppTheme.surface, in: Circle())
                        }
                        .padding(10)
                        .accessibilityLabel("移除照片")
                    }
                }
        }
    }

    private var photoSection: some View {
        VStack(spacing: 12) {
            photoStage
            HStack(spacing: 12) {
                Button {
                    if isCameraMode { camera.capture() }
                    else {
                        editor.cancelPhotoTask()
                        isCameraMode = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        if camera.isCapturing { ProgressView().tint(AppTheme.onAccent) }
                        else { Image(systemName: "camera.fill") }
                        Text(camera.isCapturing ? "拍摄中…" : (isCameraMode ? camera.shutterTitle : "重新拍"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle())
                .disabled(isCameraMode && !camera.canUseShutter)
                Button {
                    // 允许重新选取同一张照片。
                    editor.cancelPhotoTask()
                    camera.setActive(false)
                    photosPickerItem = nil
                    showPhotoPicker = true
                } label: {
                    Label("从相册选", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(isPrimary: false))
                .disabled(camera.isCapturing)
            }
            Text(isCameraMode ? "照片选填，在这里拍照后自动制作贴纸" : editor.photoMessage)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            #if DEBUG
            if editor.lastPhotoPerformance != nil {
                Button("查看处理用时") { showPhotoTiming = true }
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: 44)
            }
            #endif
        }
    }
}

#Preview {
    AddItemView()
        .modelContainer(for: [Item.self, Container.self], inMemory: true)
}
