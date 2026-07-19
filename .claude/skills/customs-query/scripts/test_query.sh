#!/usr/bin/env bash
# test_query.sh — privacy-preserving SQL test (the no-MCP fallback).
#
# Proves a SELECT runs against the customs schema and reports ONLY metadata:
# column names/types (via psql \gdesc — describe, not execute), an aggregate
# row count, and duration. Row values are never printed. The session is forced
# read-only with a statement timeout, so nothing can be written and nothing can
# run away — same guarantees as the customs-query-tester MCP server.
#
# Usage:
#   test_query.sh [--db NAME_OR_DSN] [--schema NAME] "SELECT ..."
#   echo "SELECT ..." | test_query.sh [--db ...]
set -euo pipefail

DB="${CUSTOMS_DB:-customs_sandbox}"
SCHEMA="${CUSTOMS_SCHEMA:-asycuda}"
TIMEOUT_MS="${CUSTOMS_TIMEOUT_MS:-5000}"
SQL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)     DB="$2"; shift 2 ;;
    --schema) SCHEMA="$2"; shift 2 ;;
    -h|--help) grep '^# ' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)        SQL="$1"; shift ;;
  esac
done
[[ -z "$SQL" ]] && SQL="$(cat)"
[[ -z "${SQL// /}" ]] && { echo "ERROR: no query given" >&2; exit 2; }

# --- lexical guard: single SELECT/WITH only ------------------------------
# Strip line/block comments and single-quoted strings, then check shape.
CLEAN="$(printf '%s' "$SQL" \
  | sed -e 's/--.*$//' \
  | tr '\n' ' ' \
  | sed -e 's|/\*[^*]*\*/| |g' -e "s/'[^']*'/''/g")"
BODY="$(printf '%s' "$CLEAN" | sed -e 's/[[:space:]]*$//' -e 's/;[[:space:]]*$//')"
if printf '%s' "$BODY" | grep -q ';'; then
  echo "REJECTED: multiple statements are not allowed — send exactly one SELECT" >&2; exit 3
fi
FIRST="$(printf '%s' "$BODY" | grep -oiE '^[[:space:]]*[a-z]+' | tr -d ' ' | tr '[:upper:]' '[:lower:]')"
case "$FIRST" in select|with|table|values) ;; *)
  echo "REJECTED: only read queries are allowed (SELECT/WITH); got '${FIRST:-<empty>}'" >&2; exit 3 ;;
esac
if printf '%s' "$BODY" | grep -qiE '\b(insert|update|delete|truncate|drop|alter|create|grant|revoke|copy|call|do|vacuum|merge|into)\b'; then
  echo "REJECTED: write/DDL keyword found — this tester is read-only" >&2; exit 3
fi

# --- read-only, time-boxed session ---------------------------------------
export PGOPTIONS="-c default_transaction_read_only=on -c statement_timeout=${TIMEOUT_MS} -c search_path=${SCHEMA},public"
export PGCONNECT_TIMEOUT=5
Q="$(printf '%s' "$SQL" | sed -e 's/[[:space:]]*$//' -e 's/;[[:space:]]*$//')"

echo "▸ database: $DB  schema: $SCHEMA  timeout: ${TIMEOUT_MS}ms (read-only)"

# 1. Result shape via \gdesc — describes without executing, zero data.
echo "▸ columns (name | type):"
printf '%s\n\\gdesc\n' "$Q" \
  | psql -X --quiet -v ON_ERROR_STOP=1 -A -t -d "$DB" \
  | sed 's/^/    /'

# 2. Row count via aggregate wrapper — one number leaves the database.
START=$(date +%s)
COUNT="$(psql -X --quiet -v ON_ERROR_STOP=1 -A -t -d "$DB" \
  -c "SELECT count(*) FROM ( $Q ) AS __privacy_wrapper;")"
END=$(date +%s)

echo "▸ rows: $COUNT"
echo "▸ duration: $((END - START))s (wall)"
echo "✓ OK — no row data was read or returned (read-only, ${TIMEOUT_MS}ms cap)"
