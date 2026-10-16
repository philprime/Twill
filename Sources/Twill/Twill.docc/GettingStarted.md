# Getting Started

Create a terminal application with a stateful view and keyboard-operated controls.

## Overview

Add the Twill library product to a Swift package executable target and import ``Twill``. The executable owns an ``Application`` and awaits its ``Application/run()`` method. Use a real terminal for interactive input and presentation.

The following complete executable displays a counter. The first button receives focus automatically. Enter activates the focused button, and the arrow keys move focus between the buttons.

```swift
import Twill

struct CounterView: View {
    @State private var count = 0

    var body: some View {
        VStack {
            Text("Count: \(count)")
            Button("Increment") { count += 1 }
            Button("Reset") { count = 0 }
        }
        .padding()
        .border(.rounded, color: .cyan)
    }
}

@main
struct Counter {
    @MainActor
    static func main() async throws {
        let application = Application(rootView: CounterView())
        try await application.run()
    }
}
```

Press Control-C or Control-D to request orderly shutdown with the default options. Awaiting `run()` allows Twill to finish owned work and restore borrowed terminal settings before the executable exits.

## Choose a Presentation Mode

By default, the application occupies the full terminal viewport. Choose inline mode before calling `run()` to present within the shell's primary screen instead:

```swift
application.options.ui.mode = .inline
```

Configure lifecycle shortcuts before running as well. For example, set `application.options.exitOnControlD = false` when your application needs to handle Control-D itself.

## Build a View Hierarchy

A ``View`` value describes content. Its `body` composes other views using ``ViewBuilder``. Stacks add layout, while ``Group`` groups content without adding spacing. Modifiers such as `.padding()` and `.border(.rounded, color: .cyan)` wrap the result, so their order affects the layout.

Keep rendering declarative. Load data in asynchronous work, retain mutable values in state, and let Twill present changes. Do not write terminal escape sequences or start timers from `body`.

## Continue Learning

- Explore <doc:ViewGallery> for terminal previews.
- Read <doc:ManagingState> for persistent values and bindings.
- Read <doc:KeyboardInteraction> for focus, editing, and shortcuts.
- Read <doc:LayoutAndDrawing> for cell-based sizing and appearance.
- Read <doc:ApplicationLifecycle> for terminal ownership and cleanup.
