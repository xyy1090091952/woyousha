import SwiftUI
import SwiftData

struct ItemDetailView: View {
    let item: Item
    @State private var showEditSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ItemPhotoStage(
                    image: item.imageData.flatMap { UIImage(data: $0) }, height: 300,
                    emptyTitle: "还没有照片", emptySubtitle: "可以在编辑里补一张"
                )
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.name)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.text)
                        .textSelection(.enabled)
                    Label(item.category.rawValue, systemImage: item.category.symbol)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.accentText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.inset, in: Capsule())
                }
                AppSection("收纳信息") {
                    informationRow("存放容器", value: item.container?.name ?? "未分类", symbol: "archivebox")
                    Divider().overlay(AppTheme.line)
                    informationRow("具体位置", value: item.location.isEmpty ? "暂未填写" : item.location, symbol: "mappin")
                    Divider().overlay(AppTheme.line)
                    informationRow("数量", value: "\(item.quantity) 件", symbol: "square.stack")
                }
                if !item.note.isEmpty {
                    AppSection("小备注") {
                        Text(item.note)
                            .foregroundStyle(AppTheme.secondaryText)
                            .textSelection(.enabled)
                    }
                }
                Text("收好于 \(item.createdDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .padding(AppTheme.Layout.pagePadding)
        }
        .background(AppTheme.background)
        .navigationTitle("物品")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("编辑") { showEditSheet = true }
            }
        }
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .tint(AppTheme.accentText)
        .sheet(isPresented: $showEditSheet) { AddItemView(itemToEdit: item) }
    }

    private func informationRow(_ title: String, value: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(AppTheme.accentText)
                .frame(width: 22)
            Text(title).foregroundStyle(AppTheme.secondaryText)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: Item(name: "蓝色保温杯", quantity: 1, location: "第二层"))
    }
    .modelContainer(for: [Item.self, Container.self], inMemory: true)
}
