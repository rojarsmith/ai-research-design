**English** | [繁體中文](10-open-source-platforms-build-vs-buy.zh-TW.md)

# Existing Platforms (Open-Source and Commercial) and Build vs. Buy

> Research dimension 10. Snapshot date: 2026-10-05. GitHub activity figures were pulled from the GitHub REST API on that date: commits are default-branch commits since 2026-01-01, and issue closure counts issues opened April to September 2026 that were closed by the snapshot date. Licenses, prices and versions go stale quickly, so re-verify them before any purchase or legal decision.

## TL;DR

- **No existing product covers all four asset classes plus Taiwan plus a cross-platform UI.** Tradable bonds are missing from every mainstream open-source engine: neither NautilusTrader nor LEAN has a bond instrument type. (Brokers such as IBKR do accept bond orders through their APIs, so the gap is the instrument model and analytics, not venue access.) Taiwan (TWSE/TAIFEX) is missing from every mainstream open-source engine. The only engine with Taiwan connectors, StockSharp, **left open source on 2026-07-16**, and its Taiwan connectors live in a separate `StockSharp/Connectors` repo (created 2026-07-13) that has only ever carried the proprietary notice.
- **Two engines are realistic cores.** **NautilusTrader** (LGPL-3.0, Rust core, the most active project with 4.5k commits in 2026, but its v2 is still a release candidate with breaking changes, and upstream does not recommend RCs for live trading with real capital). **QuantConnect LEAN** (Apache-2.0, C#/.NET 10, the most stable choice and the best US options and futures coverage, with frequent NuGet releases: five between 2026-08-21 and 2026-09-25).
- **Recommendation.** A solo developer or a 1-3 person team should **Extend NautilusTrader**, or LEAN for a C#-heavy team or US-options focus, and should write their own Taiwan adapter on Shioaji or Fubon Neo. A 5-20 person or institutional team should **Build** its own OMS, risk, ledger and data plane, and **Integrate** an engine behind a strategy-runtime port. Nobody should **fork** without strong triggers.
- **License traps are real and they move.** OpenBB used AGPL-3.0 from May 2024 until v5.0.0 (2026-09-29), which went back to Apache-2.0. vectorbt carries a Commons Clause. Freqtrade, backtrader and Lumibot are GPL-3.0. StockSharp is now proprietary. Pin versions and scan licenses in CI.
- **Use commercial terminals as optional front-ends or sources of trade signals, not as the core.** This covers MT5, cTrader, NinjaTrader, MultiCharts, TradingView, Sierra Chart and XQ. Each one locks you into its scripting language, its supported brokers and its EULA.

## Key questions

1. Which engine can serve as the core without blocking a future closed-source or SaaS offering?
2. Which engines give real backtest-live parity, with the same strategy code and event-driven fills, across stocks, crypto, bonds and options?
3. Who covers Taiwan stocks and TAIFEX futures and options today, and at what licensing cost?
4. What is the maintenance and bus-factor risk in 2025-2026?
5. When should we Build, Fork, Extend (use a product as the core) or Integrate (borrow components)?

## Options compared

### 1. Open-source landscape: activity and license

| Project | Language | License (commercial implication) | Latest release | 2026 commits | Issues closed (Apr-Sep 2026) | Stars | Status |
|---|---|---|---|---|---|---|---|
| NautilusTrader | Rust core + Python (PyO3) | LGPL-3.0: closed-source strategies are fine; changes to the engine itself must be published if you distribute it | v1.231.0 stable (2026-08-02); v2.0.0rc5 (2026-09-15) | ~4,536 | 531/605 (88%) | 29.6k | Very active; v2 is a Rust-native rewrite. v1 gets only critical security backports (on `develop_v1`, for about three months after the v2 cutover) |
| QuantConnect LEAN | C# (.NET 10) + Python | Apache-2.0: most permissive | NuGet 2.5.18127 (2026-09-25) | 343 | 78/105 (74%) | 21.9k | Active; ships continuously through NuGet, and GitHub "releases" are stale |
| Hummingbot | Python/Cython | Apache-2.0 | v2.17.0 (2026-09-22) | 1,541 | 48/69 (70%) | 20.3k | Active, releases every 1-2 months; crypto market making |
| Freqtrade | Python | GPL-3.0: copyleft applies to anything you distribute | 2026.9 (2026-09-29) | 2,396 | 103/104 (99%) | 55.0k | Very active, monthly releases; crypto only |
| vectorbt (open source) | Python/Numba | Apache-2.0 **+ Commons Clause** (you may not sell it or services based on it) | 1.1.1 (2026-09-26); 1.0.0 shipped 2026-04-22 | 154 | 4/5 | 9.3k | Active; single maintainer |
| vectorbt PRO | Python | Proprietary membership: individual use is "personal, non-commercial", and commercial use needs a negotiated deal | Rolling | n/a | n/a | Private | $25/mo, $240/yr or $500 lifetime |
| backtrader | Python | GPL-3.0 | 1.9.78.123 (2023-04-19) | 0 (last push 2024-08) | n/a | 23.4k | **Unmaintained** |
| Zipline-reloaded | Python | Apache-2.0 | 3.1.1 (2025-07) | 0 | n/a | 2.0k | Maintenance only |
| QuantRocket | Python, Docker (Zipline/Moonshot) | Commercial subscription (Non-Professional or Professional) | 2.11.0 (2025-01-28) | n/a | n/a | n/a | No 2026 release |
| OpenBB (ODP) | Python | **Apache-2.0 since v5**; AGPL-3.0 from May 2024 to Sep 2026 | 5.0.0 (2026-09-29) | 96 | 25/40 (63%) | 73.9k | Data only, no execution; the repo now resolves to `openbq-org/OpenBB` |
| StockSharp | C# | **Proprietary since 2026-07-16**, previously Apache-2.0; its EULA forbids derivative works | Continuous commits (tags are stale) | 1,143 | 3/4 | 10.8k | Active, but **no longer open source**. Free tier (1 connector); Premium $995 and Ultimate $1,995 for the first year |
| Jesse | Python (Rust indicators) | MIT core; **live trading needs a paid license plugin** | 3.2.4 (2026-10-01) | 377 | 10/17 (59%) | 8.6k | Active; crypto only |
| Lumibot | Python | GPL-3.0 | 4.6.4 (2026-10-03) | 1,766 | 3/17 (18%) | 2.1k | Ships fast but closes few issues |
| hftbacktest | Rust + Python (Numba) | MIT | Python 2.4.4 / rust-v0.9.4 (2025-12-10) | 0 (last push 2025-12-23) | 4/10 | 4.8k | Single maintainer and quiet in 2026 |
| Qlib (Microsoft) | Python | MIT | 0.9.7 (2025-08-15) | 16 | 9/30 (30%) | 49.1k | ML research only; activity is slowing |
| VeighNa (vn.py) | Python, Qt desktop GUI | MIT | 4.4.0 (2026-05-14) | 36 | 21/22 (95%) | 45.7k | Active; aimed at mainland China (CTP futures and options, A-shares, ETF options) plus an IB gateway; no Taiwan gateway |

### 2. Capability matrix: asset classes, Taiwan, parity

Legend: ● native or production-grade, ◐ partial, broker-dependent or via a community plugin, ○ none.

| Project | Stocks | Crypto | Bonds | Options | Taiwan (TWSE/TAIFEX) | Venue and broker adapters | Backtest-live parity | Cross-platform |
|---|---|---|---|---|---|---|---|---|
| NautilusTrader | ● (IB, Databento) | ● (Binance, Bybit, OKX, Coinbase, Kraken, Deribit, Hyperliquid, dYdX, Lighter, Polymarket) | ○ (no Bond type) | ● (OptionContract/OptionSpread, Greeks) | ○ (build an adapter) | ~14 venues + Databento/Tardis data | ● (same code, nanosecond event engine) | Linux, macOS ARM, Windows |
| LEAN | ● (US and India equities) | ● (Binance, Bybit, Coinbase, Kraken, Bitfinex, dYdX) | ○ | ● (equity, index and futures options) | ○ | 23 brokerage entries (counting QC paper trading, generic FIX and a CFD/FX group) incl. IB, Schwab, Tradier, Alpaca, Bloomberg EMSX | ● | Windows, Linux, macOS, Docker |
| Hummingbot | ○ | ● (CEX, CLOB DEX and AMM DEX connectors; README cites user volume across 140+ venues) | ○ | ○ | ○ | Crypto only | ◐ | Docker |
| Freqtrade | ○ | ● (spot on ~12 exchanges, futures on 7) | ○ | ○ | ○ | CCXT-based | ● (dry-run) | Windows, macOS, Linux |
| vectorbt / PRO | ◐ (data-agnostic research) | ◐ | ◐ | ◐ | ◐ (if you bring data) | None | ○ (research only) | Any Python |
| QuantRocket | ● | ○ | ○ | ● | ○ | IB, Alpaca | ● | Docker |
| OpenBB | Data | Data | Data (fixed-income router) | Data | ◐ (data providers) | None | ○ | Any Python, REST, MCP |
| StockSharp | ● | ● | ◐ | ● | **●** (Yuanta SPARK, Fubon Neo, SinoPac Shioaji, Taishin Nova, TWSE OpenAPI; proprietary `StockSharp/Connectors` repo) | 389+ connectors | ● | .NET, Windows-centric GUI |
| Jesse | ○ | ● | ○ | ○ | ○ | Crypto | ● | Docker |
| Lumibot | ● | ◐ (CCXT) | ○ | ● (ThetaData, Polygon) | ○ | Alpaca, IB, Tradier, Schwab, Tradovate, ProjectX | ● | Any Python |
| hftbacktest | ○ | ● (L2/L3, queue and latency models) | ○ | ○ | ○ | Binance Futures, Bybit | ● | Rust/Python |
| Qlib | ● (CN/US research) | ○ | ○ | ○ | ○ | None | ○ | Any Python |
| VeighNa (vn.py) | ● (A-shares; overseas through IB) | ○ (no official crypto gateway) | ○ (data feeds only) | ● (CTP, ETF options; OptionMaster Greeks and vol surface) | ○ | CTP family, XTP, TORA, IB and others | ● (same CTA strategy template) | Windows, Linux, macOS |

### 3. Commercial platforms

| Platform | Owner and model (2026) | Price | Scripting | Coverage | Taiwan | Devices | Fit for us |
|---|---|---|---|---|---|---|---|
| MetaTrader 5 | MetaQuotes; distributed through brokers | Free to traders; brokers pay for the license | MQL5; Python package is **Windows-only** (5.0.6231, 2026-09-27); MCP and agentic AI support arrived in build 6060 (2026-07-23), and the AI Assistant was expanded through build 6230 (2026-09-24) | Mostly FX/CFD; exchange stocks, futures and options only if the broker offers them | Not a mainstream TW channel | Windows, Mac, Web, Mobile | Optional FX/CFD execution adapter |
| cTrader | Spotware; distributed through brokers | Free through brokers | C# and Python (cTrader Algo), cloud cBots, Open API | FX/CFD | ○ | Windows, Mac, Web, Mobile | Optional FX/CFD adapter |
| NinjaTrader | **Kraken (Payward)**, acquisition announced 2025-03-20 at $1.5B | Free, $99/mo, or $1,499 lifetime (lower commissions on paid plans) | NinjaScript (C#) | US futures, including Micro Bitcoin and single-stock futures (spot equities and crypto are on Kraken's roadmap) | ○ | Desktop (Windows), Web, Mobile | Futures front-end only |
| MultiCharts | Commercial | Subscription or lifetime (checkout only); data $49/mo | PowerLanguage (EasyLanguage-like), .NET, Python beta | 50+ brokers and feeds incl. IB and crypto exchanges | ◐ | Windows | Strategy prototyping |
| TradingView | Commercial SaaS | About US$13-200/mo (Essential to Ultimate, billed annually); webhooks on every paid plan (Essential and above) | Pine Script v6 (monthly updates, latest Sep 2026) | Charting for all classes; trading through selected brokers | ◐ (charts) | Web, Desktop, Mobile | Signal source through webhooks; charting UX benchmark |
| Sierra Chart | Commercial | $26-56/mo packages | ACSIL (C++) | Futures-centric (CQG, Rithmic, IB, Denali) | ○ | Windows | Low-latency futures desktop |
| XQ 全球贏家 (XQ) | 嘉實資訊 (SysJust) | Not public; usually through a broker | XScript (XS) | Taiwan stocks, TAIFEX futures and options, US stocks | **●** (26 cooperating TW brokers; 自動交易中心 automated trading) | Windows, Mac, iPad, iPhone | Fastest way to Taiwan automation, but closed |

### 4. The main options as a platform core

| Criterion | A. Extend NautilusTrader | B. Extend LEAN (self-hosted) | C. Buy QuantConnect Cloud | D. Build core + Integrate | E. Commercial terminal + webhooks |
|---|---|---|---|---|---|
| Closed-source or SaaS fit | Good. LGPL: keep the engine unmodified or publish your patches. Distributed binaries that statically link Rust crates bring relink obligations | Best (Apache-2.0) | Their terms of service; code and data live on their infrastructure | Full control | EULA; no redistribution |
| Stocks / Crypto / Bonds / Options | ● / ● / ○ / ● | ● / ● / ○ / ● | ● / ● / ○ / ● | You build all of them | Broker-dependent |
| Taiwan | Write an adapter (Shioaji, Fubon Neo) | Write a brokerage plugin | ○ | Write it | XQ ● |
| Backtest-live parity | ● | ● | ● | Expensive to reach | ◐ |
| Latency ceiling | Microsecond-class Rust core | Millisecond-class (.NET) | Shared cloud | Design-dependent | Millisecond, retail-grade |
| API stability (2026) | ◐ (v2 RC renames configs; rc4 broke them; upstream advises against RCs for real-capital live trading) | ● | ● | Your own | ● |
| Time to MVP (estimate) | 1-3 months | 1-3 months | Weeks | 9-18 months | Days |
| Lock-in | Low to medium | Low | High (data entitlements, infrastructure) | None | High (proprietary language) |
| Cost | Free; Pro tier announced (waitlist, no prices) | Free, plus data you buy | $84/mo Researcher, $168/mo Team, $480/mo Trading Firm, $1,272/mo Institution | Engineering salaries | Subscriptions |

### 5. Build / Fork / Extend / Integrate: trigger conditions

| Strategy | Meaning | Choose it when (triggers) | Avoid it when |
|---|---|---|---|
| **Extend** (use as core) | Run Nautilus or LEAN unmodified and add adapters, strategies and services in **separate packages** | Team of 3 or fewer; live trading needed within about 6 months; your instruments fit the engine's model; you accept the upstream release cadence | You need bonds or deep core changes; you must ship desktop binaries that embed LGPL code without a legal review |
| **Fork** | Maintain a patched copy of the engine | Upstream rejects a change you need (for example a Bond instrument, or TW rules such as price limits, the tick ladder, odd lots (零股) and day trading (當沖)); the change goes deep into matching or the domain model; you have 2 or more engineers for rebases | Upstream moves fast: Nautilus has about 4.5k commits in 9 months, so a fork drifts within weeks. With LGPL you must publish modified engine files you distribute |
| **Build** | Your own OMS/EMS, risk, ledger, entitlements, data plane and UI | You **offer a service to others** (multi-tenant, audit, compliance); bonds or RFQ workflows are needed; cross-broker risk netting; strict latency or SLAs; 5 or more engineers with 12 months or more of runway | MVP stage; a single trader |
| **Integrate** (borrow components) | Use libraries behind your own interfaces | Always, for non-core pieces: OpenBB v5 (data, Apache-2.0), vectorbt (research sweeps, internal use), Qlib (ML factors), hftbacktest (crypto microstructure), QuantLib (bond and option pricing, BSD-style license), broker SDKs (Shioaji, Fubon Neo, IB) | GPL or Commons Clause code inside anything you distribute or sell |

## How the four asset classes differ in this dimension

| Asset class | Open-source maturity | Best existing coverage | What you must build or buy |
|---|---|---|---|
| **Stocks** | High | LEAN (US and India), Nautilus through IB, Lumibot, Zipline (research) | **Taiwan**: a broker adapter plus market rules (±10% price limits, tick-size ladder, intraday odd lots (盤中零股), day trading (當沖), T+2 settlement, trading-unit lots). Only StockSharp (now proprietary) and XQ (closed) have them |
| **Crypto** | Highest, and crowded | Nautilus, Freqtrade, Hummingbot, Jesse, hftbacktest | Little. The risk is API churn and exchange failure: Freqtrade 2026.8 removed Bitmart after it shut down operations |
| **Bonds** | **Lowest** | Data only (OpenBB fixed income); no tradable bond type in LEAN or Nautilus. Pricing math exists in QuantLib, and IBKR's TWS API accepts `BOND` contracts by CUSIP or conId | Instrument model (accrued interest, yield and duration, day counts), RFQ/OTC execution, pricing sources. **Build** the model and workflow; reuse QuantLib for analytics and a broker API such as IBKR for listed-bond execution |
| **Options** | Medium | LEAN (chains, equity, index and futures options), Nautilus (OptionContract/OptionSpread, Greeks; IB and Deribit), Lumibot (ThetaData) | TAIFEX TXO (台指選擇權) chains and margin through Shioaji or Fubon Neo; a vol-surface and Greeks service; OPRA-scale data costs. Commercial charting tools are weak at options backtesting |

## Recommendations by scenario

### (a) Solo developer or 1-3 person team MVP

1. **Core: Extend NautilusTrader on the v2 line.** v1 only receives critical security backports, and only for about three months after the v2 cutover, so start on v2. Pin an exact RC or stable tag and wrap the engine behind a thin strategy and adapter interface so you can absorb renames. Upstream does not recommend RCs for live trading with real capital, so use the RC for development, backtesting and paper trading, and gate real-money trading on the stable 2.0.0 release or on your own soak tests. Pick **LEAN** instead if the team is C#-first or US equity and index options are the main product.
2. **Taiwan:** write a Nautilus data and execution adapter on **Shioaji** (1.7.7, 2026-09-29; Windows, Linux and macOS; stocks, futures and options). Use Fubon Neo if you are a Fubon client. Encode TW market rules in your own module. If you need TW automation before any code exists, run **XQ** in parallel for manual or XS strategies.
3. **Research:** use vectorbt for fast parameter sweeps (internal use only) and Qlib for ML factor research. Promote candidates to the event-driven engine for final validation.
4. **Data:** use OpenBB v5 (Apache-2.0) as the research data gateway. **Avoid 4.2 to 4.7.x**, which are AGPL-3.0 (4.0 and 4.1 were still MIT).
5. **Crypto only and you need something this week?** Freqtrade is fine for self-use. Do not build a multi-asset product on it (GPL, crypto-only model).
6. **UI:** none of the engines ships a cross-platform end-user UI. Build a thin client (web first) against your own API and keep engines server-side.

### (b) 5-20 person team or institutional grade

1. **Build** the platform spine: canonical instrument and order model (including bonds), OMS/EMS, pre-trade risk, position and cash ledger, entitlements, audit log, data catalog.
2. **Integrate** an engine as a pluggable **strategy runtime**. Nautilus suits the Rust/Python stack and latency-sensitive crypto and futures work; LEAN suits a .NET stack and US options. VeighNa (MIT, Python with a Qt desktop GUI) is a third candidate only if mainland China futures through CTP matter; it has no Taiwan gateway and no official crypto gateway. Keep the engine behind a port, and do not fork.
3. **Bonds and Taiwan are your own code.** Budget for them explicitly. Evaluate StockSharp's TW connectors only under its EULA; derivative works are prohibited, and older Apache-2.0 snapshots of StockSharp do not include them.
4. **Evaluate commercial options as buy-side accelerators.** Consider QuantConnect Institution ($1,272/mo) for cloud research if data terms allow, and Nautilus Pro (execution algorithms, risk, dashboard) once it reaches GA with published terms.
5. **Legal:** get a license review of LGPL static linking (Rust) for any distributed binary. Ban GPL and Commons Clause code in shipped artifacts, and run SPDX scanning in CI.

## Impact on overall architecture

- **Engine choice decides the language stack.** Nautilus means Rust plus Python; LEAN means C#/.NET plus Python. Make this decision first and record it as an ADR.
- **Use a hexagonal design.** Define the ports `StrategyRuntime`, `ExecutionAdapter`, `MarketDataAdapter` and `ReferenceData`. The domain model is yours, so engine types never leak into the UI or OMS. This also keeps license obligations (LGPL) contained in replaceable modules.
- **Engines run server-side.** Desktop and mobile clients stay thin (API plus WebSocket) and never embed copyleft engines.
- **Use a process boundary for GPL tools.** If you use Freqtrade or Lumibot at all, run them as separate services behind APIs, and get counsel to confirm the derivative-work boundary.
- **Treat the data layer as a shared asset.** Nautilus's Parquet catalog, LEAN's data format and vectorbt all accept columnar data. Standardize on Arrow/Parquet so research and live trading read the same history.

## Risks and pitfalls

- **API churn.** Nautilus v2 RCs removed the legacy Cython package (rc3, 2026-08-21) and renamed core configs (for example `LiveDataClientConfig` became `DataClientConfig` and `LiveExecClientConfig` became `ExecutionClientConfig` in rc4), and no stable v2 date has been published.
- **License drift.** StockSharp moved from Apache-2.0 to a proprietary license on 2026-07-16. OpenBB went MIT, then AGPL (2024-05), then Apache-2.0 (2026-09). Record the license per pinned version.
- **Provenance.** The OpenBB GitHub repo now resolves to `openbq-org` (an org created 2026-09-11). Verify package signatures and origin before upgrading.
- **Bus factor.** vectorbt and hftbacktest each depend on one maintainer, and hftbacktest has had no commits in 2026. backtrader is dead. QuantRocket has had no release since January 2025.
- **Parity illusions.** Vectorized backtests ignore queue position, latency and partial fills. Validate on an event-driven engine with realistic fill models (hftbacktest-style for microstructure).
- **Lock-in.** Pine (TradingView), MQL5, NinjaScript and XScript strategies are not portable. QuantConnect cloud data cannot be freely exported. Jesse's live trading needs a license key.
- **Platform constraints.** The MetaTrader5 Python bridge is Windows-only. Several TW broker SDK samples target Windows (WPF). Check Linux support before you design server deployment.
- **Regulation.** Offering signals or automated management to others pushes you toward Build-level audit and entitlement features regardless of the engine. In Taiwan, paid securities advice needs an FSC-licensed securities investment consulting enterprise (SICE, 投顧), discretionary management (全權委託) needs separate FSC approval, and futures advice falls under futures advisory licensing. In the US the equivalents are RIA and CTA registration.

## References

- NautilusTrader repo, license, adapters, v2 status (including the note against using RCs for live trading): https://github.com/nautechsystems/nautilus_trader
- NautilusTrader releases: https://github.com/nautechsystems/nautilus_trader/releases
- NautilusTrader v2.0.0rc4 notes: https://newreleases.io/project/github/nautechsystems/nautilus_trader/release/v2.0.0rc4
- NautilusTrader instruments: https://nautilustrader.io/docs/latest/concepts/instruments/
- NautilusTrader Pro: https://nautilustrader.io/pro/
- LEAN repo: https://github.com/QuantConnect/Lean
- LEAN NuGet: https://www.nuget.org/packages/QuantConnect.Lean/
- QuantConnect brokerages: https://www.quantconnect.com/docs/v2/cloud-platform/live-trading/brokerages
- QuantConnect asset classes: https://www.quantconnect.com/docs/v2/writing-algorithms/securities/asset-classes
- QuantConnect pricing: https://www.quantconnect.com/pricing.md
- Hummingbot repo: https://github.com/hummingbot/hummingbot
- Hummingbot release notes: https://hummingbot.org/release-notes/
- Freqtrade repo and releases: https://github.com/freqtrade/freqtrade , https://github.com/freqtrade/freqtrade/releases
- vectorbt repo and PyPI: https://github.com/polakowo/vectorbt , https://pypi.org/project/vectorbt/
- vectorbt PRO membership and FAQ: https://vectorbt.pro/become-a-member , https://vectorbt.pro/faq/
- backtrader: https://github.com/mementum/backtrader , https://pypi.org/project/backtrader/
- Zipline-reloaded: https://pypi.org/project/zipline-reloaded/
- QuantRocket: https://www.quantrocket.com/docs/release-notes/ , https://www.quantrocket.com/pricing/
- OpenBB repo, license history, PyPI: https://github.com/openbq-org/OpenBB , https://github.com/openbq-org/OpenBB/commits/develop/LICENSE , https://pypi.org/project/openbb/
- StockSharp repo, license change commit, EULA, pricing: https://github.com/StockSharp/StockSharp , https://github.com/StockSharp/StockSharp/commit/81ecf7ad892f43bd39efc1bc0dbdf273bae32bf0 , https://stocksharp.com/en/products/eula/ , https://stocksharp.com/pricing/
- Jesse: https://github.com/jesse-ai/jesse , https://pypi.org/project/jesse/ , https://docs.jesse.trade/docs/livetrade
- Lumibot: https://github.com/Lumiwealth/lumibot , https://pypi.org/project/lumibot/
- hftbacktest: https://github.com/nkaz001/hftbacktest , https://pypi.org/project/hftbacktest/
- Qlib: https://github.com/microsoft/qlib , https://pypi.org/project/pyqlib/
- VeighNa (vn.py): https://github.com/vnpy/vnpy , https://pypi.org/project/vnpy/
- QuantLib: https://github.com/lballabio/QuantLib
- IBKR TWS API bond contracts: https://interactivebrokers.github.io/tws-api/basic_contracts.html
- StockSharp connectors repo (proprietary notice): https://github.com/StockSharp/Connectors
- Taiwan Securities Investment Trust and Consulting Act: https://law.moj.gov.tw/ENG/LawClass/LawAll.aspx?pcode=G0400121
- MetaTrader 5: https://www.metatrader5.com/en/releasenotes , https://pypi.org/project/MetaTrader5/
- cTrader Algo: https://help.ctrader.com/ctrader-algo/
- NinjaTrader pricing and Kraken acquisition: https://www.ninjatrader.com/pricing/ , https://blog.kraken.com/news/kraken-to-acquire-ninjatrader
- MultiCharts: https://www.multicharts.com/ , https://www.multicharts.com/purchase/
- TradingView: https://www.tradingview.com/pricing/ , https://www.tradingview.com/pine-script-docs/release-notes/
- Sierra Chart packages: https://www.sierrachart.com/index.php?page=doc/Packages.php
- XQ: https://www.xq.com.tw/ , https://www.xq.com.tw/broker , https://www.xq.com.tw/xstrader/
- Shioaji (SinoPac): https://pypi.org/project/shioaji/
- Fubon Neo API: https://www.fbs.com.tw/TradeAPI/en/docs/welcome/
- GitHub REST API (activity metrics method): https://docs.github.com/en/rest

## Verification log (2026-10)

Adversarial fact-check run on 2026-10-05 against GitHub (web and REST/GraphQL API), PyPI JSON metadata, NuGet and the vendors' own pages. Summary: 53 items checked, 33 confirmed, 13 corrected or refined in the text above, 7 unverifiable.

### Confirmed

1. NautilusTrader is LGPL-3.0 (GitHub license API; PyPI `LGPL-3.0-or-later`). Latest stable is v1.231.0 (2026-08-02) and latest pre-release is v2.0.0rc5 (2026-09-15); v2 is the Rust + PyO3 runtime (GitHub releases, PyPI).
2. Nautilus v2.0.0rc4 (2026-09-02) renamed `LiveDataClientConfig` to `DataClientConfig` (and `LiveExecClientConfig` to `ExecutionClientConfig`), and no stable 2.0.0 date is published (newreleases.io rc4 notes, README).
3. Nautilus instrument types: Equity, FuturesContract, OptionContract, OptionSpread, CryptoPerpetual, BinaryOption, BettingInstrument and Cfd are all listed, among others (CurrencyPair, Commodity, IndexInstrument, TokenizedAsset, CryptoOption and more). There is no Bond type (nautilustrader.io instruments page).
4. LEAN is Apache-2.0 (GitHub). NuGet `QuantConnect.Lean` 2.5.18127 was published 2026-09-25 and targets .NET 10. Five NuGet releases fall between 2026-08-21 and 2026-09-25 (nuget.org).
5. LEAN lists 11 asset classes (US Equity, Equity Options, Crypto, Crypto Futures, Forex, Futures, Future Options, Index, Index Options, CFD, India Equity) with no bonds, and its brokerage page lists 23 entries with no Taiwan broker (quantconnect.com docs).
6. QuantConnect pricing: Researcher $84/mo, Team $168/mo, Trading Firm $480/mo, Institution $1,272/mo (quantconnect.com/pricing.md).
7. StockSharp commit 81ecf7a ("Replace Apache license with StockSharp custom notice") is dated 2026-07-16T09:29Z. The EULA forbids creating derivative works, modification and redistribution (GitHub API; stocksharp.com/en/products/eula/).
8. The StockSharp README lists Yuanta SPARK API, Fubon Neo API, SinoPac Shioaji, Taishin Nova API (formerly MasterLink) and TWSE OpenAPI (github.com/StockSharp/StockSharp).
9. OpenBB LICENSE history: MIT, then AGPL-3.0 (commit c61d10d, 2024-05-14), then Apache-2.0 in the V5 commit (bbf1ab2, 2026-09-29). PyPI `openbb` 5.0.0 was released 2026-09-29 under Apache-2.0. `OpenBB-finance/OpenBB` resolves to `openbq-org/OpenBB`, an org created 2026-09-11, while PyPI still points to the old URL (GitHub API, PyPI).
10. vectorbt is Apache 2.0 with Commons Clause (LICENSE). 1.1.1 was released 2026-09-26 and 1.0.0 on 2026-04-22 (PyPI). PRO costs $25/mo, $240 for 12 months or $500 lifetime, and individual memberships are for personal, non-commercial use; commercial use is arranged by email (vectorbt.pro).
11. backtrader: last PyPI release 1.9.78.123 (2023-04-19), last commit 2023-04-19, last push 2024-08-19, GPL-3.0 (PyPI, GitHub API).
12. Kraken announced the NinjaTrader acquisition on 2025-03-20 for $1.5B. ninjatrader.com is now branded "NinjaTrader by Payward". Plans: Free, $99/month, $1,499 lifetime (Kraken blog, ninjatrader.com/pricing).
13. GitHub activity figures re-measured: 2026 default-branch commits for Nautilus (4,536), LEAN (343), StockSharp (1,143), OpenBB (96) and vectorbt (154); issue closure for Nautilus (531/605), LEAN (78/105) and Freqtrade (103/104); star counts for all listed repos.
14. Hummingbot v2.17.0 (2026-09-22), Apache-2.0.
15. Freqtrade 2026.9 (2026-09-29), GPL-3.0, 12 spot and 7 futures exchanges. 2026.8 removed Bitmart because the exchange ceased operations at the end of July (release notes).
16. Zipline-reloaded 3.1.1 (2025-07-19), with no default-branch commits in 2026.
17. QuantRocket's latest release is 2.11.0 (2025-01-28), with nothing since.
18. Jesse is MIT (3.2.4, 2026-10-01). Live and paper trading need the licensed plugin (docs.jesse.trade).
19. Lumibot is GPL-3.0 (4.6.4, 2026-10-03), with brokers Alpaca, IBKR, Tradier, Schwab, Tradovate and ProjectX (README).
20. hftbacktest is MIT. Python 2.4.4 and rust-v0.9.4 were released 2025-12-10, the last push was 2025-12-23, and there have been no commits in 2026.
21. Qlib is MIT (0.9.7, 2025-08-15).
22. The MetaTrader5 Python package 5.0.6231 (2026-09-27) ships only `win_amd64` wheels.
23. TradingView paid plans cost $12.95 to $199.95/mo (annual billing). Pine Script v6 is current, and its release notes run through September 2026.
24. Sierra Chart packages cost $26 to $56/mo.
25. MultiCharts market data costs $49/mo (purchase page).
26. XQ lists 26 cooperating brokers with an automated-trading-center column, and runs on Windows, Mac, iPad and iPhone (xq.com.tw).
27. Shioaji 1.7.7 (2026-09-29) has wheels for Windows, Linux (x86_64 and aarch64) and macOS, and covers stocks, futures and options.
28. Fubon Neo API supports Python, C#, Node.js, C++ and Go (with partial coverage in the last two).
29. NautilusTrader Pro is waitlist-only with no published prices, and offers execution algorithms, a risk engine and a dashboard.
30. Nautilus supports Linux (x86_64 and ARM64), macOS ARM64 and Windows x86_64, with 17 integrations including Databento and Tardis data.
31. LEAN's GitHub releases are stale (v2.4.0.1, 2017) and so are StockSharp's tags (5.0.0, 2020). The StockSharp pricing page claims 389+ connectors.
32. Kraken's announcement frames equities as a Kraken multi-asset ambition. That is consistent with the roadmap wording.
33. cTrader Algo supports C# and Python.

### Corrected or refined

| Original | Correction | Source |
|---|---|---|
| Nautilus v2.0.0rc4 removed Cython | The legacy Cython package was removed in **rc3** (2026-08-21). The rc4 notes only refer to it as already removed | https://github.com/nautechsystems/nautilus_trader/releases |
| v1 only receives security fixes (open-ended) | Critical security backports on `develop_v1` for **about three months** after the v2 cutover | v1.231.0 release notes |
| Recommendation: pin an exact v2 RC as the core (live trading implied) | Upstream does not recommend release candidates in production environments such as live trading with real capital. The text now says to use RCs for development and paper trading and to gate real-money trading on 2.0.0 stable or on soak tests | https://github.com/nautechsystems/nautilus_trader (README) |
| TradingView webhooks on Plus and above | Webhooks on **every paid plan (Essential and above)**; only Basic lacks them | https://www.tradingview.com/pricing/ (comparison table) |
| MT5 AI Assistant added in builds 6140-6230 (Aug-Sep 2026) | MCP and agentic AI support **arrived in build 6060 (2026-07-23)** and was expanded through build 6230 (2026-09-24) | https://www.metatrader5.com/en/releasenotes |
| NinjaTrader covers US futures; crypto and equities are on the roadmap | It already lists **Micro Bitcoin futures and single-stock futures**. Spot equities and crypto remain with Kraken | https://ninjatrader.com/ |
| OpenBB: avoid 4.x, which is AGPL | Only **4.2.0 to 4.7.x** are AGPL-3.0. 4.0 and 4.1 shipped while the repo was MIT | PyPI `openbb` metadata; LICENSE history |
| Taiwan regulation: "SITE/FSC licensing" | Signals for a fee need an FSC-licensed **securities investment consulting enterprise (SICE, 投顧)**, discretionary management (全權委託) needs separate FSC approval, and futures advice needs futures-advisory licensing | https://law.moj.gov.tw/ENG/LawClass/LawAll.aspx?pcode=G0400121 |
| Bonds are missing everywhere | Tradable bond types are missing from open-source engines, but broker APIs such as IBKR TWS accept `BOND` contracts, and QuantLib covers bond analytics | https://interactivebrokers.github.io/tws-api/basic_contracts.html |
| StockSharp, the only engine with TW connectors, "left open source" (implying the TW connectors were once open) | The TW connectors are in `StockSharp/Connectors` (created 2026-07-13, proprietary notice) and are absent from the 2026-07-15 pre-change README, so they were **never Apache-2.0** | GitHub API (`StockSharp/Connectors`, README history) |
| LEAN: 23 brokerages | 23 **entries**, counting QC Paper Trading, generic FIX and a "CFD and FOREX Brokerages" group | https://www.quantconnect.com/docs/v2/cloud-platform/live-trading/brokerages |
| Hummingbot: 140+ CEX/DEX/AMM venues | The README's 140+ figure counts venues where users traded, not shipped connectors | https://github.com/hummingbot/hummingbot |
| Missing options | Added **VeighNa (vn.py)** (MIT, 45.7k stars, 4.4.0 on 2026-05-14, no Taiwan gateway), **QuantLib** (bond and option pricing) and StockSharp pricing (Free with 1 connector; Premium $995 or Ultimate $1,995 for the first year) | https://github.com/vnpy/vnpy ; https://github.com/lballabio/QuantLib ; https://stocksharp.com/pricing/ |

### Unverifiable

- The closing date of the Kraken-NinjaTrader deal. Payward ownership is confirmed on ninjatrader.com, but no closing announcement was retrieved.
- QuantRocket plan names (Non-Professional or Professional). The pricing page needs a login to show tiers.
- The MultiCharts Python beta and the lifetime-license price. Neither appears on the public purchase page.
- XQ pricing being available "usually through a broker". No public price was found, which is consistent with the claim but does not prove it.
- cTrader Web and Mobile availability and the Open API. They were not shown on the cTrader Algo documentation page that was checked.
- Issue-closure ratios and 2026 commit counts for projects not re-measured (Hummingbot, Freqtrade commits, Jesse, Lumibot, hftbacktest issues, Qlib).
- The LGPL "relink obligation" for statically linked Rust crates. This is a legal interpretation, not a checkable fact; get counsel review.
