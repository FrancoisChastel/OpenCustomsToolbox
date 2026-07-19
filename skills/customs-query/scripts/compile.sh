#!/usr/bin/env bash
# compile.sh — compile a LOGICAL query (friendly toolbox names) into GENUINE
# ASYCUDA World SQL, and optionally test it read-only. The no-MCP fallback for
# the compiler bridge.
#
# Usage:
#   compile.sh "SELECT ... FROM declaration ..."      # prints genuine Sydonia SQL
#   compile.sh --test "SELECT ..."                    # + run it read-only (metadata only)
#   echo "SELECT ..." | compile.sh
# Env: CUSTOMS_MAPPING (default asycuda-world), CUSTOMS_OVERRIDES (per-instance file),
#      CUSTOMS_DB / CUSTOMS_SCHEMA (for --test; defaults customs_sandbox / asycuda).
set -euo pipefail

TEST=0
[[ "${1:-}" == "--test" ]] && { TEST=1; shift; }
SQL="${1:-$(cat)}"

# locate the repo root (this script lives at .claude/skills/customs-query/scripts/ or skills/…)
here="$(cd "$(dirname "$0")" && pwd)"
root="$here"
while [[ "$root" != "/" && ! -d "$root/compiler" ]]; do root="$(dirname "$root")"; done
[[ -d "$root/compiler" ]] || { echo "cannot find compiler/ — run from the toolbox repo" >&2; exit 1; }

args=(--mapping "${CUSTOMS_MAPPING:-asycuda-world}")
[[ -n "${CUSTOMS_OVERRIDES:-}" ]] && args+=(--overrides "$CUSTOMS_OVERRIDES")

GENUINE="$(cd "$root" && printf '%s' "$SQL" | python3 -m compiler compile - "${args[@]}")"
printf '%s\n' "$GENUINE"

if [[ $TEST -eq 1 ]]; then
  echo "--- testing compiled SQL read-only (metadata only) ---" >&2
  tester="$here/test_query.sh"
  [[ -x "$tester" ]] && printf '%s' "$GENUINE" | "$tester" || \
    echo "(test_query.sh not found alongside; skipping test)" >&2
fi
