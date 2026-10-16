import Foundation
import Twill

struct ClockView: View {
    @State private var selection = ClockFace.orbit

    var body: some View {
        VStack(spacing: 1) {
            HStack {
                Text(" TWILL / CLOCK LAB ").foregroundStyle(ClockPalette.hours)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(context.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            Picker("Face", selection: $selection, options: ClockFace.allCases) { face in
                Text("\(face.rawValue + 1) \(face.title)")
                    .foregroundStyle(face.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            GroupBox(selection.title) {
                selectedClock
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(ClockPalette.foreground)
            }
            .foregroundStyle(selection.color)
            Text(selection.caption).foregroundStyle(ClockPalette.foreground)
            Text("1–4: face · ←/→: choose · Ctrl-C: exit")
                .foregroundStyle(ClockPalette.muted)
        }
        .padding(1)
        .backgroundStyle(ClockPalette.background)
        .onKeyPress { key in
            switch key {
            case .one: selection = .analog
            case .two: selection = .digital
            case .three: selection = .binary
            case .four: selection = .orbit
            default: return .ignored
            }
            return .handled
        }
    }

    @ViewBuilder
    private var selectedClock: some View {
        switch selection {
        case .analog: AnalogClockView()
        case .digital: DigitalClockView()
        case .binary: BinaryClockView()
        case .orbit: OrbitClockView()
        }
    }
}

enum ClockFace: Int, CaseIterable {
    case analog, digital, binary, orbit

    var title: String {
        switch self {
        case .analog: "Analog"
        case .digital: "Neon"
        case .binary: "Binary"
        case .orbit: "Orbit"
        }
    }

    var color: Color {
        switch self {
        case .analog: ClockPalette.hours
        case .digital: ClockPalette.seconds
        case .binary: ClockPalette.minutes
        case .orbit: ClockPalette.orbit
        }
    }

    var caption: String {
        switch self {
        case .analog: "Classic hands. A continuous sweep."
        case .digital: "Seven segments, six digits, pulsing colons."
        case .binary: "Bits from top: 32 · 16 · 8 · 4 · 2 · 1."
        case .orbit: "Gold hours · mint minutes · pink seconds."
        }
    }
}
