**English** | [繁體中文](ADR-0005-messaging-and-deployment-topology.zh-TW.md)

# ADR-0005: Real-time messaging and deployment form: in-process bus, Valkey egress, single-host Compose

## Status

**Proposed** · 2026-10-05 · Scope: scenario 1. The Phase 0 Valkey spike updates this ADR. Scenario 2 is reached through triggers T2 and T9.

## Context and problem statement

Inside a trader node, NautilusTrader dispatches every event on one thread through its in-process MessageBus. Outside the node, several things need events or must send commands:

- the journal writer, which builds the ledger;
- the API gateway and UI;
- alerts;
- the control path (halt, resume, flatten, limit change).

Two linked questions follow. Which transport carries events between processes? And in what form (processes, containers, hosts) is the system deployed?

Forces ([07](../../research/07-system-architecture-messaging.md), [08](../../research/08-risk-security-ops-compliance.md)):

- **Messaging candidates on 2026-10-05:**
  - in-process bus;
  - NATS JetStream 2.15.0 (Apache-2.0, a single binary);
  - Kafka 4.3.1 (JVM, operationally heavier);
  - Redpanda (BSL Community edition);
  - Redis 8 (RSALv2/SSPLv1/AGPLv3) and Valkey 9.1.2 (BSD, Linux Foundation);
  - Aeron (microsecond paths; kernel bypass is a paid add-on);
  - ZeroMQ (no libzmq release since 2023-10).
- **NautilusTrader** has built-in external streams and cache backing for Redis, using JSON or MessagePack for all messages. Its documentation names Redis and PostgreSQL, not Valkey, so Valkey compatibility is unverified. Its persistence does not gate dispatch on a durable commit.
- **Durability.** Valkey with `appendfsync everysec` can lose about 1 s of acknowledged writes, and asynchronous replication loses writes on failover.
- **Style.** A modular monolith with splits only at stable seams keeps replay deterministic. Microservices on day one add network hops on the order path and distributed failure modes.
- **Isolation levels.** L0 is one node for everything. **L1** is one node per broker account. L2 is one node per strategy and account (this runs into broker session limits; Shioaji allows 5 sessions per person ID). L3 is per tenant.
- **Hosting.** Broker API keys are IP-bound, so a static egress IP is required. Some Taiwan brokers may refuse cloud IPs. 24/7 crypto favours AWS Tokyo; Taiwan brokers favour a home server or the Taipei region.
- **Proposal C** (Kubernetes, NATS, OpenBao, 13 deployables from day one) costs about $6k–16k per month before any external user, and its feasibility was scored 2.5/10.

## Decision drivers

- Deterministic replay and backtest–live parity inside a node.
- No custom bridge code if the engine already speaks a transport.
- Operational load that one person can carry; a modest monthly cost once live (about $10–200 on a home server, $200–400 on one cloud VM; see the cost table in the [main report](../../README.md)).
- Crash and reconciliation scope limited to one broker account.
- Permissive licences for anything that might later be offered as a service.
- Additive growth to a team platform without a rewrite.

## Considered options

**Messaging**

