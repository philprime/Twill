# Architecture

Twill is an event-driven terminal UI framework built around Swift Concurrency. It separates declarative view descriptions from their mounted runtime state and terminal presentation.

This document describes the implementation that exists today. It is a small foundation, not a complete SwiftUI implementation or a full-screen terminal renderer.

## Core principles

- Keep UI work serialized on `MainActor`.
- Suspend when no work is pending. Static content does not start a refresh timer.
- Preserve concrete view types in declarative composition.
- Retain identity, cached content, and scheduling state in mounted nodes.
- Share presentation scheduling across the view tree rather than creating a task or timer per view.
- Keep terminal ownership and cleanup explicit.

## Application and ownership

An application receives its root view through its initializer:

```swift
let application = Application(rootView: ClockView())
try await application.run()
```

The root is fixed for the application's lifetime. Constructing the application does not evaluate its root body or write output. Mounting begins inside `run()`, after terminal setup succeeds. `EmptyView` supplies an explicit non-presenting root for event-only applications.

```text
Application
├── TerminalSession       Saves and restores terminal input modes
├── KeyboardEventSource   Decodes input and manages Escape deadlines
│   └── InputSource       Borrows and reads an input descriptor
├── RunLoop               Schedules timer callbacks
└── ViewHost              Owns mounted presentation and its next wake-up
    ├── ViewRenderer tree Retains identity, cached content, and deadlines
    └── TerminalOutput    Writes presentation buffers
```

Replaceable collaborators are constructor-injected. Concrete defaults are chosen at composition boundaries, and descriptors remain owned by their callers.

`Application` owns lifecycle and application-level keyboard policy, including Ctrl-C shutdown. `ViewHost` owns presentation. Views themselves neither write to the terminal nor register timers.

## Execution and input

`Application.run()` owns two structured child tasks: one consumes keyboard input and one runs the timer scheduler. Their UI-facing work executes on `MainActor`.

```text
Descriptor readiness
→ Dispatch read queue
→ asynchronous byte stream
→ KeyboardEventSource on MainActor
→ Application key policy and handler
```

The reader drains available bytes in nonblocking mode. Its byte stream is lossless and unbounded, not backpressured. Dropping arbitrary chunks would corrupt UTF-8 or escape sequences, so the consumer must keep up with input.

`KeyboardEventSource` owns the parser and Escape disambiguation deadlines. It delivers keys synchronously on the UI actor. There is no forwarding task or task per key.

The type named `RunLoop` currently schedules timers. It is not Foundation's `RunLoop`, a `CFRunLoop` clone, or a central queue for all application events. Keyboard events do not pass through its queue. Actor isolation provides serialization, while presentation scheduling is handled separately by the view host.

## Strongly typed view descriptions

A custom `View` describes its content through its associated `Body` type. Primitive views such as `Text`, `EmptyView`, `TimelineView`, and `HStack` provide internal descriptions directly instead of evaluating a body.

Composition preserves concrete types:

- `ViewList<each Content>` stores a heterogeneous tuple using Swift parameter packs.
- `HStack<Content>` stores its concrete content type.
- `ConditionalContent<First, Second>` stores one of two typed branches.
- `ViewBuilder` assembles these values, including empty and conditional content.

For example, a stack containing text and a timeline has a type of this form:

```swift
HStack<ViewList<Text, TimelineView<Text>>>
```

Callers normally let the compiler infer that type:

```swift
HStack {
    Text("Time:")
    TimelineView(.periodic(from: .now, by: 0.05)) { context in
        Text(context.date.formatted(
            .dateTime.hour().minute().second().secondFraction(.fractional(3))
        ))
    }
}
```

Type erasure is used at the hosting and mounted-runtime boundaries. Internal `ViewDescription` values describe text, bodies, groups, branches, and timelines. Their heterogeneous child storage lets the runtime traverse different concrete view types without making the entire application generic over its root.

## Mounted identity and reconciliation

View values are descriptions. `ViewRenderer` instances are persistent mounted nodes.

Each node retains its concrete view type, children, cached text fragments, and earliest pending deadline. A timeline node additionally retains its schedule, current context date, and own deadline.

When a parent produces new child descriptions, reconciliation matches children by structural position and concrete type. Matching nodes receive updated inputs while keeping compatible runtime state. A type change replaces the node. Switching conditional branches mounts fresh branch content, even when both branches contain the same concrete view types.

An absent optional branch still occupies its structural position, so later siblings do not shift identity. Removed nodes are released, and their deadlines disappear from the aggregate schedule. There are no separate per-node operating-system timers to tear down.

A generic composition type is itself part of identity. Changing that type can replace a subtree. Explicit IDs and keyed dynamic collections are not implemented yet.

## Timeline scheduling

`TimelineView` evaluates its content initially and then according to its periodic schedule. Schedules are anchored to their start dates. Missed entries are skipped instead of producing a burst of catch-up renders.

The mounted tree caches each subtree's earliest deadline. The host schedules one one-shot presentation timer for the root's earliest deadline. Other application timers and keyboard Escape deadlines can coexist in the run loop.

When the presentation timer fires:

1. Refresh subtrees whose deadlines are due.
2. Re-evaluate due timeline content and reconcile its children.
3. Combine updated and cached content into the root presentation.
4. Write the result only if the composed text changed.
5. Arm the next earliest deadline, or remain idle if none exists.

For independent 50 ms and 1-second timelines:

| Time          | Evaluation                                            |
| ------------- | ----------------------------------------------------- |
| Initial mount | Both timelines and their static content               |
| 50 ms         | Fast timeline, with slow content reused               |
| 100 ms        | Fast timeline, with slow content reused               |
| 1 second      | Both timelines, followed by one combined presentation |

These are requested deadlines, not hard real-time guarantees. No timeline nodes means no presentation timer. A timeline that returns unchanged text still requests periodic evaluation, but unchanged output is not written again.

Parent updates are a separate reason to evaluate child content. A child timeline can receive new parent inputs before its deadline while retaining its current context date. Equal schedule values preserve its timing. Changing the start date or interval reconfigures it.

Consequently, reconstructing `.periodic(from: .now, ...)` during every parent update changes the schedule. Use a stable start date when the phase should survive those updates.

## Presentation

`ViewHost` owns a single-line presenter. It obtains text from the mounted tree, replaces control characters in text with spaces, and writes a carriage return, an erase-line sequence, and the new content as one presentation buffer. Text cannot inject ANSI commands through its content.

`HStack` joins child text with spaces. Transparent lists and conditional branches forward their fragments without introducing their own spacing. `EmptyView` contributes no presentation, which is distinct from an empty `Text` line.

The output baseline advances only after a successful write. Removing the last visible content clears the previous line. Shutdown emits a newline if presentation used the line.

This is not cell-buffer rendering or damage tracking. Inherited terminal output processing is currently preserved. Output writes are synchronous on the UI actor, so a slow output destination can delay UI work.

## Shutdown and failures

Stop requests, keyboard EOF, caller cancellation, and runtime errors end the application session.

Shutdown cancels the pending presentation timer, releases the mounted tree, requests reader cancellation, and stops timer processing. Structured task ownership ensures input cleanup completes before terminal input settings are restored. The reader restores inherited descriptor flags without closing the borrowed descriptor.

Initial presentation failures throw from `run()`. Later output failures originate in timer callbacks, so the application records the error, initiates shutdown, and reports it after cleanup. The task group also observes input failures that finish after timer shutdown.

Terminal restoration is best-effort on orderly shutdown. Crash recovery and fatal-signal cleanup are not implemented. Raw-mode Ctrl-C is handled as a keyboard event, not through a process signal handler.
