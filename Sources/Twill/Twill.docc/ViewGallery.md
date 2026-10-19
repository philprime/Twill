# View gallery

Explore terminal views through snapshots produced by real Twill renderer instances.

## Overview

These previews use a fixed date and a dark documentation theme. Terminal fonts and ANSI
palettes vary. Reverse video indicates focus, and an underline represents the terminal caret.
Each preview uses the content's natural size unless its description specifies a viewport.
Images show one state, rather than interactive behavior. Tab and Shift-Tab move between controls.
Up and Down navigate according to the focused control's keyboard behavior.

The gallery includes layout and composition types, controls, and modifier wrappers. Wrappers that
add behavior without visual decoration show their underlying content. EmptyView is intentionally blank.

## Text

``Text``

Text preserves line breaks and wraps words within terminal-cell width.

![Text terminal preview](preview-Text.svg)

## EmptyView

``EmptyView``

Intentionally blank: this view contributes no terminal cells.

![EmptyView terminal preview](preview-EmptyView.svg)

## HStack

``HStack``

Children arranged horizontally with two cells of spacing.

![HStack terminal preview](preview-HStack.svg)

## VStack

``VStack``

Children arranged vertically and aligned to the leading edge.

![VStack terminal preview](preview-VStack.svg)

## Group

``Group``

Groups content without introducing its own layout; the enclosing stack arranges it.

![Group terminal preview](preview-Group.svg)

## ViewList

``ViewList``

The view builder creates this heterogeneous child list; its enclosing stack supplies layout.

![ViewList terminal preview](preview-ViewList.svg)

## ConditionalContent

``ConditionalContent``

The view builder selects the visible branch while preserving structural identity.

![ConditionalContent terminal preview](preview-ConditionalContent.svg)

## IdentifiedView

``IdentifiedView``

Explicit identity retains mounted content until its ID changes.

![IdentifiedView terminal preview](preview-IdentifiedView.svg)

## ForEach

``ForEach``

Repeats keyed content inside a vertical stack.

![ForEach terminal preview](preview-ForEach.svg)

## LazyVGrid

``LazyVGrid``

Two fixed-width columns. The current runtime mounts all children when evaluated.

![LazyVGrid terminal preview](preview-LazyVGrid.svg)

## GroupBox

``GroupBox``

A titled rounded border around padded content.

![GroupBox terminal preview](preview-GroupBox.svg)

## Canvas

``Canvas``

Cell drawing in an explicit eight-by-three viewport.

![Canvas terminal preview](preview-Canvas.svg)

## ImageView

``ImageView``

A 32-by-16 pixel checkerboard PNG placement, scaled to terminal cells. Live output requires a Kitty graphics compatible terminal such as Ghostty. This SVG embeds the renderer's PNG payload; it does not test terminal decoding or graphics-protocol support.

![ImageView terminal preview](preview-ImageView.svg)

## TimelineView

``TimelineView``

A periodic timeline captured at the fixed reference date, 100 seconds after the epoch.

![TimelineView terminal preview](preview-TimelineView.svg)

## Button

``Button``

A focused button. Enter activates it.

![Button terminal preview](preview-Button.svg)

## Toggle

``Toggle``

A checked toggle. Space switches its bound Boolean value.

![Toggle terminal preview](preview-Toggle.svg)

## TextField

``TextField``

A populated single-line field. Type to edit; arrows move the caret; Enter submits.

![TextField terminal preview](preview-TextField.svg)

## SecureField

``SecureField``

A populated password field, masked with bullets. Editing and submission use the original value.

![SecureField terminal preview](preview-SecureField.svg)

## TextEditor

``TextEditor``

A multiline editor. Enter inserts a newline; arrows move the caret; Tab moves between controls.

![TextEditor terminal preview](preview-TextEditor.svg)

## Stepper

``Stepper``

An integer adjustment control. Left and Right decrement and increment within its bounds.

![Stepper terminal preview](preview-Stepper.svg)

## Slider

``Slider``

A floating-point adjustment control. Left and Right change its value.

![Slider terminal preview](preview-Slider.svg)

## Picker

``Picker``

A horizontal choice control. Left and Right change the selected option.

![Picker terminal preview](preview-Picker.svg)

## ProgressView

``ProgressView``

Determinate progress and an indeterminate spinner, captured at a fixed date.

![ProgressView terminal preview](preview-ProgressView.svg)

## Menu

``Menu``

