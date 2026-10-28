import SwiftUI
import SwiftData
import PhotosUI

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Container.createdDate) private var containers: [Container]
    @State private var editor: ItemEditorModel
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var openLibraryAfterCamera = false
    private let isEditing: Bool

    init(defaultContainer: Container? = nil, itemToEdit: Item? = nil) {
        isEditing = itemToEdit != nil
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
                    Button("取消") { dismiss() }.disabled(editor.isSaving)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    Button {
                        Task {
                            if await editor.save(in: modelContext) { dismiss() }
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
                    .disabled(!editor.canSave)
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
            .fullScreenCover(isPresented: $showCamera, onDismiss: {
                // 相机先关闭再打开相册，避免两个弹层互相争抢。
                if openLibraryAfterCamera {
                    openLibraryAfterCamera = false
                    showPhotoPicker = true
                }
            }) {
                CameraView(onCapture: { image in
                    editor.selectCameraImage(image)
                    showCamera = false
                }, onChooseLibrary: {
                    openLibraryAfterCamera = true
                    showCamera = false
                })
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photosPickerItem, matching: .images)
            .onChange(of: photosPickerItem) { _, selection in editor.selectPhoto(selection) }
            .onDisappear { editor.cancelPhotoTask() }
            .alert("暂时没有完成", isPresented: Binding(
                get: { editor.errorMessage != nil },
                set: { if !$0 { editor.errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) { editor.errorMessage = nil }
            } message: {
                Text(editor.errorMessage ?? "")
            }
        }
        .tint(AppTheme.accent)
        .interactiveDismissDisabled(editor.isSaving)
    }

    private var photoSection: some View {
        VStack(spacing: 12) {
            ItemPhotoStage(image: editor.image)
                .overlay {
                    if editor.isProcessing {
                        VStack(spacing: 10) {
                            ProgressView().tint(AppTheme.accent)
                            Text(editor.photoMessage).font(.subheadline)
                        }
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                        .accessibilityElement(children: .combine)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if editor.image != nil {
                        Button {
                            editor.removePhoto()
                            photosPickerItem = nil
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
            HStack(spacing: 12) {
                Button { showCamera = true } label: {
                    Label("拍一张", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle())
                Button {
                    // 允许重新选取同一张照片。
                    photosPickerItem = nil
                    showPhotoPicker = true
                } label: {
                    Label("从相册选", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(isPrimary: false))
            }
            Text(editor.photoMessage)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }
}

#Preview {
    AddItemView()
        .modelContainer(for: [Item.self, Container.self], inMemory: true)
}
