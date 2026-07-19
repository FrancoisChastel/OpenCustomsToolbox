# Sydonia Toolkit — Agent Skills

A suite of standard **[Agent Skills](https://code.claude.com/docs/en/skills)**
(the `SKILL.md` format) for **using the customs data model on your own
codebase**: set it up, query it, seed it, extend it, and validate it — all by
describing what you want in plain English.

These are harness-agnostic: they work in any agent the
[skills CLI](https://github.com/vercel-labs/skills) supports — **Claude Code,
Cursor, Codex, opencode**, and more.

## Install

Install the whole suite into your current project with the
[`skills`](https://skills.sh) CLI — it auto-detects your agent and drops the
skills where that harness discovers them:

```bash
npx skills add FrancoisChastel/sydonia-toolkit
```

Add a single skill with `--skill`:

```bash
npx skills add FrancoisChastel/sydonia-toolkit --skill customs-query
```

Also bring the model itself — copy the `Sydonia/` directory (at least
`Sydonia/schema/` and `Sydonia/examples/`) into your project so the setup and
validate scripts have SQL to load. The bundled scripts auto-detect `Sydonia/`
from your project root and accept `--schema-dir` / `--sydonia-dir` overrides if
it lives elsewhere.

| Skill | Does | Say something like |
|-------|------|--------------------|
| [`customs-schema-setup`](customs-schema-setup/) | Create a database and load schema + seed (+ e2e) in order | *"set up the customs sandbox"* |
| [`customs-query`](customs-query/) | Generate correct SQL — and verify it privacy-preservingly (via the [`customs-query-tester` MCP](../mcp/customs-query-tester/) or a bundled script: metadata only, never row data) | *"duty revenue by HS chapter — and test it"* |
| [`customs-seed`](customs-seed/) | Add reference values or generate sample declarations/manifests | *"generate 3 test declarations"* |
| [`customs-extend`](customs-extend/) | Add tables/columns keeping conventions + provenance | *"add a container gate-move table"* |
| [`customs-validate`](customs-validate/) | Re-run the done-conditions: clean load, fully tagged, sources resolve | *"validate the schema is still clean"* |

## Design

Each skill is a self-contained folder following Anthropic's progressive-disclosure
guidance — a small `SKILL.md` (name + trigger-rich description + concise
instructions) plus bundled `scripts/` or `reference/` files loaded only when
needed:

```
skills/customs-schema-setup/  SKILL.md + scripts/load.sh
skills/customs-query/         SKILL.md + reference/cookbook.sql + scripts/test_query.sh
skills/customs-seed/          SKILL.md + reference/patterns.sql
skills/customs-extend/        SKILL.md + reference/conventions.md
skills/customs-validate/      SKILL.md + scripts/verify.sh
```

Skills live at the top-level `skills/` directory (the canonical layout the
`skills` CLI discovers). For Claude Code in this repo, `.claude/skills` is a
symlink to `skills/`, so Claude Code auto-discovers them here too — confirm with
`/skills`.

## Optional companion MCP: privacy-preserving query testing

`customs-query` pairs with the **[`customs-query-tester` MCP server](../mcp/customs-query-tester/)**:
it lets the model *prove* a generated query runs — read-only session,
single-SELECT allowlist, statement timeout — while returning **only metadata**
(column names/types, row count, duration). Row values never reach the model, so
it is safe to point at a database holding real customs data. Without the MCP,
the skill falls back to `customs-query/scripts/test_query.sh`, which applies the
same guarantees.

This repo ships an `.mcp.json` that registers the server for **Claude Code**.
Other harnesses configure the same command in their own MCP config:

```
python3 mcp/customs-query-tester/server.py
```

with `CUSTOMS_DB` (database name or DSN) and `CUSTOMS_SCHEMA` (default
`asycuda`) in the environment — see the
[server README](../mcp/customs-query-tester/) for the full configuration.

## Scope

These skills **use** the model. They will not decompile ASYCUDA, touch a live
customs system, or fabricate source citations — the same source policy that
governs the model (see `Sydonia/SYDONIA-GOAL.md`) governs the skills. Full
documentation: <https://francoischastel.github.io/sydonia-toolkit/latest/skills/>.
