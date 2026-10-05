**English** | [繁體中文](03-market-data-storage.zh-TW.md)

# 03 · Market Data Pipeline, Data Vendors & Storage

*Research snapshot: 2026-10-05. Prices are public list prices seen in Sep–Oct 2026, in USD unless noted. Check them again before buying. "Pro" means a professional subscriber under exchange rules.*

## TL;DR

- **Lake first, database second.** Use a Parquet lake (Hive-partitioned, zstd) as the system of record and query it with DuckDB or Polars. DuckDB 1.5.x is current, but 1.5 reaches end of life on 2026-11-01 and 2.0.0 is scheduled for 2026-10-21, so plan for 2.0 (or stay on 1.4 LTS until its 2026-11-17 end of life). Add a hot time-series database only for live capture and interactive dashboards: QuestDB (Apache-2.0, v10.0 released Aug 2026) for small teams, or ClickHouse (Apache-2.0, 26.8 LTS) for team or institutional scale. Add a table format (Iceberg, Delta or DuckLake) once you need several writers or reproducible snapshots.
- **Use one normalized event schema with two encodings.** Model the records on Databento DBN and NautilusTrader: int64 nanosecond `ts_event`/`ts_recv`, fixed-point prices and a numeric `instrument_id`. Use Arrow in memory and on the wire, and Parquet at rest. Keep the raw vendor payloads unchanged (bronze layer) so normalization bugs can be replayed.
- **No single affordable vendor covers all four asset classes.** A typical MVP stack:
  - US stocks: Databento or Massive (Polygon.io renamed itself Massive on 2025-10-30).
  - Options: ThetaData or ORATS.
  - Crypto: CCXT (free) plus Tardis.dev.
  - Bonds and rates: FRED/ALFRED and Treasury Fiscal Data (both free), plus TRACE.
  - Taiwan: Shioaji or Fugle, plus FinMind or TEJ.
- **Licensing constrains the design more than technology does.** Non-pro and pro fees differ by about 30x (NYSE L1 at IBKR costs $1.50 vs $45 per month). Most retail plans are for individual use only. Showing data to other users counts as redistribution (TWSE charges NT$60,000/month for the licence plus per-account data fees). A multi-user product needs an entitlement layer from day one.
- **Point-in-time (PIT) correctness is the top data-quality requirement.** It needs:
  - a bitemporal security master
  - unadjusted prices plus corporate-action factors
  - fundamentals as originally reported
  - delisted instruments
  - macro data vintages (ALFRED)

## Key questions

1. What granularity does each strategy need: daily bars, 1-minute bars, L1 trades and quotes, or L2/L3 order books? The choice changes cost by 10–1000x.
2. Is the system for self-use only, or will third parties see the data? Third-party display means redistribution and pro classification.
3. Will it run on one workstation (Windows, macOS or Linux) or on a server or cluster with concurrent users?
4. How do we guarantee, and later reproduce, backtests that are point-in-time and free of survivorship bias?
5. Which normalized schema do backtest replay and live trading share, so the same strategy code runs on both?
6. What is the monthly data budget for each scenario?

## 1. Data types and storage profile

| Data type | Asset classes | Shape / volume | Typical sources | Storage notes |
|---|---|---|---|---|
| Trades & quotes (L1) | All | GBs/day for full US equities | Databento, Massive, IBKR, broker APIs | Partition by date/venue; sort by instrument, ts |
| L2 (MBP-10) / L3 (MBO) | Stocks, futures, crypto | 10–100x L1 | Databento, Tardis.dev, Kaiko | Deltas + periodic snapshots; rebuild books on replay |
| OHLCV bars | All | Small | Every vendor | Derive from trades where possible; vendor bars as cross-check |
| Option chains, IV/greeks | US options (OPRA), TAIFEX TXO, Deribit | OPRA: >1M option instruments; 18 participant exchanges | Databento, Cboe DataShop, ORATS, ThetaData, OptionMetrics | Chain snapshots at fixed cadence; store own IV and vendor IV |
| Bond trades/quotes | Bonds | Sparse, OTC, keyed by CUSIP | FINRA TRACE, ICE, Bloomberg, LSEG | Small; evaluated prices come from models, not trades |
| Rate curves | Bonds, options | Tiny | Treasury, FRED/ALFRED | Store with publication (vintage) date |
| Fundamentals | Stocks | Small, revised | Sharadar, EODHD, TEJ, FinMind | Keep as-reported and restated values, keyed by announcement date |
| Corporate actions | Stocks, ETFs, options | Small, critical | Vendors, exchange, OCC and TAIFEX notices | Separate factor table; adjust on read |
| Security master | All | Small, changes daily | Vendor definitions, OpenFIGI | Bitemporal (valid time + knowledge time) |
| On-chain | Crypto | Large, append-only | Own node/indexer, analytics vendors | Parquet partitioned by block range |
| News / alternative data | Stocks, crypto | Text + metadata | Benzinga (Massive add-on, $99/mo), Tiingo News | Object store; timestamp = first availability |

## 2. Storage engines compared

