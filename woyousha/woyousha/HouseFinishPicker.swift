import SwiftUI

/// 配色只写入房间草稿；确认保存房间后才进入正式存档，取消保持原装修。
struct HouseFinishPicker: View {
    @Binding var draft: HouseRoom?
    @Environment(\.dismiss) private var dismiss
    private let columns=Array(repeating:GridItem(.flexible(),spacing:10),count:3)
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:18) {
                    Text("为 \(draft?.name ?? "房间") 选择装修")
                        .font(.title3.bold())
                    Text("回到房间后预览，点“保存房间”确认；取消房间草稿会恢复原装修。")
                        .font(.caption).foregroundStyle(AppTheme.secondaryText)
                    Text("地板").font(.headline)
                    LazyVGrid(columns:columns,spacing:10) {
                        option("随房间配色",color:nil,selected:draft?.floorFinish == nil) { changeFloor(nil) }
                        ForEach(HouseFloorFinish.allCases,id:\.self) { finish in
                            option(finish.title,color:finish.color,selected:draft?.floorFinish == finish) { changeFloor(finish) }
                        }
                    }
                    Text("墙面").font(.headline).padding(.top,8)
                    LazyVGrid(columns:columns,spacing:10) {
                        option("随房间配色",color:nil,selected:draft?.wallFinish == nil) { changeWall(nil) }
                        ForEach(HouseWallFinish.allCases,id:\.self) { finish in
                            option(finish.title,color:finish.color,selected:draft?.wallFinish == finish) { changeWall(finish) }
                        }
                    }
                }.padding(16)
            }.background(AppTheme.background)
                .navigationTitle("地板与墙面").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.topBarTrailing) { Button("预览房间") { dismiss() }.fontWeight(.bold) } }
        }.tint(AppTheme.accentText).foregroundStyle(AppTheme.text)
    }
    private func option(_ title:String,color:UInt32?,selected:Bool,action:@escaping ()->Void) -> some View {
        Button(action:action) {
            VStack(spacing:8) {
                ZStack(alignment:.topTrailing) {
                    RoundedRectangle(cornerRadius:10)
                        .fill(color.map { Color(.sRGB,red:Double($0>>16&255)/255,
                                                green:Double($0>>8&255)/255,blue:Double($0&255)/255) } ?? AppTheme.inset)
                        .frame(height:40)
                    if selected {
                        Image(systemName:"checkmark.circle.fill").foregroundStyle(AppTheme.onAccent)
                            .padding(5).background(AppTheme.accent,in:Circle())
                    }
                }
                Text(title).font(.caption.weight(.semibold)).lineLimit(1)
            }.padding(9).frame(maxWidth:.infinity)
                .background(AppTheme.surface,in:RoundedRectangle(cornerRadius:14))
                .overlay { RoundedRectangle(cornerRadius:14).strokeBorder(selected ? AppTheme.accentText:AppTheme.line,lineWidth:selected ? 2:1) }
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityAddTraits(selected ? .isSelected:[])
    }
    private func changeFloor(_ finish:HouseFloorFinish?) { draft?.floorFinish=finish }
    private func changeWall(_ finish:HouseWallFinish?) { draft?.wallFinish=finish }
}
