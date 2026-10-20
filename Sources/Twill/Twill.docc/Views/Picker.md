# ``Picker``

## Preview

A horizontal choice control. Left and Right change the selected option.

![Picker terminal preview: A horizontal choice control. Left and Right change the selected option.](preview-Picker)

## Presentation and Labels

The default `.inline` presentation shows marked options beside the control label. `.compact` displays only the effective option and adjusts with Left/Right; it does not open a popup. `.vertical` stacks marked rows below the label and uses Up/Down as well as Left/Right for selection. Tab traverses controls in every presentation, while Enter and Escape retain their enclosing routing behavior.

```swift
Picker("Sort", selection: $sort, options: ["Name", "Date"], presentation: .compact)

Picker(selection: $mode, options: modes, presentation: .vertical) { option in
    Text(option.title)
} label: {
    Text("Mode:").bold()
}
```

Values are explicit rather than inferred from tags. String-option conveniences use each string directly. Custom control labels are concretely typed and own their punctuation; titled initializers append a colon. The concrete type is `Picker<SelectionValue, Label, OptionLabel>`. Existing inferred title/option-label calls retain inline behavior.

An absent stored value displays the first option without rewriting the binding until a deliberate valid change. Empty options display only the control label, and selection keys do not write at boundaries. Parent option updates/reordering preserve value-based selection. Compact presentation evaluates only the effective option label, and visible value labels retain selection styling independently of the control label.

A presentation change retains the control focus owner but may replace option subtrees whose layout or visibility changes. Ordinary updates retain keyed rows and independent timeline phases. Resize reuses cached content, disabled controls do not select, and modal scopes keep selection keys from underlying controls.

Explore related views in <doc:ViewGallery>.
