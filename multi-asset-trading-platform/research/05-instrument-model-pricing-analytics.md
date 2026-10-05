**English** | [繁體中文](05-instrument-model-pricing-analytics.zh-TW.md)

# Instrument Modeling & Pricing Analytics (Options, Bonds, Crypto Derivatives)

*Research dimension 05 · Status as of 2026-10-05 · Scope: stocks, crypto, bonds, options; US/global + Taiwan (TWSE/TAIFEX)*

## TL;DR

- **Use one canonical, effective-dated instrument model**, keyed on an internal `instrument_id`. The runtime types follow NautilusTrader's 18 concrete instrument types (19 counting `SyntheticInstrument`; no bond type), and a bitemporal security master holds the cross-reference identifiers. **FIGI** is the free cross-vendor key (MIT-licensed open data, free OpenFIGI API). **CUSIP** needs a licence from CUSIP Global Services (run by FactSet). US options use the 21-character **OCC OSI** symbol. Crypto uses the venue symbol plus base, quote and settlement currency.
- **QuantLib 1.43 (BSD-3, 2026-07-14; 1.44-rc 2026-10-03) is the default pricing core in every scenario.** It covers curves, bonds, American engines (QD+ fixed-point), Heston, SABR, SVI and local vol. Add a vectorized European IV/greeks layer: **vollib** (MIT, revived in 2026) or **fast-vollib** (MIT, NumPy/PyTorch/JAX backends). **No surveyed library models perpetual funding or coin-margined (inverse) options natively**, so that thin layer is yours to write.
- **For institutional scale, add ORE** (Modified BSD; 1.8.17.0 tagged on GitHub 2026-09-15, PyPI wheel 2026-09-14). It brings XVA, SIMM and market risk, plus AAD and OpenCL/CUDA through its computation graph. Use **Strata** (Apache-2.0, v2.12.76 on 2026-09-30) only in a JVM rates/credit shop. **Rateslib** is source-available: free only for private, non-commercial use, and any commercial, professional or revenue-generating use costs £251/user/year. That includes using it as a validator for corporate code. **FinancePy** is GPL-3.0: fine for research and internal use, but a problem inside distributed closed-source apps.
- **The asset classes need different analytics.** Stocks need corporate actions and effective-dated tick tables. Bonds need a cash-flow, curve and day-count engine. Options need volatility surfaces, early-exercise engines and margin models. Crypto needs inverse-contract math, funding accrual and 24/7 calendars.
- **Precision and speed:** keep orders, fills and PnL in fixed-point and the model path in float64. A full-chain Black-76 price plus 3 greeks for 1M contracts took **0.06 s** in plain NumPy on one CPU core (local measurement). Use GPUs only for scenario grids or Monte Carlo, and remember that JAX defaults to float32 and has no native Windows GPU support.

## Key questions

1. What is the canonical instrument schema? Which identifiers are free versus licensed, and how do Taiwan and crypto symbols fit in?
2. Which pricing models are actually needed per asset class, and which can wait?
3. Which open-source library (or combination) gives correct, maintained, permissively licensed coverage in 2026?
4. How should margin (Reg T, portfolio margin, SPAN, TAIFEX, crypto venues) be estimated pre-trade?
5. Where do GPU and vectorization pay off, and where does float32 or a naive solver silently corrupt numbers?

## Options compared

### 1. Identifiers and symbology

| Identifier | Covers | Licence / cost | Role in our model |
|---|---|---|---|
| **FIGI** (OMG standard; Bloomberg is the Registration Authority) | All asset classes, including futures, options, loans, crypto and venue pairs | Open data under an MIT declaration; OpenFIGI API is free (25 req/min and 10 jobs per request without a key; 25 req/6 s and 100 jobs with a key) | **Preferred cross-reference key**; one FIGI per listing, plus composite and share-class levels |
| **ISIN** | Securities (equities, bonds, ETFs); Taiwan ISINs start with `TW` | Free to quote; bulk files come from national numbering agencies | Bond and equity key used in settlement and broker statements |
| **CUSIP** | US and Canadian securities | **Licensed**: CGS is managed for the ABA by FactSet, and its terms forbid redistribution | Store only if licensed (institutional); otherwise derive it from the ISIN at runtime and never redistribute |
| **OCC OSI** (since 2010-02-12) | US listed options: root (6) + YYMMDD + C/P + strike×1000 (8) = 21 chars | Free | Natural key for US options. Roots change after corporate-action adjustments |
| **Ticker + MIC** | Exchange listings (e.g., `2330` on XTAI, `AAPL` on XNAS) | Free | Display and routing key. **Not stable** (renames, reuse) |
| **TAIFEX product code** | TX/MTX/TMF futures, TXO options, stock futures/options | Free | Venue symbol; month codes and weekly series are mapped in an adapter |
| **Crypto venue symbol** | `BTCUSDT` (Binance), `BTC-PERPETUAL`, `BTC-5OCT26-74000-C` (Deribit) | Free | Venue-scoped key, always paired with base, quote and settlement currencies |

