import AppKit
import SwiftUI

// MARK: - Drawing Models

enum DrawingTool: String, CaseIterable {
    case pen = "pencil.line"
    case arrow = "arrow.up.right"
    case rectangle = "rectangle"
    case text = "textformat"
    case eraser = "eraser"

    var label: String {
        switch self {
        case .pen: return "Pen"
        case .arrow: return "Arrow"
        case .rectangle: return "Rect"
        case .text: return "Text"
        case .eraser: return "Eraser"
        }
    }
}

struct DrawingElement: Identifiable {
    let id = UUID()
    let tool: DrawingTool
    let color: NSColor
    let lineWidth: CGFloat
    var points: [CGPoint]  // for pen
    var startPoint: CGPoint
    var endPoint: CGPoint
    var text: String?
}

// MARK: - Undo Manager

@Observable
final class DrawingHistory {
    var elements: [DrawingElement] = []
    private var undoStack: [[DrawingElement]] = []
    private var redoStack: [[DrawingElement]] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func addElement(_ element: DrawingElement) {
        undoStack.append(elements)
        redoStack.removeAll()
        elements.append(element)
    }

    func updateLastElement(_ element: DrawingElement) {
        guard !elements.isEmpty else { return }
        elements[elements.count - 1] = element
    }

    func removeElements(matching predicate: (DrawingElement) -> Bool) {
        let before = elements
        elements.removeAll(where: predicate)
        if elements.count != before.count {
            undoStack.append(before)
            redoStack.removeAll()
        }
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(elements)
        elements = previous
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(elements)
        elements = next
    }
}

// MARK: - Editor View

struct ScreenshotEditorView: View {
    let originalImage: NSImage
    let onSave: (NSImage) -> Void
    let onCancel: () -> Void
    let onPin: ((NSImage) -> Void)?

    @State private var currentTool: DrawingTool = .pen
    @State private var currentColor: Color = .red
    @State private var lineWidth: CGFloat = 3
    @State private var history = DrawingHistory()
    @State private var currentElement: DrawingElement?

    // Inline text editing
    @State private var isEditingText = false
    @State private var textEditPoint: CGPoint = .zero
    @State private var textEditValue: String = ""
    @FocusState private var textFieldFocused: Bool

