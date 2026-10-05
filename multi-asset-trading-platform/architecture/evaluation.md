**English** | [繁體中文](evaluation.zh-TW.md)

# Evaluation Record: Three Proposals, Three Judges, One Fused Recommendation

*Status as of 2026-10-05 · This record explains how the [recommended architecture](recommended-architecture.md) and the [main report](../README.md) were derived from proposals [A](proposal-A-lean-mvp.md), [B](proposal-B-performance-core.md) and [C](proposal-C-platform-scale.md) and from research [01](../research/01-core-language-runtime.md)–[11](../research/11-taiwan-market-localization.md).*

## 1. Method

| Step | What was done |
|---|---|
| Inputs | 11 research reports (each with an adversarial verification log dated 2026-10-05) and 3 architecture proposals written for different team shapes: **A** Lean MVP (1–3 people), **B** Performance and correctness first (5–20 people with senior Rust engineers), **C** Platform and scale (6–12 people, multi-tenant) |
| Judging | Three independent judges each scored all three proposals from 0 to 10 through one lens, listed strengths, weaknesses and fatal flaws, proposed grafts, and raised factual concerns |
| Backbone rule | Choose the proposal with the highest average score **and** no fatal flaw for the situation the user most likely starts in: an undecided team size, probably 1–3 people, self-use |
| Graft rule | Accept an element from another proposal or a judge when it closes a gap that a judge identified at low cost, or when it creates a cheap seam that makes a later evolution path an extension instead of a rewrite. Defer anything that adds standing operational load before its trigger fires |
| Contradiction rule | When research reports disagree, prefer the verification logs, primary sources (registries, licence files, statutes) and the newer date. Items that remain unverified become Phase 0 checks |

## 2. Scores

| Proposal | Feasibility & delivery (1–3 people, live in 3–9 months) | Correctness & performance | Long-term evolution & multi-asset completeness | Average | Fatal flaw |
|---|---|---|---|---|---|
| **A** Lean MVP on open-source shoulders | **7.8** | 6.5 | 6.0 | **6.77** | None |
| **B** Own Rust core, one engine for backtest and live | 3.0 | **7.8** | 6.8 | 5.87 | Under the feasibility lens: first live trade around month 10 with about six engineers including senior Rust staff; by its own statement it is unsuitable for teams under four or for live trading within six months |
| **C** Multi-user, cloud-native platform | 2.5 | 6.0 | **7.6** | 5.37 | Under the feasibility lens: internal live trading at months 10–14 after about 120 person-months with 8–10 engineers; Kubernetes, OpenBao and multi-tenant operations are unaffordable for 1–3 people |

**Weight sensitivity.** These figures are our own calculation from the judges' scores.

| Weighting | A | B | C | Leader |
|---|---|---|---|---|
| Equal (as reported) | 6.77 | 5.87 | 5.37 | A |
| Scenario 1 emphasis: feasibility 50%, correctness 30%, evolution 20% | 7.05 | 5.20 | 4.57 | A |
| Scenario 2 emphasis: feasibility 20%, correctness 40%, evolution 40% | 6.56 | 6.44 | 5.94 | A (narrowly) |
| Correctness only | 6.5 | 7.8 | 6.0 | B |
| Evolution only | 6.0 | 6.8 | 7.6 | C |

The feasibility lens was scored explicitly for a 1–3 person team. For a funded team of six or more with Rust skills, B's and C's feasibility scores would be higher, which is why both remain **triggered evolution targets** rather than discarded designs.

## 3. Judge verdicts

### 3.1 Feasibility and delivery (A 7.8 · B 3.0 · C 2.5)

**A is the only proposal sized for the lens.** It reaches the first live market in about 10.5 person-months (about 6.5 months for two people) because NautilusTrader brings the OMS, reconciliation, risk engine and the IBKR and crypto adapters, so the team owns only the Taiwan adapter. It also has the lowest total cost of ownership (about $150–600/month live on one Compose host), needs only Python and TypeScript hires, and has a sound real-money gate.

