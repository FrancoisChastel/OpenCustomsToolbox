<div align="center">

# 🛃 Sydonia Toolkit

### Write friendly SQL. Run it on a real ASYCUDA World (SYDONIA) customs database.

You write a clean query against a friendly model — `declaration`, `hs_code`,
`tax_amount`. The compiler turns it into **genuine ASYCUDA World SQL** you can
run, read-only, on a live instance. *The abstraction is easy; the output is real.*

[![Docs](https://img.shields.io/badge/docs-latest-14b8a6?logo=readthedocs&logoColor=white)](https://francoischastel.github.io/sydonia-toolkit/latest/)
[![Docs build](https://github.com/FrancoisChastel/sydonia-toolkit/actions/workflows/docs.yml/badge.svg)](https://github.com/FrancoisChastel/sydonia-toolkit/actions/workflows/docs.yml)
[![License: AGPL v3](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)
[![PostgreSQL 14+](https://img.shields.io/badge/PostgreSQL-14%2B-336791?logo=postgresql&logoColor=white)](#-quickstart)
[![llms.txt](https://img.shields.io/badge/llms.txt-%E2%9C%93-black)](https://francoischastel.github.io/sydonia-toolkit/latest/llms.txt)
[![Stars](https://img.shields.io/github/stars/FrancoisChastel/sydonia-toolkit?style=social)](https://github.com/FrancoisChastel/sydonia-toolkit/stargazers)

[**Docs**](https://francoischastel.github.io/sydonia-toolkit/latest/) ·
[**Query Sydonia**](https://francoischastel.github.io/sydonia-toolkit/latest/querying-sydonia/) ·
[**The compiler**](https://francoischastel.github.io/sydonia-toolkit/latest/compiler/) ·
[**Agent Skills**](https://francoischastel.github.io/sydonia-toolkit/latest/skills/)

</div>

---

## ✨ The idea in one screen

ASYCUDA World — the customs system used by 100+ countries — has a **wide,
denormalised, mostly non-public** database: `SAD_General_Segment`, `SAD_Item`,
`SAD_Tax`, `INSTANCE_ID` keys, the HS code split across `TAR_HSC_NB1..5`. Writing
analytics against it hurts.

So you write against a **friendly logical model** instead:

```sql
-- ✍️  what you write
SELECT di.hs_code, sum(tl.tax_amount) AS taxes
FROM declaration_item di
JOIN declaration_tax_line tl ON tl.declaration_item_id = di.id
GROUP BY di.hs_code;
```

…and `python -m compiler compile` gives you **genuine Sydonia SQL to run**:

```sql
-- 🚀  what you run (excerpt)
WITH declaration_item AS (
  SELECT concat(i.TAR_HSC_NB1, i.TAR_HSC_NB2, i.TAR_HSC_NB3, i.TAR_HSC_NB4, i.TAR_HSC_NB5) AS hs_code,
         i.VIT_CIF AS customs_value, … FROM SAD_Item i ),
     declaration_tax_line AS (
  SELECT x.TAX_ITM_ID AS declaration_item_id, x.AMT AS tax_amount, … FROM SAD_Tax x )
SELECT di.hs_code, sum(tl.tax_amount) AS taxes
FROM declaration_item di JOIN declaration_tax_line tl ON tl.declaration_item_id = di.id
GROUP BY di.hs_code;
```

Same query, same results — verified against a mock ASYCUDA World database. It runs
**read-only**, returning only metadata (columns, row counts) — safe on real,
sensitive customs data.

## 🚀 Quickstart

```bash
git clone https://github.com/FrancoisChastel/sydonia-toolkit.git
cd sydonia-toolkit

# 1) stand up the friendly logical model (a local sandbox)
createdb customs_sandbox
psql -v ON_ERROR_STOP=1 -d customs_sandbox -f Sydonia/schema/asycuda.sql
psql -v ON_ERROR_STOP=1 -d customs_sandbox -f Sydonia/schema/seed_reference.sql
psql -v ON_ERROR_STOP=1 -d customs_sandbox -f Sydonia/examples/e2e.sql

# 2) compile a friendly query into genuine ASYCUDA World SQL
pip install pyyaml
echo "SELECT hs_code, sum(tax_amount) FROM declaration_item di
      JOIN declaration_tax_line tl ON tl.declaration_item_id = di.id
      GROUP BY hs_code" | python -m compiler compile -
```

Prove the whole loop with the mock ASYCUDA World database:

```bash
createdb aw_mock
psql -v ON_ERROR_STOP=1 -d aw_mock -f Sydonia/adapters/mock_asycuda_world.sql
echo "SELECT hs_code, sum(tax_amount) AS taxes FROM declaration_item di
      JOIN declaration_tax_line tl ON tl.declaration_item_id = di.id GROUP BY hs_code" \
  | python -m compiler compile - | psql -d aw_mock -c 'SET search_path TO aw, public;' -f -
```

## 📦 What's inside

| | |
|---|---|
| 🧭 **Query compiler** (`compiler/`) | Friendly logical SQL — or a no-SQL query spec — → **genuine ASYCUDA World SQL**. Per-instance name overrides; a mock AW database proves the round-trip. |
| 🗄️ **The logical model** (`Sydonia/schema/`) | 55 tables across 8 modules — the friendly names the compiler maps *from*, and a local PostgreSQL sandbox. |
| 📚 **Docs: how to query Sydonia** (`docs/`) | The real ASYCUDA World tables explained, the compiler, guides, and the full ASYCUDA platform reference. Built with MkDocs Material. |
| 🔒 **Privacy-preserving tester** (`mcp/`) | An MCP server that validates/compiles/tests queries returning **metadata only** — never row data. |
| 🤖 **Agent Skills** (`skills/`) | Set up, query, compile, seed, extend and validate — installable into any agent via `npx skills add`. |
| 🧠 **ML blueprint** | Customs risk-engine features mapped to the schema, the selectivity loop, labels from the inspection act. |

## 🌍 Run it on a real Sydonia

The real ASYCUDA World schema is non-public and instance-specific. The compiler
targets the **publicly-documented physical shape** by default; pin your
deployment's exact names once in a small **overrides file**, then every query and
skill runs unchanged against the live system — read-only.

→ [Running on a real ASYCUDA World](https://francoischastel.github.io/sydonia-toolkit/latest/platform/running-on-real-asycuda/)

## 🤖 Agent Skills

```bash
npx skills add FrancoisChastel/sydonia-toolkit
```

Then just ask your agent: *“compile a duty-revenue-by-HS query for our Sydonia and
test it read-only.”* Works in Claude Code, Cursor, Codex, opencode, and more.

## 🧱 How it's built

A faithful, **information-equivalent reconstruction** of the ASYCUDA World data
model, built from **public documentation only** — public ASYCUDA / UNCTAD
programme materials, national ASYCUDA World user manuals, and open ISO / UN / WCO
standards. Every `CREATE TABLE` is tagged `-- src:` (grounded) or `-- inferred`
(honest modelling), and the reconstruction contains **no proprietary schema and
no data from any live customs system**.

## 🤝 Contributing

Issues and PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) and the
[Code of Conduct](CODE_OF_CONDUCT.md). Good first contributions: new verified
queries, mapping entries for a deployment you know, or extra tables in the
compatibility adapter.

## 📣 Share

If this is useful, a ⭐ helps — and there's a ready-to-post thread in
[SOCIAL.md](SOCIAL.md).

## 📜 License

[**AGPL-3.0**](LICENSE). If you run a modified version as a network service, the
AGPL requires you to offer users its source. Bundled third-party reference
material remains its publishers' property — see [NOTICE](NOTICE).

<div align="center">
<sub>Independent project. ASYCUDA and SYDONIA are programmes of UNCTAD; this
project is not affiliated with or endorsed by UNCTAD.</sub>
</div>
