**English** | [繁體中文](09-research-ml-analytics.zh-TW.md)

# Research Environment, Quant Analytics, AI/ML & Performance Analytics

> Research snapshot as of 2026-10-05. Versions and dates come from PyPI and project pages checked on that date (see References). Recheck them before you pin dependencies.

## TL;DR

- **Build on Arrow-native tools.** Store data as Parquet, use DuckDB for SQL and as-of joins, use Polars for transformations, and keep pandas 3.0 at library boundaries. Three "reloaded" Quantopian packages (`zipline-reloaded`, `alphalens-reloaded` and `pyfolio-reloaded`) still require `pandas<3.0`, and so do Nixtla's `statsforecast`/`mlforecast`/`utilsforecast` and the Taiwan `FinMind` client. Run them in a separate legacy environment, or reimplement the few metrics you need.
- **Portfolio construction and analytics.** Use skfolio (scikit-learn-style API with purged/combinatorial cross-validation built in) plus cvxpy. Add Riskfolio-Lib when you need its wide range of risk measures. PyPortfolioOpt is "mature" (no major new features), but it is now co-maintained under the PyPortfolio GitHub org and 1.6.0 added pandas 3 support. QuantStats has been active again since mid-2025 (latest 0.0.86, Sep 2026) and works well for tear sheets, but keep your own tested metrics module as the source of truth.
- **ML.** Gradient-boosted trees on engineered, point-in-time features are still the workhorse. Time-series foundation models (TSFMs) work as baselines and for volatility, volume or covariate forecasting. They are not alpha engines: 2025–26 studies find that zero-shot TSFMs either underperform on returns or give only small, sparse gains. The newest top-ranked weights also forbid commercial use (TimesFM 3.0 is non-commercial; Moirai 2.0 is CC-BY-NC).
- **MLOps.** Self-host MLflow (Apache-2.0) as the experiment registry and as the trial counter that overfitting statistics such as the Deflated Sharpe Ratio need. Version data with immutable Parquet snapshots or DVC. Note that lakeFS moved to the Business Source License (BSL) in September 2026: only unmodified, internal production use is allowed, so it cannot sit inside a production system that serves people outside your organization.
- **LLMs and GPUs.** Give LLMs only read-only MCP data and filings tools, and run AI-written strategy code in a sandbox. LLMs only produce *proposals*. Only the deterministic risk engine plus human approval can reach the order management system (OMS). GPU dataframes (RAPIDS cuDF, the Polars GPU engine) pay off only for tick data, options-surface data and deep models. They need Linux or WSL2, and RAPIDS 26.08 pins older pandas (`<3.0.4`) and Polars (`<1.43`) releases.

## Key questions

1. Which notebook/IDE and dataframe stack gives reproducible research that becomes production code without a rewrite?
2. Which factor and portfolio libraries are maintained and compatible with pandas 3 as of late 2026?
3. Where does ML (including foundation models and LLMs) add measurable value in finance, and where is it mostly hype?
4. How do we track experiments, data and model versions so that the number of trials is known and results can be reproduced?
5. How do we let AI assistants help without ever giving them a path to place orders?
6. Which overfitting controls and promotion gates sit between research, backtest, paper trading and live trading?
7. Is GPU acceleration worth the platform constraints it brings?

## Options compared

### 1. Research environment

| Tool | Status (Oct 2026) | License | Strengths | Weaknesses | Best fit |
|---|---|---|---|---|---|
| JupyterLab | 4.6.4 (Sep 2026) | BSD-3 | Largest ecosystem; JupyterHub for multi-user; any kernel | `.ipynb` JSON diffs badly; hidden out-of-order state | Exploration; team hubs |
| VS Code notebooks | Monthly releases | Free (Code-OSS is MIT) | Same editor as production code, debugger, AI assistants | Same `.ipynb` hidden-state problem | Solo developers who are also engineers |
| marimo | 0.25.1 (1 Oct 2026); team joined CoreWeave (30 Oct 2025) and stays open source | Apache-2.0 | Reactive dataflow graph means no hidden state. Notebooks are pure `.py` files: git-diffable, runnable as scripts, can be served as apps | Younger ecosystem; expensive cells re-run reactively unless you guard them | Reproducible research notebooks and internal dashboards |
| Positron (Posit) | 2026.09 | Elastic License 2.0 (source-available) | Data explorer, Python and R in one IDE | ELv2 forbids offering it as a hosted service | Teams that mix R and Python |

### 2. Dataframe and query engines

| Engine | Latest | Model | Strengths | Weaknesses | Role |
|---|---|---|---|---|---|
| pandas 3.0 | 3.0.0 (21 Jan 2026), now 3.0.6 (17 Sep 2026); 3.1.0rc0 out 30 Sep 2026 | Eager, NumPy/Arrow | Universal interop. Copy-on-Write is now the *only* mode. Default `str` dtype (PyArrow-backed when installed). Datetimes no longer forced to nanoseconds | Breaks chained assignment; many quant libraries pin `<3`; single-threaded | Library-boundary format, small data |
| Polars | 1.44.2 (Sep 2026); 2.0.0rc2 out 20 Sep 2026 | Lazy/eager, Rust, multithreaded, streaming | Fast `join_asof` and rolling windows; low memory use; GPU engine (beta) | API still changes between minor releases, and a 2.0 major release is imminent; the GPU engine (`cudf-polars` 26.08) requires `polars<1.43`; fewer finance libraries accept it natively | Feature engineering and signal code shared with production |
| DuckDB | 1.5.6 (28 Sep 2026); 2.0.0 scheduled for 21 Oct 2026 (tentative); 1.5 end of life 1 Nov 2026; 1.4 LTS community support until 17 Nov 2026 | Embedded SQL OLAP | Queries Parquet/Iceberg in place; `ASOF JOIN`; larger-than-memory; no server | Single-node; one writer process | Research query layer, local lake, ad hoc SQL |
| Ibis | 12.0.0 (Feb 2026) | Portable expression API | One API compiled to DuckDB, Polars, Postgres, Spark, BigQuery and others | Extra abstraction; slower release cadence | Teams that expect to move from local DuckDB to a warehouse |

