# ``ImageView``

## Preview

A 32-by-16 pixel checkerboard PNG placement, scaled to terminal cells. Live output requires a Kitty graphics compatible terminal such as Ghostty. This SVG embeds the renderer's PNG payload; it does not test terminal decoding or graphics-protocol support.

![ImageView terminal preview: A 32-by-16 pixel checkerboard PNG placement, scaled to terminal cells. Live output requires a Kitty graphics compatible terminal such as Ghostty. This SVG embeds the renderer's PNG payload; it does not test terminal decoding or graphics-protocol support.](preview-ImageView)

## Capabilities and Fallback

```swift
ImageView(image, width: 40, height: 20) {
    ContentUnavailableView("Image unavailable")
}

application.options.ui.terminalCapabilities = TerminalCapabilities(
    imageProtocol: .kitty, cellHeightToWidth: 2)
```

`Image` remains immutable PNG data. `ImageView<Fallback>` stores concrete fallback content and chooses a mounted branch from the application's injected `TerminalCapabilities` snapshot. Unsupported terminals mount ordinary fallback state, controls, and schedules without emitting graphics commands. Fallback layout follows its own content.

Application settings default to `TerminalCapabilities.detect()`, which recognizes known Ghostty/Kitty environment hints. Detection does not actively probe protocol responses. Override the snapshot before running when hints are absent or inaccurate. Capabilities stay fixed for that session.

## Cell Geometry

The width and height define a reserved cell rectangle, clamped by parent proposals. Default `.aspectFit` centers the image's pixel proportions inside it. The finite positive cell-height-to-width assumption defaults to 2, meaning a cell is twice as tall as wide. Nonempty fitted axes occupy at least one cell, so quantization can approximate very thin images. `.stretch` explicitly fills the rectangle independently of pixel proportions.

Cached resize recomputes fitted placement without reevaluating bodies. A partially clipped placement is omitted rather than rescaled or pixel-cropped. This preserves geometry without inventing unavailable pixel metrics. The host owns uploads and image IDs, suppresses unchanged output, and deletes owned placements during replacement, failure cleanup, and shutdown.

Explore related views in <doc:ViewGallery>.
