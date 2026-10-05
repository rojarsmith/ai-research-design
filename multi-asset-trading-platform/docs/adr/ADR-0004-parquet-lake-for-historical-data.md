**English** | [繁體中文](ADR-0004-parquet-lake-for-historical-data.zh-TW.md)

# ADR-0004: Historical data storage and format: a Parquet lake queried with DuckDB and Polars

## Status

**Proposed** · 2026-10-05 · Scope: scenario 1, with the growth path at trigger T4. A DuckDB 2.0 upgrade check in Phase 0 updates this ADR.

## Context and problem statement

Research, both backtest tiers and golden-master replays need the same historical data: trades and quotes (L1), bars, funding history, option-chain snapshots, rates and macro vintages, plus later L2/L3 books. The data must be point-in-time (PIT) correct and reproducible years later. It must be cheap for one operator to run, on any OS from a laptop to a cloud VM. Where and in what format should it live?

Forces ([03](../../research/03-market-data-storage.md), [09](../../research/09-research-ml-analytics.md)):

- **Workload.** Single writer (our ingest), batch-heavy reads, scenario-1 fidelity of bars plus L1, and no need for sub-second freshness in historical storage. Live capture only has to be recorded for replay.
- **Candidates on 2026-10-05:**
  - Parquet + Arrow + DuckDB/Polars: MIT/Apache-2.0, embedded, any OS.
  - QuestDB 10.0.1: Apache-2.0; replication and OIDC are Enterprise-only.
  - ClickHouse 26.8 LTS: Apache-2.0; server operations; no native Windows server.
  - TimescaleDB 2.30: its TSL features may not be sold as a database service.
  - KDB-X: the free Community edition is capped at 16 GB RAM.
  - ArcticDB: BSL 1.1, and any business use needs an agreement.
  - InfluxDB 3 Core: built for recent data.
- **DuckDB lifecycle.** DuckDB 1.5.6 is current, 2.0.0 is scheduled for 2026-10-21, 1.5 reaches end of life on 2026-11-01, and the 1.4 LTS line on 2026-11-17.
- **Schema.** Databento DBN (Apache-2.0) and NautilusTrader share the same shape: int64 nanosecond `ts_event`/`ts_recv`, scaled-integer prices and a numeric instrument ID.
- **PIT and vendor churn.** Vendors restate history. On 2026-10-31 Databento reassigns some pre-2023 Nasdaq `instrument_id` values. Vendor IDs therefore cannot be our keys, and raw payloads must be kept.
- **Licensing.** Most retail data plans are individual-use only, and redistribution is forbidden by default, so every row needs a licence tag.

## Decision drivers

- Zero operations for one person; runs on Linux, macOS and Windows.
- Reproducibility: a backtest pins exactly the bytes it read.
- Point-in-time correctness and replay of normalization bugs.
- The same files feed research, the vectorized tier and the NautilusTrader catalog.
- Licence compliance per dataset.
- A clear upgrade path to many writers or many concurrent users.

## Considered options

1. **Parquet lake (bronze/silver/gold) with a DBN-compatible schema, content-hashed dataset manifests, and DuckDB plus Polars for queries.** Add a table format and a hot database only on trigger.
2. **A time-series database as the system of record** (QuestDB, ClickHouse or TimescaleDB).
3. **kdb+/KDB-X.**
4. **ArcticDB.**
5. **A lake with Iceberg or DuckLake snapshots from day one.**

## Decision outcome

**Chosen option: 1, "Parquet lake with DuckDB and Polars".** It has zero operations on any OS, its columnar scans are fast enough for bar and L1 research, and content-hashed manifests give single-writer reproducibility without a table-format catalog.

