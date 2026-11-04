import SwiftUI
import SwiftData

/// 信息页只编辑草稿。新增只需名称，数量和备注选填；旧物品的存放信息仍可维护。
struct ItemInformationPage: View {
    @Bindable var editor: ItemEditorModel
    let isEditing: Bool
    var onRetake: (() -> Void)?
    let onPickPhoto: () -> Void
    let onSave: () -> Void
    @Query(sort: \Container.createdDate) private var containers: [Container]
    #if DEBUG
    @State private var showPhotoTiming = false
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isEditing ? "让物品信息更完整" : "给它起个名字")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text(isEditing ? "修改完成后保存即可。" : "保存后会放进「未分类」，之后可以拖进家具里。")
                        .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                }
                photoSection
                AppSection("这是什么") {
                    TextField("物品名称，例如：蓝色保温杯", text: $editor.draft.name)
                        .font(.body).submitLabel(.done).padding(14)
                        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityLabel("物品名称")
                    Stepper(value: $editor.draft.quantity, in: AppTheme.Layout.quantityRange) {
                        HStack {
                            Text("数量")
                            Spacer()
                            Text("\(editor.draft.quantity)").monospacedDigit().fontWeight(.semibold)
                        }
                    }
                }
                AppSection("小备注") {
                    TextField("颜色、用途，或其他想记住的事（选填）", text: $editor.draft.note, axis: .vertical)
                        .lineLimit(3...6).accessibilityLabel("备注")
                }
                if isEditing {
                    AppSection("放在哪里") {
                        Picker("存放容器", selection: $editor.draft.container) {
                            Text("未分类").tag(Optional<Container>.none)
                            ForEach(containers) { Text($0.name).tag(Optional($0)) }
                        }
                        Divider().overlay(AppTheme.line)
                        TextField("具体位置，例如：第二层", text: $editor.draft.location)
                            .accessibilityLabel("具体位置")
                    }
                }
            }
            .padding(AppTheme.Layout.pagePadding)
            .disabled(editor.isSaving)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.background).foregroundStyle(AppTheme.text)
        .navigationTitle(isEditing ? "编辑物品" : "添加物品 · 名称")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .navigationBarBackButtonHidden(editor.isSaving)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                Button(action: onSave) {
                    HStack(spacing: 10) {
                        if editor.isSaving { ProgressView().tint(AppTheme.onAccent) }
                        Text(editor.isSaving ? "正在保存…" : (isEditing ? "保存修改" : "收好这件物品"))
                        if !editor.isSaving { Image(systemName: "checkmark") }
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle()).disabled(!editor.canSave)
                Text(saveHint).font(.caption).foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.horizontal, AppTheme.Layout.pagePadding).padding(.vertical, 12)
            .background(AppTheme.surface)
        }
        #if DEBUG
        .sheet(isPresented: $showPhotoTiming) {
            if let performance = editor.lastPhotoPerformance {
                PhotoProcessingTimingView(snapshot: performance)
            }
        }
        #endif
    }

    private var saveHint: String {
        if editor.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "填写名称后就可以保存"
        }
        if editor.isProcessing { return "贴纸正在处理，完成后就可以保存" }
        return isEditing ? "修改只在保存后生效" : "会放入「未分类」"
    }

    private var photoSection: some View {
        VStack(spacing: 10) {
            ItemPhotoStage(image: editor.image, height: AppTheme.Layout.photoHeight)
                .overlay(alignment: .bottom) {
                    if editor.isProcessing {
                        HStack(spacing: 10) {
                            ProgressView().tint(AppTheme.accentText)
                            Text(editor.photoMessage).font(.subheadline.weight(.semibold))
                        }
                        .padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .padding(10)
                    }
                }
            HStack(spacing: 20) {
                if let onRetake {
                    Button(action: onRetake) {
                        Label(editor.image == nil ? "拍一张" : "重新拍", systemImage: "camera")
                    }
                }
                Button(action: onPickPhoto) { Label("更换照片", systemImage: "photo.on.rectangle") }
                Spacer(minLength: 0)
                if editor.image != nil {
                    Button("移除") { editor.removePhoto() }.accessibilityLabel("移除照片")
                }
            }
            .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            if editor.processingIsTakingLong, editor.canKeepOriginalPhoto {
                Button("先用原图") { editor.keepOriginalPhoto() }
                    .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
            } else if !editor.isProcessing {
                Text(editor.photoMessage).font(.caption).foregroundStyle(AppTheme.secondaryText)
            }
            #if DEBUG
            if editor.lastPhotoPerformance != nil {
                Button("查看处理用时") { showPhotoTiming = true }.font(.caption).frame(minHeight: 44)
            }
            #endif
        }
    }
}

#Preview {
    NavigationStack {
        ItemInformationPage(editor: ItemEditorModel(item: nil),
            isEditing: false, onRetake: {}, onPickPhoto: {}, onSave: {})
    }
    .modelContainer(for: [Item.self, Container.self], inMemory: true)
}
