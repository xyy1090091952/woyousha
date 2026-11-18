import SwiftUI

/// 固定在画布外的操作面板：位置和字号不随家具缩放，所有按钮至少 44pt 高。
struct FurnitureInspector: View {
    let container: Container
    let onAction: (FurniturePlacementRepository.Action) -> Bool
    let onClose: () -> Void
    let failureMessage: () -> String
    var surfaceOptions: [HouseSurfaceOption] = []
    var supportName: String? = nil
    var onGround: () -> Void = {}
    @State private var showStyles = false
    @State private var showDeleteConfirmation = false

    init(container: Container, onAction: @escaping (FurniturePlacementRepository.Action) -> Bool,
         onClose: @escaping () -> Void,
         failureMessage: @escaping () -> String = { "没有保存成功，请再试一次。" },
         surfaceOptions:[HouseSurfaceOption] = [],supportName:String? = nil,onGround:@escaping ()->Void = {}) {
        self.container = container
        self.onAction = onAction
        self.onClose = onClose
        self.failureMessage = failureMessage
        self.surfaceOptions=surfaceOptions;self.supportName=supportName;self.onGround=onGround
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
                    Text(container.furnitureRole.rawValue + (supportName.map {" · 在\($0)上"} ??
                        " · 占地 \(container.gridWidth) × \(container.gridDepth) 格"))
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
                actionButton("转向", symbol: "arrow.triangle.2.circlepath", selected: container.isMirrored) { _ = onAction(.mirror) }
                actionButton("收起", symbol: "archivebox", destructive: true) { _ = onAction(.store) }
                actionButton("删除", symbol: "trash", destructive: true) { showDeleteConfirmation=true }
            }

            HStack(spacing:8) {
                nudge("左","arrow.left",x:-1,y:0)
                nudge("上","arrow.up",x:0,y:-1)
                nudge("下","arrow.down",x:0,y:1)
                nudge("右","arrow.right",x:1,y:0)
            }
            if HouseFurnitureAttributes.canSitOnSurface(.furniture(styleID)) {
                HouseSurfaceMenu(options:surfaceOptions,isAttached:container.surfaceAttachment != nil,
                    onAttach:{_ = onAction(.attach($0))},onGround:onGround)
            }
        }
        .padding(16)
        .foregroundStyle(AppTheme.text)
        .tint(AppTheme.accentText)
        .background(AppTheme.surface)
        .overlay(alignment: .top) { Rectangle().fill(AppTheme.line).frame(height: 2) }
        .sheet(isPresented: $showStyles) {
            FurnitureCatalogPicker(selectedStyleID: styleID, role:container.furnitureRole, failureMessage: failureMessage) { id in
                onAction(.style(id))
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog("删除这件家具？",isPresented:$showDeleteConfirmation,titleVisibility:.visible) {
            Button("删除",role:.destructive) { _=onAction(.delete) }
        } message: {
            Text("其中的物品会移到未分类，桌面上的摆件会保留在待布置区。")
        }
    }

    private func nudge(_ title:String,_ symbol:String,x:Int,y:Int) -> some View {
        actionButton(title+(container.surfaceAttachment == nil ? "一格":"微调"),symbol:symbol) {
            if container.surfaceAttachment != nil { _=onAction(.moveSurface(x:x,y:y)) }
            else { _=onAction(.move(.init(x:container.gridX+x,y:container.gridY+y))) }
        }
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
        .accessibilityLabel(title)
    }
}
