//
//  ImageUtils.swift
//  woyousha
//
//  Created by ByteDance on 2/27/26.
//

import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// 图像处理工具类
/// 负责处理图片的 AI 抠图、描边等操作
struct ImageUtils {
    
    /// 移除图片背景 (AI 抠图)
    /// - Parameter inputImage: 输入的原始图片
    /// - Returns: 移除背景后的透明背景图片
    @MainActor
    static func removeBackground(from inputImage: UIImage) async -> UIImage? {
        // 1. 转换为 CIImage (Core Image 的标准格式)
        guard let ciImage = CIImage(image: inputImage) else { return nil }
        
        // 2. 检查是否支持 iOS 17 的新 API
        if #available(iOS 17.0, *) {
            return await removeBackgroundNew(ciImage: ciImage, originalOrientation: inputImage.imageOrientation)
        } else {
            // 旧版本暂不支持，原样返回 (或者可以使用 CoreML 模型，但比较重)
            print("⚠️ 系统版本低于 iOS 17，暂不支持自动抠图")
            return inputImage
        }
    }
    
    /// 使用 iOS 17 Vision 框架的新 API 进行主体分离
    @available(iOS 17.0, *)
    private static func removeBackgroundNew(ciImage: CIImage, originalOrientation: UIImage.Orientation) async -> UIImage? {
        return await Task.detached(priority: .userInitiated) {
            // 创建请求：生成前景实例掩码 (也就是抠图)
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(ciImage: ciImage)
            
            do {
                // 执行请求
                try handler.perform([request])
                
                // 获取结果
                guard let result = request.results?.first else { return nil }
                
                // 获取遮罩 (Mask)
                let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
                let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
                
                // 将遮罩应用到原图
                // BlendWithMask: inputImage (原图), inputMaskImage (遮罩), inputBackgroundImage (背景，这里设为空白)
                let filter = CIFilter.blendWithMask()
                filter.inputImage = ciImage
                filter.maskImage = maskImage
                filter.backgroundImage = CIImage.empty() // 透明背景
                
                guard let outputCIImage = filter.outputImage else { return nil }
                
                // 转换为 UIImage
                let context = CIContext()
                guard let cgImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) else { return nil }
                
                return UIImage(cgImage: cgImage, scale: 1.0, orientation: originalOrientation)
            } catch {
                print("❌ 抠图失败: \(error)")
                return nil
            }
        }.value
    }
    
    /// 给图片添加白色描边 (贴纸效果)
    /// - Parameters:
    ///   - image: 输入的透明背景图片
    ///   - thickness: 描边宽度
    /// - Returns: 带描边的图片
    static func addWhiteBorder(to image: UIImage, thickness: CGFloat = 10) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        
        // 1. 获取 Alpha 通道掩码
        let alphaFilter = CIFilter.maskToAlpha()
        alphaFilter.inputImage = ciImage
        guard let alphaMask = alphaFilter.outputImage else { return nil }
        
        // 2. 膨胀掩码 (MorphologyDilate) - 让轮廓变大一圈
        // 注意：Morphology 滤镜在 iOS 13+ 可用
        let dilateFilter = CIFilter.morphologyRectangleMaximum()
        dilateFilter.inputImage = alphaMask
        dilateFilter.width = Float(thickness) // 修复：width 应该是 Float
        dilateFilter.height = Float(thickness) // 修复：height 应该是 Float
        
        guard let dilatedMask = dilateFilter.outputImage else { return nil }
        
        // 3. 给膨胀后的掩码上色 (变成纯白色)
        let whiteImage = CIImage(color: .white)
        let coloredMaskFilter = CIFilter.sourceAtopCompositing() // 修复：使用 sourceAtopCompositing
        coloredMaskFilter.inputImage = whiteImage
        coloredMaskFilter.backgroundImage = dilatedMask // 这里其实是用 mask 切割白色
        
        // 重新构建白色背景层
        let solidWhite = CIImage(color: .white).cropped(to: ciImage.extent.insetBy(dx: -thickness, dy: -thickness))
        let maskFilter = CIFilter.blendWithMask()
        maskFilter.inputImage = solidWhite
        maskFilter.maskImage = dilatedMask
        maskFilter.backgroundImage = CIImage.empty()
        guard let whiteBorderLayer = maskFilter.outputImage else { return nil }
        
        // 4. 合成：原图在上，白色描边在下
        let compositeFilter = CIFilter.sourceOverCompositing() // 修复：使用 sourceOverCompositing
        compositeFilter.inputImage = ciImage
        compositeFilter.backgroundImage = whiteBorderLayer
        
        guard let finalOutput = compositeFilter.outputImage else { return nil }
        
        let context = CIContext()
        guard let finalCGImage = context.createCGImage(finalOutput, from: finalOutput.extent) else { return nil }
        
        return UIImage(cgImage: finalCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
