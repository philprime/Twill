package struct TextStyle: Sendable, Hashable {
    package enum Weight: Sendable, Hashable {
        case regular
        case bold
    }

    package let size: Double
    package let weight: Weight

    package init(size: Double, weight: Weight) {
        self.size = size
        self.weight = weight
    }
}
