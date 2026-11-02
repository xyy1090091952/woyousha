#if DEBUG
import SwiftUI

/// 开发版内查看真实设备的分段耗时，发布版不显示调试入口。
struct PhotoProcessingTimingView: View {
    let snapshot: PhotoPerformanceTrace.Snapshot
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("总等待", value: duration(snapshot.totalMilliseconds))
                    if let title = snapshot.bottleneckTitle {
                        LabeledContent("最久的一步", value: title)
                    }
                    Text(snapshot.separated ? "已完成主体分离和贴纸制作" : "本次未完成主体分离，已保留原图")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("记录于 \(snapshot.recordedAt.formatted(date: .omitted, time: .standard))。总等待包含拍照、处理和队列交接；保存物品不计入。")
                }
                Section("每一步花了多久") {
                    ForEach(snapshot.entries) { entry in
                        LabeledContent(entry.stage.title, value: duration(entry.milliseconds))
                    }
                    LabeledContent("其他未细分开销", value: duration(snapshot.handoffMilliseconds))
                }
                Section {
                    if let size = snapshot.sourceSize {
                        LabeledContent("相机照片", value: size.description)
                    }
                    if let size = snapshot.preparedSize {
                        LabeledContent("保留清晰度的图片", value: size.description)
                    }
                    if let size = snapshot.analysisSize {
                        LabeledContent("分析轮廓的图片", value: size.description)
                    }
                } header: {
                    Text("实际处理的图片尺寸")
                } footer: {
                    Text("取景窗口的大小不决定拍摄像素。首次使用系统抠图可能还包含模型启动时间；连续拍摄的记录可用于对照。")
                }
            }
            .navigationTitle("照片处理用时")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
        .tint(AppTheme.accent)
    }

    private func duration(_ milliseconds: Double) -> String {
        if milliseconds < 1000 { return "\(Int(milliseconds.rounded())) 毫秒" }
        return String(format: "%.2f 秒", milliseconds / 1000)
    }
}
#endif
