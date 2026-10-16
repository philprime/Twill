import Foundation
import Twill

struct AnalogClockView: View {
    var body: some View {
        Canvas(interval: 1.0 / 5.0) { context, size in
            drawClock(in: context, size: size)
        }
    }

    private func drawClock(in context: Canvas.Context, size: Canvas.Size) {
        let time = ClockTime(context.date)
        guard size.width >= 10, size.height >= 7 else {
            let originX = max(0, (size.width - time.label.count) / 2)
            for (offset, character) in time.label.enumerated() {
                context.draw(character, column: originX + offset, row: size.height / 2, foreground: ClockPalette.hours)
            }
            return
        }

        let centerX = Double(size.width - 1) / 2
        let centerY = Double(size.height - 1) / 2
        // Terminal columns are typically about half as wide as rows are tall.
        let radius = min(Double(size.width - 4) / 4, Double(size.height - 3) / 2)
        let face = ClockPalette.muted
        let ticks = ClockPalette.hours

        let samples = max(48, Int(radius * 24))
        for step in 0..<samples {
            let angle = 2 * Double.pi * Double(step) / Double(samples)
            context.draw(
                "·", column: Int((centerX + 2 * radius * sin(angle)).rounded()),
                row: Int((centerY - radius * cos(angle)).rounded()), foreground: face)
        }
        for hour in 0..<12 {
            let angle = 2 * Double.pi * Double(hour) / 12
            context.draw(
                "◆", column: Int((centerX + 2 * radius * sin(angle)).rounded()),
                row: Int((centerY - radius * cos(angle)).rounded()), foreground: ticks)
        }

        let center = (column: centerX, row: centerY)
        drawHand(
            time.hourTurn, length: radius * 0.5, cell: Canvas.Cell("█", foreground: ticks), center: center, in: context)
        drawHand(
            time.minuteTurn, length: radius * 0.75,
            cell: Canvas.Cell("●", foreground: ClockPalette.minutes), center: center, in: context)
        drawHand(
            time.secondTurn, length: radius * 0.9,
            cell: Canvas.Cell("•", foreground: ClockPalette.seconds), center: center, in: context)
        context.draw("◉", column: Int(centerX.rounded()), row: Int(centerY.rounded()), foreground: ticks)
    }

    private func drawHand(
        _ turn: Double, length: Double, cell: Canvas.Cell,
        center: (column: Double, row: Double), in context: Canvas.Context
    ) {
        let angle = turn * 2 * Double.pi
        let steps = max(1, Int((length * 3).rounded()))
        for step in 0...steps {
            let distance = length * Double(step) / Double(steps)
            context.draw(
                cell.character, column: Int((center.column + 2 * distance * sin(angle)).rounded()),
                row: Int((center.row - distance * cos(angle)).rounded()), foreground: cell.foreground)
        }
    }
}
