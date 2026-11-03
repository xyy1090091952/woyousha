import SwiftUI

/// 装饰与家具共享“选中后在底部操作”的体验；装饰不提供物品收纳和容器字段。
struct DecorationInspector: View {
    let decoration: RoomDecoration
    let roomStyle: String
    let onAction: (RoomDecorationStore.Action) -> Bool
    let onPreviewScale: (Double?) -> Void
    let onClose: () -> Void
    @State private var scaleDraft: Double

    init(decoration:RoomDecoration,roomStyle:String,onAction:@escaping (RoomDecorationStore.Action)->Bool,
         onPreviewScale:@escaping (Double?)->Void,onClose:@escaping ()->Void) {
        self.decoration=decoration;self.roomStyle=roomStyle;self.onAction=onAction
        self.onPreviewScale=onPreviewScale;self.onClose=onClose
        _scaleDraft=State(initialValue:decoration.scale)
    }

    var body: some View {
        VStack(spacing:14) {
            HStack(spacing:12) {
                PixelDecorationView(kind:decoration.kind,roomStyle:roomStyle,mirrored:decoration.isMirrored)
                    .frame(width:54,height:62)
                VStack(alignment:.leading,spacing:4) {
                    Text(decoration.name).font(.system(.headline,design:.rounded,weight:.heavy))
                    Text("装饰物 · 不用于收纳").font(.caption).foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Button(action:onClose) { Image(systemName:"checkmark").frame(width:44,height:44) }
                    .buttonStyle(ToyIconButtonStyle(isPrimary:true)).accessibilityLabel("完成装饰调整")
            }
            HStack(spacing:8) {
                action("镜像","arrow.left.and.right") { _=onAction(.mirror) }
                action("置前","square.3.layers.3d.top.filled") { _=onAction(.forward) }
                    .disabled(decoration.kind.isFloorCovering)
                action("置后","square.3.layers.3d.bottom.filled") { _=onAction(.backward) }
                    .disabled(decoration.kind.isFloorCovering)
                action("删除","trash", destructive: true) { _=onAction(.delete) }
            }
            HStack(spacing:10) {
                Button {
                    scaleDraft=max(0.5,scaleDraft-0.1);commitScale()
                } label: { Image(systemName:"minus").frame(width:44,height:44) }
                    .accessibilityLabel("缩小装饰")
                Slider(value:$scaleDraft,in:RoomConfig.furnitureRange,onEditingChanged:{ editing in
                    if !editing { commitScale() }
                }).accessibilityLabel("装饰大小")
                Button {
                    scaleDraft=min(2,scaleDraft+0.1);commitScale()
                } label: { Image(systemName:"plus").frame(width:44,height:44) }
                    .accessibilityLabel("放大装饰")
                Text("\(Int(scaleDraft*100))%").font(.caption.weight(.bold)).monospacedDigit()
            }
            .onChange(of:scaleDraft) { _,value in onPreviewScale(value) }
        }
        .padding(16).tint(AppTheme.accentText).foregroundStyle(AppTheme.text)
        .background(AppTheme.surface)
        .onDisappear { onPreviewScale(nil) }
    }

    private func commitScale() {
        if !onAction(.scale(scaleDraft)) { scaleDraft=decoration.scale }
        onPreviewScale(nil)
    }
    private func action(_ title:String,_ symbol:String,destructive:Bool = false,perform:@escaping ()->Void) -> some View {
        Button(action:perform) {
            VStack(spacing:6) {
                Image(systemName:symbol).font(.system(size:19,weight:.semibold))
                Text(title).font(.caption.weight(.bold))
            }.frame(maxWidth:.infinity,minHeight:58)
                .foregroundStyle(destructive ? Color.red : AppTheme.blue)
                .background(AppTheme.blueInset,in:RoundedRectangle(cornerRadius:14))
        }.buttonStyle(.plain)
    }
}
