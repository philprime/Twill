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

Payload sheets reuse the ordinary modal scope and key isolation. Caller actions can clear the optional binding or use the scoped dismiss action.

## Dismissal Lifecycle

```swift
.sheet(isPresented: $showDetails, dismissalPolicy: .escape, onDismiss: didClose) { dismiss in
    Button("Close", action: dismiss.callAsFunction)
}

.sheet(item: $editingNote) { note, dismiss in
    NoteEditor(note: note, onClose: dismiss.callAsFunction)
}
```

Unhandled Escape dismisses ordinary sheets by default. `.manual` keeps them open until an explicit action or binding change. Content handlers keep first refusal, and modal keys never leak to underlying views. Dialog and menu dismissal retain their own precedence.

A `DismissAction` belongs to one mounted content lifetime. Matching payload IDs retain its validity; replacement revokes it, including when an old ID later returns. Dismissing/reopening creates a fresh scope. Retaining an action does not retain its sheet, and stale calls do nothing.

`onDismiss` runs once after the presented subtree is removed, including parent removal and shutdown. The current callback is cleared before delivery, allowing reentrant writes to open a fresh lifetime. Payload updates/replacement do not dismiss the modal scope. Child cancellation starts before the hook; the host still joins owned cleanup before terminal restoration.

Explore related views in <doc:ViewGallery>.
