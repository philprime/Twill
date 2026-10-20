# Managing State

Keep values alive with mounted view identity and share mutations through bindings.

## Overview

View values are descriptions that can be recreated. Twill retains ``State`` storage in the mounted hierarchy, not in each new copy of a description. The initial value is used when the owner first mounts. Later descriptions with the same identity reuse that storage.

## Share a Value with a Control

Declare `@State` in the view that owns a value. Pass its projected value, prefixed with `$`, to a control that edits it:

```swift
struct Preferences: View {
    @State private var name = "Taylor"
    @State private var notifications = true

    var body: some View {
        VStack {
            TextField("Name", text: $name)
            Toggle("Notifications", isOn: $notifications)
            Text("Hello, \(name)")
        }
    }
}
```

A ``Binding`` reads and writes the owner's value. It does not create independent storage or extend the owner's lifetime. A write requests presentation internally. Multiple writes can be coalesced, and unchanged output does not cause another terminal frame to be written.

Use bindings for shared mutable values and action closures for commands. A child can declare `@Binding var name: String` to receive a value owned by an ancestor.

Project writable properties through a binding, such as `$settings.name`, to edit one property of a larger state value. Projections can be chained for nested properties. Each write updates the latest owner value while preserving its other properties and requests presentation through the original binding.

Use `Binding.constant(value)` when a control needs a binding to a fixed value. The binding returns the supplied value and ignores writes from the control.

## Edit Collections

Index a binding to a mutable collection, such as `$items[index].name`, to edit an element at a position. The index must remain valid in the current collection. An indexed binding follows the position, not the element's identity, when elements move.

Pass a collection binding to ``ForEach`` to create editable rows:

```swift
ForEach($items) { item in
    TextField("Name", text: item.name)
}
```

Each closure receives a binding to an element. Elements must be identifiable, or supply an explicit `id:` key path. Row bindings resolve the latest element by its stable, unique ID on each access, including after insertion or reordering. This lookup is linear in the collection size. A row binding is invalid after its element is removed or its ID changes, so do not retain bindings to removed rows or edit identity through them.

Projected closure parameters are also supported. Use an explicit UI-actor annotation for this syntax:

```swift
ForEach($items) { @MainActor $item in
    TextField("Name", text: $item.name)
}
```

## Preserve Identity

For ordinary composition, structural position and concrete view type determine mounted identity. Replacing a type or switching a conditional branch replaces the affected subtree. Removing a view releases its state. Mounting it again starts from its initial values.

Use `.id(value)` to give a subtree an explicit identity within its structural position. Equal IDs retain the subtree's state, focus and viewport memory, and pending schedules while updating its inputs. Changing the ID replaces the subtree and cancels its owned tasks. Returning to a previous ID mounts fresh state rather than restoring removed content.

Modifier order determines the identity boundary. In `content.task { ... }.id(value)`, changing the ID replaces the task owner. In `content.id(value).task { ... }`, the task owner is outside that boundary and retains its lifetime. Replacement does not wait for cancelled tasks to finish. The host retains unfinished work and joins it during shutdown.

Use ``ForEach`` with stable, unique element identifiers for dynamic collections. Reordering elements then preserves state for the identifiers that remain mounted. Do not use an index as identity when insertion or reordering changes which logical element occupies it.

Keep state in a persistent ancestor when it must survive removal of a child. In particular, collapsed disclosure content is unmounted. A hidden tab destination, in contrast, remains mounted and retains its state.

## Separate Selection from Focus

Selection identifies an item within a collection. Focus identifies the control receiving keyboard input. Store selection in an ancestor if it needs to survive navigation. A selected row can remain visibly selected even when focus moves to another control.

When a collection's bound selection is absent, the first visible item is the effective selection without rewriting the binding. User selection then updates the bound value. Empty collections have no activation target.

See <doc:KeyboardInteraction> for focus routing and <doc:ScheduledWork> for work owned by a mounted view.

## Observe Equatable Values

```swift
Toggle("Show hidden", isOn: $showHidden)
    .onChange(of: showHidden) { oldValue, newValue in
        reload(showHidden: newValue)
    }
```

``View/onChange(of:initial:_:)`` delivers old/new values after reconciliation, coalescing intermediate and equal updates. Set `initial: true` for a current/current callback on the first eligible pass. Retained inactive destinations defer delivery until activation, while removal cancels it. Callback state writes request later mounted passes, with input routing and presentation handled by the host.

## Restart Work by Identity

```swift
let requestedID = requestID
Text(title).task(id: requestedID) {
    title = await loadTitle(requestedID)
}
```

``View/task(id:priority:_:)`` retains work for equal Equatable IDs, including after completion. A changed ID cancels and joins prior cleanup before starting its replacement. Rapid changes can skip intermediate actions without skipping predecessor cleanup. Task identity does not replace mounted content identity or its state/focus.

Actions handle their own errors and cancellation cooperatively. Removal and shutdown join all owned work before terminal restoration, so unfinished cleanup delays both replacement and shutdown.
