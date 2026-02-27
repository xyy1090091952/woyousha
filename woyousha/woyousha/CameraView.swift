//
//  CameraView.swift
//  woyousha
//
//  Created by ByteDance on 2/27/26.
//

import SwiftUI
import UIKit

/// 封装 UIKit 的 UIImagePickerController 以在 SwiftUI 中使用相机
struct CameraView: UIViewControllerRepresentable {
    // 绑定选中的图片，当用户拍完照，这个变量会被更新
    @Binding var selectedImage: UIImage?
    // 绑定是否显示相机页面，拍完或取消后设为 false
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        // 设置源为相机
        // 注意：在模拟器上相机不可用，会崩溃。实际代码中应该检查 isSourceTypeAvailable
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            print("⚠️ 模拟器不支持相机，将使用相册代替以便测试")
            picker.sourceType = .photoLibrary
        }
        picker.allowsEditing = false // 不允许系统自带的编辑，我们自己处理
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // 协调器，处理 UIImagePickerController 的回调
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // 获取拍摄的原图
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            // 关闭相机页面
            parent.isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            // 用户取消，直接关闭
            parent.isPresented = false
        }
    }
}
