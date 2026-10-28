import Foundation

struct ItemRecognitionResult {
    let name: String
    let category: Category
}

/// 以后更换识别接口，只需实现这个协议，录入页面不依赖某一家服务。
protocol ItemRecognizing {
    var isEnabled: Bool { get }
    func recognize(imageData: Data) async throws -> ItemRecognitionResult
}

enum ItemRecognitionError: LocalizedError {
    case unavailable

    var errorDescription: String? { "自动识别暂未开启，请手动填写物品信息。" }
}

struct DisabledItemRecognizer: ItemRecognizing {
    let isEnabled = false

    func recognize(imageData: Data) async throws -> ItemRecognitionResult {
        throw ItemRecognitionError.unavailable
    }
}

enum ItemRecognitionService {
    // 当前关闭识别，没有网络请求。新服务准备好后从这里替换实现。
    static let provider: any ItemRecognizing = DisabledItemRecognizer()
}
