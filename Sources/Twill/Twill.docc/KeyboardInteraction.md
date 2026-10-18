# Keyboard Interaction

Route input through focused controls, scoped handlers, and modal presentations.

## Overview

Twill manages focus independently of selection, scroll position, and the terminal's hardware cursor. Controls such as ``Button`` and ``TextField`` are focusable automatically. Apply `.focusable()` when a custom row needs to participate in keyboard navigation.

The first eligible control receives initial focus. Tab and Shift-Tab move between controls in composition order, without wrapping. This works automatically, with no navigation wrappers. Compound controls such as lists, tables, and editors expose one control-level Tab stop and retain their internal focus when revisited. Arrow keys move focus when the control does not consume them or confine them to internal navigation. Navigation is not spatial.

## Handle a Scoped Shortcut

Attach `.onKeyPress` to the smallest appropriate container. Return ``KeyPressResult/handled`` to stop propagation or ``KeyPressResult/ignored`` to allow an enclosing handler to receive the key:

```swift
VStack {
    Text("Press r to reset")
    Button("Increment") { count += 1 }
}
.onKeyPress { key in
    guard key == .r else { return .ignored }
    count = 0
    return .handled
}
```

The focused control receives input before its ancestors. A focused text field consumes printable input and caret keys, so those keys do not trigger enclosing shortcuts. ``Application/onKeyEvent`` receives otherwise unhandled keys after view routing. Enabled lifecycle shortcuts, including Control-C by default, are handled by the application first.

## Edit and Submit Text

A focused text field accepts input immediately. Enter invokes the nearest `.onSubmit` action. Submission does not clear the text or move focus automatically. Escape remains available to enclosing handlers so the application can define dismissal or navigation.

The host displays the hardware cursor at an editing control's caret and hides it when appropriate. Reverse-video focus highlighting does not depend on that cursor.

## Navigate Scrolling Content

A ``ScrollView`` controls its viewport, not keyboard grouping. Tab visits the controls inside it in the same way as controls outside it. Moving focus reveals the control through its enclosing viewports, each of which retains its own offset.

A scroll view with no interactive descendants receives focus itself. Up and Down scroll one row, and Page Up and Page Down scroll by a viewport. Paging from a contained control uses its nearest enclosing viewport unless the control consumes the key. Give the scroll view a bounded height, for example with `.frame(height: 8)`, to establish its visible area.

## Request Focus Programmatically

Use ``FocusState`` when automatic navigation is insufficient. A Boolean identifies one target, while an optional hashable value can identify several:

```swift
enum Field: Hashable { case name, email }

@FocusState private var focusedField: Field?
```

Attach `.focused($focusedField, equals: .name)` and `.focused($focusedField, equals: .email)` to the respective fields. Set `focusedField = .email` from an action to move focus. Automatic navigation also updates the binding. Setting it to `nil` removes focus until another target is requested.

## Present a Modal Scope

The `.sheet`, `.alert`, and `.confirmationDialog` modifiers isolate interaction from the underlying screen. While presented, ignored keys do not escape into underlying handlers. Dismissal restores the previous focus when that target is still mounted, or falls back to an eligible target.

A sheet retains the underlying mounted view and its schedules. Keep the presentation Boolean in ``State`` and pass its binding to the modifier. See <doc:ViewGallery> for presentation previews.
