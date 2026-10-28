import AVFoundation
import Observation
import UIKit
import OSLog

/// 在录入页完成权限检查，再展示相机。授权弹窗与相机展示不争抢同一个转场。
@MainActor @Observable
final class CameraController {
    enum AccessError { case denied, restricted, unavailable }
    private(set) var isRequesting = false
    var accessError: AccessError?
    private let logger = Logger(subsystem: "com.OGS.woyousha", category: "Camera")

    var errorMessage: String {
        switch accessError {
        case .denied: return "相机权限尚未开启，请在系统设置中允许 Oyoha 使用相机。"
        case .restricted: return "系统限制了相机使用，请检查屏幕使用时间或设备管理设置。"
        case .unavailable: return "这台设备没有可用相机，可以从相册选择物品照片。"
        case nil: return ""
        }
    }

    func prepare() async -> Bool {
        guard !isRequesting else { return false }
        isRequesting = true
        accessError = nil
        defer { isRequesting = false }

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            accessError = .unavailable
            logger.error("No camera source available")
            return false
        }
        let authorized: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: authorized = true
        case .notDetermined: authorized = await AVCaptureDevice.requestAccess(for: .video)
        case .restricted:
            accessError = .restricted
            return false
        default: authorized = false
        }
        guard !Task.isCancelled else { return false }
        if !authorized { accessError = .denied }
        logger.info("Camera permission result: \(authorized)")
        return authorized
    }
}
