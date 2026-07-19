# The Sydonia query compiler

Write queries against the toolbox's **friendly logical model**; get **genuine
ASYCUDA World SQL** you can actually run. The abstraction is easy; the output is
real.

```
  query spec (no SQL)  ──build──►  LOGICAL SQL  ──compile──►  GENUINE SYDONIA SQL
   from/where/select                declaration,                SAD_General_Segment,
                                     tax_amount, hs_code         SAD_Tax.AMT, TAR_HSC…
```

## Why

ASYCUDA World's real schema is **wide, denormalised and mostly non-public**:
`SAD_General_Segment`, `SAD_Item`, `SAD_Tax`, the `UN*` reference tables;
`INSTANCE_ID` keys; the HS code split across `TAR_HSC_NB1..5`; code+name stored
inline; the general segment repeated into every item row. Writing analytics
against that directly is painful. So you write against the clean logical names
(`declaration`, `declaration_item`, `tax_amount`, `hs_code`) and the compiler
rewrites your query into the genuine shape.

## How it works — the CTE prelude

The compiler finds which logical tables your query references and prepends each
as a **CTE** that `SELECT`s-and-aliases from the real ASYCUDA World tables (per
the mapping). Your query is left untouched:

```sql
WITH declaration_item AS (
  SELECT i.INSTANCE_ID AS id,
         concat(i.TAR_HSC_NB1, i.TAR_HSC_NB2, i.TAR_HSC_NB3, i.TAR_HSC_NB4, i.TAR_HSC_NB5) AS hs_code,
         i.VIT_CIF AS customs_value, …
  FROM SAD_Item i ),
     declaration_tax_line AS (
  SELECT x.TAX_ITM_ID AS declaration_item_id, x.AMT AS tax_amount, … FROM SAD_Tax x )
SELECT di.hs_code, sum(tl.tax_amount) AS taxes    -- your original logical query
FROM declaration_item di JOIN declaration_tax_line tl ON tl.declaration_item_id = di.id
GROUP BY di.hs_code;
```

The result is one standalone statement — runnable anywhere, no privilege to
create views required.

## Install & use

```bash
pip install pyyaml       # the only dependency

# logical SQL -> genuine Sydonia SQL
python -m compiler compile my_query.sql
echo "SELECT * FROM declaration WHERE selectivity_lane_id='RED'" | python -m compiler compile -

# a no-SQL query spec -> logical SQL -> genuine Sydonia SQL
python -m compiler build my_spec.yml
python -m compiler build my_spec.yml --logical      # stop at logical SQL

# regenerate the persistent-view adapter from the mapping
python -m compiler emit-views > Sydonia/adapters/asycuda_world_compat.sql
```

## The mapping (configurable per instance)

`compiler/mappings/asycuda-world.yml` maps each logical table to its real AW
source table and, per column, the physical expression. It targets the
**publicly-documented shape** by default (pinned where public: `SAD_Tax`
COD/BSE/RAT/AMT/MOP, `TAR_HSC_NB1..5`, `PTY_*`, `VIT_CIF/STV`, `VALID_FROM/TO`).

The exact physical column names of a *real* deployment are instance-specific and
non-public. Pin them once in a **per-instance overrides file** (deep-merged over
the base — override only what differs); see
[`mappings/overrides.example.yml`](mappings/overrides.example.yml):

```bash
python -m compiler compile q.sql --overrides mappings/myinstance.yml
```

## Run it — and prove it works without a real Sydonia

`Sydonia/adapters/mock_asycuda_world.sql` is a **mock ASYCUDA World database** in
the documented physical shape, seeded from the toolbox's end-to-end example. It
lets compiled queries actually execute:

```bash
createdb aw_mock
psql -v ON_ERROR_STOP=1 -d aw_mock -f Sydonia/adapters/mock_asycuda_world.sql
python -m compiler compile my_query.sql | psql -d aw_mock -c 'SET search_path TO aw, public;' -f -
```

The round-trip guarantee: the *same* logical query returns the *same* results
whether run on the reconstruction sandbox (logical) or compiled and run on the
mock physical DB (genuine) — verified in CI.

Point it at a **real** instance by loading the persistent views
([`emit-views`](../Sydonia/adapters/asycuda_world_compat.sql)) with your
overrides, then run the compiled SQL there — **read-only**, via the
[`customs-query-tester`](../mcp/customs-query-tester/) so no row data ever leaves
the database.

## Scope

The compiler targets read **analytics** queries (`SELECT` / `WITH`) — the
project's use case. It is not a general SQL transpiler and deliberately does not
handle writes or DDL.
