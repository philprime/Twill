# Architecture

Twill is an event-driven terminal UI framework built around Swift Concurrency. It separates declarative view descriptions from their mounted runtime state and terminal presentation.

[State and identity](STATE.md) defines mounted state ownership and reconciliation. The [interaction model](INTERACTION.md) defines focus, text editing, and modal key routing. The [run loop](RUN_LOOP.md) defines source readiness, logical timer delivery, and scheduler lifecycle.

## Core principles

- Keep UI work serialized on `MainActor`.
- Suspend when no work is pending. Static content does not start a refresh timer.
- Preserve concrete view types in declarative composition.
- Retain identity, cached content, and scheduling state in mounted nodes.
- Share presentation scheduling across the view tree rather than creating a task or timer per view.
- Keep terminal ownership and cleanup explicit.

## Application and ownership

An application receives its root view through its initializer. The root is fixed for the application's lifetime. Constructing the application does not evaluate its root body or write output. Mounting begins inside `run()`, after terminal setup succeeds. `EmptyView` supplies an explicit non-presenting root for event-only applications.

```text
Application
├── TerminalSession       Saves and restores terminal input modes
├── KeyboardEventSource   Decodes input and manages Escape deadlines
│   └── InputSource       Borrows and reads an input descriptor
├── RunLoop               Delivers signaled callbacks and timer deadlines
└── ViewHost              Owns mounted presentation and its next wake-up
    ├── ViewRenderer tree Retains identity, state, content, and deadlines
    ├── Focus routing     Tracks eligible controls and modal scopes
    └── TerminalOutput    Writes presentation buffers
```

Replaceable collaborators are constructor-injected. Concrete defaults are chosen at composition boundaries, and descriptors remain owned by their callers.

`Application` owns lifecycle and application-level keyboard policy, including Ctrl-C shutdown. `ViewHost` owns presentation. Views themselves neither write to the terminal nor register timers.

## Execution and input

`Application.run()` owns three structured child tasks: one consumes keyboard input, one consumes viewport changes, and one runs the callback and timer scheduler. Their UI-facing work executes on `MainActor`.

```text
Descriptor readiness
→ Dispatch read queue
→ asynchronous byte stream
→ KeyboardEventSource on MainActor
→ Application lifecycle policy
→ Modal scope and focused control
→ Enclosing view and application handlers
```

The reader drains available bytes in nonblocking mode. Its byte stream is lossless and unbounded, not backpressured. Dropping arbitrary chunks would corrupt UTF-8 or escape sequences, so the consumer must keep up with input.

`KeyboardEventSource` owns the parser and Escape disambiguation deadlines. It delivers keys synchronously on the UI actor. There is no forwarding task or task per key.

`RunLoop` delivers signaled callbacks and logical timer deadlines. Keyboard and viewport events currently use independent consumers, so `MainActor` serialization does not establish a global FIFO across those producers. See the [run-loop contract](RUN_LOOP.md) for registration, readiness, timer, ordering, and shutdown semantics.

## Strongly typed view descriptions

A custom `View` describes content through its associated `Body` type. Primitive views provide internal descriptions directly rather than evaluating a body. Result-builder composition retains concrete child types using Swift generics and parameter packs, so public view storage does not require type erasure.

Hosting and mounted-runtime boundaries erase view types for heterogeneous traversal. Internal descriptions separate view evaluation from layout and drawing. Keyed dynamic content retains identity by element ID; ordinary composition uses structural identity. The supported set of view primitives can grow without changing these boundaries.

## Mounted identity and reconciliation

View values are descriptions. `ViewRenderer` instances are persistent mounted nodes.

Each node retains its concrete view type, children, cached presentation, owned state, and earliest pending deadline. A timeline node additionally retains its schedule, current context date, and own deadline.

When a parent produces new child descriptions, reconciliation matches children by structural position and concrete type. Matching nodes receive updated inputs while keeping compatible runtime state. A type change replaces the node. Switching conditional branches mounts fresh branch content, even when both branches contain the same concrete view types.

