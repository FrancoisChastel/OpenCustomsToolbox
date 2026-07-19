# Open Customs Toolbox

A faithful, **fully-sourced** PostgreSQL reference data model of the UNCTAD
**ASYCUDA World (SYDONIA)** customs management system — manifests, SAD
declarations, valuation, taxes, selectivity, accounting and suspense regimes —
reconstructed from *public documentation only*, for sandbox, analytics,
integration and training use.

📖 **Documentation:** <https://francoischastel.github.io/OpenCustomsToolbox/>
· 🤖 **For LLMs:** [`llms.txt`](https://francoischastel.github.io/OpenCustomsToolbox/llms.txt)
· [`llms-full.txt`](https://francoischastel.github.io/OpenCustomsToolbox/llms-full.txt)

> [!NOTE]
> This is a **reference reconstruction** for sandbox/analytics/integration/training
> use. It is **not** UNCTAD's proprietary internal schema, and contains no pirated
> software or data from any live customs system. Not affiliated with UNCTAD.

---

## What's in the box

| | |
|---|---|
| 🗄️ **The model** | `Sydonia/schema/asycuda.sql` — 55 tables across 8 modules, every `CREATE TABLE` provenance-tagged. Loads into a dedicated `asycuda` schema on PostgreSQL 14+. |
| 🌱 **Seed data** | `Sydonia/schema/seed_reference.sql` — reference/code-table values grounded in ISO/UN/WCO standards. |
| ▶️ **Worked example** | `Sydonia/examples/e2e.sql` — a full manifest → declaration → valuation → taxes → selectivity → payment → release, balancing end to end. |
| 📚 **Docs site** | A MkDocs Material site (`docs/`, `mkdocs.yml`) — concepts, per-module schema guide, querying/extending guides, and full provenance. |
| 🤖 **Claude Code skills** | `.claude/skills/customs-*` — set up, query, seed, extend and validate the model in your own codebase. |
| 🔎 **Provenance** | `Sydonia/SOURCES.md`, `COVERAGE.md`, `FIT.md`, `DATA_DICTIONARY.md`, `ERD.md`, `RESEARCH_LOG.md`. |

## Quickstart

```bash
git clone https://github.com/FrancoisChastel/OpenCustomsToolbox.git
cd OpenCustomsToolbox

createdb customs_sandbox
psql -v ON_ERROR_STOP=1 -d customs_sandbox -f Sydonia/schema/asycuda.sql
psql -v ON_ERROR_STOP=1 -d customs_sandbox -f Sydonia/schema/seed_reference.sql
psql -v ON_ERROR_STOP=1 -d customs_sandbox -f Sydonia/examples/e2e.sql
```

```text
--- Total assessed vs receipt ---
 total_assessed | receipt_amount
----------------+----------------
     12132.5000 |     12132.5000
```

A complete import — two items, freight/insurance apportioned to per-item CIF,
duty and VAT assessed, routed RED, inspected, paid and released — inserts with
full referential integrity. See the
[quickstart](https://francoischastel.github.io/OpenCustomsToolbox/getting-started/quickstart/).

## The eight modules

1. **Reference & configuration** — `ref_*` code tables (countries, currencies,
   HS tariff, taxes, offices…) + traders & users.
2. **Manifest & cargo** — manifest, bills of lading (master/house), containers.
3. **Declaration (the SAD)** — general + item segments, valuation, tax lines.
4. **Selectivity & risk** — lanes (green/yellow/red/blue), criteria, inspection.
5. **Accounting** — accounts, payments, receipts, ledger movements, guarantees.
6. **Transit & suspense** — warehousing, transit, temporary admission.
7. **Audit & workflow** — audit log and the status-history pattern.

Full map: the
[schema overview](https://francoischastel.github.io/OpenCustomsToolbox/schema/)
and the
[ER diagram](https://francoischastel.github.io/OpenCustomsToolbox/schema/erd/).

## Provenance — why you can trust it

Every table is either grounded in a cited public source (`-- src: <ID>`) or
honestly flagged `-- inferred` — **49 documented / 6 inferred**, from **20 cited,
cached sources** (official UNCTAD/DTL table descriptions, national ASYCUDA World
manuals, and open ISO/UN/WCO standards). Audit it yourself:

```bash
grep -niE 'create[ \t]+table' Sydonia/schema/asycuda.sql   # every one is tagged
```

The [methodology](https://francoischastel.github.io/OpenCustomsToolbox/provenance/methodology/)
and [fit/gap analysis](https://francoischastel.github.io/OpenCustomsToolbox/provenance/fit/)
document the evidence-first approach and how the model maps to the official tables.

## Claude Code skills

Drive the model in plain English inside your own project — copy
`.claude/skills/customs-*` into your repo (or `~/.claude/skills/`):

```text
> set up the customs model in a throwaway database and run the example
> write a query for assessed-vs-paid across all released declarations
> add a "carrier rating" column to trader, keep it sourced
> validate the schema is still clean and fully grounded
```

See [`.claude/skills/README.md`](.claude/skills/README.md) and the
[skills docs](https://francoischastel.github.io/OpenCustomsToolbox/skills/).

## Repository layout

```text
OpenCustomsToolbox/
├── Sydonia/                    # the model + provenance
│   ├── schema/                 #   asycuda.sql, seed_reference.sql
│   ├── examples/               #   e2e.sql (worked example)
│   ├── sources/ · docs/        #   cached public sources & official PDFs
│   ├── SOURCES.md · COVERAGE.md · FIT.md
│   └── DATA_DICTIONARY.md · ERD.md · RESEARCH_LOG.md
├── docs/                       # MkDocs Material documentation site
├── .claude/skills/customs-*    # Claude Code skills
├── scripts/gen_llms_full.py    # builds docs/llms-full.txt
└── mkdocs.yml
```

## Build the docs locally

```bash
python -m venv .venv-docs && . .venv-docs/bin/activate
pip install -r requirements-docs.txt
python scripts/gen_llms_full.py     # refresh llms-full.txt
mkdocs serve                        # http://127.0.0.1:8000
```

## Sources & licensing

All source material is public and cited in
[`Sydonia/SOURCES.md`](Sydonia/SOURCES.md); field semantics are restated in the
project's own words. ASYCUDA and SYDONIA are programmes of **UNCTAD**; this
project is independent and not affiliated with or endorsed by UNCTAD. Cited
documents remain the property of their respective publishers.
