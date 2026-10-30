# Layout and Drawing

Compose terminal-cell layouts and draw custom content within measured bounds.

## Overview

Twill measures width in terminal columns and height in rows. These are not pixel dimensions or Swift string character counts. Wide characters can occupy multiple columns. ``Text`` preserves LF and CRLF line breaks and wraps at ordinary spaces when offered a finite width. Other control characters become spaces rather than terminal commands.

## Compose and Constrain Content

``VStack`` places children vertically at their intrinsic heights. ``HStack`` places children horizontally at their intrinsic widths. Their spacing and alignment apply between and across children. Vertical stacks and single-child composition forward finite proposals so text can reflow. Multiple intrinsic-width horizontal siblings keep their natural widths; bound an individual child's width or use a filling frame to give it a wrapping proposal. Bounds clip content that exceeds the allocated height.

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

## Control Text Breaks and Overflow

Use `.lineBreakMode(.wordWrapping)` for word boundaries, `.lineBreakMode(.characterWrapping)` for complete grapheme boundaries, or `.lineBreakMode(.clipping)` to preserve logical lines without wrapping. Unspecified width keeps natural line widths. Whitespace that fits is preserved, while word-wrapping separators at a break are omitted. Oversized words split only between graphemes. A grapheme wider than the viewport occupies a clipped row and is never partially drawn.

```swift
Text("A long terminal title")
    .lineLimit(1)
    .truncationMode(.middle)
    .frame(width: 12)
```

`.lineLimit(_:)` limits visible lines and defaults omitted content to tail truncation. Nil resets an inherited limit, and values below one use one line. `.truncationMode(.head)`, `.middle`, and `.tail` choose which part is replaced by an ellipsis. Ellipsis placement also respects whole graphemes and terminal-cell width. Without an explicit limit or truncation mode, height bounds clip complete rows.

Use `.multilineTextAlignment(.leading)`, `.center`, or `.trailing` to position rendered rows within the text block. The modifier reuses `HorizontalAlignment` and defaults to leading. Row offsets use terminal-cell widths after wrapping and truncation, including combining and wide graphemes. Center alignment rounds spare cells down on the leading side. Alignment distributes spare cells only, leaving clipped horizontal overflow at the leading edge. It changes neither measured size nor the block's placement within an enclosing frame.

These modifiers inherit through containers. The nearest setting to a text node takes precedence, including a local `.lineLimit(nil)` reset. They configure static text rather than editing-control viewports or single-line terminal chrome. Resize reflows cached descriptions without reevaluating view bodies or changing timeline deadlines.

## Apply Appearance

Use `.foregroundStyle(...)` and `.backgroundStyle(...)` with a ``Style`` such as ``Color``. Styles propagate to descendants, and more local styling can override them. ANSI palette colors follow the terminal's theme. RGB colors request true color, whose appearance depends on terminal support.

## Resolve Foreground Hierarchy and Tint

```swift
VStack {
    Text("Primary").foregroundStyle(.primary)
    Text("Detail").foregroundStyle(.secondary)
    Text("Action").foregroundStyle(.tint)
}
.foregroundStyle(Color.blue)
.tint(.cyan)
```

``HierarchicalStyle`` expresses prominence relative to the inherited primary foreground. Secondary keeps its hue and adds terminal dim emphasis; primary restores the primary style without clearing explicit view attributes. Dim is a terminal-specific approximation whose appearance depends on terminal and font support. Local attribute modifiers can clear inherited style contributions; a nearer hierarchical declaration can restore its prominence without restoring unrelated cleared flags. A concrete foreground style establishes a new primary style.

``View/tint(_:)`` sets control emphasis independently of ordinary text. Otherwise unstyled buttons use the nearest tint, while explicit foreground declarations take precedence. Destructive buttons retain their red default, and styles on their label content can override it. ``TintStyle`` follows the nearest tint override, including for declarations inherited from outside the override. Nil clears an inherited tint and falls back to the primary foreground color. Application palettes and validation colors remain application-owned.

Custom ``Style`` implementations resolve with `resolve(in:)` using an immutable ``StyleContext``. They return a ``ResolvedStyle`` containing a color and additional text attributes. A nil resolved color explicitly selects the terminal default. Foreground and border styles contribute attributes to their drawn text; background styles use the resolved color to paint their bounds. Border attributes do not affect content. Style values remain concrete in public composition and resolve at the mounted presentation boundary. Style and tint updates preserve layout, mounted state, focus, and independent schedules.

## Style Control State

``ControlStyle`` resolves an immutable ``ControlAppearance`` from ``ControlState`` and the inherited ``StyleContext``. It adds control-state policy to contextual ``Style`` resolution. Apply a concrete implementation with `.controlStyle(...)` to one control or a subtree; a nearer declaration replaces it, and ordinary text outside controls is unchanged.