### 2. Canonical schema: how the four asset classes differ

| Attribute | Stocks / ETFs | Crypto (spot, perp, dated, options) | Bonds | Listed options (equity, index, TXO) |
|---|---|---|---|---|
| Price unit | Currency per share | Quote currency; **inverse** contracts are quoted in USD but settled in coin | % of par, clean vs dirty; yield | Premium × multiplier (US equity 100 shares; TXO NT$50/pt) |
| Tick | Tiered by price (TWSE NT$0.01→NT$5). US $0.01; the SEC's amended Rule 612 half-penny ($0.005) tick for certain NMS stocks priced ≥$1 is **deferred to Nov 2027**, together with the lower Rule 610(c) access-fee cap | Venue tick tables, e.g., Deribit BTC options 0.0001 BTC (0.0005 above 0.005); BTC-PERPETUAL 0.5 USD | 32nds (UST), decimal elsewhere | Tiered by premium (TXO: 0.1 pt below 10 up to 10 pts at ≥1,000) |
| Lot | 1 share (US); TW board lot of 1,000 shares plus intraday odd lots | Min quantity and size increment (8+ decimals); Deribit options min 0.1 BTC | Min denomination / face increment | 1 contract |
| Sessions | Exchange calendars, auctions, ±10% limits (TW) | 24/7 with maintenance windows | OTC dealer hours | TAIFEX regular 08:45–13:45 and after-hours 15:00–05:00 |
| Settlement / expiry | US T+1, TW T+2 | Perps never expire (funding instead); Deribit dated contracts expire **08:00 UTC** | Coupon schedule, maturity, call/put schedule | Exercise style, AM/PM or averaged settlement (TXO: average index over the last 30 min), cash vs physical |
| Lifecycle events | Splits, dividends, symbol changes | Funding payments, delistings, redenominations | Coupons, calls, sinks, defaults | Deliverable adjustments, assignment, auto-exercise |
| Analytics needed | Little (marks) | Mark/index price, funding accrual, basis | Price↔yield, accrued interest, DV01, curves | IV, greeks, surfaces, margin |

**Model choice:** adopt NautilusTrader's instrument types (`Equity`, `FuturesContract`, `OptionContract`, `CryptoPerpetual`, `CryptoFuture`, `CryptoOption`, `PerpetualContract`, spreads and others; 18 variants in `InstrumentAny` as of Oct 2026). NautilusTrader 2.0 is still a release candidate (2.0.0rc5, 2026-09-15), so pin the version and expect type changes at 2.0 GA. Their common fields (`price_increment`, `size_increment`, `multiplier`, `lot_size`, `margin_init/maint`, maker/taker fees) become the runtime contract. Extend them with:

- a `Bond` type (coupon schedule, day count, settlement days, call schedule);
- `settlement_currency` / `is_inverse`;
- an effective-dated `tick_scheme_id`;
- a `calendar_id`.

Strata's split between product, security and trade (OTC trades embed products; listed trades reference securities by ID) is a good reference design for the bond and OTC side.

### 3. Pricing model menu

| Model | Use it for | Asset classes | Priority |
|---|---|---|---|
| **Black-76** on an implied forward (from put-call parity or futures) | Index options (SPX, TXO), futures options, **crypto options** (forward from the dated future or perp), swaptions | Options, crypto | **MVP** |
| Black-Scholes-Merton | European equity options; quick marks | Options | MVP |
| Bachelier (normal) | Rates, spreads, near-zero or negative forwards | Bonds/rates | Later |
| CRR / Leisen-Reimer trees | American options with discrete dividends; teaching; callable bonds (HW/BK/BDT trees) | Options, bonds | MVP (bonds: later) |
| Bjerksund-Stensland / Barone-Adesi-Whaley | Fast American approximations for screening | Options | Optional |
| **ALO "QD+" fixed-point** (QuantLib `QdFpAmericanEngine`) | Fast **and** accurate American pricing; the default for US single-stock options | Options | **MVP** |
| Finite difference (Crank-Nicolson) | American with discrete dividends, barriers | Options | MVP via QuantLib |
| **SVI per expiry → SSVI surface** | Arbitrage-aware surface fit, smile interpolation, IV analytics | Options, crypto options | **MVP (SVI)**, SSVI later |
| SABR (and no-arbitrage SABR) | Rates/FX smiles; sometimes crypto smiles | Rates, FX, crypto | Later |
| Heston (and rough Heston, new in QuantLib 1.44) | Stochastic-vol dynamics, exotics, forward-skew studies | Options, crypto | Later |
| Dupire local vol | Exotics consistent with vanillas; needs an arbitrage-free surface | Options | Institutional |
| Curve bootstrapping + Nelson-Siegel-Svensson | Discount/forward curves; fitted government curves; rich/cheap analysis | Bonds | MVP for bonds |
| Z-spread / OAS / credit spread | Corporate and callable bonds | Bonds | Later |

**Crypto-specific math to own (not in any library):**

