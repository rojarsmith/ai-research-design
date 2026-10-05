**English** | [繁體中文](ADR-0011-intent-wal-and-hash-chained-ledger.zh-TW.md)

# ADR-0011: Order-intent write-ahead log, hash-chained ledger and reconciliation as a release blocker

## Status

**Proposed** · 2026-10-05 · Scope: scenario 1, with the scenario-2 extension noted.

## Context and problem statement

After a crash we must know exactly which orders were sent, which were filled and what we hold. Months later we must be able to prove which orders, fills and limit changes happened, in a tamper-evident way. The venue is the source of truth for what actually happened.

Forces ([07](../../research/07-system-architecture-messaging.md), [08](../../research/08-risk-security-ops-compliance.md), [evaluation](../../architecture/evaluation.md)):

- **NautilusTrader's persistence is asynchronous.** Event capture does not gate dispatch on a durable commit. There is therefore a window in which an order can reach the venue with no durable local record.
- **Valkey** with `appendfsync everysec` can lose about 1 s of acknowledged writes, and asynchronous replication loses writes on failover.
- **None of the three proposals closed this window completely.** B and C proposed a journal written before each send; A relied on reconciliation alone.
- **Ledger options:**
  - PostgreSQL append-only event tables (ACID, cheap);
  - KurrentDB (source-available; another system to run);
  - Kafka as the system of record (no per-aggregate concurrency);
  - immudb (BSL 1.1);
  - Amazon QLDB, which AWS has discontinued;
  - S3 Object Lock in compliance mode, assessed for SEC 17a-4, CFTC and FINRA, as a WORM archive.
- **Positions change without orders**: through funding, corporate actions, exercise, assignment and coupons.

## Decision drivers

- No order may leave the node without a durable local record of the intent.
- No duplicate orders after a crash or timeout.
- A tamper-evident audit trail at near-zero cost and operations.
- One store for the ledger, reference data and MLflow (PostgreSQL is already in the stack).
- Recovery that always defers to the venue.

## Considered options

1. **Rely on NautilusTrader's cache persistence plus reconciliation** (Proposal A's original design).
2. **A node-local intent WAL with fsync before send, tailed into a PostgreSQL append-only, hash-chained ledger, with a nightly WORM export and reconciliation as a release blocker.**
3. **A dedicated event store** (KurrentDB) or **Kafka** as the system of record.
4. **immudb** as the tamper-evident ledger.

## Decision outcome

**Chosen option: 2.** The WAL closes NautilusTrader's asynchronous-persistence window at a cost that is negligible at our latency tier (tens to hundreds of milliseconds). PostgreSQL with a hash chain gives tamper evidence in a store we already run. Reconciliation remains the final authority.

### Intent WAL

