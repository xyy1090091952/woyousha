import AppKit
import SwiftUI
import Observation
import ImageIO
import UniformTypeIdentifiers

// Mac 验证适配：正式 StickerGridItemView 直接参与编译，UIKit 图片/文字改用 AppKit 承载。
// 不代替手机触摸或 UIKit 字体截图检查，也不写入正式数据。
@Observable final class Item {
    enum Category { case other; var symbol: String { "shippingbox.fill" } }
    let id: UUID
    var name: String
    var quantity: Int
    var thumbnailData: Data?
    var category: Category
    init(id: UUID = UUID(), name: String, category: Category = .other, quantity: Int = 1, thumbnailData: Data? = nil) {
        self.id = id; self.name = name; self.category = category
        self.quantity = quantity; self.thumbnailData = thumbnailData
    }
}

enum AppTheme {
    static let blue = Color.blue
    static let background = Color.white
    static let stickerDot = Color.gray.opacity(0.22)
}

extension Image {
    init(uiImage: NSImage) { self.init(nsImage: uiImage) }
}

struct StickerThumbnail {
    let image: NSImage
    let visibleCoverage: CGFloat
}

@MainActor enum StickerThumbnailStore {
    static var loads: [UUID: Int] = [:]
    static func thumbnail(id: UUID, data: Data) async -> StickerThumbnail? {
        loads[id, default: 0] += 1
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let result = StickerSubjectAnalyzer.prepare(image) else { return nil }
        return StickerThumbnail(image: NSImage(cgImage: result.image, size: .zero),
                                visibleCoverage: result.visibleCoverage)
    }
}

@MainActor enum LayoutProbe {
    static var nameWidths: [String: CGFloat] = [:]
}

/// 有固有宽度的原生文字控件，覆盖此前短名称压缩整格的布局触发条件。
struct StickerOutlinedText: NSViewRepresentable {
    let text: String
    let pointSize: CGFloat
    var lineLimit = 1
    var maximumWidth: CGFloat?

    func makeNSView(context: Context) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.backgroundColor = .clear
        label.alignment = .center
        return label
    }

    func updateNSView(_ label: NSTextField, context: Context) {
        let font = NSFont.systemFont(ofSize: pointSize, weight: .heavy)
        label.font = NSFont(descriptor: font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor, size: pointSize)
        label.stringValue = text
        label.maximumNumberOfLines = lineLimit
        label.lineBreakMode = .byTruncatingTail
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextField, context: Context) -> CGSize? {
        let width = min(proposal.width ?? .greatestFiniteMagnitude, maximumWidth ?? .greatestFiniteMagnitude)
        if lineLimit == 2, width < 10_000, width > 0 { LayoutProbe.nameWidths[text] = width }
        let font = nsView.font!
        let bounds = (text as NSString).boundingRect(with: CGSize(width: max(1, width - 10), height: 1000),
                                                   options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                   attributes: [.font: font])
        return CGSize(width: min(width, bounds.width + 10),
                      height: min(bounds.height, CGFloat(lineLimit) * (font.ascender - font.descender + font.leading)) + 10)
    }
}

@MainActor final class GridModel: ObservableObject {
    @Published var columns = 2
    @Published var editing = false
    let items: [Item]
    var cells: [UUID: CGSize] = [:]
    init(items: [Item]) { self.items = items }
}

struct CellSizeKey: PreferenceKey {
    static let defaultValue: [UUID: CGSize] = [:]
    static func reduce(value: inout [UUID: CGSize], nextValue: () -> [UUID: CGSize]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

struct GridHarness: View {
    @ObservedObject var model: GridModel
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let columnWidth = StickerStyle.columnWidth(containerWidth: geometry.size.width, pagePadding: 20, count: model.columns)
                let columns = Array(repeating: GridItem(.fixed(columnWidth), spacing: StickerStyle.columnSpacing), count: model.columns)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: StickerStyle.rowSpacing) {
                        ForEach(model.items, id: \.id) { item in
                            if model.editing {
                                cell(item, width: columnWidth)
                            } else {
                                NavigationLink { Text("物品详情") } label: { cell(item, width: columnWidth) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                }
                .background(DotGridBackground())
            }
        }
        .onPreferenceChange(CellSizeKey.self) { model.cells = $0 }
    }

    private func cell(_ item: Item, width: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            StickerGridItemView(item: item, height: StickerStyle.imageHeight(columnWidth: width))
            if model.editing { Image(systemName: "circle").padding(8) }
        }
        .frame(width: width)
        .frame(maxWidth: .infinity)
        .background {
            GeometryReader { geometry in
                Color.clear.preference(key: CellSizeKey.self, value: [item.id: geometry.size])
            }
        }
    }
}

