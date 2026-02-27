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
        // 提前检测模拟器环境，避免无效请求
        #if targetEnvironment(simulator)
        print("⚠️ 检测到模拟器环境，Vision 抠图不支持，已自动降级为原图")
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            return UIImage(cgImage: cgImage, scale: 1.0, orientation: originalOrientation)
        }
        return nil
        #else
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
                
                // 将 CIImage 转回 UIImage 并返回
                let context = CIContext()
                if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                    return UIImage(cgImage: cgImage, scale: 1.0, orientation: originalOrientation)
                }
                return nil
            }
        }.value
        #endif
    }
    
    /// 给图片添加白色描边 (贴纸效果)
    /// - Parameters:
    ///   - image: 输入的透明背景图片
    ///   - thickness: 描边宽度
    /// - Returns: 带描边的图片
    static func addWhiteBorder(to image: UIImage, thickness: CGFloat = 25) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        
        // 动态计算描边厚度：基于图片宽度，例如宽度的 3%
        let dynamicThickness = max(thickness, ciImage.extent.width * 0.03)
        
        // --- 新版贴纸描边算法 (Smooth Sticker Effect) ---
        
        // 1. 生成实体白色遮罩 (Binarize Alpha)
        // 将原图的 Alpha 通道放大并截断，使半透明区域变全不透明，
        // 同时将 RGB 通道设为全白 (1,1,1)。
        // 这样可以处理原图边缘半透明或内部有半透明像素导致的描边断裂问题。
        let solidMaskFilter = CIFilter.colorMatrix()
        solidMaskFilter.inputImage = ciImage
        solidMaskFilter.rVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        solidMaskFilter.gVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        solidMaskFilter.bVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        solidMaskFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 100) // 放大 Alpha，使其变为 0 或 1
        solidMaskFilter.biasVector = CIVector(x: 1, y: 1, z: 1, w: 0) // RGB 设为白色
        
        guard let solidMask = solidMaskFilter.outputImage else { return nil }
        
        // 2. 圆形膨胀 (Circular Dilation)
        // 使用 MorphologyMaximum (圆形) 替代 RectangleMaximum (矩形)
        // 解决边缘锯齿和方块感，使描边圆润平滑。
        let dilateFilter = CIFilter.morphologyMaximum()
        dilateFilter.inputImage = solidMask
        dilateFilter.radius = Float(dynamicThickness)
        guard let dilatedMask = dilateFilter.outputImage else { return nil }
        
        // 3. 平滑处理 (Smoothing)
        // 添加轻微的高斯模糊，消除膨胀带来的像素边缘，使贴纸边缘更自然
        let smoothFilter = CIFilter.gaussianBlur()
        smoothFilter.inputImage = dilatedMask
        smoothFilter.radius = 2.0
        guard let smoothedMask = smoothFilter.outputImage else { return nil }
        
        // 4. 合成：原图在上，白色描边在下
        let compositeFilter = CIFilter.sourceOverCompositing()
        compositeFilter.inputImage = ciImage
        compositeFilter.backgroundImage = smoothedMask
        
        guard let finalOutput = compositeFilter.outputImage else { return nil }
        
        // 5. 自动裁剪 (Auto Crop)：切掉四周多余的透明区域
        let context = CIContext()
        
        guard let finalCGImage = context.createCGImage(finalOutput, from: finalOutput.extent) else { return nil }
        
        // 重新创建 UIImage
        let resultImage = UIImage(cgImage: finalCGImage, scale: image.scale, orientation: image.imageOrientation)
        
        // 调用裁剪辅助方法
        if let cropped = resultImage.trimmingTransparentPixels() {
            print("✅ 自动裁剪成功")
            return cropped
        } else {
            print("⚠️ 自动裁剪失败，返回未裁剪的带描边图片")
            return resultImage
        }
    }
}

// 扩展 UIImage 以支持透明像素裁剪
extension UIImage {
    func trimmingTransparentPixels(maximumAlphaChannel: UInt8 = 0) -> UIImage? {
        guard let cgImage = cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // 分配内存用于像素数据
        let bytesPerRow = width * 4
        let dataSize = bytesPerRow * height
        var data = [UInt8](repeating: 0, count: dataSize)
        
        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 寻找非透明区域的边界 (优化算法：分别扫描上下左右，避免全像素遍历)
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        
        var found = false
        
        // 1. 扫描 Top (minY)
        for y in 0..<height {
            var rowHasPixels = false
            for x in 0..<width {
                // Alpha is at index 3 (premultipliedLast: R G B A)
                let alpha = data[(y * bytesPerRow) + (x * 4) + 3]
                if alpha > maximumAlphaChannel {
                    minY = y
                    rowHasPixels = true
                    found = true
                    break
                }
            }
            if rowHasPixels { break }
        }
        
        if !found { return nil } // 全透明图片
        
        // 2. 扫描 Bottom (maxY)
        for y in (0..<height).reversed() {
            var rowHasPixels = false
            for x in 0..<width {
                let alpha = data[(y * bytesPerRow) + (x * 4) + 3]
                if alpha > maximumAlphaChannel {
                    maxY = y
                    rowHasPixels = true
                    break
                }
            }
            if rowHasPixels { break }
        }
        
        // 3. 扫描 Left (minX) - 只需要扫描 minY...maxY 范围
        for x in 0..<width {
            var colHasPixels = false
            for y in minY...maxY {
                let alpha = data[(y * bytesPerRow) + (x * 4) + 3]
                if alpha > maximumAlphaChannel {
                    minX = x
                    colHasPixels = true
                    break
                }
            }
            if colHasPixels { break }
        }
        
        // 4. 扫描 Right (maxX) - 只需要扫描 minY...maxY 范围
        for x in (0..<width).reversed() {
            var colHasPixels = false
            for y in minY...maxY {
                let alpha = data[(y * bytesPerRow) + (x * 4) + 3]
                if alpha > maximumAlphaChannel {
                    maxX = x
                    colHasPixels = true
                    break
                }
            }
            if colHasPixels { break }
        }
        
        print("🔍 裁剪区域: x[\(minX)-\(maxX)], y[\(minY)-\(maxY)] (原图: \(width)x\(height))")
        
        // 添加 padding，让贴纸呼吸感更强
        let padding = 20
        let safeMinX = max(0, minX - padding)
        let safeMinY = max(0, minY - padding)
        let safeMaxX = min(width, maxX + padding)
        let safeMaxY = min(height, maxY + padding)
        
        let rect = CGRect(
            x: safeMinX,
            y: safeMinY,
            width: safeMaxX - safeMinX,
            height: safeMaxY - safeMinY
        )
        
        // 修正 rect 宽度高度可能为负的情况 (虽然逻辑上不应该，但防御性编程)
        if rect.width <= 0 || rect.height <= 0 { return nil }
        
        guard let croppedCGImage = cgImage.cropping(to: rect) else { return nil }
        
        return UIImage(cgImage: croppedCGImage, scale: scale, orientation: imageOrientation)
    }
}
