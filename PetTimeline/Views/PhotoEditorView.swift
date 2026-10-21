import SwiftUI
import PencilKit

/// 照片编辑视图：支持添加文字、表情和涂鸦
struct PhotoEditorView: View {
    let imageData: Data
    let onSave: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var canvasView: PKCanvasView = PKCanvasView()
    @State private var textElements: [TextElement] = []
    @State private var emojiElements: [EmojiElement] = []
    @State private var currentText: String = ""
    @State private var currentEmoji: String = ""
    @State private var textSize: CGFloat = 28
    @State private var textColor: Color = .white
    @State private var showingTextInput = false
    @State private var showingEmojiPicker = false
    @State private var showingColorPicker = false
    @State private var selectedTool: Tool = .pen
    @State private var lineWidth: CGFloat = 3.0
    @State private var strokeColor: Color = .red
    @State private var imageSize: CGSize = .zero
    @State private var canvasOffset: CGPoint = .zero

    enum Tool {
        case pen, eraser, text, emoji
    }

    struct TextElement: Identifiable {
        let id = UUID()
        var text: String
        var position: CGPoint  // 相对于图片中心的偏移
        var size: CGFloat
        var color: Color
    }

    struct EmojiElement: Identifiable {
        let id = UUID()
        var emoji: String
        var position: CGPoint  // 相对于图片中心的偏移
        var size: CGFloat
    }

    var body: some View {
        ZStack {
            // 黑色背景
            Color.black
                .ignoresSafeArea()

            GeometryReader { geometry in
                ZStack {
                    // 基础图片（居中等比缩放，计算实际显示尺寸）
                    if let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(
                                GeometryReader { imageGeo in
                                    Color.clear
                                        .onAppear {
                                            updateImageSize(in: imageGeo.size, containerSize: geometry.size)
                                        }
                                        .onChange(of: imageGeo.size) { _, newSize in
                                            updateImageSize(in: newSize, containerSize: geometry.size)
                                        }
                                }
                            )
                    }

                    // 画布（透明背景，叠加在图片上，尺寸与图片一致）
                    if imageSize != .zero {
                        CanvasView(canvasView: $canvasView, lineWidth: $lineWidth, strokeColor: $strokeColor, selectedTool: $selectedTool)
                            .frame(width: imageSize.width, height: imageSize.height)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }

                    // 文字元素
                    ForEach(textElements) { element in
                        Text(element.text)
                            .font(.system(size: element.size))
                            .foregroundColor(element.color)
                            .position(
                                x: geometry.size.width / 2 + element.position.x,
                                y: geometry.size.height / 2 + element.position.y
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if let index = textElements.firstIndex(where: { $0.id == element.id }) {
                                            textElements[index].position = CGPoint(
                                                x: value.location.x - geometry.size.width / 2,
                                                y: value.location.y - geometry.size.height / 2
                                            )
                                        }
                                    }
                            )
                    }

                    // 表情元素
                    ForEach(emojiElements) { element in
                        Text(element.emoji)
                            .font(.system(size: element.size))
                            .position(
                                x: geometry.size.width / 2 + element.position.x,
                                y: geometry.size.height / 2 + element.position.y
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        if let index = emojiElements.firstIndex(where: { $0.id == element.id }) {
                                            emojiElements[index].position = CGPoint(
                                                x: value.location.x - geometry.size.width / 2,
                                                y: value.location.y - geometry.size.height / 2
                                            )
                                        }
                                    }
                            )
                    }

                    // 顶部工具栏
                    VStack {
                        HStack {
                            Button("取消") {
                                dismiss()
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)

                            Spacer()

                            Button("完成") {
                                saveEditedImage()
                            }
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        Spacer()

                        // 底部工具栏
                        HStack(spacing: 16) {
                            ToolButton(icon: "pencil", label: "笔", isSelected: selectedTool == .pen) {
                                selectedTool = .pen
                            }
                            ToolButton(icon: "eraser.fill", label: "橡皮", isSelected: selectedTool == .eraser) {
                                selectedTool = .eraser
                            }
                            ToolButton(icon: "textformat.size", label: "文字", isSelected: selectedTool == .text) {
                                selectedTool = .text
                                showingTextInput = true
                            }
                            ToolButton(icon: "face.smiling", label: "表情", isSelected: selectedTool == .emoji) {
                                selectedTool = .emoji
                                showingEmojiPicker = true
                            }
                            ToolButton(icon: "paintpalette", label: "颜色", isSelected: showingColorPicker) {
                                showingColorPicker = true
                            }
                            ToolButton(icon: "trash", label: "清除", isSelected: false) {
                                canvasView.drawing = PKDrawing()
                                textElements.removeAll()
                                emojiElements.removeAll()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.regularMaterial)
                    }
                }
            }
        }
        .sheet(isPresented: $showingTextInput) {
            TextInputView(text: $currentText, size: $textSize, color: $textColor) { newText in
                if !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // 新文字默认放在图片中心
                    textElements.append(TextElement(
                        text: newText,
                        position: .zero,
                        size: textSize,
                        color: textColor
                    ))
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingEmojiPicker) {
            EmojiPickerView(selectedEmoji: $currentEmoji) { emoji in
                emojiElements.append(EmojiElement(
                    emoji: emoji,
                    position: .zero,
                    size: 60
                ))
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerView(selectedColor: $textColor, strokeColor: $strokeColor)
                .presentationDetents([.medium])
        }
    }

    private func updateImageSize(in imageFrameSize: CGSize, containerSize: CGSize) {
        guard let uiImage = UIImage(data: imageData) else { return }
        let imageAspect = uiImage.size.width / uiImage.size.height
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            // 图片更宽，受限于容器宽度
            imageSize = CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
        } else {
            // 图片更高，受限于容器高度
            imageSize = CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
        }
    }