**Weaknesses the judge found in A:**

- **Scope.** Phases M2–M4 pack three broker families, a bitemporal security master, a hash-chained journal, MLflow promotion gating, tier-agreement checks and three UI shells into about 6.5 PM, so slip toward 8–9 months is likely.
- **Unregistered dependency risk.** NautilusTrader has a bus factor of about 1, an announced Nautilus Pro tier suggests open-core, and the IB path rests on a single-maintainer `ibapi` crate.
- **Operations.** For a lone operator, 24/7 crypto, IBKR 2FA, Shioaji's 14-day releases and RC upgrades add up.
- **Two Python images** to keep patched.

**B and C fail the lens** on their own arithmetic.

**Recommendation:** use A as the baseline, de-scoped (one venue family first, web plus Telegram first, a simpler security master) and hardened with B's execution semantics, determinism rules and kill criterion, and with C's deployable rule, licence registry and thin SDK.

*Follow-up (2026-10-05):* the [main report](../README.md) roadmap was later re-planned bottom-up with this slip in mind. It now estimates about 12 PM base (14–16 PM with a 20–30% contingency) to the first live market, with first live at about month 8–9 for two people, and its cost table supersedes the "$150–600/month" figure above.

### 3.2 Correctness and performance (B 7.8 · A 6.5 · C 6.0)

**B has the best design:**

- a CI-enforced determinism contract and checked fixed-point arithmetic;
- a journal written before each send, and a byte-identical OMS and risk gate in every mode;
- Taiwan auction and limit-lock matching;
- a real bond model.

Its risks are the matcher it builds itself (oracles cannot validate the new Taiwan and bond logic) and an over-promised cross-OS bit-identical guarantee for Python strategies.

**A is the most credible near-term route to trustworthy backtests:** Nautilus's deterministic i128 kernel, the same code in every mode, strong gates, and honesty about its gaps. Its weaknesses:

- no write-ahead record before send (it relies on asynchronous Valkey persistence plus reconciliation);
- no corporate-action events and no early-assignment model;
- unverified Taiwan matching rules in the simulator;
- vectorbt-vs-Nautilus tier agreement made noisy by different indicator implementations.

**C has strong recovery mechanics**, but its extra network hops and second order state machine weaken backtest-live parity. Its paper adapter duplicates the simulation models, and it claims bond and assignment modelling on an engine that lacks both.

**Gaps shared by all three:** a corporate-action event pipeline, a dividend-driven early-assignment model, and rounding and minimum-fee rules.

### 3.3 Long-term evolution and multi-asset completeness (C 7.6 · B 6.8 · A 6.0)

**C is the only proposal that designs the path from self-use to a multi-user product end to end:**

- tenancy, entitlements and OIDC/WebAuthn;
- an order gateway as single writer;
- a customer-hosted edge connector for personal Taiwan certificates;
- the broadest Taiwan coverage, including MAX and BitoPro for TWD crypto;
- the most thorough licence and regulatory model.

However, it understates adapter cost (it says it uses Nautilus adapters but routes orders through its own venue gateways), and its `Bond` type has no specified path into the backtester.

**B has the most complete instrument model** and the cleanest licensing for a distributed product (no LGPL ships), but it re-implements every adapter and has no tenancy.

**A is the most executable for Taiwan today,** but its seams are thin. Strategies are coupled to the Nautilus API, and there is no tenant or order-gateway contract. Its claim that a later service would be "a licensing project rather than a rewrite" contradicts its own trigger table.

**Recommendation:** build A's scope first and adopt C's cheap seams from day one, plus B's capability flags, `Bond` domain type and LGPL-free-distributable rule.

## 4. Fusion decisions

### 4.1 Backbone

**Proposal A** is the backbone. It has the highest average, it is the only proposal with no fatal flaw for the probable starting situation, and its weaknesses are fixable by grafts and de-scoping, while B's and C's weaknesses are structural for a small team. B and C become **evolution paths with explicit triggers** (T1–T11 in the [main report](../README.md)).

