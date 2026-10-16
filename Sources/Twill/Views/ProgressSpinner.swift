import Foundation

struct ProgressSpinner: View {
    private static let interval: TimeInterval = 0.1
    let style: SpinnerStyle

    var body: some View {
        let frames = style.frames
        return Canvas(interval: Self.interval) { context, _ in
            // Use the mounted canvas date so parent updates and resize cannot
            // advance the animation before its independently scheduled deadline.
            let tick = floor(context.date.timeIntervalSinceReferenceDate * (1 / Self.interval))
            let remainder = Int(tick.truncatingRemainder(dividingBy: Double(frames.count)))
            let index = (remainder + frames.count) % frames.count
            context.draw(frames[index], column: 0, row: 0)
        }
        .frame(width: 1, height: 1)
    }
}
