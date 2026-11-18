import Foundation
import CoreGraphics

/// 相机交互参数统一管理，界面和采集层使用同一套默认配置。
nonisolated enum CameraSettings {
    static let startupTimeout: TimeInterval = 8
    static let captureTimeout: TimeInterval = 12
    static let focusIndicatorSize: CGFloat = 44
    static let focusIndicatorDuration: TimeInterval = 1.2
    static let cornerRadius: CGFloat = 32
    static let portraitRotation: CGFloat = 90
    static let landscapePhotoAspectRatio: CGFloat = 4.0 / 3.0
    static let portraitPhotoAspectRatio: CGFloat = 3.0 / 4.0
    static let maximumPreviewWidth: CGFloat = 480
    static let capturePageInset: CGFloat = 16

    /// 按可用宽、高一起缩放取景窗口；小屏和横屏也完整显示照片，不需要上下滚动。
    static func previewSize(in available: CGSize, aspectRatio: CGFloat) -> CGSize {
        guard available.width.isFinite, available.height.isFinite else { return .zero }
        let ratio = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : portraitPhotoAspectRatio
        let width = min(maximumPreviewWidth, max(0, available.width - capturePageInset * 2))
        let height = min(max(0, available.height - capturePageInset * 2), width / ratio)
        return CGSize(width: height * ratio, height: height)
    }

    /// 照片尺寸来自相机格式，转为竖拍/横拍后的宽高比，界面只消费这个结果。
    static func orientedPhotoAspectRatio(sensorRatio: CGFloat, rotationAngle: CGFloat) -> CGFloat {
        let ratio = sensorRatio > 0 ? sensorRatio : landscapePhotoAspectRatio
        let quarterTurns = Int((rotationAngle / portraitRotation).rounded())
        return quarterTurns.isMultiple(of: 2) ? ratio : 1 / ratio
    }
}