| Option | Version (Oct 2026) | License | Deployment | Ingest / query | As-of join | Best fit | Watch-outs |
|---|---|---|---|---|---|---|---|
| **Parquet + Arrow + DuckDB/Polars** (+ Iceberg / Delta / DuckLake) | DuckDB 1.5.6 (2026-09-28), 1.4 LTS, 2.0-dev (2.0.0 planned for 2026-10-21; 1.5 EOL 2026-11-01, 1.4 LTS EOL 2026-11-17); Polars 1.44.2 (2.0 in release candidates); PyArrow 25.0.1; Iceberg 1.12.0; Delta 4.4.0; DuckLake 1.0 (2026-04-13) | MIT / Apache-2.0 | Embedded; any OS; laptop to S3 | Batch writes; very fast columnar scans; no server | DuckDB `ASOF JOIN`, Polars `join_asof` | System of record, research, backtests | No live ingest server; small-file compaction; concurrent writers need a table format |
| **QuestDB** | 10.0.1 (2026-08-24); 16 OSS releases in 2025 | Apache-2.0 (Enterprise is commercial) | Single binary or Docker | QWP protocol: ~3.6x ILP ingest; ~220M rows/s Arrow egress (vendor figures) | Native, with `TOLERANCE`; dense algorithm since 9.2 | Live tick capture, OHLC materialized views, dashboards | Replication, tiered storage and OIDC are Enterprise-only |
| **ClickHouse** | 26.8 LTS (patch 2026-10-04) | Apache-2.0 | Server/cluster or Cloud | Very high ingest, strong compression, many concurrent users | `ASOF JOIN` with the `hash`, `full_sorting_merge` or (since 26.6) `parallel_hash` algorithms | Team or institutional analytics, multi-tenant | Ops effort; no native Windows server (use Docker/WSL2) |
| **TimescaleDB** (Tiger Data) | 2.30.2 (2026-09-29) | Apache-2 core + Tiger Data License (TSL) for columnstore and continuous aggregates | PostgreSQL extension | Moderate; full relational SQL | No native ASOF (`LATERAL` workaround) | Postgres shops; security master and bars in one DB | TSL edition cannot be sold as a database service; slower tick scans |
| **kdb+ / KDB-X** | KDB-X GA 2025-11-17; 5.0.20260723 | Commercial; free Community Edition (commercial use allowed) capped at 16 GB RAM, 4 secondary threads and 8 connections | Server | Long-standing reference engine for tick data | Native `aj` / `wj` | Banks and HFT teams with q skills | q skills are scarce; paid licence above the caps |
| **ArcticDB** | 6.26.0 (2026-09-14; 6.27.0 was yanked from PyPI) | BSL 1.1; each version becomes Apache-2.0 two years after release | Python library over S3/LMDB | DataFrame-native; built-in versioning | Via pandas | Python research with versioned datasets | Any business use, even R&D, needs a commercial agreement |
| **InfluxDB 3** | v3.12.0 (2026-10-01) | Core MIT/Apache-2; Enterprise commercial | Server; Parquet on object storage | Strong ingest | Weak | Monitoring the platform itself | Core is built for recent data; few finance features |

For one machine, DuckDB or Polars on Parquet delivers value fastest and runs on every OS, including embedded inside a desktop app. A server database is worth running in two cases:
- you need continuous ingest with sub-second freshness;
- many people query the data at the same time.

## 3. Normalized formats & binary encodings

| Format | Role | Key properties | Status |
|---|---|---|---|
| **Databento DBN** | Wire and file format for normalized market data | Fixed-width structs, self-describing header, zero-copy, zstd; schemas MBO, MBP-1/10, trades, OHLCV, definitions, statistics | Apache-2.0; `dbn` v0.71.0 (2026-09-29); Rust, Python and C bindings (C++ through the separate `databento-cpp` client) |
| **NautilusTrader model** | Engine types + `ParquetDataCatalog` | `QuoteTick`, `TradeTick`, `Bar`, `OrderBookDelta(s)`, `OrderBookDepth10`, `OptionGreeks`, funding/mark price; `ts_event` + `ts_init`; 64- or 128-bit fixed point | LGPL-3.0; v1.231.0 (2026-08-02) stable; 2.0 (Rust-native core, breaking changes) in release candidates, rc5 on 2026-09-15; ships a Databento adapter |
| **Arrow IPC / Flight / ADBC** | Zero-copy exchange across Rust, Python, TypeScript and C# | Columnar, language-neutral; Flight for bulk RPC | Apache-2.0 |
| **Parquet + table format** | At-rest storage | Column stats, predicate pushdown; Iceberg, Delta and DuckLake add snapshots and schema evolution | Universal |
| **QuestDB QWP** | Database ingest and egress | Binary, columnar, over WebSocket; Arrow results | New in 10.0 |

**Proposal:** define an internal canonical schema that is compatible with DBN. Databento data then loads without conversion and NautilusTrader can consume it. Express the schema as Arrow schemas and persist it as Parquet. Every event carries these fields:
- `ts_event`: venue time, UTC nanoseconds
- `ts_recv`: our receipt time
- `instrument_id`: internal ID from the security master
- `venue`
- `price` and `size` as scaled int64 (1e-9)
- `source` and `license_tag`, used to enforce entitlements