### 4.2 Grafts and adjustments

"Raised by" refers to the judge lenses: **J1** feasibility, **J2** correctness, **J3** evolution.

| # | Element | From | Raised by | Decision | Rationale | Where it lives |
|---|---|---|---|---|---|---|
| 1 | Extend NautilusTrader v2 with an exact pin and `runtime/` config factories | A | J1, J2 | **Adopt** | The fastest route to backtest-live parity; factories absorb RC renames | [§3.3](recommended-architecture.md) |
| 2 | Real-money gate (GA, or a 30-day soak with zero unexplained breaks, a signed ADR and a 10% cap) | A | J1, J2, J3 | **Adopt** | Upstream advises against RCs with real capital | §8.3 |
| 3 | Shioaji sidecar, `.pfx` mounted only there, empty responses treated as alarms, client-side throttling | A | J1 | **Adopt**, built to C's edge-connector contract | Crash and secret isolation now; portability to a customer host later | §2, §3.4 |
| 4 | Single Linux host on Compose, static egress IP, Tailscale, Grafana Cloud free tier, SOPS+age | A | J1 | **Adopt** | Keeps run cost at about $150–600/month | §2, §7 |
| 5 | Budget data stack (IBKR bundle, ThetaData, CCXT capture, FRED, TW OpenAPIs) | A | J1 | **Adopt**, with FinMind's terms flagged and TEJ advised for TW point-in-time data | Cheap and adequate for bars and L1 | README cost |
| 6 | Bonds analytics-first; no backtests on indicative OTC quotes | A | J1, J2 | **Adopt** | Avoids a bond OMS/RFQ in the MVP and avoids fake Sharpe | §4.8 |
| 7 | First-class `Bond` domain type (% of par, 32nds codec, face-value quantity, coupons as ledger events) | B | J2, J3 | **Adopt** in `tp_domain`, outside the engine | Nautilus has no tradable bond type; the ledger and valuation still need one | §4.8 |
| 8 | Write-ahead order intent before send | B, C | J2 | **Adopt** as a node-local fsync WAL tailed by the journal writer | Closes Nautilus's asynchronous-persistence window and Valkey's `everysec` loss window | §3.4, §5.7 |
| 9 | ULID client IDs encoded per venue; fill dedup on `(venue, exec_id)`; `UNKNOWN` resolved by query, never blind resubmission | B, C | J1, J2, J3 | **Adopt** | Cheap, and most live bugs live in connectivity | §3.4, §4.4 |
| 10 | Adapter capability flags | B | J1, J3 | **Adopt** (`adapters/capabilities.yaml`) | Strategy and risk branch on capabilities, never on venue names | §3.4 |
| 11 | Determinism contract and run manifests | B | J1, J2 | **Adopt, scoped:** exact same-platform golden hashes; documented tolerances across platforms | Python, NumPy SIMD and Polars reductions are not bit-reproducible across architectures | §5.5 |
| 12 | One indicator library for both backtest tiers | B | J2 | **Adopt** (`tp_signals` batch and incremental) | Makes the 10%/sign-flip agreement rule catch look-ahead bugs | §3.3, §3.8 |
| 13 | Taiwan `SimVenue` semantics (call auctions, locked-limit refusal, odd-lot book, end-of-day day-trade status) | B | J2 | **Adapt:** Phase 0 spike as Nautilus fill/matching extensions; trigger T7 builds a TW-only simulator if they cannot be expressed | Keeps the engine while protecting TW backtest validity | §5.6 |
| 14 | Kill criterion: stop if a phase exit slips by more than 3 months | B | J1 | **Adopt** for build items (Taiwan adapter, TW simulation extensions, WAL) | Bounds sunk cost | README roadmap |
| 15 | Record/replay, chaos tests, Monte Carlo drift alarm | B | J2 | **Adopt** | Parity infrastructure at low cost | §8.1, §3.5 |
| 16 | NautilusTrader and LEAN as unlinked differential oracles | B | J2 | **Defer** to scenario 2 (optional LEAN oracle for US equities) | Maintaining scenario translations for three engines is unbudgeted for 1–3 people | §8.1 |
| 17 | Per-hop HDR latency histograms, PTP clocks | B | J2 | **Defer** to scenario 2 or trigger T5; measure WAL fsync and order-ack latency now | The latency tier is tens to hundreds of ms | §3.12 |
| 18 | Rust/WASM model crate in the UI | B | J2 | **Adapt:** decimal strings or scaled integers on the wire now; WASM later | Same precision guarantee without a Rust UI toolchain | §3.10 |
| 19 | `StrategyRuntime` port and thin strategy SDK | C | J1, J3 | **Adopt (reduced):** `tp_signals` engine-agnostic and 3.11-compatible; `GuardedStrategy` as glue | Turns a forced engine move (bus factor, open-core) into a port | §2, §3.3 |
| 20 | Order gateway as single writer per account (lease plus fencing) | C | J2, J3 | **Adopt the contract in-process now**; move out of process on T1/T2 | Tenancy and an out-of-process risk gate depend on it | §2, §9 |
| 21 | `tenant_id` and `account_id` in every schema | C | J3 | **Adopt** | Avoids a later migration | §4.1 |
| 22 | `license_tag`, a licence registry and an entitlement stub | C | J1, J3 | **Adopt** the tag and registry; **defer** the entitlement service to T1 | Licences constrain the design more than technology does | §4.1 |
| 23 | TWD crypto venues (MAX, BitoPro) on a configured allow-list tied to the FSC register | C | J3 | **Adopt** as configuration; adapters only when used | VASP Act transition 2027–2028 | `config/venues.yaml` |
| 24 | "New deployable only with its own scaling, failure or security boundary" | C | J1 | **Adopt** | Prevents Compose sprawl | §2 |
| 25 | "Self-directed software" regulatory-posture ADR with a legal gate | C | J3 | **Adopt** | Required before any external user | README, ADR list |
| 26 | Nothing distributable contains LGPL, GPL, AGPL or Commons Clause code | B | J3 | **Adopt** (SPDX scan now; `cargo-deny` if Rust code appears) | Keeps desktop or self-hosted options open | §8.1 |
| 27 | One gateway process per venue account | B | J3 | **Defer** to T2 (Taiwan is already process-isolated by the sidecar) | Not needed at L1 with upstream adapters | §3.4 |
| 28 | Iceberg/DuckLake snapshot IDs; TEJ for point-in-time data | C | J2 | **Adapt:** content-hashed dataset manifests now; DuckLake/Iceberg at T4; TEJ advised for TW cross-sectional work | Equivalent reproducibility for a single writer at zero ops | §3.1 |
| 29 | Corporate-action event pipeline (splits, dividends, TW 除權息 including stock dividends that create odd lots, OCC adjusted deliverables) | None (gap in all three) | J2 | **Add**, as a promotion prerequisite | Factors on read do not adjust held positions or book cash | §4.2, §5.6 |
| 30 | Dividend-driven early-assignment model for short American options | None | J2 | **Add** in Phase 3 | Neither Nautilus nor LEAN models it realistically | §5.6 |
| 31 | Rounding and minimum-fee rules in the rules pack | None | J2 | **Add** | Taxes, commissions and accrued interest round by convention | §4.2 |
| 32 | Round QuantLib (double) accrued interest to settlement convention before booking | None | J2 | **Add** | Reconciles research 01's Decimal guidance with QuantLib's float API | §3.6, §4.8 |
| 33 | Dependency-risk register (Nautilus key-person and open-core risk; `ibapi`; Shioaji cadence) | None | J1, J3 | **Add** | Missing from all three risk sections | README risks |
| 34 | At least one team member able to read Rust | None | J1 | **Add** | v2 failures surface in Rust | README scenario 1 |
| 35 | First live on one venue family; Taiwan second | J1 | J1 | **Adopt**, with a documented Taiwan-first variant (+2 PM) | Reduces slip risk | README roadmap |
| 36 | Web workstation plus Telegram/ntfy first; Tauri and PWA push later | J1 | J1 | **Adopt** | Saves UI effort in the critical path | §3.11 |
| 37 | Security master: effective-dated rows recording `known_at`, with full bitemporal queries later | J1 vs J2/J3 | J1, J2, J3 | **Compromise** | Cheap now, with no data loss for later as-of-knowledge queries | §4.2 |
| 38 | One Python image until Phase 3; call FinMind's REST API directly | J1 | J1 | **Adopt** | Removes the second image from the critical path | README scenario 1 |
| 39 | Valkey `appendfsync always` on the trading host | J2 concern | J2 | **Adopt** | Removes the 1-second loss window on a single host at an acceptable latency cost | §2 |
| 40 | Tick ladder per instrument class (`tick_scheme_id`), not one TW ladder | B, C | J2 | **Adopt** | TW ETFs use 0.01 below NT$50 and 0.05 above | §4.2 |