```swift
struct AccentControls: ControlStyle {
    func resolve(_ state: ControlState, in context: StyleContext) -> ControlAppearance {
        ControlAppearance(
            foreground: state.isEnabled ? TintStyle.tint : HierarchicalStyle.secondary,
            attributes: state.isFocused ? [.bold] : nil,
            focusEffect: .none)
    }
}
```

State identifies the control family and its effective availability and focus owner. Toggle selection means on, picker options expose their own selection, and disclosure headers expose expansion without styling expanded content. Other controls can inherit enclosing row selection. Nested controls have independent owners, so their focus and value selection do not leak into one another. Progress participates in styling without becoming a focus stop.

Appearance overrides ordinary inherited colors and attributes without changing layout, binding values, actions, or eligibility. Nil fields retain inherited presentation. A style can resolve to terminal-default color and contribute foreground attributes. Explicit appearance attributes replace inherited and style-contributed flags, including an empty set that clears them. ``ControlFocusEffect`` controls only reverse video, independently of logical focus and the hardware caret. Default appearance retains existing styling and focus highlighting.

Slider and stepper initializers accept `format:` closures for their displayed values:

```swift
Stepper("Files", value: $count, in: 0...100, format: { "\($0) items" })
Slider("Level", value: $level, format: { "\(Int($0 * 100))%" })
```

Formatting receives the actual external value, not its clamped track representation, and does not change adjustment behavior. Default formatting retains the ordinary numeric representation. Styles and formatting run during presentation/body evaluation and must not perform terminal output or register work.

## Apply Terminal Text Attributes

```swift
VStack {
    Text("Heading").bold().underline()
    Text("Secondary detail").dim().italic()
    Text("Normal weight").bold(false)
}
.bold()
```

`.bold(_:)`, `.dim(_:)`, `.italic(_:)`, and `.underline(_:)` inherit through view composition, with local false values clearing an ancestor's flag. `.textAttributes(_:)` replaces the inherited set, and an empty set clears all supported flags. Modifiers preserve layout and mounted identity. Attributes remain separate from colors and reverse-video focus styling.

``Canvas/Context/draw(_:column:row:foreground:background:attributes:)`` and ``Canvas/Cell`` accept optional attribute overrides. Nil inherits the drawing context, while an empty set clears its flags. Wide graphemes carry the same attributes across their cells. Attribute-only changes participate in frame differences, and unchanged frames remain unwritten.

The host encodes and resets attributes at write boundaries. Bold and dim share the terminal intensity reset, so transitions preserve either flag when the other turns off. Italic, underline, colors, and focus reset independently. Terminal/font support determines appearance, especially for italic and dim. Views describe flags rather than emitting escape sequences.

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

## Draw Pixels with Paths

A ``PixelCanvas`` supplies a drawing context and a bitmap size in pixels. Its frame still uses terminal cells. Pixel sampling resolution is configured through `pixelsPerCell`, and the terminal scales the RGBA bitmap into the allocated cell rectangle. Pixel presentation requires a Kitty graphics-compatible terminal.

Build reusable ``Path`` values and supply a solid ``PixelColor`` to each fill or stroke:

```swift
PixelCanvas { context, size in
    let bounds = PixelRect(x: 8, y: 8, width: 100, height: 40)
    let ellipse = Path(ellipseIn: bounds)
    context.fill(
        ellipse,
        with: PixelColor(red: 86, green: 182, blue: 194)
    )
    context.stroke(
        ellipse,
        with: PixelColor(red: 230, green: 230, blue: 240),
        lineWidth: 2
    )
}
.frame(width: 20, height: 6)
```

Paths describe line contours, rectangles, and ellipses. Filling implicitly closes open contours and uses nonzero winding. Strokes use round caps and joins and leave open contours open.

The context references a fixed bitmap destination. Copy it into a local variable before changing opacity, transforms, or clipping when those changes should not affect later operations through the original context. All copies draw into the same bitmap, but each has independent drawing state. Clips capture the transform at the time they are applied.

Draw only during the callback, and do not retain contexts for later use. Each presentation starts with a transparent bitmap. State changes request presentation; use a ``TimelineView`` for scheduled animation.

## Display Raster Images

``Image`` holds immutable PNG data. Load it outside view evaluation, then pass it to ``ImageView`` with dimensions in terminal cells. Image presentation uses the Kitty graphics protocol and requires a compatible terminal. Terminal emulators without that protocol cannot display the raster content. Text-based view previews in <doc:ViewGallery> are independent of terminal raster-image support.
