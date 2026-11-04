import SwiftUI

/// 建房草稿独立于正式存档，拖错位置或取消不会改动已经保存的房型。
struct HouseBuildPanel: View {
    @Binding var draft: HouseRoom?
    let roomCount: Int
    let issue: String?
    let isExisting: Bool
    let onNew: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void
    @State private var showsFinishes=false

    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            if draft != nil {
                HStack {
                    Text(isExisting ? "调整房间":"扩建新房间").font(.headline)
                    Spacer()
                    Button("取消") { draft=nil }.frame(minHeight:44).accessibilityLabel("取消房间草稿")
                }
                HStack(spacing:10) {
                    TextField("房间名称",text:binding(\.name,default:"卧室"))
                        .textFieldStyle(.roundedBorder)
                    Picker("用途",selection:binding(\.kind,default:.bedroom)) {
                        ForEach(HouseRoom.Kind.allCases,id:\.self) { Text($0.title).tag($0) }
                    }.labelsHidden()
                }
                HStack {
                    Stepper("宽 \(draft?.width ?? 5) 格",value:binding(\.width,default:5),in:HouseGridConfig.roomSize)
                    Stepper("深 \(draft?.depth ?? 5) 格",value:binding(\.depth,default:5),in:HouseGridConfig.roomSize)
                }.font(.subheadline)
                Button { showsFinishes=true } label: {
                    HStack {
                        Label("地板与墙面",systemImage:"paintpalette.fill")
                        Spacer()
                        Text("\(draft?.floorFinish?.title ?? "默认") · \(draft?.wallFinish?.title ?? "默认")").font(.caption)
                    }.frame(maxWidth:.infinity)
                }.buttonStyle(AppButtonStyle(isPrimary:false))
                Text(issue ?? "拖动高亮房间到空地，贴着已有房间放置。")
                    .font(.caption).foregroundStyle(issue == nil ? AppTheme.secondaryText:.red)
                    .frame(minHeight:30,alignment:.leading)
                HStack {
                    if isExisting {
                        Button("拆除房间",role:.destructive,action:onDelete).frame(minHeight:44)
                    }
                    Button(action:onSave) {
                        Text(isExisting ? "保存房间":"确认扩建").frame(maxWidth:.infinity)
                    }.buttonStyle(AppButtonStyle()).disabled(issue != nil)
                }
            } else {
                HStack {
                    Text("我的户型 · \(roomCount) 个房间").font(.headline)
                    Spacer()
                    Image(systemName:"square.grid.3x3.fill").foregroundStyle(AppTheme.accentText)
                }
                Text("点房间可以换地板和墙面、改大小和用途；也可以继续扩建自己的家。")
                    .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                Button(action:onNew) {
                    Label("扩建一个房间",systemImage:"plus").frame(maxWidth:.infinity)
                }.buttonStyle(AppButtonStyle()).accessibilityLabel("扩建一个房间")
                Text("相邻房间自动连接门洞 · 修改成功后自动保存").font(.caption).foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(16).foregroundStyle(AppTheme.text).background(AppTheme.surface)
        .accessibilityElement(children:.contain)
        .accessibilityLabel("房间搭建操作")
        .sheet(isPresented:$showsFinishes) {
            HouseFinishPicker(draft:$draft).presentationDetents([.medium,.large])
        }
    }

    private func binding<Value>(_ keyPath:WritableKeyPath<HouseRoom,Value>,default fallback:Value) -> Binding<Value> {
        Binding(get:{draft?[keyPath:keyPath] ?? fallback},set:{value in
            guard var room=draft else { return }
            room[keyPath:keyPath]=value
            draft=room
        })
    }
}