### 4.3 Considered and rejected or deferred

| Element | From | Decision | Reason |
|---|---|---|---|
| Own Rust kernel, `SimVenue` for all markets, native adapters for every venue | B | **Rejected for scenario 1;** kept as T6/T7/T10 paths | Fatal under the feasibility lens; rebuilds what Nautilus provides (B itself estimates 30–40 PM saved by adopting Nautilus) |
| Cross-architecture bit-identical golden hashes | B | **Rejected as stated;** replaced by a scoped contract | Not achievable for Python/NumPy/Polars decision paths |
| Day-one multi-region hybrid (Tokyo, Taipei, US-East) with Kubernetes | B | **Deferred** (T2/T5) | Operational load without a latency need |
| Day-one Kubernetes, OpenBao, OIDC, 13 deployables, Iceberg + ClickHouse, Ray, JupyterHub sandboxes | C | **Deferred** to T1/T2/T4 | About $6k–16k/month before any external user |
| `PlatformExecutionClient` routing all orders through an external order gateway and C's own venue gateways | C | **Rejected for scenario 1.** In scenario 2, an out-of-process gateway may sit in front of upstream adapters only after a spike proves Nautilus reconciliation still works end to end | Bypasses Nautilus adapters and reconciliation, and creates two order state machines |
| `nautilus-ext` Rust crate built against Nautilus internals | C | **Rejected** | Rebuilding against Nautilus crates on every RC bump is unbudgeted LGPL maintenance; use the documented Python out-of-tree adapter path |
| "Platform paper" adapter with its own simulation models | C | **Rejected** | A second fill model drifts from the engine; paper uses the Nautilus sandbox and venue paper accounts only |
| Three UI shells in the MVP (web, Tauri, PWA push) | A | **Deferred** to Phase 3 | Feasibility |
| Tardis.dev in scenario 1 | B, C | **Optional** | From $700/month (Solo); CCXT capture first |
| Rateslib | All | **Excluded** | Any commercial use, including as a validator, needs a £251/user/yr licence |
| lakeFS v1.87+ | — | **Avoid** if a service is ever planned | BSL: unmodified internal use only |

