//
//  DotGridBackground.swift
//  woyousha
//
//  Created by ByteDance on 2/27/26.
//

import SwiftUI

struct DotGridBackground: View {
    var spacing: CGFloat = 20
    var dotSize: CGFloat = 2
    var dotColor: Color = .gray.opacity(0.2)
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let rows = Int(size.height / spacing) + 1
                let cols = Int(size.width / spacing) + 1
                
                for row in 0...rows {
                    for col in 0...cols {
                        let point = CGPoint(x: CGFloat(col) * spacing, y: CGFloat(row) * spacing)
                        let rect = CGRect(origin: point, size: CGSize(width: dotSize, height: dotSize))
                        context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .background(Color.white) // 背景底色
    }
}

#Preview {
    DotGridBackground()
}