| Aspect | Decision |
|---|---|
| Layers | `bronze/`: raw vendor payloads, immutable. `silver/`: the normalized canonical schema. `gold/`: bars, features and the NautilusTrader `ParquetDataCatalog`. `quarantine/`: partitions that failed checks, with a reason |
| Canonical schema | Arrow schemas compatible with DBN. Shared columns: `ts_event`, `ts_recv` (int64 UTC ns), `instrument_id` (our internal ID), `venue`, `source`, `license_tag`, `ingest_batch`. Prices and sizes are int64 scaled by 1e-9 unless the instrument declares another scale ([ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md)). Tables: `trades`, `quotes` (MBP-1), `bars`, `funding`, `option_chain_snap`, `instrument_status`, `macro_vintage`; `book_mbp10`/`book_mbo` later |
| Files | Parquet with zstd, Hive-style partitions (equities by date and venue; crypto by venue and date; option chains by underlying and expiry), and scheduled compaction |
| Reproducibility | Every partition is content-hashed. A **dataset manifest** lists the partition hashes, and its hash is pinned in every run manifest (`data_manifest_hash`) |
| Point in time | Raw (unadjusted) prices only. Corporate actions are separate events ([ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.md)). Adjusted series are derived views used only for signals. Fundamentals are keyed by announcement time, macro data by ALFRED vintage, and universes include delisted names |
| Quality | Checks on every ingest: gaps against the session calendar (including the TAIFEX night session and 24/7 crypto), duplicate or out-of-order timestamps, crossed quotes, spikes, volume against vendor statistics, bars against ticks, and sampled cross-vendor comparisons. Failures go to quarantine and are never silently dropped. Ingest is idempotent per `(source, partition)` |
| Query engines | DuckDB 1.5.6, **moving to 2.0 after its 2026-10-21 release** (do not stay on 1.5 past 2026-11-01); Polars 1.44.x; PyArrow. pandas 3 only at library boundaries |
| Live capture | NautilusTrader data clients and CCXT capture record into `bronze/` for golden replay. There is no hot time-series database in scenario 1 |
| Placement | Local NVMe on the trading or research host, mirrored to an S3-compatible bucket. Raw ticks are never exported from internal storage |
| What does not live here | The security master, rules packs, corporate-action table and trade ledger live in PostgreSQL 18 ([ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.md), [ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.md)) |
| Licensing | `license_tag` on every row group and manifest, resolved against `data/licence-registry.yaml` ([ADR-0009](ADR-0009-open-source-licensing-strategy.md)) |
| Avoid | ArcticDB (BSL; business use needs an agreement); TimescaleDB TSL features if a service is ever planned; paid kdb+; Kafka as a store; lakeFS v1.87+ (BSL) if a service is ever planned |

**Growth path (trigger T4: live tick capture, several concurrent dashboards, or several writers):**

- QuestDB 10 for live capture.
- DuckLake or Iceberg tables, whose snapshot IDs replace the manifest hash in run manifests.
- ClickHouse 26.8 LTS for many concurrent users.
- Licensed vendors (Databento distribution tiers, Tardis, TEJ, TWSE Data E-Shop) as budgets allow.

### Consequences

**Positive**

- No database server to run for history. The same files serve notebooks, the vectorized tier and `BacktestNode`.
- A backtest from any date can be reproduced byte for byte from its manifest. Raw bronze data lets us replay normalization fixes.
- DBN compatibility means Databento data loads without conversion if it is bought later.
- Our own IDs survive vendor restatements.

**Negative**

- No live-ingest server and no concurrent writers. Both need the T4 additions.
- Small files and schema drift need scheduled compaction and versioned schemas.
- The DuckDB 2.0 migration happens within weeks of the decision and must be tested (Phase 0).
- Content-hash manifests are our own convention, not a standard table format, so tooling around them is ours to maintain.

### Confirmation

- An ingest test suite exercises each quality check and the quarantine path.
- Golden-master backtests pin a manifest hash and reproduce their event hash in CI.
- Schema checks reject non-integer price and size columns and rows without `license_tag`.
- The Phase 0 DuckDB 2.0 check runs the research and ingest test suites on 2.0.

### Revisit when

- **T4** fires (live tick capture, many concurrent readers, or several writers).
- L2/L3 data arrives (T5): add `book_mbp10`/`book_mbo` with periodic snapshots.
- A service is offered (T1): the entitlement service must enforce `license_tag` at the API, and data plans must be business or distribution licences.

## Links

- [Main report: market data storage row and cost tables](../../README.md)
- [Recommended architecture §3.1, §4.3 and §4.9](../../architecture/recommended-architecture.md)
- [Evaluation record: graft 28 and concern 10](../../architecture/evaluation.md)
- Research: [03 Market data storage](../../research/03-market-data-storage.md) · [09 Research and ML](../../research/09-research-ml-analytics.md) · [11 Taiwan localization](../../research/11-taiwan-market-localization.md)
- Related ADRs: [ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md) · [ADR-0009](ADR-0009-open-source-licensing-strategy.md) · [ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.md) · [ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.md)
