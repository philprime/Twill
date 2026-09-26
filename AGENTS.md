# Agent Instructions

## Architecture

- Prefer protocol-oriented boundaries for replaceable collaborators while keeping leaf implementations concrete.
- Use protocol extensions for shared default behavior where appropriate.
- Use constructor injection. Choose concrete defaults at composition boundaries.
- Use protocols for replaceable collaborators in debug builds and alias them to concrete implementations in release builds, as illustrated below.

```swift
#if DEBUG
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
- Keep platform-specific terminal behavior behind cross-platform boundaries.
- Make executor boundaries explicit. Mark off-actor Dispatch callbacks `@Sendable` and enqueue work for the UI actor instead of mutating application state from worker queues.

## Code Conventions

- Keep distinct responsibilities in separate files, including public event types and their parsers.
- Prefer Swift enums and named cases at public API boundaries. Convert to POSIX values only at the system-call boundary.
- Name byte ranges, protocol values, masks, and timing constants. Use platform constants for standard file descriptors.
- Document why code is needed, especially ownership, cleanup ordering, platform differences, and intentional limitations. Do not merely restate operations.

## Workflow

- For behavior changes and bug fixes, add a focused failing test before changing production code.
- Structure tests with explicit `// -- Arrange --`, `// -- Act --`, and `// -- Assert --` sections.
- Integration tests must exercise framework instances directly with real pipes or pseudo-terminals. Inject resources instead of replacing the test runner's global stdin.
- Keep examples as manual playgrounds, not integration-test fixtures or automated verification dependencies.
- Test terminal behavior with nondefault inherited settings and verify resource and mode restoration on shutdown, cancellation, and error paths.
- Use Just for development commands. Run standalone example packages with `just example <Name>`.
- Use `--linux` for Linux verification. On Linux, add `--container` only to select the Docker toolchain. See `docs/DEVELOPMENT.md`.
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

Run `just format` after Swift edits, then rerun `just analyze` before handing changes back. Verify debug and release configurations when changing conditional abstractions. For cross-platform runtime changes, also run the relevant checks with `--linux`.