## 5. Judges' factual concerns and how they were handled

| # | Concern | Raised by | Assessment | Handling |
|---|---|---|---|---|
| 1 | NautilusTrader concentration: about 19,182 commits by the lead maintainer against 339 for the next contributor (GitHub contributors API, 2026-10-05); "Nautilus Pro" (risk engine, execution algorithms, dashboard; waitlist, no prices) suggests open-core | J1 | Accepted. Research 10 independently confirms the Pro waitlist | Dependency-risk register; thin SDK and `StrategyRuntime` port; LEAN fallback rehearsed once; at least one Rust reader; trigger T6 |
| 2 | The Rust `ibapi` crate is effectively single-maintainer; verify which crate Nautilus v2 uses | J1 | Verified by J3: Nautilus's `develop` `Cargo.toml` pins `ibapi = "=3.3.0"` (MIT) and declares `LGPL-3.0-only`; crates.io shows ibapi 5.0.0 published 2026-10-04, two majors ahead | Risk register; ib_async (BSD-2) used independently by the kill switch; the MIT crate can be vendored or forked |
| 3 | "IBC handles 2FA" overstates automation; periodic full re-authentication needs a human to approve the 2FA push | J1 | Accepted | Recorded as an operator duty with a scheduler reminder and runbook |
| 4 | FinMind data is educational and non-commercial (research 09) | J1, J3 | Accepted | Flagged in the stack, risks and cost; confirm the sponsor terms cover personal live trading; TEJ or TWSE Data E-Shop as licensed alternatives; `license_tag` registry |
| 5 | Binance `countdownCancelAll` is a USDⓈ-M futures endpoint and does not cover spot | J1, J2 | Accepted (research 08) | Per-venue kill-switch table: spot has no venue dead-man in our research, so working balances are minimized; other venues' features are confirmed in Phase 0 |
| 6 | Nautilus documents Redis (and PostgreSQL) backing, not Valkey | J1 | Accepted | Phase 0 spike; fallback is the PostgreSQL cache backing plus NATS JetStream through a small bridge actor |
| 7 | An IBKR client normally cancels only its own orders unless it uses the master client ID or `reqGlobalCancel`; the kill switch shares IB Gateway | J1, J2 | Accepted | `reqGlobalCancel` (or the master client ID) specified and verified in Phase 0; the broker mobile app or web as a manual last resort; a second username for an independent session to be investigated |
| 8 | C's `nautilus-ext` Rust crate may require rebuilding against Nautilus crates on every RC | J1 | Accepted | Rejected the design (§4.3) |
| 9 | B's bit-identical guarantee cannot hold for Python, NumPy SIMD or multithreaded Polars | J1, J2 | Accepted | Scoped determinism contract (§5.5 of the architecture) |
| 10 | Version and price snapshots are internally consistent but point-in-time | J1 | Noted | Every document carries a snapshot date and a "re-verify before purchase" note |
| 11 | Databento US Equities Standard ($199) includes about 12 months of L1 and 1 month of L2/L3, too little for B's queue-model calibration | J2 | Accepted | Not relevant to scenario 1 (bars + L1). Scenario 2 budgets note that deeper depth history is billed on top |
| 12 | Valkey `appendfsync everysec` can lose about 1 s of acknowledged writes; asynchronous replication loses writes on failover | J2 | Accepted | Intent WAL with fsync before send; `appendfsync always` on the trading host; reconciliation as a release blocker |
| 13 | Bond plug-ins and assignment events were placed in the Nautilus tier, which supports neither | J2 | Accepted | Bonds are excluded from event-driven backtests; early assignment is our simulation module, spiked before Phase 3 |
| 14 | QuantLib double-precision accrued interest conflicts with research 01's Decimal guidance | J2 | Accepted | Explicit rounding to settlement convention before booking into the fixed-point ledger |
| 15 | "Corporate-action factors at read time" do not adjust positions or book dividend cash | J2 | Accepted | Corporate-action event pipeline (§5.6), a promotion prerequisite |
| 16 | A lists one TW tick ladder, but ETFs use 0.01 below NT$50 and 0.05 above | J2 | Accepted (research 11) | `tick_scheme_id` per instrument class |
| 17 | C's decision-to-wire p99 ≤ 25 ms is unbenchmarked | J2 | Noted | Not adopted as a target; scenario 2 measures per hop before committing to SLOs |
| 18 | C contradicts itself on crypto connectivity (Nautilus adapters vs its own venue gateways) | J3 | Accepted | Scenario 1 uses upstream Nautilus adapters; any later out-of-process gateway requires a reconciliation spike (§4.3) |
| 19 | C's `Bond` type has no specified path into the Nautilus `BacktestEngine` | J3 | Accepted | `Bond` is a domain type outside the engine; no event-driven bond backtests |
| 20 | C says Tauri notifications are local only, so push needs React Native, overlooking PWA Web Push (iOS 16.4+) | J3 | Accepted | PWA web push is the Phase 3 option; React Native only in scenario 2 |
| 21 | C misstates AGPL for Grafana ("tenants never given a modified copy") | J3 | Accepted | Correct rule: never expose a **modified** Grafana, Loki or Tempo to outside users over a network (or do not modify them) |
| 22 | C says IBKR's Taiwan listings exclude Taiwan residents | J3 | Partially accepted: confirmed only for TPEx (IBKR release of 2025-11-18); TWSE access is unverifiable (research 04) | Wording narrowed to TPEx; planning assumes no IBKR access to TW markets for a Taiwan resident; local brokers are used |
| 23 | The edge connector as the answer to Taiwan broker terms is a legal hypothesis; redistributing broker SDKs may need consent | J3 | Accepted | Legal gate (T1); counsel and broker confirmation before any external user; the contract is built now, the legal claim is not made |
| 24 | B lists ThetaData (individual use) and FinMind (non-commercial) for a 5–20 person team | J3 | Accepted | Scenario 2 data budgets use business or distribution licences |
| 25 | A's claim that a service would be "a licensing project rather than a rewrite" contradicts its own §7 trigger | J3 | Accepted | The seams (tenant IDs, order-gateway contract, `StrategyRuntime`, licence registry) make the claim closer to true, but the roadmap still budgets Phases 4–5 as a platform increment |
| 26 | Research 02, 03, 07 and 10 say "LGPL-3.0-or-later" for Nautilus, while research 01 (corrected) says v2 is "LGPL-3.0-only" | J3 | Accepted | Resolved to `LGPL-3.0-only` for v2 (§6) |
| 27 | C equates its ~120 PM with research 10's "9–18 month Build" estimate, but that estimate is elapsed time to an MVP | J3 | Noted | Our estimates are stated separately as PM and elapsed time |

