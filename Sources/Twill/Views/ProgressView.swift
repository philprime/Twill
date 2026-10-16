/// Shows progress within the layout, independently of the terminal-native indicator.
/// A nil value produces an animated spinner. A non-nil value produces a linear
/// bar, clamped to zero through `total`. Only the spinner schedules updates.
/// The bar fills the proposed width, or uses 20 cells when unconstrained.
public struct ProgressView<Label: View>: View {
    private let fraction: Double?
    private let label: Label

    /// `total` must be positive and finite when `value` is non-nil.
    /// A NaN value is treated as zero progress.
    public init(value: Double? = nil, total: Double = 1, @ViewBuilder label: () -> Label) {
        if let value {
            precondition(total.isFinite && total > 0, "Progress total must be positive and finite")
            fraction = value.isNaN ? 0 : min(max(value / total, 0), 1)
        } else {
            fraction = nil
        }
        self.label = label()
    }

    @ViewBuilder public var body: some View {
        if let fraction {
            VStack(alignment: .leading, spacing: 0) {
                label
                ProgressBar(fraction: fraction).frame(maxWidth: .infinity)
            }
        } else {
            HStack {
                ProgressSpinner()
                label
            }
        }
    }
}

extension ProgressView where Label == EmptyView {
    public init(value: Double? = nil, total: Double = 1) {
        self.init(value: value, total: total) { return EmptyView() }
    }
}

extension ProgressView where Label == Text {
    public init(_ title: String, value: Double? = nil, total: Double = 1) {
        self.init(value: value, total: total) { return Text(title) }
    }
}

private struct ProgressBar: View, PrimitiveView {
    typealias Body = Never
    let fraction: Double

    func makeDescription() -> ViewDescription {
        .drawing(ProgressBarDrawing(fraction: fraction))
    }
}
