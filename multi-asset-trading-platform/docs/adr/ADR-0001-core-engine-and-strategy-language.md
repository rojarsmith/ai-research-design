**English** | [繁體中文](ADR-0001-core-engine-and-strategy-language.zh-TW.md)

# ADR-0001: Core engine language and strategy language

## Status

**Proposed** · 2026-10-05 · Scope: scenario 1 (1–3 people, self-use), with the scenario-2 evolution noted under *Revisit when*.

## Context and problem statement

The platform needs two language choices that are hard to reverse:

1. The language of the **core engine**: the event loop, order management system (OMS), pre-trade risk, matching simulator and market-data normalization.
2. The language that **strategy authors** write in. The same strategy code must run in backtest, paper and live trading ([design principle 1](../../README.md)).

The forces at play (research [01](../../research/01-core-language-runtime.md) and [10](../../research/10-open-source-platforms-build-vs-buy.md)):

- **Latency tier.** Scenario 1 targets decision-to-order latency of tens to hundreds of milliseconds, bars and L1 data, and holding periods from minutes to weeks. Market making and sub-10 ms strategies are out of scope. Broker round-trips dominate at this tier, so the core language is not the bottleneck.
- **Team.** One to three people, possibly growing to 5–20. Python is used by 57.9% of developers (Stack Overflow 2025), Rust by 14.8% and C# by 27.8%. A small team cannot also staff a Rust core.
- **Existing cores.** NautilusTrader v2 has a Rust core with a Python (PyO3) strategy API. It supports Python 3.12–3.14 on Linux x86_64/ARM64, macOS ARM64 and Windows x86_64, and needs glibc 2.35+ on Linux. QuantConnect LEAN has a C#/.NET 10 core and runs Python 3.11 through its pythonnet fork; Python 3.11 reaches end of life in October 2027.
- **Building our own Rust core** (Proposal B) puts the first live trade at about month 10 with roughly six engineers, including senior Rust staff. The feasibility judge scored that 3.0/10 for a small team ([evaluation](../../architecture/evaluation.md)).
- **Python versions.** On 2026-10-05, 3.14 is the only bugfix branch, 3.13 is security-only, and 3.15.0 ships on 2026-10-09.
- **Concurrency.** Determinism comes from a single-threaded event-driven kernel. Free-threaded CPython 3.14 adds thread nondeterminism, which is harmful in backtests.

## Decision drivers

- Time to the first live market for 1–3 people.
- Backtest–live parity: one strategy codebase in every mode.
- Research ecosystem (NumPy, Polars, DuckDB, SciPy, scikit-learn, QuantLib bindings).
- Hiring pool and bus factor of our own code.
- A deterministic kernel with fixed-point numerics ([ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md)).
- The cost of a forced engine change later (key-person risk, open-core risk, licensing).
- Cross-platform packaging for Linux servers and Windows/macOS desktops.

## Considered options

1. **Python strategies on an adopted Rust core (NautilusTrader v2).** We write no Rust in scenario 1.
2. **Python or C# strategies on an adopted C# core (LEAN, .NET 10).**
3. **Our own Rust core with a PyO3 strategy API** (Proposal B).
4. **A pure-Python engine** accelerated with Numba and Polars.
5. **A C++, JVM or Go core** with Python strategies over FFI or IPC.

## Decision outcome

**Chosen option: 1, "Python strategies on an adopted Rust core (NautilusTrader v2)".** It is the only option that gives a deterministic, fixed-point, Rust-speed kernel *and* lets a 1–3 person team work only in Python and TypeScript. The engine adoption itself is recorded in [ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.md).

Rules that follow from this decision:

| Area | Rule |
|---|---|
| Core | NautilusTrader v2's Rust kernel, adopted unmodified. We do not write or patch Rust in scenario 1. **At least one team member must be able to read Rust**, because v2 failures surface in Rust stack traces |
| Strategy and research language | **Python 3.14, standard (GIL) build.** The free-threaded build is not used for strategy or engine code |
| Images | One main image (Python 3.14, pandas 3) through Phase 2. A `legacy-quant` image (Python 3.13, pandas 2.3) appears only when Phase 3 options work needs vollib or alphalens. Python 3.15 is a 2027 upgrade, after every pinned wheel is verified |
| Layering | Signal and sizing logic lives in **`tp_signals`**: pure functions, engine-agnostic, written in **Python 3.11-compatible syntax** so that a LEAN runtime could host it. `GuardedStrategy` in `platform/runtime/nautilus/` is the thin Nautilus glue. `tp_*` packages never import `nautilus_trader`; an import linter enforces this |
| Hot paths | Vectorize with NumPy/Polars, or use Numba kernels in research. Rust strategies only when trigger T5 fires |
| Concurrency | One single-threaded kernel per node. Parallelism only *across* runs (sweeps, folds), never within one run |
| Other languages | TypeScript for the client ([ADR-0007](ADR-0007-web-first-client-and-charting-stack.md)). Python for the API gateway, journal, scheduler and kill switch. Vendor SDKs in other languages run out of process ([ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.md)) |

