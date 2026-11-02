import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// 独立的原生图像检查，只创建内存样例，不访问 App 数据库。
@main struct CheckStickerSizing {
    static func fixture(width: Int = 200, height: Int = 200, draw: (CGContext) -> Void) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.15, green: 0.55, blue: 0.8, alpha: 1))
        draw(context)
        return context.makeImage()!
    }

    static func pixels(_ image: CGImage) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                    bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return bytes
    }

    static func colorCentroid(_ image: CGImage, red: Bool) -> CGFloat {
        let bytes = pixels(image)
        var sum: CGFloat = 0, count: CGFloat = 0
        for index in 0..<(image.width * image.height) {
            let r = Int(bytes[index * 4]), b = Int(bytes[index * 4 + 2]), alpha = bytes[index * 4 + 3]
            if alpha > 240, red ? r > b + 40 : b > r + 40 {
                sum += CGFloat(index / image.width); count += 1
            }
        }
        precondition(count > 0)
        return sum / count / CGFloat(image.height)
    }

    static func displayArea(_ image: StickerSubjectAnalyzer.PreparedImage, viewport: CGSize, angle: Double = 0) -> CGFloat {
        let size = StickerStyle.imageSize(CGSize(width: image.image.width, height: image.image.height),
                                         fitting: viewport, visibleCoverage: image.visibleCoverage, rotationDegrees: angle)
        return size.width * size.height * image.visibleCoverage
    }

    static func main() throws {
        let small = fixture {
            $0.fill(CGRect(x: 94, y: 91, width: 12, height: 18))
            $0.fill(CGRect(x: 196, y: 3, width: 1, height: 1)) // 远离主体的孤立噪点。
        }
        let large = fixture { $0.fill(CGRect(x: 60, y: 40, width: 80, height: 120)) }
        let smallSubject = StickerSubjectAnalyzer.subject(in: small)!
        precondition(smallSubject.image.width == 14 && smallSubject.image.height == 20,
                     "Noise stretched the crop: \(smallSubject.image.width) × \(smallSubject.image.height)")
        let smallPrepared = StickerSubjectAnalyzer.prepare(small)!
        let largePrepared = StickerSubjectAnalyzer.prepare(large)!
        precondition(max(smallPrepared.image.width, smallPrepared.image.height) == 208)
        precondition(max(largePrepared.image.width, largePrepared.image.height) == 208,
                     "Outline/padding were added before subject normalization")
        let viewport = CGSize(width: 160, height: 210)
        precondition(abs(displayArea(smallPrepared, viewport: viewport) / displayArea(largePrepared, viewport: viewport) - 1) < 0.01,
                     "Identical subjects in different canvases have different perceived areas")
        print("PASS: tiny historical subject, isolated noise, normalized outline/padding, equal visible display area")

        let pair = fixture {
            $0.fillEllipse(in: CGRect(x: 45, y: 70, width: 24, height: 50))
            $0.fillEllipse(in: CGRect(x: 108, y: 77, width: 18, height: 42))
            $0.fill(CGRect(x: 1, y: 1, width: 1, height: 1))
        }
        let pairSubject = StickerSubjectAnalyzer.subject(in: pair)!
        precondition(pairSubject.image.width > 75 && pairSubject.image.width < 90,
                     "Second earbud was removed or noise expanded bounds")
        precondition(StickerSubjectAnalyzer.visibleCoverage(of: pairSubject.image) < 0.5)
        let pairPrepared = StickerSubjectAnalyzer.prepare(pair)!
        precondition(pairPrepared.visibleCoverage > 0.2 && pairPrepared.visibleCoverage < 0.6)
        print("PASS: both separate earbud subjects retained, gap excluded from visible area")

        let asymmetric = fixture(width: 120, height: 200) {
            $0.setFillColor(CGColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1))
            $0.fill(CGRect(x: 35, y: 122, width: 36, height: 28))
            $0.setFillColor(CGColor(red: 0.1, green: 0.2, blue: 0.9, alpha: 1))
            $0.fill(CGRect(x: 35, y: 75, width: 36, height: 47))
        }
        let asymmetricOutput = StickerSubjectAnalyzer.prepare(asymmetric)!.image
        let oldOrder = colorCentroid(asymmetric, red: true) < colorCentroid(asymmetric, red: false)
        let newOrder = colorCentroid(asymmetricOutput, red: true) < colorCentroid(asymmetricOutput, red: false)
        precondition(oldOrder == newOrder, "Cropping/normalization flipped the photo")
        let colors = pixels(asymmetricOutput)
        precondition(colors[3] == 0 && colors[(asymmetricOutput.width - 1) * 4 + 3] == 0,
                     "White outline lost transparent outer padding")
        precondition(stride(from: 0, to: colors.count, by: 4).contains { base in
            let alpha = Int(colors[base + 3])
            // RGBA 是预乘格式：半透明白色的 RGB 等于 alpha，并不一定是 255。
            return alpha > 64 && (0..<3).allSatisfy { abs(Int(colors[base + $0]) - alpha) < 3 }
        }, "White outline was not generated")
        print("PASS: non-square top/bottom colors retain direction, transparent edges and true white outline")

        let opaque = fixture(width: 200, height: 120) { $0.fill(CGRect(x: 0, y: 0, width: 200, height: 120)) }
        let opaquePrepared = StickerSubjectAnalyzer.prepare(opaque)!
        precondition(opaquePrepared.image.width == 200 && opaquePrepared.image.height == 120)
        precondition(pixels(opaquePrepared.image) == pixels(opaque) && opaquePrepared.visibleCoverage == 1)
        precondition(StickerSubjectAnalyzer.prepare(fixture { _ in }) == nil)
        print("PASS: opaque photo unchanged, empty transparent image uses placeholder")

        let square = StickerSubjectAnalyzer.prepare(fixture { $0.fill(CGRect(x: 45, y: 45, width: 110, height: 110)) })!
        let circle = StickerSubjectAnalyzer.prepare(fixture { $0.fillEllipse(in: CGRect(x: 40, y: 40, width: 120, height: 120)) })!
        let ring = StickerSubjectAnalyzer.prepare(fixture {
            $0.fillEllipse(in: CGRect(x: 40, y: 40, width: 120, height: 120))
            $0.setBlendMode(.clear)
            $0.fillEllipse(in: CGRect(x: 70, y: 70, width: 60, height: 60))
        })!
        let areas = [square, circle, ring].map { displayArea($0, viewport: viewport, angle: 4) }
        precondition(areas.max()! / areas.min()! < 1.01, "Compact/hollow subjects did not normalize by alpha area")
        let squareSize = StickerStyle.imageSize(CGSize(width: square.image.width, height: square.image.height),
                                               fitting: viewport, visibleCoverage: square.visibleCoverage, rotationDegrees: 4)
        let ringSize = StickerStyle.imageSize(CGSize(width: ring.image.width, height: ring.image.height),
                                             fitting: viewport, visibleCoverage: ring.visibleCoverage, rotationDegrees: 4)
        precondition(ringSize.width > squareSize.width, "Hollow shape was not given extra display space")
        print("PASS: square/circle/hollow shapes have equal visible area, hollow shape appears larger")

        var positive = 0, negative = 0, unique = Set<Double>()
        for number in 0..<100 {
            let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
            let angle = StickerStyle.rotationAngle(for: id)
            precondition(angle == StickerStyle.rotationAngle(for: id))
            precondition(abs(angle) >= 2 && abs(angle) <= 5.5)
            if angle > 0 { positive += 1 } else { negative += 1 }
            unique.insert(angle)
        }
        precondition(positive > 30 && negative > 30 && unique.count > 40)
        for width: CGFloat in [320, 393, 440, 768] {
            for count in 2...5 {
                let columnWidth = StickerStyle.columnWidth(containerWidth: width, pagePadding: 20, count: count)
                let view = CGSize(width: columnWidth - StickerStyle.cellPadding * 2,
                                  height: StickerStyle.imageHeight(columnWidth: columnWidth))
                for shape in [CGSize(width: 208, height: 208), CGSize(width: 100, height: 208),
                              CGSize(width: 208, height: 70), CGSize(width: 10, height: 208)] {
                    for angle: Double in [-5.5, -2, 2, 5.5] {
                        let fit = StickerStyle.imageSize(shape, fitting: view, visibleCoverage: 0.4, rotationDegrees: angle)
                        let cosine = abs(cos(angle * .pi / 180)), sine = abs(sin(angle * .pi / 180))
                        precondition(fit.width * cosine + fit.height * sine <= view.width + 0.001)
                        precondition(fit.width * sine + fit.height * cosine <= view.height + 0.001)
                        precondition(abs(fit.width / fit.height - shape.width / shape.height) < 0.001)
                        let group = StickerStyle.groupSize(imageSize: fit, viewport: view, hasQuantity: true)
                        precondition(group.width * cosine + group.height * sine <= columnWidth + 0.001,
                                     "Rotated quantity label crossed cell width")
                        precondition(group.width * sine + group.height * cosine <= view.height + 0.001,
                                     "Rotated quantity label crossed image viewport")
                    }
                }
            }
        }
        print("PASS: stable ±2…5.5° tilt, 320–768pt / 2–5 columns, no stretched images or rotated overflow")

        let start = Date()
        for _ in 0..<12 { _ = StickerSubjectAnalyzer.prepare(pair) }
        print("INFO: warm 200px image preparation average \(Int(Date().timeIntervalSince(start) / 12 * 1000)) ms on Mac; not iPhone performance")
        print("PASS: all native CGImage sticker size checks")
    }
}
