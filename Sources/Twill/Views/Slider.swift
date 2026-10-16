/// A floating-point control with a visible value and a horizontal track.
/// Left/Right adjust by `step`, clamping partial steps at the bounds.
/// Home/End reach the endpoints. Up/Down remain available for focus navigation.
/// Without an explicit step, each adjustment moves one percent of the range.
public struct Slider<Value: BinaryFloatingPoint, Label: View>: View where Value.Stride: BinaryFloatingPoint {
    private let value: Binding<Value>
    private let bounds: ClosedRange<Value>
    private let step: Value
    private let label: Label
    private static var keyboardSteps: Value { 100 }

    /// Bounds must be finite with a finite span, and an explicit step must be
    /// positive and finite. External values are shown unchanged beside a clamped
    /// track and are only written back when the user adjusts the control.
    public init(
        value: Binding<Value>, in bounds: ClosedRange<Value> = 0...1, step: Value.Stride? = nil,
        @ViewBuilder label: () -> Label
    ) {
        let span = bounds.upperBound - bounds.lowerBound
        precondition(
            bounds.lowerBound.isFinite && bounds.upperBound.isFinite && span.isFinite,
            "Slider bounds and their span must be finite")
        let increment = step.map { Value($0) } ?? max(span / Self.keyboardSteps, Value.leastNonzeroMagnitude)
        precondition(increment.isFinite && increment > 0, "Slider step must be positive and finite")
        self.value = value
        self.bounds = bounds
        self.step = increment
        self.label = label()
    }

    private var boundedValue: Value {
        value.wrappedValue.isNaN
            ? bounds.lowerBound : min(max(value.wrappedValue, bounds.lowerBound), bounds.upperBound)
    }

    /// The label, current value, and clamped track with keyboard adjustment handling.
    public var body: some View {
        let span = bounds.upperBound - bounds.lowerBound
        let fraction = span > 0 ? Double((boundedValue - bounds.lowerBound) / span) : 0
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                label
                Text("\(value.wrappedValue)")
            }
            SliderTrack(fraction: fraction).frame(maxWidth: .infinity)
        }
        .focusable()
        .onKeyPress(handle)
    }

    private func handle(_ key: KeyEvent) -> KeyPressResult {
        let candidate: Value
        switch key {
        case .arrowLeft: candidate = boundedValue - step
        case .arrowRight: candidate = boundedValue + step
        case .home: candidate = bounds.lowerBound
        case .end: candidate = bounds.upperBound
        default: return .ignored
        }
        let updated = min(max(candidate, bounds.lowerBound), bounds.upperBound)
        if updated != value.wrappedValue { value.wrappedValue = updated }
        return .handled
    }
}

extension Slider where Label == EmptyView {
    /// Creates an unlabeled slider with finite bounds and an optional positive, finite step.
    public init(value: Binding<Value>, in bounds: ClosedRange<Value> = 0...1, step: Value.Stride? = nil) {
        self.init(value: value, in: bounds, step: step) { return EmptyView() }
    }
}

extension Slider where Label == Text {
    /// Creates a text-labeled slider with finite bounds and an optional positive, finite step.
    public init(
        _ title: String, value: Binding<Value>, in bounds: ClosedRange<Value> = 0...1, step: Value.Stride? = nil
    ) {
        self.init(value: value, in: bounds, step: step) { return Text(title) }
    }
}

private struct SliderTrack: View, PrimitiveView {
    typealias Body = Never
    let fraction: Double

    func makeDescription() -> ViewDescription {
        .drawing(SliderTrackDrawing(fraction: fraction))
    }
}
