**English** | [繁體中文](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md)

# ADR-0012: Own security master, effective-dated rules packs and one calendar port

## Status

**Proposed** · 2026-10-05 · Scope: scenario 1, with full bitemporal queries deferred to scenario 2. Phase 0 checks (the TAIFEX night-session rule, rounding rules checked against real statements, the 2027 holidays) update this ADR.

## Context and problem statement

Every layer (backtest, pre-trade risk, live execution, accounting) needs the same answers to three questions:

1. **What is this instrument** (identity, precision, tick ladder, lot, multiplier, status) **as known at a given time**?
2. **What are the market rules** (ticks, limits, auctions, fees, taxes, rounding, settlement, margin) **in force on a given date**?
3. **Which trading date and session** does a timestamp belong to?

Forces ([03](../../research/03-market-data-storage.md), [05](../../research/05-instrument-model-pricing-analytics.md), [11](../../research/11-taiwan-market-localization.md)):

- **Vendor identifiers change.** Databento reassigns some pre-2023 Nasdaq `instrument_id` values on 2026-10-31, tickers are reused, and CUSIP needs a licence.
- **Taiwan rules are many and dated:**
  - tick ladders per instrument class (stocks 0.01–5; ETFs 0.01 below NT$50 and 0.05 above);
  - ±10% limits, call auctions and the 3.5% volatility interruption;
  - odd lots as a separate book with 5-second auctions;
  - disposition stocks and sell-first suspensions, refreshed daily;
  - securities transaction tax of 0.3%, or 0.15% for day trades **until 2027-12-31**;
  - the corporate bond and bond-ETF tax holiday, which **ends 2026-12-31** unless extended;
  - the futures transaction tax on both sides.

  TWSE's English page still shows an outdated date for the day-trade tax.
- **US rules also move.** The SEC Section 31 fee resets each fiscal year. FINRA intraday margin replaced PDT on 2026-06-04, but brokers may phase it in until 2027-10-20.
- **Calendars.** `exchange_calendars` has XTAI but no TAIFEX calendar. `pandas_market_calendars` adds CME and SIFMA. QuantLib's Taiwan calendar stops at 2026. The TAIFEX night session runs 15:00–05:00; whether its fills belong to the next trading date is unverified. Typhoon closures are ad hoc, and crypto needs an artificial daily cut.
- **Point in time.** A fully bitemporal security master is costly; the feasibility judge wanted it simplified, while the correctness judges wanted point-in-time data preserved ([evaluation](../../architecture/evaluation.md), graft 37).

## Decision drivers

- One source of truth shared by backtest, risk and live.
- No look-ahead: record what was known, and when.
- Rules that change by date without code changes, and that can be reviewed and audited.
- Exact cost modelling, including rounding and minimum fees.
- Cheap now, with no data loss for richer queries later.

## Considered options

1. **Our own security master in PostgreSQL** (internal `instrument_id`, effective-dated append-only rows that record `known_at`), plus **rules packs as effective-dated YAML in git**, plus **one `CalendarPort`**.
2. **Vendor IDs as keys**, with rules hard-coded per market.
3. **A full bitemporal reference-data service** from day one.
4. **Rules stored only in database tables** and edited through an admin UI.

## Decision outcome

**Chosen option: 1.** It protects us from vendor restatements, makes rules reviewable data, and records `known_at` now, so that "as known at" queries can be added later without migration.

### Security master

