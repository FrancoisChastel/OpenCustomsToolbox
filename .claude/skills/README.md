# Open Customs Toolbox — Claude Code skills

A suite of [Claude Code](https://claude.com/claude-code) Skills for **using the
customs data model on your own codebase**: set it up, query it, seed it, extend
it, and validate it — all by describing what you want in plain English.

| Skill | Does | Say something like |
|-------|------|--------------------|
| [`customs-schema-setup`](customs-schema-setup/) | Create a database and load schema + seed (+ e2e) in order | *"set up the customs sandbox"* |
| [`customs-query`](customs-query/) | Write correct SQL — knows the `asycuda` search path and join paths | *"duty revenue by HS chapter"* |
| [`customs-seed`](customs-seed/) | Add reference values or generate sample declarations/manifests | *"generate 3 test declarations"* |
| [`customs-extend`](customs-extend/) | Add tables/columns keeping conventions + provenance | *"add a container gate-move table"* |
| [`customs-validate`](customs-validate/) | Re-run the done-conditions: clean load, fully tagged, sources resolve | *"validate the schema is still clean"* |

## Install

Claude Code auto-discovers skills under a project's `.claude/skills/`. To use
these in **your** project:

```bash
git clone https://github.com/FrancoisChastel/OpenCustomsToolbox.git /tmp/oct

# project-scoped (committed with your repo):
mkdir -p .claude/skills && cp -R /tmp/oct/.claude/skills/customs-* .claude/skills/

# or personal (every project on your machine):
mkdir -p ~/.claude/skills && cp -R /tmp/oct/.claude/skills/customs-* ~/.claude/skills/
```

Also bring the model itself — copy the `Sydonia/` directory (at least
`Sydonia/schema/` and `Sydonia/examples/`) so the setup/validate scripts have SQL
to load. The bundled scripts auto-detect `Sydonia/` from your project root and
accept `--schema-dir` / `--sydonia-dir` overrides if it lives elsewhere.

Confirm Claude Code sees them with `/skills`.

## Design

Each skill is a self-contained folder following Anthropic's progressive-disclosure
guidance — a small `SKILL.md` (name + trigger-rich description + concise
instructions) plus bundled `scripts/` or `reference/` files loaded only when
needed:

```
customs-schema-setup/  SKILL.md + scripts/load.sh
customs-query/         SKILL.md + reference/cookbook.sql
customs-seed/          SKILL.md + reference/patterns.sql
customs-extend/        SKILL.md + reference/conventions.md
customs-validate/      SKILL.md + scripts/verify.sh
```

## Scope

These skills **use** the model. They will not decompile ASYCUDA, touch a live
customs system, or fabricate source citations — the same source policy that
governs the model (see `Sydonia/SYDONIA-GOAL.md`) governs the skills. Full
documentation: <https://francoischastel.github.io/OpenCustomsToolbox/skills/>.
