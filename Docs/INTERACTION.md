# Interaction model

Twill routes keyboard input through mounted views on the UI actor. Views declare focusable controls and key handlers. The runtime owns focus traversal, modal scopes, and terminal cursor presentation. [State and identity](STATE.md) defines how mutations retain values and trigger presentation.

## Focus, selection, and cursor

Focus identifies the control that receives keyboard input. Selection identifies an active item _within_ a control. Selection can remain visible when that control loses focus. Scroll position belongs to the mounted viewport, independently of both focus and selection. None of these concepts is the terminal hardware cursor. Interactive rows opt in with `.focusable()` individually; static headers and layout containers do not become focus targets. `TextField` is focusable by default.

The first eligible control on a newly mounted screen receives initial focus. Its content is rendered in reverse video without using the terminal hardware cursor as the focus indicator or changing selection. Tab moves to the next control and Shift-Tab to the previous control in mounted composition order, without wrapping. Static content is skipped. Controls participate automatically, without navigation wrappers. Compound controls expose one control-level Tab stop and retain their internal focus when revisited. Their grouping is an internal implementation detail, not a public layout API. A tab bar is its own control; Tab or Down enters its selected destination and restores that destination's remembered control.

ArrowDown and ArrowRight move to the next eligible focus target, and ArrowUp and ArrowLeft move to the previous one, unless consumed by the control. This is not spatial navigation. Compound controls handle or confine internal navigation rather than using arrows to leave their scope. When a focused control is removed, focus falls back to an eligible remaining target. If a scope has no focusable controls, keys can still reach its enclosing handlers.

`ScrollView` takes its viewport height from the proposed size (for example, a fixed-height frame) and clips larger content without unmounting it. It does not group its controls for keyboard traversal. Moving focus reveals the control through its enclosing viewports. Each viewport owns its vertical offset independently of focus and other viewports. A viewport without interactive controls receives focus itself; Up/Down scroll by one row and Page Up/Down scroll by one viewport, clamped to content bounds. Paging from a contained control uses the nearest enclosing viewport unless the control consumes the key. Enter does not enter a scrolling mode.

Conditional navigation activates only the mounted screen. Opening a new screen focuses its first control; returning to a screen restores its prior control when still mounted, otherwise its first control.

Retained inactive destinations do not participate in focus discovery, key routing, or modal activation. Modifiers surrounding an inactive destination follow the same eligibility rule. Focus-binding synchronization still visits inactive destinations when focus changes so bindings observe losing focus. Within a modal scope, discovery and binding synchronization follow its active branch rather than the retained underlying content. Interaction eligibility does not suspend retained timeline schedules.

A `.sheet` establishes a modal focus scope. Its content replaces the active inline frame while the underlying view remains mounted and retains its timeline deadlines. Presentation remembers the underlying focus and activates the sheet's first control. While presented, keys cannot reach the underlying screen, even when a handler returns `.ignored`. Dismissal restores the remembered control if it remains mounted, otherwise focus falls back to the active screen's first control. Explicit `@FocusState` and `.focused(...)` are for programmatic focus changes when automatic focus behavior is insufficient. A Boolean binding identifies a single focus target; an optional hashable value identifies one of several targets with `.focused(_:equals:)`. Bindings follow automatic focus traversal. Focusing a container restores its remembered focusable descendant when available, otherwise its first descendant. Programmatic focus can reach controls elsewhere in the active screen. Setting a binding to `false` or `nil` removes focus until another target is requested.

## Nonselectable collections

Omitting a collection's selection binding constructs nonselectable rows, rather than a selectable control with an empty value. Such a collection does not mark or activate rows, and its `.onActivate` callback is inactive. Embedded controls participate in ordinary Tab traversal and keep their own actions and submission routing. Sortable table headers remain interactive without adding a synthetic row-focus target. A static viewport receives scrolling keys when it has no interactive descendants.

Supply stable unique IDs for reconciliation, including an explicit `Table(..., id:)` when elements are not `Identifiable`. Reorder and insertion retain keyed row state; removal unmounts it. A constant nil selection binding still constructs a selectable collection governed by its selection policy. Layout and viewport clipping remain independent of these interaction choices.

## Collection selection policies

Selection resolution is independent of keyboard focus. The default `selectionPolicy: .firstVisible` displays the first visible row for nil, missing, or hidden IDs. `.allowEmpty` displays no selection for those IDs. Empty collections have no effective selection under either policy. Outline visibility follows bound expansion, and a hidden stored ID can become selected again when it reappears.

With row content focused and no effective selection, Down/Home selects the first visible row and Up/End the last. Enter is consumed without submission or binding writes. Outline Left/Right is likewise consumed without changing expansion or selection. With an effective selection, navigation and submission retain their ordinary behavior. Sortable table headers remain reachable above the first selected row, or from an empty table, without normalizing row selection merely to move focus.

