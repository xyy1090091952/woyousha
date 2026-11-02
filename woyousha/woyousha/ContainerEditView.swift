import SwiftUI
import SwiftData

struct ContainerEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var containerToEdit: Container?
    var onDelete: (() -> Void)?
    @State private var name = ""
    @State private var selectedFurnitureImage: String?
    @State private var showsFurnitureCatalog = false
    @State private var showDeleteConfirmation = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    /// 未手选造型的新容器按名称提供预览；旧图标仅用来兼容历史容器。
    private var previewStyleID: String {
        FurnitureConfig.styleID(
            name: name, icon: containerToEdit?.icon ?? FurnitureConfig.defaultIcon,
            savedID: selectedFurnitureImage
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    AppSection("容器名称") {
                        TextField("例如：衣柜、书包、床头柜", text: $name)
                            .accessibilityLabel("容器名称")
                    }
                    furnitureSummary
                    if containerToEdit != nil {
                        Button("删除这个容器", role: .destructive) { showDeleteConfirmation = true }
                            .frame(minHeight: 44)
                        Text("其中的物品会保留，并移到“未分类”。")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .padding(AppTheme.Layout.pagePadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.background)
            .navigationTitle(containerToEdit == nil ? "添加容器" : "编辑容器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button { saveContainer() } label: {
                    Text("保存容器").frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(20)
                .background(AppTheme.surface)
            }
            .onAppear {
                guard !hasLoaded else { return }
                hasLoaded = true
                if let container = containerToEdit {
                    name = container.name
                    // 先锁定当前显示的造型，重命名时不会意外换掉家具。
                    selectedFurnitureImage = FurnitureConfig.styleID(
                        name: container.name, icon: container.icon, savedID: container.furnitureImageName
                    )
                }
            }
            .sheet(isPresented: $showsFurnitureCatalog) {
                FurnitureCatalogPicker(selectedStyleID: previewStyleID, dismissOnSelection: true) { id in
                    selectFurniture(id)
                    return true
                }
                .presentationDetents([.medium, .large])
            }
            .alert("删除容器", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) { deleteContainer() }
            } message: {
                Text("确定删除“\(name)”吗？物品会保留，并移到“未分类”。")
            }
            .alert("操作未完成", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .tint(AppTheme.accent)
    }

    /// 主页面只保留一个造型入口，完整目录复用装修页的搜索抽屉。
    private var furnitureSummary: some View {
        Button { showsFurnitureCatalog = true } label: {
            HStack(spacing: 20) {
                PixelFurnitureView(styleID: previewStyleID, isMirrored: containerToEdit?.isMirrored ?? false)
                    .frame(width: 88, height: 96)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("家具造型")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(FurnitureConfig.get(byImageName: previewStyleID)?.name ?? "纸箱")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.text)
                    Text("更换造型")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.accentText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.inset, in: RoundedRectangle(cornerRadius: AppTheme.Layout.cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("更换家具造型")
        .accessibilityValue(FurnitureConfig.get(byImageName: previewStyleID)?.name ?? "纸箱")
    }

    private func selectFurniture(_ id: String) {
        guard let config = FurnitureConfig.get(byImageName: id) else { return }
        let previousDefaultName = selectedFurnitureImage.flatMap { FurnitureConfig.get(byImageName: $0)?.name }
        selectedFurnitureImage = id
        // 仅新建时跟随默认名称；编辑既有容器与用户自定义名称始终保留。
        if containerToEdit == nil,
           name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name == previousDefaultName {
            name = config.name
        }
    }

    private func deleteContainer() {
        guard let container = containerToEdit else { return }
        do {
            try ContainerRepository.delete(container, in: modelContext)
            onDelete?()
            dismiss()
        } catch { errorMessage = "容器没有删除成功，请重试。" }
    }

    private func saveContainer() {
        do {
            try ContainerRepository.save(
                name: name, furnitureImage: previewStyleID,
                editing: containerToEdit, in: modelContext
            )
            dismiss()
        } catch { errorMessage = "容器没有保存成功，请重试。" }
    }
}

#Preview {
    ContainerEditView()
        .modelContainer(for: [Item.self, Container.self], inMemory: true)
}