## 4. Vendors by asset class

### Stocks

| Vendor | Coverage | Price | Licensing notes |
|---|---|---|---|
| **Databento** | US equities (15 exchanges + ATSs), CME, ICE, OPRA; tick to L3 | Historical data billed per GB. US Equities Standard $199/mo: at launch (Jan 2025) 7 years of OHLCV, 12 months of L1, 1 month of L2/L3, plus live data. The headline Plus $1,750/mo and Unlimited $4,500/mo (annual contracts) are the CME rates. New rates from 2026-06-22: CME Standard up from $179 to $199; Unlimited tier for US Equities $4,000/mo (ICE venues $2,500/mo); US Equities Standard and Plus unchanged | Standard includes live data with no separate licence fees; Plus adds external distribution |
| **Massive** (formerly Polygon.io) | US stocks, options, indices, futures, FX and crypto (crypto is sold under the Currencies plans); flat files | Stocks: Basic free (end-of-day, 2 years), Starter $29 and Developer $79 (both 15-minute delayed), Advanced $199/mo (real-time, 20+ years) | Individual use only (Advanced: non-pro only); separate business plans; `api.polygon.io` still served alongside `api.massive.com` |
| **Tiingo** | 110k securities, 30+ years EOD, IEX intraday, crypto, news | Free; Power $30/mo (individual) or $50/mo (internal commercial use) | Redistribution through sales |
| **Alpha Vantage** | Global EOD/intraday, FX | Free 25 requests/day; $49.99–249.99/mo | Real-time US data needs a separate entitlement |
| **EODHD** | 150k+ tickers, including `.TW` | $19.99–99.99/mo (personal) | Commercial plans are separate |
| **IBKR** | Global, including TWSE/TPEx | Free non-consolidated Cboe One + IEX. US Snapshot & Futures Value Bundle $10/mo, waived at $30 in commissions. NYSE L1 $1.50 non-pro vs $45 pro. TWSE L1 $1/mo; TPEx L1 NT$15/mo | For your own trading only; historical-request pacing limits |
| **Alpaca Market Data** (added in review) | US stocks, options (OPRA), crypto; 7+ years of bars | Free: IEX only, 30 WebSocket symbols, options indicative only. Algo Trader Plus $99/mo: all US exchanges plus real-time OPRA | Aimed at self-directed traders; check redistribution terms before showing data to others |
| **Norgate Data** (added in review) | Survivorship-bias-free daily data for US, ASX and Canadian stocks | 6- or 12-month terms; no intraday or tick data | Windows-only local database; useful for PIT daily backtests, not for live trading |
| **Bloomberg / LSEG / ICE** | All asset classes, reference data, evaluated bonds | Bloomberg Terminal from about $30k per user per year; feeds (B-PIPE, LSEG Tick History, ICE) priced by quote | Enterprise contracts with audit rights |

### Options

| Vendor | Coverage | Price |
|---|---|---|
| Databento OPRA | Consolidated OPRA feed: all US options exchanges (17 at launch in 2023, 18 OPRA participant exchanges today); history from 2023-03-28; point-in-time definitions | Included in subscription plans |
| Cboe DataShop | EOD summary since 2012; intraday quotes and trades | Full-market EOD with greeks: $420/mo or $4,200/yr; one symbol: $35/mo (list price effective 2024-12) |
| ORATS | EOD since 2007; 1-minute data since Aug 2020; tick time & sales since Sep 2022; smoothed IV (SMV) | Data API: Delayed $199, Live $299, Live Intraday $599, All-In $899 per month; tool add-ons $99–299 |
| ThetaData | US options; 1-minute data on Value, tick-level on Standard and Pro; 6, 10 and 14 years of history | Value $40, Standard $80, Pro $160 per month; individual use only, no redistribution or business use |
| OptionMetrics IvyDB | EOD prices with IV and greeks since 1996 | Institutional or academic (via WRDS); priced by quote |

### Crypto

| Vendor | Role | Price |
|---|---|---|
| CCXT | Unified REST/WebSocket API for 100+ exchanges; live data and recent history | Free, MIT licence; v4.5.85 (2026-10-01) |
| Tardis.dev | Tick-level L2/L3, trades, funding, liquidations, options chains; 50+ exchanges; CSV files and replay | Academic $350–650, Solo $700–1,200, Professional $1,000–2,200, Business $3,000–6,000 per month (range = single data plan up to all exchanges); Academic is billed quarterly or yearly only |
| CoinAPI | Normalized REST, WebSocket and FIX feeds, plus flat files | Startup $79, Streamer $249, Pro $599 per month |
| Kaiko | Institutional L1/L2 data and reference rates, CeFi and DeFi | Enterprise pricing by quote |

### Bonds & rates

