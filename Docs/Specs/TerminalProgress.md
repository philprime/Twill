# Terminal-native progress

## Purpose and scope

Provide one application-owned controller for the terminal emulator's native indeterminate progress indicator. Independent operations can report activity without hiding another operation's indicator. This capability does not occupy layout cells or evaluate view bodies.

Environment infrastructure, determinate percentages, capability detection, rendered progress views, and crash recovery are outside this change. The controller can later be exposed through an environment without changing its ownership.

## Public contract

`Application.terminalProgress` is a stable `@MainActor` controller with no public standalone initializer. Its `state` is `.hidden` by default or `.indeterminate`. Setting state is an explicit opt-in to terminal progress reporting. Repeated assignments do not repeat output.

`withActivity` accepts a main-actor asynchronous throwing operation and returns its result, propagating its error. Each scope contributes activity until it exits, including error and cooperative cancellation exits. Effective progress is indeterminate if explicit state is indeterminate or at least one scope remains active. The state property represents the explicit request, not the aggregate. Setting hidden cannot hide active scopes.

Requests before application run are retained without output. Requests after stopping produce no output. The controller does not cancel or own user operations. Cancellation must unwind the operation before its scoped activity ends.

## Runtime boundaries

Application constructs the controller using its injected run loop and terminal session. It activates the controller after terminal setup and before mounting views. Progress writes are serialized on MainActor. Output errors enter the application's existing failure path and cause orderly shutdown.

TerminalSession encodes OSC 9;4: indeterminate is ESC ] 9;4;3 BEL and hidden is ESC ] 9;4;0 BEL. It claims cleanup before attempting an active write because writes can partially succeed. Clearing successfully releases that claim. Restore attempts a final clear if a claim remains, independently of cursor and termios restoration. No progress output occurs for applications that never request it.

The controller owns one repeating one-second logical keepalive timer only while effective progress is active. It sends the active sequence again to accommodate terminal expiry. Hidden state and stop cancel that timer. Stale timer delivery must not emit output. Idle applications remain unscheduled for progress.

Stop disables controller output and cancels its timer. Final clearing belongs to terminal restoration after owned runtime tasks have joined. Retained controllers must not retain the application through failure callbacks.

## Terminal limitations

Appearance and animation belong to the emulator. Unsupported terminals may ignore OSC 9;4. There is no reliable general query for inherited progress, so cleanup clears Twill's request rather than restoring an unknown prior value. Multiple applications sharing an output terminal can interfere with each other.

## Verification

Unit tests cover deferred activation, idempotent explicit state, active-only scheduling, manually delivered keepalives, stale delivery after hiding/stopping, nested and overlapping activity, returned values, throwing and cancellation cleanup, and reporting output failures. Session tests cover exact bytes, opt-in cleanup, partial-write failure, and idempotent restoration. Real pseudo-terminal integration tests exercise Application activation and shutdown/cancellation/error restoration with nondefault inherited terminal settings. Run the repository's formatting, analysis, unit, integration, build, Linux, and Linux sanitizer checks.
