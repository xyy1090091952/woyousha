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
}
