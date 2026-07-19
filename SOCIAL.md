# Share kit

Copy-paste posts for launching / sharing **Open Customs Toolbox**. No source
links or specific document names — safe to post as-is.

## One-liner

> Write friendly SQL, compile it to genuine ASYCUDA World (SYDONIA) customs SQL
> you can run read-only. Open-source data model + query compiler + docs.
> https://francoischastel.github.io/OpenCustomsToolbox/latest/

## X / Twitter thread

**1/ (hook)**
> ASYCUDA World runs customs for 100+ countries — but its database is wide,
> denormalised, and mostly non-public. Querying it is painful.
>
> So I built a compiler: write friendly SQL, get genuine Sydonia SQL you can run. 🧵

**2/**
> You write against clean names:
>
> `SELECT hs_code, sum(tax_amount) FROM declaration_item JOIN declaration_tax_line …`
>
> It compiles to the real thing: `SAD_Item`, `SAD_Tax.AMT`,
> `concat(TAR_HSC_NB1..5)`, `INSTANCE_ID` keys — all handled for you.

**3/**
> The friendly layer is a faithful, information-equivalent reconstruction of the
> ASYCUDA World data model — 55 tables, built from public documentation only. It
> doubles as a local sandbox you can spin up in one `psql`.

**4/**
> Real customs data is sensitive. So the runner is read-only and returns
> **metadata only** — column names, row counts, timing — never rows. Point it at
> a live instance safely. The model gets an oracle, not a window.

**5/**
> It’s built for analytics, ML and selectivity: features map straight to the
> schema, and there’s a risk-engine blueprint (read → score → inject → feedback).

**6/**
> Drive the whole thing from your AI agent — Claude Code, Cursor, Codex… —
> `npx skills add FrancoisChastel/OpenCustomsToolbox`. Ask in plain English,
> get a tested, compiled query back.

**7/ (CTA)**
> Docs, quickstart, and the compiler here 👇 open-source (AGPL-3.0). ⭐ if useful.
> https://francoischastel.github.io/OpenCustomsToolbox/latest/

## Hashtags / topics

`#customs` `#ASYCUDA` `#SYDONIA` `#trade` `#PostgreSQL` `#SQL` `#dataengineering`
`#opensource` `#GovTech` `#riskmanagement`

## LinkedIn / longer post

> **Open Customs Toolbox** — an open-source way to query ASYCUDA World (SYDONIA)
> customs data.
>
> The real customs database is wide, denormalised and mostly non-public, which
> makes analytics hard. This project lets you write against a clean, friendly
> data model and **compiles your query into genuine ASYCUDA World SQL** you can
> run — read-only, returning only metadata, so it's safe on real declarations.
>
> It ships a faithful reconstruction of the data model (built from public
> documentation only), a query compiler, full docs on how to query the real
> tables, a privacy-preserving test runner, and Agent Skills to drive it from an
> AI assistant. Built for analytics, ML and selectivity.
>
> AGPL-3.0. Not affiliated with UNCTAD.
