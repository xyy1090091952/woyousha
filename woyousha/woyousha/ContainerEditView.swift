import SwiftUI
import SwiftData

struct ContainerEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var containerToEdit: Container?
    var onDelete: (() -> Void)?
    @State private var name = ""
    @State private var icon = "cube.box"
    @State private var selectedFurnitureImage: String?
    @State private var showDeleteConfirmation = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    private static let availableIcons = [
        "cube.box", "archivebox", "shippingbox", "cabinet", "refrigerator",
        "washer", "cart", "basket", "bag", "backpack", "suitcase",
        "books.vertical", "lamp.desk", "bed.double", "sofa", "chair", "hanger"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        if let selectedFurnitureImage {
                            Image(selectedFurnitureImage)
                                .resizable().scaledToFit().frame(height: 120)
                        } else {
                            Image(systemName: icon)
                                .font(.system(size: 56, weight: .light))
                                .foregroundStyle(AppTheme.accent)
                                .frame(height: 120)
                        }
                        Text(name.isEmpty ? "为物品准备一个家" : name)
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(AppTheme.inset, in: RoundedRectangle(cornerRadius: 32))

                    AppSection("容器名称") {
                        TextField("例如：衣柜、书包、床头柜", text: $name)
                            .accessibilityLabel("容器名称")
                    }
                    AppSection("列表里的图标") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 12) {
                            ForEach(Self.availableIcons, id: \.self) { symbol in
                                Button { icon = symbol } label: {
                                    Image(systemName: symbol)
                                        .font(.system(size: 22))
                                        .frame(width: 48, height: 48)
                                        .foregroundStyle(icon == symbol ? AppTheme.onAccent : AppTheme.accent)
                                        .background(icon == symbol ? AppTheme.accent : AppTheme.inset, in: RoundedRectangle(cornerRadius: 16))
                                }
                                .accessibilityLabel("图标 \(symbol)")
                                .accessibilityAddTraits(icon == symbol ? .isSelected : [])
                            }
                        }
                    }
                    AppSection("小房间里的造型") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                furnitureChoice(imageName: nil, title: "默认图标")
                                ForEach(FurnitureConfig.all) { config in
                                    furnitureChoice(imageName: config.imageName, title: config.name)
                                }
                            }
                        }
                        Text("创建后，在装修页面把它放进房间。")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
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
                    icon = container.icon
                    selectedFurnitureImage = container.furnitureImageName
                }
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

    private func furnitureChoice(imageName: String?, title: String) -> some View {
        Button { selectedFurnitureImage = imageName } label: {
            VStack(spacing: 8) {
                Group {
                    if let imageName {
                        Image(imageName).resizable().scaledToFit().padding(10)
                    } else {
                        Image(systemName: icon).font(.system(size: 30)).foregroundStyle(AppTheme.accent)
                    }
                }
                .frame(width: 80, height: 80)
                .background(AppTheme.inset, in: RoundedRectangle(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(selectedFurnitureImage == imageName ? AppTheme.accent : .clear, lineWidth: 2)
                }
                Text(title).font(.caption).foregroundStyle(AppTheme.text)
            }
        }
        .accessibilityAddTraits(selectedFurnitureImage == imageName ? .isSelected : [])
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
                name: name, icon: icon, furnitureImage: selectedFurnitureImage,
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
