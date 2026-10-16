/// Shows progress within the layout, independently of the terminal-native indicator.
/// A nil value produces an animated spinner. A non-nil value produces a linear
/// bar, clamped to zero through `total`. Only the spinner schedules updates.
/// The bar fills the proposed width, or uses 20 cells when unconstrained.
public struct ProgressView<Label: View>: View {
    private let fraction: Double?
    private let label: Label
    private let spinnerStyle: SpinnerStyle

    /// `total` must be positive and finite when `value` is non-nil.
    /// A NaN value is treated as zero progress.
    public init(
        value: Double? = nil, total: Double = 1, spinnerStyle: SpinnerStyle = .dots,
        @ViewBuilder label: () -> Label
    ) {
        if let value {
            precondition(total.isFinite && total > 0, "Progress total must be positive and finite")
            fraction = value.isNaN ? 0 : min(max(value / total, 0), 1)
        } else {
            fraction = nil
        }
        self.label = label()
        self.spinnerStyle = spinnerStyle
    }

    /// The label with a determinate bar or an independently animated spinner.
    @ViewBuilder public var body: some View {
        if let fraction {
            VStack(alignment: .leading, spacing: 0) {
                label
                ProgressBar(fraction: fraction).frame(maxWidth: .infinity)
            }
        } else {
            HStack {
                ProgressSpinner(style: spinnerStyle)
                label
            }
        }
    }
}

extension ProgressView where Label == EmptyView {
    /// Creates unlabeled progress. A nil value selects a spinner; otherwise total must be positive and finite.
    public init(value: Double? = nil, total: Double = 1, spinnerStyle: SpinnerStyle = .dots) {
        self.init(value: value, total: total, spinnerStyle: spinnerStyle) { return EmptyView() }
    }
}

extension ProgressView where Label == Text {
    /// Creates text-labeled progress. A nil value selects a spinner; otherwise total must be positive and finite.
    public init(_ title: String, value: Double? = nil, total: Double = 1, spinnerStyle: SpinnerStyle = .dots) {
        self.init(value: value, total: total, spinnerStyle: spinnerStyle) { return Text(title) }
    }
}

private struct ProgressBar: View, PrimitiveView {
    typealias Body = Never
    let fraction: Double

    func makeDescription() -> ViewDescription {
        .drawing(ProgressBarDrawing(fraction: fraction))
    }
}