An absent optional branch still occupies its structural position, so later siblings do not shift identity. Removed nodes are released, and their deadlines disappear from the aggregate schedule. There are no separate per-node operating-system timers to tear down.

A generic composition type is itself part of identity. Changing that type can replace a subtree. Keyed collections reconcile children by stable element ID rather than position. State and binding lifetimes follow the [state and identity contract](STATE.md).

## Timeline scheduling

`TimelineView` evaluates its content initially and then according to its periodic schedule. Schedules are anchored to their start dates. Missed entries are skipped instead of producing a burst of catch-up renders.

The mounted tree caches each subtree's earliest deadline. The host schedules one one-shot presentation timer for the root's earliest deadline. Other application timers and keyboard Escape deadlines can coexist in the run loop.

When the presentation timer fires:

1. Refresh subtrees whose deadlines are due.
2. Re-evaluate due timeline content and reconcile its children.
3. Combine updated and cached content into the root presentation.
4. Write the result only if the composed text changed.
5. Arm the next earliest deadline, or remain idle if none exists.

Timelines with independent schedules reuse unchanged siblings. When multiple deadlines become due together, they share one presentation.

These are requested deadlines, not hard real-time guarantees. No timeline nodes means no presentation timer. A timeline that returns unchanged text still requests periodic evaluation, but unchanged output is not written again.

Parent updates are a separate reason to evaluate child content. A child timeline can receive new parent inputs before its deadline while retaining its current context date. Equal schedule values preserve its timing. Changing the start date or interval reconfigures it.

Consequently, reconstructing `.periodic(from: .now, ...)` during every parent update changes the schedule. Use a stable start date when the phase should survive those updates.

## Presentation

`ViewHost` measures and draws mounted content into a terminal-cell grid. Text control characters are rendered safely rather than emitted as terminal commands. Horizontal and vertical stacks place children at integer cell coordinates; transparent groups and conditionals do not add spacing. Wide graphemes occupy a leading cell and continuation cell so clipping and updates never render half a character.

The terminal host encodes changed cells, batches output, and advances its diff baseline only after a successful write. Views cannot write terminal output. The host registers one presentation source for its lifetime. State changes and keyboard-driven mutations signal that source, and repeated signals coalesce until delivery. A due timeline render consumes pending presentation readiness in the same frame. Readiness is cleared before rendering so a state change during rendering requests a later frame rather than being lost.

Resize events keep only the newest unread size and redraw cached content directly. They do not reevaluate view bodies or disturb timeline deadlines. Static trees remain idle after presentation.

For multi-row inline frames, the host reserves space below the shell's current line and returns its hidden cursor to the frame's top-left anchor between writes. It clears removed rows and redraws the frame after growing its footprint. Shutdown advances below the last row. The host does not enter an alternate screen or claim unrelated shell output.

The host also owns the hardware cursor. It places and shows the cursor at a focused text field's editing caret and hides it in navigation mode. Modal presentation and focus changes do not expose cursor escapes to view bodies. Output writes remain serialized with UI presentation.

## Shutdown and failures

Stop requests, keyboard EOF, caller cancellation, and runtime errors end the application session.

Shutdown removes the presentation source, cancels the pending timeline timer, releases the mounted tree, requests reader cancellation, and stops callback and timer processing. Structured task ownership ensures input cleanup completes before terminal input settings are restored. The reader restores inherited descriptor flags without closing the borrowed descriptor.

Initial presentation failures throw from `run()`. Later output failures can originate in source or timer callbacks, so the application records the error, initiates shutdown, and reports it after cleanup. The task group also observes input failures that finish after scheduler shutdown.

Terminal restoration is best-effort on orderly shutdown. Crash recovery and fatal-signal cleanup are not implemented. Raw-mode Ctrl-C is handled as a keyboard event, not through a process signal handler.