| Source | Content | Price / access |
|---|---|---|
| FRED / ALFRED | Treasury yields, policy rates, macro; ALFRED vintages give PIT history | Free with an API key |
| Treasury Fiscal Data API | Interest rates, auctions, debt | Free; no key needed |
| FINRA TRACE | Corporate, agency and Treasury trades. Enhanced Historical data released 6 months after the trade (18 months for securitized products) | Agreement + fees. Academic dataset: $500/yr + $500 setup, 36-month delay |
| ICE / Bloomberg BVAL / LSEG | Evaluated prices, curves, reference data | Enterprise pricing |

### Taiwan (TWSE / TPEx / TAIFEX)

| Source | Content | Price / limits |
|---|---|---|
| Shioaji (Sinopac, 永豐金) | Live ticks and bid/ask for stocks, futures and options, plus order routing | Free with a brokerage account. Max 200 subscriptions. Daily traffic of 500 MB–10 GB, depending on trading volume. v1.7.7 (2026-09-29) |
| Fugle MarketData (富果) | Stocks and options over WebSocket; history since 2010 | Free (5 subscriptions); NT$1,499/mo (300 subscriptions); NT$2,999/mo (2,000 subscriptions) |
| FinMind | Aggregated open data: prices, investor flows (籌碼), fundamentals | Free at 300–600 requests/hour; paid sponsor tiers |
| TEJ (台灣經濟新報) | Point-in-time quantitative database; TQuant Lab platform | Commercial or academic subscription |
| TAIFEX (期交所) | Time & sales | Last 30 trading days free to download. Older history by application form, delivered on DVD. No API for historical tick data |
| TWSE OpenAPI / TAIFEX OpenAPI (added in review) | Official free open-data REST APIs (Swagger): TWSE daily quotes, company and dividend data; TAIFEX daily futures/options reports, institutional positions, contract adjustments | Free; end-of-day / daily, not real-time; good for calendars, corporate actions and daily bars |
| TWSE vendor licence | Redistribution of real-time data | Non-brokers: NT$60,000/mo redistribution licence, plus an internet data fee (auto-updating data) of NT$100,000/mo for up to 5,000 accounts and NT$12 per extra account. Data fees above NT$200,000 can offset the licence fee |

## 5. How the four asset classes differ

| Dimension | Stocks | Crypto | Bonds | Options |
|---|---|---|---|---|
| Structure | Exchanges + consolidated tape | 50+ fragmented venues; 24/7; no consolidated tape | OTC, dealer quotes, sparse prints | Exchange-traded; OPRA consolidates; huge instrument count |
| Identifiers | Tickers change over time; CUSIP/ISIN/FIGI; Taiwan numeric codes | Each venue has its own symbols; tickers get reused | CUSIP/ISIN only | OCC symbols and TAIFEX codes; contracts list and expire daily |
| Cost | Bars are cheap; L3 is expensive | Live data free from exchanges; tick history is paid | Rates are free; trade-level data is paid and delayed | EOD is affordable; tick data is the most expensive |
| PIT traps | Splits, dividends, delistings, restatements, index membership | Exchange failures, delisted pairs, wash volume | Bonds that are called or mature disappear; evaluated vs traded prices | Contracts adjusted after corporate actions; choice of IV model |
| Licensing | Exchange display, non-display and pro fees | Mostly exchange terms of service; history vendors license their data | TRACE agreements; licences for evaluated prices | OPRA fees; vendor-specific terms |
| Partitioning | Date / venue | Venue / date; no session boundaries | One small table | Underlying / expiry, with snapshots of the underlying |

## 6. Point-in-time data, quality & versioning

- **Security master.** Make it bitemporal. Each attribute row is valid over `[valid_from, valid_to)` and records when we learned it (`known_at`). It maps every vendor's symbols (Databento IDs, Massive tickers, CCXT market IDs, Shioaji contract codes) to one internal `instrument_id`.
- **Prices.** Store unadjusted prices. Apply corporate-action factors at read time, as of the backtest date.
- **Fundamentals and macro data.** Key them by announcement or publication time. TEJ and Sharadar provide as-reported data; ALFRED provides vintages.
- **Survivorship.** The universe at date *t* is every instrument listed on *t*, including names that were later delisted. Keep historical index constituents too.
- **Quality checks on every ingest.** Failing partitions are quarantined, not silently dropped.
  - gaps against the session calendar, including the TAIFEX after-hours session (夜盤) and 24/7 crypto
  - duplicate or out-of-order timestamps
  - crossed or locked quotes
  - price spikes against a reference price
  - volume that does not match the vendor's daily statistics
  - bars that do not reconcile with the ticks
  - sampled comparisons between vendors
- **Versioning.** Raw files are immutable. Normalized tables use Iceberg, Delta or DuckLake snapshots, or ArcticDB versions. Every backtest records its dataset snapshot IDs and code commit.

## 7. How exchange licensing constrains the design

