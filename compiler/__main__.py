"""Open Customs Toolbox — Sydonia query compiler CLI.

Turn friendly LOGICAL queries into GENUINE ASYCUDA World SQL you can run.

    python -m compiler compile query.sql              # logical SQL file -> genuine SQL
    echo "SELECT * FROM declaration" | python -m compiler compile -
    python -m compiler build spec.yml                 # query spec -> logical SQL -> genuine SQL
    python -m compiler emit-views                      # regenerate the persistent-view adapter

Options:
    --mapping NAME      base mapping (default: asycuda-world)
    --overrides FILE    per-instance overrides merged over the base mapping
    --logical           (compile/build) print the LOGICAL SQL only, don't compile
"""
from __future__ import annotations

import sys

from .compile import load_mapping, compile_sql, emit_views
from .build import build_logical_sql, load_spec


def _opt(args: list[str], name: str, default=None):
    return args[args.index(name) + 1] if name in args else default


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    cmd, rest = argv[0], argv[1:]
    mapping_name = _opt(rest, "--mapping", "asycuda-world")
    overrides = _opt(rest, "--overrides")
    logical_only = "--logical" in rest
    positionals = [a for a in rest if not a.startswith("--") and a not in (mapping_name, overrides)]

    if cmd == "emit-views":
        print(emit_views(load_mapping(mapping_name, overrides)))
        return 0

    if cmd not in ("compile", "build"):
        print(f"unknown command: {cmd}\n{__doc__}", file=sys.stderr)
        return 2

    if not positionals:
        print(f"{cmd}: need a file argument (or - for stdin)", file=sys.stderr)
        return 2
    src = positionals[0]

    if cmd == "build":
        logical = build_logical_sql(load_spec(src))
    else:
        logical = sys.stdin.read() if src == "-" else open(src, encoding="utf-8").read()

    if logical_only:
        print(logical.rstrip())
        return 0

    genuine, warnings = compile_sql(logical, load_mapping(mapping_name, overrides))
    for w in warnings:
        print(f"-- warning: {w}", file=sys.stderr)
    print(genuine.rstrip())
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
