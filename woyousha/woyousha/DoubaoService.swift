//
//  DoubaoService.swift
//  woyousha
//
//  Created by ByteDance on 2/27/26.
//

import Foundation
import UIKit

// 豆包 API 服务
// 用于调用火山引擎方舟 (Volcengine Ark) 的大模型 API 进行图片识别
class DoubaoService {
    // 单例模式
    static let shared = DoubaoService()
    
    // MARK: - 配置项 (需要替换为你自己的配置)
    // 请前往火山引擎控制台获取: https://console.volcengine.com/ark/region:ark+cn-beijing/endpoint
    // 从 Info.plist 读取 API Key，避免硬编码
    private var apiKey: String {
        return Bundle.main.object(forInfoDictionaryKey: "DOUBAO_API_KEY") as? String ?? ""
    }
    // 从截图代码示例中提取的模型 ID
    private let modelEndpointId = "doubao-seed-1-8-251228" 
    private let baseURL = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
    
    private init() {}
    
    // 识别结果结构体
    struct AnalysisResult {
        let name: String
        let category: Category
    }
    
    // 错误类型
    enum AnalysisError: Error {
        case invalidImage
        case networkError(Error)
        case invalidResponse
        case apiError(String)
        case decodingError
    }
    
    // 分析图片
    func analyzeImage(image: UIImage) async throws -> AnalysisResult {
        // 1. 图片转 Base64
        // 压缩图片以减少网络传输，宽高限制在 512px 左右通常足够识别
        guard let resizedImage = image.resized(to: 512),
              let imageData = resizedImage.jpegData(compressionQuality: 0.7) else {
            throw AnalysisError.invalidImage
        }
        
        let base64Image = imageData.base64EncodedString()
        
        // 2. 构造 Prompt
        // 要求模型返回 JSON 格式，方便解析
        let prompt = """
        请识别这张图片中的物品。
        请只返回一个 JSON 对象，不要包含 markdown 格式或其他废话。
        JSON 格式如下：
        {
            "name": "物品名称(限制在7个汉字以内)",
            "category": "物品分类(只能是以下之一: 衣服, 食品, 数码, 书籍, 药品, 工具, 其他)"
        }
        要求：
        1. 物品名称要尽量精准，描述出品牌、款式、颜色或口味等特征（例如：“Switch手柄”、“优衣库黑T恤”、“乐事薯片”）。
        2. 尽管要精准，但名称总长度严格不能超过 7 个汉字。如果太长，请精简。
        3. category 字段必须严格返回上述中文枚举值之一，不要返回英文。
        """
        
        // 3. 构造请求体 (OpenAI 兼容格式)
        let requestBody: [String: Any] = [
            "model": modelEndpointId,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        // 4. 发起请求
        guard let url = URL(string: baseURL) else {
            throw AnalysisError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AnalysisError.invalidResponse
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnalysisError.networkError(NSError(domain: "Invalid Response", code: 0))
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            if let errorStr = String(data: data, encoding: .utf8) {
                print("API Error: \(errorStr)")
                throw AnalysisError.apiError("Status: \(httpResponse.statusCode)")
            }
            throw AnalysisError.apiError("Status: \(httpResponse.statusCode)")
        }
        
        // 5. 解析结果
        return try parseResponse(data: data)
    }
    
    private func parseResponse(data: Data) throws -> AnalysisResult {
        // 定义响应结构
        struct ApiResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        
        let apiResponse = try JSONDecoder().decode(ApiResponse.self, from: data)
        
        guard let content = apiResponse.choices.first?.message.content else {
            throw AnalysisError.invalidResponse
        }
        
        // 清理可能存在的 Markdown 代码块标记
        let cleanContent = content.replacingOccurrences(of: "```json", with: "")
                                  .replacingOccurrences(of: "```", with: "")
                                  .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanContent.data(using: .utf8) else {
            throw AnalysisError.decodingError
        }
        
        // 定义结果 JSON 结构
        struct ResultJSON: Decodable {
            let name: String
            let category: String
        }
        
        let result = try JSONDecoder().decode(ResultJSON.self, from: jsonData)
        
        // 映射分类
        let category = Category(rawValue: result.category) ?? .other
        
        return AnalysisResult(name: result.name, category: category)
    }
}

// 图片压缩扩展
extension UIImage {
    func resized(to maxDimension: CGFloat) -> UIImage? {
        let aspectRatio = size.width / size.height
        var newSize: CGSize
        
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}
