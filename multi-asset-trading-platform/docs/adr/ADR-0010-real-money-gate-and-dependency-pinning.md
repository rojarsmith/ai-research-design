**English** | [繁體中文](ADR-0010-real-money-gate-and-dependency-pinning.zh-TW.md)

# ADR-0010: Real-money gate for a release-candidate engine, and dependency pinning

## Status

**Proposed** · 2026-10-05 · Scope: scenario 1, until NautilusTrader 2.0.0 GA is pinned; the pinning policy applies in all scenarios.

## Context and problem statement

[ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.md) builds on NautilusTrader v2, which is still a release candidate:

- 2.0.0rc5 (2026-09-15) is the newest build on PyPI; the rc6 notes are dated 2026-10-04. No GA date is published.
- Upstream advises against running RCs with real capital.
- The RCs break things. rc3 removed the Cython package, rc4 renamed `LiveExecClientConfig` to `ExecutionClientConfig`, and rc6 makes an explicit fee model mandatory and drops BitMEX.
- The stable 1.231.x line receives only critical security backports, ending around November 2026, which is before any realistic go-live.

Other dependencies churn too ([main report risks](../../README.md)):

- DuckDB 2.0 (2026-10-21; 1.5 reaches end of life on 2026-11-01).
- Python 3.15 (2026-10-09).
- The pandas 3 / 2.3 split, and Polars 2.0 release candidates.
- Tauri v3 alpha.
- Shioaji's 14-day release cycle (1.7.6 was yanked).
- The `ibapi` crate pinned at `=3.3.0` while crates.io has 5.0.0.
- QuantLib's Taiwan calendar, which stops at 2026.
- LEAN's Python 3.11, which reaches end of life in 2027-10.

There is also key-person risk: about 19,182 commits by NautilusTrader's lead maintainer against 339 for the next contributor, and an announced "Nautilus Pro" tier.

When may real money run on this stack, and how are versions controlled?

## Decision drivers

- Do not trade real capital on software its maintainers call unready, without compensating controls.
- Do not stall the roadmap waiting for an unannounced GA.
- Make upgrades safe and repeatable for one operator.
- Keep dependency risks visible and owned.

## Considered options

1. **Go live on 1.231.x (stable v1)** and port to v2 later.
2. **Go live on a pinned RC** with no extra gate.
3. **Wait for GA** before any real-money trading.
4. **A real-money gate:** GA, *or* a pinned RC that passes a 30-day paper soak with zero unexplained reconciliation breaks, plus a signed risk-acceptance ADR and capital capped at 10% until GA. Add a dependency-risk register and a strict pinning policy.

## Decision outcome

**Chosen option: 4.** It turns "RC with real money" from an open risk into a measured, capped and documented one. It does not block Phase 2, and it avoids investing in a v1 line whose support ends before go-live.

### The gate

Live capital requires **either**:

- **(a)** a pinned NautilusTrader **2.0.0 GA**; **or**
- **(b)** a pinned release candidate that has:
  - passed a **30-day paper soak** (sandbox and/or venue paper) of the exact bundle and engine pin, with **zero unexplained reconciliation breaks**;
  - a **signed risk-acceptance ADR**, written as its own numbered ADR when the gate is used. A solo operator signs it with the written checklist and a 24-hour cooling-off period;
  - **capital capped at 10%** until GA.

`assert_real_money_gate(bundle, accounts)` in the runtime factory checks the pin, the soak record and the cap whenever a node starts in `LIVE` mode, and refuses to start otherwise. Falling back to 1.231.x is only a stopgap.

### Pinning and upgrade policy

| Rule | Detail |
|---|---|
| Exact pins | `nautilus_trader==2.0.0rc5` (exact) and hash-pinned lockfiles (`uv.lock`, npm lockfile). Container images are referenced by digest |
| One main image | Python 3.14 and pandas 3 through Phase 2. A `legacy-quant` image only when Phase 3 needs it |
| Adoption delay | New versions wait 3–7 days before adoption (supply-chain hygiene) |
| Maintenance window | Monthly: NautilusTrader RCs, Shioaji (14-day cycle), Python patches, DuckDB 2.0, QuantLib (quarterly) |
| Upgrade test | Every upgrade runs the golden-master replays (event hash on the same platform), adapter contract tests and reconciliation tests before it reaches a live node |
| Rollback | Redeploy the previous image digest and bundle. Live code is never hot-patched |
| Configuration churn | All engine configuration is built in `platform/runtime/` factories, so a rename is a one-place change |

