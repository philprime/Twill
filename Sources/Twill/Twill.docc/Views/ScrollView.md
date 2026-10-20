# ``ScrollView``

## Preview

Content clipped to a two-row viewport. Up/Down scroll; Tab moves between controls.

![ScrollView terminal preview: Content clipped to a two-row viewport. Up/Down scroll; Tab moves between controls.](preview-ScrollView)

## Cell Indicators

Apply `.scrollIndicators(.visible)` to reserve one right-hand column and draw a cell-based track and proportional thumb. Visibility is inherited by nested viewports, including collection viewports; a closer modifier overrides it. The default `.hidden` reserves no space.

Visible viewports use offered width and height, or intrinsic content plus the indicator column when proposals are unspecified. The reservation is constant even when content fits, preventing content wrapping and overflow from changing the width repeatedly. Fitting or empty content uses a full-height thumb. Zero-sized viewports draw nothing, while an indicator-only one-column viewport remains valid.

Content is measured and clipped separately from the indicator. Shared table geometry uses the reduced content width, and cached resize recomputes wrapping and thumb position together. Cells inherit foreground/background and text attributes without adding focus stops, timers, or animation. Unchanged cells do not produce terminal output.

## Programmatic Targets

A `ScrollViewReader` proxy resolves `ForEach` keys and explicit `.id(...)` targets after measurement. `.top` and `.bottom` align edges, while `.center` centers the target with any extra terminal row below it. `.nearest` makes the smallest offset change that fully reveals a target. For an oversized target it keeps the viewport inside that target, leaving an already-contained viewport unchanged. Offsets clamp to content bounds. A transparent composite target uses the combined bounds of its layout items.

Lookup stays within the reader's active content, excludes nested readers and inactive tab or modal-base branches, and uses the target's nearest contained scroll viewport. Clipped but mounted targets remain eligible. Missing, removed, unmeasured, and unscrollable targets are ignored. Explicit scrolling never moves keyboard focus or shifts timeline phases.

Use one reader per independently addressed pane so unrelated panes can reuse IDs. Within one reader, IDs should be unique; the first measured scrollable depth-first match wins. Nested scroll views keep independent offsets, and scrolling an inner target does not reveal its outer viewport automatically.

Explore related views in <doc:ViewGallery>.
