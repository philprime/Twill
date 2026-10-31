# ``SheetView``

## Preview

A modal sheet over the base page. It traps keys and focus, restoring focus when dismissed.

![SheetView terminal preview: A modal sheet over the base page. It traps keys and focus, restoring focus when dismissed.](preview-SheetView)

## Payload-driven Presentation

Use `.sheet(item: $selectedItem)` for an optional identifiable payload. A non-nil item presents content, and nil dismisses it while restoring underlying focus.

```swift
.sheet(item: $editingNote) { note in
    NoteEditor(note: note, onClose: { editingNote = nil })
}
```

The content closure receives updated payload values. A matching ID retains mounted state and owned work. A changed ID replaces the presented subtree using ordinary keyed identity, and dismissing/re-presenting starts a new lifetime even for the same ID. The base remains mounted with independent state and schedules. Resize reuses cached descriptions.

Payload sheets reuse the ordinary modal scope and key isolation. Caller actions clear the optional binding to dismiss. Presentation policy and dismissal hooks are separate from payload identity.

Explore related views in <doc:ViewGallery>.