- **Inverse futures and perps:** PnL in coin is `Q_usd × (1/F_entry − 1/F_exit)`. Exposure is convex and collateral is the underlying itself.
- **Inverse options (Deribit "reversed"):** the premium is quoted in BTC, so the coin price equals the USD Black-76 value divided by the underlying price. Delta must be premium-adjusted for coin-margined hedging.
- **Funding:**
  - Binance USDⓈ-M: `F = [P̄ + clamp(I − P̄, ±0.05%)] / (8/N)` for an N-hour interval, with `I` = 0.01% per 8 h. The default is 00/08/16 UTC, but some contracts use 4 h, and Binance can switch a contract to 1 h when the cap is hit.
  - Hyperliquid computes an 8 h rate but pays 1/8 of it **hourly**, capped at 4%/h.
- **Basis:** annualized basis = `(F/S − 1) × 365/days`. Funding and basis are cash-flow events in the backtester, not just analytics.
- **Deribit ownership:** Coinbase completed its acquisition of Deribit (~US$2.9B) in August 2025. Deribit added USDC-settled linear BTC/ETH options on 2025-08-19 alongside the inverse ones, so model both `settlement_currency` variants.

### 4. Library comparison

| Library | Language / bindings | Licence | Maintenance (verified) | Options | Bonds / curves | Crypto derivs | Performance | Verdict |
|---|---|---|---|---|---|---|---|---|
| **QuantLib** | C++ (C++17; 1.44 drops the Boost `any`/`optional` fallbacks); SWIG for Python, C#, Java | **BSD-3** | 1.40 (2025-10-14) → 1.41 → 1.42/1.42.1 → **1.43 (2026-07-14)** → 1.44-rc (2026-10-03); quarterly | BSM, Black, Bachelier, trees, Bjerksund-Stensland, **QD+ American**, FD, Heston, SABR, SVI (experimental), local vol | Fixed/floating/callable/convertible bonds, all day counts, multi-curve bootstrap, NS/Svensson fits, Taiwan calendar | None built in (Black-76 primitives only) | Fast scalar C++. The global evaluation date limits threading, so use process-level parallelism | **Core in both scenarios** |
| **ORE** (Open Source Risk Engine, LSEG Post Trade Solutions) | C++ on QuantLib; Python via `open-source-risk-engine` wheels | **Modified BSD** | ORE 15 (2026-03-04, on QuantLib 1.41); ORE 16 (2026-05-28); **1.8.17.0 (GitHub 2026-09-15; PyPI wheel 2026-09-14)** | QuantLib plus scripted trades, Heston, SVI across asset classes | Plus XVA, SIMM, market risk, sensitivities | None | Multi-threaded valuation, **AAD**, OpenCL/CUDA via computation graph | **Institutional** risk layer |
| **OpenGamma Strata** | Java 8u40+ | **Apache-2.0** | **v2.12.76 (2026-09-30)**, about monthly | FX vanilla, swaptions, caps/floors; ETD modeling | Strong rates, bonds, bond futures, CDS | None | JVM, production-grade | Only for a JVM rates/credit shop |
| **Rateslib** | Python + Rust (PyO3) | **Source-available**; free only for private non-commercial use; any commercial use (including as a benchmark/validator) £251/user/yr | 2.0.1 (2025-06) → **2.7.1 (2026-04-04)** | FX options (SABR/spline smiles); IR swaptions (beta, 2.7) | Best-in-class bond conventions (`spec` presets), bond futures, curve solver with AD | None | Rust core, forward-mode AD | Rates/bond specialist; budget the licence |
| **FinancePy** | Python + Numba | **GPL-3.0-or-later** | 1.0.0 (2025-08-31) → **1.1.2 (2026-08-21)**; Python ≥3.10,<3.14 | American, Heston, SABR, **SVI/SSVI surfaces**, Bjerksund-Stensland | Bonds, embedded options (HW/BK/BDT), NSS fits | None | Numba JIT | Research and cross-checks only (copyleft) |
| **vollib** / **fast-vollib** | Python (NumPy); fast-vollib adds PyTorch, JAX and Triton kernels | **MIT** | vollib **1.0.11 (2026-06-01)**, Python 3.9–3.13 (`py_vollib` 1.0.12 is a transition package); fast-vollib **0.2.3 (2026-09-05)**, a young single-maintainer 0.x project | European Black/BS/BSM, IV via "Let's Be Rational", greeks; fast-vollib 0.2.2 adds SVI/SSVI and Heston surface fitting | fast-vollib 0.2.3 adds fixed-income contracts | Use as the Black-76 engine for crypto | Vectorized; GPU (fast-vollib) | **Chain-wide IV/greeks** |
| **RustQuant** | Rust | MIT / Apache-2.0 | Commits through 2026-10, but **no crates.io release since Nov 2024**; self-described "free-time project" | BS, Heston, SABR pieces | Basic | None | Native | Watch; not production |
| **JAX / PyTorch (in-house)** | Python | Apache / BSD | Google's **tf-quant-finance is declared unmaintained** (its README says "no longer maintained and has been archived", though GitHub does not flag the repo as archived); py_vollib_vectorized last released 2021 | Whatever you write: MC, AD greeks | Batch scenario risk | Custom | GPU; **float32 by default** (`jax_enable_x64`); no native Windows CUDA (WSL2 experimental) | Institutional batch risk only |

