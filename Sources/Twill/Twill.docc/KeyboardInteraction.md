# Keyboard Interaction

Route input through focused controls, scoped handlers, and modal presentations.

## Overview

Twill manages focus independently of selection, scroll position, and the terminal's hardware cursor. Controls such as ``Button`` and ``TextField`` are focusable automatically. Apply `.focusable()` when a custom row needs to participate in keyboard navigation.

The first eligible control receives initial focus. Tab and Shift-Tab move between controls in composition order, without wrapping. This works automatically, with no navigation wrappers. Compound controls such as lists, tables, and editors expose one control-level Tab stop and retain their internal focus when revisited. Arrow keys move focus when the control does not consume them or confine them to internal navigation. Navigation is not spatial.

## Share Commands and Hints

Describe an action once and share its current metadata between controls and help text:

```swift
let save = Command("save", title: "Save", isEnabled: !title.isEmpty,
    shortcuts: [KeyboardShortcut(.controlS), KeyboardShortcut(.superS)],
    action: saveChanges)

VStack {
    Button(save)
    KeyHints([save])
}
```

Create command snapshots from mounted state in the view body so titles, availability, shortcuts, and hints update together. Use `Button(command)` inside a menu builder to share the same action metadata. Its shortcut alternatives remain scoped to the open menu. A command's role participates in dialog policy, and `perform()` skips an unavailable snapshot.

``KeyHints`` shows available commands with shortcuts, using each shortcut's generated or overridden hint. It respects its inherited disabled scope and omits empty content. Hints alone do not activate shortcuts. Use shared command availability for conditions that must also hide hints, rather than a separate disabled modifier on a particular control.

Command IDs are application metadata. Use `.id(_:)` separately when explicit mounted identity is needed.

## Attach Action Shortcuts

Use `.keyboardShortcut(_:)` to reuse a button's action and disabled state:

```swift
let saveShortcut = KeyboardShortcut(.controlS)
let superSaveShortcut = KeyboardShortcut(.superS)

Button("Save", action: save)
    .disabled(title.isEmpty)
    .keyboardShortcut([saveShortcut, superSaveShortcut])
```

Pass one `KeyboardShortcut`, an array of alternatives, or a `KeyEvent` directly. A matching event invokes the action once without moving focus. The modifier leaves the label unchanged. Reuse `saveShortcut.hint` in help text, or supply a custom hint with `KeyboardShortcut(.controlS, hint: "Save")`.

Focused editing and existing scoped handlers take priority. Otherwise the nearest enclosing content with a matching enabled action wins, with composition order resolving ties. Inactive destinations and underlying modal content cannot supply shortcuts. Apply the modifier to a button or its modifiers, rather than a container of independent actions.

``KeyEvent`` includes named control chords, Super-letter chords, and function keys. Compose other combinations with `.s.withModifiers([.superKey, .shift])` or `.arrowUp.withModifiers(.alt)`. Super corresponds to Command on macOS only when the terminal reports it. Twill decodes primary CSI-u character reports but does not enable a reporting mode or bypass the terminal's own key bindings. Keys match their decoded identity and modifiers, so legacy control-byte events and enhanced modified-character events remain distinct.

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

The focused control receives input before its ancestors. A focused text field consumes printable input and caret keys, so those keys do not trigger enclosing shortcuts. Left/Right move one grapheme, Home/End move to the beginning/end of the value, Backspace removes the previous grapheme, and Delete removes the next one without advancing the caret. Boundary keys remain consumed without changing the binding. ``SecureField`` shares these keys while keeping rendered content and caret geometry masked. Non-text modified character chords remain available to scoped handlers and action shortcuts. ``Application/onKeyEvent`` receives otherwise unhandled keys after view routing. Enabled lifecycle shortcuts, including Control-C by default, are handled by the application first.

## Navigate Words and Present Read-Only Values

Alt or Control with Left/Right moves to the previous run's start or next run's end. The same modifiers with Backspace/Delete remove that range. Whitespace is skipped before a run; Unicode letters, numbers, and underscores group together, separately from punctuation and emoji. These operations preserve whole graphemes across all editing controls. Terminals must report the modifiers. Alt-Backspace also accepts the common Escape-prefixed encoding.

Use an explicit editing mode when text should remain navigable without accepting edits:

```swift
TextEditor(text: $document, editingMode: .readOnly)
```

``TextField`` and ``SecureField`` accept the same option. Read-only controls retain focus, caret navigation, and scrolling. Attempts to insert or delete are consumed without changing the binding. Single-line submit actions and non-text modified character shortcuts retain their normal routing, while multiline Enter is consumed without insertion or submission. Application-owned updates remain visible. Editing mode changes preserve mounted state and schedules. Use `.disabled(_:)` when interaction and focus should be excluded entirely.

