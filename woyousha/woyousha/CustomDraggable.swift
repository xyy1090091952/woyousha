//
//  CustomDraggable.swift
//  woyousha
//
//  Created by Trae on 2026/02/28.
//

import SwiftUI
import UIKit

/// A custom wrapper to enable drag interactions with a clean preview (no system background/shadow).
struct CustomDraggable<Content: View, Preview: View>: UIViewRepresentable {
    let content: Content
    let preview: Preview
    let itemProvider: () -> NSItemProvider
    
    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder preview: () -> Preview,
        itemProvider: @escaping () -> NSItemProvider
    ) {
        self.content = content()
        self.preview = preview()
        self.itemProvider = itemProvider
    }
    
    func makeUIView(context: Context) -> UIView {
        // Create the hosting controller
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        
        // Add drag interaction directly to the hosting view
        let interaction = UIDragInteraction(delegate: context.coordinator)
        host.view.addInteraction(interaction)
        
        // Store the controller in the coordinator to prevent deallocation
        context.coordinator.host = host
        
        return host.view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the content of the hosting controller
        context.coordinator.host?.rootView = content
        context.coordinator.parent = self
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UIDragInteractionDelegate {
        var parent: CustomDraggable
        var host: UIHostingController<Content>? // Retain the hosting controller
        
        init(parent: CustomDraggable) {
            self.parent = parent
        }
        
        // MARK: - UIDragInteractionDelegate
        
        func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
            let provider = parent.itemProvider()
            let item = UIDragItem(itemProvider: provider)
            return [item]
        }
        
        func dragInteraction(_ interaction: UIDragInteraction, previewForLifting item: UIDragItem, session: UIDragSession) -> UITargetedDragPreview? {
            guard let sourceView = interaction.view else { return nil }
            
            // Create a hosting controller for the preview
            let previewHost = UIHostingController(rootView: parent.preview)
            previewHost.view.backgroundColor = .clear
            
            // Determine the size of the preview
            // We give it a large available space to measure itself
            let targetSize = previewHost.sizeThatFits(in: CGSize(width: 500, height: 500))
            previewHost.view.bounds = CGRect(origin: .zero, size: targetSize)
            
            // Configure parameters to remove the system shadow and background
            let parameters = UIDragPreviewParameters()
            parameters.backgroundColor = .clear
            // Setting shadowPath to an empty path removes the shadow
            parameters.shadowPath = UIBezierPath(rect: .zero)
            
            // Target the center of the source view
            let center = CGPoint(x: sourceView.bounds.midX, y: sourceView.bounds.midY)
            let target = UIDragPreviewTarget(container: sourceView, center: center)
            
            return UITargetedDragPreview(view: previewHost.view, parameters: parameters, target: target)
        }
    }
}

extension View {
    /// Enables drag with a custom preview that has no system background or shadow.
    func customDraggable<Preview: View>(
        itemProvider: @escaping () -> NSItemProvider,
        @ViewBuilder preview: @escaping () -> Preview
    ) -> some View {
        CustomDraggable(content: { self }, preview: preview, itemProvider: itemProvider)
    }
}
