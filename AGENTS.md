# Agent Instructions

## Architecture

- Consult [Docs/README.md](Docs/README.md) for architectural boundaries, interaction and state contracts, and development commands.
- Prefer protocol-oriented boundaries for replaceable collaborators while keeping leaf implementations concrete.
- Use protocol extensions for shared default behavior where appropriate.
- Use constructor injection. Choose concrete defaults at composition boundaries.
- Use `#if TESTING` protocols for replaceable collaborators and concrete typealiases otherwise. `just test` enables `TESTING` for both the library and tests in debug and release. Integration tests run without it, as illustrated below.

```swift
#if TESTING
@MainActor
protocol TerminalOutput: AnyObject {
    func write(_ text: String)
}

extension StandardTerminalOutput: TerminalOutput {}
#else
typealias TerminalOutput = StandardTerminalOutput
#endif

@MainActor
final class StandardTerminalOutput {
    func write(_ text: String) {
        print(text, terminator: "")
    }
}
```

- Keep the runtime event-driven and idle without polling. Do not couple it to Foundation's `RunLoop`.
- Preserve concrete types in view composition using generics and parameter packs. Erase types at hosting and mounted-runtime boundaries, not in public composition storage.
- Keep views as descriptions, identity and cached state in mounted nodes, and terminal output in the host. Do not register timers or perform output from view bodies.
- Follow [Docs/STATE.md](Docs/STATE.md) for mounted `@State`, `@Binding`, and keyed identity. State changes invalidate presentation internally; do not expose a public invalidation method.
- Follow [Docs/INTERACTION.md](Docs/INTERACTION.md) for focus and key routing. Keep selection, control focus, and the terminal caret distinct; modal scopes trap keys and restore focus. Reserve explicit focus state for programmatic changes.
- Preserve independent timeline deadlines and unchanged child schedules during parent updates. Coalesce due work into one presentation and leave static trees unscheduled.
- Join owned tasks before restoring borrowed terminal resources. Observe all child results so early completion cannot hide failures still awaiting cleanup.
- Keep platform-specific terminal behavior behind cross-platform boundaries.
- Make executor boundaries explicit. Mark off-actor Dispatch callbacks `@Sendable` and enqueue work for the UI actor instead of mutating application state from worker queues.

## Code Conventions

- Keep distinct responsibilities in separate files, including public event types and their parsers.
- Keep callback context types independent of content generics when their data does not depend on content. Nested generic context types can prevent result-builder inference.
- Prefer Swift enums and named cases at public API boundaries. Convert to POSIX values only at the system-call boundary.
- Name byte ranges, protocol values, masks, and timing constants. Use platform constants for standard file descriptors.
- Document why code is needed, especially ownership, cleanup ordering, platform differences, and intentional limitations. Do not merely restate operations.
- Write technical docs as general contracts, without referencing examples or maintaining inventories of view types. Keep state ownership and keyboard interaction in their separate documents.

## Workflow

- For behavior changes and bug fixes, add a focused failing test before changing production code.
- Structure tests with explicit `// -- Arrange --`, `// -- Act --`, and `// -- Assert --` sections.
- Test scheduling semantics with controlled dates and manual timer delivery rather than wall-clock sleeps. Cover sibling independence, parent updates, branch removal, and unchanged output.
- Integration tests must exercise framework instances directly with real pipes or pseudo-terminals. Inject resources instead of replacing the test runner's global stdin.
- Keep examples as manual playgrounds, not integration-test fixtures or automated verification dependencies. Public API prototypes may intentionally not compile; label them clearly and keep them outside package verification targets.
- Test terminal behavior with nondefault inherited settings and verify resource and mode restoration on shutdown, cancellation, and error paths.
- Use Just for development commands. Run standalone example packages with `just example <Name>`.
- Use `--linux` for Linux verification. On Linux, add `--container` only to select the Docker toolchain.
- Linux TUI workflows must run as the host UID/GID and must not create root-owned files.
- Keep changes scoped and avoid unrelated refactoring.
- Leave commits and pushes to the user.

## Verification

Run the narrowest relevant tests first, then before completion run:

```bash
just test
just test-integration
just analyze
just build
```

Run `just format` after Swift edits, then rerun `just analyze` before handing changes back. Verify debug and release configurations both with `TESTING` (`just test`) and without it (`just test-integration` and `just build`) when changing conditional abstractions. For cross-platform runtime changes, also run the relevant checks with `--linux`.
