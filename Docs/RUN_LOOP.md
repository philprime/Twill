# Run loop

Twill's run loop coordinates manually signaled readiness and logical timer deadlines on the UI actor. It suspends when no work is ready and no deadline is due.

The run loop is implemented with Swift Concurrency and Dispatch. It is not Foundation's `RunLoop` or a `CFRunLoop` wrapper. The architecture follows the same separation between registered sources, readiness signals, and timer deadlines without adopting Core Foundation's thread model or blocking execution APIs.

## Responsibilities

The run loop owns:

- Source and timer registration lifecycles.
- Coalesced source readiness.
- Logical timer deadlines.
- Delivery of source and timer actions on `MainActor`.
- Suppression of stale and post-shutdown callbacks.
- One physical timer backend for the earliest logical deadline.

The run loop does not own:

- Payloads associated with readiness.
- File descriptors or terminal resources.
- Keyboard parsing or interaction routing.
- Mounted view state or rendered output.
- Chronological ordering across independent operating-system producers.

Payload ownership remains with the collaborator that understands its buffering requirements. A lossless producer retains every unread value. A latest-value producer may replace unread state. The generic run loop only records that work is ready.

## Sources

A `RunLoopSource` describes synchronous work to perform on `MainActor`. Registering a source returns a `RunLoopSourceRegistration`, which is a thread-safe, `Sendable` signaling capability.

```text
producer stores payload
→ producer signals registration
→ run loop wakes
→ source action consumes payload on MainActor
```

The signal contains no payload and does not preserve a count. Repeated signals coalesce while the registration is pending. Coalescing is safe only when the source owner retains all information needed by the eventual action.

A source added more than once during the same registration lifecycle retains one registration. Removing and adding that source again creates a new lifecycle.

### Executor boundary

`RunLoopSourceRegistration.signal()` may be called from an off-actor Dispatch callback. It updates synchronized readiness and wakes the run loop without creating a task per signal.

The source action itself remains isolated to `MainActor`. Off-actor producers must not mutate application, interaction, or mounted presentation state directly.

Code already isolated to `MainActor` may signal through the run loop using the source object. Both paths use the same synchronized registration state.

### Readiness lifecycle

A registration tracks separate lifecycle and readiness generations. The run loop validates both before invoking an action.

Readiness is cleared before the action begins. A signal raised by the action therefore schedules a distinct later delivery rather than being absorbed into the active callback.

Pending readiness can be consumed without invoking the source. This allows another path that performs the same work to suppress a redundant queued callback. A later signal remains deliverable.

Removing a source deactivates its registration. Signals through an inactive registration are no-ops. Queued notifications are ignored after:

- Readiness was consumed.
- The source was removed.
- The source was removed and registered again.
- The run loop stopped.

These checks permit producer callbacks already in flight to finish safely after shutdown begins.

## Timers

A `Timer` is a logical deadline registered with the run loop. Registering a timer does not create a dedicated `DispatchSourceTimer`.

The run loop retains each active timer's:

- Identity.
- Monotonic deadline.
- Repeat interval when applicable.
- Registration order.
- Cancellation state.
- `MainActor` action.

Interval-based deadlines are anchored when their registration event is processed. An explicit deadline retains the date computed by its owner.

### Physical wake-up

`DefaultRunLoop` owns one Dispatch timer backend. The backend is armed for the earliest logical deadline and is rescheduled when that deadline changes.

```text
logical deadlines
→ select earliest deadline
→ arm one Dispatch timer source
→ enqueue generation-tagged wake-up
→ deliver all timers due at the controlled date
```

The backend callback performs no application work. It only wakes the run loop. A generation check rejects a callback from an earlier arm after cancellation or rescheduling.

When no logical timer remains, the physical backend is disarmed. The run-loop task remains suspended until a source signal, timer registration, or stop request arrives.

### Delivery

A physical wake-up captures one controlled iteration date. Every timer due at that date is ordered by deadline and then registration order.

A one-shot timer is removed before its action runs. This makes cancellation and re-registration from callbacks unambiguous.

