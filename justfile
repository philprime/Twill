# Execution options for build, test, test-integration, and example:
#   No flags: use system-installed Swift on the host.
#   --linux: use Docker on macOS, system-installed Swift on Linux.
#   --container: force Docker on Linux; on macOS it requires --linux and is redundant.
# Options are consumed before --; remaining arguments are forwarded to SwiftPM unchanged.
# macOS execution from Linux is not supported. See Docs/DEVELOPMENT.md for the full matrix.
set positional-arguments := true

root := justfile_directory()
linux_swift_image := env_var_or_default("LINUX_SWIFT_IMAGE", "swift:6.4.0")
linux_arch := env_var_or_default("LINUX_ARCH", if arch() == "aarch64" { "arm64" } else { "amd64" })
linux_build_dir := root + "/.build/linux-" + linux_arch

# List available commands.
default:
    @just --list

# Install development tools and resolve dependencies (macOS with Homebrew).
setup:
    brew bundle
    swift package resolve

# Build on the host. Supports --linux, --container, and SwiftPM arguments such as -c release.
build *args:
    just _swift batch build --disable-index-store --explicit-target-dependency-import-check warn -Xswiftc -warnings-as-errors "$@"

# Enable injectable collaborators in the library and unit tests, in either configuration.
# Supports --linux, --container, and SwiftPM arguments such as --filter SomeSuite.
test *args:
    just _swift batch test --parallel --disable-index-store --explicit-target-dependency-import-check warn -Xswiftc -warnings-as-errors -Xswiftc -DTESTING --skip TwillIntegrationTests "$@"

# Test production collaborators without TESTING. Supports --linux and --container.
test-integration *args:
    just _swift batch test --parallel --disable-index-store --explicit-target-dependency-import-check warn -Xswiftc -warnings-as-errors --test-product TwillIntegrationTests --filter TwillIntegrationTests "$@"

# Run unit and integration tests with AddressSanitizer. Supports --linux and --container.
test-sanitize *args:
    just test --sanitize address "$@"
    just test-integration --sanitize address "$@"

# Run an example, e.g. just example Clock --linux. Supports --container. Use -- before example flags.
example name *args:
    #!/usr/bin/env bash
    set -euo pipefail
    name="$1"
    shift
    just _swift interactive run --package-path "Examples/$name" --scratch-path ".build/examples/$name" "$@"

# Apply Swift and dprint formatting, including example packages.
format:
    #!/usr/bin/env bash
    set -euo pipefail
    paths=(Sources Tests Package.swift)
    if [[ -d Examples ]]; then paths+=(Examples); fi
    swift format format --configuration .swift-format.json --in-place --recursive --parallel "${paths[@]}"
    dprint fmt

# Check formatting without modifying files.
format-check:
    #!/usr/bin/env bash
    set -euo pipefail
    paths=(Sources Tests Package.swift)
    if [[ -d Examples ]]; then paths+=(Examples); fi
    swift format lint --configuration .swift-format.json --recursive --parallel --strict "${paths[@]}"
    dprint check

# Check Swift code and GitHub Actions workflows.
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "$(uname -s)" == Linux ]]; then
        runtime_library_path="$(swiftc -print-target-info | jq -er '.paths.runtimeLibraryPaths[] | select(endswith("/swift/linux"))')"
        export LINUX_SOURCEKIT_LIB_PATH="$(dirname "$(dirname "$runtime_library_path")")"
    fi
    swiftlint lint --strict --config .swiftlint.yml
    actionlint

# Run all static quality checks.
analyze: lint format-check

# Clean the root package's SwiftPM build output.
clean:
    swift package clean

# Select native Swift or a Linux container without passing execution flags to SwiftPM.
[private]
_swift mode command *args:
    #!/usr/bin/env bash
    set -euo pipefail
    mode="$1"
    command=("$2")
    shift 2
    linux=false
    container=false
    while (( $# )); do
        case "$1" in
            --linux) linux=true ;;
            --container) container=true ;;
            --) command+=("$@"); break ;;
            *) command+=("$1") ;;
        esac
        shift
    done
    host="$(uname -s)"
    if [[ "$host" == Darwin && "$container" == true && "$linux" != true ]]; then
        echo "error: --container requires --linux on macOS" >&2
        exit 1
    fi
    if [[ "$container" == true || ( "$linux" == true && "$host" != Linux ) ]]; then
        exec just _linux "$mode" swift "${command[@]}"
    fi
    exec swift "${command[@]}"

# Set LINUX_ARCH to amd64 or arm64 for Docker. Keep sources read-only and builds host-owned.
[private]
_linux mode +args:
    #!/usr/bin/env bash
    set -euo pipefail
    flags=()
    if [[ "$1" == interactive ]]; then flags+=(--interactive --tty); fi
    shift
    mkdir -p "{{linux_build_dir}}"
    docker run --rm ${flags[@]+"${flags[@]}"} \
        --platform "linux/{{linux_arch}}" \
        --user "$(id -u):$(id -g)" \
        --env HOME=/tmp \
        --mount "type=bind,source={{root}},target=/workspace,readonly" \
        --mount "type=bind,source={{linux_build_dir}},target=/workspace/.build" \
        --workdir /workspace \
        "{{linux_swift_image}}" \
        "$@"
