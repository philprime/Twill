# Interaction model

Twill routes keyboard input through mounted views on the UI actor. Views declare focusable controls and key handlers. The runtime owns focus traversal, modal scopes, and terminal cursor presentation. [State and identity](STATE.md) defines how mutations retain values and trigger presentation.

## Focus, selection, and cursor

Focus identifies the control that receives keyboard input. Selection identifies an active item _within_ a control. Selection can remain visible when that control loses focus. Scroll position belongs to the mounted viewport, independently of both focus and selection. None of these concepts is the terminal hardware cursor. Interactive rows opt in with `.focusable()` individually; static headers and layout containers do not become focus targets. `TextField` is focusable by default.

The first focusable control on a newly mounted screen receives initial focus. Its content is rendered in reverse video without using the terminal hardware cursor as the focus indicator or changing selection. Outside scrollable panes, ArrowDown and ArrowRight move to the next focusable control in mounted composition order; ArrowUp and ArrowLeft move to the previous one. This is not spatial navigation. Static content is skipped. Tab and Shift-Tab have no default focus behavior outside panes. When a focused control is removed, focus falls back to the first remaining control. If a scope has no focusable controls, keys can still reach its enclosing handlers.

`ScrollView` takes its viewport height from the proposed size (for example, a fixed-height frame) and clips larger content without unmounting it. Each scroll view establishes a keyboard pane. The first pane is active initially. Arrow keys navigate focusable controls only within the active pane in composition order; moving focus automatically reveals the control. At a pane boundary, arrows do not enter another pane. Tab activates the next pane and Shift-Tab activates the previous pane, without wrapping. Each mounted pane retains its own focus and vertical scroll offset when inactive. A pane without interactive controls receives focus itself; Up/Down scroll by one row and Page Up/Down scroll by one viewport, clamped to content bounds. Enter does not enter a scrolling mode. When no pane is present, the previous screen-wide focus behavior applies.

Conditional navigation activates only the mounted screen. Opening a new screen focuses its first control; returning to a screen restores its prior control when still mounted, otherwise its first control.

A `.sheet` establishes a modal focus scope. Its content replaces the active inline frame while the underlying view remains mounted and retains its timeline deadlines. Presentation remembers the underlying focus and activates the sheet's first control. While presented, keys cannot reach the underlying screen, even when a handler returns `.ignored`. Dismissal restores the remembered control if it remains mounted, otherwise focus falls back to the active screen's first control. Explicit `@FocusState` and `.focused(...)` are for programmatic focus changes when automatic focus behavior is insufficient. A Boolean binding identifies a single focus target; an optional hashable value identifies one of several targets with `.focused(_:equals:)`. Bindings follow automatic focus traversal. Focusing a container restores its remembered focusable descendant when available, otherwise its first descendant. Programmatic focus can reach controls outside the active scroll pane. Setting a binding to `false` or `nil` removes focus until another target is requested.

## Text-field input

A focused text field accepts input immediately. It consumes text and caret keys before screen or application shortcuts. Losing focus hides its caret; regaining focus places the insertion point at the end of the current text. Editing does not require a separate public state or activation key. Tab and Shift-Tab are not editing keys: they route through enclosing handlers and switch panes when present, preserving each pane's remembered focus and scroll position. At pane boundaries focus does not wrap. Outside panes these keys have no default focus behavior.

Enter invokes the nearest enclosing `.onSubmit` action. Submission retains the text and does not implicitly move focus; the action can request another target. Escape routes to enclosing handlers, allowing the screen to choose whether to move focus, dismiss a sheet, or navigate back. Cancelling or reverting text is a separate action.

| Key             | Focused interactive row                         | Focused text field                           |
| --------------- | ----------------------------------------------- | -------------------------------------------- |
| Tab / Shift-Tab | Switch panes when present                       | Switch panes when present                    |
| Arrow keys      | Move focus within active pane unless handled    | Edit or move caret as supported by the field |
| Enter           | Activate focused row if its handler consumes it | Invoke the nearest submit action             |
| Escape          | Route to enclosing handlers                     | Route to enclosing handlers                  |
| Page Up/Down    | Route to enclosing handlers                     | Remain in the field                          |
| Printable keys  | Route to enclosing handlers                     | Insert text; do not invoke shortcuts         |

Ctrl-C remains an application-owned orderly shutdown exception in every mode.

## Key routing

The application handles reserved lifecycle keys first. Other keys are routed within the topmost modal scope, or the active screen when no modal is present. A focused text field consumes its editing keys. Otherwise the focused control receives the key first, followed by enclosing view handlers when a handler returns `.ignored`, then application-level handlers if still unhandled. `.handled` stops propagation. Returning `.ignored` never crosses a modal boundary.

`.onKeyPress` is scoped to its view. A parent can provide screen-level shortcuts for keys ignored by its focused descendants. A focused text field consumes printable characters and navigation keys, including characters that would otherwise trigger shortcuts. Application-level shortcuts are not a substitute for focus-scoped interaction.

The terminal host alone positions and shows the hardware cursor at the editing caret. It hides the cursor when no text field is focused and restores inherited terminal settings and cursor visibility during shutdown. Views supply a caret position relative to their laid-out bounds; they do not emit terminal escape sequences. Presentation uses terminal cells, so the caret's column is measured in display cells rather than string indices.

The runtime remains event-driven: input, state writes, and modal transitions request coalesced presentation without polling. Unrelated timeline deadlines remain unchanged by those updates.
