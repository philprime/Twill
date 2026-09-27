@testable import Twill

extension CellGrid {
    /// Readable assertions for scheduling tests, without making text the render model.
    var snapshotText: String {
        (0..<size.height).map { row in
            (0..<size.width).reduce(into: "") { text, column in
                switch self[column, row] {
                case .blank: text += " "
                case .glyph(let character, _): text.append(character)
                case .continuation: break
                }
            }
        }.joined(separator: "\n")
    }
}
