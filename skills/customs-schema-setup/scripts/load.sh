#!/usr/bin/env bash
# load.sh — load the Open Customs Toolbox schema into a PostgreSQL database,
# in the correct order, failing loudly on the first error.
#
# Usage:  load.sh [DB_NAME] [--schema-dir DIR] [--examples-dir DIR] [--no-e2e] [--keep]
# Connection uses standard libpq env vars (PGHOST, PGPORT, PGUSER, PGPASSWORD).
set -euo pipefail

DB="customs_sandbox"
SCHEMA_DIR=""
EXAMPLES_DIR=""
WITH_E2E=1
KEEP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --schema-dir)   SCHEMA_DIR="$2"; shift 2 ;;
    --examples-dir) EXAMPLES_DIR="$2"; shift 2 ;;
    --no-e2e)       WITH_E2E=0; shift ;;
    --keep)         KEEP=1; shift ;;
    -h|--help)      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)             echo "unknown option: $1" >&2; exit 2 ;;
    *)              DB="$1"; shift ;;
  esac
done

# --- locate the schema directory ------------------------------------------
find_schema_dir() {
  local d
  for d in "$SCHEMA_DIR" "Sydonia/schema" "../Sydonia/schema" "./schema" \
           "$(dirname "$0")/../../../Sydonia/schema" \
           "$(dirname "$0")/../../../../Sydonia/schema"; do
    [[ -n "$d" && -f "$d/asycuda.sql" ]] && { (cd "$d" && pwd); return 0; }
  done
  return 1
}

if ! SCHEMA_DIR="$(find_schema_dir)"; then
  echo "ERROR: could not find asycuda.sql. Pass --schema-dir /path/to/Sydonia/schema" >&2
  exit 1
fi
[[ -z "$EXAMPLES_DIR" ]] && EXAMPLES_DIR="$(cd "$SCHEMA_DIR/../examples" 2>/dev/null && pwd || true)"

echo "▸ database    : $DB"
echo "▸ schema dir  : $SCHEMA_DIR"
echo "▸ examples dir: ${EXAMPLES_DIR:-<none>}"
echo "▸ load e2e    : $([[ $WITH_E2E -eq 1 ]] && echo yes || echo no)"

# --- (re)create the database ----------------------------------------------
if psql -lqt 2>/dev/null | cut -d'|' -f1 | grep -qw "$DB"; then
  if [[ $KEEP -eq 0 ]]; then
    echo "▸ dropping existing database $DB"
    dropdb "$DB"
    createdb "$DB"
  else
    echo "▸ keeping existing database $DB (--keep)"
  fi
else
  createdb "$DB"
fi

run() { echo "→ $1"; psql -v ON_ERROR_STOP=1 -q -d "$DB" -f "$1"; }

# --- load in order --------------------------------------------------------
run "$SCHEMA_DIR/asycuda.sql"
run "$SCHEMA_DIR/seed_reference.sql"
if [[ $WITH_E2E -eq 1 && -n "$EXAMPLES_DIR" && -f "$EXAMPLES_DIR/e2e.sql" ]]; then
  run "$EXAMPLES_DIR/e2e.sql"
elif [[ $WITH_E2E -eq 1 ]]; then
  echo "▸ note: e2e.sql not found in ${EXAMPLES_DIR:-<none>} — skipping example" >&2
fi

# --- report ---------------------------------------------------------------
TABLES="$(psql -tAqc "SELECT count(*) FROM information_schema.tables WHERE table_schema='asycuda' AND table_type='BASE TABLE'" -d "$DB")"
echo "✓ loaded — $TABLES tables in schema 'asycuda' (expected 55)"
echo "  next: psql -d $DB  then  SET search_path TO asycuda, public;"