A repeating timer advances from its previous scheduled deadline rather than callback completion. If several periods were missed, it runs once and advances to the first deadline after the iteration date. Missed periods do not create a catch-up burst.

Timer deadlines are scheduling requests rather than real-time guarantees. Actor contention and operating-system scheduling can delay delivery.

### Cancellation

Cancellation is permanent for a timer instance. It suppresses:

- A registration event that has not been processed.
- A pending logical deadline.
- Later repetitions.
- A stale physical wake-up that no longer represents the earliest deadline.

A callback may cancel another due timer before its turn. The run loop revalidates each timer immediately before delivery.

## Event delivery

Run-loop actions execute serially on `MainActor`. Serialization prevents concurrent UI mutation but does not establish a global FIFO across independent producers.

The internal event stream preserves the order in which it observes run-loop events. It cannot reconstruct the chronological order of events produced concurrently by different Dispatch queues, operating-system signals, and actor tasks.

The run loop guarantees:

- Serial source and timer actions.
- Coalesced readiness for each source registration.
- Deadline and registration ordering within one due timer set.
- No action after its registration is removed.
- No action after shutdown is requested.

The run loop does not guarantee:

- Chronological ordering across independent producers.
- A delivery for every source signal.
- That every wake-up causes terminal output.
- Hard real-time timer delivery.

Code must not infer stronger ordering merely because all actions eventually execute on `MainActor`.

## Presentation boundary

Presentation is a run-loop client. The host registers one source for invalidation and one logical timer for the mounted tree's aggregate deadline. The run loop provides readiness and physical wake-ups without owning mounted state, deadline aggregation, rendering, or terminal output.

Mounted scheduling and presentation semantics are defined in the [architecture contract](ARCHITECTURE.md).

## Lifecycle

A run loop is single-use. `run()` returns after `stop()` or task cancellation.

Stopping the run loop:

1. Marks the loop stopped.
2. Deactivates all source registrations.
3. Releases logical timer registrations.
4. Stops the physical timer backend.
5. Finishes the internal event stream.
6. Discards buffered events without invoking actions.

External producers own their own cancellation and queue barriers. Stopping the run loop only makes their signaling capabilities inert. Application shutdown must still join those producers before restoring borrowed terminal resources.

The physical backend also owns a cancellation guard for a run loop that is constructed but never entered.

## Errors

Source and timer actions are synchronous and nonthrowing. A collaborator that encounters an asynchronous error records the original error, requests application shutdown, and reports it after owned resources have finished cleanup.

Errors during initial setup or initial presentation may throw directly before the run loop begins waiting.

This preserves one cleanup path and prevents callback failures from bypassing terminal restoration.

## Modes

Twill does not currently implement run-loop modes. Focus scopes and modal key routing are interaction concerns and do not filter scheduler registrations.

If mode-based eligibility is added, it must preserve the existing ownership boundaries:

- Sources and logical timers declare scheduler eligibility.
- Mounted timeline eligibility is resolved before the host aggregates deadlines.
- Payload buffering remains owned by producers.
- Changing modes does not create nested blocking run-loop activations.

A host timer alone cannot distinguish modes of individual mounted deadlines. Eligibility therefore belongs to mounted scheduling as well as run-loop registration.

## Testing contract

Scheduling tests use controlled monotonic dates and manual physical wake delivery. They do not rely on wall-clock sleeps for deadline semantics.

Tests cover:

- Source signal coalescing and follow-up delivery.
- Off-actor signaling.
- Consumption, removal, re-registration, and shutdown suppression.
- One-shot, repeating, cancelled, and equal-deadline timers.
- Rejection of stale physical wake-ups.
- Shared physical wake-up behavior.
- Independent mounted deadlines and unchanged sibling schedules.
- Static content remaining unscheduled.

Integration tests exercise real descriptors, Dispatch sources, pipes, and pseudo-terminals. Test doubles replace scheduler boundaries only in unit tests compiled with `TESTING`.