### 3. Factor research and portfolio construction

| Library | Latest (date) | License | What it does | Maintenance and compatibility |
|---|---|---|---|---|
| Alphalens-reloaded | 0.4.6 (Jun 2025) | Apache-2.0 | Factor IC, quantile returns, turnover tear sheets | Requires `pandas<3.0`; only one commit since Sep 2024 |
| Microsoft Qlib | `pyqlib` 0.9.7 (15 Aug 2025) | MIT | End-to-end ML factor pipeline (Alpha158/360 features, model zoo, backtester); RD-Agent for LLM-driven factor mining | Commits continue (last Sep 2026) but no release in more than 13 months; data focus is China and US; heavyweight framework. The separate RD-Agent project (MIT) reached 1.0.0 on 23 Sep 2026 |
| cvxpy | 1.9.3 (Sep 2026) | Apache-2.0 | General convex modeling | You write the model yourself; production portfolios usually need a commercial solver |
| Riskfolio-Lib | 7.4.0 (4 Oct 2026) | BSD-3 | Very wide set of risk measures (CVaR, CDaR, EVaR …), HRP/HERC, Black-Litterman | Active; large API surface; essentially one maintainer |
| PyPortfolioOpt | 1.6.0 (26 Feb 2026) | MIT | Mean-variance, Black-Litterman, HRP, discrete allocation | Roadmap still calls it "mature" (no major new features). The repo moved to the PyPortfolio GitHub org with new co-maintainers; 1.6.0 added pandas 3 and Python 3.14 support |
| skfolio | 1.4.11 (3 Oct 2026) | BSD-3 | scikit-learn-compatible estimators; `CombinatorialPurgedCV` with purge and embargo; walk-forward validation; hyperparameter search | Active; the best fit for ML-style validation of allocations |

### 4. Performance analytics

| Option | Latest | License | Notes |
|---|---|---|---|
| QuantStats | 0.0.86 (27 Sep 2026) | Apache-2.0 | Dormant from Jul 2023 to Jul 2025, then revived (0.0.64–0.0.77 in Jul–Sep 2025, 0.0.78–0.0.81 in Jan 2026). Releases 0.0.82–0.0.86 shipped on 26–27 Sep 2026 and include "statistical corrections" (trade statistics, rolling Sharpe/Sortino, drawdown, risk-free handling), so metric definitions changed: pin the version. Its HTML tear sheets are good for reporting |
| quantstats-lumi | 1.1.5 (Jun 2026) | Apache-2.0 | Lumiwealth fork, created during QuantStats' dormancy |
| pyfolio-reloaded / empyrical-reloaded | 0.9.9 / 0.5.12 (Jun 2025) | Apache-2.0 | pyfolio requires `pandas<3`; empyrical does not. Little activity since mid-2025 |
| In-house metrics module (Polars) | n/a | n/a | **Recommended source of truth**: Sharpe/Sortino/drawdown/turnover, plus probabilistic and deflated Sharpe ratios, unit-tested against reference values. Use the libraries above only for presentation |

### 5. ML stack and time-series foundation models

The core stack is all permissively licensed and current: scikit-learn 1.9.1, LightGBM 4.7.0, XGBoost 3.4.1, PyTorch 2.14.1, Optuna 5.0.0, statsmodels 0.15.0, arch 8.0.0 (GARCH models; NCSA license), and Nixtla statsforecast 2.1.1/neuralforecast 3.2.2. Caveat: `statsforecast`, `mlforecast` 1.1.0 and `utilsforecast` 0.2.16 (a dependency of neuralforecast) all declare `pandas<3.0`, so the Nixtla stack belongs in the legacy (pandas 2.3) environment for now. For noisy tabular financial features, gradient-boosted trees remain the strongest default for cost versus accuracy. Deep sequence models need far more data and stronger regularization.

| Foundation model | Release | Size | Weights license | Notes for finance |
|---|---|---|---|---|
| TimesFM 2.5 (Google) | Sep 2025 | 200M params, 16k context | Apache-2.0 | Strong on general benchmarks; univariate |
| TimesFM 3.0 (Google) | Aug 2026 | ≈331M (Hugging Face weights metadata) | **Non-commercial, non-production**; production use allowed only through Google Cloud (BigQuery ML) | Natively multivariate with covariates; #1 on fev-bench, TIME and GIFT-Eval per Google |
| Chronos-2 (Amazon) | 20 Oct 2025 | 120M | Apache-2.0 | Zero-shot univariate, multivariate and covariate-informed; runs on CPU or GPU |
| Moirai 2.0 (Salesforce) | Weights Aug 2025; paper Nov 2025 | small variant (`moirai-2.0-R-small`) | **CC-BY-NC-4.0**, research only | `uni2ts` 2.0.0 pins `torch<2.5` and `numpy~=1.26`, so it needs an isolated environment |
| Kronos | arXiv Aug 2025; AAAI 2026 | 4.1M–102M open; 499M not released | MIT | Finance-native: tokenized OHLCV (candlestick, K-line) data from 45+ exchanges |