1. **Display vs non-display.** A person looking at data is display use. Algorithms that consume data (signals, order generation, risk) are non-display use, which is often licensed separately at professional rates.
2. **Pro vs non-pro.** The same NYSE L1 feed costs $1.50 or $45 per month at IBKR. Running the system as a company, or managing other people's money, usually makes a user professional.
3. **Redistribution.** Showing data to any other user, whether in a web or mobile UI or on a shared dashboard, requires redistribution rights:
   - TWSE requires its redistribution licence.
   - Massive's and ThetaData's individual plans forbid it.
   - Tiingo offers it through its sales team.
   - Databento says most of its datasets may be redistributed after 24 hours, subject to each publisher's terms.
4. **Design consequences:**
   - Put a `license_tag` on every dataset, and have an entitlement service that the API gateway and UI check.
   - "Bring your own vendor key" is the cheapest model for multiple users.
   - Show only delayed or derived data on public screens.
   - Keep access logs for exchange usage audits.
   - Never export raw ticks from internal storage.

## 8. Recommendations by scenario

### (a) Solo / 1–3 person MVP (about $0–500/month)

| Layer | Choice |
|---|---|
| System of record | Parquet (zstd) on local NVMe or an S3-compatible bucket; DuckDB + Polars; DuckLake or Iceberg only when needed |
| Hot store | None at first; add single-node QuestDB once live tick capture or dashboards arrive |
| Schema | DBN-compatible Arrow schemas, or the NautilusTrader catalog if Nautilus is the engine |
| US stocks | Massive Starter or Developer ($29–79, 15-minute delayed) for research; Massive Advanced ($199) or Alpaca Algo Trader Plus ($99) for real-time; Databento Standard ($199) when tick or L2 data is needed |
| Options | ThetaData ($40–160) or ORATS (from $199); Cboe DataShop for one-off history |
| Crypto | Capture live data with CCXT into your own Parquet; add Tardis.dev when you need tick history (Academic from $350/mo if eligible; Solo from $700/mo, which is above this budget) |
| Bonds / rates | FRED/ALFRED + Treasury Fiscal Data + IBKR quotes |
| Taiwan | Shioaji or Fugle for live data; FinMind and the free TWSE/TAIFEX OpenAPIs for daily history; TEJ if PIT fundamentals matter; TAIFEX DVD for deep futures and options ticks |
| Avoid | Kafka, a ClickHouse cluster, paid kdb+, and ArcticDB in any commercial use |

### (b) 5–20 person team / institutional

| Layer | Choice |
|---|---|
| System of record | Iceberg (or Delta) on object storage behind a catalog, in bronze, silver and gold layers |
| Hot / interactive | ClickHouse cluster for many users, or QuestDB Enterprise for tick-focused work with HA; KDB-X only if the team knows q |
| Capture | Event bus (see the messaging dimension) → Arrow/DBN → lake + hot database |
| Security master | Dedicated bitemporal service on PostgreSQL |
| Vendors | Databento Plus/Unlimited or direct exchange feeds; Bloomberg/LSEG for reference data, fundamentals and bonds; ICE evaluated pricing; OptionMetrics or Cboe for options history; Tardis.dev Business or Kaiko for crypto; TEJ, plus TWSE/TAIFEX vendor licences if you redistribute |
| Governance | Data contracts, quality SLAs, entitlements, a licence inventory and audits |

## 9. Impact on overall architecture

- **The data platform is its own bounded context** with stable contracts. The flow is vendor adapters → normalizer → lake and hot store → query API (Arrow Flight/ADBC, plus REST for UIs).
- **A backtest replays the same normalized stream that live trading uses.** Strategy code never sees a vendor's format.
- **Clocks.** Use UTC int64 nanoseconds everywhere. Keep trading calendars per venue: TWSE and TAIFEX sessions, US holidays, crypto running 24/7.
- **Cross-platform UI.** The desktop app can embed DuckDB for local research. Web and mobile clients go through an entitlement-aware API.
- **Vendor abstraction.** Vendors rename themselves and change prices every year.

## 10. Risks & pitfalls

- **Vendor churn.** Polygon.io became Massive in Oct 2025, and Databento raised several plan prices in Jun 2026. Vendors also restate history: on 2026-10-31 Databento reassigns `instrument_id` values in Nasdaq TotalView-ITCH data before 2023-11-28 and backfills missing winter after-hours data. Never use a vendor's instrument ID as your own key, and keep vendor snapshots versioned.
- **Source-available licences.** ArcticDB is BSL, TimescaleDB's TSL edition cannot be resold as a database service, KDB-X Community is capped at 16 GB, and high availability is Enterprise-only in QuestDB and InfluxDB.
- **Look-ahead bias.** It creeps in through adjusted prices, restated fundamentals, current index membership and vendor-corrected bars.
- **Timestamp semantics.** Exchange time, SIP time and vendor receipt time differ. Taiwan runs on UTC+8, not UTC.
- **Options data volume.** Full OPRA tick data is huge, so start with EOD or 1-minute chain snapshots.
- **Bonds.** Evaluated prices are model outputs, and TRACE history is delayed.
- **Crypto.** Venues go down, symbols get reused and volume is inflated. CCXT's history depth varies by exchange.
- **Taiwan.** Shioaji has traffic caps and a 200-subscription limit, deep TAIFEX history is offline only, and redistributing data needs TWSE and TAIFEX licences.
- **Parquet maintenance.** Small files pile up and schemas drift, so schedule compaction and version the schemas.

