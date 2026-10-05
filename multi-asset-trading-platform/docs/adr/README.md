**English** | [繁體中文](README.zh-TW.md)

# Architecture Decision Records

*Index · Status as of 2026-10-05 · Companion to the [main report](../../README.md), the [recommended architecture](../../architecture/recommended-architecture.md) and the [evaluation record](../../architecture/evaluation.md).*

These records capture the key decisions behind the recommended architecture: what was decided, which alternatives were weighed, and what each choice costs. They use the [MADR](https://adr.github.io/madr/) structure:

- Status
- Context and problem statement
- Decision drivers
- Considered options
- Decision outcome, with consequences (positive and negative), confirmation and revisit triggers
- Links

Every record is **Proposed** until the project owner accepts it. Phase 0 spikes will update several of them. Versions and prices are snapshots from 2026-10-05; re-verify them before committing. Nothing here is legal, tax or investment advice.

## Index

| # | Title | Status | One-line summary |
|---|---|---|---|
| 0001 | [Core engine language and strategy language](ADR-0001-core-engine-and-strategy-language.md) | Proposed | Python 3.14 strategies on NautilusTrader v2's adopted Rust core; we write no Rust, but one person must read it; `tp_signals` stays engine-agnostic and 3.11-compatible |
| 0002 | [Backtest engine: extend NautilusTrader v2 rather than build or fork](ADR-0002-extend-nautilustrader-as-backtest-engine.md) | Proposed | Run NautilusTrader unmodified behind a `StrategyRuntime` port; add our own fee, funding, corporate-action, Taiwan-rules and early-assignment modules; LEAN is the fallback |
| 0003 | [Numeric representation and timestamp precision](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md) | Proposed | Exact fixed-point values per layer (i128 engine, int64 1e-9 lake, `NUMERIC` ledger, decimal strings on the wire), float64 only in models, UTC int64 ns for every event time |
| 0004 | [Historical data storage and format](ADR-0004-parquet-lake-for-historical-data.md) | Proposed | A bronze/silver/gold Parquet lake with a DBN-compatible schema and content-hashed manifests, queried with DuckDB (2.0 after 2026-10-21) and Polars; hot databases only at T4 |
| 0005 | [Real-time messaging and deployment form](ADR-0005-messaging-and-deployment-topology.md) | Proposed | In-process bus inside one node per account, Valkey streams for egress and control (NATS fallback), about ten containers on one Docker Compose Linux host with a static IP |
| 0006 | [Broker and exchange connectivity](ADR-0006-broker-connectivity-and-gateway-contract.md) | Proposed | Ports and capability flags; upstream adapters for IBKR and crypto; a platform-defined Taiwan gateway contract served by the Shioaji sidecar and, on T3, by Windows gateway VMs for Windows-only broker APIs |
| 0007 | [Cross-platform front end and charting](ADR-0007-web-first-client-and-charting-stack.md) | Proposed | A React + TypeScript web workstation plus Telegram/ntfy first; Tauri 2 and PWA push later; Lightweight Charts, uPlot, ECharts, AG Grid Community and KLineChart; no TradingView Advanced Charts |
| 0008 | [Key and secret management](ADR-0008-key-and-secret-management.md) | Proposed | SOPS + age mounted per container; trade-only, withdrawal-disabled, IP-bound keys rotated every 90 days; the `.pfx` only in the Shioaji sidecar and the kill switch; OpenBao in scenario 2 |
| 0009 | [Open-source licensing strategy](ADR-0009-open-source-licensing-strategy.md) | Proposed | A policy by distribution context: engines server-side, no LGPL, GPL, AGPL or Commons Clause code in anything distributed, SPDX scan in CI, `license_tag` on all data |
| 0010 | [Real-money gate and dependency pinning](ADR-0010-real-money-gate-and-dependency-pinning.md) | Proposed | Live capital needs NautilusTrader GA, or a pinned RC plus a 30-day clean soak, a signed risk acceptance and a 10% cap; exact pins, a monthly upgrade window, a dependency-risk register |
| 0011 | [Intent WAL, hash-chained ledger and reconciliation](ADR-0011-intent-wal-and-hash-chained-ledger.md) | Proposed | fsync each order intent before send; append-only SHA-256-chained PostgreSQL ledger with a WORM export; startup, intraday and end-of-day reconciliation as a release blocker |
| 0012 | [Security master, rules packs and calendars](ADR-0012-security-master-rules-packs-and-calendars.md) | Proposed | Own instrument IDs with effective-dated rows recording `known_at`; market rules as effective-dated YAML packs (including rounding and minimum fees); one `CalendarPort` |
| 0013 | [Risk gate and three-path kill switch](ADR-0013-risk-gate-and-three-path-kill-switch.md) | Proposed | Fail-closed checks identical in every mode, plus NautilusTrader's `RiskEngine` and venue controls; kill switch via node, an independent service (one per site) and venue dead-man timers |
| 0014 | [Two-tier backtesting and promotion gates](ADR-0014-two-tier-backtesting-and-promotion-gates.md) | Proposed | A vectorized tier and an event-driven tier sharing `tp_signals`; a CI-enforced determinism contract; an MLflow trial registry; gates G0–G4 with DSR ≥ 0.95 and PBO ≤ 0.2 |
| 0015 | [Self-use regulatory posture and legal gate](ADR-0015-self-use-regulatory-posture-and-legal-gate.md) | Proposed | Self-directed software for the owner's own accounts only; no signals, copy trading or data redistribution; a legal review and sign-off ADR before any external user (T1) |
| 0016 | [Multi-currency books, tax lots, withholding and jurisdiction tax plug-ins](ADR-0016-multi-currency-books-tax-lots-and-tax-plugins.md) | Proposed | Cash per currency with explicit FX conversions; `TaxLot` with a broker-matched lot method; withholding events; a Taiwan-resident plug-in for annual TWD summaries; not tax advice |
| 0017 | [AI trust boundary](ADR-0017-ai-trust-boundary.md) | Proposed | AI output becomes proposals only, through `tp_risk` and human approval; AI-scoped tokens with no order, control or limit rights; no secrets; network isolation; audit log; `llm_export_allowed` licence check |

## Mapping to the candidate list in the recommended architecture

§10 of the [recommended architecture](../../architecture/recommended-architecture.md) lists 19 candidate decisions. They are covered as follows:

| Candidate (§10) | Covered by |
|---|---|
| 1. Extend NautilusTrader v2 behind `StrategyRuntime`, LEAN fallback | [ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.md) |
| 2. Real-money gate for release-candidate engines | [ADR-0010](ADR-0010-real-money-gate-and-dependency-pinning.md) |
| 3. Python 3.14 main image; legacy-quant image on demand | [ADR-0001](ADR-0001-core-engine-and-strategy-language.md) |
| 4. Parquet lake, DBN-compatible schema, DuckDB/Polars, manifests | [ADR-0004](ADR-0004-parquet-lake-for-historical-data.md) |
| 5. Effective-dated security master with `known_at`; own IDs | [ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.md) |
| 6. Rules packs as effective-dated data, incl. rounding and minimum fees | [ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.md) |
| 7. Intent WAL, hash-chained ledger, reconciliation as release blocker | [ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.md) |
| 8. Valkey streams for node egress (NATS fallback) | [ADR-0005](ADR-0005-messaging-and-deployment-topology.md) |
| 9. Shioaji sidecar on the edge-connector contract; no Windows gateway in the MVP | [ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.md) |
| 10. Three-path kill switch and per-venue dead-man semantics | [ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.md) |
| 11. Corporate-action and early-assignment simulation; TW matching extensions (or T7) | [ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.md), [ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.md) |
| 12. Two-tier backtesting with a shared indicator library; G0–G4 gates | [ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.md) |
| 13. Web-first UI; Tauri and PWA push later; decimal strings on the wire | [ADR-0007](ADR-0007-web-first-client-and-charting-stack.md), [ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md) |
| 14. Licence policy | [ADR-0009](ADR-0009-open-source-licensing-strategy.md) |
| 15. Single-host Compose deployment and the deployable rule | [ADR-0005](ADR-0005-messaging-and-deployment-topology.md) |
| 16. Dependency-risk register | [ADR-0010](ADR-0010-real-money-gate-and-dependency-pinning.md) |
| 17. "Self-directed software" regulatory posture and legal gate | [ADR-0015](ADR-0015-self-use-regulatory-posture-and-legal-gate.md) |
| 18. Multi-currency books, tax lots and jurisdiction tax plug-ins | [ADR-0016](ADR-0016-multi-currency-books-tax-lots-and-tax-plugins.md) |
| 19. AI trust boundary | [ADR-0017](ADR-0017-ai-trust-boundary.md) |

Later additions that extend existing records rather than creating new ones: semi-automated trading and the external-order policy ([ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.md), [ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.md)); short selling, borrow and financing ([ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.md), [ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.md)); crypto venue counterparty risk ([ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.md)); disaster recovery ([ADR-0005](ADR-0005-messaging-and-deployment-topology.md), [ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.md)); the LEAN port-cost table ([ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.md)).

## Amendments to the main documents (applied)

While writing these records, five inconsistencies were found between the [main report](../../README.md) and the [recommended architecture](../../architecture/recommended-architecture.md), or inside the latter. Each ADR states a resolution. **All five, and the smaller messaging-row point below, were applied to the main documents on 2026-10-05**; the "Status" column says where.

| # | Inconsistency | Resolution | Status |
|---|---|---|---|
| 1 | The README security row, §2 and the §8.4 checklist say the Taiwan `.pfx` is mounted **only** into the Shioaji sidecar. §3.5 and §3.12 give the kill switch its own Shioaji session, which needs the certificate. §7's split topology places the kill switch in Tokyo, away from the broker's allow-listed IP | [ADR-0008](ADR-0008-key-and-secret-management.md), [ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.md): mount the `.pfx` into exactly two containers (sidecar and kill switch), and run one kill-switch instance per site | **Applied:** README security row and component diagram; architecture §2, §3.5, §3.12, §7 (one kill-switch instance per site) and the §8.4 checklist |
| 2 | The README and §2 say the kill switch has "its own credentials", but for IBKR it shares the IB Gateway login (§3.5), and an independent session is unverified | [ADR-0008](ADR-0008-key-and-secret-management.md), [ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.md): state the IBKR caveat explicitly until Phase 0 verifies a second username | **Applied:** the caveat ("path 2 is not independent of IB Gateway until Phase 0 verifies a second username; the broker app is the last resort") is in the README Control bullet, component diagram and risk table, and in architecture §2, §3.5 and §8.4 |
| 3 | The README calls the Taiwan sidecar "built to an edge-connector contract", and T3 puts the Windows gateway behind "HTTP/gRPC or a NATS leaf node". §2 defines the sidecar as SinoPac's own `shioaji server start`, and §7 says a Windows shim exposes "the same gateway contract as the Shioaji sidecar (HTTP/SSE)". The contract is never defined | [ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.md): define a platform-owned Taiwan gateway contract (Protobuf; HTTP + SSE in scenario 1, a NATS leaf node in scenario 2); the sidecar runs a shim over Shioaji | **Applied:** README bottom line, broker row, seams table and T3; architecture §2 (contract shim), §3.4 (contract defined) and §7 |
| 4 | README principle 3 says money is held as "fixed-point integers in the engine **and ledger**"; §3.6 and §4.1 specify PostgreSQL `NUMERIC` and `Decimal` in the ledger | [ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md): "exact fixed-point values", meaning scaled integers in the engine and lake and scale-quantized `NUMERIC`/`Decimal` in the ledger | **Applied:** README principle 3 |
| 5 | README principle 4 says "UTC int64 nanoseconds **everywhere**", but the §4.2 and §4.4 schemas use `TIMESTAMPTZ` for `valid_from`, `known_at` and `ts_recorded`. The lake stores `ts_recv` while replay merges by `ts_init`, with no mapping defined | [ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md): int64 ns for every *event* time; `TIMESTAMPTZ` only for bookkeeping metadata; the catalog build sets `ts_init = ts_recv` (or `ts_event` when no receipt time exists) | **Applied:** README principle 4 |

A smaller wording point: the README messaging row listed "Protobuf contracts" next to the Valkey streams, while §5.1 specifies NautilusTrader's JSON/MessagePack on those streams. [ADR-0005](ADR-0005-messaging-and-deployment-topology.md) keeps engine-native payloads on Valkey and applies Protobuf at the journal and API boundary. **Applied** to the README messaging row.

## Phase 0 verifications that will update these records

| Verification | ADR |
|---|---|
| NautilusTrader v2 out-of-tree adapter API; Taiwan matching extensions (else T7); a corporate-action module in `BacktestNode` | [0002](ADR-0002-extend-nautilustrader-as-backtest-engine.md), [0006](ADR-0006-broker-connectivity-and-gateway-contract.md) |
| Valkey as the NautilusTrader Redis backend and the egress format | [0005](ADR-0005-messaging-and-deployment-topology.md) |
| IBKR `reqGlobalCancel` versus master client ID; 2FA cadence; a second username | [0008](ADR-0008-key-and-secret-management.md), [0013](ADR-0013-risk-gate-and-three-path-kill-switch.md) |
| Dead-man and cancel-on-disconnect support per venue and product | [0013](ADR-0013-risk-gate-and-three-path-kill-switch.md) |
| Shioaji shim approach, odd lots with tiny real orders, second-session cancel path; cloud-IP acceptance by the Taiwan broker | [0006](ADR-0006-broker-connectivity-and-gateway-contract.md), [0005](ADR-0005-messaging-and-deployment-topology.md) |
| TAIFEX night-session trading-date rule; 2027 holidays; rounding and minimum fees checked against real statements | [0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md), [0012](ADR-0012-security-master-rules-packs-and-calendars.md) |
| Python 3.14 wheels for every pin; DuckDB 2.0 upgrade | [0001](ADR-0001-core-engine-and-strategy-language.md), [0004](ADR-0004-parquet-lake-for-historical-data.md) |
| NautilusTrader 2.0 GA date and rc6 changes | [0010](ADR-0010-real-money-gate-and-dependency-pinning.md) |
| FinMind sponsor-tier terms for personal live trading; FinMind and TEJ quotes | [0009](ADR-0009-open-source-licensing-strategy.md) |
| NautilusTrader in-flight-order reconciliation for each upstream adapter; the IB adapter's use of `orderRef` | [0002](ADR-0002-extend-nautilustrader-as-backtest-engine.md), [0006](ADR-0006-broker-connectivity-and-gateway-contract.md), [0011](ADR-0011-intent-wal-and-hash-chained-ledger.md) |
| Each crypto perpetual and options venue's eligibility for a Taiwan resident (FSC AML-registration list, venue geo terms) | [0006](ADR-0006-broker-connectivity-and-gateway-contract.md), [0013](ADR-0013-risk-gate-and-three-path-kill-switch.md), [0015](ADR-0015-self-use-regulatory-posture-and-legal-gate.md) |
| Short-sale and financing rules and fees against broker contracts and statements; borrow data sources | [0012](ADR-0012-security-master-rules-packs-and-calendars.md) |
| Massive corporate-action coverage of delisted US tickers | [0004](ADR-0004-parquet-lake-for-historical-data.md), [0012](ADR-0012-security-master-rules-packs-and-calendars.md) |
| IBKR streaming bundles, OPRA and market-data-line limits | [0006](ADR-0006-broker-connectivity-and-gateway-contract.md) |
| Taiwan-resident tax rates and thresholds for the tax year | [0016](ADR-0016-multi-currency-books-tax-lots-and-tax-plugins.md) |

## Adding a record

1. Copy the section structure of any record above. Use the next free number and a kebab-case name: `ADR-NNNN-short-title.md`.
2. The first line is the language switcher (`**English** | [繁體中文](ADR-NNNN-short-title.zh-TW.md)`), followed by a blank line and the H1 title.
3. Start at **Proposed**. When a record changes a decision, mark the old one **Superseded by ADR-NNNN** instead of editing its outcome.
4. Records that the roadmap requires later include the signed risk-acceptance ADR for an RC engine ([ADR-0010](ADR-0010-real-money-gate-and-dependency-pinning.md)), solo-operator promotion checklists for G3 ([ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.md)), and the T1 legal sign-off ([ADR-0015](ADR-0015-self-use-regulatory-posture-and-legal-gate.md)).
5. Add a row to the index above.
