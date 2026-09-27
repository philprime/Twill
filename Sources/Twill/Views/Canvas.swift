import Foundation

/// A drawable extent measured in terminal columns and rows.
public struct CanvasSize: Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        precondition(width >= 0 && height >= 0, "Canvas dimensions must not be negative")
        self.width = width
        self.height = height
    }
}

/// One terminal grapheme with optional per-cell colors.
public struct CanvasCell: Equatable {
    public let character: Character
    public let foreground: Color?
    public let background: Color?

    public init(_ character: Character, foreground: Color? = nil, background: Color? = nil) {
        self.character = character
        self.foreground = foreground
        self.background = background
    }
}

/// Sparse image: nil cells leave the canvas background untouched when copied.
public struct CanvasBuffer {
    public let size: CanvasSize
    private var cells: [CanvasCell?]

    public init(size: CanvasSize) {
        self.size = size
        cells = Array(repeating: nil, count: size.width * size.height)
    }

    public subscript(column: Int, row: Int) -> CanvasCell? {
        get {
            precondition(column >= 0 && column < size.width && row >= 0 && row < size.height)
            return cells[row * size.width + column]
        }
        set {
            precondition(column >= 0 && column < size.width && row >= 0 && row < size.height)
            cells[row * size.width + column] = newValue
        }
    }
}

/// The short-lived drawing surface for one presentation. Do not retain it after rendering.
@MainActor
public final class CanvasContext {
    public let date: Date
    fileprivate var drawing: DrawingContext

    init(date: Date, drawing: DrawingContext) {
        self.date = date
        self.drawing = drawing
    }

    public func draw(
        _ character: Character, column: Int, row: Int,
        foreground: Color? = nil, background: Color? = nil
    ) {
        let first = character.unicodeScalars.first!
        let category = first.properties.generalCategory
        let safe: Character
        if category == .control || category == .format {
            safe = " "
        } else if category == .nonspacingMark || category == .enclosingMark || category == .spacingMark {
            safe = Character("◌" + String(character))
        } else {
            safe = character
        }
        drawing.draw(
            safe, width: TerminalCharacterWidth.columns(for: safe), column: column, row: row,
            foreground: foreground, background: background)
    }

    public func render(_ buffer: CanvasBuffer, column: Int = 0, row: Int = 0) {
        for bufferRow in 0..<buffer.size.height {
            for bufferColumn in 0..<buffer.size.width {
                guard let cell = buffer[bufferColumn, bufferRow] else { continue }
                guard bufferColumn + TerminalCharacterWidth.columns(for: cell.character) <= buffer.size.width else {
                    continue
                }
                draw(
                    cell.character, column: column + bufferColumn, row: row + bufferRow,
                    foreground: cell.foreground, background: cell.background)
            }
        }
    }
}

/// Draws terminal cells within the size assigned by layout. The interval form
/// requests updates; it does not synchronize with a display refresh signal.
public struct Canvas: View {
    public typealias Body = Never

    private let interval: TimeInterval?
    private let render: @MainActor (CanvasContext, CanvasSize) -> Void

    public init(_ render: @escaping @MainActor (CanvasContext, CanvasSize) -> Void) {
        interval = nil
        self.render = render
    }

    public init(interval: TimeInterval, render: @escaping @MainActor (CanvasContext, CanvasSize) -> Void) {
        precondition(interval.isFinite && interval > 0, "Canvas interval must be positive and finite")
        self.interval = interval
        self.render = render
    }
}

extension Canvas: PrimitiveView {
    func makeDescription() -> ViewDescription {
        .canvas(interval: interval, render: render)
    }
}

struct CanvasDrawing: PrimitiveDrawing {
    let size: CellSize
    let date: Date
    let render: @MainActor (CanvasContext, CanvasSize) -> Void

    func sizeThatFits(_ proposal: ProposedCellSize) -> CellSize {
        CellSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    func draw(in context: inout DrawingContext) {
        // Primitive drawings are invoked by the UI-actor renderer.
        MainActor.assumeIsolated {
            let surface = CanvasContext(date: date, drawing: context)
            render(surface, CanvasSize(width: size.width, height: size.height))
            context = surface.drawing
        }
    }
}