## Disable Controls

Use `.disabled(_:)` on a control or container:

```swift
Button("Save", action: save)
    .disabled(title.isEmpty)
```

The value is inherited, so a disabled ancestor cannot be re-enabled by a descendant. Disabled controls remain visible and mounted but are skipped by focus traversal and cannot edit, activate, or handle keys within their disabled scope. Disabling the focused control moves focus to an eligible target and hides its editing caret. State and schedules remain intact. The modifier does not change colors or layout.

Enabled enclosing shortcuts and lifecycle commands remain available. Dialog dismissal does not invoke a disabled cancel action.

## Edit and Submit Text

A focused editable text field accepts input immediately. Enter invokes the nearest `.onSubmit` action. Submission does not clear the text or move focus automatically. Escape remains available to enclosing handlers so the application can define dismissal or navigation.

The host displays the hardware cursor at an editing control's caret and hides it when appropriate. Reverse-video focus highlighting does not depend on that cursor.

## Wrap Editor Lines

```swift
TextEditor(text: $document, lineBreakMode: .wordWrapping)
    .frame(width: 40, height: 8)
```

An editor's `lineBreakMode` is explicit: `.wordWrapping` and `.characterWrapping` reflow into visual rows, while the default `.clipping` retains unwrapped horizontal scrolling. Soft wraps preserve every model character and never insert newlines. Wrapped rows reserve the final viewport cell for the caret. A one-column viewport can show only the caret; oversized graphemes are omitted whole rather than split.

Up/Down and Page keys follow visual rows and preserve a preferred cell column, including end-of-row affinity at shared wrap boundaries. Home/End still reach logical-line endpoints. Read-only and word-editing policies apply in either layout mode. Resize reflows cached descriptions, retains the logical insertion offset, and reveals the caret without reevaluating view bodies or altering sibling schedules. Wrapping-mode and external value updates preserve mounted editor state.

## Display Collections Without Selection

```swift
List(items) { item in
    Button(item.title) { open(item) }
}
Table(records, id: \.code) {
    TableColumn("Name", value: \.name)
}
```

Omitting the selection binding creates nonselectable content. Embedded controls participate in ordinary focus traversal, and sortable table headers retain their actions. Static content can scroll without row selection. Collection-level `.onActivate` is inactive, while row controls keep their own activation and submission behavior. A constant nil binding instead constructs a selectable collection and applies its selection policy.

Explicit table IDs support non-Identifiable elements and stable reconciliation on reorder, insertion, and removal. The concrete type is `Table<Data, ID, each Content>`; inferred Identifiable construction remains available without `id:`. Public column composition remains typed.

## Choose Collection Selection Behavior

```swift
List(items, selection: $selectedID, selectionPolicy: .allowEmpty) { item in
    Text(item.title)
}
let detail = SelectionPolicy.allowEmpty.resolve(in: items, selection: selectedID)
```

List, table, and outline controls default to `.firstVisible`, resolving nil, missing, or hidden IDs to the first visible row. `.allowEmpty` keeps those cases unselected. Empty collections have no effective selection under either policy. Resolution never writes the binding; a stored ID can reappear after filtering or expansion changes. The hierarchy resolver accepts `children:` and `expandedIDs:` to match outline visibility.

With row content focused and no effective selection, Down/Home chooses the first row and Up/End chooses the last. Enter does not submit, and outline Left/Right does not expand or normalize selection. Existing selection retains ordinary navigation and submission behavior. Sortable table headers remain independent of row selection. Policy updates retain mounted rows, focus, and sibling schedules.

## Activate Collection Items

```swift
List(items, selection: $selectedID) { item in
    Text(item.title)
}
.onActivate { item in
    open(item)
}
.frame(height: 8)
```

List, table, and outline activation callbacks receive the effective original element under the current selection policy. The element is captured before the selection write, and its ID is written before the callback runs. Callers do not need to read focus or recompute fallback selection. An installed callback consumes Enter instead of also firing `.onSubmit`; without one, submission behavior remains unchanged.

No effective row means no activation, binding write, or submission. Sortable headers continue sorting rather than activating rows. Disabled/inactive controls and underlying modal content cannot activate. A later callback replaces an earlier one without changing collection identity or schedules. Callbacks may update or remove data, with ordinary keyed reconciliation on the next presentation. Apply `.onActivate` to the collection before general view modifiers.

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