**Reading:** QuantLib is the only maintained, permissively licensed library that covers options, bonds and curves together. ORE is QuantLib plus a risk factory. The rest are either narrow (vollib), licence-encumbered (Rateslib, FinancePy), JVM-bound (Strata) or immature (RustQuant).

**Not compared above: buy instead of build.** Commercial options analytics and data, such as vendor IV surfaces and greeks (ORATS, OptionMetrics IvyDB, Cboe LiveVol) or pricing libraries such as Numerix, are the usual alternative for scenario (b). Buying surface history can be cheaper than building and validating your own, but it adds the redistribution limits noted under data licensing.

### 5. Margin methodologies

| Regime | Where | Method | Data | Build vs use broker |
|---|---|---|---|---|
| **Reg T** strategy-based, plus FINRA 4210 intraday margin | US margin accounts | 50% initial on equities; option strategy tables (spreads, straddles, covered). Since 2026-06-04 (SR-FINRA-2025-017), FINRA 4210 has replaced the pattern-day-trader provisions with intraday-margin-deficit rules | Rule tables | Build a rule engine for pre-trade estimates, including intraday margin |
| **Portfolio margin** (FINRA 4210(g), OCC CPM/TIMS) | Approved US accounts. Minimum equity is broker policy, typically about $100k or more; 4210(g) itself only sets a $5M floor for unlisted derivatives | Worst loss over a price grid: ±15% single names, −8%/+6% high-cap broad indexes | OCC theoretical values (licensed, via broker) | Use broker numbers; replicate approximately with our own surface |
| **SPAN / SPAN 2** | CME (moving to the VaR-based SPAN 2), **TAIFEX** | Scenario arrays plus inter- and intra-commodity credits | TAIFEX publishes **SPAN risk-parameter files for regular and after-hours sessions** | Implement a SPAN-file loader (deterministic, documented) |
| **Crypto venue margin** | Deribit standard/portfolio margin, Binance/OKX unified accounts | Venue-specific scenario or VaR models; liquidation engines | Venue APIs | Read from the API; replicate only for backtests |

## Recommendations (by scenario)

### (a) Solo / 1-3 person MVP

1. **Instrument model:** use NautilusTrader instrument types as the runtime schema (consistent with research 01/02). Add a `Bond` type and an effective-dated `tick_scheme`.
2. **Security master:** keep it in PostgreSQL with an `instrument_xref(instrument_id, scheme, value, valid_from, valid_to)` table.
   - Populate FIGI via OpenFIGI. Use ISIN from broker and exchange files.
   - Generate OCC OSI from the chain data. Map TAIFEX and crypto venue symbols in their adapters.
   - **Do not** store CUSIPs from unlicensed sources.
3. **Pricing core: QuantLib-Python 1.43**, pinned and upgraded quarterly. Use it for American options (`QdFpAmericanEngine`; FD when discrete dividends matter), bonds (accrued interest, yield, duration/convexity, DV01), curve bootstrapping and NSS fits.
4. **Chain analytics:** use **vollib 1.0.11** (`import vollib`, not `py_vollib`) or **fast-vollib** for vectorized IV and greeks. Run everything through **Black-76 on an implied forward**, including TXO and Deribit options.
5. **Write a ~500-line crypto module:** inverse/linear PnL, premium-adjusted delta, funding accrual per venue rule, and basis. Unit-test it against venue-published marks.
6. **Surface:** fit SVI per expiry with SciPy and check butterfly and calendar arbitrage. Defer SABR, Heston and local vol until a strategy needs them.
7. **Margin:** take broker and venue numbers in live trading. For backtests, use a Reg T rule table plus a TAIFEX SPAN-parameter loader for TX/TXO.
8. **Licences:** keep FinancePy (GPL) out of anything you distribute; using it internally as a test oracle is fine. **Rateslib is different.** Its free licence covers only private, non-commercial use on non-corporate machines. It forbids commercial or revenue-generating use, including use in a trading application or as a validator for corporate code. Real-money trading arguably counts, so either buy the £251/user/yr licence or leave Rateslib out.

### (b) 5-20 person team / institutional grade

