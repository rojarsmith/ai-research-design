**English** | [繁體中文](02-backtesting-engine.zh-TW.md)

# Backtesting Engine Design & Methodology

*Research dimension 02 for the multi-asset (stocks, crypto, bonds, options) analysis, backtesting and trading platform. Facts verified as of 2026-10-05.*

## TL;DR

- **Build two tiers, not one engine.** A vectorized tier (array kernels in Numba or Rust) screens large parameter grids cheaply. An event-driven tier then re-runs the shortlisted strategies with realistic fills, fees, funding, corporate actions and option lifecycle, **using the same strategy code that runs live**. No strategy is promoted on a vectorized result alone.
- **NautilusTrader is the best-fit event-driven core** for a multi-asset platform that must also trade live. It has an LGPL-3.0 Rust core, L1/L2/L3 matching with queue position, and 17 listed integrations (crypto venues, Interactive Brokers, Databento, Tardis and others). It is in the middle of a major-version change: 1.231.0 (2026-08-02) is intended to be the last 1.x release, and 2.0 is at rc6 (release notes dated 2026-10-04; on 2026-10-05 the newest wheel on PyPI was still rc5). Pin exact versions. **LEAN** (Apache-2.0, near-daily builds) is the strongest alternative for teams focused on US equities and options or working in C#.
- **No surveyed engine supports bonds or Taiwan market rules out of the box.** Plan in-house plug-ins: a QuantLib-based bond instrument (accrued interest, coupons, maturities) and a Taiwan rules pack (±10% price limits, call auctions, odd lots, 0.3%/0.15% securities transaction tax 證券交易稅, TAIFEX transaction tax 期貨交易稅). Neither NautilusTrader nor LEAN ships a Taiwan broker adapter, so live Taiwan trading also needs a custom adapter (for example over SinoPac's Shioaji API).
- **Make statistical validation a pipeline stage, not a report.** Log every trial. Before a strategy is promoted, it must pass walk-forward or CPCV out-of-sample tests, the Deflated Sharpe Ratio and the Probability of Backtest Overfitting (PBO).
- **Do not build on dormant engines.** backtrader (last commit 2023-04), QSTrader (last commit 2024-06) and zipline-reloaded (maintenance mode) are fine for learning, but not as a foundation.

## Key questions

1. Which simulation approaches do we need, and how do we keep them consistent?
2. How much execution detail (bars, L1, L2, L3) does each strategy type need?
3. What must be simulated differently for stocks, crypto, bonds and options, including Taiwan and TAIFEX?
4. Which open-source engine can be the core, and what must we build?
5. How do we prevent overfitting when users (or an LLM) run millions of trials?
6. How do we guarantee reproducibility and backtest-live parity?

## Options compared

### 1. Simulation paradigms

| Paradigm | Mechanism | Throughput | Fidelity | Best for | Weak spots |
|---|---|---|---|---|---|
| **Vectorized** | Signals and positions are computed as arrays over all bars. An optional compiled loop handles path-dependent cash and stops | Very high: thousands of configs/sec on bar data | Bar-level. Fills at close or next open; stops are approximate | Universe screens, parameter sweeps, factor research, CPCV folds | Look-ahead bugs are easy (e.g. a missing `shift`). Weak on order types, partial fills, margin and option lifecycle |
| **Event-driven** | A discrete-event loop: data → strategy → orders → simulated venue → fills → portfolio | 1–3 orders of magnitude slower | Tick, quote or order book. Models order types, latency, margin, corporate actions and expiries | Final validation, execution research, paper/live parity | Too slow for broad sweeps. Correctness depends on how good the venue model is |
| **Hybrid** (recommended) | The vectorized tier searches. The top-N candidates are re-run event-driven. Both tiers use one shared feature/indicator library | High overall | Final numbers always come from the event-driven run | The platform default | Needs automated checks that the two tiers agree |

**Agreement rule:** if the two tiers disagree on the same config (e.g. total return differs by more than 10%, or the sign flips), block promotion. The cause is almost always a look-ahead bug or a gap in the cost model.

### 2. Open-source engine survey: maintenance status

| Engine | License | Latest release | Activity | Verdict |
|---|---|---|---|---|
| NautilusTrader | LGPL-3.0 | 2.0.0rc6 (release notes 2026-10-04; PyPI still served rc5, 2026-09-15, on 2026-10-05). 1.231.0 (2026-08-02) is intended as the final 1.x and is still the default (non-pre-release) install | Very active. Cython removed; Rust core + PyO3 | **Active, mid major-version change** |
| LEAN (QuantConnect) | Apache-2.0 | Build 18155 (2026-10-02). Builds roughly every day | Very active | **Active** |
| vectorbt (open source) | Apache-2.0 + Commons Clause | 1.1.1 (2026-09-26). 1.0.0 was 2026-04-22 | Revived; optional Rust engine | **Active** |
| vectorbt PRO | Proprietary, source shared with members | Calendar versions (the public site cites 2026.6.27; newer builds are members-only) | Active; Rust backend | **Active, commercial**: from $25/mo, $240/yr or $500 lifetime |
| hftbacktest | MIT | py 2.4.4 / rust 0.9.4 (2025-12-10). Last commit 2025-12-23 | Quiet for about 9 months | **Slowing**; one maintainer |
| Freqtrade | GPL-3.0 | 2026.9 (2026-09-29), monthly releases | Very active | **Active (crypto only)** |
| Jesse | MIT | 3.2.4 (2026-10-01) | Very active | **Active (crypto only)** |
| bt | MIT | 1.3.0 (2026-10-03) | Active | **Active (portfolio-rebalancing niche)** |
| Backtesting.py | AGPL-3.0 | 0.6.6 (2026-07-22) | Small but active | **Active**; AGPL is a problem for a SaaS |
| zipline-reloaded | Apache-2.0 | 3.1.1 (2025-07-19). Last commit was a CI bump (2025-11-13) | Maintenance | **Legacy / educational** |
| QSTrader | MIT | 0.3.0. Last commit 2024-06-24 | Dormant | **Avoid** for new builds |
| backtrader | GPL-3.0 | 1.9.78.123 (2023-04-19), which is also the last commit | Dormant | **Avoid** for new builds |

*Also active but not surveyed in depth:* **VeighNa (vn.py)** (MIT, 4.4.0 on 2026-05-14, commits in 2026-10), an event-driven Python platform with CTA and portfolio backtesters and many gateways, strongest for Chinese futures; **Lumibot** (GPL-3.0 per its LICENSE file, although the README says MIT; 4.6.4 on 2026-10-03), which runs the same code for backtests and live trading of stocks, options and crypto; and **barter-rs** (MIT, Rust, crypto-focused). None of them changes the recommendation, but they are worth a look before building in-house.

### 3. Main candidates in depth

| Aspect | NautilusTrader | LEAN | vectorbt / PRO | hftbacktest | In-house core |
|---|---|---|---|---|---|
| Paradigm / core | Event-driven. Rust core with a Python API | Event-driven. C# core; algorithms in C# or Python | Vectorized. Numba kernels, optional Rust | Event-driven, tick by tick. Rust, plus Python with Numba | Whatever you design |
| Data / matching | L3 MBO, L2 MBP, L1, quotes, trades and bars. Bars use OHLC sequencing | Tick, second, minute, hour and daily data. Market orders fill at once at the latest price (last tick, quote-bar bid/ask or trade-bar close); limit and stop orders fill on later bars. **Assumes complete fills by default**; no book depth or queue | Bars only | L2 and L3 order-book reconstruction | Must be built |
| Fill realism | Fill model (`prob_fill_on_limit`, `prob_slippage`), queue position, latency model, custom fee model (v2) | Pluggable per-security models: fill, slippage, fee, brokerage, buying power, settlement, short availability | Fixed or percentage fees and slippage. PRO adds limit/stop orders and leverage | Queue-position models, feed and order latency, partial-fill exchange model | Must be built |
| Equities | `Equity` instrument. Corporate actions are not a built-in backtest feature (bring adjusted data or custom events) | **Strongest.** Map and factor files handle splits, dividends and ticker changes. Data on QuantConnect is survivorship-free | Bring adjusted arrays | n/a | Must be built |
| Crypto | Spot, perpetuals, futures and options. Venue adapters for Binance, Bybit, OKX, Deribit, Hyperliquid and others. Backtests settle perpetual funding from `FundingRateUpdate` data (`FundingSettlement` events), so you must load each venue's funding history | Crypto and crypto futures asset classes | Funding is entered as cash-flow arrays (PRO) | **Best fit** for crypto market-making | Must be built |
| Options | `OptionContract`, `OptionSpread`. Expiry and physical settlement handled in v2 RCs. No early-assignment model | **Strongest.** Equity, index and future options; exercise and assignment models; multi-leg strategies | No lifecycle | No | Must be built |
| Bonds | **No bond instrument type** | **No fixed-income asset class** | Only as price series | No | Required (QuantLib) |
| Live parity | Same strategy code in backtest and live; 17 listed integrations (IB, Databento, Tardis …). BitMEX is in the 1.x list but not in the v2 list. No Taiwan broker adapter | Same algorithm in backtest, paper and live; many brokerages | None (research only) | Same code for live Rust bots (Binance Futures, Bybit) | Must be built |
| Scaling | One engine per process; deterministic matching; spread runs over processes or Ray | LEAN CLI optimizer, or QuantConnect cloud | Parameter broadcasting. PRO adds chunking and parallel/distributed engines | One process per run | Free choice |
| License risk | LGPL: changes to the library itself must be shared if distributed | Low | Commons Clause forbids selling it. PRO terms forbid competing products | Low | None |

### 4. Execution-model fidelity ladder

| Level | Data | Fill logic | Good enough for | Supported by |
|---|---|---|---|---|
| 0. Bar close / next open | OHLCV | Fill at next open ± fixed basis points; cap at a share of volume | Daily or weekly rebalancing, low turnover | All engines |
| 1. Intra-bar | OHLCV or finer bars | Assumed OHLC path; pessimistic ordering (the stop is hit before the target); limits fill only if price trades through | Swing trading, stop/limit strategies | Nautilus, LEAN, vectorbt PRO, Freqtrade |
| 2. L1 | Top of book plus trades | Cross the spread; size capped at displayed size; volume participation limit | Intraday trading. **All options work**, because the bid/ask spread is the main cost | Nautilus, LEAN |
| 3. L2 (market-by-price) | Depth at each price | Walk the book; partial fills; temporary price impact | Large orders, crypto | Nautilus, hftbacktest |
| 4. L3 (market-by-order) + latency | Every order event | Queue position, cancel/replace races, feed and order latency | Market making, high-frequency trading | hftbacktest, Nautilus |

**Fees and taxes should be versioned, effective-dated data** (a rules pack), not hard-coded constants:

| Market | What to model |
|---|---|
| US equities | Commission. SEC Section 31 fee on sales (the rate is reset each fiscal year; the FY2026 advisory was published 2026-02-27). FINRA TAF. Borrow fees on shorts. T+1 settlement |
| Taiwan stocks (台股) | Broker commission (legal maximum 0.1425%, usually discounted). Securities transaction tax of **0.3% on sales**. **0.15% for same-day round trips (當沖), extended to 2027-12-31** (Securities Transaction Tax Act, Art. 2-2). 0.1% on ETFs; bond ETFs are exempt through 2026-12-31. T+2 settlement |
| TAIFEX (期交所) | Broker fee per contract. Futures transaction tax: **0.002% of contract value** on stock-index futures, **0.1% of the premium** on options. Options held to settlement are taxed on contract value at the futures rate |
| Crypto | Maker/taker fee tiers and rebates, funding payments, withdrawal and gas fees |
| Bonds | The dealer bid/ask markup (usually the biggest cost). The buyer pays accrued interest. Taiwan's government bonds are exempt from securities transaction tax. The tax on corporate and financial bonds (normally 0.1%) is suspended only until **2026-12-31** (Art. 2-1), so store it as an effective-dated rule and re-check it in early 2027 |

### 5. How the four asset classes differ

| | Equities | Crypto | Options | Bonds |
|---|---|---|---|---|
| **Time and calendar** | Exchange calendars, holidays, half days. TWSE: opening call auction 08:30–09:00, continuous trading until 13:25, closing auction 13:25–13:30; intraday odd-lot (盤中零股) periodic call auctions every 5 seconds from 09:10 | 24/7 in UTC. You must define the daily bar boundary yourself. Venue outages and maintenance | Expiry calendars, including weeklies. TAIFEX TXO: European style, cash settled, weeklies expiring Wednesday or Friday, regular session plus an after-hours session (15:00–05:00) | Day-count conventions (ACT/ACT, 30/360), business-day rules, settlement lags |
| **Prices** | Store **raw prices plus adjustment factors**. Compute signals on adjusted prices, fill at raw prices, and adjust positions on split dates | Prices differ by venue. Distinguish mark, index and last prices; linear vs inverse contracts | Full option-chain snapshots and implied-volatility surfaces. **Fill at bid/ask, not at mid.** Watch for stale quotes | Clean vs dirty price, yield-based quoting. Many quotes are evaluated or indicative, not tradable |
| **Cash flows / carry** | Dividends (net of withholding tax), mergers, spin-offs, ticker changes, borrow fees | **Funding.** Binance defaults to every 8 h (00/08/16 UTC), but some contracts use other intervals, and a contract switches to hourly when the cap or floor is hit. Hyperliquid pays hourly, capped at 4%/h. Model funding as timestamped events for each venue | Exercise and assignment. Early exercise of American options, especially before ex-dividend dates. Pin risk. Physical vs cash settlement | Coupons, accrued interest, amortization, call/put features, redemption at maturity, defaults |
| **Execution quirks** | Taiwan's **±10% daily price limit** (none in the first five trading days after listing): refuse fills when a stock is locked at limit-down or limit-up. Intraday volatility interruption: if a trade would move more than 3.5% from the 5-minute reference price, matching pauses for 2 minutes and resumes by call auction. Tick-size ladders; 1,000-share board lots | Exchange tick/lot filters, liquidation engine, auto-deleveraging (ADL), rate limits | Multi-leg (combo) orders at a net debit or credit; legging risk; wide spreads | Over-the-counter request-for-quote trading, minimum sizes, low chance of a fill |
| **Margin** | Cash or Reg-T; short-sale rules | Cross vs isolated margin, tiered maintenance margin. **The engine must simulate liquidations** | Strategy-based or portfolio margin; exchange margin rules; combos reduce margin | Repo financing and haircuts |
| **Data traps** | Survivorship bias (delisted stocks, 下市櫃), restated fundamentals, history of index membership | Delisted pairs, inflated (wash) volume, history that differs between venues | Huge data volume; contract terms change after corporate actions | Sparse trades and smoothed evaluated prices make volatility look low and the Sharpe ratio look high |

**Bias control for all four classes:** point-in-time (bitemporal) storage, where every record has an event time and a "known at" time; universes that include delisted securities; features that read only data timestamped strictly before the decision (fundamentals at *publication* time, not period end); and a log of every trial, including failures.

### 6. Validation methods

| Method | Question it answers | Compute cost | Pitfalls | Tooling |
|---|---|---|---|---|
| Walk-forward (rolling or anchored) | Does periodic re-optimization hold up out of sample? | Low–medium | Produces only one path; results depend on window choice | All engines; vectorbt splitters |
| Purged K-fold / CPCV | What does the *distribution* of out-of-sample performance look like, with purging and embargo to stop leakage? | High. N groups with k test groups gives C(N,k) splits and (k/N)·C(N,k) paths | Needs the label horizon to set purge and embargo; awkward for stateful strategies | skfolio `CombinatorialPurgedCV` (BSD-3, 1.4.11) |
| Monte Carlo | What are the drawdown and ruin distributions, and how sensitive is the result to costs and fill noise? | Medium | A plain i.i.d. bootstrap destroys autocorrelation; use a block bootstrap | Custom; Jesse includes Monte Carlo |
| Deflated Sharpe Ratio (DSR) | Is the best Sharpe ratio still significant after accounting for the number of trials, skew, kurtosis and sample length? | Trivial | Needs an honest trial count | Formula from Bailey & López de Prado (2014) |
| PBO via CSCV | How likely is it that the in-sample winner ranks below the median out of sample? | Medium. Needs a matrix of returns for every trial | Returns for all trials must be stored | R `pbo` package or custom code |

**Example promotion gate (all must hold):** DSR ≥ 0.95; PBO < 0.2; more than 70% of CPCV paths positive; still profitable with fees and slippage doubled; out-of-sample Sharpe at least 50% of in-sample.

2026 evidence supports enforcing this mechanically. A study that added look-ahead-safe tool registries and logged every evaluation rejected *every* LLM-discovered strategy it tested, while passive benchmarks passed. A human trader's production rule system, evaluated the same way, did not hold up out of sample either (arXiv 2608.27734). **If the platform ever generates strategies with AI, a trial registry is mandatory.**

### 7. Scale-out and reproducibility

| Option | Fits | Notes |
|---|---|---|
| multiprocessing / joblib | One machine | No infrastructure; fine for an MVP |
| Ray (2.59.0, 2026-10-02, Apache-2.0) | Cluster-wide sweeps and CPCV; Ray Tune with Optuna | Actors keep loaded data in memory; autoscales on Kubernetes |
| Dask | DataFrame-based feature computation | Less natural for many independent stateful simulations |
| vectorbt PRO engines | Built-in chunking and parallel/distributed execution | Ties you to the vectorbt API |
| GPU (CuPy, cuDF, JAX) | Large vectorized indicator grids, Monte Carlo | Event logic that depends on the price path maps poorly to GPUs. Speed-ups apply only to the vectorized tier |

**Determinism checklist:** every run writes a manifest (engine version and lockfile, git SHA, container digest, data snapshot hash, config and parameters, RNG seeds, rules-pack version). Use fixed-point or decimal prices (Nautilus uses fixed-point types), a fixed order for same-timestamp events, no wall-clock reads, order-stable reductions when combining parallel results, and "golden-master" regression backtests in CI.

### 8. Backtest-live parity mechanisms

1. **One strategy API and domain model** (instruments, orders, events) for backtest, paper and live. NautilusTrader, LEAN, hftbacktest, Freqtrade and Jesse all follow this pattern.
2. **Engine-owned clock and timers.** Strategies never call `now()` directly.
3. **Venue simulators share configuration with live adapters**: tick and lot filters, order types, fee tiers and rate limits.
4. **Record and replay.** Capture live market data and order events, then replay them through the backtest engine and compare the fills.
5. **Shadow and paper period with transaction-cost analysis (TCA).** Compare live fills against simulated fills (implementation shortfall), and feed the measured slippage back into the fill models.
6. **Daily reconciliation** of positions and cash against the broker. **Drift alarms** halt a strategy when its live P&L falls outside the Monte Carlo 95% band of the backtest.

## Recommendations

### (a) Solo / 1–3 person MVP

1. **Event-driven core: NautilusTrader 2.x.** Pin the exact RC or GA version, and do not start new work on 1.x. If the focus is mostly US equities and options and you want data plus realistic simulation models out of the box, use **LEAN via the LEAN CLI** instead.
2. **Screening tier: vectorbt 1.x (free).** Upgrade to PRO (from $240/yr) for limit orders, chunking and the Rust backend. Review both licenses before offering anything as a service.
3. **Fidelity:** bars plus L1 quotes, pessimistic intra-bar ordering, and costs of spread + fixed basis points + a participation cap. Skip L2/L3.
4. **Asset rollout:** crypto perpetuals (with funding events) plus US and Taiwan equities on daily or minute bars first; then options with L1 chains, expiry and assignment; bonds only through ETF or futures proxies at first.
5. **Validation from day one:** walk-forward, DSR and PBO, with a trial registry stored as Parquet or SQLite.
6. **Compute:** one workstation, using multiprocessing or local Ray.

### (b) 5–20 person team or institutional grade

1. **NautilusTrader 2.x GA as the shared execution and domain core** (LEAN instead for a C# shop focused on US options). Around it, build an in-house extension layer: a bond instrument and cash-flow engine on QuantLib (1.43, BSD-3), a Taiwan/TAIFEX market-rules pack, venue funding events, and effective-dated fee and tax schedules.
2. **Microstructure desks:** use L3 matching in Nautilus or hftbacktest. Calibrate the queue and latency models with your own live fills. Because hftbacktest has a single maintainer, fork it and vendor it in.
3. **Shared research grid:** a Ray cluster on Kubernetes, a trial registry for each user and team that feeds DSR, and storage of every trial's returns so PBO can be computed.
4. **Enforced promotion gates** (CPCV, PBO, DSR, cost stress), with model-risk sign-off and an audit trail.
5. **Parity infrastructure:** record and replay, shadow trading, a TCA feedback loop and golden-master CI.

## Impact on overall architecture

- **The engine fixes the domain model.** Its instruments, orders and events become the canonical schema for paper, live, risk and UI, so choose it before designing the OMS and risk services.
- **Data layer must provide:** bitemporal point-in-time storage; raw prices plus adjustment factors; a security master with delisted securities and corporate actions; per-venue funding history; option-chain snapshots; bond reference data. Store it as Parquet/Arrow readable by both tiers (DuckDB/Polars; the Nautilus data catalog).
- **A market-rules service** serves calendars, tick/lot sizes, price limits and fee/tax schedules as versioned, effective-dated config to backtests, risk checks and live pre-trade checks alike.
- **Compute plane:** job queue, Ray cluster, results/experiment store and trial registry. Backtests always run server-side; desktop, web and mobile clients only submit jobs and display results.
- **Language split:** Python for research; Rust (Nautilus) or C# (LEAN) for the core. Custom fill, fee and instrument models are plug-ins with their own test suites.

## Risks & pitfalls

- **NautilusTrader v2 churn.** The RCs still include breaking changes to configuration and enums (rc6, for example, makes an explicit `fee_model` mandatory for backtest venues). Some lower-use features are deferred past the cutover. Version 1.x (now on the `develop_v1` branch) receives only critical security backports for about three months after the v2 cutover, which followed 1.231.0 on 2026-08-02. Expect that window to close around November 2026.
- **License traps:** Backtesting.py is AGPL (triggered by SaaS use); Freqtrade and backtrader are GPL; vectorbt's Commons Clause forbids selling it; vectorbt PRO's terms forbid competing products; NautilusTrader is LGPL, so keep library changes separate or publish them.
- **Optimistic defaults:** Freqtrade fills at the requested price whenever it lies inside the candle range, with no slippage. LEAN's built-in fill models assume complete fills, and its default assignment model is a heuristic (hourly scan; American options within 4 days of expiry and at least 5% in the money), whereas real early exercise is driven by dividends.
- **Crypto venue drift.** Funding intervals change dynamically, and liquidation and ADL rules differ by venue. A backtest that uses one exchange's rules for another is wrong.
- **Taiwan specifics:** ignoring locked limit-down stocks (跌停鎖死) badly understates exit difficulty; the 0.15% day-trading tax rate expires 2027-12-31 unless extended again; survivorship-free data on delisted Taiwan stocks usually needs a paid vendor.
- **Bond illusions.** Evaluated prices are smoothed, which inflates the Sharpe ratio. Use bid/ask spreads, staleness flags and fill probabilities.
- **Multiple testing at platform scale.** With many users, the number of trials grows very quickly. Deflate results per user and also platform-wide.
- **Single-maintainer dependencies** (hftbacktest, vectorbt) put continuity at risk. Mitigate by vendoring them and wrapping them behind your own interfaces.

## References

- NautilusTrader releases: https://raw.githubusercontent.com/nautechsystems/nautilus_trader/master/RELEASES.md
- NautilusTrader 1.231.0 (final 1.x): https://newreleases.io/project/github/nautechsystems/nautilus_trader/release/v1.231.0
- NautilusTrader 2.0.0rc4: https://newreleases.io/project/github/nautechsystems/nautilus_trader/release/v2.0.0rc4
- NautilusTrader repository (license, integrations): https://github.com/nautechsystems/nautilus_trader
- NautilusTrader backtesting concepts: https://nautilustrader.io/docs/latest/concepts/backtesting
- NautilusTrader instruments: https://nautilustrader.io/docs/latest/concepts/instruments
- LEAN repository: https://github.com/QuantConnect/Lean
- LEAN release feed: https://releasealert.dev/github/QuantConnect/Lean
- LEAN reality models: https://www.quantconnect.com/docs/v2/writing-algorithms/reality-modeling/key-concepts
- LEAN fill models: https://www.quantconnect.com/docs/v2/writing-algorithms/reality-modeling/trade-fills/key-concepts
- LEAN option assignment model: https://www.quantconnect.com/docs/v2/writing-algorithms/reality-modeling/options-models/assignment
- LEAN asset classes: https://www.quantconnect.com/docs/v2/writing-algorithms/securities/asset-classes
- vectorbt on PyPI: https://pypi.org/project/vectorbt/
- vectorbt repository: https://github.com/polakowo/vectorbt
- vectorbt PRO (pricing, terms): https://vectorbt.pro/
- vectorbt PRO Rust backend: https://vectorbt.pro/documentation/rust
- hftbacktest repository: https://github.com/nkaz001/hftbacktest
- hftbacktest releases: https://github.com/nkaz001/hftbacktest/releases
- backtrader commits: https://api.github.com/repos/mementum/backtrader/commits?per_page=1
- QSTrader commits: https://api.github.com/repos/mhallsmoore/qstrader/commits?per_page=1
- zipline-reloaded on PyPI: https://pypi.org/project/zipline-reloaded/
- zipline-reloaded commits: https://api.github.com/repos/stefan-jansen/zipline-reloaded/commits?per_page=1
- Backtesting.py on PyPI: https://pypi.org/project/backtesting/
- bt on PyPI: https://pypi.org/project/bt/
- Jesse on PyPI: https://pypi.org/project/jesse/
- Freqtrade on PyPI: https://pypi.org/project/freqtrade/
- Freqtrade backtesting assumptions: https://www.freqtrade.io/en/stable/backtesting/
- LEAN equity fill model: https://www.quantconnect.com/docs/v2/writing-algorithms/reality-modeling/trade-fills/supported-models/equity-model
- NautilusTrader funding in backtests: https://github.com/nautechsystems/nautilus_trader/blob/master/docs/concepts/backtesting/accounts-and-margin.md
- VeighNa (vn.py): https://github.com/vnpy/vnpy
- Lumibot: https://github.com/Lumiwealth/lumibot
- barter-rs: https://github.com/barter-rs/barter-rs
- Shioaji on PyPI: https://pypi.org/project/shioaji/
- Ray on PyPI: https://pypi.org/project/ray/
- skfolio CombinatorialPurgedCV: https://skfolio.org/generated/skfolio.model_selection.CombinatorialPurgedCV.html
- skfolio on PyPI: https://pypi.org/project/skfolio/
- QuantLib on PyPI: https://pypi.org/project/QuantLib/
- Deflated Sharpe Ratio (SSRN): https://papers.ssrn.com/abstract=2460551
- Probability of Backtest Overfitting (SSRN): https://papers.ssrn.com/abstract=2326253
- Purged cross-validation overview: https://en.wikipedia.org/wiki/Purged_cross-validation
- Honest evaluation of LLM-discovered strategies (2026): https://arxiv.org/abs/2608.27734
- Binance funding rates: https://www.binance.com/en/support/faq/introduction-to-binance-futures-funding-rates-360033525031
- Hyperliquid funding: https://hyperliquid.gitbook.io/hyperliquid-docs/trading/funding
- TWSE trading mechanism: https://www.twse.com.tw/en/products/system/trading.html
- TAIFEX TXO contract specifications: https://www.taifex.com.tw/enl/eng2/tXO
- Taiwan futures transaction tax (MOF eTax): https://www.etax.nat.gov.tw/etwmain/tax-info/understanding/tax-q-and-a/national/future-transaction-tax/filing-payment-and-collection-reward/jDxbO8a
- Taiwan day-trading tax extended to 2027: https://taipeitimes.com/News/biz/archives/2025/01/01/2003829438
- Taiwan Securities Transaction Tax Act (全國法規資料庫): https://law.moj.gov.tw/LawClass/LawAll.aspx?pcode=G0340078
- Taiwan Futures Transaction Tax Act: https://law.moj.gov.tw/LawClass/LawAll.aspx?pcode=G0340079
- SEC Section 31 fee rate advisories: https://www.sec.gov/rules-regulations/fee-rate-advisories

## Verification log (2026-10)

An adversarial fact-check ran on 2026-10-05. It used GitHub (API, tags and branches), PyPI JSON, official documentation, the Taiwan law database and the cited articles. In total, 30 items were checked: 22 confirmed, 5 corrected and 3 unverifiable.

**Confirmed**

1. NautilusTrader 2.0.0rc6 release notes are dated 2026-10-04. 1.231.0 (2026-08-02) is "intended to be" the final 1.x. Critical security backports on `develop_v1` continue for about 3 months after the v2 cutover.
2. NautilusTrader is LGPL-3.0 (GitHub license API; PyPI lists LGPL-3.0-or-later).
3. NautilusTrader's instrument list has no bond or fixed-income type.
4. NautilusTrader v2 details: Cython is removed (rc4 notes), a custom Python fee model was added in rc4, physical option exercise and settlement is handled in the v2 RCs, and the RCs contain breaking configuration changes.
5. LEAN is Apache-2.0. Tag 18155 is on a 2026-10-02 commit, and about 155 build tags have appeared since 2026-08-13.
6. LEAN's pre-built fill models assume complete fills in backtests, and its asset-class list contains no fixed income.
7. LEAN's `DefaultOptionAssignmentModel` scans hourly and considers American options within 4 days of expiry that are more than 5% in the money (source defaults `0.05m` and 4 days).
8. LEAN's US equity data is survivorship-bias free and includes delisted stocks. Splits, dividends and symbol changes come from the US Equity Security Master.
9. vectorbt 1.0.0 was released 2026-04-22 and 1.1.1 on 2026-09-26. It has an optional `vectorbt-rust` engine and is licensed Apache-2.0 with Commons Clause.
10. vectorbt PRO costs from $25/month, $240/year or $500 lifetime. Its terms forbid competing products.
11. hftbacktest py 2.4.4 and rust-v0.9.4 were released 2025-12-10. Its last commit was 2025-12-23 and it is MIT licensed. One maintainer wrote about 900 of its roughly 1,000 commits. It supports L2/L3 data, queue and latency models, and live bots for Binance Futures and Bybit.
12. backtrader 1.9.78.123 (2023-04-19, GPL-3.0) is also its last commit. QSTrader 0.3.0's last commit was 2024-06-24. zipline-reloaded 3.1.1 was released 2025-07-19, and its last commit was a CI bump on 2025-11-13.
13. Freqtrade 2026.9 (2026-09-29, GPLv3), Jesse 3.2.4 (2026-10-01, MIT), bt 1.3.0 (2026-10-03, MIT) and Backtesting.py 0.6.6 (2026-07-22, AGPL-3.0) are current, and each repository had commits in Aug–Oct 2026.
14. Freqtrade fills at the requested price, without slippage, whenever that price is inside the candle's high/low range. Jesse includes Monte Carlo analysis.
15. Taiwan's 0.15% day-trading securities transaction tax runs until 2027-12-31 (Securities Transaction Tax Act Art. 2-2). The normal rate is 0.3% on stocks and 0.1% on ETFs and corporate bonds (Art. 2).
16. The TAIFEX futures transaction tax is 0.002% on stock-index futures and 0.1% of the premium on options. Options cash-settled at or before expiry are taxed on the settlement value at the futures rate (Futures Transaction Tax Act Art. 2).
17. TXO is European style and cash settled, with an after-hours session from 15:00 to 05:00 and weeklies expiring on Wednesday or Friday.
18. Binance funding defaults to every 8 h (00/08/16 UTC) and switches to hourly at the cap or floor. Hyperliquid pays funding hourly, capped at 4%/h.
19. The SEC's FY2026 Section 31 fee-rate advisory was published 2026-02-27.
20. TWSE: call auctions 08:30–09:00 and 13:25–13:30, ±10% daily limit, 1,000-share board lots, T+2 settlement.
21. Tooling versions: skfolio 1.4.11 (2026-10-03, BSD-3), Ray 2.59.0 (2026-10-02, Apache-2.0), QuantLib 1.43 (2026-07-14, BSD-3), and the R `pbo` package (CRAN 1.3.5).
22. arXiv 2608.27734 (2026-08-27) exists. Under leakage-safe, trial-logged evaluation it rejects every LLM-discovered strategy and certifies passive benchmarks.

**Corrected**

1. "20+ / 21+ NautilusTrader integrations" → the README lists 17 on both the v1 and v2 branches, and v2 drops BitMEX (source: README.md on `develop`/`develop_v1`).
2. LEAN "fills on the next bar" → market orders fill immediately at the latest tick, quote-bar bid/ask or trade-bar close, and only limit and stop orders wait for later bars (source: LEAN equity fill model docs).
3. arXiv 2608.27734: "a human trader's production system passed" → it did not persist out of sample, and the paired test against holding gold rejected it (source: arxiv.org/html/2608.27734, Table 7).
4. NautilusTrader funding: "check that your version simulates funding payments" → backtests settle perpetual funding from `FundingRateUpdate` data as `FundingSettlement` events (source: docs/concepts/backtesting/accounts-and-margin.md).
5. NautilusTrader versions: "1.231.0 is the last 1.x; rc6 released 2026-10-04" → 1.231.0 is *intended* as the last 1.x. On 2026-10-05 the rc6 release build was still running, with no rc6 GitHub release or PyPI wheel yet. The newest installable pre-release is rc5 (2026-09-15) (sources: PyPI JSON, GitHub releases/actions).

**Added (missing or stale-prone detail)**

- The Taiwan suspension of transaction tax on corporate and financial bonds and bond ETFs ends 2026-12-31 (Art. 2-1), and government bonds are exempt (Art. 1).
- TWSE intraday odd-lot auctions run every 5 seconds from 09:10. TWSE has a ±3.5% intraday volatility interruption (2-minute pause, then a call auction). Newly listed stocks have no price limit for their first five days (source: TWSE trading-mechanism page).
- NautilusTrader and LEAN have no Taiwan broker adapter. Shioaji 1.7.7 was released 2026-09-29.
- Other engines worth a look: VeighNa (vn.py, MIT, 4.4.0), Lumibot (GPL-3.0 per its LICENSE file, 4.6.4) and barter-rs (MIT).
- The vectorbt PRO price is now stated as "from".

**Unverifiable**

1. The vectorbt PRO "2026.9.x" calendar version. The public site shows only 2026.6.27, and release notes are members-only, so the table now cites the public version.
2. "LEAN does not model order-book depth or queue position." The fill-model docs do not state this, although it is consistent with LEAN's tick/bar data model.
3. "NautilusTrader has no early-assignment model." No early-assignment feature appears in the docs or release notes, but no explicit statement was found either.
