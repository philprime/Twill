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

## Disabled state

`.disabled(_:)` sets inherited interaction eligibility. A disabled ancestor cannot be re-enabled by a descendant. Disabled content remains mounted and visible, retaining state, selection, viewport memory, tasks, and timeline deadlines. The modifier does not change layout or colors.

Disabled controls are excluded from automatic and programmatic focus, editing, activation, and key handlers within the disabled scope. Disabling the focused control hides its caret and falls back to an eligible target, or clears focus when none remains. Enabled enclosing handlers and application-owned lifecycle commands remain available. Modal isolation still applies when a presented scope has no enabled controls.

Menu shortcuts and direct dialog actions respect disabled state. Escape dismisses an alert or confirmation without invoking a disabled cancel action. Confirmation dialogs supply a cancellation fallback when no enabled cancel action is available, so destructive actions do not become the default. Disabled tab destinations remain visible in the bar and are skipped by keyboard selection.

## Text-field input

A focused text field accepts input immediately. It consumes text and caret keys before screen or application shortcuts. Losing focus hides its caret; regaining focus places the insertion point at the end of the current text. Editing does not require a separate public state or activation key. Tab and Shift-Tab are not editing keys: they route through enclosing handlers and move between controls without wrapping. No scroll container or navigation wrapper is needed to leave a field.

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

## Key routing

The application handles reserved lifecycle keys first. Other keys are routed within the topmost modal scope, or the active screen when no modal is present. A focused text field consumes its editing keys. Otherwise the focused control receives the key first, followed by enclosing view handlers when a handler returns `.ignored`, then application-level handlers if still unhandled. `.handled` stops propagation. Returning `.ignored` never crosses a modal boundary.

`.onKeyPress` is scoped to its view. A parent can provide screen-level shortcuts for keys ignored by its focused descendants. A focused text field consumes printable characters and navigation keys, including characters that would otherwise trigger shortcuts. Application-level shortcuts are not a substitute for focus-scoped interaction.

The terminal host alone positions and shows the hardware cursor at the editing caret. It hides the cursor when no text field is focused and restores inherited terminal settings and cursor visibility during shutdown. Views supply a caret position relative to their laid-out bounds; they do not emit terminal escape sequences. Presentation uses terminal cells, so the caret's column is measured in display cells rather than string indices.

Focus resolution separates mounted queries, target selection, and transition application. Queries gather eligible candidates and binding requests without changing focus. Selection returns a synchronous transition rather than invoking callbacks. Navigation and branch restoration use the same application path for ordered memory updates, blur, and binding synchronization. Unchanged targets do not repeat blur or binding publication. Transition data is not retained across input or tree updates, and modal dismissal can reset the presentation marker while preserving the enclosing scope's remembered target.

The runtime remains event-driven: input, state writes, and modal transitions request coalesced presentation without polling. Unrelated timeline deadlines remain unchanged by those updates.
