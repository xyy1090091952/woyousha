import SwiftUI

/// 家园画布的浅色织纸纹理，固定在屏幕上，平移/缩放房子时不晃动。
struct HouseBackdrop: View {
    private enum Texture {
        static let spacing: CGFloat = 22
        static let threadLength: CGFloat = 3
    }
    var body: some View {
        Canvas { context,size in
            let step=Texture.spacing
            for row in 0...Int(size.height/step) {
                for column in 0...Int(size.width/step) {
                    let x=CGFloat(column)*step+(row.isMultiple(of:2) ? 5:step/2)
                    let y=CGFloat(row)*step+7
                    let horizontal=(row+column).isMultiple(of:2)
                    let rect=CGRect(x:x,y:y,width:horizontal ? Texture.threadLength:1,
                                    height:horizontal ? 1:Texture.threadLength)
                    context.fill(Path(rect),with:.color(AppTheme.stickerDot.opacity(0.55)))
                }
            }
        }
        .background(AppTheme.background)
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}
