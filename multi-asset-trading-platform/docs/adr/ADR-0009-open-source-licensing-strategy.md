**English** | [繁體中文](ADR-0009-open-source-licensing-strategy.zh-TW.md)

# ADR-0009: Open-source licensing strategy: keep commercialization options open

## Status

**Proposed** · 2026-10-05 · Scope: all scenarios. This is engineering policy, not legal advice; the items marked *counsel* need legal review before any external offering or distribution.

## Context and problem statement

The platform starts as self-use, but it may later become a service for others (trigger T1) or a desktop or self-hosted product (trigger T10). Dependency and data licences constrain those options more than technology does ([03](../../research/03-market-data-storage.md), [10](../../research/10-open-source-platforms-build-vs-buy.md)). Which licences may we depend on, in which parts of the system, so that commercialization never forces a rewrite?

Facts on 2026-10-05:

| Licence class | Examples in or near our stack | Trigger for obligations |
|---|---|---|
| Permissive | MIT, BSD, Apache-2.0: CCXT, ib_async (BSD-2), the Rust `ibapi` crate (MIT), Polars, DuckDB, Valkey (BSD), NATS, PostgreSQL, QuantLib (BSD-style), MLflow, LEAN, Lightweight Charts (Apache-2.0, **attribution required**), uPlot, ECharts, AG Grid Community, KLineChart, Tauri | Notices and attribution |
| Weak copyleft (file-level) | MPL-2.0: OpenBao | Modified MPL files must be shared if distributed |
| LGPL | **NautilusTrader v2 (LGPL-3.0-only;** v1.x was LGPL-3.0-or-later) | **Distribution.** No network clause. Its wheels statically link Rust crates, so relinking obligations for distributed binaries are a legal question (*counsel*) |
| GPL | IBKR TWS API client 10.49+ (since 2026-08-03), Freqtrade, backtrader, Lumibot, FinancePy, Qt Graphs | Distribution of derivative works |
| AGPL | Grafana, Loki, Tempo; Redis 8 (one of its three licences); Backtesting.py; OpenBB 4.2–4.7.x | **Network use of a modified version** |
| Commons Clause | vectorbt (open source) | Forbids selling the software or services based on it |
| Source-available (BSL and similar) | HashiCorp Vault, immudb, Redpanda, lakeFS v1.87+, ArcticDB (any business use needs an agreement), KurrentDB, TimescaleDB TSL; Redis 8 RSAL/SSPL | Offering the product itself as a service, or commercial use, depending on the licence |
| Proprietary SDKs, EULAs and terms | Shioaji, Fubon Neo, Capital SKCOM, IB Gateway, StockSharp (proprietary since 2026-07-16), TradingView Advanced Charts (companies only), vectorbt PRO (personal, non-commercial), Nautilus Pro (announced) | Per vendor terms |
| Non-commercial or paid for any commercial use | Rateslib (£251 per user per year for any commercial use, even as a validator); TimesFM 3.0 and Moirai 2.0 model weights | Any commercial use |
| Data licences | Massive and ThetaData individual-use plans; FinMind data (educational/non-commercial); broker feeds (no redistribution); TWSE redistribution (NT$60,000/month plus NT$100,000/month internet fee); IBKR forbids redistributing TWS API data | Display to others, professional use, redistribution |

Licences also drift. OpenBB went MIT → AGPL-3.0 (2024-05) → Apache-2.0 (v5.0.0, 2026-09-29). StockSharp went Apache-2.0 → proprietary.

## Decision drivers

- Self-use today must not block a later service (T1) or a distributed product (T10).
- Keep the best tools where their licences are harmless (for example LGPL NautilusTrader on a server).
- Make violations impossible to merge, not just discouraged.
- Treat data licences as first-class, because they constrain the design the most.
- Keep the policy cheap enough for one person to run.

## Considered options

1. **A tiered policy by distribution context**: engines stay server-side; nothing distributable contains LGPL, GPL, AGPL or Commons Clause code; an SPDX licence scan runs in CI; every dataset carries a `license_tag`.
2. **Permissive-only everywhere**, which means dropping NautilusTrader now for LEAN or an own core.
3. **No policy until commercialization**, then review.
4. **Release our platform under a strong copyleft licence** (for example AGPL), so that inbound copyleft is moot.

## Decision outcome

**Chosen option: 1, "a tiered policy by distribution context".** It keeps NautilusTrader, where LGPL has no network clause and is harmless on our servers. It forbids copyleft only where it would bite (distributed artifacts) and enforces the rule mechanically.

### Policy matrix

