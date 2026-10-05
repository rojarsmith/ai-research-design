**English** | [繁體中文](ADR-0014-two-tier-backtesting-and-promotion-gates.zh-TW.md)

# ADR-0014: Two-tier backtesting with one indicator library, a determinism contract and evidence-based promotion gates

## Status

**Proposed** · 2026-10-05 · Scope: scenario 1, with platform-wide trial counting in scenario 2.

## Context and problem statement

Parameter sweeps need cheap vectorized runs. Realistic fills, fees, funding, corporate actions and option lifecycle need an event-driven run. If the two tiers use different indicator code, they disagree for reasons unrelated to look-ahead bugs, so the disagreement test becomes noise. If trials are not counted, overfitting statistics such as the Deflated Sharpe Ratio (DSR) are meaningless. A 2026 study that logged every evaluation rejected every LLM-discovered strategy it tested ([02](../../research/02-backtesting-engine.md)). How do research results become live strategies, safely and reproducibly?

Forces ([02](../../research/02-backtesting-engine.md), [09](../../research/09-research-ml-analytics.md), [evaluation](../../architecture/evaluation.md)):

- **Reproducibility.** CPython math, NumPy SIMD dispatch and multithreaded reductions are not bit-reproducible across operating systems and CPUs. Proposal B's cross-platform bit-identical promise was rejected as stated.
- **Tooling on 2026-10-05:**
  - vectorbt 1.x (Apache-2.0 with Commons Clause; single maintainer);
  - skfolio 1.4.11 `CombinatorialPurgedCV` (BSD-3);
  - MLflow 3.16;
  - the R `pbo` package;
  - QuantStats for presentation.
- **Engine.** The event-driven engine is NautilusTrader `BacktestNode` with our simulation extensions ([ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.md)).

## Decision drivers

- No strategy reaches real money on vectorized evidence alone.
- Disagreement between tiers must signal a real bug.
- Every result is reproducible from a manifest.
- An honest trial count, including AI-generated variants.
- Gates are cheap enough for one person to run mechanically, with a solo four-eyes substitute.

## Considered options

