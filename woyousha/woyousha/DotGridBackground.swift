//
//  DotGridBackground.swift
//  woyousha
//
//  Created by ByteDance on 2/27/26.
//

import SwiftUI

struct DotGridBackground: View {
    var spacing: CGFloat = StickerStyle.dotSpacing
    var dotSize: CGFloat = StickerStyle.dotDiameter
    var dotColor: Color = AppTheme.stickerDot
    
    var body: some View {
        Canvas { context, size in
            let step = max(4, spacing)
            // 从半格开始，边缘不出现半颗点；底纹只画在调用方给出的区域内。
            for y in stride(from: step / 2, to: size.height, by: step) {
                for x in stride(from: step / 2, to: size.width, by: step) {
                    let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                }
            }
        }
        .background(AppTheme.background)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    DotGridBackground()
}
