# Layout and Drawing

Compose terminal-cell layouts and draw custom content within measured bounds.

## Overview

Twill measures width in terminal columns and height in rows. These are not pixel dimensions or Swift string character counts. Wide characters can occupy multiple columns. Single-line ``Text`` replaces control characters with spaces rather than interpreting them as terminal commands.

## Compose and Constrain Content

``VStack`` places children vertically at their intrinsic heights. ``HStack`` places children horizontally at their intrinsic widths. Their spacing and alignment apply between and across children. Content outside the allocated bounds is clipped rather than wrapped or compressed.

Use `.frame(width:height:alignment:)` for fixed dimensions and `.frame(maxWidth:maxHeight:alignment:)` to limit dimensions or fill a parent's proposed space with ``FrameLimit/infinity``. A frame can align a smaller child within its allocated bounds.

```swift
VStack(spacing: 1) {
    Text("Deployment")
    ProgressView(value: 3, total: 5)
}
.frame(width: 30, alignment: .leading)
.padding(1)
.border(.rounded, color: .cyan)
```

Modifier order matters. Padding inside a border creates interior space. Padding outside a border creates exterior space. ``GroupBox`` provides a titled border, while ``Form`` and its sections organize controls without making them scrollable.

``LazyVGrid`` uses ``GridItem`` descriptions to choose column widths. ``ScrollView`` clips content to a visible height while preserving mounted state outside the visible area. Use ``ScrollViewReader`` to obtain a proxy for scrolling to keyed children.

## Apply Appearance

Use `.foregroundStyle(...)` and `.backgroundStyle(...)` with a ``Style`` such as ``Color``. Styles propagate to descendants, and more local styling can override them. ANSI palette colors follow the terminal's theme. RGB colors request true color, whose appearance depends on terminal support.

## Draw Cells with Canvas

A ``Canvas`` receives a short-lived context and its assigned size. Constrain its size through layout and draw only during the rendering closure:

```swift
Canvas { context, size in
    guard size.width > 0, size.height > 0 else { return }
    context.draw("*", column: 0, row: 0, foreground: .yellow)
}
.frame(width: 20, height: 4)
```

Coordinates are relative to the canvas. Drawing is clipped by its bounds and enclosing containers. Do not retain the context beyond the closure. Use ``Canvas/Buffer`` to prepare reusable cell content, then render the buffer into the context.

For animated drawing, use the interval initializer and derive the frame from the context's date. See <doc:ScheduledWork> for scheduling semantics.

## Display Raster Images

``Image`` holds immutable PNG data. Load it outside view evaluation, then pass it to ``ImageView`` with dimensions in terminal cells. Image presentation uses the Kitty graphics protocol and requires a compatible terminal. Terminal emulators without that protocol cannot display the raster content. Text-based view previews in <doc:ViewGallery> are independent of terminal raster-image support.