1. **Two tiers sharing one indicator library (`tp_signals`, batch and incremental), a CI-enforced determinism contract, an MLflow trial registry, and gates G0–G4.**
2. **Event-driven only.** Simple, but too slow for sweeps and cross-validation folds.
3. **vectorbt for screening and NautilusTrader for validation, with separate indicator code** (Proposal A's original design).
4. **Ad-hoc notebooks with a manual review.**

## Decision outcome

**Chosen option: 1.** Sharing `tp_signals` across tiers turns the 10%/no-sign-flip agreement rule into a real look-ahead and cost-model detector. Manifests and golden masters make every result reproducible, and the registry makes DSR and PBO honest.

### Tiers

| Tier | Implementation | Use |
|---|---|---|
| Vectorized | `tp_signals` batch functions plus a simple vectorized portfolio simulator over Polars/NumPy. vectorbt 1.x is optional and **internal-only** ([ADR-0009](ADR-0009-open-source-licensing-strategy.md)) | Screens, sweeps, CPCV folds |
| Event-driven | `tp backtest run --bundle <sha> --data-manifest <hash> --seed <n>` builds a `BacktestNode` through the runtime factory: bars plus L1, pessimistic intra-bar ordering, explicit fee models, funding replay and our simulation extensions | The **only** tier whose results can be promoted |
| Agreement | For the same configuration, total return must agree within **10% with no sign flip**, or promotion is blocked | Usual causes: look-ahead bugs or cost-model gaps |

`tp_signals` holds pure indicator and signal functions in batch and incremental versions, tested against each other.

### Determinism contract (enforced in CI)

1. **No ambient inputs.** No wall clock, I/O or unseeded randomness in decision code (lint). `PYTHONHASHSEED` is fixed in backtest workers, and decision code does not iterate over sets.
2. **Stable ordering.** Multi-source data is merged by `(ts_init, source priority, sequence)`.
3. **Fixed-point** wherever a decision touches money ([ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md)).
4. **A run manifest for every run:** bundle (`git SHA + config hash + rules-pack hash + engine pin`), lockfile hash, image digest, data-manifest hash, seeds, `trial_group_id` and output event hash.
5. **Golden masters.** On the same platform and image the event hash must match **exactly**. Across operating systems and CPU architectures, results must stay within **documented tolerances**.
6. **Parallelism only across runs** (multiprocessing or local Ray), never within one run.

### Trial registry and metrics

- **MLflow 3.16**: SQLite in Phases 0–1, the PostgreSQL backend from Phase 2. **Every variant is a run**, including AI-generated ones, grouped by `trial_group_id`.
- `tp_metrics` (Sharpe, Sortino, drawdown, turnover, PSR, DSR, PBO via CSCV) is the source of truth and is unit-tested against reference values. QuantStats is pinned and used for presentation only.
- Cross-validation uses skfolio `CombinatorialPurgedCV` with purge and embargo, or walk-forward.

### Promotion gates

| Gate | Entry criteria (starting points, calibrated per strategy class) |
|---|---|
| **G0 Research** | Hypothesis and data lineage written before testing; every variant logged |
| **G1 Backtest** | Walk-forward or CPCV; **DSR ≥ 0.95**; **PBO ≤ 0.2**; more than 70% of CPCV paths positive; out-of-sample Sharpe at least 50% of in-sample; profitable with fees, slippage and borrow and financing costs doubled, with shorts refused when not borrowable (`BorrowModel`, [ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.md)); tier agreement; capacity estimate; corporate-action coverage for equities held across ex-dates; early-assignment coverage for short American options; funding replayed for perpetuals |
| **G2 Paper** | At least 3 months, *or* the trade-count route for the strategy's class: intraday (≥ 3 round trips a day) ≥ 200 round trips and ≥ 6 weeks; swing ≥ 60 round trips and ≥ 8 weeks; position strategies have no trade-count route; defined-risk options ≥ 30 closed positions and ≥ 2 expiry cycles. Never shorter than the 30-day soak while the engine is a release candidate. Slippage and tracking error within bands; clean reconciliation; no manual overrides ([recommended architecture](../../architecture/recommended-architecture.md) §8.2) |
| **G3 Live (small)** | Real-money gate ([ADR-0010](ADR-0010-real-money-gate-and-dependency-pinning.md)); go-live checklist; 10% capital; an independent approver or, for a solo operator, a signed checklist ADR plus a 24-hour cooling-off period |
| **G4 Live (scaled)** | 25%, then 100%, while live P&L stays inside the backtest's Monte Carlo 95% band; quarterly re-validation; automatic `REDUCING`/`HALTED` outside the band |

**Mechanics.** A promotion writes the MLflow stage tag for the bundle. The live node loads only bundles carrying the stage that the account's mode requires, and **refuses unregistered bundles**. A configuration change creates a new bundle version; live code is never hot-patched. Rollback means flattening or handing over, then redeploying the previous bundle.

**AI assistance.** Read-only MCP tools over the lake. AI-written code runs in a container with no network and no credentials. Broker MCP servers are allowed on paper accounts only. These rules are only part of the guardrails that research 09 calls non-negotiable; the full **AI trust boundary** is [ADR-0017](ADR-0017-ai-trust-boundary.md): LLM output becomes proposals only, through `tp_risk` and human approval; AI-scoped tokens with no order, control or limit rights; no access to Telegram control or SOPS/age keys; news and filings treated as prompt-injection vectors; a prompt and tool-call audit log; an `llm_export_allowed` licence check; and no coding agents on the key-holding host.

### Consequences

**Positive**

- Look-ahead bugs and cost-model gaps surface as tier disagreements before any money is at risk.
- Any result, live or backtest, can be reproduced from its manifest. Golden masters catch regressions on every merge.
- DSR and PBO rest on an honest trial count, which protects against self-deception and against AI-generated overfitting.
- The live node cannot run code that has not passed the gates.

**Negative**

- Every indicator must be written twice (batch and incremental) and kept equivalent by tests.
- Gate evidence takes calendar time: at least 3 months of paper trading, or the per-class trade-count route, before live. Effort cannot shorten it, which is why the roadmap splits Phase 2 into building the paper stack (2a), the paper window (2b) and first live (2c).
- Cross-platform comparisons need maintained tolerances instead of exact hashes.
- MLflow and the registry discipline add overhead to every experiment.

### Confirmation

- CI jobs: wall-clock and I/O lint, golden-master replay on every merge, tier agreement before G1, and `tp_metrics` reference tests.
- `assert_real_money_gate` and the bundle-stage check run at node start.
- Promotion records (MLflow tags plus signed checklists) are attached to each G3 or G4 decision.

### Revisit when

- **T11:** AI-generated strategies or automated factor mining → platform-wide trial counting, sandboxed code execution and human approval before any order, before Phase 2.
- Scenario 2: JupyterHub with sandboxed kernels, Ray on Kubernetes, MLflow role-based access control, platform-wide DSR deflation, and an optional LEAN differential oracle for US equities.
- **T5:** queue-sensitive strategies → L2/L3 fidelity and TCA-calibrated fill models.

## Links

- [Main report: backtesting row, design principles 2 and 10, the data-flow table and phases 1–2](../../README.md)
- [Recommended architecture §3.8, §4.9, §5.5, §8.1 and §8.2](../../architecture/recommended-architecture.md)
- [Evaluation record: grafts 11, 12, 15 and 16; concern 9](../../architecture/evaluation.md)
- Research: [02 Backtesting engine](../../research/02-backtesting-engine.md) · [09 Research, ML and analytics](../../research/09-research-ml-analytics.md) · [01 Determinism](../../research/01-core-language-runtime.md)
- Related ADRs: [ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.md) · [ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md) · [ADR-0004](ADR-0004-parquet-lake-for-historical-data.md) · [ADR-0010](ADR-0010-real-money-gate-and-dependency-pinning.md) · [ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.md) · [ADR-0017](ADR-0017-ai-trust-boundary.md)