### Consequences

**Positive**

- One language from research notebook to live node, and the same strategy code in backtest, sandbox and live.
- Zero custom Rust or C++ to maintain. The team hires for Python and TypeScript.
- Fixed-point i128 prices, UTC-nanosecond time and a deterministic single-threaded kernel come with the engine.
- Because `tp_signals` is engine-agnostic, a forced move to LEAN (triggers T6/T10) becomes a bounded port, estimated at 2–4 PM, rather than a rewrite of strategies: the engine-bound adapter, simulation extensions and runtime glue are rewritten ([ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.md)). A move to an own core costs far more.

**Negative**

- Python callbacks per event cost more than native code. This is acceptable at our latency tier but rules out sub-10 ms strategies without T5.
- Debugging needs Rust literacy, which narrows the hiring profile slightly.
- Python version skew must be managed: the main image is 3.14, `tp_signals` syntax is frozen at 3.11 (no PEP 695 type-parameter syntax, for example), and some vendor SDKs lag. Fubon Neo supports Python 3.8–3.13, so it cannot share the main image and must run in its own sidecar.
- We depend on NautilusTrader's wheel matrix and its glibc 2.35+ floor.

### Confirmation

- An import linter in CI blocks `nautilus_trader` imports outside `platform/runtime/` and `adapters/`.
- A CI job runs the `tp_signals` unit tests on a Python 3.11 interpreter.
- Lint bans wall-clock reads, I/O and unseeded randomness in `tp_signals`, `tp_risk` and `strategies/`.
- The Phase 0 spike confirms Python 3.14 wheels for every pinned dependency.

### Revisit when

- **T5:** reactions under about 10 ms or L2/L3 queue modelling are needed. Add Rust strategies; this requires Rust staff.
- **T6:** NautilusTrader 2.0 GA slips past the Phase 2 exit, upstream rejects a change we need, or the project changes licence or moves features behind a paywall. Move to LEAN behind `StrategyRuntime`, or to an own Rust core if two or more senior Rust engineers are available.
- **The team turns out to be C#-first.** Swap NautilusTrader for LEAN behind the same port and accept Python 3.11 for strategies.

## Pros and cons of the options

| Option | Pros | Cons |
|---|---|---|
| 1. Python on adopted Rust core | Fastest to live; Rust speed without Rust staff; maintained IB and crypto adapters | RC churn; key-person risk; needs one Rust reader |
| 2. LEAN (C#) | Apache-2.0; most stable; strongest US equities and options models | Python pinned to 3.11 (EOL 2027-10); slower Python strategies; no Taiwan, no bonds; C# skills |
| 3. Own Rust core | Full control; no LGPL in the engine | First live trade around month 10 with about six engineers; fatal for 1–3 people |
| 4. Pure Python | Simplest | Slow per event; we would build the OMS, reconciliation and adapters ourselves |
| 5. C++/JVM/Go | Mature performance options | Two-language debugging; weak retail-quant ecosystem; no adoptable multi-asset engine |

## Links

- [Main report: recommended stack and scenario 1](../../README.md)
- [Recommended architecture §2, §3.3 and §6](../../architecture/recommended-architecture.md)
- [Evaluation record: scores and graft 19 (`StrategyRuntime`) and graft 34 (Rust reader)](../../architecture/evaluation.md)
- [Proposal A](../../architecture/proposal-A-lean-mvp.md) · [Proposal B](../../architecture/proposal-B-performance-core.md)
- Research: [01 Core language and runtime](../../research/01-core-language-runtime.md) · [10 Build vs buy](../../research/10-open-source-platforms-build-vs-buy.md)
- Related ADRs: [ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.md) · [ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md) · [ADR-0009](ADR-0009-open-source-licensing-strategy.md) · [ADR-0010](ADR-0010-real-money-gate-and-dependency-pinning.md)