An open menu, including a shortcut and disabled action. Enter opens or activates; arrows navigate; Escape dismisses.

![Menu terminal preview](preview-Menu.svg)

## KeyHints

``KeyHints``

Available commands share their current titles and shortcut hints with controls.

![KeyHints terminal preview](preview-KeyHints.svg)

## DisclosureGroup

``DisclosureGroup``

An expanded section. Enter or Space on the header toggles its content.

![DisclosureGroup terminal preview](preview-DisclosureGroup.svg)

## List

``List``

Keyed rows with the first row selected. Up/Down and Home/End change selection; Enter submits.

![List terminal preview](preview-List.svg)

## Table

``Table``

Aligned column headers and selected rows. Up/Down and Home/End navigate; Enter submits.

![Table terminal preview](preview-Table.svg)

## OutlineGroup

``OutlineGroup``

An expanded tree. Up/Down navigate visible rows; Right expands or enters; Left collapses or moves to a parent.

![OutlineGroup terminal preview](preview-OutlineGroup.svg)

## TabView

``TabView``

A selected tab and its destination. Left/Right selects at the bar; Tab or Down enters content; Control-PageUp/Down switches from content.

![TabView terminal preview](preview-TabView.svg)

## Tab

``Tab``

A tab declaration shown inside its required TabView container; the selected destination is visible.

![Tab terminal preview](preview-Tab.svg)

## ScrollView

``ScrollView``

Content clipped to a two-row viewport. Up/Down scroll; Tab moves between controls.

![ScrollView terminal preview](preview-ScrollView.svg)

## ScrollViewReader

``ScrollViewReader``

Supplies a proxy for programmatic scrolling. The wrapper itself adds no visual treatment.

![ScrollViewReader terminal preview](preview-ScrollViewReader.svg)

## Form

``Form``

Sections group labeled controls, help, and validation. Arrows navigate controls; Enter submits fields.

![Form terminal preview](preview-Form.svg)

## FormSection

``FormSection``

A section heading groups related fields inside a form.

![FormSection terminal preview](preview-FormSection.svg)

## FormField

``FormField``

A label, editor, help text, and red validation message arranged in reading order.

![FormField terminal preview](preview-FormField.svg)

## BorderView

``BorderView``

The border modifier encloses content in rounded terminal glyphs.

![BorderView terminal preview](preview-BorderView.svg)

## DisabledView

``DisabledView``

Disabled controls stay visible but do not receive focus or activate.

![DisabledView terminal preview](preview-DisabledView.svg)

## TextLayoutView

``TextLayoutView``

Inherited line limits and truncation keep a terminal title within its viewport.

![TextLayoutView terminal preview](preview-TextLayoutView.svg)

## PaddingView

``PaddingView``

The padding modifier reserves one blank cell around the enclosed content.

![PaddingView terminal preview](preview-PaddingView.svg)

## FrameView

``FrameView``

The frame modifier centers content in a fixed twenty-by-three cell rectangle.

![FrameView terminal preview](preview-FrameView.svg)

## StyledView

``StyledView``

Foreground and background modifiers resolve styles into terminal cell colors.

![StyledView terminal preview](preview-StyledView.svg)

## FocusableView

``FocusableView``

A focusable text target. Reverse video indicates focus; enclosing key handlers define actions.

![FocusableView terminal preview](preview-FocusableView.svg)

## FocusedView

``FocusedView``

Associates a focus binding with a control. The binding adds no visual treatment of its own.

![FocusedView terminal preview](preview-FocusedView.svg)

## KeyboardShortcutView

``KeyboardShortcutView``

A shortcut reuses the button action without changing its label.

![KeyboardShortcutView terminal preview](preview-KeyboardShortcutView.svg)

## KeyPressView

``KeyPressView``

Attaches a key handler to a focusable target; the handler itself adds no visual treatment.

![KeyPressView terminal preview](preview-KeyPressView.svg)

## SubmitView

``SubmitView``

Attaches submission behavior to the enclosed field without changing its appearance. Enter submits.

![SubmitView terminal preview](preview-SubmitView.svg)

## TaskView

``TaskView``

Attaches a mounted asynchronous action. The empty action here leaves the underlying content unchanged.

![TaskView terminal preview](preview-TaskView.svg)

## SheetView

``SheetView``

A modal sheet over the base page. It traps keys and focus, restoring focus when dismissed.

![SheetView terminal preview](preview-SheetView.svg)
