---
title: Claude Code skills
description: A suite of Claude Code Skills to set up, query, seed, extend and validate the model in your own codebase.
tags:
  - skills
---

# Claude Code skills

The toolbox ships a suite of **[Claude Code](https://claude.com/claude-code)
Skills** so you can drive the customs model in plain English, right inside your
own project. They live in [`.claude/skills/`](https://github.com/FrancoisChastel/OpenCustomsToolbox/tree/main/.claude/skills)
and are focused on one thing: **using the model on your own codebase.**

## The suite

<div class="grid cards" markdown>

-   :material-database-plus:{ .lg .middle } &nbsp;**`customs-schema-setup`**

    ---

    Stand the model up in a database: create it, load schema + seed (+ optional
    e2e) in order, and report a clean/failed result.

    *"Set up the customs sandbox in a local Postgres database."*

-   :material-magnify-scan:{ .lg .middle } &nbsp;**`customs-query`**

    ---

    Write correct SQL against the model — it knows the `asycuda` search path and
    the join paths (declaration → item → tax, manifest → B/L → cargo).

    *"Show me duty revenue by HS chapter last quarter."*

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

Claude Code auto-discovers skills in a project's `.claude/skills/` directory.
To use these on **your own** project, copy the folder in:

```bash
# from the root of your project
git clone https://github.com/FrancoisChastel/OpenCustomsToolbox.git /tmp/oct

# option A — project-scoped (committed with your repo, shared with your team)
mkdir -p .claude/skills
cp -R /tmp/oct/.claude/skills/customs-* .claude/skills/

# option B — personal (available in every project on your machine)
mkdir -p ~/.claude/skills
cp -R /tmp/oct/.claude/skills/customs-* ~/.claude/skills/
```

Also copy the model itself (the `Sydonia/` folder, or at least
`Sydonia/schema/` and `Sydonia/examples/`) so the skills have SQL to load. The
skills accept a `--schema-dir` argument if you put it elsewhere.

Verify Claude Code sees them:

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

## What they deliberately don't do

These skills are for **using** the model. They will not decompile ASYCUDA, touch
a live customs system, or fabricate source citations — the same
[source policy](../provenance/methodology.md#source-policy-non-negotiable) that
governs the model governs the skills.
