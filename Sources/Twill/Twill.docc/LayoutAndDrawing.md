# Layout and Drawing

Compose terminal-cell layouts and draw custom content within measured bounds.

## Overview

Twill measures width in terminal columns and height in rows. These are not pixel dimensions or Swift string character counts. Wide characters can occupy multiple columns. ``Text`` preserves LF and CRLF line breaks and wraps at ordinary spaces when offered a finite width. Other control characters become spaces rather than terminal commands.

## Compose and Constrain Content

``VStack`` places children vertically at their intrinsic heights. ``HStack`` places children horizontally at their intrinsic widths. Their spacing and alignment apply between and across children. Vertical stacks and single-child composition forward finite proposals so text can reflow. Multiple intrinsic-width horizontal siblings keep their natural widths; bound an individual child's width or use a filling frame to give it a wrapping proposal. Bounds clip content that exceeds the allocated height.

Use `.frame(width:height:minWidth:maxWidth:minHeight:maxHeight:alignment:)` to combine fixed dimensions, minimums, and flexible limits in one modifier. For example, `.frame(width: 26, maxHeight: .infinity, alignment: .top)` fixes width while filling offered height. Fixed/minimum values are runtime integers in terminal cells. Use `.cells(runtimeValue)` for finite maximums or ``FrameLimit/infinity`` to fill an offered dimension.

Dimensions must be nonnegative, minimums cannot exceed finite maximums, and a fixed dimension must lie inside any same-axis bounds. Contradictory constraints fail a precondition. A minimum pads smaller intrinsic content without making an intrinsic child demand all available space. Unbounded infinity retains intrinsic sizing, augmented by minimums. Parent proposals remain clipping boundaries even below minimum or fixed sizes. Alignment positions smaller content inside the allocated bounds, and resizing uses cached layout without reevaluating bodies.

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

``VGrid`` eagerly mounts its children and uses ``GridItem`` descriptions to choose column widths. Fixed columns reserve exact nonnegative cell widths, while flexible columns share space within nonnegative bounds. Row and column spacing are independently configurable. An adaptive description must be the sole column description; it repeats positive-minimum columns to fit the resolved width. Without a finite proposal, intrinsic content determines that width. Fixed widths and minimums remain intact under viewport clipping.

``LazyVGrid`` uses a shared `spacing:` parameter for both axes. Its current implementation mounts all children when evaluated, as documented on that type. ``ScrollView`` clips content to a visible height while preserving mounted state outside the visible area. Use ``ScrollViewReader`` to obtain a proxy for scrolling to keyed children or explicit `.id(...)` targets.

## Distribute Space and Separate Content

```swift
HStack {
    Text("Status")
    Spacer(minLength: 1)
    Divider()
    Text("Ready")
}
```

`Spacer` expands along the nearest horizontal or vertical stack's main axis, including through composition and appearance modifiers. Outside a stack it expands on both axes. Its nonnegative `minLength` defaults to zero. Stacks reserve spacer minimums and ordinary stack gaps before sharing surplus among flexible children, assigning any remainder to the last flexible child. With no finite proposal, a spacer uses its minimum. Insufficient space clips the resulting layout rather than shrinking intrinsic sibling content or spacer minimums.

`Divider()` spans the stack's minor axis, or horizontally outside a stack. `Divider(.horizontal)` and `Divider(.vertical)` choose an explicit line direction. Separators are one terminal cell thick, inherit colors and text attributes, and span intrinsic multiline neighbors even without a finite cross-axis proposal. Neither primitive adds focus stops or scheduled work. Cached resize changes placement and extent without reevaluating bodies.

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

## Size and Align Table Columns

```swift
Table(records, id: \.code) {
    TableColumn("Name", value: \.name).width(.flexible(minimum: 8, maximum: 32))
    TableColumn("Count") { Text("\($0.count)") }.width(6).alignment(.trailing)
}
```

Column width and alignment apply to headers and every body cell through one shared measurement pass. Unconfigured `.automatic` columns preserve intrinsic content and share surplus, shrinking when space is scarce. `.width(cells)` or `.width(.fixed(cells))` reserves an exact width. `.flexible(minimum:maximum:)` shares space within hard inclusive bounds, including minimum-only and maximum-only configurations using its defaults. Widths and minimums must be nonnegative, and maximums must not be smaller than minimums.

Fixed widths and minimums are retained when their sum exceeds the offered viewport, with ordinary clipping rather than negative widths or inconsistent header geometry. Capped columns leave unusable surplus blank. Without a finite proposal, bounded intrinsic content determines widths. Empty automatic columns retain a minimum cell slot, while explicit zero widths are permitted.

Per-column leading/center/trailing alignment places content within its cell at the top. Multiline cells retain their row height, with the tallest cell determining each row. Text wrapping and truncation remain ordinary text policies, so a wrapped header can add lines before the body. Wide glyphs remain atomic. Resize recomputes shared widths and placement from cached content without reevaluating bodies, remounting keyed rows, or shifting schedules.

## Format Table Values

```swift
TableColumn("Count", value: \.count, format: { "\($0) items" })
    .width(12)
    .alignment(.trailing)
```

Formatted-value columns take a typed comparable key path and a value-to-string closure. Their comparator continues to use the source value, not the resulting text, so numeric values retain numeric order regardless of units or formatting. Sorting remains caller-owned. Format changes update presentation without changing stable row IDs, activation payloads, column policies, or timeline phases. Output is ordinary `Text`, with the same sanitization and text-layout contracts.

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