## References

- https://fisd.net/polygon-io-is-now-massive
- https://massive.com/pricing
- https://databento.com/pricing
- https://databento.com/blog/updates-to-subscription-pricing
- https://databento.com/blog/introducing-databento-us-equities
- https://databento.com/blog/opra-data
- https://github.com/databento/dbn
- https://nautilustrader.io/docs/latest/concepts/data
- https://pypi.org/project/nautilus_trader/
- https://github.com/questdb/questdb/releases/tag/10.0.0
- https://questdb.com/blog/questdb-10-release/
- https://questdb.com/blog/questdb-2025-year-in-review/
- https://duckdb.org/news/
- https://duckdb.org/2025/09/16/announcing-duckdb-140.html
- https://duckdb.org/2026/04/13/ducklake-10
- https://pypi.org/project/polars/
- https://pypi.org/project/pyarrow/
- https://github.com/apache/iceberg/releases
- https://github.com/delta-io/delta/releases
- https://github.com/ClickHouse/ClickHouse/releases
- https://clickhouse.com/clickhouse/feature-journey
- https://www.tigerdata.com/docs/about/latest/timescaledb-editions
- https://en.wikipedia.org/wiki/TimescaleDB
- https://code.kx.com/kdb-x/releases/release-notes-latest.html
- https://docs.arcticdb.io/latest/licensing/
- https://pypi.org/project/arcticdb/
- https://influxdata.com/blog/influxdb3-open-source-public-alpha-jan-27
- https://docs.influxdata.com/influxdb3/core/
- https://www.tiingo.com/about/pricing
- https://www.alphavantage.co/premium/
- https://eodhd.com/pricing
- https://www.interactivebrokers.com/en/pricing/market-data-pricing.php
- https://en.wikipedia.org/wiki/Bloomberg_Terminal
- https://datashopcert.livevol.com/option-eod-summary
- https://orats.com/data-api
- https://www.thetadata.net/pricing
- https://wrds-www.wharton.upenn.edu/pages/about/data-vendors/optionmetrics
- https://github.com/ccxt/ccxt
- https://pypi.org/project/ccxt/
- https://tardis.dev/
- https://www.coinapi.io/products/market-data-api/pricing
- https://www.kaiko.com/products
- https://fred.stlouisfed.org/docs/api/fred/
- https://fiscaldata.treasury.gov/api-documentation/
- https://www.finra.org/filing-reporting/trace/historic-academic-data
- https://sinotrade.github.io/tutor/limit/
- https://pypi.org/project/shioaji/
- https://developer.fugle.tw/docs/pricing
- https://pypi.org/project/FinMind/
- https://www.tejwin.com/en/
- https://tquant.tejwin.com/
- https://www.taifex.com.tw/enl/eng9/tradersQAIS
- https://www.twse.com.tw/en/products/information/real-time.html
- https://massive.com/blog/polygon-is-now-massive
- https://databento.com/blog/nasdaq-historical-data-changes-2026-09
- https://duckdb.org/release_calendar
- https://questdb.com/docs/query/sql/asof-join/
- https://clickhouse.com/docs/sql-reference/statements/select/join
- https://github.com/ClickHouse/ClickHouse/blob/master/CHANGELOG.md
- https://kx.com/products/kdb-x/
- https://github.com/influxdata/influxdb/releases/tag/v3.12.0
- https://www.finra.org/rules-guidance/rulebooks/finra-rules/7730
- https://www.opraplan.com/
- https://alpaca.markets/data
- https://norgatedata.com/
- https://openapi.twse.com.tw/
- https://openapi.taifex.com.tw/
- https://github.com/FinMind/FinMind

## Verification log (2026-10)

Adversarial fact-check run on 2026-10-05 against official pages, GitHub release pages, PyPI metadata and exchange or vendor documentation. 54 items checked: 34 confirmed, 15 corrected or added, 5 unverifiable.

### Confirmed

