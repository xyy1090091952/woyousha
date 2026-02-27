//
//  AddItemView.swift
//  woyousha
//
//  Created by ByteDance on 2/27/26.
//

import SwiftUI
import SwiftData

// 这个页面是用来让用户输入新物品信息的表单
// 类似于 Web 开发中的 <form> 页面
struct AddItemView: View {
    // 环境变量：用于关闭当前弹窗 (类似于 history.back() 或 router.back())
    @Environment(\.dismiss) private var dismiss
    
    // 环境变量：数据库操作上下文 (类似于 DB connection)
    @Environment(\.modelContext) private var modelContext
    
    // @State 标记的变量是页面内部的状态
    // 当用户输入内容时，这些变量会自动更新 (类似于 Vue 的 v-model)
    @State private var name: String = ""
    @State private var category: String = "衣服" // 默认分类
    @State private var quantity: Int = 1
    @State private var location: String = ""
    @State private var note: String = ""
    
    // 预定义的分类列表，后面可以从数据库动态获取
    let categories = ["衣服", "工具", "药品", "书籍", "食品", "其他"]
    
    var body: some View {
        NavigationStack {
            Form {
                // 第一部分：基本信息
                Section("基本信息") {
                    // TextField 类似于 <input type="text">
                    TextField("物品名称 (必填)", text: $name)
                    
                    // Picker 类似于 <select> 下拉框
                    Picker("分类", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }
                
                // 第二部分：位置与数量
                Section("位置与数量") {
                    TextField("存放位置 (例如: 衣柜第二层)", text: $location)
                    
                    // Stepper 是加减号控件，适合调节数量
                    Stepper("数量: \(quantity)", value: $quantity, in: 1...999)
                }
                
                // 第三部分：备注
                Section("备注") {
                    // TextEditor 类似于 <textarea> 多行文本框
                    TextField("备注信息 (选填)", text: $note, axis: .vertical)
                        .lineLimit(3...6) // 限制显示 3-6 行高度
                }
            }
            .navigationTitle("添加新物品")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左上角取消按钮
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss() // 关闭页面
                    }
                }
                
                // 右上角保存按钮
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveItem()
                    }
                    .disabled(name.isEmpty) // 如果名字没填，禁用按钮 (表单验证)
                }
            }
        }
    }
    
    // 保存逻辑
    private func saveItem() {
        // 1. 创建新物品对象
        let newItem = Item(
            name: name,
            category: category,
            quantity: quantity,
            location: location,
            note: note
        )
        
        // 2. 插入数据库
        modelContext.insert(newItem)
        
        // 3. 关闭页面
        dismiss()
    }
}

// 预览视图
#Preview {
    AddItemView()
        .modelContainer(for: Item.self, inMemory: true)
}