## 6. Contradictions between research reports and their resolution

| Topic | Conflict | Resolution | Basis |
|---|---|---|---|
| NautilusTrader v2 licence | Research 02, 03, 07 and 10 say "LGPL-3.0-or-later"; research 01 (corrected) says "LGPL-3.0-only" | **LGPL-3.0-only for v2**; "or-later" applies to v1.x | Research 01 verification log (`pyproject.toml`, `Cargo.toml`, rc5 metadata); J3's check of the `develop` `Cargo.toml` |
| Bond support in NautilusTrader | Research 01 says Nautilus "has a `Bond` instrument class but no fixed-income analytics"; research 02, 05, 07 and 10 say there is no bond instrument type | **No tradable bond type.** `Bond` exists as an instrument-class enum value, but none of the 18 concrete `InstrumentAny` types is a bond | Research 05 (verified count of 18 types) and research 10 (verified instrument list); research 01 cites `enums.rs` |
| v1 vs v2 for real money | Research 07 recommends pinning 1.231.x for real money and using v2 RCs only in paper; research 10 recommends starting on v2 with a real-money gate | **Start on v2 with the real-money gate;** 1.231.x is only a stopgap | Research 01, 02 and 10 verification logs: v1 receives only critical security backports for about three months after the cutover (closing around November 2026, before a realistic go-live) |
| Latest NautilusTrader RC | rc6 is dated 2026-10-04 in the release notes, but rc5 is the newest on PyPI | **Pin rc5**; move when rc6 or GA is published | Research 01, 02 and 04 verification logs |
| NautilusTrader integrations and instrument count | "20+/21+ integrations" and "21 instrument types" appear in drafts | **17 integrations** (v2 drops BitMEX, which closed on 2026-09-23); **18 concrete instrument types** (19 with `SyntheticInstrument`) | Research 02, 04 and 05 verification logs |
| Taiwan tick sizes | Proposal A uses one ladder for every TW equity | **Per instrument class:** stocks 0.01–5 at breaks of 10/50/100/500/1,000; ETFs 0.01 below NT$50 and 0.05 above | Research 11 |
| Day-trade tax expiry | TWSE's English page still says 2024-12-31 | **2027-12-31** (Securities Transaction Tax Act Art. 2-2) | Research 02 and 11, law database |
| Taiwan bond transaction tax | "Bonds are exempt" | Government bonds exempt; **corporate bonds, financial debentures and bond ETFs only until 2026-12-31**, then 0.1% unless extended | Research 02 and 11 (Art. 1 and 2-1) |
| Fubon Neo test environment | "No separate simulation environment" | A test environment exists, but only with securities test accounts; test futures with tiny real orders | Research 11 verification log |
| Fugle history depth | "Minute bars from 2017-06" | Stock minute bars only from **2023-05-23**; 2017-06 applies to futures | Research 11 |
| TAIFEX night-session trading date | Several reports state that night fills belong to the next trading date | **Treat as plausible but unverified;** confirm against TAIFEX rules before implementing `CalendarPort` | Research 01 lists it as unverifiable |
| VASP Act timing | "Effective in 2027" | Passed 2026-06-30; **effective Q1 2027 at the earliest**; first licences around **Q1 2028** | Research 08 and 11 |
| IBKR third-party OAuth | "OAuth 2.0 (beta) for third parties" | Third-party vendors can currently get only **OAuth 1.0a**, after a compliance review | Research 04 |
| Coinbase derivatives | "Options, futures and perpetuals" | Since 2026-10-01 the Deribit-powered gateway trades **perpetuals only**; trade crypto options on Deribit directly | Research 04 |
| Databento pricing | "US Equities plan $4,000/month" | $4,000 is the US Equities **Unlimited** tier; Plus $1,750 and Unlimited $4,500 are CME rates; US Equities Standard is $199 | Research 03 |
| Rateslib as a test oracle | "Fine as a validator" | Any commercial use, including as a validator for corporate code, needs a paid licence; excluded | Research 05 |
| Python version | "3.13 or 3.14" | **3.14** (3.13 is security-only; 3.15 ships 2026-10-09, adopt in 2027) | Research 01 |