1. Run a **dedicated security-master service** (bitemporal) fed by licensed reference data (CUSIP, vendor corporate actions, OCC adjusted-deliverable notices). FIGI is the public join key.
2. Run a **pricing service on QuantLib C++ / ORE**. It is stateless, takes a versioned market snapshot (curves and surfaces by ID) and is reached over gRPC or Arrow Flight. Use ORE for sensitivities, XVA, SIMM and stress, with AAD and the GPU computation graph where they pay off.
3. Run a **volatility-surface service**: SSVI/eSSVI with arbitrage constraints, intraday re-fits and stored parameter history (needed for reproducible backtests). Use SABR for rates and FX, and Heston or local vol for exotics.
4. Use **GPU batch risk** (JAX x64 or PyTorch, or fast-vollib) only for full-book scenario grids and Monte Carlo. Keep American and discrete-dividend pricing on CPU QuantLib.
5. **Margin replicas:** a SPAN/SPAN 2 engine, an OCC CPM-style grid with our own surfaces, and crypto venue PM replicas. Reconcile daily against clearing and broker statements.
6. **Model risk management:**
   - Dual-implement every production model (QuantLib vs vollib, with FinancePy or a *licensed* Rateslib as oracle).
   - Keep golden test vectors in CI.
   - Document assumptions per model.
7. **Rates/bond-heavy desks:** evaluate a Rateslib enterprise licence, or Strata if the team is JVM-centric.

## Impact on overall architecture

- **The security master is a first-class, bitemporal service.** Every other component references `instrument_id` only. Tick tables, multipliers, calendars and deliverables are effective-dated, because regimes change (for example, the Rule 612 half-penny tick was stayed in Dec 2024 and then deferred twice, first to Nov 2026 and now to Nov 2027).
- **Two numeric worlds:** the order, fill and accounting path in the Rust core uses fixed-point (research 01). The pricing service uses float64. Conversions happen explicitly at the boundary through `make_price/make_qty`.
- **Market objects are data:** curves, surfaces and funding histories are versioned artifacts in the data lake (Parquet, research 03). Backtests and live runs reference snapshot IDs, so prices are reproducible.
- **Lifecycle events live in the engine:** coupons, ex-dividends, funding payments, expiry and settlement, assignment and auto-exercise are engine events, not post-processing.
- **Concurrency:** QuantLib's global evaluation date makes it effectively single-threaded per process, and ORE notes it has to work around QuantLib's thread-safety limitations. Scale QuantLib with a process pool keyed by valuation date.
- **Clients never price:** desktop, web and mobile UIs receive greeks and IV from the server. This avoids shipping native QuantLib to mobile and sidesteps GPL questions.
- **Calendars:** use QuantLib calendars for financial date math and `exchange_calendars` (Apache-2.0, XTAI included) for sessions. Overlay manual closures, such as Taiwan typhoon days (颱風假). These are announced at short notice, normally by 22:00 the evening before and sometimes on the day itself. QuantLib's `Taiwan` calendar hard-codes lunar and adjusted holidays year by year and, as of Oct 2026, stops at 2026. Load TWSE/TAIFEX's published 2027 holiday schedule before year-end rather than relying on the library default.

## Risks & pitfalls

- **Wrong exercise style or settlement:** US single-stock options are American with discrete dividends; TXO is European and settles on a 30-minute average. Index options differ in AM vs PM settlement. Using BSM everywhere misprices early exercise and expiry PnL.
- **Naive IV solvers fail in the wings.** In our local test, vectorized Newton converged on only ~96% of 1M random contracts (low vega). Use "Let's Be Rational", which reaches double precision in two iterations, or bracketed fallbacks, and flag no-arbitrage violations instead of forcing a solution.
- **Inverse-contract convexity and coin collateral.** Treating BTC-settled contracts as linear gives wrong delta, PnL and liquidation prices.
- **Funding rules change:** intervals (8 h → 1 h), caps and formulas differ by venue and over time. Store them per venue and per period.
- **Bond conventions:** a wrong day count (Act/Act ICMA vs 30/360), ex-coupon period, settlement lag or holiday calendar gives errors as large as the edge being traded. Use QuantLib (or licensed Rateslib) conventions, not hand-rolled ones.
- **Surface arbitrage:** independent SVI slices can create calendar arbitrage, and local vol then blows up. Enforce SSVI-style constraints.
- **GPU precision:** float32 defaults (JAX, PyTorch) and slow FP64 on consumer GPUs can silently degrade greeks. Validate against float64 CPU results.
- **Library churn:** QuantLib removes features about five releases after deprecating them (1.43 removed what 1.38 deprecated). RustQuant has no recent releases, py_vollib_vectorized is stale and tf-quant-finance is declared unmaintained. vollib was revived in 2026 by a small maintainer base.
- **Data licensing:** CUSIP, OCC theoretical values and vendor IV/greeks have redistribution limits. A multi-user service needs explicit licences.
- **Corporate-action-adjusted options** (non-standard deliverables) break naive "100 × underlying" assumptions.

## References

