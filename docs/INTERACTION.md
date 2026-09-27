# Interaction model

Twill routes keyboard input through mounted views on the UI actor. Views declare focusable controls and key handlers. The runtime owns focus traversal, modal scopes, and terminal cursor presentation. [State and identity](STATE.md) defines how mutations retain values and trigger presentation.

## Focus, selection, and cursor

Focus identifies the control that receives keyboard input. Selection identifies an active item _within_ a control. Selection can remain visible when that control loses focus. Neither concept is the terminal hardware cursor. Interactive rows opt in with `.focusable()` individually; static headers and layout containers do not become focus targets. `Button` and `TextField` are focusable by default.

The first focusable control on a newly mounted screen receives initial focus. ArrowDown and ArrowRight move to the next focusable control in mounted composition order; ArrowUp and ArrowLeft move to the previous one. This is not spatial navigation, so a horizontal move may reach the first control of the next row. Static content is skipped. Tab and Shift-Tab have no default focus behavior. When a focused control is removed, focus falls back to the first remaining control. If a scope has no focusable controls, keys can still reach its enclosing handlers.

Conditional navigation activates only the mounted screen. Opening a new screen focuses its first control; returning to a screen restores its prior control when still mounted, otherwise its first control.

A `.sheet` establishes a modal focus scope. Presentation remembers the underlying focus and activates the sheet's first control. While presented, keys cannot reach the underlying screen, even when a handler returns `.ignored`. Dismissal restores the remembered control if it remains mounted, otherwise focus falls back to the active screen's first control. Explicit `@FocusState` and `.focused(...)` are for programmatic focus changes when automatic focus behavior is insufficient.

## Text-field modes

A focused text field starts in **navigation mode**. Enter activates **editing mode**. Editing consumes text and caret keys before screen or application shortcuts. Enter or Escape ends editing, retains the current text, and keeps focus on the field. Escape does not also dismiss a sheet or navigate back. Cancelling or reverting text is a separate action.

| Key             | Focused interactive row                         | Focused text field, navigation mode | Text field, editing mode                     |
| --------------- | ----------------------------------------------- | ----------------------------------- | -------------------------------------------- |
| Tab / Shift-Tab | No default action                               | No default action                   | Remain in the field                          |
| Arrow keys      | Move focus in mounted order unless handled      | Move focus in mounted order         | Edit or move caret as supported by the field |
| Enter           | Activate focused row if its handler consumes it | Begin editing                       | End editing, retaining text                  |
| Escape          | Route to enclosing handlers                     | Route to enclosing handlers         | End editing; consume the key                 |
| Printable keys  | Route to enclosing handlers                     | Route to enclosing handlers         | Insert text; do not invoke shortcuts         |

Ctrl-C remains an application-owned orderly shutdown exception in every mode.

## Key routing

The application handles reserved lifecycle keys first. Other keys are routed within the topmost modal scope, or the active screen when no modal is present. An editing control consumes its editing keys. Otherwise the focused control receives the key first, followed by enclosing view handlers when a handler returns `.ignored`, then application-level handlers if still unhandled. `.handled` stops propagation. Returning `.ignored` never crosses a modal boundary.

`.onKeyPress` is scoped to its view. A parent can provide screen-level shortcuts for keys ignored by its focused descendants. A text field in editing mode consumes printable characters, including characters that would otherwise trigger shortcuts. Application-level shortcuts are not a substitute for focus-scoped interaction.

The terminal host alone positions and shows the hardware cursor at the editing caret. It hides the cursor outside editing mode and restores inherited terminal settings and cursor visibility during shutdown. Views supply a caret position relative to their laid-out bounds; they do not emit terminal escape sequences. Presentation uses terminal cells, so the caret's column is measured in display cells rather than string indices.

The runtime remains event-driven: input, state writes, and modal transitions request coalesced presentation without polling. Unrelated timeline deadlines remain unchanged by those updates.
