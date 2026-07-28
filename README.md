# Meridian — Client Assurance Platform

Customer platform for delivery assurance: one console asking *is this customer on track* and
*which of my other customers has the same problem*.

## Architecture

```
frontend/  TypeScript · React · Vite      — persistent console shell, renders API data only
backend/   Go · net/http · go-duckdb      — REST API over the semantic layer
db/        schema.sql · seed.sql          — the data lake: DuckDB now, BigQuery later
docs/      DATA_LAYER_DESIGN.md           — integration + build design
```

**The rule that holds everything together: no claim without a source record.** The frontend
contains zero data — every figure on screen is served by the Go API from DuckDB semantic views,
which derive from canonical entities, which carry provenance back to staging.

The schema uses only BigQuery-portable SQL (see the header of `db/schema.sql`): DuckDB schemas map
to BQ datasets, `VARCHAR/BIGINT/DOUBLE/TIMESTAMP/JSON` map to `STRING/INT64/FLOAT64/TIMESTAMP/JSON`,
views use standard SQL + `QUALIFY`, no arrays/sequences in base tables.

## Run it

```sh
make db     # build meridian.duckdb from db/schema.sql + db/seed.sql
make api    # build + run the Go API on :8787 (bootstraps the DB itself if missing)
make web    # vite dev server on :5173, proxies /api → :8787
```

`db/seed.sql` is dev fixture data only — it lives in the lake, never in the app, and is skipped
with `MERIDIAN_SEED=0`. Replacing it with real Salesforce/Workday/Jira/JSM/Confluence/Drive
connectors (docs/DATA_LAYER_DESIGN.md §1) changes nothing downstream.

## API

| Endpoint | View it feeds |
|---|---|
| `GET /api/health` | sidebar source freshness (staging.sync_status) |
| `GET /api/signal` | Customer signal: KPI strip, ranked table, decision queue, renewal runway |
| `GET /api/customers/{id}` | Customer 360: outcomes vs clauses, capacity, evidence, epics |
| `GET /api/journal` | Risk journal (append-only audit.journal_entry) |
| `GET /api/correlation` | blast radius, shared-service matrix, correlated symptoms |

## Where derived numbers come from

Health bands, outcome status, velocity trend, blast-radius impact are all defined in
`db/schema.sql` under `semantic.*` — rule-based and documented in-line so a CSM can defend any
band in front of a client. Change the rules there; the API and UI pick them up unchanged.