- QuantLib on PyPI (versions, BSD-3): https://pypi.org/project/QuantLib/
- QuantLib releases (1.42, 1.43, 1.44-rc notes): https://github.com/lballabio/QuantLib/releases
- QuantLib 1.40 (Zenodo): https://zenodo.org/records/17347020
- QuantLib `QdFpAmericanEngine`: https://www.quantlib.org/reference/class_quant_lib_1_1_qd_fp_american_engine.html
- QuantLib `BjerksundStenslandApproximationEngine`: https://www.quantlib.org/reference/class_quant_lib_1_1_bjerksund_stensland_approximation_engine.html
- QuantLib-Python term structures (NS/Svensson, SABR, SVI): https://quantlib-python-docs.readthedocs.io/en/latest/termstructures.html
- QuantLib-Python pricing engines: https://quantlib-python-docs.readthedocs.io/en/latest/pricing_engines.html
- ORE repository and licence: https://github.com/OpenSourceRisk/Engine
- ORE performance (AAD, OpenCL/GPU, threading): https://github.com/OpenSourceRisk/Engine/blob/master/Examples/Performance/Readme.md
- ORE 15 announcement: https://www.lseg.com/en/about-us/new-at-lseg/post-trade-solutions-strengthen-open-source-innovation-with-the-15th-release-of-open-source-risk-engine-ore
- ORE 16 announcement: https://www.lseg.com/en/about-us/new-at-lseg/post-trade-solutions-advances-open-source-capabilities-with-release-of-open-source-risk-engine-ore-16
- ORE Python wheels: https://pypi.org/project/open-source-risk-engine/
- OpenGamma Strata: https://github.com/OpenGamma/Strata
- Strata releases (Maven Central): https://repo1.maven.org/maven2/com/opengamma/strata/strata-pricer/
- Strata product model: https://strata.opengamma.io/product_model/
- Rateslib release notes: https://rateslib.com/py/en/latest/i_whatsnew.html
- Rateslib licence: https://rateslib.com/py/en/latest/_sources/i_licence.rst.txt
- Rateslib on PyPI: https://pypi.org/project/rateslib/
- FinancePy: https://github.com/domokane/FinancePy
- FinancePy on PyPI: https://pypi.org/project/financepy/
- vollib on PyPI: https://pypi.org/project/vollib/
- py_vollib on PyPI: https://pypi.org/project/py-vollib/
- fast-vollib: https://pypi.org/project/fast-vollib/
- fast-vollib paper (arXiv 2604.27210): https://arxiv.org/abs/2604.27210
- RustQuant: https://github.com/avhz/RustQuant
- RustQuant on crates.io: https://crates.io/crates/RustQuant
- TF Quant Finance (declared unmaintained): https://github.com/google/tf-quant-finance
- JAX double precision: https://docs.jax.dev/en/latest/notebooks/Common_Gotchas_in_JAX.html
- JAX platform support: https://docs.jax.dev/en/latest/installation.html
- Jäckel, "Let's Be Rational": http://www.jaeckel.org/LetsBeRational.pdf
- Gatheral & Jacquier, "Arbitrage-free SVI volatility surfaces": https://arxiv.org/abs/1204.0646
- NautilusTrader instruments: https://nautilustrader.io/docs/latest/concepts/instruments/
- NautilusTrader `InstrumentAny` (18 variants): https://github.com/nautechsystems/nautilus_trader/blob/develop/crates/model/src/instruments/any.rs
- NautilusTrader on PyPI (2.0 release candidates): https://pypi.org/project/nautilus_trader/
- OpenFIGI (FIGI standard): https://www.openfigi.com/about/figi
- OpenFIGI API limits: https://www.openfigi.com/api/documentation
- CUSIP Global Services terms: https://www.cusip.com/about/index.html
- OCC option symbology (OSI): https://en.wikipedia.org/wiki/Option_symbol
- SEC Rule 612 exemptive relief (half-penny tick deferred to Nov 2027): https://www.federalregister.gov/documents/2026/06/15/2026-11997/order-granting-temporary-exemptive-relief-pursuant-to-section-36a1-of-the-securities-exchange-act-of
- Regulation T §220.12: https://www.law.cornell.edu/cfr/text/12/220.12
- FINRA Rule 4210 (portfolio margin, intraday margin): https://www.finra.org/rules-guidance/rulebooks/finra-rules/4210
- SR-FINRA-2025-017 (day-trading margin replaced by intraday margin, effective 2026-06-04): https://www.finra.org/rules-guidance/rule-filings/sr-finra-2025-017
- Portfolio margin overview: https://en.wikipedia.org/wiki/Portfolio_margin
- CME SPAN 2: https://www.cmegroup.com/solutions/risk-management/performance-bonds-margins/span-2.html
- TAIFEX TXO spec: https://www.taifex.com.tw/enl/eng2/tXO
- TAIFEX TX spec: https://www.taifex.com.tw/enl/eng2/tX
- TAIFEX TMF spec: https://www.taifex.com.tw/enl/eng2/tMF
- TAIFEX margining and SPAN parameter files: https://www.taifex.com.tw/enl/eng5/indexMargining
- TWSE trading rules: https://www.twse.com.tw/en/products/system/trading.html
- exchange_calendars: https://github.com/gerrymanoim/exchange_calendars
- QuantLib Taiwan calendar source (holiday tables through 2026): https://github.com/lballabio/QuantLib/blob/master/ql/time/calendars/taiwan.cpp
- Taiwan typhoon-day announcement rules (zh): https://zh.wikipedia.org/zh-tw/颱風假
- Deribit instruments API (live specs): https://www.deribit.com/api/v2/public/get_instruments?currency=BTC&kind=option&expired=false
- Deribit BTC-PERPETUAL spec (API): https://www.deribit.com/api/v2/public/get_instrument?instrument_name=BTC-PERPETUAL
- Deribit USDC linear options launch: https://insights.deribit.com/education/usdc-settled-btc-eth-options-launch/
- Coinbase–Deribit completion (The Block): https://www.theblock.co/post/367106/deribit-linear-bitcoin-ether-options
- Binance funding rates: https://www.binance.com/en/support/faq/detail/360033525031
- Hyperliquid funding: https://hyperliquid.gitbook.io/hyperliquid-docs/trading/funding
- Day count conventions: https://en.wikipedia.org/wiki/Day_count_convention

