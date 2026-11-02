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

    /// 照片尺寸来自相机格式，转为竖拍/横拍后的宽高比，界面只消费这个结果。
    static func orientedPhotoAspectRatio(sensorRatio: CGFloat, rotationAngle: CGFloat) -> CGFloat {
        let ratio = sensorRatio > 0 ? sensorRatio : landscapePhotoAspectRatio
        let quarterTurns = Int((rotationAngle / portraitRotation).rounded())
        return quarterTurns.isMultiple(of: 2) ? ratio : 1 / ratio
    }
}
