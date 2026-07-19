# Contributing to Open Customs Toolbox

Thanks for helping out! This project is a friendly-SQL → genuine-ASYCUDA-World-SQL
toolkit: a reconstructed data model, a query compiler, docs, and Agent Skills.
Contributions of all sizes are welcome.

## Good first contributions

- ✅ **A new verified query** in the [useful queries](docs/guides/useful-queries.md)
  library (follow the copy-paste entry format; run it read-only before adding).
- 🧭 **A mapping entry** in `compiler/mappings/` for a table not yet covered, or a
  per-instance override you know is correct for a real deployment.
- 🧱 **A compatibility-view / mock table** in `Sydonia/adapters/` extending coverage.
- 📚 **Docs fixes** — clarity, examples, typos.
- 🐛 **Bug reports** with a minimal repro.

## Setup

```bash
# the logical sandbox (needs PostgreSQL 14+)
createdb customs_sandbox
psql -v ON_ERROR_STOP=1 -d customs_sandbox -f Sydonia/schema/asycuda.sql
psql -v ON_ERROR_STOP=1 -d customs_sandbox -f Sydonia/schema/seed_reference.sql
psql -v ON_ERROR_STOP=1 -d customs_sandbox -f Sydonia/examples/e2e.sql

# the compiler
pip install pyyaml

# the docs toolchain (optional)
python -m venv .venv-docs && . .venv-docs/bin/activate
pip install -r requirements-docs.txt
```

## Before you open a PR — verify

| Change | How to check |
|--------|--------------|
| Schema / seed / example | Re-run the three loads above with `ON_ERROR_STOP=1` — zero errors. |
| Provenance | Every `CREATE TABLE` carries `-- src: <ID>` or `-- inferred`; cited IDs appear in `SOURCES.md`. The `customs-validate` skill automates this. |
| Compiler / mapping | `createdb aw_mock && psql -d aw_mock -f Sydonia/adapters/mock_asycuda_world.sql`, then compile a query and run it on the mock — results match the sandbox. |
| Docs | `mkdocs build --strict` is clean; run `python scripts/gen_llms_full.py` if you added/moved pages. |
| Queries | Test **read-only** — `bash skills/customs-query/scripts/test_query.sh "…"`. Never paste real row data into the repo or an issue. |

## Pull-request process

1. Branch from `master`; keep PRs focused.
2. Use clear commit messages (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`…).
3. Describe what and why; note how you verified it.
4. CI builds the docs on every push — keep it green.

## Ground rules

- **Public sources only.** Never add proprietary ASYCUDA schema/software, leaked
  material, or data from a live customs system. Restate semantics in your own
  words; don't paste real declarations.
- **Honesty over coverage.** If something can't be grounded in public
  documentation, tag it `-- inferred` — a larger honest inferred set beats a
  fabricated "documented" one.
- Be kind — see the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

By contributing, you agree that your contributions are licensed under the
project's [AGPL-3.0](LICENSE).
