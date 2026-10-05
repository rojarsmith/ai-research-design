**English** | [繁體中文](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md)

# ADR-0002: Backtest engine: extend NautilusTrader v2 rather than build or fork

## Status

**Proposed** · 2026-10-05 · Scope: scenarios 1 and 2. Phase 0 spikes will update this ADR (see *Confirmation*).

## Context and problem statement

The platform needs an event-driven backtest engine that shares its strategy code, order semantics and risk checks with paper and live trading. It must cover stocks, crypto, options and bonds across US/global markets, crypto venues and Taiwan (TWSE/TPEx, TAIFEX). Should we build that engine, adopt an open-source one, or fork one?

What the research found ([02](../../research/02-backtesting-engine.md), [10](../../research/10-open-source-platforms-build-vs-buy.md)):

- **No engine covers the whole scope.** Neither NautilusTrader nor LEAN has a tradable bond type or Taiwan market rules. Neither ships a Taiwan broker adapter. The only engine with Taiwan connectors, StockSharp, became proprietary on 2026-07-16.
- **NautilusTrader** (Rust core, Python API, LGPL-3.0-only for v2) runs the same strategy code in backtest, sandbox and live. It has L1/L2/L3 matching, funding settlement from `FundingRateUpdate` data, 17 integrations (IBKR plus major crypto venues), built-in reconciliation and a deterministic kernel. It is mid-transition: 1.231.0 (2026-08-02) is intended as the last 1.x, and v1 security backports end around November 2026. The newest v2 build on PyPI is 2.0.0rc5 (2026-09-15); the rc6 notes are dated 2026-10-04. The RCs break configs: rc4 renamed `LiveExecClientConfig` to `ExecutionClientConfig`, and rc6 makes an explicit fee model mandatory and drops BitMEX. Upstream advises against RCs with real capital. There are no corporate actions in backtests, no early-assignment model and no Taiwan matching rules. On 2026-10-05 the lead maintainer had about 19,182 commits against 339 for the next contributor, and a commercial "Nautilus Pro" tier has been announced.
- **LEAN** (C#, Apache-2.0) is the most stable engine and has the best US equity and options models (map and factor files, survivorship-free US data). However, its Python is pinned to 3.11, its fill models assume complete fills, its assignment model is a heuristic, and it has no Taiwan or bond support.
- **Building our own engine** (Proposal B's Rust kernel and `SimVenue`) duplicates what NautilusTrader provides. B itself estimates that adopting NautilusTrader saves 30–40 PM.
- **Dormant or restrictive engines** (backtrader, QSTrader, zipline-reloaded; GPL Freqtrade; AGPL Backtesting.py) are unsuitable as a foundation.

## Decision drivers

- Backtest–live parity: the same code and order semantics in every mode.
- Time to the first live market for 1–3 people (about 12 PM base, 14–16 PM with contingency, in the roadmap).
- Correctness of the simulation: fees, funding, corporate actions, option lifecycle and Taiwan auction and limit rules.
- Containment of engine risk: RC churn, key-person risk, open-core risk and licence.
- The ability to change engines later without rewriting strategies.

## Considered options

1. **Extend NautilusTrader v2:** run it unmodified, add our adapters and simulation modules in separate packages, and keep it behind a `StrategyRuntime` port.
2. **Extend LEAN** (self-hosted, through the LEAN CLI).
3. **Build our own event-driven engine** (Proposal B).
4. **Fork NautilusTrader** and patch the core for bonds and Taiwan rules.
5. **Use a vectorized or crypto-only framework** (vectorbt, Freqtrade, Jesse, hftbacktest) as the only engine.
6. **Buy QuantConnect Cloud.**

## Decision outcome

**Chosen option: 1, "Extend NautilusTrader v2".** It is the fastest credible route to backtest–live parity for a small team. Its gaps are narrow enough to close with our own simulation modules, and the `StrategyRuntime` port bounds the cost of leaving it.

What "extend" means here:

| Element | Decision |
|---|---|
| Version | Exact pin `nautilus_trader==2.0.0rc5`; move to rc6 or GA in a planned upgrade window. Do not start on 1.231.x. Real money is gated by [ADR-0010](ADR-0010-real-money-gate-and-dependency-pinning.md) |
| Configuration | Every Nautilus config is built in `platform/runtime/` factories, which absorb RC renames in one place |
| Engine seam | `StrategyRuntime` port: `deploy(bundle, account, mode)`, `start()`, `stop()`, `halt(reason)`, `flatten(scope)`, `status()`. NautilusTrader is the only implementation in scenario 1. A LEAN implementation would wrap the same `tp_signals` in `QCAlgorithm` glue |
| No fork | We do not maintain a patched engine. We do not build Rust crates against Nautilus internals (C's `nautilus-ext` was rejected). Fixes go upstream where welcome |
| Fidelity | Bars plus L1 with pessimistic intra-bar ordering; options fill at bid/ask, never mid; no L2/L3 queue models in scenario 1 |
| Our simulation extensions (in `platform/runtime/nautilus/`) | **Fees:** explicit fee models built from the rules pack, including taxes, rounding and minimum fees (mandatory from rc6). **Funding:** replay of venue-published funding history; never recomputed from the formula when history exists. **Corporate actions:** splits, cash and stock dividends (including Taiwan stock dividends that create odd lots), capital reductions, delistings and OCC adjusted deliverables, applied on the ex-date while fills stay at raw prices (Phase 0 spike). **Taiwan rules:** call-auction fills at the auction price, no fills while limit-locked, the volatility interruption and the odd-lot book (Phase 0 spike). **Early assignment:** dividend-driven assignment for short American calls, plus a conservative heuristic for deep in-the-money short puts (Phase 3). **Borrow and financing (`BorrowModel`):** refuses short fills when the security was not shortable at the time or a rules-pack `short_sale` check fails (Rule 201 SSR, the Taiwan below-previous-close rule, 融券 suspension and forced-cover dates, quotas); accrues borrow fees and margin or 融資 interest daily; books payment in lieu on shorted dividends; models hard-to-borrow recalls as a configurable buy-in probability (Phase 1 for the first market if it shorts or uses margin; Taiwan in Phase 3a; [ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.md)) |
| Bonds | Not simulated in the event-driven engine. `Bond` is our own `tp_domain` type, valued daily with QuantLib. Bond ETFs are simulated as equities. There are no event-driven backtests on indicative OTC quotes |
| Vectorized tier | Our own (`tp_signals` batch functions plus a simple vectorized simulator); vectorbt is optional and internal-only. Covered in [ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.md) |
| Fallback | LEAN is the documented fallback. It is rehearsed once on a reference strategy in **Phase 3c** (about weeks 44–56 for two people, 0.5 PM), and the rehearsal report updates the port-cost estimate below |

### Cost of a forced move to LEAN

The `StrategyRuntime` port bounds the cost of leaving NautilusTrader, but it does not make the move cheap. Earlier wording ("weeks, not a rewrite") understated it. Everything engine-bound lives in `platform/runtime/nautilus/` and `adapters/` and must be rewritten for LEAN, mostly in C#.

| Part | Reused or rewritten | Estimate |
|---|---|---|
| `tp_signals`, `tp_risk`, `tp_domain`, `tp_rules`, `tp_calendars`, `tp_refdata`, `tp_data`, `tp_pricing`, `tp_metrics`, `tp_tax` | **Reused** (Python 3.11-compatible syntax is kept for this reason) | 0 |
| Rules-pack YAML, security master, corporate-action table, Parquet lake and manifests | **Reused**; LEAN needs map and factor files generated from the corporate-action table | 0.2 PM |
| Ledger, journal writer, reconciliation, API, UI, the TW gateway contract and the Shioaji sidecar | **Reused**; the journal writer needs a LEAN event translator instead of the Nautilus one | 0.3 PM |
| LEAN `IBrokerage` (C#) that speaks the TW gateway contract, plus its data queue handler | **Rewritten** | 0.6–1.0 PM |
| Simulation extensions as LEAN reality models: fee and tax models with rounding, TW auction and limit-lock fill model, odd-lot handling, `BorrowModel`, funding replay, early assignment | **Rewritten** (LEAN's own assignment model is a heuristic) | 0.7–1.2 PM |
| Runtime glue: `QCAlgorithm` wrappers around `tp_signals`, `GuardedStrategy` equivalent, intent-WAL hook, runtime factories, control actor | **Rewritten** | 0.3–0.6 PM |
| Golden masters and contract tests re-baselined against LEAN | **Rewritten** | 0.3 PM |
| **Total** | | **≈ 2.4–3.6 PM (quoted as 2–4 PM)**, plus a paper window before real money moves |

IBKR and the large crypto venues have LEAN brokerages already, so they need configuration and reconciliation testing rather than new code. A move to an own Rust core (B) is far larger and is not estimated here.

**Kill criterion (from Proposal B).** If the Taiwan simulation extensions slip more than three months past their phase exit, fall back to conservative bar-level rules and evaluate trigger T7 (a Taiwan-only simulator in the style of B's `SimVenue`).

### Consequences

**Positive**

- The first live market costs about 12 PM (base) instead of a multi-year engine build. The team's effort goes to the Taiwan adapter, the rules packs and correctness grafts.
- One kernel runs backtest, sandbox and live. The upstream IBKR and crypto adapters come with reconciliation.
- Engine-specific code is confined to `platform/runtime/` and `adapters/`, so a move to LEAN is a bounded port of about 2–4 PM (table above), not a rewrite of strategies, rules or records.

**Negative**

- RC churn: each upgrade can break configuration, and real money must wait for GA or for the soak gate.
- Key-person and open-core risk is accepted and tracked in the dependency-risk register ([ADR-0010](ADR-0010-real-money-gate-and-dependency-pinning.md)).
- LGPL-3.0-only obligations apply if the engine is ever distributed ([ADR-0009](ADR-0009-open-source-licensing-strategy.md)).
- The corporate-action and Taiwan matching extensions depend on v2 extension points that are still unverified (Phase 0).
- Bonds stay outside the engine, so bond strategies get daily valuation and carry analysis only.
- The simulation extensions, the Shioaji adapter, `GuardedStrategy`, the runtime factories and the WAL hook are written to NautilusTrader's APIs, so they are the part of our code that a forced engine move rewrites.

### Confirmation

Phase 0 spikes record their verdicts as updates to this ADR:

1. Maturity of the v2 out-of-tree adapter API (for the Shioaji adapter).
2. Whether Taiwan call auctions, limit-lock refusal, the volatility interruption and the odd-lot book can be expressed as Nautilus fill/matching extensions. If not, trigger T7.
3. A v2 mechanism for corporate-action cash and position adjustments inside `BacktestNode`.
4. A backtest of a reference strategy runs in CI and reproduces its golden event hash.
5. NautilusTrader's in-flight-order reconciliation works for each upstream adapter we use, checked against the per-venue recovery table in §3.4 of the [recommended architecture](../../architecture/recommended-architecture.md) ([ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.md)).

Phase 3c records the LEAN rehearsal and updates the port-cost table.

### Revisit when

- **T6:** GA slips past the Phase 2 exit, upstream rejects a change we need, the key maintainer leaves, or the licence or open-core model changes. Move to LEAN behind `StrategyRuntime`, or to B's own core if two or more senior Rust engineers are available.
- **T7:** the Taiwan rules cannot be expressed as extensions.
- **T10:** a desktop or self-hosted product must ship the engine. Use an LGPL-free core.
- **T5:** L2/L3 queue modelling is needed. Use Nautilus L3 or hftbacktest.

## Pros and cons of the options

| Option | Pros | Cons |
|---|---|---|
| 1. Extend NautilusTrader v2 | Parity by design; adapters and reconciliation included; Python strategies; most active project | RC churn; key-person risk; no corporate actions, early assignment, Taiwan rules or bonds out of the box |
| 2. Extend LEAN | Apache-2.0; stable; best US equity and options reality models | Python 3.11 (EOL 2027-10); C# core; complete-fill default; heuristic assignment; no Taiwan, no bonds |
| 3. Build own engine | Full control; bit-level design freedom | Infeasible for 1–3 people; the new matcher cannot be validated against an oracle |
| 4. Fork NautilusTrader | Deep changes possible | About 4.5k upstream commits in 9 months, so a fork drifts within weeks; LGPL publication duties if distributed |
| 5. Vectorized or crypto-only | Fast to start | No backtest–live parity across asset classes; GPL or Commons Clause licences |
| 6. QuantConnect Cloud | Weeks to start | High lock-in (data entitlements, infrastructure); no Taiwan; code and data live on their infrastructure |

## Links

- [Main report: backtesting row, risks and roadmap](../../README.md)
- [Recommended architecture §3.3, §5.4 and §5.6](../../architecture/recommended-architecture.md)
- [Evaluation record: grafts 1, 13, 14, 29 and 30; rejected elements in §4.3](../../architecture/evaluation.md)
- Research: [02 Backtesting engine](../../research/02-backtesting-engine.md) · [10 Build vs buy](../../research/10-open-source-platforms-build-vs-buy.md) · [11 Taiwan localization](../../research/11-taiwan-market-localization.md)
- Related ADRs: [ADR-0001](ADR-0001-core-engine-and-strategy-language.md) · [ADR-0010](ADR-0010-real-money-gate-and-dependency-pinning.md) · [ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.md) · [ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.md)
