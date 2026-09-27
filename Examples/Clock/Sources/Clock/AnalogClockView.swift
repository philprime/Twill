import Foundation
import Twill

struct AnalogClockView: View {
    var body: some View {
        Canvas(interval: 1.0 / 30.0) { context, size in
            drawClock(in: context, size: size)
        }
    }

    private func drawClock(in context: CanvasContext, size: CanvasSize) {
        guard size.width >= 10, size.height >= 7 else { return }

        let centerX = Double(size.width - 1) / 2
        let centerY = Double(size.height - 1) / 2
        // Terminal columns are typically about half as wide as rows are tall.
        let radius = min(Double(size.width - 4) / 4, Double(size.height - 3) / 2)
        let face = Color(red: 160, green: 170, blue: 185)
        let ticks = Color(red: 245, green: 205, blue: 105)

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

        let parts = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: context.date)
        let seconds = Double(parts.second ?? 0) + Double(parts.nanosecond ?? 0) / 1_000_000_000
        let minutes = Double(parts.minute ?? 0) + seconds / 60
        let hours = Double((parts.hour ?? 0) % 12) + minutes / 60

        let center = (column: centerX, row: centerY)
        drawHand(
            hours / 12, length: radius * 0.5, cell: CanvasCell("█", foreground: ticks), center: center, in: context)
        drawHand(
            minutes / 60, length: radius * 0.75, cell: CanvasCell("●", foreground: ticks), center: center, in: context)
        drawHand(
            seconds / 60, length: radius * 0.9,
            cell: CanvasCell("•", foreground: Color(red: 235, green: 95, blue: 85)), center: center, in: context)
        context.draw("◉", column: Int(centerX.rounded()), row: Int(centerY.rounded()), foreground: ticks)
    }

    private func drawHand(
        _ turn: Double, length: Double, cell: CanvasCell,
        center: (column: Double, row: Double), in context: CanvasContext
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