## Verification log (2026-10)

An adversarial fact-check ran on 2026-10-05. It used PyPI, crates.io and GitHub APIs, the live Deribit API, Federal Register and FINRA rule text, vendor licence pages and exchange spec pages.

**Confirmed (29)**

1. QuantLib 1.43 was released 2026-07-14 under BSD-3-Clause. Earlier releases: 1.42.1 (2026-04-17), 1.42 (2026-04-14), 1.41 (2026-01-13), 1.40 (2025-10-14). Source: PyPI JSON, GitHub releases.
2. QuantLib v1.44-rc was published 2026-10-03 (pre-release). It adds a rough Heston model, and the Boost `any`/`optional` implementations can no longer be selected (std only). Source: GitHub release, `News.md`.
3. QuantLib's deprecation cadence: 1.43 removed features deprecated in 1.38, 1.44 removes those deprecated in 1.39, and the 1.44 deprecations are expected to go in about 1.49. Source: release notes.
4. QuantLib requires C++17, and the `QdFpAmericanEngine`, experimental SVI smile section and `Taiwan` calendar all exist. Source: QuantLib `CMakeLists.txt` and source tree.
5. ORE capabilities: AAD and an external compute device (OpenCL, and CUDA environments in QuantExt) via the computation graph. Its multi-threaded engine "works around QuantLib's thread-safety limitations". Source: ORE `Examples/Performance/Readme.md`, `QuantExt/qle/math`.
6. ORE 16 adds Heston for scripted trades and SVI across equity, FX, commodity and credit. Source: LSEG ORE 16 announcement (2026-05-28).
7. Strata is Apache-2.0. v2.12.76 is on Maven Central (2026-09-30), and the README requires Java 8u40+. Source: Maven Central, GitHub.
8. Rateslib is "not open source": source-available non-commercial terms plus a commercial subscription of £251/user/yr. Versions: 2.7.1 (2026-04-04), 2.7.0 (2026-03-30, beta IR vol with SABR/spline cubes and swaptions), 2.0.1 (2025-06-10). Source: licence page, PyPI JSON, release notes.
9. FinancePy 1.1.2 (2026-08-21) is GPL-3.0-or-later and requires Python >=3.10,<3.14. It uses Numba, has SVI/SSVI, BAW and Bjerksund-Stensland, and has HW/BK/BDT embedded-option models. Source: PyPI JSON, GitHub source.
10. vollib 1.0.11 (2026-06-01) is MIT and built on Jäckel's LetsBeRational. `py-vollib` 1.0.12 is a "deprecated transition package". Source: PyPI.
11. fast-vollib 0.2.3 (2026-09-05) is MIT, with NumPy, PyTorch and JAX backends and a CUDA fused-kernel Triton contribution. Source: PyPI, arXiv 2604.27210.
12. RustQuant is MIT OR Apache-2.0. Its last crates.io release is 0.3.1 (2024-11-19), it has commits through 2026-10-04, and its README carries a "free-time project … not recommend … for trading" disclaimer. Source: crates.io API, GitHub.
13. py_vollib_vectorized was last released 2021-02-28 (0.1.1). Source: PyPI.
14. The SEC order of 2026-06-15 extends relief for the Rule 612 $0.005 increment and the Rule 610(c) access-fee cap to the first business day of November 2027. History: partial stay Dec 2024, relief to Nov 2026 granted Oct 2025. Source: Federal Register 2026-11997.
15. Deribit BTC options are `reversed` (inverse): settled in BTC, contract size 1, tick 0.0001 (0.0005 above 0.005), minimum 0.1. They expire at 08:00 UTC. Source: live Deribit API.
16. Deribit added USDC-settled linear BTC/ETH options on 2025-08-19, and Coinbase completed the ~US$2.9B Deribit acquisition in August 2025. Source: The Block, Deribit Insights.
17. BTC-PERPETUAL is inverse with a tick of 0.5 USD. Source: Deribit API.
18. FIGI carries an MIT open-data declaration and Bloomberg is the Registration Authority. OpenFIGI mapping limits are 25 req/min with 10 jobs without a key, and 25 req/6 s with 100 jobs with a key. Source: openfigi.com.
19. CGS is managed for the ABA by FactSet, and its terms forbid redistribution and building master files. Source: cusip.com.
20. OCC OSI was implemented 2010-02-12 in a 21-character format. Source: Wikipedia, Option symbol.
21. TWSE: tick NT$0.01 to NT$5, ±10% limit, 1,000-share board lot, intraday odd lots since 2020-10-26, T+2 settlement. Source: TWSE trading rules.
22. TXO: NT$50 per point, tick 0.1 to 10 pts, European exercise, settlement on the 30-minute average, sessions 08:45–13:45 and 15:00–05:00. Source: TAIFEX spec.
23. TAIFEX publishes SPAN parameter files for both the regular and after-hours sessions. Source: TAIFEX margining page.
24. Hyperliquid pays funding hourly at 1/8 of the 8 h rate, capped at 4%/h. Source: Hyperliquid docs.
25. FINRA 4210(g) valuation ranges: ±15% for equities and narrow indexes, +6%/−8% for high-cap broad indexes. Source: FINRA Rule 4210.
26. JAX defaults to 32-bit, and native Windows has no NVIDIA GPU support (WSL2 is experimental). Source: JAX docs.
27. `exchange_calendars` is Apache-2.0 and includes XTAI. Source: GitHub.
28. ORE 15 was announced 2026-03-04 on QuantLib 1.41, and ORE's README says Modified BSD. Source: LSEG, GitHub.
29. Black-76 price plus 3 greeks for 1M contracts in NumPy on one thread was re-measured at 0.066–0.072 s, consistent with the ~0.06 s stated. Source: local re-run.

