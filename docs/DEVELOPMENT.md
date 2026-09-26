# Development

## Prerequisites

- Swift 6.4 or later for native builds and tests.
- Just and Bash for development commands.
- SwiftLint, dprint, and actionlint for quality checks.
- Homebrew for the macOS setup recipe.
- Docker with a running daemon when using Linux containers. The default image is `swift:6.4.0`.

On macOS, install Just first, then install the remaining development tools and resolve SwiftPM dependencies:

```bash
brew install just
just setup
```

On Linux, install Swift, Just, Bash, and the quality-check tools through your preferred installation methods, then run `swift package resolve`. `just setup` is Homebrew-specific.

## Development commands

Run commands from the repository root. `just` lists the available recipes.

| Command                 | Purpose                                                |
| ----------------------- | ------------------------------------------------------ |
| `just build`            | Build the Twill package in debug configuration.        |
| `just test`             | Run unit tests, excluding `TwillIntegrationTests`.     |
| `just test-integration` | Run `TwillIntegrationTests`.                           |
| `just example Clock`    | Run the standalone package in `Examples/Clock`.        |
| `just format`           | Apply Swift and dprint formatting, including examples. |
| `just format-check`     | Check formatting without changing files.               |
| `just lint`             | Run SwiftLint and actionlint.                          |
| `just analyze`          | Run lint and formatting checks.                        |
| `just clean`            | Clean the root package's SwiftPM build output.         |

## Host and container execution

`build`, `test`, `test-integration`, and `example` accept the same execution options:

- Without options, use system-installed Swift on the host.
- `--linux` selects Linux. On macOS, this requires Docker. On Linux, it uses system-installed Swift.
- `--container` forces Linux execution through Docker. On macOS, it must be combined with `--linux`, where it is redundant.
- Running or testing macOS software from Linux is not supported.

| Host  | Options               | Execution                         |
| ----- | --------------------- | --------------------------------- |
| macOS | None                  | System-installed Swift on macOS   |
| macOS | `--linux`             | Swift in a Linux Docker container |
| macOS | `--linux --container` | Swift in a Linux Docker container |
| macOS | `--container`         | Error: requires `--linux`         |
| Linux | None                  | System-installed Swift on Linux   |
| Linux | `--linux`             | System-installed Swift on Linux   |
| Linux | `--container`         | Swift in a Linux Docker container |
| Linux | `--linux --container` | Swift in a Linux Docker container |

For example:

```bash
just test
just test --linux
just test --linux --container
just build --linux -c release
just test-integration --linux
just example Clock --linux
```

Setup, formatting, linting, and cleaning always run on the host and do not accept these execution options.

### Argument forwarding

Execution options are removed before invoking SwiftPM. Other arguments are forwarded unchanged, including quoted values:

```bash
just test --filter ApplicationTests
just test --linux --filter ApplicationTests
just test -c release
just build -c release
```

Put execution options before a literal `--`. The separator and everything after it are forwarded unchanged, so example arguments named `--linux` or `--container` are not consumed by Just. The example name comes first, as in `just example Clock --linux`.

### Container configuration

Containers run as the host UID/GID with `HOME=/tmp`. The repository is mounted read-only at `/workspace`. Build output is writable at `/workspace/.build`, backed by `.build/linux-<architecture>` on the host, separate from native build output.

The default container architecture matches the host. Override it explicitly when needed:

```bash
LINUX_ARCH=amd64 just test --linux --container
LINUX_ARCH=arm64 just test --linux --container
LINUX_SWIFT_IMAGE=swift:6.4.0 just build --linux --container
```

`LINUX_ARCH` and `LINUX_SWIFT_IMAGE` affect containers only. Selecting another architecture may require Docker emulation. Native execution always uses the host architecture and installed toolchain.

Example containers allocate an interactive terminal. Build and test containers do not require one. Example builds use `.build/examples/<name>` within the selected native or container build directory rather than writing into `Examples/`.

`just clean` cleans only the root package's native SwiftPM build output. It is not a command for clearing every container or example cache.

## Verification

Run focused tests first, then the relevant full checks:

```bash
just test
just test-integration
just analyze
just build
```

After Swift edits, run `just format` and rerun `just analyze`. Check release compilation and tests as well because Twill uses different abstraction definitions in debug and release builds:

```bash
just build -c release
just test -c release
just test-integration -c release
```

For cross-platform runtime changes, also run the relevant checks with `--linux`. On Linux, add `--container` when you specifically need the pinned Docker toolchain instead of system-installed Swift.

Follow the [repository instructions](../AGENTS.md). During the extraction, report checks blocked by incomplete package wiring separately from failures introduced by a change.