| Element | Decision |
|---|---|
| Identity | `instrument_id`: an internal BIGINT surrogate that is never reused. Vendor and venue identifiers live only in `instrument_xref` (FIGI via OpenFIGI, ISIN, OCC OSI, TAIFEX codes, venue symbols, IB conId, Shioaji codes, CCXT market IDs; CUSIP only under licence) |
| Time | Rows are effective-dated (`valid_from`, `valid_to`), append-only, and record `known_at`. Full bitemporal querying is deferred to scenario 2 |
| Attributes | Asset class, MIC, segment (board lot, odd lot, day or night), precisions, `tick_scheme_id`, `quantity_unit`, lot size, multiplier, `calendar_id`, underlying, expiry, status, and effective-dated names `name_en` and `name_zh_tw` (a rename is a new row). Taiwan board-lot and odd-lot books share a `security_id` but have separate `instrument_id`s |
| Daily flags | `instrument_daily_flag`: disposition level, day-trade eligibility (TWTB4U), sell-first suspension (TWTBAU1), notices and limit regime, refreshed pre-open from the TWSE/TPEx/TAIFEX OpenAPIs |
| Borrow and credit data | Datasets with their own `license_tag`, keyed by `instrument_id` and time: **`borrow_availability`** (US: IBKR shortable level and shortable shares from generic tick 236; TW: lendable shares for SBL short sales from TWSE `SBL/TWT96U`), **`borrow_rate`** (US: IBKR's shortable-stock fee files, because the TWS API has no fee-rate tick; TW: broker 融券 and 借券 fee schedules), and **`tw_credit_balance`** (融資融券 balances, quotas, short-sale suspension windows and forced-cover dates from TWSE `MI_MARGN` and TPEx `tpex_mainboard_margin_balance`, `tpex_margin_sbl`, `tpex_margin_trading_term`) |
| Corporate actions | A `corporate_action` table (splits, reverse splits, cash and stock dividends, capital reductions, rights, symbol changes, mergers, spin-offs, delistings, deliverable adjustments) keyed by `announce_ns` for point-in-time use. It feeds the backtest simulation module and the live ledger alike |
| Domain types | `OptionTerms` and `BondTerms` in `tp_domain`. `Bond` is our own type, outside the engine |

### Rules packs

- **YAML in git is the source of truth**, reviewed by pull request and mirrored into PostgreSQL for queries and the UI.
- Packs: `us`, `tw`, `taifex`, `crypto`. Each rule has `valid_from`/`valid_to`, `params`, a `legal_ref` and a `verified_at` date.
- They cover:
  - tick ladders per instrument class, lot sizes and price-limit regimes;
  - auction phases and the volatility interruption;
  - fees and taxes, **rounding modes and minimum fees**;
  - settlement lags and funding intervals;
  - margin tables: Reg T, FINRA intraday, legacy PDT, TAIFEX SPAN parameters;
  - **`short_sale`** sections in `us` and `tw`. US: the locate requirement (Reg SHO Rule 203(b)), the Rule 201 short-sale circuit breaker (after a 10% fall from the prior close, short sales only above the national best bid for the rest of that day and the next), hard-to-borrow recall and buy-in handling, and payment in lieu of dividends. Taiwan: credit-account (信用交易) eligibility, 融券 and SBL short sales (借券賣出) as distinct order types, the below-previous-close (平盤以下) restriction and its exemptions, 融券 suspension and forced-cover dates around shareholder meetings and ex-rights, and per-stock quotas. The FSC has changed the Taiwan short-sale rules at short notice in market stress, so they are effective-dated rules with an emergency-override path;
  - **`financing`** sections in `us` and `tw`: IBKR margin-interest tiers and borrow-fee accrual conventions; 融資 financing ratios, 融券 margin ratios and per-stock adjustments, the maintenance ratio (維持率) and margin-call rule, and broker 融資 interest and 融券/借券 fees. Values are illustrative until checked against broker contracts and statements.
- The loader returns an **immutable, hashed `RulesPack`**, and its hash is part of every strategy bundle and run manifest.
- Known expiries are encoded as `valid_to` dates (for example 2026-12-31 for the bond-ETF holiday and 2027-12-31 for the 0.15% day-trade rate) and re-verified against the law database every year.

### Calendar port

- `CalendarPort` (`session_at`, `trading_date`, `sessions`, `next_open_ns`, `is_trading_day`) is the **only** source of trading dates and session phases.
- Implementations: `exchange_calendars` (XTAI, US), `pandas_market_calendars` (CME, SIFMA), and our own TAIFEX day/night, Taiwan odd-lot and crypto (24/7, 00:00 UTC cut) calendars, plus versioned override files for typhoon closures.
- Load the **2027 TWSE/TAIFEX holidays before year-end**.
- **Confirm the TAIFEX night-session trading-date rule** against TAIFEX's rules before implementing it.
- The scheduler and all jobs use the port; there are no hard-coded clock times.

### Consequences

**Positive**

- Vendor restatements and symbol reuse cannot corrupt our history or positions.
- A tax-rate change or holiday is a reviewed data change, not a code release, and it applies identically in backtest, risk and live.
- Exact cost modelling, including rounding and minimum fees, closes a gap that all three proposals missed.
- Pre-trade checks and the backtest `BorrowModel` ([ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.md)) read the same short-sale and financing rules, so a backtest cannot profit from a short that live trading would refuse, and the G1 cost stress includes borrow and financing costs ([ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.md)).
- Recording `known_at` now means scenario-2 bitemporal queries need no data migration.

**Negative**

- We own symbology mapping, the daily flag refresh and the custom calendars, which is ongoing work.
- Rules packs need yearly legal re-verification and a test per rule. Wrong rules produce wrong P&L silently.
- Effective-dated rows without full bitemporal queries cannot yet answer every "as known at" question.
- The calendar override files depend on a human reacting to ad-hoc closures.
- Historical borrow availability and fee rates are sparse; until history accumulates from daily capture, backtests use a conservative default and flag it in the run manifest.

### Confirmation

- Unit tests per rule: ticks, limits, taxes, rounding and minimum fees, checked against real broker statements in Phase 0. Short-sale tests: a short is refused when not shortable, under SSR, below the previous close in Taiwan, or inside a 融券 suspension window; borrow fees and margin interest match a broker statement.
- Calendar tests: DST shifts, the TAIFEX night-session trading date, typhoon overrides, the 2027 holidays and the crypto daily cut.
- A CI check that every rule has `legal_ref` and `verified_at`, plus a scheduled alert for rules whose `valid_to` is within 60 days.
- Golden-master backtests pin the rules-pack hash.

### Revisit when

- Scenario 2: a dedicated bitemporal reference-data service with "as known at" queries, licensed CUSIP and corporate-action feeds, OCC adjusted-deliverable notices, and a gRPC or Connect API.
- **T8:** bonds beyond ETFs and manual booking → extend `BondTerms` workflows.
- A law changes a dated rule (extension or expiry) → a rules-pack PR.

## Links

- [Main report: reference-data row, design principles 5 and 9, and the Taiwan table](../../README.md)
- [Recommended architecture §3.2, §4.2, §5.3 and §5.6](../../architecture/recommended-architecture.md)
- [Evaluation record: grafts 29, 31, 37 and 40; §6 contradictions on tax dates; §7 open verifications 8, 11 and 13](../../architecture/evaluation.md)
- Research: [03 Market data storage](../../research/03-market-data-storage.md) · [05 Instruments and pricing](../../research/05-instrument-model-pricing-analytics.md) · [02 Backtesting](../../research/02-backtesting-engine.md) · [07 Calendars](../../research/07-system-architecture-messaging.md) · [11 Taiwan localization](../../research/11-taiwan-market-localization.md)
- Related ADRs: [ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md) · [ADR-0004](ADR-0004-parquet-lake-for-historical-data.md) · [ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.md) · [ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.md)