    private let availableColors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .white, .black]

    var body: some View {
        VStack(spacing: 0) {
            // Canvas
            ZStack(alignment: .topLeading) {
                // Background image
                Image(nsImage: originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                // Drawing canvas overlay
                DrawingCanvasView(
                    elements: history.elements,
                    currentElement: currentElement,
                    imageSize: originalImage.size
                )

                // Mouse interaction layer
                DrawingInteractionView(
                    tool: currentTool,
                    color: currentColor,
                    lineWidth: lineWidth,
                    isEditingText: isEditingText,
                    onElementStarted: { element in
                        currentElement = element
                    },
                    onElementUpdated: { element in
                        currentElement = element
                    },
                    onElementFinished: { element in
                        if currentTool == .text {
                            commitCurrentText()
                            textEditPoint = element.startPoint
                            textEditValue = ""
                            isEditingText = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                textFieldFocused = true
                            }
                        } else if currentTool == .eraser {
                            eraseAt(element.endPoint)
                        } else {
                            history.addElement(element)
                        }
                        currentElement = nil
                    }
                )

                // Inline text field
                if isEditingText {
                    InlineTextFieldView(
                        text: $textEditValue,
                        isFocused: $textFieldFocused,
                        color: currentColor,
                        fontSize: max(14, lineWidth * 5),
                        position: textEditPoint,
                        onCommit: { commitCurrentText() }
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Spacer().frame(height: 12)

            // Toolbar
            toolbarView
        }
        .padding(16)
        .background(Color.white.opacity(0.95))
        .environment(\.colorScheme, .light)
    }

    // MARK: - Commit inline text

    private func commitCurrentText() {
        guard isEditingText, !textEditValue.isEmpty else {
            isEditingText = false
            textEditValue = ""
            return
        }
        var element = DrawingElement(
            tool: .text,
            color: NSColor(currentColor),
            lineWidth: lineWidth,
            points: [],
            startPoint: textEditPoint,
            endPoint: textEditPoint
        )
        element.text = textEditValue
        history.addElement(element)
        isEditingText = false
        textEditValue = ""
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack(spacing: 12) {
            // Drawing tools
            ForEach(DrawingTool.allCases, id: \.rawValue) { tool in
                Button {
                    if isEditingText { commitCurrentText() }
                    currentTool = tool
                } label: {
                    Image(systemName: tool.rawValue)
                        .font(.system(size: 14))
                        .frame(width: 30, height: 30)
                        .background(currentTool == tool ? Color.accentColor.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help(tool.label)
            }

            Divider().frame(height: 24)

            // Colors
            ForEach(availableColors, id: \.self) { color in
                Button {
                    currentColor = color
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 18, height: 18)
                        .overlay {
                            if currentColor == color {
                                Circle().stroke(Color.gray, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }

            Divider().frame(height: 24)

            // Line width
            Slider(value: $lineWidth, in: 1...10, step: 1)
                .frame(width: 60)

            Divider().frame(height: 24)

            // Undo
            Button {
                history.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .disabled(!history.canUndo)
            .help("Undo (Cmd+Z)")

            // Redo
            Button {
                history.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .disabled(!history.canRedo)
            .help("Redo (Cmd+Shift+Z)")

            Spacer()

            // Pin button
            if let onPin {
                Button {
                    commitCurrentText()
                    let finalImage = renderFinalImage()
                    onPin(finalImage)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pin")
                        Text("Pin")
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            // Cancel
            Button {
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.plain)

            // Save & Copy
            Button {
                commitCurrentText()
                let finalImage = renderFinalImage()
                onSave(finalImage)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Text("Save & Copy")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Erase

    private func eraseAt(_ point: CGPoint) {
        let threshold: CGFloat = 15
        history.removeElements { element in
            switch element.tool {
            case .pen:
                return element.points.contains { p in
                    hypot(p.x - point.x, p.y - point.y) < threshold
                }
            case .arrow, .rectangle:
                let r = NSRect(
                    x: min(element.startPoint.x, element.endPoint.x),
                    y: min(element.startPoint.y, element.endPoint.y),
                    width: abs(element.endPoint.x - element.startPoint.x),
                    height: abs(element.endPoint.y - element.startPoint.y)
                ).insetBy(dx: -threshold, dy: -threshold)
                return r.contains(point)
            case .text:
                return hypot(element.startPoint.x - point.x, element.startPoint.y - point.y) < threshold * 3
            case .eraser:
                return false
            }
        }
    }

    // MARK: - Render Final Image

    func renderFinalImage() -> NSImage {
        let size = originalImage.size
        let image = NSImage(size: size)
        image.lockFocus()

        originalImage.draw(in: NSRect(origin: .zero, size: size))

        for element in history.elements {
            drawElement(element, in: size)
        }

        image.unlockFocus()
        return image
    }

    private func drawElement(_ element: DrawingElement, in size: NSSize) {
        element.color.setStroke()
        element.color.setFill()

        switch element.tool {
        case .pen:
            guard element.points.count > 1 else { return }
            let path = NSBezierPath()
            path.lineWidth = element.lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: element.points[0])
            for i in 1..<element.points.count {
                path.line(to: element.points[i])
            }
            path.stroke()

        case .arrow:
            let path = NSBezierPath()
            path.lineWidth = element.lineWidth
            path.move(to: element.startPoint)
            path.line(to: element.endPoint)
            path.stroke()

            let angle = atan2(element.endPoint.y - element.startPoint.y,
                              element.endPoint.x - element.startPoint.x)
            let headLength: CGFloat = 15
            let headAngle: CGFloat = .pi / 6

            let arrowPath = NSBezierPath()
            arrowPath.lineWidth = element.lineWidth
            arrowPath.move(to: element.endPoint)
            arrowPath.line(to: CGPoint(
                x: element.endPoint.x - headLength * cos(angle - headAngle),
                y: element.endPoint.y - headLength * sin(angle - headAngle)
            ))
            arrowPath.move(to: element.endPoint)
            arrowPath.line(to: CGPoint(
                x: element.endPoint.x - headLength * cos(angle + headAngle),
                y: element.endPoint.y - headLength * sin(angle + headAngle)
            ))
            arrowPath.stroke()

        case .rectangle:
            let rect = NSRect(
                x: min(element.startPoint.x, element.endPoint.x),
                y: min(element.startPoint.y, element.endPoint.y),
                width: abs(element.endPoint.x - element.startPoint.x),
                height: abs(element.endPoint.y - element.startPoint.y)
            )
            let path = NSBezierPath(rect: rect)
            path.lineWidth = element.lineWidth
            path.stroke()

        case .text:
            if let text = element.text {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: max(14, element.lineWidth * 5), weight: .medium),
                    .foregroundColor: element.color
                ]
                text.draw(at: element.startPoint, withAttributes: attrs)
            }

        case .eraser:
            break
        }
    }
}

// MARK: - Inline Text Field (positioned on canvas)

struct InlineTextFieldView: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let color: Color
    let fontSize: CGFloat
    let position: CGPoint
    let onCommit: () -> Void

    var body: some View {
        GeometryReader { geo in
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(color)
                .focused(isFocused)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.8))
                .border(color.opacity(0.5), width: 1)
                .frame(width: max(120, min(geo.size.width - position.x - 20, 400)))
                .position(
                    x: position.x + max(60, min((geo.size.width - position.x - 20) / 2, 200)),
                    y: geo.size.height - position.y
                )
                .onSubmit {
                    onCommit()
                }
        }
        .allowsHitTesting(true)
    }
}

// MARK: - Drawing Canvas (renders elements)

struct DrawingCanvasView: NSViewRepresentable {
    let elements: [DrawingElement]
    let currentElement: DrawingElement?
    let imageSize: NSSize

    func makeNSView(context: Context) -> DrawingCanvasNSView {
        let view = DrawingCanvasNSView()
        return view
    }

    func updateNSView(_ nsView: DrawingCanvasNSView, context: Context) {
        nsView.elements = elements
        nsView.currentElement = currentElement
        nsView.needsDisplay = true
    }
}

class DrawingCanvasNSView: NSView {
    var elements: [DrawingElement] = []
    var currentElement: DrawingElement?

    override func draw(_ dirtyRect: NSRect) {
        let allElements = currentElement != nil ? elements + [currentElement!] : elements
        for element in allElements {
            drawElement(element)
        }
    }

    private func drawElement(_ element: DrawingElement) {
        element.color.setStroke()
        element.color.setFill()

        switch element.tool {
        case .pen:
            guard element.points.count > 1 else { return }
            let path = NSBezierPath()
            path.lineWidth = element.lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: element.points[0])
            for i in 1..<element.points.count {
                path.line(to: element.points[i])
            }
            path.stroke()

        case .arrow:
            let path = NSBezierPath()
            path.lineWidth = element.lineWidth
            path.move(to: element.startPoint)
            path.line(to: element.endPoint)
            path.stroke()
            let angle = atan2(element.endPoint.y - element.startPoint.y,
                              element.endPoint.x - element.startPoint.x)
            let headLength: CGFloat = 15
            let headAngle: CGFloat = .pi / 6
            let arrowPath = NSBezierPath()
            arrowPath.lineWidth = element.lineWidth
            arrowPath.move(to: element.endPoint)
            arrowPath.line(to: CGPoint(
                x: element.endPoint.x - headLength * cos(angle - headAngle),
                y: element.endPoint.y - headLength * sin(angle - headAngle)
            ))
            arrowPath.move(to: element.endPoint)
            arrowPath.line(to: CGPoint(
                x: element.endPoint.x - headLength * cos(angle + headAngle),
                y: element.endPoint.y - headLength * sin(angle + headAngle)
            ))
            arrowPath.stroke()

        case .rectangle:
            let rect = NSRect(
                x: min(element.startPoint.x, element.endPoint.x),
                y: min(element.startPoint.y, element.endPoint.y),
                width: abs(element.endPoint.x - element.startPoint.x),
                height: abs(element.endPoint.y - element.startPoint.y)
            )
            let path = NSBezierPath(rect: rect)
            path.lineWidth = element.lineWidth
            path.stroke()

        case .text:
            if let text = element.text {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: max(14, element.lineWidth * 5), weight: .medium),
                    .foregroundColor: element.color
                ]
                text.draw(at: element.startPoint, withAttributes: attrs)
            }

        case .eraser:
            break
        }
    }
}

// MARK: - Drawing Interaction View

struct DrawingInteractionView: NSViewRepresentable {
    let tool: DrawingTool
    let color: Color
    let lineWidth: CGFloat
    let isEditingText: Bool
    let onElementStarted: (DrawingElement) -> Void
    let onElementUpdated: (DrawingElement) -> Void
    let onElementFinished: (DrawingElement) -> Void

    func makeNSView(context: Context) -> DrawingInteractionNSView {
        let view = DrawingInteractionNSView()
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: DrawingInteractionNSView, context: Context) {
        context.coordinator.tool = tool
        context.coordinator.color = NSColor(color)
        context.coordinator.lineWidth = lineWidth
        context.coordinator.isEditingText = isEditingText
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            tool: tool,
            color: NSColor(color),
            lineWidth: lineWidth,
            onStarted: onElementStarted,
            onUpdated: onElementUpdated,
            onFinished: onElementFinished
        )
    }

    class Coordinator {
        var tool: DrawingTool
        var color: NSColor
        var lineWidth: CGFloat
        var isEditingText = false
        let onStarted: (DrawingElement) -> Void
        let onUpdated: (DrawingElement) -> Void
        let onFinished: (DrawingElement) -> Void
        var currentElement: DrawingElement?

        init(tool: DrawingTool, color: NSColor, lineWidth: CGFloat,
             onStarted: @escaping (DrawingElement) -> Void,
             onUpdated: @escaping (DrawingElement) -> Void,
             onFinished: @escaping (DrawingElement) -> Void) {
            self.tool = tool
            self.color = color
            self.lineWidth = lineWidth
            self.onStarted = onStarted
            self.onUpdated = onUpdated
            self.onFinished = onFinished
        }

        func mouseDown(at point: CGPoint) {
            // Don't start new drawing if editing text (unless it's a new text click)
            if isEditingText && tool != .text { return }

            let element = DrawingElement(
                tool: tool,
                color: color,
                lineWidth: lineWidth,
                points: [point],
                startPoint: point,
                endPoint: point
            )
            currentElement = element
            onStarted(element)
        }

        func mouseDragged(to point: CGPoint) {
            guard var element = currentElement else { return }
            element.points.append(point)
            element.endPoint = point
            currentElement = element
            onUpdated(element)
        }

        func mouseUp(at point: CGPoint) {
            guard var element = currentElement else { return }
            element.endPoint = point
            if tool == .pen {
                element.points.append(point)
            }
            currentElement = nil
            onFinished(element)
        }
    }
}

class DrawingInteractionNSView: NSView {
    weak var delegate: DrawingInteractionView.Coordinator?

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        delegate?.mouseDown(at: point)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        delegate?.mouseDragged(to: point)
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        delegate?.mouseUp(at: point)
    }
}