**What the evidence says:**
- Rahimikia, Ni and Wang (Nov 2025) ran the first large-scale TSFM study on 34 years of daily excess returns across 94 countries. Off-the-shelf TSFMs (Chronos, TimesFM) "perform poorly" zero-shot and after fine-tuning. Models pre-trained on financial data from scratch did much better. Note that it tested the earlier generations (original Chronos, TimesFM up to 500M), not Chronos-2, TimesFM 2.5 or 3.0.
- Noguer i Alonso and Franklin (Jun 2026) tested five liquid US stocks. Pretrained TSFMs (including the newer Moirai 2.0 and TimesFM 2.5) won 8 of 10 tasks against neural baselines, but gains over a random walk were "small and sparse."

**Use TSFMs for:**
- baselines;
- forecasting volatility, volume and liquidity;
- macro or covariate nowcasts;
- teams with little data.

Do not use them as a direct return signal.

### 6. Experiment tracking, data and model versioning, feature store

| Tool | Latest | License / ownership | Strengths | Caveats |
|---|---|---|---|---|
| MLflow | 3.16.1 (Sep 2026) | Apache-2.0, self-hostable | Runs, model registry, LLM/agent tracing; workspace role-based access control (RBAC) since 3.13 (May 2026); MCP server registry since 3.15 | You operate it yourself; the UI for deep-learning sweeps is weaker than W&B |
| Weights & Biases | SaaS | Now part of CoreWeave ("Forge") | Best UI for sweeps and deep learning. Free tier: up to 5 seats and 5 GB storage. Pro from $60/month (up to 10 seats; limited to teams under 50 employees) | Data leaves your premises unless you buy Enterprise; vendor consolidation risk |
| DVC | 3.67.1 (Mar 2026) | Apache-2.0; acquired by lakeFS (18 Nov 2025) and stays open source | Git-based pointers to data in object storage; light and suited to small teams | Awkward for very large, frequently appended tick data |
| lakeFS | v1.87.0+ (latest v1.88.0, 1 Oct 2026) | **Moved from Apache-2.0 to BSL (22 Sep 2026)**: production use is allowed only for the *unmodified* release and only for your organization's internal purposes. You may not make lakeFS or its functionality available to third parties, and the vendor's guidance says it cannot run "within a production system that is serving anyone outside of your organization." Releases up to v1.86.0 stay Apache-2.0; each BSL release converts to Apache-2.0 after 4 years | Git-style branches and commits over object storage; can isolate agents from production data | Blocks the "offer the platform to others" scenario unless you buy a commercial license, stay on v1.86.0 (no further fixes) or use Iceberg snapshots/DVC instead |
| Feast | 0.66.0 (Aug 2026) | Apache-2.0 | Online and offline feature serving with point-in-time joins | Requires `pandas<3`; overkill unless low-latency online features are shared across models |

### 7. LLM and agent integration

| Use case | Recommended pattern | Tools (2026) |
|---|---|---|
| Filings and news to structured events | Extract into a typed schema (event, entity, date, confidence); store with model version and prompt hash; human spot-checks | `edgartools` 5.60 (MIT; built-in MCP server; parses 10-K/10-Q/8-K, 13F, Form 4, XBRL). Taiwan: Market Observation Post System (MOPS, 公開資訊觀測站) filings and monthly revenue (月營收); FinMind (Apache-2.0 code; data offered for educational, non-commercial use; 300 requests/hour, 600 with a token; the 2.0.11 Python client requires `pandas<3`) |
| Sentiment signals | Batch-score and cache the results; anonymize company names to reduce look-ahead and "distraction" bias (Glasserman & Lin); only backtest periods *after* the model's training cutoff | Hosted LLMs for quality; small fine-tuned encoders for cheap bulk scoring |
| Market data for AI assistants | **Read-only** MCP servers; give each tool a scoped API key | Massive (formerly Polygon.io) MCP server: data only (stocks, options, FX, crypto, futures, Treasury yields). An in-house DuckDB-backed MCP server over the lake |
| Broker MCP servers | Paper accounts only, in a separate sandbox | The Alpaca MCP server V2 (2.3.2) *can place live stock, crypto and multi-leg option orders*. It defaults to paper trading (`ALPACA_PAPER_TRADE=true`). Use `ALPACA_TOOLSETS` to expose only data toolsets (leave out `trading`) when the assistant should be read-only. Never load live credentials into an LLM client |
| AI-assisted strategy coding | The LLM writes code against a typed strategy SDK. Code runs in a container with no network and no credentials. It must pass CI, backtest gates and human code review | Coding agents, MLflow tracing for agent sessions; Qlib RD-Agent for automated factor mining |

**Guardrails (non-negotiable):**
- An LLM never holds OMS or broker credentials. Its output is a *trade proposal* that goes through the same pre-trade risk engine as any strategy, then to a human for approval.
- These controls follow OWASP LLM01:2025 (least privilege and human-in-the-loop for privileged operations) and the 2026 FINRA report, which warns that agents may act "beyond the user's actual or intended scope."
- Treat all retrieved news, filings and web text as untrusted input that may contain prompt injection. Separate retrieval tools from action tools.
- Follow the MCP security best practices: no token passthrough, minimal scopes, sandboxed local servers, and per-client consent.
- Log every prompt, tool call and output for audit and reproducibility.
- Check data-vendor licenses before sending licensed market data to third-party LLM APIs.