@main struct CheckStickerGridLayout {
    static func fixture(_ index: Int) -> Data {
        let context = CGContext(data: nil, width: 200, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.16, green: 0.55, blue: 0.8, alpha: 1))
        switch index {
        case 0:
            context.fillEllipse(in: CGRect(x: 85, y: 92, width: 9, height: 18))
            context.fillEllipse(in: CGRect(x: 104, y: 94, width: 8, height: 16))
        case 1:
            context.fill(CGRect(x: 80, y: 50, width: 40, height: 110))
        case 2:
            context.fill(CGRect(x: 40, y: 55, width: 120, height: 90))
        case 3:
            context.fillEllipse(in: CGRect(x: 40, y: 40, width: 120, height: 120))
        case 4:
            context.fillEllipse(in: CGRect(x: 40, y: 40, width: 120, height: 120))
            context.setBlendMode(.clear)
            context.fillEllipse(in: CGRect(x: 70, y: 70, width: 60, height: 60))
        default:
            context.fill(CGRect(x: 92, y: 30, width: 16, height: 140))
        }
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @MainActor static func settle(_ view: NSView) {
        for _ in 0..<12 {
            view.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.015))
        }
    }

    @MainActor static func main() throws {
        _ = NSApplication.shared
        setvbuf(stdout, nil, _IONBF, 0)
        let names = ["耳机", "杯", "相机", "一个两行的比较长的物品名称", "圆环", "笔"]
        for width: CGFloat in [320, 393, 440, 768] {
            let items = names.enumerated().map {
                Item(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0.offset))!,
                     name: $0.element, quantity: 999, thumbnailData: fixture($0.offset))
            }
            let model = GridModel(items: items)
            let view = NSHostingView(rootView: GridHarness(model: model))
            view.frame = CGRect(x: 0, y: 0, width: width, height: 1200)
            for editing in [false, true] {
                model.editing = editing
                for count in 2...5 {
                    model.columns = count
                    settle(view)
                    let expected = StickerStyle.columnWidth(containerWidth: width, pagePadding: 20, count: count)
                    precondition(model.cells.count == items.count, "Cells not measured")
                    for item in items {
                        precondition(abs(model.cells[item.id]!.width - expected) < 1,
                                     "Cell collapsed: \(item.name) \(model.cells[item.id]!) expected \(expected)")
                        precondition(abs((LayoutProbe.nameWidths[item.name] ?? 0) - (expected - 8)) < 1,
                                     "Native label shrank image viewport: \(item.name) width \(LayoutProbe.nameWidths[item.name] ?? 0)")
                    }
                    print("PASS: actual SwiftUI \(Int(width))pt / \(count) columns / \(editing ? "editing" : "NavigationLink"), short and long labels fill same width")
                }
            }
            model.editing = false
            model.columns = 2
            settle(view)
            let before = StickerThumbnailStore.loads[items[0].id]!
            let previousAngle = StickerStyle.rotationAngle(for: items[0].id)
            items[0].name = "修改后的耳机名字"
            items[0].quantity = 5
            settle(view)
            precondition(StickerThumbnailStore.loads[items[0].id] == before, "Name/quantity edit restarted image work")
            precondition(StickerStyle.rotationAngle(for: items[0].id) == previousAngle)
            print("PASS: name/quantity update retains loaded thumbnail and stable angle")
        }
        print("PASS: native SwiftUI grid layout, actual production StickerGridItemView, AppKit image/text adapters")
    }
}
