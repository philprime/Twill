# ``ScrollView``

## Preview

Content clipped to a two-row viewport. Up/Down scroll; Tab moves between controls.

![ScrollView terminal preview: Content clipped to a two-row viewport. Up/Down scroll; Tab moves between controls.](preview-ScrollView)

## Programmatic Targets

A `ScrollViewReader` proxy resolves `ForEach` keys and explicit `.id(...)` targets after measurement. `.top` and `.bottom` align edges, while `.center` centers the target with any extra terminal row below it. `.nearest` makes the smallest offset change that fully reveals a target. For an oversized target it keeps the viewport inside that target, leaving an already-contained viewport unchanged. Offsets clamp to content bounds. A transparent composite target uses the combined bounds of its layout items.

Lookup stays within the reader's active content, excludes nested readers and inactive tab or modal-base branches, and uses the target's nearest contained scroll viewport. Clipped but mounted targets remain eligible. Missing, removed, unmeasured, and unscrollable targets are ignored. Explicit scrolling never moves keyboard focus or shifts timeline phases.

Use one reader per independently addressed pane so unrelated panes can reuse IDs. Within one reader, IDs should be unique; the first measured scrollable depth-first match wins. Nested scroll views keep independent offsets, and scrolling an inner target does not reveal its outer viewport automatically.

Explore related views in <doc:ViewGallery>.
