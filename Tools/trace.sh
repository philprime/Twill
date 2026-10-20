#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"

usage() {
    printf 'Usage: just trace <pid> [duration=30s] [new-output-directory]\n' >&2
    printf '       just trace-report <existing.trace> [new-output-directory]\n' >&2
    exit 1
}

trace=""
pid=""
duration="30s"
if [[ "${1:-}" == --input ]]; then
    (( $# >= 2 && $# <= 3 )) || usage
    trace="$2"
    [[ -d "$trace" ]] || { printf 'Trace does not exist: %s\n' "$trace" >&2; exit 1; }
    output="${3:-}"
else
    (( $# >= 1 && $# <= 3 )) || usage
    pid="$1"
    duration="${2:-30s}"
    output="${3:-}"
    [[ "$pid" =~ ^[1-9][0-9]*$ ]] || usage
    [[ "$duration" =~ ^[1-9][0-9]*(ms|s|m|h)$ ]] || usage
fi
[[ "$(uname -s)" == Darwin ]] || { printf 'Tracing requires macOS and Xcode.\n' >&2; exit 1; }
for tool in xcrun xsltproc awk; do command -v "$tool" > /dev/null; done

# Each capture owns a new directory. Never overwrite an earlier recording.
if [[ -n "$output" ]]; then
    mkdir "$output"
else
    output="$(mktemp -d "${TMPDIR:-/tmp}/twill-trace.XXXXXX")"
fi
printf 'Artifacts: %s\n' "$output"
printf 'Trace bundles can contain process environment and local paths. Review before sharing.\n'
if [[ -n "$pid" ]]; then
    trace="$output/recording.trace"
    printf 'Recording PID %s for %s. Reproduce the slow interaction now.\n' "$pid" "$duration"
    xcrun xctrace record --template 'Time Profiler' --attach "$pid" --time-limit "$duration" \
        --output "$trace" --no-prompt 2>&1 | tee "$output/record.log"
fi
xcrun xctrace export --input "$trace" --toc --output "$output/toc.xml"
xcrun xctrace export --input "$trace" \
    --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' --output "$output/samples.xml"
bash "$root/trace-summary.sh" "$output/samples.xml" > "$output/summary.md"
printf '\nTrace (run 1): %s\n\nRaw samples: %s/samples.xml\n' "$trace" "$output" >> "$output/summary.md"
cat "$output/summary.md"
printf '\nReport: %s/summary.md\n' "$output"