    private func saveEditedImage() {
        guard let uiImage = UIImage(data: imageData) else {
            dismiss()
            return
        }

        // 使用原始图片尺寸进行渲染
        let originalSize = uiImage.size
        let renderer = ImageRenderer(content:
            ZStack {
                // 原始图片
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()

                // 画布内容 - 使用 PKCanvasView 的 drawing 生成图片
                CanvasRenderView(
                    drawing: canvasView.drawing,
                    imageSize: originalSize
                )

                // 文字元素
                ForEach(textElements) { element in
                    Text(element.text)
                        .font(.system(size: element.size * originalSize.width / imageSize.width))
                        .foregroundColor(element.color)
                        .position(
                            x: originalSize.width / 2 + element.position.x * originalSize.width / imageSize.width,
                            y: originalSize.height / 2 + element.position.y * originalSize.height / imageSize.height
                        )
                }

                // 表情元素
                ForEach(emojiElements) { element in
                    Text(element.emoji)
                        .font(.system(size: element.size * originalSize.width / imageSize.width))
                        .position(
                            x: originalSize.width / 2 + element.position.x * originalSize.width / imageSize.width,
                            y: originalSize.height / 2 + element.position.y * originalSize.height / imageSize.height
                        )
                }
            }
            .frame(width: originalSize.width, height: originalSize.height)
        )

        renderer.scale = 1.0

        if let renderedImage = renderer.uiImage,
           let data = renderedImage.jpegData(compressionQuality: 0.9) {
            onSave(data)
        }

        dismiss()
    }
}

// MARK: - Supporting Views

/// 画布渲染视图 - 用于 ImageRenderer 生成最终图片
struct CanvasRenderView: View {
    let drawing: PKDrawing
    let imageSize: CGSize

    var body: some View {
        Canvas { context, size in
            // 将 PKDrawing 渲染到 Canvas 上，区域等同于最终图片尺寸
            let drawingImage = drawing.image(from: drawing.bounds, scale: 1.0)
            if let cgImage = drawingImage.cgImage {
                context.draw(
                    Image(decorative: cgImage, scale: 1.0, orientation: .up),
                    in: CGRect(origin: .zero, size: imageSize)
                )
            }
        }
        .frame(width: imageSize.width, height: imageSize.height)
    }
}

