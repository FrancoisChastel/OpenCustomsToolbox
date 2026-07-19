---
title: Agent Skills
description: A suite of Agent Skills to set up, query, seed, extend and validate the model in your own codebase — installable into any agent harness.
tags:
  - skills
---

# Agent Skills

The toolbox ships a suite of standard **[Agent Skills](https://code.claude.com/docs/en/skills)**
(the `SKILL.md` format) so you can drive the customs model in plain English,
right inside your own project. They live in
[`skills/`](https://github.com/FrancoisChastel/OpenCustomsToolbox/tree/master/skills)
and are focused on one thing: **using the model on your own codebase.**

They are harness-agnostic — installable into **Claude Code, Cursor, Codex,
opencode** and any other agent the [skills CLI](https://github.com/vercel-labs/skills)
supports.

## The suite

<div class="grid cards" markdown>

-   :material-database-plus:{ .lg .middle } &nbsp;**`customs-schema-setup`**

    ---

    Stand the model up in a database: create it, load schema + seed (+ optional
    e2e) in order, and report a clean/failed result.

    *"Set up the customs sandbox in a local Postgres database."*

-   :material-magnify-scan:{ .lg .middle } &nbsp;**`customs-query`**

    ---

    Generate correct SQL against the model — it knows the `asycuda` search path
    and the join paths — and **verify it privacy-preservingly** through the
    companion tester MCP (or a bundled script): metadata only, never row data.

    *"Show me duty revenue by HS chapter last quarter — and test it."*

-   :material-table-plus:{ .lg .middle } &nbsp;**`customs-seed`**

    ---

    Add reference/code values or generate realistic sample declarations and
    manifests that respect every foreign key.

    *"Generate three more import declarations with 2–4 items each."*

-   :material-source-branch-plus:{ .lg .middle } &nbsp;**`customs-extend`**

    ---

    Add tables/columns while preserving the conventions and the provenance trail,
    and update the coverage docs in lock-step.

    *"Add a container gate-movement table to the schema."*

-   :material-check-decagram:{ .lg .middle } &nbsp;**`customs-validate`**

    ---

    Re-run the done-condition checks: clean load, every table tagged, every cited
    source resolves. Your auditable green light.

    *"Validate the customs schema still loads clean and is fully sourced."*

</div>

## Install into your codebase

Install the whole suite into your current project with the
[`skills`](https://skills.sh) CLI — it auto-detects your agent (Claude Code,
Cursor, Codex, opencode, …) and drops the skills where that harness discovers
them:

```bash
npx skills add FrancoisChastel/OpenCustomsToolbox
```

Add a single skill with `--skill`:

```bash
npx skills add FrancoisChastel/OpenCustomsToolbox --skill customs-query
```

Also copy the model itself (the `Sydonia/` folder, or at least
`Sydonia/schema/` and `Sydonia/examples/`) so the skills have SQL to load. The
skills accept a `--schema-dir` argument if you put it elsewhere.

In Claude Code, verify it sees them:

```text
/skills          # lists available skills; customs-* should appear
```

## Use them

Just describe what you want — Claude Code matches the request to a skill:

```text
> set up the customs model in a throwaway database and run the example
> write a query for assessed-vs-paid across all released declarations
> add a "carrier rating" column to trader, keep it sourced
> validate the schema is still clean and fully grounded
```

Each skill is a self-contained `SKILL.md` with bundled scripts and reference
material, following Anthropic's progressive-disclosure guidance — small
front-matter, details loaded only when needed.

## The privacy-preserving query tester (optional MCP)

`customs-query` ships with a companion **MCP server**,
[`customs-query-tester`](https://github.com/FrancoisChastel/OpenCustomsToolbox/tree/master/mcp/customs-query-tester)
(pre-registered in the repo's `.mcp.json`), that closes the generate→verify
loop: the assistant can **prove a query is valid and runs** — against a
database that may contain *real, sensitive customs declarations* — without any
row ever reaching the model.

**The model gets an oracle, not a window.** Four guarantees, enforced
server-side on every call:

| Guarantee | How |
|-----------|-----|
| Nothing can be written | Sessions start with `default_transaction_read_only=on` — the PostgreSQL server itself refuses writes, even data-modifying CTEs |
| Only single SELECTs run | A comment/string-aware scanner rejects multi-statements and every write/DDL/`COPY`/`INTO` keyword before the DB is touched |
| No row data in responses | Result shape via `\gdesc` (describe **without executing**); volume via `SELECT count(*) FROM (<query>) __q` — one aggregate number |
| Bounded execution | `statement_timeout` (default 5 s) + a hard subprocess cap |

Three tools: `describe_schema` (structure), `validate_query` (EXPLAIN-only),
`test_query` (read-only run → columns, types, row count, duration). No MCP
connected? The skill falls back to `scripts/test_query.sh` with the identical
guarantees through plain `psql`. For defence in depth on real data, run it as a
`SELECT`-only database role — the server's README shows the three-line GRANT.

## What they deliberately don't do

These skills are for **using** the model. They will not decompile ASYCUDA, touch
a live customs system, or fabricate source citations — the same
[source policy](../provenance/methodology.md#source-policy-non-negotiable) that
governs the model governs the skills.
