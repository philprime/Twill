# Twill - Terminal user interfaces in Swift

[![Test](https://github.com/philprime/Twill/actions/workflows/test.yml/badge.svg)](https://github.com/philprime/Twill/actions/workflows/test.yml)
[![Build](https://github.com/philprime/Twill/actions/workflows/build.yml/badge.svg)](https://github.com/philprime/Twill/actions/workflows/build.yml)
[![Analyze](https://github.com/philprime/Twill/actions/workflows/analyze.yml/badge.svg)](https://github.com/philprime/Twill/actions/workflows/analyze.yml)
[![License: FSL-1.1-MIT](https://img.shields.io/badge/license-FSL--1.1--MIT-blue.svg)](LICENSE.md)

> Build interactive terminal apps with declarative Swift views and an event-driven runtime that rests when there is nothing to do.

<p align="center">
    <sub>Created and maintained by <a href="https://github.com/philprime">Philip Niedertscheider</a>.</sub>
</p>

Twill is a Swift library for terminal user interfaces on macOS and Linux. Describe what should appear on screen with views, and let Twill handle keyboard input, layout, updates, and terminal output. It brings Swift Concurrency to the terminal without making your views manage a render loop.

> [!NOTE]
> Twill is in early development and the API is subject to change.

## Why Twill?

A terminal app needs more than text printed to stdout. It must turn input bytes into keys, keep track of which control has focus, lay out content in character cells, update only what changed, and restore the terminal when it exits. Twill keeps that machinery in the runtime so your views can focus on describing the interface.

If you have used SwiftUI, the view-building style will feel familiar. Compose screens from `Text`, `VStack`, and `HStack`, and use `@State` to keep values across updates to a mounted view. The [state model](docs/STATE.md) also describes `@Binding` for sharing that state with child views, but bindings are not implemented yet.

Keyboard input and timeline deadlines wake the runtime only when there is work to do, so static screens stay idle. Layout happens in terminal cells, and the host writes changed content instead of blindly redrawing everything. The application also owns terminal setup and orderly cleanup, leaving views to describe the interface rather than emit escape sequences.

## Try it

With Swift 6.4 or later and [Just](https://just.systems/) installed, clone the repository and run the Clock example from the repository root in a terminal:

```bash
just example Clock
```

Press Ctrl-C to exit. For setup instructions and Linux execution options, see [Development](docs/DEVELOPMENT.md).

The example is a small Twill app:

```swift
import Foundation
import Twill

@main
struct Clock {
    @MainActor
    static func main() async throws {
        let application = Twill.Application(rootView: ClockView())
        try await application.run()
    }
}

struct ClockView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(context.date.formatted(.dateTime.hour().minute().second()))
        }
    }
}
```

`ClockView` describes the screen. `TimelineView` requests updates on its schedule, while `Application` owns the terminal session and runs until it stops. The runnable version lives in [`Examples/Clock`](Examples/Clock).

## Explore further

- [Documentation index](docs/README.md) for a map of the project docs.
- [Architecture](docs/ARCHITECTURE.md) for view composition, scheduling, rendering, and lifecycle ownership.
- [State and identity](docs/STATE.md) for mounted state, bindings, and keyed content.
- [Interaction model](docs/INTERACTION.md) for focus, keyboard routing, and text editing.
- [Development](docs/DEVELOPMENT.md) for setup, examples, tests, and macOS/Linux workflows.

Contributions and feedback are welcome. If you want to explore the code or run the checks locally, start with the [development guide](docs/DEVELOPMENT.md).

## License

Licensed under [FSL-1.1-MIT](LICENSE.md). This is source-available software with restrictions on competing commercial uses. Each version becomes available under the MIT license on the second anniversary of its release. See the license for the full terms.