### Dependency-risk register

A register maintained in the repository (a Phase 0 deliverable). Each entry has an owner, a trigger and a fallback. Initial entries:

| Dependency | Risk | Mitigation or fallback |
|---|---|---|
| NautilusTrader | Key-person concentration; open-core (Nautilus Pro); RC churn; no GA date | Thin `tp_signals` and the `StrategyRuntime` port; at least one Rust reader; the LEAN fallback rehearsed once in Phase 3c, with a 2–4 PM port estimate ([ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.md)); trigger T6 |
| Rust `ibapi` crate (`=3.3.0`) | Effectively one maintainer; two majors behind crates.io | ib_async (BSD-2) is independent and already used by the kill switch; the MIT crate can be vendored or forked |
| Shioaji | 14-day releases, yanked versions, traffic caps that return empty values | Sidecar boundary, exact pins, contract tests, empty response treated as an alarm, Fubon Neo as fallback |
| DuckDB | 2.0 on 2026-10-21; 1.5 end of life on 2026-11-01 | Phase 0 upgrade test ([ADR-0004](ADR-0004-parquet-lake-for-historical-data.md)) |
| Python | 3.15 on 2026-10-09; LEAN fallback pinned to 3.11 (end of life 2027-10) | Adopt 3.15 in 2027 after verifying wheels; keep `tp_signals` 3.11-compatible |
| QuantLib calendars | Taiwan calendar ends in 2026 | Load the 2027 TWSE/TAIFEX holidays before year-end ([ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.md)) |
| Tauri | v3 in alpha | Pin 2.x |

### Consequences

**Positive**

- Real money starts at most 10% of capital on an RC, and only after evidence that reconciliation is clean.
- The roadmap is not hostage to an unannounced GA date.
- Upgrades become a routine, tested monthly event instead of an incident.
- Dependency risks have owners and fallbacks before they bite.

**Negative**

- The 30-day soak would lengthen the path to first live by up to a month if it ran on its own. The roadmap runs it inside the G2 paper window (Phase 2b), so first live stays at about month 8–9 for two people; it does extend the trade-count route for a high-turnover strategy to at least 30 days.
- The 10% cap limits returns until GA.
- Each RC bump still costs engineering time, and the soak may have to restart if the pin changes before go-live.
- The monthly window and the register are standing operational duties for a small team.

### Confirmation

- `assert_real_money_gate` has unit tests and is exercised by a deliberate failed start in the go-live drill.
- The soak record and the risk-acceptance ADR are attached to the G3 approval record ([ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.md)).
- The register is reviewed in every monthly maintenance window.

### Revisit when

- NautilusTrader 2.0.0 GA is published → pin it, re-run the golden masters and lift the 10% cap through normal G4 ramping.
- **T6:** GA slips past the Phase 2 exit, or a licence or open-core change → LEAN or an own core.
- A register entry's trigger fires.

## Links

- [Main report: bottom line ("Gate real money"), scenario 1 and risks](../../README.md)
- [Recommended architecture §3.3, §3.12 and §8.3](../../architecture/recommended-architecture.md)
- [Evaluation record: grafts 1, 2 and 33; concerns 1 and 2; §6 v1-versus-v2 resolution](../../architecture/evaluation.md)
- Research: [01 Core language](../../research/01-core-language-runtime.md) · [02 Backtesting engine](../../research/02-backtesting-engine.md) · [10 Build vs buy](../../research/10-open-source-platforms-build-vs-buy.md)
- Related ADRs: [ADR-0001](ADR-0001-core-engine-and-strategy-language.md) · [ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.md) · [ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.md) · [ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.md)
