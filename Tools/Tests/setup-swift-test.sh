#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

# -- Arrange --
export SWIFT_VERSION=6.4.0
export SWIFT_CACHE_PATH="$temporary/cache"
export GITHUB_PATH="$temporary/github-path"
export RUNNER_OS=Linux
mkdir -p "$SWIFT_CACHE_PATH/bin" "$temporary/toolchain/usr/bin"
touch "$SWIFT_CACHE_PATH.complete"
export TEST_TOOLCHAIN="$temporary/toolchain"
cat > "$SWIFT_CACHE_PATH/bin/swiftly" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$TEST_TOOLCHAIN"
SH
cat > "$TEST_TOOLCHAIN/usr/bin/swift" <<'SH'
#!/usr/bin/env bash
printf 'Swift version 6.4.0 (swift-6.4-RELEASE)\n'
SH
cat > "$TEST_TOOLCHAIN/usr/bin/swift-build" <<'SH'
#!/usr/bin/env bash
exit "${BUILD_EXIT_CODE:-0}"
SH
cat > "$TEST_TOOLCHAIN/usr/bin/swift-test" <<'SH'
#!/usr/bin/env bash
exit "${TEST_EXIT_CODE:-0}"
SH
chmod +x "$SWIFT_CACHE_PATH/bin/swiftly" "$TEST_TOOLCHAIN/usr/bin/"*

# -- Act --
if BUILD_EXIT_CODE=127 bash "$root/.github/actions/setup-swift/setup.sh" > "$temporary/build.log" 2>&1; then
    # -- Assert --
    printf 'Setup accepted a toolchain with an unusable swift-build.\n' >&2
    exit 1
fi
test ! -s "$GITHUB_PATH"

# -- Act --
if TEST_EXIT_CODE=127 bash "$root/.github/actions/setup-swift/setup.sh" > "$temporary/test.log" 2>&1; then
    # -- Assert --
    printf 'Setup accepted a toolchain with an unusable swift-test.\n' >&2
    exit 1
fi
test ! -s "$GITHUB_PATH"

# -- Act --
bash "$root/.github/actions/setup-swift/setup.sh" > "$temporary/success.log" 2>&1

# -- Assert --
grep -Fxq "$TEST_TOOLCHAIN/usr/bin" "$GITHUB_PATH"
printf 'Swift setup tests passed.\n'
