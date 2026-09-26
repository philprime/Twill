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

## Workflow

- For behavior changes and bug fixes, add a focused failing test before changing production code.
- Structure tests with explicit `// -- Arrange --`, `// -- Act --`, and `// -- Assert --` sections.
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
