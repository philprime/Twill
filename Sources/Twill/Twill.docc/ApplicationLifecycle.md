# Application Lifecycle

Own one terminal session and await its cleanup before returning to the shell.

## Overview

``Application`` coordinates the view host, keyboard input, viewport changes, scheduling, and terminal session. Construct it on the main actor with a root view, configure its options, then await ``Application/run()``.

The default collaborators use standard terminal resources. Constructor injection supports applications that supply their own descriptors or runtime resources. ``FileDescriptor`` represents a borrowed descriptor, not ownership of its lifetime. The caller remains responsible for keeping injected resources valid while the application uses them.

## Run and Stop

Set presentation options before running. Fullscreen mode uses the terminal viewport, while inline mode presents in the primary screen. Changing these options during a session does not reconfigure its presentation.

Call ``Application/stop()`` to request shutdown. Enabled exit keys also request orderly shutdown before view or application handlers receive them. Cancellation of the running task follows cleanup as well. Await `run()` after requesting a stop, because requesting shutdown is not the same as finishing cleanup.

Twill stops input and scheduled presentation, cancels owned tasks, and joins asynchronous work before restoring terminal settings. Errors propagate after cleanup. Use this lifecycle instead of terminating the process from a control action, which would bypass orderly restoration.

## Keep Terminal Output Centralized

Do not print directly to the terminal while the application owns presentation. View descriptions, state updates, and drawing closures supply content to the host. The host owns escape-sequence output, cursor positioning, and frame presentation.

The hardware cursor is used for an editing caret, not keyboard focus. The terminal session restores borrowed modes and cursor visibility at shutdown.

## Integrate Event Sources

The ``RunLoop`` coordinates logical timers and explicitly signaled sources without polling or depending on Foundation's run loop. ``RunLoopSource`` describes UI-actor work, and ``RunLoopSourceRegistration`` supplies a signaling capability for one registration. Keep off-actor callbacks separate from UI mutation and deliver work through the runtime boundary.

Most applications should use ``TimelineView`` or `.task` rather than coordinating low-level timers themselves. Use runtime integration APIs when adapting an external source or supplying terminal resources, not to force manual view invalidation. State changes already request presentation.