### 8. GPU acceleration

| Workload | CPU (Polars/DuckDB) | GPU worth it? |
|---|---|---|
| Daily bars, about 5k stocks × 20 years (≈25M rows) | Seconds | No |
| Minute bars, multi-asset feature engineering | Fine with lazy/streaming execution | Marginal; rent a GPU when needed |
| Tick/L2 data, full options chains and implied-volatility surfaces | I/O- and memory-heavy | **Yes**, but often I/O-bound |
| Deep models, TSFM fine-tuning | Impractical | **Yes** (PyTorch) |
| GBDT on large panels | LightGBM on CPU is fine | XGBoost on GPU helps at scale |

**Facts behind the verdict:**
- RAPIDS cuDF 26.08 (Aug 2026) runs on Linux, or on Windows 11 only via WSL2 with a single GPU. RAPIDS lists a Volta-or-newer GPU (compute capability 7.0+) and CUDA 12 or 13. CUDA 13's own libraries (for example cuFFT and cuSPARSE) dropped pre-Turing GPUs, so plan on Turing or newer, or use the CUDA 12 builds on Volta.
- `cudf.pandas` gives zero-code-change acceleration with CPU fallback, but cuDF 26.08 pins `pandas>=3.0.0,<3.0.4`. That excludes the current pandas 3.0.4–3.0.6 and couples your pandas version to RAPIDS.
- The Polars GPU engine is in open beta: it passes 99.2% of Polars tests with CPU fallback and 88.8% without. Resampling and user-defined functions fall back to the CPU. Its backend (`cudf-polars` 26.08) requires `polars>=1.35,<1.43`, so a GPU image cannot use the current Polars 1.44.x.

**Verdict:** don't design the platform around GPU dataframes. Rent GPUs on demand for options-surface, tick and deep-model work.

### 9. How the four asset classes differ in this dimension

