import Foundation

struct ProgressSpinner: View {
    private static let interval: TimeInterval = 0.1
    private static let frames: [Character] = ["|", "/", "-", "\\"]

    var body: some View {
        Canvas(interval: Self.interval) { context, _ in
            // Use the mounted canvas date so parent updates and resize cannot
            // advance the animation before its independently scheduled deadline.
            let tick = floor(context.date.timeIntervalSinceReferenceDate * (1 / Self.interval))
            let remainder = Int(tick.truncatingRemainder(dividingBy: Double(Self.frames.count)))
            let index = (remainder + Self.frames.count) % Self.frames.count
            context.draw(Self.frames[index], column: 0, row: 0)
        }
        .frame(width: 1, height: 1)
    }
}
