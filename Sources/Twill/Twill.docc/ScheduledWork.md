# Scheduled and Asynchronous Work

Update time-dependent views and attach asynchronous work to mounted identity.

## Overview

Twill remains idle when there is no input, state change, or scheduled deadline. Static views do not need a refresh timer. Use ``TimelineView`` for time-dependent descriptions, the interval form of ``Canvas`` for animated drawing, and `.task` for asynchronous work owned by a view.

## Describe a Timeline

A periodic schedule is anchored to a start date with a positive, finite interval in seconds:

```swift
import Foundation
import Twill

struct ClockView: View {
    private let start = Date()

    var body: some View {
        TimelineView(.periodic(from: start, by: 1)) { context in
            Text(context.date.formatted(date: .omitted, time: .standard))
        }
    }
}
```

Keep the schedule's start stable across parent updates when the schedule should continue unchanged. Constructing a fresh start date in `body` changes the schedule rather than merely refreshing its content.

Each mounted timeline retains its own deadline. A parent update does not reset an unchanged child schedule. Due work is coalesced into a presentation, and missed entries are skipped instead of accumulating catch-up renders. Removing a timeline removes its pending updates.

An inactive tab retains its mounted tasks and timeline schedules. A collapsed disclosure subtree is unmounted. Put work in the owner whose lifetime matches the operation you intend.

## Animate a Canvas

Use `Canvas(interval:render:)` when the drawing itself depends on time. Read `context.date` in the rendering closure rather than creating a timer there. The interval requests scheduled updates, not synchronization with a display refresh signal.

``ProgressView`` with a nil value schedules spinner updates. A determinate progress bar is static until its input changes. ``TerminalProgress`` is separate: it controls the terminal emulator's native indicator rather than occupying layout cells.

## Attach an Asynchronous Action

The `.task` modifier starts a nonthrowing asynchronous action when its view mounts. Update state from the action to show a result:

```swift
struct StatusView: View {
    @State private var status = "Loading"

    var body: some View {
        Text(status)
            .task {
                // Replace this operation with cancellation-aware data loading.
                status = "Ready"
            }
    }
}
```

Parent reevaluation does not restart a task when mounted identity remains unchanged. Removing or replacing the view cancels its task. Remounting starts a new task. Handle operation errors within the action, for example with `do` and `catch`, and present an error through state.

Cancellation is cooperative. Check cancellation or await cancellation-aware operations in long-running work. During shutdown, Twill cancels and joins owned view tasks before restoring terminal resources. An action that does not finish after cancellation can delay shutdown.