1. **In-process MessageBus inside nodes, plus Valkey streams for node egress and control** (NautilusTrader's built-in external streams), with NATS JetStream as the fallback.
2. In-process bus plus **NATS JetStream from day one**, through a bridge actor.
3. A **Kafka or Redpanda** backbone.
4. **Aeron or ZeroMQ.**

**Deployment form**

1. **A modular-monolith trader node per broker account (L1), plus a few processes split at stable seams, on Docker Compose on one Linux host.**
2. **Microservices on Kubernetes** (Proposal C).
3. **A desktop all-in-one** (topology A) for live trading.
4. **A multi-region hybrid from day one** (Proposal B).

## Decision outcome

**Chosen options: messaging 1 and deployment 1.** NautilusTrader already speaks Redis-protocol streams, so no bridge is needed if Valkey works. Valkey keeps a BSD licence where Redis 8 does not. One Compose host is the smallest topology that still isolates accounts, secrets and vendor processes.

### Messaging rules

| Path | Transport | Notes |
|---|---|---|
| Inside a node | NautilusTrader in-process MessageBus | Single-threaded dispatch; no external hop on the order path |
| Node → journal and API | NautilusTrader external streams on **Valkey 9.1** (JSON or MessagePack, the engine's own serialization) | The journal writer and the API translate these messages into the Protobuf contracts in `proto/` at the boundary. Valkey payloads stay engine-native |
| Control → node | One Valkey stream per account, `tp:ctl:{account_id}`, consumed by a `ControlActor` in the node | Commands come from the API or Telegram and are audited in the ledger |
| Alerts | `tp:alerts` stream → notifier (Telegram/ntfy) | — |
| Engine cache | Valkey as the NautilusTrader cache backing | Valkey runs with **`appendfsync always`** on the trading host |
| Durability of order intent | Not delegated to the bus | A node-local intent WAL with fsync before send ([ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.md)) |
| Contracts | Protobuf schemas in `proto/` with `buf breaking` checks in CI, for the API, commands and ledger payloads | JSON mapping on the wire first; binary when profiling justifies it |

**Phase 0 spike.** Validate Valkey as the NautilusTrader Redis backend and the egress format. **Fallback:** the PostgreSQL cache backing plus NATS JetStream 2.15 through a small bridge actor.

**Not used in scenario 1:** Kafka, Redpanda, Aeron, ZeroMQ, RabbitMQ and Pulsar.

### Deployment rules

| Aspect | Decision |
|---|---|
| Style | A modular monolith per trader node (hexagonal core). Processes are split only at stable seams: broker sidecars, the API, journaling, the kill switch and the scheduler |
| Isolation | **L1**: one NautilusTrader `LiveNode` per broker account, with strategies tagged inside it. Cross-account risk is aggregated asynchronously |
| Deployable rule | A new deployable must have its own scaling, failure or security boundary; otherwise it is a module in an existing one |
| Containers (about ten) | `node-<account>`, `ib-gateway` (IB Gateway + IBC), `shioaji-sidecar`, `journal`, `api`, `killswitch`, `scheduler`, `postgres`, `valkey`, `mlflow`, a metrics/log shipper, plus on-demand `backtest` jobs from the same image |
| Host | **One Linux host running Docker Compose with a static egress IP**: an always-on home mini-PC with a UPS, or one VM in Taipei (AWS `ap-east-2`, opt-in, or GCP `asia-east1`) or Tokyo (AWS `ap-northeast-1`). Choose by measured RTT, and only after confirming that the Taiwan broker accepts API logins from cloud IPs |
| Access | The UI and API are reachable only over Tailscale/WireGuard. Nothing is exposed to the public internet |
| Optional split | A second small VM in Tokyo for 24/7 crypto, with one ledger. The kill switch then runs one instance per site ([ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.md)) |
| Time and operations | chrony; a monthly maintenance window; Grafana Cloud free tier or Prometheus + Grafana + Loki |
| Backup and disaster recovery | Continuous PostgreSQL archiving (pgBackRest or WAL-G) to S3 for a ledger RPO of 5 minutes or less; the intent WAL shipped off-box every few seconds; Valkey treated as rebuildable; bronze synced nightly. RTO of 1 hour or less by an infrastructure-as-code rebuild on a cold standby whose IP is pre-registered on broker allow-lists. A host-loss runbook, a monthly restore test and a quarterly full-rebuild drill (§7.1 of the [recommended architecture](../../architecture/recommended-architecture.md)) |
| Research and backtests | They may also run on a desktop (topology A: Windows, macOS or Linux), but never as the live host |

### Scenario 2 (triggers T2 and T9)

- NATS JetStream becomes the inter-process bus, with subjects `tp.{tenant}.{account}.orders.{event}`, `tp.{tenant}.{account}.ctl` and `tp.md.{venue}.{instrument}`, accounts per tenant, and leaf nodes for Taiwan sites and edge connectors.
- The order/risk gateway moves out of process as the single writer per account, with a lease and fencing token.
- There is one gateway process per venue account. Kubernetes 1.35+ hosts stateless services, while trader nodes stay on pinned VMs.
- On T9: active-passive per account, never active-active against one account.

### Consequences

**Positive**

- No network hop on the order path, so replay stays deterministic.
- No custom bridge if the spike passes. The fallback is small and known.
- The whole system runs on one box, with a single static IP for broker allow-lists, for about $10–200 per month on a home server (plus hardware) or $200–400 on one cloud VM once live.
- A crash or reconciliation break is contained to one account.
- The messaging components are permissively licensed (Valkey BSD, NATS Apache-2.0), so a later service offering inherits no Redis or Redpanda licence trap.

**Negative**

- A single host is a single point of failure, and the WAL, Valkey, the ledger and the lake share its disk. Venue dead-man timers, auto-flatten rules, paging, a UPS, off-box archiving, a cold standby and rebuild drills partly compensate; a host loss still costs up to an hour of trading.
- `appendfsync always` costs Valkey write latency (acceptable at our tier). The WAL remains the real durability guarantee.
- Valkey compatibility with NautilusTrader is unverified until the spike.
- Two serialization worlds exist (engine JSON/MessagePack on Valkey, Protobuf at the API and ledger), so the boundary translators must be tested.
- Moving to NATS later means rewriting the egress and control plumbing, though not the kernel, strategies or ledger.

### Confirmation

- The Phase 0 spike verdict is recorded here: Valkey as NautilusTrader cache and stream backend, and the egress message format.
- Chaos drills before G3: `kill -9` mid-order, Valkey restart, network partition, PostgreSQL restore.
- A Compose health dashboard plus trading SLIs: journal lag, reconnects, clock offset and WAL fsync latency.
- A review gate applies the deployable rule to any new container.

### Revisit when

- **T2:** 4–5+ engineers, or more than about five trader nodes or accounts → NATS, per-venue gateways, an out-of-process risk gateway, OpenBao and Kubernetes for stateless services.
- **T3:** a Windows-only broker is needed → a Windows gateway VM ([ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.md)).
- **T9:** capital that cannot tolerate hours of downtime → active-passive with fencing and a second region.
- The Valkey spike fails → the NATS fallback.

## Links

- [Main report: messaging and deployment rows; triggers T2, T3 and T9](../../README.md)
- [Recommended architecture §2, §5.1 and §7](../../architecture/recommended-architecture.md)
- [Evaluation record: grafts 4, 24 and 39; concerns 6 and 12; rejected elements in §4.3](../../architecture/evaluation.md)
- [Proposal C](../../architecture/proposal-C-platform-scale.md)
- Research: [07 System architecture and messaging](../../research/07-system-architecture-messaging.md) · [08 Risk, security and operations](../../research/08-risk-security-ops-compliance.md)
- Related ADRs: [ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.md) · [ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.md) · [ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.md)
