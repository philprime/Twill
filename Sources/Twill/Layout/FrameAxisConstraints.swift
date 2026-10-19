/// One axis keeps proposal, allocation and inherited fill intent consistent.
struct FrameAxisConstraints {
    let fixed: Int?
    let minimum: Int?
    let maximum: FrameLimit?

    init(fixed: Int? = nil, minimum: Int? = nil, maximum: FrameLimit? = nil) {
        precondition(
            Self.isValid(fixed: fixed, minimum: minimum, maximum: maximum),
            "Frame constraints must be nonnegative and ordered, with fixed dimensions inside their bounds")
        self.fixed = fixed
        self.minimum = minimum
        self.maximum = maximum
    }

    static func isValid(fixed: Int? = nil, minimum: Int? = nil, maximum: FrameLimit? = nil) -> Bool {
        let upper: Int
        if case .cells(let limit) = maximum { upper = limit } else { upper = .max }
        let lower = minimum ?? 0
        return lower >= 0 && upper >= lower && (fixed.map { $0 >= lower && $0 <= upper } ?? true)
    }

    var fill: LayoutBehavior.Fill {
        if fixed != nil { return .intrinsic }
        switch maximum {
        case .cells: return .intrinsic
        case .infinity: return .filling
        case nil: return .inherited
        }
    }

    func childProposal(_ proposed: Int?) -> Int? {
        if let fixed { return min(fixed, proposed ?? fixed) }
        if case .cells(let limit) = maximum { return min(limit, proposed ?? limit) }
        return proposed
    }

    func dimension(content: Int, proposed: Int?) -> Int {
        let desired: Int
        if let fixed {
            desired = fixed
        } else {
            switch maximum {
            case .infinity: desired = proposed ?? content
            case .cells(let limit): desired = min(max(content, proposed ?? content), limit)
            case nil: desired = content
            }
        }
        // Terminal parents remain clipping boundaries even below a requested minimum.
        return min(max(desired, minimum ?? 0), proposed ?? .max)
    }
}
