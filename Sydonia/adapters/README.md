# Adapters — run our queries on a real ASYCUDA World database

Our schema (`Sydonia/schema/asycuda.sql`) is a **normalised reconstruction**:
`declaration`, `declaration_item`, `declaration_tax_line`, `ref_*` tables,
snake_case, surrogate `id` keys, FKs. A real ASYCUDA World database is the
opposite — **wide and denormalised**: `SAD_General_Segment`, `SAD_Item`,
`SAD_Tax`, `GEN_TAB`/`BOL_TAB`/`CTN_TAB`, `UN*`/`xx*TAB` reference tables,
`INSTANCE_ID` engine keys, code+name stored inline, the HS code split across
`TAR_HSC_NB1..NB5`.

**The adapter closes that gap with read-only compatibility views.**
[`asycuda_world_compat.sql`](asycuda_world_compat.sql) creates views named
*exactly* like our tables that SELECT-and-alias from the real AW tables. Point
our queries, the [`customs-query`](../../skills/customs-query/) skill and the
[customs-query-tester](../../mcp/customs-query-tester/) at those views and
**everything runs unchanged** against the live system — no query rewrites.

## The read-only rule

Views only. The adapter never writes to, or alters, ASYCUDA's own objects. That
is what lets the customs-query-tester's privacy guarantees (read-only session,
metadata-only results) hold on **real** customs data. For defence in depth,
create a `SELECT`-only role and — ideally — build the views over a
**read-replica**, never primary. (Grant snippet at the bottom of the SQL file.)

## The template is not runnable as-is — filling the TODOs

ASYCUDA World's **physical schema (exact table and column names) is not public**
— it is the #1 "must-request" gap (see
[integration surfaces](../../docs/platform/integration.md)). So the SQL ships as
a **contract + crib**, not a finished script:

- The **contract** is each view's output column set — it must match our schema
  name-for-name, and it already does (verified against `asycuda.sql`).
- The **crib** is the annotation on every line: the real AW source it maps from,
  grounded in [`FIT.md`](../FIT.md) and
  [`xml-messages.md`](../../docs/platform/xml-messages.md).
- Wherever the public docs do **not** pin an exact physical column name, the
  line is marked `-- TODO(instance):`. A DBA fills those once, per deployment.

To fill them:

1. Obtain the real physical schema / ERD (see *What you must request*, item 1,
   in [integration.md](../../docs/platform/integration.md)) from your national
   customs administration or `ASYCUDA@UNCTAD.org`.
2. Confirm the deployment **generation/version** — ASYCUDA++, World, or ASY5 —
   because the physical names differ ([versions](../../docs/platform/versions.md)).
3. Replace each `-- TODO(instance)` name with the real one. The already-pinned
   names (e.g. `SAD_Tax` `COD`/`BSE`/`RAT`/`AMT`/`MOP`, the `GEN_*`/`BOL_*`/`SGS_*`
   prefixes) come straight from `FIT.md`/`xml-messages.md` and are your template.
4. Extend the `ref_*` views for every code table your queries actually join
   (Module 1 has the full `xx*TAB → ref_*` list from `FIT.md`).

## Three deployment shapes

| Your situation | What to do |
|----------------|------------|
| **AW runs on PostgreSQL** | Run `asycuda_world_compat.sql` (with TODOs filled) directly in that database. The views sit in schema `asycuda`; our queries find them via `search_path`. |
| **AW runs on Oracle / MS SQL Server** | Either create equivalent views there in AW's own SQL dialect, or stand up a Postgres front-end that imports the real tables as **foreign tables** via `oracle_fdw` / `tds_fdw`, then build these views on top. The column contracts are identical either way. |
| **You cannot touch production** | Point the views (or the FDW) at a **read-replica**. Nothing here writes, so a replica is sufficient and safest. |

## Pointing the tooling at the adapted database

The [customs-query-tester](../../mcp/customs-query-tester/) MCP server and the
`test_query.sh` fallback both read the **same two settings**. Point them at the
real DB and the `asycuda` view schema:

```jsonc
// .mcp.json  →  mcpServers.customs-query-tester.env
{
  "CUSTOMS_DB": "postgresql://query_tester@replica-host:5432/customs_prod",
  "CUSTOMS_SCHEMA": "asycuda"
}
```

```bash
# script fallback (same guarantees, no MCP)
CUSTOMS_DB="postgresql://query_tester@replica-host:5432/customs_prod" \
CUSTOMS_SCHEMA=asycuda \
  skills/customs-query/scripts/test_query.sh "SELECT count(*) FROM declaration"
```

Use `CUSTOMS_SCHEMA=compat` instead if you created the views in a `compat`
schema rather than `asycuda`. The tester stays read-only and returns metadata
only — column names/types, an aggregate row count, duration — never row data,
so it is safe against a database holding real declarations.

## The ETL alternative (bulk analytics / ML)

Compatibility views are the right tool for **running our queries live** on
modest result sets. For **bulk analytics or training data** — where you want a
full copy in the clean normalised shape — run an **ETL** instead: extract from a
read-replica (or from `<ASYCUDA>` / AWMDS XML exports), transform to our schema,
load into a separate Postgres, and query that copy. The same
`FIT.md`/`xml-messages.md` mapping drives both; the adapter's `SELECT … AS …`
lines are, in effect, the transform step written out. See
[Running on a real ASYCUDA World](../../docs/platform/running-on-real-asycuda.md)
and [the ML risk-engine path](../../docs/guides/ml-risk-engine.md).