struct CanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var lineWidth: CGFloat
    @Binding var strokeColor: Color
    @Binding var selectedTool: PhotoEditorView.Tool

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.isOpaque = false
        canvasView.backgroundColor = .clear
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .red, width: 3)
        canvasView.minimumZoomScale = 1
        canvasView.maximumZoomScale = 1
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        switch selectedTool {
        case .pen:
            uiView.tool = PKInkingTool(.pen, color: UIColor(strokeColor), width: lineWidth)
        case .eraser:
            uiView.tool = PKEraserTool(.vector)
        case .text, .emoji:
            // 非绘图工具时保持当前工具但不响应输入
            break
        }
    }
}

struct ToolButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .accentColor : .primary)
            .frame(width: 50, height: 50)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(8)
        }
    }
}

struct TextInputView: View {
    @Binding var text: String
    @Binding var size: CGFloat
    @Binding var color: Color
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("输入文字", text: $text, axis: .vertical)
                    .font(.system(size: 24))
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .frame(minHeight: 120)

                VStack(alignment: .leading, spacing: 8) {
                    Text("字号: \(Int(size))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $size, in: 12...80, step: 1)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("颜色")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        ForEach([Color.white, Color.red, Color.yellow, Color.green, Color.blue, Color.pink, Color.orange, Color.black], id: \.self) { c in
                            Circle()
                                .fill(c)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(color == c ? Color.primary : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    color = c
                                }
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("添加文字")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onSave(text)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    let onSelect: (String) -> Void

    let emojis = [
        "😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "😊", "😇",
        "🙂", "🙃", "😉", "😌", "😍", "😘", "😗", "😙", "😚", "😋",
        "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🤩", "🥶",
        "🥵", "😱", "😨", "😰", "😥", "😓", "🤗", "🤔", "🤭", "🤫",
        "🤥", "😶", "😐", "😑", "😬", "🙄", "😯", "😦", "😧", "😖",
        "😣", "😞", "😟", "😤", "😢", "😭", "😦", "😧", "😨", "😩",
        "🤯", "😳", "🥵", "🥶", "😱", "😖", "😣", "😞", "😟", "😤",
        "😢", "😭", "😂", "🤣", "😊", "😇", "🙂", "🙃", "😉", "😌",
        "😍", "😘", "😗", "😙", "😚", "😋", "😛", "😝", "😜", "🤪",
        "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯",
        "🦁", "🐮", "🐷", "🐸", "🐵", "🙈", "🙉", "🙊", "🐒", "🐔",
        "🐧", "🐦", "🐤", "🐣", "🐥", "🦆", "🦅", "🦉", "🦇", "🐺",
        "🐗", "🐴", "🦌", "🐭", "🐹", "🐰", "🦝", "🐻", "🐨", "🐾"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(emojis, id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 32))
                            .frame(width: 50, height: 50)
                            .background(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                            .onTapGesture {
                                selectedEmoji = emoji
                                onSelect(emoji)
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("选择表情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { selectedEmoji = "" }
                }
            }
        }
    }
}

struct ColorPickerView: View {
    @Binding var selectedColor: Color
    @Binding var strokeColor: Color
    @Environment(\.dismiss) private var dismiss

    let colors: [Color] = [.white, .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown, .black]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("文字颜色")
                    .font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                            )
                            .onTapGesture {
                                selectedColor = color
                            }
                    }
                }
                .padding()

                Divider()

                Text("画笔颜色")
                    .font(.headline)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(strokeColor == color ? Color.primary : Color.clear, lineWidth: 3)
                            )
                            .onTapGesture {
                                strokeColor = color
                            }
                    }
                }
                .padding()

                Spacer()
            }
            .navigationTitle("选择颜色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
