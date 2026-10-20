import Foundation

@testable import Twill

extension DocumentationPreviewFixture {
    static var imageFixture: Self {
        Self(
            "ImageView",
            "A 32-by-16 pixel checkerboard PNG placement, scaled to terminal "
                + "cells. Live output requires a Kitty graphics "
                + "compatible terminal such as Ghostty. This SVG embeds the renderer's PNG payload; "
                + "it does not test "
                + "terminal decoding or graphics-protocol support."
        ) {
            ImageView(try Image(pngData: imageData), width: 8, height: 4) { Text("Unsupported") }
        }
    }

    // SVG needs a complete PNG, while Image's validation reads only header metadata.
    static let imageData = Data(
        base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAACAAAAAQCAIAAAD4YuoOAAAAL0lEQVR4nGMI23YIjv6nMcARtcSpZtAw"
            + "toAWhiKLj1pA2IKhn4qGvgVDPxUNeQsAwo0zLiJrTHEAAAAASUVORK5CYII=")!
}