1. Polygon.io was renamed Massive.com on 2025-10-30. Existing API keys stay valid, and `api.polygon.io` keeps working in parallel with `api.massive.com` (FISD notice; Massive blog).
2. Massive stock plans: Basic free, Starter $29, Developer $79, Advanced $199/mo (real-time, 20+ years). All are individual-use plans, Advanced is for non-professionals only, and business pricing is separate (massive.com/pricing).
3. QuestDB 10.0.0 was released 2026-08-06 with QWP (binary, columnar, over WebSocket, for ingest and query results) and Live Views. 10.0.1 followed on 2026-08-24, and the repository is Apache-2.0 (GitHub releases, LICENSE.txt).
4. DuckDB 1.5.6 was released 2026-09-28 and 2.0-dev previews are out. 1.4.0 LTS (2025-09-16) added Iceberg writes, and DuckLake v1.0 shipped 2026-04-13 (duckdb.org news, release calendar, PyPI).
5. KDB-X reached GA on 2025-11-17. The Community Edition is free for personal and commercial use and capped at 16 GiB RAM and 4 secondary threads (plus 8 connections, now added). The latest build is 5.0.20260723 (KX release notes, kx.com product page).
6. ArcticDB is under BSL 1.1, and any business use, including research or dev environments, needs an agreement. Each version converts to Apache-2.0 after two years. The latest usable release is 6.26.0 (2026-09-14) (docs.arcticdb.io, PyPI).
7. The TimescaleDB Community Edition (TSL) is free to self-host but cannot be sold as a service. Timescale became Tiger Data on 2025-06-17, and the current release is 2.30.2 (2026-09-29) (tigerdata.com docs and blog, GitHub).
8. Tardis.dev costs Academic $350–650, Solo $700–1,200, Professional $1,000–2,200 and Business $3,000–6,000 per month, and covers 50+ exchanges (tardis.dev).
9. ThetaData options plans: Value $40, Standard $80, Pro $160 per month, with 6, 10 and 14 years of history, for individual use only (thetadata.net/pricing).
10. IBKR: NYSE Network A L1 costs $1.50 (non-pro) or $45 (pro). TWSE L1 costs USD 1.00. The US Securities Snapshot and Futures Value Bundle costs USD 10, waived at USD 30 in commissions. Cboe One and IEX streaming is free (IBKR market-data pricing page).
11. TWSE non-broker vendors pay a NT$60,000/mo redistribution licence plus NT$100,000/mo for 0–5,000 accounts and NT$12 per extra account. TAIFEX offers 30 trading days of trades for free, sells older history on DVD by application form, and has no API for historical data (twse.com.tw; taifex.com.tw Q&A).
12. QuestDB QWP figures: about 3.6x ILP ingest over a network and 220M rows/s egress into Arrow. ILP and PG wire remain supported. QuestDB shipped 16 OSS releases in 2025, added the dense ASOF algorithm in 9.2, and supports `TOLERANCE` in ASOF joins. Replication, cold storage and OIDC are Enterprise-only (QuestDB 10 blog, 2025 review, docs).
13. ClickHouse 26.8 LTS received a patch on 2026-10-04 (v26.8.17.4-lts).
14. Polars 1.44.2, PyArrow 25.0.1, Apache Iceberg 1.12.0 and Delta Lake 4.4.0 are the current stable releases (PyPI, GitHub).
15. InfluxDB 3 Core is MIT/Apache-2.0 and built for recent data. Historical queries, HA and read replicas are Enterprise features (docs.influxdata.com, README).
16. Databento DBN is Apache-2.0, and `dbn` v0.71.0 was released 2026-09-29 (GitHub, PyPI `databento-dbn`).
17. NautilusTrader is LGPL-3.0-or-later. v1.231.0 was released 2026-08-02, and it has a stable Databento adapter (PyPI).
18. Databento's pricing page lists Standard $199, Plus $1,750 and Unlimited $4,500 (the last two on annual contracts), and says most datasets may be redistributed after 24 hours. The 2026-05-29 notice raises CME Standard from $179 to $199 from 2026-06-22, with existing customers grandfathered for 12 months (databento.com).
19. Databento OPRA history starts 2023-03-28 and covers more than 1M option instruments, with point-in-time definitions (Databento OPRA blog).
20. At its January 2025 launch, Databento US Equities Standard ($199) included 7 years of OHLCV, 12 months of L1 and 1 month of L2/L3, covering 15 exchanges and 30 ATSs (Databento blog).
21. Massive's Benzinga add-on costs $99/mo per dataset.
22. Tiingo Power costs $30/mo for individuals or $50/mo for internal commercial use, covering 110,200 securities with 30+ years of history. Redistribution goes through sales.
23. Alpha Vantage: the free tier allows 25 requests/day, premium costs $49.99–249.99/mo, and real-time US data needs a separate entitlement.
24. EODHD personal plans cost $19.99–99.99/mo for 150k+ tickers, and commercial plans are separate.
25. A Bloomberg Terminal costs roughly $24k–30k+ per user per year (Wikipedia, citing Investopedia 2022). The "about $30k" figure is a reasonable approximation.
26. CCXT is MIT-licensed, supports 100+ exchanges, and v4.5.85 was released 2026-10-01 (GitHub, PyPI).
27. CoinAPI: Startup $79, Streamer $249, Pro $599 per month.
28. Kaiko sells L1/L2 CeFi and DeFi data and reference rates, priced by quote or trial.
29. The FRED/ALFRED API needs a free key and serves vintages. The Treasury Fiscal Data API needs no key or registration.
30. FINRA TRACE academic data costs $500/yr plus a $500 setup fee and has a 36-month delay. Enhanced historical data comes 6 months after the trade (18 months for securitized products) (FINRA Rule 7730; FINRA TRACE page).
31. Shioaji allows 200 subscriptions and 500 MB–10 GB of daily traffic depending on volume. v1.7.7 was released 2026-09-29 (Shioaji docs, PyPI).
32. Fugle: free (5 subscriptions), NT$1,499/mo (300), NT$2,999/mo (2,000). Stock history goes back to 2010 (developer.fugle.tw).
33. FinMind allows 300 requests/hour, or 600/hour with a free token (FinMind README).
34. TEJ TQuant Lab is a Zipline-based PIT research platform, paid after a 14-day free trial (tquant.tejwin.com).