- **Pre-send record.** Before `submit_order`, `GuardedStrategy` (or the `ManualOrderActor` for manual tickets and approved proposals) appends an intent record to a node-local, append-only file and **fsyncs it**, using group commit within one kernel cycle.
- Each intent record holds `intent_id`, the **canonical** `client_order_id`, `origin` (STRATEGY, MANUAL or PROPOSAL), `tenant_id`, account, instrument, side, quantity, price, order type, time in force, flags, the `RiskDecision` ID and a record hash. It does **not** hold the venue-encoded ID: upstream adapters assign that inside the adapter, after the WAL write (IBKR's integer `orderId` comes from `nextValidId` at send time).
- **Post-send record.** When the adapter reports the venue identifiers, the node appends a `venue_id_assigned` record (canonical ID → venue-encoded client ID, venue order ID, and for IBKR `orderId` and `permId`). It is not fsynced ahead of anything, and recovery never depends on it.
- The `journal` container tails both record kinds into the ledger as `OrderIntentRecorded` and `VenueIdAssigned` events. WAL fsync latency and journal lag are trading SLIs with alerts.
- **Off-box copy.** A shipper copies new WAL segments to S3 (or to the standby) every few seconds, for an intent RPO of about 10 s; PostgreSQL is archived continuously for a ledger RPO of 5 minutes or less (§7.1 of the [recommended architecture](../../architecture/recommended-architecture.md)).

### Ledger

| Aspect | Decision |
|---|---|
| Store | PostgreSQL 18, table `ledger_event`, append-only and partitioned by month on `ts_recorded` |
| Immutability | `UPDATE` and `DELETE` are revoked; the journal role may only `INSERT` |
| Tamper evidence | Each row stores `prev_hash` and `hash = SHA-256(prev_hash ‖ canonical row)`. A daily digest of the last hash is stored off-box |
| Concurrency | A per-aggregate `seq` gives optimistic concurrency. `event_id` is a UUIDv7 |
| Payload | The Protobuf JSON mapping of the event, with `tenant_id` (default `'self'`) and `account_id` on every row |
| Event types | Order lifecycle (including `VenueIdAssigned`, `OrderStatusUnknown`, `OrderReconciled` and `ExternalOrderAdopted`), proposals (`ProposalCreated`, `ProposalApproved`, `ProposalRejected`, `ProposalExpired`), fills, `FundingSettled`, `CorporateActionBooked`, `OptionAssigned`, `CouponPaid`, `FxConverted`, `CashTransferred`, `WithholdingTaxBooked`, `BorrowFeeAccrued`, `MarginInterestAccrued`, `TaxLotOpened`/`Closed` ([ADR-0016](ADR-0016-multi-currency-books-tax-lots-and-tax-plugins.md)), `LimitChanged`, `TradingStateChanged`, `ReconciliationBreak` and others |
| Projections | Positions per account, strategy and instrument; cash per currency; realized and unrealized P&L; fees and taxes; funding accruals; open orders |
| Archive | A nightly export to **S3 Object Lock in compliance mode** |
| Numbers | `NUMERIC` and `Decimal` quantized to scale ([ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md)) |

### Idempotency and reconciliation

- Fills are de-duplicated on `(venue, exec_id)`. Positions are derived from fills and lifecycle events, never from status messages.
- A timeout or disconnect makes an order `UNKNOWN` in our Shioaji adapter and in the ledger projection. It is resolved by query or reconciliation, never by blind resubmission ([ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.md)). For upstream adapters, NautilusTrader keeps the order `SUBMITTED` and its in-flight-order reconciliation resolves it; a Phase 0 spike verifies this per adapter.
- **Per-venue recovery** (table in §3.4 of the [recommended architecture](../../architecture/recommended-architecture.md)). IBKR has no lookup by `orderRef`, so recovery scans `reqAllOpenOrders`, `reqExecutions` and `reqCompletedOrders` and matches the canonical ID in `orderRef`, or the `permId` from the post-send record. Crypto venues are queried by their client-ID field (`origClientOrderId`, `clOrdId`, `orderLinkId`, `label`, `cloid`). Shioaji is queried through the TW gateway contract by client ID or by the ack-data match.
- **Startup:**
  1. Rebuild state from the cache and the ledger projections.
  2. Start the adapters in reconciling mode, with **strategies stopped and new orders blocked**.
  3. Resolve every WAL intent that has no terminal state with the per-venue recovery procedure.
  4. Pull open orders, fills since the watermark (minus a safety margin), positions and balances.
  5. Write missing fills as events tagged `source=RECONCILIATION`. Orders with no matching intent are external and follow the account's external-order policy (below).
  6. Stay `HALTED` and page a human on any break beyond tolerance that the policy does not explain.
- **Intraday:** every 1–5 minutes. **End of day:** against broker statements (對帳單), including fees, funding, corporate actions, exercise and assignment, and coupons.
- **Any unexplained break halts the account.** Breaks are tracked with a reason and a resolution.
- **External-order policy (per account).** A solo trader often places manual orders in the broker app on the same account. Each account declares `dedicated` (the automated book has its own account or sub-account, so any external order is a break and halts) or `adopt` (external orders and fills are booked by reconciliation as `ExternalOrderAdopted` and `source=EXTERNAL` fills into a `manual` book, count toward limits at once, and move any automated strategy trading the same instrument to `REDUCING` until the owner confirms). Position differences that external fills do not explain still halt. Manual trades placed through the platform's own order ticket need no adoption ([recommended architecture](../../architecture/recommended-architecture.md) §3.13 and §5.7).
- **Reconciliation is a release blocker** for the first live trade. Valkey runs with `appendfsync always` on the trading host as an extra safeguard.

**Kill criterion.** If the WAL build item slips more than three months past its phase exit, rely on NautilusTrader persistence plus reconciliation, and record the residual risk in a new ADR.

### Consequences

**Positive**

- A crash between "send" and "acknowledge" is recoverable without duplicate orders, through the per-venue recovery procedure (verified for each adapter in Phase 0).
- Manual trades on a shared account no longer halt the node when the account uses the `adopt` policy.
- The audit trail is tamper-evident, queryable with SQL, and costs nothing extra to run. The WORM archive covers regulatory-style retention if it is ever needed.
- `tenant_id` in every row means tenancy later needs no migration.
- The same projections feed the UI, risk and P&L.

**Negative**

- The fsync adds latency to every order (measured, and acceptable at our tier). WAL rotation and retention must be managed.
- A second order record exists next to NautilusTrader's own state, and they must agree. Reconciliation tests cover this.
- Hash chains detect tampering only if the digests are stored somewhere the attacker cannot reach.
- Recovery for IBKR depends on scanning callbacks rather than a lookup, so it is slower and must handle the daily scope of `reqCompletedOrders`; an intent older than that scope is resolved from executions and statements.
- In `adopt` mode, a mistaken manual trade is booked rather than stopped; the alert and the `REDUCING` state of the affected strategy are the only guard.
- Event schemas must be versioned forever, with upcasters.

### Confirmation

- Property tests: position equals the sum of fills; fill handling is idempotent; the hash chain verifies.
- Reconciliation tests (`tests/recon`) inject synthetic breaks, `UNKNOWN` orders and external orders (under both policies) on every merge.
- A Phase 0 spike verifies in-flight-order recovery for every upstream adapter used, including that the Nautilus IB adapter carries the canonical ID in `orderRef`.
- A quarterly full-rebuild drill restores the ledger by point-in-time recovery and replays the shipped WAL segments on the standby.
- Chaos drill before G3: `kill -9` mid-order, then restart and verify that there is no duplicate and the ledger is complete.
- Go-live checklist: 5+ consecutive clean reconciliation sessions; WAL fsync latency measured; journal-lag alert configured.

### Revisit when

- **T1 or T2:** the out-of-process order gateway becomes the single writer per account, with a lease and fencing token and `PendingNew` persisted before send. The ledger publishes through a transactional outbox to NATS. A synchronous replica gives RPO ≈ 0 for the order journal.
- **T9:** active-passive per account; a new leader reconciles before trading.
- The kill criterion fires.

## Links

- [Main report: trade-records row, bottom-line grafts and risks](../../README.md)
- [Recommended architecture §3.4, §3.6, §4.4, §5.2 and §5.7](../../architecture/recommended-architecture.md)
- [Evaluation record: grafts 8, 9 and 39; concern 12](../../architecture/evaluation.md)
- [Proposal B](../../architecture/proposal-B-performance-core.md) · [Proposal C](../../architecture/proposal-C-platform-scale.md)
- Research: [07 Messaging and state](../../research/07-system-architecture-messaging.md) · [08 Risk and audit](../../research/08-risk-security-ops-compliance.md) · [04 Order lifecycle](../../research/04-broker-exchange-connectivity.md)
- Related ADRs: [ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md) · [ADR-0005](ADR-0005-messaging-and-deployment-topology.md) · [ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.md) · [ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.md)