## 7. Open verifications carried into Phase 0

These items are unverified or depend on behaviour that only a spike can show. Each produces an ADR or an update to one.

1. Maturity of the NautilusTrader v2 out-of-tree adapter API (for the Shioaji adapter).
2. Whether TW call auctions, locked-limit refusal, the volatility interruption and the odd-lot book can be expressed as Nautilus fill/matching extensions (otherwise trigger T7).
3. A v2 mechanism for corporate-action cash and position adjustments inside `BacktestNode`.
4. Valkey as the Nautilus Redis backend, and the external-stream egress format.
5. IBKR kill-switch cancel semantics (`reqGlobalCancel` vs master client ID); the periodic 2FA re-authentication cadence; whether a second username gives an independent session.
6. Dead-man and cancel-on-disconnect support per venue and product actually traded.
7. Shioaji: odd-lot behaviour with tiny real orders (the simulator rejects odd lots), session limits, and the cancel path from a second session.
8. The TAIFEX night-session trading-date rule.
9. FinMind sponsor-tier terms for personal live trading.
10. Whether the chosen Taiwan broker accepts API logins from cloud IPs.
11. Rounding and minimum-fee rules for TW tax and commission, checked against real broker statements.
12. Python 3.14 wheels for every pinned dependency (QuantLib, vollib or fast-vollib, Shioaji, CCXT), and the DuckDB 2.0 upgrade.
13. Loading the 2027 TWSE/TAIFEX holiday schedule (QuantLib's Taiwan calendar stops at 2026).
14. IBKR TWSE access for Taiwan residents (assume none).
15. The NautilusTrader 2.0 GA date and the rc6 changes (mandatory fee model, BitMEX removal).
