import Foundation
import Twill

struct DigitalClockView: View {
    // Segments run clockwise from the top, with the middle bar last.
    private let segments = [
        [0, 1, 2, 3, 4, 5], [1, 2], [0, 1, 3, 4, 6], [0, 1, 2, 3, 6],
        [1, 2, 5, 6], [0, 2, 3, 5, 6], [0, 2, 3, 4, 5, 6], [0, 1, 2],
        [0, 1, 2, 3, 4, 5, 6], [0, 1, 2, 3, 5, 6],
    ]

    var body: some View {
        Canvas(interval: 1.0 / 5.0) { context, size in
            let time = ClockTime(context.date)
            guard size.width >= 41, size.height >= 7 else {
                let originX = max(0, (size.width - time.label.count) / 2)
                for (offset, character) in time.label.enumerated() {
                    context.draw(
                        character, column: originX + offset, row: size.height / 2, foreground: ClockPalette.seconds)
                }
                return
            }
            let scale = max(1, min(size.width / 41, size.height / 9))
            let originX = (size.width - 41 * scale) / 2
            let originY = (size.height - 7 * scale) / 2
            let colors = [ClockPalette.hours, ClockPalette.minutes, ClockPalette.seconds]
            for (index, digit) in time.digits.enumerated() {
                let origin = originX + (index * 6 + (index / 2) * 3) * scale
                for segment in 0..<7 {
                    let color = segments[digit].contains(segment) ? colors[index / 2] : ClockPalette.track
                    drawSegment(segment, origin: (origin, originY), scale: scale, color: color, in: context)
                }
            }
            let pulse = UInt8(110 + 145 * (0.5 + 0.5 * cos(time.fraction * 2 * .pi)))
            for column in [12, 27] {
                for row in [2, 4] {
                    drawBlock(
                        column: originX + column * scale, row: originY + row * scale,
                        scale: scale, color: Color(red: pulse, green: pulse, blue: pulse), in: context)
                }
            }
        }
    }

    private func drawSegment(
        _ segment: Int, origin: (column: Int, row: Int), scale: Int, color: Color, in context: Canvas.Context
    ) {
        let (column, row) = origin
        switch segment {
        case 0, 3, 6:
            let offset = segment == 0 ? 0 : (segment == 3 ? 6 : 3)
            for step in 1...3 {
                drawBlock(
                    column: column + step * scale, row: row + offset * scale, scale: scale, color: color, in: context)
            }
        default:
            let offsetX = (segment == 1 || segment == 2) ? 4 : 0
            let offsetY = (segment == 1 || segment == 5) ? 1 : 4
            for step in 0..<2 {
                drawBlock(
                    column: column + offsetX * scale, row: row + (offsetY + step) * scale,
                    scale: scale, color: color, in: context)
            }
        }
    }

    private func drawBlock(column: Int, row: Int, scale: Int, color: Color, in context: Canvas.Context) {
        for offsetY in 0..<scale {
            for offsetX in 0..<scale {
                context.draw("█", column: column + offsetX, row: row + offsetY, foreground: color)
            }
        }
    }
}
