import SwiftUI

/// 固定在画布外的操作面板：位置和字号不随家具缩放，所有按钮至少 44pt 高。
struct FurnitureInspector: View {
    let container: Container
    let onAction: (FurniturePlacementRepository.Action) -> Bool
    let onPreviewScale: (Double?) -> Void
    let onClose: () -> Void
    @State private var scaleDraft: Double
    @State private var showStyles = false

    init(container: Container, onAction: @escaping (FurniturePlacementRepository.Action) -> Bool,
         onPreviewScale: @escaping (Double?) -> Void, onClose: @escaping () -> Void) {
        self.container = container
        self.onAction = onAction
        self.onPreviewScale = onPreviewScale
        self.onClose = onClose
        _scaleDraft = State(initialValue: container.scale.isFinite ? min(max(container.scale, 0.5), 2) : 1)
    }

    private var styleID: String {
        FurnitureConfig.styleID(name: container.name, icon: container.icon, savedID: container.furnitureImageName)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                PixelFurnitureView(styleID: styleID, isMirrored: container.isMirrored)
                    .frame(width: 50, height: 56)
                    .padding(6)
                    .background(AppTheme.inset, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text(container.name)
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .lineLimit(1)
                    Text("造型：\(FurnitureConfig.get(byImageName: styleID)?.name ?? "收纳箱")")
                        .font(.caption).foregroundStyle(AppTheme.secondaryText)
                }
                Spacer(minLength: 4)
                Button(action: onClose) {
                    Image(systemName: "checkmark").frame(width: 44, height: 44)
                }
                .buttonStyle(ToyIconButtonStyle(isPrimary: true))
                .accessibilityLabel("完成家具调整")
            }

            HStack(spacing: 8) {
                actionButton("造型", symbol: "paintpalette.fill", selected: showStyles) { showStyles.toggle() }
                actionButton("镜像", symbol: "arrow.left.and.right", selected: container.isMirrored) { _ = onAction(.mirror) }
                actionButton("前移", symbol: "square.3.layers.3d.top.filled") { _ = onAction(.forward) }
                actionButton("后移", symbol: "square.3.layers.3d.bottom.filled") { _ = onAction(.backward) }
                actionButton("收起", symbol: "archivebox", destructive: true) { _ = onAction(.store) }
            }

            HStack(spacing: 12) {
                Button {
                    scaleDraft = max(RoomConfig.furnitureRange.lowerBound, scaleDraft - 0.1)
                    commitScale()
                } label: { Image(systemName: "minus").frame(width: 44, height: 44) }
                .buttonStyle(.plain)
                .accessibilityLabel("缩小家具")
                Slider(value: $scaleDraft, in: RoomConfig.furnitureRange, onEditingChanged: { editing in
                    if !editing {
                        commitScale()
                    }
                })
                .accessibilityLabel("家具大小")
                .accessibilityValue("\(Int(scaleDraft * 100))%")
                Button {
                    scaleDraft = min(RoomConfig.furnitureRange.upperBound, scaleDraft + 0.1)
                    commitScale()
                } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                .buttonStyle(.plain)
                .accessibilityLabel("放大家具")
                Text("\(Int(scaleDraft * 100))%")
                    .monospacedDigit().font(.caption.weight(.bold)).frame(width: 44)
            }
            .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 14))
            .onChange(of: scaleDraft) { _, value in onPreviewScale(value) }

        }
        .padding(16)
        .foregroundStyle(AppTheme.text)
        .tint(AppTheme.accentText)
        .background(AppTheme.surface)
        .overlay(alignment: .top) { Rectangle().fill(AppTheme.line).frame(height: 2) }
        .sheet(isPresented: $showStyles) {
            FurnitureCatalogPicker(selectedStyleID: styleID) { id in
                onAction(.style(id))
            }
            .presentationDetents([.medium, .large])
        }
        .onDisappear { onPreviewScale(nil) }
    }

    private func commitScale() {
        if !onAction(.scale(scaleDraft)) { scaleDraft = container.scale }
        onPreviewScale(nil)
    }

    private func actionButton(_ title: String, symbol: String, selected: Bool = false,
                              destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 19, weight: .semibold))
                Text(title).font(.system(.caption, design: .rounded, weight: .bold))
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(destructive ? Color.red : (selected ? AppTheme.accentText : AppTheme.blue))
            .background(selected ? AppTheme.inset : AppTheme.blueInset, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title == "前移" ? "图层向前一层" : (title == "后移" ? "图层向后一层" : title))
    }
}
