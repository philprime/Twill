import Twill

struct GraphLabelPlacement<ID: Hashable & Sendable> {
    let nodeID: ID
    let text: PixelText
    let bounds: PixelRect
}
