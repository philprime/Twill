/// Pixel representation is retained with each placement so the host chooses the wire format.
enum ImageFormat: Equatable {
    case png
    case rgba(width: Int, height: Int)

    var control: String {
        switch self {
        case .png: "f=100"
        case .rgba(let width, let height): "f=32,s=\(width),v=\(height)"
        }
    }
}