### Corrected or added

1. Databento: the original said "US Equities plan $4,000/mo", implying a standalone plan. In the 2026-05-29 notice, $4,000/mo is the **Unlimited** tier for Databento US Equities, and the headline Plus $1,750 and Unlimited $4,500 are the **CME** rates. US Equities Standard and Plus are unchanged. Source: databento.com/blog/updates-to-subscription-pricing (list grouped under Standard, Plus and Unlimited headings).
2. InfluxDB 3: "v3.11.4 (2026-09-08)" changed to "v3.12.0 (2026-10-01)". Source: GitHub tag v3.12.0; docs release notes.
3. ClickHouse: "ASOF JOIN; sort-merge algorithm; spills to disk since 26.6" changed to ASOF via `hash`, `full_sorting_merge`, or `parallel_hash` (new in 26.6). Automatic spilling arrived for hash joins in 26.4/26.5 and is not ASOF-specific. Source: ClickHouse docs (JOIN) and CHANGELOG.md (26.4, 26.5, 26.6).
4. ORATS: "$99 / $199 / $399 per month" changed to Delayed $199, Live $299, Live Intraday $599, All-In $899 per month. Scenario (a) "ORATS ($99)" changed to "from $199". Source: orats.com/data-api.
5. ThetaData: "tick-level on Pro" changed to tick-level on Standard **and** Pro (Value has 1-minute data). Source: thetadata.net/pricing.
6. Databento OPRA: "All 17 US options exchanges" (2023 figure) changed to 18 current OPRA participant exchanges (MIAX Sapphire and others added since). Source: opraplan.com participant list.
7. Options data shape: ">2M active symbols/day" was attributed to OPRA. Databento's ">2M active symbols" counts all of its datasets combined, so it was removed from the OPRA row. Source: databento.com/blog/opra-data.
8. DBN languages: "Rust, Python, C++" changed to Rust, Python and C bindings, with C++ through the separate `databento-cpp` client. Source: github.com/databento/dbn.
9. Massive: futures were missing from the coverage list (crypto is sold under the Currencies plans). Starter and Developer are 15-minute delayed and Basic is end-of-day only, so scenario (a) no longer implies that the $29–79 plans support live trading. Source: massive.com/pricing.
10. DuckDB lifecycle: the "DuckDB 1.5.x" recommendation now notes that 2.0.0 is scheduled for 2026-10-21, 1.5 reaches EOL on 2026-11-01 and 1.4 LTS on 2026-11-17. Source: duckdb.org/release_calendar.
11. TAIFEX: "No API" changed to "No API for historical tick data". An official free TAIFEX OpenAPI (and a TWSE OpenAPI) does exist for daily reports, institutional positions and contract adjustments, and a row was added. Source: openapi.taifex.com.tw, openapi.twse.com.tw (Swagger specs).
12. TWSE vendor licence: added that data fees above NT$200,000 can offset the NT$60,000 licence fee, and that the NT$100,000 internet fee applies to auto-updating data. Source: twse.com.tw real-time page.
13. Scenario (a) internal contradiction: the $0–500/month budget suggested Tardis.dev "Academic or Solo", but Solo starts at $700/mo and Academic is billed quarterly or yearly only and meant for academic users. The text now says so. Source: tardis.dev pricing.
14. Missing options added: Alpaca Market Data (free IEX; $99/mo for all US exchanges plus OPRA), Norgate Data (survivorship-bias-free daily data, Windows-only), and the TWSE/TAIFEX OpenAPIs. Sources: alpaca.markets/data, norgatedata.com, openapi.twse.com.tw, openapi.taifex.com.tw.
15. Missing risk added: on 2026-10-31 Databento retroactively reassigns `instrument_id` values in pre-2023-11-28 Nasdaq TotalView-ITCH data and backfills winter after-hours data. This supports keeping our own security-master IDs and versioning vendor snapshots. Source: databento.com/blog/nasdaq-historical-data-changes-2026-09.

### Unverifiable

1. Cboe DataShop list prices ($420/mo or $4,200/yr full-market EOD with greeks; $35/mo for one symbol). The pricing page is behind Cloudflare, and the public page shows no list prices. Only "available from January 2012" was confirmed.
2. EODHD coverage of Taiwan (`.TW`). The public exchange list (70 exchanges as of Aug 2026) is not shown without an API key.
3. Databento "exchange fees passed through without markup". Not found on the current pricing page, so it was replaced with the verified statement that Standard includes live data with no separate licence fees.
4. OptionMetrics IvyDB coverage since 1996 and WRDS-only access. Not re-checked in this pass.
5. Current history depth of Databento US Equities Standard beyond the January 2025 launch figures (the pricing page shows only the CME table).