**Corrected (11)**

1. "NautilusTrader's 21 instrument types" became **18** concrete types in `InstrumentAny`, 19 counting `SyntheticInstrument`. A note was added that NautilusTrader 2.0 is still at RC (2.0.0rc5, 2026-09-15). Source: `crates/model/src/instruments/any.rs`, PyPI.
2. "ORE 1.8.17.0 GitHub release and PyPI wheel dated 2026-09-15" became: GitHub release 2026-09-15, **PyPI wheel 2026-09-14** (17:35 UTC). Source: GitHub releases API, PyPI JSON.
3. "tf-quant-finance is archived" became: its README declares it "no longer maintained and has been archived", but the GitHub repo is **not** flagged as archived (occasional build commits through 2026-08). It is still treated as unmaintained. Source: GitHub API, README.
4. "Rateslib and FinancePy are both fine for research and only a problem in distributed apps; use them as test oracles" became: this holds for FinancePy (GPL, internal use is fine). Rateslib's free licence **forbids any commercial/professional use, use in a trading application, and use as a benchmark or validator for corporate code**, so the oracle role needs the paid licence. The TL;DR, recommendations (a)8 and (b)6, and the risks section were updated. Source: Rateslib licence page.
5. "Portfolio margin: ≥$100k equity (firm-dependent)" became: Rule 4210(g) sets only a $5M floor for unlisted derivatives, so the ~$100k+ minimum is broker policy. Source: FINRA Rule 4210 text.
6. A missing regulatory change was added: FINRA replaced the pattern-day-trader margin provisions with intraday margin standards (SR-FINRA-2025-017, SEC-approved Apr 2026, effective 2026-06-04). This affects US pre-trade margin checks. Source: FINRA Rule 4210, SR-FINRA-2025-017.
7. "Taiwan typhoon days are announced the same day" became: normally by 22:00 the evening before, sometimes on the day itself. Source: zh.wikipedia 颱風假, citing 天然災害停止上班及上課作業辦法.
8. A risk was added: QuantLib's `Taiwan` calendar hard-codes holidays only through 2026, so load the 2027 TWSE/TAIFEX schedule. Source: QuantLib `taiwan.cpp`.
9. The Binance funding formula was incomplete. It became `[P̄ + clamp(I − P̄, ±0.05%)] / (8/N)`, and the interval may be 4 h or 1 h rather than only 8 h. Source: Binance FAQ.
10. The library table was stale or incomplete. Added: vollib 1.0.11 supports only Python 3.9–3.13; fast-vollib 0.2.2 added SVI/SSVI and Heston surface fitting and is a single-maintainer 0.x project. Source: PyPI.
11. A missing option was added: a "buy instead of build" note covering commercial IV-surface data and pricing libraries for scenario (b).

**Unverifiable (5)**

1. CME SPAN 2 migration status ("moving to VaR-based SPAN 2"). The CME page blocked automated access and web search was unavailable in this pass.
2. The local test where vectorized Newton converged on ~96% of 1M random contracts. The result depends on the sampled distribution, and it was not re-run.
3. The typical broker portfolio-margin minimum (~$100k+) is general market knowledge, not checked per broker.
4. The commercial vendors named in the "buy instead of build" note (ORATS, OptionMetrics IvyDB, Cboe LiveVol, Numerix) come from general knowledge. Their products and pricing were not individually checked.
5. "Best-in-class" Rateslib bond conventions is an editorial judgement, not a checkable fact.