| Licence class | Server-side, internal (scenarios 1 and 2) | Network service to others (T1) | Distributed artifact: desktop or mobile app, self-hosted bundle, customer edge connector |
|---|---|---|---|
| Permissive, MPL-2.0 | Allowed | Allowed | Allowed, with notices and attribution |
| LGPL (NautilusTrader) | Allowed; keep unmodified, contribute fixes upstream | Allowed (no network clause) | **Forbidden** without legal review (T10) |
| GPL | Only as separate, unlinked tools (for example FinancePy as an internal test oracle). Never link IBKR's GPL client | Same as internal | **Forbidden** |
| AGPL | Grafana, Loki and Tempo **unmodified**, for our own operations only. Redis 8, Backtesting.py and OpenBB 4.2–4.7.x are not used | Never expose a **modified** AGPL service to outside users | **Forbidden** |
| Commons Clause | vectorbt for internal research only | **Forbidden** | **Forbidden** |
| BSL and source-available | Prefer the permissive alternative: OpenBao over Vault, a PostgreSQL hash chain over immudb, NATS over Redpanda, Parquet with DuckLake or Iceberg over ArcticDB. Avoid lakeFS v1.87+ if a service is planned | Avoid | **Forbidden** |
| Proprietary SDKs and EULAs | Per vendor terms, for self-use | Only with vendor approval (IBKR third-party OAuth 1.0a after a compliance review; broker terms forbid third-party authorization) | Only with written vendor consent. The edge connector must not bundle broker SDKs without consent (*counsel*) |
| Non-commercial or paid-commercial | Rateslib excluded; TimesFM 3.0 and Moirai 2.0 weights excluded; vectorbt PRO personal use only | Excluded | Excluded |

### Rules

1. **Engines stay server-side.** Clients are thin ([ADR-0007](ADR-0007-web-first-client-and-charting-stack.md)).
2. **Nothing distributable contains LGPL, GPL, AGPL or Commons Clause code** (design principle 11 of the main report). If the engine itself must ship (T10), use LEAN (Apache-2.0) or Proposal B's own core, after a licence review.
3. **IBKR:** use NautilusTrader's MIT `ibapi` crate and ib_async (BSD-2). IB Gateway runs as vendor software.
4. **An SPDX licence scan runs on every merge** (Python, npm, container images; `cargo-deny` if Rust code ever appears). An allow-list and a deny-list live in the repo, and the licence of every pinned version is recorded, so drift shows up as a diff.
5. **Data:** a `license_tag` on every dataset and row group, resolved against `data/licence-registry.yaml` (terms, permitted uses, display or non-display, professional status, redistribution, and `llm_export_allowed` for sending the data to a third-party LLM API, [ADR-0017](ADR-0017-ai-trust-boundary.md)). Redistribution and LLM export are forbidden by default. Trading through a company entity can make us a professional subscriber, so re-check the plans. The entitlement service arrives at T1.
6. **Attribution:** the UI bundle ships a NOTICE file, and the TradingView attribution stays visible.
7. **Our own code:** its outbound licence is **not decided here**. The repository stays private in scenario 1, and the choice is made with counsel at T1 or T10.

### Consequences

**Positive**

- We keep NautilusTrader's speed-to-market without closing the door on a service or a product.
- Licence violations fail CI instead of surfacing in due diligence.
- Data-licence constraints are visible on every dataset, which an external offering will need anyway.
- Licence drift (OpenBB, StockSharp) is caught at upgrade time.

**Negative**

- A distributed product that must contain the engine (T10) still means changing engines. The `StrategyRuntime` port keeps that to weeks, but it is not free.
- The allow-list and registry need maintenance, and some licences are ambiguous (Lumibot's LICENSE file says GPL-3.0 while its README says MIT), which forces manual review.
- Useful tools are fenced off: vectorbt cannot back a paid service, and Rateslib is excluded entirely.
- Several questions stay open until counsel reviews them: LGPL static linking, broker-SDK redistribution and the edge connector's legal basis.

### Confirmation

- The SPDX scan and deny-list gate every merge (§8.1 of the recommended architecture, "Licence and supply chain").
- The go-live checklist requires a licence-registry entry permitting the use of every dataset a strategy reads.
- Before T1 or T10: a written licence review covering every row of the policy matrix, plus counsel sign-off ([ADR-0015](ADR-0015-self-use-regulatory-posture-and-legal-gate.md)).

### Revisit when

- **T1:** an external offering → entitlements, distribution data licences, an AGPL audit of everything exposed.
- **T10:** a desktop or self-hosted product must ship the engine → LGPL-free core.
- A dependency changes licence or opens a paid tier (for example Nautilus Pro features moving from open source) → T6 review.

## Links

- [Main report: design principle 11, cost exclusions and the data-licence risk](../../README.md)
- [Recommended architecture §4.1 (licensing), §8.1 and §9](../../architecture/recommended-architecture.md)
- [Evaluation record: grafts 22 and 26; concerns 4, 21, 23 and 26; Rateslib and lakeFS in §4.3](../../architecture/evaluation.md)
- Research: [10 Build vs buy](../../research/10-open-source-platforms-build-vs-buy.md) · [03 Market data storage](../../research/03-market-data-storage.md) · [04 Broker connectivity](../../research/04-broker-exchange-connectivity.md) · [06 Client UI](../../research/06-cross-platform-client-ui.md) · [07 Messaging](../../research/07-system-architecture-messaging.md) · [08 Security and compliance](../../research/08-risk-security-ops-compliance.md) · [09 Research and ML](../../research/09-research-ml-analytics.md)
- Related ADRs: [ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.md) · [ADR-0004](ADR-0004-parquet-lake-for-historical-data.md) · [ADR-0007](ADR-0007-web-first-client-and-charting-stack.md) · [ADR-0015](ADR-0015-self-use-regulatory-posture-and-legal-gate.md)