Rendering, filtering, expansion changes, and policy changes do not write the selection binding. Only explicit interaction or application actions do so. Use `SelectionPolicy.resolve(...)` with the same data and policy for detail presentation. Its hierarchy overload shares the outline's visible-row traversal.

## Item-aware collection activation

A collection's `.onActivate` callback receives its effective original element on Enter. It follows the configured selection policy and current visible data, not a separately maintained focus value or a second lookup of the stored ID. The handler snapshots the element, writes its effective ID to the selection binding, then invokes the callback exactly once. A binding setter that redirects selection does not replace that payload.

An installed activation callback consumes Enter instead of also invoking `.onSubmit`. Without one, existing submission routing remains. Empty or allow-empty collections with no effective row consume Enter without writes, activation, or submission. Sortable headers retain their own Enter/Space behavior and do not activate rows. A later activation callback replaces an earlier one, and callback changes preserve mounted identity and schedules.

Activation is scoped to the eligible focused collection. Inactive, disabled, and underlying modal content do not receive it. The callback may change or remove data; subsequent presentation reconciles keyed rows normally. Apply this typed callback directly to the collection before general view modifiers.

## Disabled state

`.disabled(_:)` sets inherited interaction eligibility. A disabled ancestor cannot be re-enabled by a descendant. Disabled content remains mounted and visible, retaining state, selection, viewport memory, tasks, and timeline deadlines. The modifier does not change layout or colors.

Disabled controls are excluded from automatic and programmatic focus, editing, activation, and key handlers within the disabled scope. Disabling the focused control hides its caret and falls back to an eligible target, or clears focus when none remains. Enabled enclosing handlers and application-owned lifecycle commands remain available. Modal isolation still applies when a presented scope has no enabled controls.

Menu shortcuts and direct dialog actions respect disabled state. Escape dismisses an alert or confirmation without invoking a disabled cancel action. Confirmation dialogs supply a cancellation fallback when no enabled cancel action is available, so destructive actions do not become the default. Disabled tab destinations remain visible in the bar and are skipped by keyboard selection.

## Text-field input

A focused editable text field accepts input immediately. It consumes text and caret keys before screen or application shortcuts. Losing focus hides its caret; regaining focus places the insertion point at the end of the current text. Left/Right move one grapheme, Home/End move to the value's start/end, Backspace removes the preceding grapheme, and Delete removes the following grapheme without advancing the insertion point. These ordinary editing keys are consumed even at boundaries; no-op keys do not write the binding. Secure fields share this behavior while presenting only masked cells. Editing does not require a separate public state or activation key. Tab and Shift-Tab are not editing keys: they route through enclosing handlers and move between controls without wrapping. No scroll container or navigation wrapper is needed to leave a field.

Enter invokes the nearest enclosing `.onSubmit` action. Submission retains the text and does not implicitly move focus; the action can request another target. Escape routes to enclosing handlers, allowing the screen to choose whether to move focus, dismiss a sheet, or navigate back. Cancelling or reverting text is a separate action.

| Key             | Focused interactive row                         | Focused text field                           |
| --------------- | ----------------------------------------------- | -------------------------------------------- |
| Tab / Shift-Tab | Move to the next or previous control            | Move to the next or previous control         |
| Arrow keys      | Move focus unless consumed or internally scoped | Edit or move caret as supported by the field |
| Enter           | Activate focused row if its handler consumes it | Invoke the nearest submit action             |
| Escape          | Route to enclosing handlers                     | Route to enclosing handlers                  |
| Page Up/Down    | Route to enclosing handlers                     | Remain in the field                          |
| Printable keys  | Route to enclosing handlers                     | Insert text; do not invoke shortcuts         |

Ctrl-C remains an application-owned orderly shutdown exception in every mode.

## Editor visual rows

An editor's explicit `lineBreakMode` selects word or character soft wrapping, or unwrapped horizontal scrolling with the default `.clipping`. Soft wraps preserve logical text, including separators and empty lines. Wrapped visual rows reserve one terminal cell for the insertion caret and disable horizontal viewport offsets. A one-column viewport contains only the caret; oversized graphemes remain wholly clipped.

Vertical and page movement use visual rows and preferred cell columns. Shared wrap boundaries retain visual caret affinity without changing their logical offset. Home/End retain logical-line semantics, and word editing continues to use logical grapheme offsets. Resize reflows cached content and reveals the same insertion point without body reevaluation or schedule changes. Mode changes and external value updates retain mounted caret and viewport memory.

## Word editing and read-only values

Exact Alt or Control modifiers on Left/Right move to the start of the previous run or end of the next run. Backspace/Delete with either modifier remove the corresponding range. Intervening whitespace, including newlines, is skipped before finding a run. Unicode letters, numbers, and underscores form word runs; punctuation and emoji form separate runs. All offsets are grapheme boundaries, and these operations share one policy across single-line, masked, and multiline editing. Modified events must be forwarded by the terminal. Escape-prefixed Backspace is recognized as Alt-Backspace alongside primary CSI-u reports.

