/// A bound integer control with Left/Right adjustment and a visible value.
///
/// Brackets mark available adjustments; parentheses mark unavailable ones.
/// Up/Down remain available for focus navigation. Adjustments clamp to the
/// bounds without wrapping, including a final step shorter than `step`.
public struct Stepper<Value: FixedWidthInteger, Label: View>: View {
    private let value: Binding<Value>
    private let bounds: ClosedRange<Value>
    private let step: Value
    private let label: Label
    private let format: @MainActor (Value) -> String

    /// Creates a stepper with a positive step. Without explicit bounds, the
    /// control uses the integer type's representable range. External binding
    /// values are displayed unchanged until an available adjustment is made.
    /// The formatter changes presentation only, receiving the actual bound value.
    public init(
        value: Binding<Value>, in bounds: ClosedRange<Value> = Value.min...Value.max, step: Value = 1,
        format: @escaping @MainActor (Value) -> String = { String(describing: $0) }, @ViewBuilder label: () -> Label
    ) {
        precondition(step > 0, "Stepper step must be positive")
        self.value = value
        self.bounds = bounds
        self.step = step
        self.label = label()
        self.format = format
    }

    /// The label and value with availability markers and Left/Right adjustment handling.
    public var body: some View {
        HStack(spacing: 1) {
            Text(value.wrappedValue > bounds.lowerBound ? "[-]" : "(-)")
            HStack(spacing: 0) {
                label
                Text(": \(format(value.wrappedValue))")
            }
            Text(value.wrappedValue < bounds.upperBound ? "[+]" : "(+)")
        }
        .focusable()
        .onKeyPress { key in
            guard key == .arrowLeft || key == .arrowRight else { return .ignored }
            adjust(increasing: key == .arrowRight)
            return .handled
        }
        .controlPresentation(.stepper)
    }

    private func adjust(increasing: Bool) {
        let current = value.wrappedValue
        guard increasing ? current < bounds.upperBound : current > bounds.lowerBound else { return }
        let result = increasing ? current.addingReportingOverflow(step) : current.subtractingReportingOverflow(step)
        // Arithmetic overflow is a boundary crossing, not a wrapped adjustment.
        let candidate = result.overflow ? (increasing ? bounds.upperBound : bounds.lowerBound) : result.partialValue
        value.wrappedValue = min(max(candidate, bounds.lowerBound), bounds.upperBound)
    }
}

extension Stepper where Label == Text {
    /// Creates a text-labeled integer stepper with a positive step and optional inclusive bounds.
    public init(
        _ title: String, value: Binding<Value>, in bounds: ClosedRange<Value> = Value.min...Value.max, step: Value = 1,
        format: @escaping @MainActor (Value) -> String = { String(describing: $0) }
    ) {
        self.init(value: value, in: bounds, step: step, format: format) { return Text(title) }
    }
}
