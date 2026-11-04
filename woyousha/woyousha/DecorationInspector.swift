import SwiftUI

/// 装饰与家具共享“选中后在底部操作”的体验；装饰不提供物品收纳和容器字段。
struct DecorationInspector: View {
    let decoration: RoomDecoration
    let roomStyle: String
    let onAction: (RoomDecorationStore.Action) -> Bool
    let onClose: () -> Void

    init(decoration:RoomDecoration,roomStyle:String,onAction:@escaping (RoomDecorationStore.Action)->Bool,
         onClose:@escaping ()->Void) {
        self.decoration=decoration;self.roomStyle=roomStyle;self.onAction=onAction
        self.onClose=onClose
    }

    var body: some View {
        VStack(spacing:14) {
            HStack(spacing:12) {
                PixelDecorationView(kind:decoration.kind,roomStyle:roomStyle,mirrored:decoration.isMirrored)
                    .frame(width:54,height:62)
                VStack(alignment:.leading,spacing:4) {
                    Text(decoration.name).font(.system(.headline,design:.rounded,weight:.heavy))
                    let size=HouseFurnitureCatalog.decoration(decoration.kind,mirrored:decoration.isMirrored).footprint
                    Text("占地 \(size.width) × \(size.depth) 格 · 固定尺寸").font(.caption).foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Button(action:onClose) { Image(systemName:"checkmark").frame(width:44,height:44) }
                    .buttonStyle(ToyIconButtonStyle(isPrimary:true)).accessibilityLabel("完成装饰调整")
            }
            HStack(spacing:8) {
                action("转向","arrow.triangle.2.circlepath") { _=onAction(.mirror) }
                action("收起","archivebox") { _=onAction(.store) }
                action("删除","trash", destructive: true) { _=onAction(.delete) }
            }
            HStack(spacing:8) {
                nudge("左","arrow.left",x:-1,y:0)
                nudge("上","arrow.up",x:0,y:-1)
                nudge("下","arrow.down",x:0,y:1)
                nudge("右","arrow.right",x:1,y:0)
            }
        }
        .padding(16).tint(AppTheme.accentText).foregroundStyle(AppTheme.text)
        .background(AppTheme.surface)
    }

    private func nudge(_ title:String,_ symbol:String,x:Int,y:Int) -> some View {
        action(title+"一格",symbol) { _=onAction(.move(.init(x:(decoration.gridX ?? 0)+x,y:(decoration.gridY ?? 0)+y))) }
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