| Aspect | Stocks | Crypto | Bonds | Options |
|---|---|---|---|---|
| Research unit | Cross-sectional factors over a point-in-time universe | Time-series signals per venue/pair, plus cross-sectional factors over tokens | Curve factors (level, slope, curvature), spreads, carry/roll | Volatility surface (strike × expiry × time), Greeks |
| Main data traps | Survivorship bias, corporate actions, filing lags | 24/7 trading means you must define the daily close (e.g., 00:00 UTC); venue fragmentation; delisted or rugged tokens; short history | Instruments mature, so there are no continuous series; sparse over-the-counter (OTC) quotes; accrued interest | Huge data volume; stale quotes; early exercise and assignment; expiry effects |
| Analytics libraries | Alphalens, Qlib, skfolio | Polars/DuckDB on exchange data, plus funding-rate and on-chain features | QuantLib 1.43 (BSD-3): curves, duration and convexity | QuantLib, py_vollib 1.0.12 for implied volatility and Greeks; GPU helps here |
| ML suitability | Best understood; the benchmark is gradient boosting on factors | High noise and regime shifts; keep models simple and retrain often | Mostly rates and curve modeling; little ML at single-bond level | Volatility forecasting (GARCH, TSFMs) is more tractable than direction |
| Performance analytics | Return-based metrics (QuantStats) work | Mark-to-market every hour; include fees and funding | Duration-adjusted, carry versus price return | Margin-based returns and Greek P&L attribution; plain return tear sheets mislead |
| Taiwan notes | TWSE/TPEx ±10% daily price limits (no limit during a new listing's first five trading days); monthly revenue and institutional flows (三大法人) and margin data (融資融券) are unique signals; data from FinMind or TEJ (TQuant Lab is built on zipline, pyfolio and alphalens, and the FinMind client also pins `pandas<3`, so expect the pandas-2 constraint) | Local exchanges are regulated by the Financial Supervisory Commission (FSC, 金管會); global venues dominate research data | Thin local secondary market; mostly government-bond yield curves | TAIFEX index options (TXO, 臺指選擇權) including Wednesday- and Friday-expiry weekly series; the after-hours session (盤後交易, 15:00 to 05:00 the next day) complicates "daily" bar boundaries |

## Recommendations

### (a) Solo or 1–3 person MVP

| Layer | Choice | Why |
|---|---|---|
| Environment | VS Code (or Positron) plus **marimo** for any notebook that must be re-run; JupyterLab for scratch work; `uv` lockfiles | Reproducible notebooks you can review in git |
| Data | Parquet partitions on local disk or S3-compatible storage, **DuckDB** for queries and as-of joins, **Polars** for features; pandas 3 only at boundaries | Zero ops; fast; the same code later runs in production |
| Legacy quant stack | A separate `legacy-quant` environment (pandas 2.3) for alphalens/pyfolio/zipline-reloaded, the Nixtla forecasting packages and the FinMind client (or call FinMind's REST API directly), *or* reimplement IC, quantile returns and tear-sheet metrics in Polars (a few hundred lines) | Avoids the pandas<3 trap |
| Portfolio | **skfolio** (with `CombinatorialPurgedCV`) plus cvxpy; Riskfolio-Lib when you need exotic risk measures | Active, permissive licenses, ML-style validation |
| Performance | In-house metrics plus pinned QuantStats tear sheets | Stable definitions |
| ML | LightGBM plus scikit-learn pipelines plus Optuna; Chronos-2 or TimesFM 2.5 (Apache-2.0) only as baselines or volatility features | Cost versus value; no license traps |
| Tracking | MLflow with a local SQLite store and local artifacts; DVC *or* immutable, content-hashed Parquet snapshots | Trial counts and reproducibility from day one |
| LLM | Read-only MCP (in-house DuckDB, edgartools, a data vendor); AI coding in a sandbox; broker MCP on paper only | Productivity without order risk |
| GPU | None; rent one for deep-learning experiments | Constraints outweigh benefits |

### (b) 5–20 person team or institutional grade

- **Environment.** JupyterHub or a managed workspace with containerized, versioned kernels; marimo for notebooks that feed reports. Research code goes through pull request review and CI.
- **Data.** A lakehouse (Iceberg or DuckLake on object storage) with bitemporal, point-in-time tables. DuckDB and Polars stay the per-user engines; Ibis lets queries move to a warehouse when data outgrows one node.
- **Factor work.** An internal Polars factor library with a factor registry. Evaluate Qlib for cross-sectional equity ML, but fork or vendor it given its release cadence.
- **Portfolio.** skfolio and cvxpy with a commercial solver. Optimizer outputs pass through the same risk engine as live trading.
- **MLOps.** A self-hosted MLflow server (RBAC, model registry, LLM tracing) is the system of record; W&B Enterprise only if deep-learning sweeps dominate and SaaS is acceptable. Version data with Iceberg snapshots or lakeFS. The lakeFS BSL allows only unmodified, *internal* use, so if the platform will serve external users, use Iceberg snapshots or DVC, or buy a commercial lakeFS license. Add Feast only when several models share online features.
- **LLM.** A central MCP gateway with read-only, per-user-scoped tools, full audit logging and prompt-injection red-teaming. Agent output becomes proposals that go through four-eyes approval.
- **GPU.** A shared, scheduled Linux GPU pool (RAPIDS, Polars GPU, PyTorch) for options-surface, tick and deep-model work.

### Overfitting controls and promotion gates

The thresholds below are suggested starting points; calibrate them to each strategy class.

| Gate | Entry criteria | Evidence artifact |
|---|---|---|
| 0. Research | Hypothesis written *before* testing; data lineage recorded; every variant logged as an MLflow run, so the trial count *N* is known | MLflow experiment with all trials |
| 1. Backtest | Walk-forward or combinatorial purged cross-validation (CPCV) with purge and embargo; realistic costs, slippage, borrow and funding; Deflated Sharpe Ratio (computed from *N*) ≥ 0.95 probability; Probability of Backtest Overfitting (PBO) ≤ 0.2; parameter-stability surface; capacity estimate | Signed backtest report from the same signal code that runs live |
| 2. Paper | At least 3 months *or* N trades; live versus backtest tracking error and slippage within agreed bands; no manual overrides | Paper-trading P&L reconciliation |
| 3. Live (small) | Capital ramp schedule; kill switch; drawdown and exposure limits enforced by the risk engine; independent approver | Approval record, limit config |
| 4. Live (scaled) | Monitoring for decay and regime change; automatic de-risking when metrics break bands; quarterly re-validation | Monitoring dashboard, re-validation log |

AI-generated strategies and automated factor mining (for example RD-Agent) can multiply *N* by orders of magnitude. Count every generated candidate, or the deflated Sharpe ratio is meaningless.

## Impact on overall architecture

- **One signal codebase.** Package features and signals as a versioned Python library (Polars/Arrow) that the backtester, paper trading and live trading all import. Research notebooks only *call* it. This removes skew between research and production.
- **Arrow as the interchange format.** Parquet at rest, Arrow in memory, and Arrow Flight or IPC to a core engine written in another language (Rust, C#, Java). Point-in-time ("as-of") semantics must exist in the storage layer, not only in notebooks.
- **The experiment registry is a platform service.** MLflow run IDs link data snapshot, code commit, parameters, trial count and promotion decisions. The OMS should refuse to run a strategy version that has no approved registry entry.
- **Isolate dependencies by design.** Expect at least three runtime images: modern (pandas 3, Polars), legacy-quant (pandas 2.3), and deep learning/TSFM (pinned torch). Add a fourth, RAPIDS-pinned GPU image (pandas `<3.0.4`, Polars `<1.43` for RAPIDS 26.08) if you use GPU dataframes. Use containers, not one global environment.
- **Batch inference first.** Daily and intraday signals run as scheduled jobs. Online model serving (in-process LightGBM or ONNX) only when latency needs demand it.
- **The LLM layer stays outside the trading trust boundary.** Read-only MCP lets it see data; its proposals go to a queue, then the risk engine, then a human, then the OMS. The LLM never gets OMS credentials, and no network path from the sandbox reaches the broker.
- **Plan for Linux.** GPU and most quant infrastructure assume Linux, so Windows desktop research uses WSL2 or remote kernels.

## Risks and pitfalls

- **The pandas 3 migration splits the ecosystem.** The reloaded stack, Feast, Nixtla (statsforecast, mlforecast, utilsforecast) and the FinMind client pin `<3`, while cuDF 26.08 pins `>=3.0.0,<3.0.4` (which excludes the current 3.0.6); one environment cannot satisfy both. pandas 3.1 (rc0 on 30 Sep 2026) and Polars 2.0 (rc2 on 20 Sep 2026) are about to add another round of churn.
- **License traps.** TimesFM 3.0 and Moirai 2.0 weights are non-commercial. lakeFS BSL (v1.87.0+) forbids modified builds in production and any use inside a production system that serves people outside your organization. FinMind data is for educational, non-commercial use. Data-vendor terms may prohibit sending data to LLM providers.
- **Maintenance and consolidation.** Alphalens and pyfolio-reloaded have been quiet since Jun 2025; Qlib has had no release for 13+ months; QuantStats changed statistics in Sep 2026; DuckDB 1.5 reaches end of life on 1 Nov 2026 and 1.4 LTS community support ends on 17 Nov 2026, so plan the move to 2.0. CoreWeave now owns W&B and marimo, and lakeFS owns DVC.
- **Foundation-model hype.** Strong general benchmark rankings do not carry over to return prediction. Always compare against a random walk and a gradient-boosting baseline after costs.
- **LLM backtests are contaminated.** Training data includes the "future." Use only periods after the model's training cutoff, or anonymized inputs. Record the model version, because hosted models change silently.
- **Prompt injection through news and filings**, plus tool-poisoned or malicious MCP servers. Install MCP servers only from pinned, reviewed sources and run them sandboxed.
- **Uncounted trials.** Notebook tinkering and AI-generated variants inflate in-sample Sharpe. If it isn't logged, it isn't valid.
- **Misapplied analytics.** Return-based tear sheets applied to options or levered futures, or "daily" metrics on 24/7 crypto without a defined close, give misleading results.

## References

- pandas 3.0 release: https://pandas.pydata.org/community/blog/pandas-3.0.html ; https://pypi.org/project/pandas/
- Polars GPU support: https://docs.pola.rs/user-guide/gpu-support/ ; https://pypi.org/project/polars/
- DuckDB 1.5 / 1.4 LTS / release calendar: https://duckdb.org/2026/09/28/announcing-duckdb-156 ; https://duckdb.org/2025/09/16/announcing-duckdb-140.html ; https://duckdb.org/release_calendar
- Ibis: https://pypi.org/project/ibis-framework/
- marimo joins CoreWeave: https://marimo.io/blog/joining-coreweave ; https://pypi.org/project/marimo/
- JupyterLab: https://pypi.org/project/jupyterlab/
- Positron: https://positron.posit.co/
- Qlib: https://github.com/microsoft/qlib ; https://pypi.org/project/pyqlib/ ; https://github.com/microsoft/RD-Agent
- Alphalens-reloaded: https://pypi.org/project/alphalens-reloaded/ ; https://github.com/stefan-jansen/alphalens-reloaded
- pyfolio-reloaded / empyrical-reloaded / zipline-reloaded: https://pypi.org/project/pyfolio-reloaded/ ; https://pypi.org/project/empyrical-reloaded/ ; https://pypi.org/project/zipline-reloaded/
- QuantStats: https://github.com/ranaroussi/quantstats/releases ; https://pypi.org/project/quantstats/ ; https://github.com/Lumiwealth/quantstats_lumi
- skfolio CPCV: https://skfolio.org/generated/skfolio.model_selection.CombinatorialPurgedCV.html ; https://pypi.org/project/skfolio/
- Riskfolio-Lib: https://pypi.org/project/Riskfolio-Lib/
- PyPortfolioOpt: https://pypi.org/project/pyportfolioopt/ ; https://pyportfolioopt.readthedocs.io/en/latest/Roadmap.html
- cvxpy: https://pypi.org/project/cvxpy/
- TimesFM (2.5 / 3.0 licensing): https://github.com/google-research/timesfm
- Chronos-2: https://www.amazon.science/blog/introducing-chronos-2-from-univariate-to-universal-forecasting ; https://huggingface.co/amazon/chronos-2
- Moirai 2.0: https://huggingface.co/Salesforce/moirai-2.0-R-small ; https://arxiv.org/abs/2511.11698
- Kronos: https://github.com/shiyu-coder/Kronos
- Rahimikia, Ni, Wang, "Re(Visiting) Time Series Foundation Models in Finance": https://arxiv.org/abs/2511.18578
- Noguer i Alonso, Franklin, "Pretrained Time-Series Foundation Models for Financial Return Forecasting": https://arxiv.org/abs/2606.27100
- Glasserman, Lin, look-ahead bias in GPT sentiment: https://arxiv.org/abs/2309.17322
- MLflow releases: https://mlflow.org/releases ; https://github.com/mlflow/mlflow
- W&B / CoreWeave Forge pricing: https://wandb.ai/site/ ; https://coreweave.com/forge-pricing
- lakeFS acquires DVC: https://lakefs.io/media-mentions/lakefs-acquires-dvc-uniting-data-version-control-pioneers/
- lakeFS BSL change: https://lakefs.io/blog/lakefs-business-source-license/
- DVC: https://pypi.org/project/dvc/ ; Feast: https://pypi.org/project/feast/
- RAPIDS install requirements: https://docs.nvidia.com/datascience/install/ ; cudf.pandas: https://docs.nvidia.com/cudf/latest/cudf_pandas/ ; https://pypi.org/project/cudf-cu12/
- Alpaca MCP server: https://github.com/alpacahq/alpaca-mcp-server
- Massive (formerly Polygon.io) MCP server: https://github.com/massive-com/mcp_massive
- edgartools: https://github.com/dgunning/edgartools
- FinMind: https://github.com/FinMind/FinMind ; TEJ TQuant Lab: https://github.com/tejtw/TQuant-Lab
- OWASP LLM01:2025 Prompt Injection: https://genai.owasp.org/llmrisk/llm01-prompt-injection/
- MCP security best practices: https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices
- FINRA 2026 Annual Regulatory Oversight Report, GenAI: https://www.finra.org/rules-guidance/guidance/reports/2026-finra-annual-regulatory-oversight-report/gen-ai
- Bailey & López de Prado, Deflated Sharpe Ratio: https://www.davidhbailey.com/dhbpapers/deflated-sharpe.pdf
- Bailey, Borwein, López de Prado, Zhu, Probability of Backtest Overfitting: https://www.davidhbailey.com/dhbpapers/backtest-prob.pdf
- QuantLib / py_vollib: https://pypi.org/project/QuantLib/ ; https://pypi.org/project/py-vollib/
- Nixtla pandas pins: https://pypi.org/project/statsforecast/ ; https://pypi.org/project/mlforecast/ ; https://pypi.org/project/utilsforecast/
- FinMind client: https://pypi.org/project/FinMind/
- cudf-polars (Polars GPU backend) pins: https://pypi.org/project/cudf-polars-cu12/
- CUDA 13.0 architecture removals: https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/index.html
- TimesFM 3.0 weights card: https://huggingface.co/google/timesfm-3.0-pytorch
- lakeFS BSL text: https://github.com/treeverse/lakeFS/blob/master/LICENSE
- PyPortfolioOpt 1.6.0 release: https://github.com/PyPortfolio/PyPortfolioOpt/releases
- RD-Agent 1.0.0: https://github.com/microsoft/RD-Agent/releases ; https://pypi.org/project/rdagent/
- TWSE price limits: https://www.twse.com.tw/en/page/products/trading/introduce.html ; TAIFEX TXO: https://www.taifex.com.tw/enl/eng2/tXO

## Verification log (2026-10)

An adversarial fact-check ran on 2026-10-05 against PyPI JSON metadata, GitHub repositories and releases, Hugging Face model metadata, and official docs and announcements.

**Confirmed**
- pandas 3.0.0 came out on 21 Jan 2026; 3.0.6 on 17 Sep 2026. Copy-on-Write is the only mode, and the default `str` dtype is PyArrow-backed when pyarrow is installed (pandas blog, PyPI).
- alphalens-reloaded 0.4.6, pyfolio-reloaded 0.9.9 and zipline-reloaded 3.1.1 declare `pandas<3.0`. Feast 0.66.0 declares `pandas<3`. cudf-cu12 26.8.1 declares `pandas>=3.0.0,<3.0.4a0`. empyrical-reloaded has no upper pin (PyPI `requires_dist`).
- DuckDB 1.5.0 "Variegata" came out on 9 Mar 2026 and 1.5.6 on 28 Sep 2026. 2.0.0 is scheduled for 21 Oct 2026 (tentative). 1.4 LTS reaches end of life on 17 Nov 2026 (duckdb.org release calendar).
- pyqlib 0.9.7 came out on 15 Aug 2025 (MIT). Qlib commits continued to 16 Sep 2026.
- QuantStats 0.0.82–0.0.86 came out on 26–27 Sep 2026 with "statistical corrections" to trade statistics and rolling analytics (Apache-2.0).
- skfolio 1.4.11 (3 Oct 2026, BSD-3) has `CombinatorialPurgedCV(n_folds, n_test_folds, purged_size, embargo_size)`. Riskfolio-Lib 7.4.0 came out on 4 Oct 2026 (BSD-3) and PyPortfolioOpt 1.6.0 on 26 Feb 2026 (MIT).
- TimesFM 2.5 (Sep 2025, 200M parameters, 16k context) has Apache-2.0 weights. TimesFM 3.0 weights (Aug 2026, about 331M parameters) use `timesfm-non-commercial-license-v1.0`, which allows non-commercial, non-production use only; commercial use goes through Google Cloud/BigQuery ML (GitHub README, Hugging Face).
- Chronos-2 (blog post 20 Oct 2025; 120M parameters; CPU or GPU) is Apache-2.0. Moirai 2.0 weights are CC-BY-NC-4.0 and "for research purposes only."
- arXiv 2511.18578 (Rahimikia, Ni, Wang): 34 years and 94 countries of daily excess returns; off-the-shelf TSFMs perform poorly, and finance-native pretraining gives substantial gains. arXiv 2606.27100 (Noguer i Alonso, Franklin): five stocks, 8/10 wins over neural baselines, "small and sparse" gains over a random walk.
- lakeFS acquired DVC (18 Nov 2025), and DVC stays open source. lakeFS v1.87.0 (22 Sep 2026) is under BSL 1.1 with a four-year change date to Apache-2.0.
- Alpaca MCP server v2 (2.3.2, MIT) supports stock, crypto and single- or multi-leg options orders, and `ALPACA_PAPER_TRADE` defaults to `true`. The Massive MCP server only exposes Massive data APIs.
- RAPIDS needs Linux or Windows 11 via WSL2 (single GPU), compute capability 7.0+ and CUDA 12 or 13. The Polars GPU engine is in open beta and passes 99.2% of tests with CPU fallback and 88.8% without.
- These versions and dates match PyPI or GitHub: JupyterLab 4.6.4, marimo 0.25.1 (joined CoreWeave 30 Oct 2025, still Apache-2.0), Positron 2026.09 (Elastic License 2.0), Polars 1.44.2, Ibis 12.0.0, cvxpy 1.9.3, quantstats-lumi 1.1.5, empyrical-reloaded 0.5.12, scikit-learn 1.9.1, LightGBM 4.7.0, XGBoost 3.4.1, PyTorch 2.14.1, Optuna 5.0.0, statsmodels 0.15.0, arch 8.0.0, MLflow 3.16.1 (RBAC in 3.13, May 2026; MCP registry in 3.15, Jul 2026), DVC 3.67.1, Feast 0.66.0, edgartools 5.60.0 (MIT, built-in MCP server), QuantLib 1.43, py_vollib 1.0.12, uni2ts 2.0.0 (`torch<2.5`, `numpy~=1.26`), cuDF 26.08.
- Also confirmed:
  - Kronos: MIT; accepted at AAAI 2026; mini, small and base weights (4.1M–102.3M) are open, and the 499.2M large model is not; trained on data from 45+ exchanges.
  - W&B is now part of CoreWeave Forge: the free tier has 5 seats and 5 GB, and Pro starts at $60/month.
  - FinMind code is Apache-2.0; its data is for educational, non-commercial use; limits are 300 requests/hour, or 600 with a token.
  - TQuant Lab is built on zipline, pyfolio and alphalens.
  - Taiwan market rules: the TWSE ±10% price limit; TXO weekly series and the after-hours session.
  - Guidance documents: OWASP LLM01:2025 calls for least privilege and human-in-the-loop controls. The FINRA 2026 GenAI section has the quoted "beyond the user's actual or intended scope" wording. The MCP 2025-11-25 security best practices cover token passthrough, per-client consent, scope minimization and local-server sandboxing.
  - Glasserman and Lin (anonymization, look-ahead bias, "distraction effect").

**Corrected**
- QuantStats was described as "revived after years of dormancy" in Sep 2026. In fact it was dormant from Jul 2023 to Jul 2025, revived with 0.0.64–0.0.77 (Jul–Sep 2025) and 0.0.78–0.0.81 (Jan 2026), and the Sep 2026 burst is the latest round (source: PyPI release history, GitHub releases).
- Moirai 2.0 release date: "Nov 2025" became "weights Aug 2025 (Hugging Face repo created 6 Aug 2025); paper Nov 2025" (source: Hugging Face commit history, arXiv 2511.11698).
- TimesFM 3.0 size: "~330M (reported)" became "≈331M" (source: Hugging Face safetensors metadata, 330,710,976 parameters).
- lakeFS BSL scope: the draft said "internal use is fine, but hosting or reselling it as a service is prohibited." The actual terms: only unmodified releases may be used in production, and only internally. Neither lakeFS nor its functionality may be made available to third parties, and the vendor's guidance excludes any production system that serves people outside the organization (source: lakeFS LICENSE, lakeFS BSL blog post).
- "The core ML stack is all … current": Nixtla `statsforecast` 2.1.1, `mlforecast` 1.1.0 and `utilsforecast` 0.2.16 (a neuralforecast dependency) declare `pandas<3.0`. They were added to the legacy environment and to the risks (source: PyPI `requires_dist`).
- The FinMind client (2.0.11) declares `pandas<3.0.0`; this was missing from the Taiwan data path (source: PyPI).
- "cuDF 26.08 pins 3.0.x" became "`>=3.0.0,<3.0.4`, which excludes the current 3.0.4–3.0.6" (source: PyPI cudf-cu12).
- The Polars GPU engine was missing a version coupling: `cudf-polars` 26.08 requires `polars>=1.35,<1.43`, so it cannot run with the current Polars 1.44.x (source: PyPI cudf-polars-cu12/cu13).
- RAPIDS "Volta+ with CUDA 12 or 13": CUDA 13 libraries (cuFFT, cuSPARSE) dropped pre-Turing GPUs, so Volta in practice needs the CUDA 12 builds (source: CUDA Toolkit release notes).
- PyPortfolioOpt "mature (bug fixes only)": the repo moved to the PyPortfolio org with new co-maintainers, and 1.6.0 added pandas 3 and Python 3.14 support (source: GitHub release v1.6.0).
- Added items that would otherwise be stale:
  - pandas 3.1.0rc0 (30 Sep 2026).
  - Polars 2.0.0rc2 (20 Sep 2026).
  - DuckDB 1.5 end of life (1 Nov 2026).
  - RD-Agent 1.0.0 (23 Sep 2026).
  - lakeFS v1.88.0 (1 Oct 2026).
  - Alpaca `ALPACA_TOOLSETS` filtering for read-only use.
  - The fact that arXiv 2511.18578 tested earlier TSFM generations.
  - The W&B Pro team-size limit.
  - TXO Wednesday and Friday weeklies.

**Unverifiable**
- The legal status of Taiwan crypto exchanges. "Regulated by the FSC" is plausible: they register with the FSC under its anti-money-laundering (AML) rules. Whether the Virtual Asset Service Act has passed by Oct 2026 could not be confirmed.
- How well pandas 3 works in practice with skfolio, Riskfolio-Lib and QuantStats. They declare no upper bound on pandas (skfolio `>=2.1`, Riskfolio `>=2.2.2`, QuantStats `>=2.0`), but no pandas-3 CI results were checked.
- The current status of other hosted experiment trackers (for example Neptune.ai) could not be checked because the site blocked automated access. They are left out of the comparison, so check vendor continuity before adopting any of them.
