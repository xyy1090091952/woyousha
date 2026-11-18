import SwiftUI

nonisolated struct HouseSurfaceOption: Identifiable {
    let attachment: HouseSurfaceAttachment
    let name: String
    var id: String { attachment.supportID }
}

struct HouseSurfaceMenu: View {
    let options: [HouseSurfaceOption]
    let isAttached: Bool
    let onAttach: (HouseSurfaceAttachment) -> Void
    let onGround: () -> Void
    var body: some View {
        HStack {
            Menu {
                ForEach(options) { option in Button(option.name) { onAttach(option.attachment) } }
            } label: { Label(options.isEmpty ? "暂无空桌面":"放到桌面",systemImage:"table.furniture") }
                .disabled(options.isEmpty)
            Spacer()
            if isAttached { Button("放回地面",action:onGround) }
        }
        .font(.subheadline.weight(.semibold)).frame(minHeight:44)
    }
}
