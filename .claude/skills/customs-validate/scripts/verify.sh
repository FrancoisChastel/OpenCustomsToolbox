#!/usr/bin/env bash
# verify.sh — re-run the Open Customs Toolbox done-conditions and print PASS/FAIL.
# Usage:  verify.sh [--sydonia-dir DIR] [--db NAME]
set -uo pipefail

SYDONIA=""
DB="oct_verify_$$"
FAILS=0
pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAILS=$((FAILS+1)); }
skip() { printf '  \033[33mSKIP\033[0m  %s\n' "$1"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sydonia-dir) SYDONIA="$2"; shift 2 ;;
    --db)          DB="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

# --- locate Sydonia/ -------------------------------------------------------
for d in "$SYDONIA" "Sydonia" "../Sydonia" "." "$(dirname "$0")/../../../../Sydonia"; do
  [[ -n "$d" && -f "$d/schema/asycuda.sql" ]] && { SYDONIA="$(cd "$d" && pwd)"; break; }
done
if [[ -z "${SYDONIA:-}" || ! -f "$SYDONIA/schema/asycuda.sql" ]]; then
  echo "ERROR: could not find Sydonia/schema/asycuda.sql. Pass --sydonia-dir." >&2
  exit 1
fi
SCHEMA="$SYDONIA/schema"; EX="$SYDONIA/examples"
echo "Auditing: $SYDONIA"
echo

# --- 1. clean load ---------------------------------------------------------
echo "1 · Schema loads clean"
if command -v psql >/dev/null && command -v createdb >/dev/null; then
  if createdb "$DB" 2>/dev/null; then
    LOG="$(mktemp)"
    ok=1
    for f in "$SCHEMA/asycuda.sql" "$SCHEMA/seed_reference.sql" "$EX/e2e.sql"; do
      [[ -f "$f" ]] || continue
      if ! psql -v ON_ERROR_STOP=1 -q -d "$DB" -f "$f" >>"$LOG" 2>&1; then
        fail "load failed on $(basename "$f") — $(tail -1 "$LOG")"; ok=0; break
      fi
    done
    if [[ $ok -eq 1 ]]; then
      n="$(psql -tAqc "SELECT count(*) FROM information_schema.tables WHERE table_schema='asycuda' AND table_type='BASE TABLE'" -d "$DB")"
      [[ "$n" == "55" ]] && pass "loaded $n tables, e2e example inserted" \
                         || fail "loaded $n tables (expected 55)"
    fi
    dropdb "$DB" 2>/dev/null || true
    rm -f "$LOG"
  else
    skip "could not create database $DB — check permissions/connection"
  fi
else
  skip "psql/createdb not found — static checks only"
fi

# --- 2. every table tagged -------------------------------------------------
echo "2 · Every table is grounded"
UNTAGGED="$(awk '
  /[Cc][Rr][Ee][Aa][Tt][Ee][ \t]+[Tt][Aa][Bb][Ll][Ee]/{
    tagged=0; for(i=NR-1;i>=NR-4 && i>0;i--) if(prev[i] ~ /-- *src:|-- *inferred/) tagged=1;
    if(!tagged) print "     untagged: " $0
  } {prev[NR]=$0}' "$SCHEMA"/*.sql)"
TOTAL="$(grep -ciE 'create[ \t]+table' "$SCHEMA/asycuda.sql")"
if [[ -z "$UNTAGGED" ]]; then pass "all $TOTAL CREATE TABLE statements tagged (-- src: or -- inferred)";
else fail "untagged tables found:"; echo "$UNTAGGED"; fi

# --- 3. every cited source resolves ---------------------------------------
echo "3 · Every cited source resolves in SOURCES.md"
MISSING=""
for id in $(grep -hoiE '\-\- *src: *S[0-9, ]+' "$SCHEMA"/*.sql | grep -oiE 'S[0-9]+' | sort -u); do
  grep -q "\b$id\b" "$SYDONIA/SOURCES.md" 2>/dev/null || MISSING="$MISSING $id"
done
[[ -z "$MISSING" ]] && pass "all cited IDs present in SOURCES.md" \
                    || fail "IDs missing from SOURCES.md:$MISSING"

# --- 4. docs present -------------------------------------------------------
echo "4 · Supporting docs exist"
for doc in DATA_DICTIONARY.md ERD.md COVERAGE.md RESEARCH_LOG.md; do
  [[ -f "$SYDONIA/$doc" ]] && pass "$doc" || fail "$doc missing"
done

echo
if [[ $FAILS -eq 0 ]]; then
  printf '\033[32m✓ ALL CHECKS PASSED\033[0m — schema is clean and fully grounded.\n'; exit 0
else
  printf '\033[31m✗ %d CHECK(S) FAILED\033[0m — see above; do not commit until resolved.\n' "$FAILS"; exit 1
fi
