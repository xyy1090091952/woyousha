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
        // Create a container view to avoid modifying UIHostingController.view directly
        let containerView = ContentWrapperView(content: content)
        
        // Add drag interaction to the container view
        let interaction = UIDragInteraction(delegate: context.coordinator)
        containerView.addInteraction(interaction)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let wrapper = uiView as? ContentWrapperView<Content> {
            wrapper.updateContent(content)
        }
        context.coordinator.parent = self
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    // Custom wrapper view to handle layout correctly
    class ContentWrapperView<C: View>: UIView {
        var host: UIHostingController<C>
        
        init(content: C) {
            self.host = UIHostingController(rootView: content)
            super.init(frame: .zero)
            
            host.view.backgroundColor = .clear
            host.view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(host.view)
            
            // Set up constraints to fill the wrapper
            NSLayoutConstraint.activate([
                host.view.topAnchor.constraint(equalTo: topAnchor),
                host.view.bottomAnchor.constraint(equalTo: bottomAnchor),
                host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: trailingAnchor)
            ])
            
            // Ensure the wrapper hugs the content tightly
            setContentHuggingPriority(.required, for: .horizontal)
            setContentHuggingPriority(.required, for: .vertical)
            setContentCompressionResistancePriority(.required, for: .horizontal)
            setContentCompressionResistancePriority(.required, for: .vertical)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func updateContent(_ content: C) {
            host.rootView = content
            host.view.invalidateIntrinsicContentSize()
            invalidateIntrinsicContentSize()
        }
        
        // Propagate intrinsic content size from the hosted view
        override var intrinsicContentSize: CGSize {
            return host.view.intrinsicContentSize
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            // Force layout update if needed
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
        }
    }
    
    class Coordinator: NSObject, UIDragInteractionDelegate {
        var parent: CustomDraggable
        
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
