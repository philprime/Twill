#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")" && pwd)"
samples="${1:?usage: trace-summary.sh exported-time-profile.xml}"

# XML references are resolved before aggregation. Recursion contributes only
# once to a symbol's inclusive weight in each sample.
xsltproc --nonet "$root/trace-samples.xsl" "$samples" |
    awk -F '\t' '
        function fail(message) { print message > "/dev/stderr"; failed = 1; exit 1 }
        $1 == "weight" {
            weight = ($3 != "" ? weights[$3] : $4) / 1000000
            if (weight <= 0) fail("Invalid or unresolved sample weight")
            if ($2 != "") weights[$2] = $4
        }
        $1 == "thread" {
            thread = $3 != "" ? threadNames[$3] : $4
            if (thread == "") fail("Missing or unresolved thread")
            if ($2 != "") threadNames[$2] = thread
        }
        $1 == "tagged-backtrace" {
            stackID = $2
            stack = $3 != "" ? stacks[$3] : ""
            if ($3 != "" && !($3 in stacks)) fail("Unresolved stack")
        }
        $1 == "frame" {
            name = $3 != "" ? frames[$3] : $4
            if (name == "") fail("Missing or unresolved frame")
            if ($2 != "") frames[$2] = name
            stack = stack == "" ? name : stack SUBSEP name
        }
        $1 == "sentinel" {
            stackID = ""
            stack = "[unavailable stack]"
        }
        $1 == "E" {
            if (stackID != "") stacks[stackID] = stack
            total += weight
            count++
            threads[thread] += weight
            frameCount = split(stack, names, SUBSEP)
            if (stack != "") own[names[1]] += weight
            for (indexInStack = 1; indexInStack <= frameCount; indexInStack++) {
                name = names[indexInStack]
                if (seen[name] != count) { inclusive[name] += weight; seen[name] = count }
            }
        }
        END {
            if (failed) exit 1
            printf "0\t%.9f\t%d\n", total, count
            for (name in threads) printf "1\t%.9f\t%s\n", threads[name], name
            for (name in inclusive) printf "2\t%.9f\t%s\n", inclusive[name], name
            for (name in own) printf "3\t%.9f\t%s\n", own[name], name
        }
    ' |
    LC_ALL=C sort -t $'\t' -k1,1n -k2,2nr -k3,3 |
    awk -F '\t' '
        BEGIN { print "# Time Profiler summary\n" }
        $1 == 0 {
            total = $2
            if (!total) {
                print "No running-thread samples were captured. Reproduce the slow interaction while recording."
                next
            }
            printf "Sampled CPU: **%.2f ms** across %d samples.\n\n", total, $3
            print "Weighted running-thread samples, not wall-clock latency. Sleeping and blocked time are excluded."
            print "Inclusive costs overlap and must not be added together. Self cost belongs to the leaf frame."
            next
        }
        $1 != section {
            section = $1
            count = 0
            title = section == 1 ? "Threads" : section == 2 ? "Inclusive hotspots" : "Self hotspots"
            printf "\n## %s\n\n| Name | CPU ms | Share |\n| --- | ---: | ---: |\n", title
        }
        ++count <= (section == 1 ? 10 : section == 2 ? 40 : 20) {
            name = $3
            gsub(/&/, "\\&amp;", name)
            gsub(/</, "\\&lt;", name)
            gsub(/>/, "\\&gt;", name)
            gsub(/\|/, "\\&#124;", name)
            printf "| %s | %.2f | %.1f%% |\n", name, $2, $2 / total * 100
        }
    '
