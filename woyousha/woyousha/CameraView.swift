import SwiftUI
import UIKit
import UniformTypeIdentifiers
import OSLog

/// 直接展示完整的系统相机：不添加子控制器、覆盖层或自定义快门。
/// 保留系统的取景、对焦、拍摄、重拍和“使用照片”流程。
struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera // 调用方先完成设备检查和授权。
        picker.mediaTypes = [UTType.image.identifier]
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.showsCameraControls = true
        picker.modalPresentationStyle = .fullScreen
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    static func dismantleUIViewController(_ picker: UIImagePickerController, coordinator: Coordinator) {
        picker.delegate = nil
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraView
        private var completed = false
        private let logger = Logger(subsystem: "com.OGS.woyousha", category: "Camera")

        init(parent: CameraView) { self.parent = parent }

        func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
            logger.info("Native camera controller appeared")
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard !completed else { return }
            completed = true
            guard let image = info[.originalImage] as? UIImage else {
                logger.error("System camera returned no image")
                parent.onError("系统没有返回照片，请重试。")
                return
            }
            logger.info("Native camera delivered photo: \(image.size.width) × \(image.size.height)")
            parent.onCapture(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            guard !completed else { return }
            completed = true
            parent.onCancel()
        }
    }
}
