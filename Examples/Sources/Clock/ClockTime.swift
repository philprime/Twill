import Foundation

struct ClockTime {
    let hour: Int
    let minute: Int
    let second: Int
    let fraction: Double

    init(_ date: Date) {
        let parts = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        hour = parts.hour ?? 0
        minute = parts.minute ?? 0
        second = parts.second ?? 0
        fraction = Double(parts.nanosecond ?? 0) / 1_000_000_000
    }

    var secondTurn: Double { (Double(second) + fraction) / 60 }
    var minuteTurn: Double { (Double(minute) + secondTurn) / 60 }
    var hourTurn: Double { (Double(hour % 12) + minuteTurn) / 12 }

    var digits: [Int] {
        [hour / 10, hour % 10, minute / 10, minute % 10, second / 10, second % 10]
    }

    var label: String {
        String(format: "%02d:%02d:%02d", hour, minute, second)
    }
}
