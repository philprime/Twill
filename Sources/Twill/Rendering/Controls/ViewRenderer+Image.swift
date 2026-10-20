import Foundation

@MainActor
extension ViewRenderer {
    func updateImage(_ image: ImageDescription, at date: Date) {
        if terminalCapabilities.imageProtocol == .kitty {
            reconcile(
                [
                    SupportedImageView(
                        drawing: ImageDrawing(
                            image: image.image, size: image.size,
                            contentMode: image.contentMode, cellHeightToWidth: terminalCapabilities.cellHeightToWidth))
                ], at: date)
        } else {
            reconcile([image.fallback], at: date)
        }
    }
}