`editingMode: .readOnly` retains focus, the visible caret, word/caret navigation, and editor viewport movement. It consumes attempted insertion, deletion, and editor newlines without writing the binding or leaking those keys into enclosing shortcuts. Ordinary single-line Enter still submits; multiline Enter stays consumed without an implicit submit. Non-text character chords and Escape retain their existing routing. This policy does not disable the control or change its appearance, and application-owned binding updates remain visible.

Editing-mode updates retain mounted caret and viewport state and independent timeline deadlines. The default mode is `.editable`. Inherited disabled state still removes interaction and focus eligibility regardless of editing mode.

## Commands and key hints

`Command<ID>` is an immutable snapshot of application-owned action identity, title, availability, role, shortcut alternatives, and a UI-actor action. `perform()` respects the snapshot's availability. Derive command values from mounted state when describing a screen, and share those values through `Button(command)` (including inside menu builders) and `KeyHints(commands)`.

Command identity is logical metadata. It does not establish mounted view identity or register an action globally. Only mounted eligible controls supply shortcut actions. Buttons use the command's current title, role, availability, and alternatives. Inherited disabled state can further restrict a control without mutating the shared command snapshot.

`KeyHints` displays available commands with shortcuts, omitting unavailable commands and commands without shortcuts. It honors its own inherited disabled scope and contributes no layout when no hints remain. Extra control-local disabled modifiers do not change a command value elsewhere; use the shared command's availability for conditions that must also govern its hints. Hints are presentation only and do not install handlers, register work, or change focus. Metadata updates retain mounted state and independent scheduling deadlines.

## Action shortcuts

`.keyboardShortcut(_:)` associates one key or an array of `KeyboardShortcut` alternatives with a button's existing action. Apply it to a button or its surrounding modifiers, not to a container of independent actions. A matching event invokes the action once, even when alternatives repeat. The modifier does not move focus. Menu action labels include hints from structurally eligible shortcut metadata, including disabled actions; other button labels remain unchanged. `KeyboardShortcut` supplies generated display hints and accepts explicit hint overrides for menus and help text.

Focused controls and existing scoped handlers receive input first. Unhandled shortcuts run before default focus navigation. Search starts at the focused subtree and expands through its enclosing mounted content, stopping at the current screen or topmost modal boundary. The nearest matching enabled action wins; ties within a subtree follow composition order. Without focus, search uses the active scope. Inactive destinations and disabled actions do not participate. Dialog shortcuts preserve action-before-dismissal ordering, and inner sheets own their own dismissal.

Matching uses the decoded key identity, character case, and reported modifier flags. Legacy control bytes are distinct from modified character events. Named control chords represent the legacy decoder's values, including ambiguities with special keys. Modifier composition supports any key without enumerating every chord. Super corresponds to Command on macOS when the terminal forwards that modifier.

The decoder accepts primary CSI-u Unicode key reports with the supported modifier flags, in addition to legacy input and modified navigation/function sequences. Unsupported extended or functional CSI-u reports remain atomic unknown events. Decoding does not negotiate a keyboard protocol or override shortcuts reserved by the terminal. See the [keyboard protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/) for terminal reporting requirements.

## Key routing

The application handles reserved lifecycle keys first, recognizing enabled Control-C and Control-D shutdown policy in both legacy control-byte and primary CSI-u encodings. Other keys are routed within the topmost modal scope, or the active screen when no modal is present. A focused text field consumes its editing keys. Otherwise the focused control receives the key first, followed by enclosing view handlers when a handler returns `.ignored`, then application-level handlers if still unhandled. `.handled` stops propagation. Returning `.ignored` never crosses a modal boundary.

`.onKeyPress` is scoped to its view. A parent can provide screen-level shortcuts for keys ignored by its focused descendants. A focused text field consumes printable characters and navigation keys, including unmodified characters that would otherwise trigger shortcuts. Non-text Control, Alt, Super, Hyper, and Meta character chords route to enclosing handlers and action shortcuts. Application-level shortcuts are not a substitute for focus-scoped interaction.

The terminal host alone positions and shows the hardware cursor at the editing caret. It hides the cursor when no text field is focused and restores inherited terminal settings and cursor visibility during shutdown. Views supply a caret position relative to their laid-out bounds; they do not emit terminal escape sequences. Presentation uses terminal cells, so the caret's column is measured in display cells rather than string indices.

Focus resolution separates mounted queries, target selection, and transition application. Queries gather eligible candidates and binding requests without changing focus. Selection returns a synchronous transition rather than invoking callbacks. Navigation and branch restoration use the same application path for ordered memory updates, blur, and binding synchronization. Unchanged targets do not repeat blur or binding publication. Transition data is not retained across input or tree updates, and modal dismissal can reset the presentation marker while preserving the enclosing scope's remembered target.

The runtime remains event-driven: input, state writes, and modal transitions request coalesced presentation without polling. Unrelated timeline deadlines remain unchanged by those updates.
