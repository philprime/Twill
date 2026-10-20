#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

# -- Arrange --
cat > "$temporary/samples.xml" <<'XML'
<trace-query-result><node>
<row><thread id="1" fmt="Main Thread"/><weight id="2">2000000</weight>
<tagged-backtrace id="3"><frame id="4" name="leaf&lt;T&gt; | next"/>
<frame id="5" name="recursive"/><frame ref="5"/></tagged-backtrace></row>
<row><thread ref="1"/><weight ref="2"/><tagged-backtrace ref="3"/></row>
</node></trace-query-result>
XML

# -- Act --
bash "$root/Tools/trace-summary.sh" "$temporary/samples.xml" > "$temporary/report.md"

# -- Assert --
grep -Fq 'Sampled CPU: **4.00 ms** across 2 samples' "$temporary/report.md"
grep -Fq '| recursive | 4.00 | 100.0% |' "$temporary/report.md"
grep -Fq '| leaf&lt;T&gt; &#124; next | 4.00 | 100.0% |' "$temporary/report.md"
grep -Fq '| Main Thread | 4.00 | 100.0% |' "$temporary/report.md"
grep -Fq 'not wall-clock latency' "$temporary/report.md"
test "$(grep -Fc '| recursive |' "$temporary/report.md")" = 1

# -- Arrange --
printf '%s\n' '<trace-query-result><node/></trace-query-result>' > "$temporary/empty.xml"

# -- Act --
bash "$root/Tools/trace-summary.sh" "$temporary/empty.xml" > "$temporary/empty.md"

# -- Assert --
grep -Fq 'No running-thread samples' "$temporary/empty.md"
if grep -Fq '100.0%' "$temporary/empty.md"; then exit 1; fi

# -- Arrange --
cat > "$temporary/mixed.xml" <<'XML'
<trace-query-result><node>
<row><thread id="1" fmt="Main"/><weight id="2">1000000</weight>
<tagged-backtrace id="3"><frame id="4" name="leaf"/><frame id="5" name="parent"/></tagged-backtrace></row>
<row><thread id="6" fmt="Worker"/><weight>3000000</weight>
<tagged-backtrace><frame ref="5"/></tagged-backtrace></row>
</node></trace-query-result>
XML

# -- Act --
bash "$root/Tools/trace-summary.sh" "$temporary/mixed.xml" > "$temporary/mixed.md"

# -- Assert --
grep -Fq '| Worker | 3.00 | 75.0% |' "$temporary/mixed.md"
grep -Fq '| parent | 4.00 | 100.0% |' "$temporary/mixed.md"
grep -Fq '| parent | 3.00 | 75.0% |' "$temporary/mixed.md"
grep -Fq '| leaf | 1.00 | 25.0% |' "$temporary/mixed.md"

# -- Arrange --
cat > "$temporary/unavailable.xml" <<'XML'
<trace-query-result><node>
<row><thread id="1" fmt="Main"/><weight id="2">1000000</weight>
<tagged-backtrace id="3"><frame name="work"/></tagged-backtrace></row>
<row><thread ref="1"/><weight ref="2"/><sentinel/></row>
<row><thread ref="1"/><weight ref="2"/><tagged-backtrace ref="3"/></row>
</node></trace-query-result>
XML

# -- Act --
bash "$root/Tools/trace-summary.sh" "$temporary/unavailable.xml" > "$temporary/unavailable.md"

# -- Assert --
grep -Fq 'Sampled CPU: **3.00 ms** across 3 samples' "$temporary/unavailable.md"
grep -Fq '| Main | 3.00 | 100.0% |' "$temporary/unavailable.md"
grep -Fq '| work | 2.00 | 66.7% |' "$temporary/unavailable.md"
grep -Fq '| [unavailable stack] | 1.00 | 33.3% |' "$temporary/unavailable.md"

# -- Arrange --
printf '%s\n' '<trace-query-result><node><row><weight ref="missing"/></row></node></trace-query-result>' \
    > "$temporary/broken.xml"

# -- Act / Assert --
if bash "$root/Tools/trace-summary.sh" "$temporary/broken.xml" > /dev/null 2>&1; then
    printf 'Malformed samples unexpectedly succeeded.\n' >&2
    exit 1
fi
printf 'Trace summary tests passed.\n'
