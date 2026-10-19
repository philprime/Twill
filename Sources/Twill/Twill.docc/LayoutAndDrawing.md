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

## Resolve Semantic Colors

```swift
VStack {
    Text("Primary").foregroundStyle(.foreground)
    Text("Action").foregroundStyle(.accent)
    Text("Detail").foregroundStyle(.muted)
}
.backgroundStyle(.background)
.theme(Theme(foreground: .white, background: .black, accent: .cyan))
```

``SemanticColor`` supplies foreground, background, accent, muted, and validation roles. ``Theme`` maps each role to a concrete color or nil for the terminal default. A palette alone does not paint content; semantic styles select the roles to use. Concrete ``Color`` values remain available and independent of the palette. Destructive buttons use the validation role, which defaults to red.

Theme boundaries replace the palette for their subtree. Semantic declarations inherited from outside a boundary resolve again against the nearer palette, while local style declarations and concrete colors retain precedence. Explicit terminal-default roles clear inherited colors rather than acting as missing overrides. Background styles paint their bounds; foreground styles do not. Theme updates preserve layout, mounted state, and independent schedules.

Custom ``Style`` implementations resolve with `resolve(in:)`, returning a concrete color or nil for terminal default. Style values remain concrete in public composition and resolve only at the mounted presentation boundary.

## Style Control State

``ControlStyle`` resolves an immutable ``ControlAppearance`` from ``ControlState`` and the nearest theme. It is separate from color-only ``Style``. Apply a concrete implementation with `.controlStyle(...)` to one control or a subtree; a nearer declaration replaces it, and ordinary text outside controls is unchanged.

```swift
struct AccentControls: ControlStyle {
    func resolve(_ state: ControlState, in theme: Theme) -> ControlAppearance {
        ControlAppearance(
            foreground: state.isEnabled ? SemanticColor.accent : .muted,
            attributes: state.isFocused ? [.bold] : [],
            focusEffect: .none)
    }
}
```

State identifies the control family and its effective availability and focus owner. Toggle selection means on, picker options expose their own selection, and disclosure headers expose expansion without styling expanded content. Other controls can inherit enclosing row selection. Nested controls have independent owners, so their focus and value selection do not leak into one another. Progress participates in styling without becoming a focus stop.

Appearance overrides ordinary inherited colors and attributes without changing layout, binding values, actions, or eligibility. Nil fields retain inherited presentation. A supplied semantic color can explicitly select terminal default; an empty attribute set clears inherited flags. ``ControlFocusEffect`` controls only reverse video, independently of logical focus and the hardware caret. Default appearance retains existing styling and focus highlighting.

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

## Display Raster Images

``Image`` holds immutable PNG data. Load it outside view evaluation, then pass it to ``ImageView`` with dimensions in terminal cells. Image presentation uses the Kitty graphics protocol and requires a compatible terminal. Terminal emulators without that protocol cannot display the raster content. Text-based view previews in <doc:ViewGallery> are independent of terminal raster-image support.
