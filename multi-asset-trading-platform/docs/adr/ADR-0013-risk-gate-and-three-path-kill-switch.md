**English** | [繁體中文](ADR-0013-risk-gate-and-three-path-kill-switch.zh-TW.md)

# ADR-0013: A fail-closed risk gate identical in every mode, and a three-path kill switch

## Status

**Proposed** · 2026-10-05 · Scope: scenario 1, with the scenario-2 risk gateway noted. Phase 0 verification of per-venue cancel and dead-man semantics updates this ADR.

## Context and problem statement

Every order must pass the same pre-trade checks in backtest, paper and live, or backtests lie. All trading must stop quickly even if our own process is wedged. What is the shape of the risk gate, and how does the kill switch work?

Forces ([08](../../research/08-risk-security-ops-compliance.md), [evaluation](../../architecture/evaluation.md)):

- **Where controls can live:**
  - venue-native controls (price bands, IP-bound keys, dead-man timers);
  - the framework engine: NautilusTrader `RiskEngine` checks precision, maximum notional, reduce-only and submit/modify rate limits, and has `ACTIVE`/`REDUCING`/`HALTED` states;
  - a custom in-process library;
  - an out-of-process risk gateway (about 0.1–2 ms per hop);
  - broker or hardware layers.

  SEC 15c3-5 and EU RTS 6 are useful checklists even for self-use.
- **Kill-switch gaps found in review:**
  - Binance's `countdownCancelAll` dead-man timer covers USDⓈ-M futures only, per symbol, and not spot.
  - An IBKR client can normally cancel only its own orders, unless it uses `reqGlobalCancel` (which also cancels manual orders) or the master client ID.
  - The kill switch shares IB Gateway with the node.
  - Shioaji has no known dead-man feature.
  - Revoking a key does not cancel resting orders.
- **Classic failure modes** are runaway loops (Knight Capital, 2012), fail-open exceptions and internal state treated as truth.
- **Operations.** A solo operator on 24/7 crypto cannot watch the screen all the time.
- **Placement.** The §7 split topology of the [recommended architecture](../../architecture/recommended-architecture.md) places the kill switch in Tokyo, while the Taiwan broker keys are bound to the home or Taipei IP and IB Gateway runs there too.

## Decision drivers

- Identical checks in every mode (backtest–live parity).
- Fail closed: an exception rejects the order.
- A stop path that does not depend on the strategy process.
- Cheap enough for one person; no extra network hop on the order path in scenario 1.
- Honest coverage per venue: never assume a dead-man feature that does not exist.

## Considered options

1. **Three layers inside the node path** (our fail-closed rules-pack checks in `GuardedStrategy` via `tp_risk`, then the NautilusTrader `RiskEngine`, then venue-native controls), plus loss breakers, plus a **three-path kill switch**: node, independent `killswitch` service, venue dead-man.
2. **The NautilusTrader `RiskEngine` and venue controls only.**
3. **An out-of-process risk gateway now** (option D in research 08).
4. **Venue-native controls only.**

## Decision outcome

**Chosen option: 1.** It gives a full check set that is identical in every mode at in-process cost. The kill switch survives a wedged node. The out-of-process gateway is deferred to scenario 2, where it brings multi-account aggregation.

### Risk layers (identical in every mode)

| Layer | Checks |
|---|---|
| 1. `GuardedStrategy` → `tp_risk.check(intent, context) -> RiskDecision` (pure, engine-agnostic, **fail-closed**) | Tick conformity; lot and quantity unit; price-limit band (Taiwan ±10%, US LULD); auction-phase order-type restrictions; disposition-stock and sell-first-suspension restrictions; short-sale checks from the rules pack (shortable and locate, Rule 201 SSR, the Taiwan below-previous-close rule, 融券 suspension windows, credit-account eligibility and quotas; [ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.md)); maximum order quantity and notional; position and exposure limits; **per-venue exposure caps**; a margin and buying-power estimate with a 20–30% buffer; duplicate and runaway detection; session and instrument-state checks; capability flags |
| 2. NautilusTrader `RiskEngine` | Precision, maximum notional, reduce-only, submit/modify rate limits, trading state `ACTIVE`/`REDUCING`/`HALTED` |
| 3. Venue-native | Price bands, IP-bound trade-only keys, dead-man timers where offered |

- **Loss breakers.** A daily loss limit moves the account to `REDUCING`. A hard limit moves it to `HALTED` and cancels all orders. A reset requires a logged reason and, for a solo operator, a cooling-off period.
- **Limits** live in `config/limits.yaml` in git. Every change is a `LimitChanged` ledger event. Changing limits through the API requires re-authentication and a reason. **Telegram can never raise a limit.**
- **One gate for every order source.** Strategy intents, manual tickets (`POST /v1/orders`) and approved proposals (`POST /v1/proposals/{id}/approve`, or Telegram `/approve` with the PIN) all pass layer 1, the WAL and layer 2. A proposal is re-checked at approval time and refused if it has expired or the price has moved beyond its tolerance. Telegram can approve or reject a proposal but cannot edit it, enter a free-form order or raise a limit. AI tools can only create proposals ([ADR-0017](ADR-0017-ai-trust-boundary.md)).
- **External orders** (placed outside the platform) follow the account's external-order policy, `dedicated` or `adopt` ([ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.md)); adopted orders count toward every limit and loss breaker.
- **Portfolio risk (asynchronous):** real-time P&L, drawdown and exposure in TWD and per currency; daily historical VaR/ES on 250–500 days; fixed stress shocks (index gap −10%, crypto ±30%, volatility ×2, rates +100 bp, TWD/USD ±5%, a stablecoin de-peg to 0.90, loss of the largest crypto venue balance); portfolio greeks and DV01. A drift alarm moves a strategy to `REDUCING` when live P&L leaves the backtest's Monte Carlo 95% band.
- **Crypto venue counterparty risk:** per-venue exposure caps in `limits.yaml` (maximum equity in USD and as a share of net liquidation value); stablecoins held as instruments with de-peg alerts; venue-health alerts (withdrawal suspensions, proof-of-reserves changes, abnormal funding, API degradation); a venue-failure runbook; perpetual and options venues admitted only after a Phase 0 eligibility check for a Taiwan resident, with IBKR-first as the default ([recommended architecture](../../architecture/recommended-architecture.md) §3.5).

### Kill switch: three paths

| Venue / product | Path 1: node | Path 2: `killswitch` service | Path 3: venue-native |
|---|---|---|---|
| IBKR | Strategy cancel-all and flatten | Its own TWS API client session (ib_async) through IB Gateway, using **`reqGlobalCancel`** or the master client ID (verify in Phase 0) | None known for API orders. Manual last resort: the IBKR mobile app or web client (runbook) |
| Binance USDⓈ-M futures | Same | Its own trade-only key; cancel all open orders per symbol | `countdownCancelAll`, **armed per traded symbol** |
| Binance spot | Same | Same | **None.** Keep only working capital on the venue |
| OKX, Bybit, Deribit, Hyperliquid | Same | Same | Dead-man or cancel-on-disconnect where offered; confirm per product in Phase 0 |
| Shioaji (TWSE/TPEx/TAIFEX) | Same | Its own Shioaji session (5 allowed per person ID) to list and cancel open orders | None known |

- **Placement.** The kill switch is a minimal container, separate from the nodes, with its own crypto keys and its own Shioaji session ([ADR-0008](ADR-0008-key-and-secret-management.md)). In a split deployment it runs **one instance per site**, so each instance uses the static IP that its brokers allow-list, and the IBKR path reaches the local IB Gateway.
- **Triggers:** the `killswitch` CLI, an API endpoint, the web UI, and Telegram `/halt` and `/flatten` with a confirmation PIN. Runbooks **cancel resting orders before revoking keys**.
- **Known limitation (IBKR caveat).** For IBKR, path 2 is not independent of IB Gateway until Phase 0 verifies a second username: paths 1 and 2 share the gateway and the IBKR login, so a wedged gateway leaves only the manual last resort, the IBKR mobile app or web client. The main report and §2, §3.5 of the recommended architecture state this wherever the kill switch is described.

### Consequences

**Positive**

- Backtests include the same rejections the live system would make, so there is no hidden P&L from orders the real system would deny.
- A crashed or hung node cannot leave orders unmanaged on crypto venues or at SinoPac.
- Coverage gaps are explicit per venue, and balances are minimized where no dead-man exists.
- Controls map to SEC 15c3-5 and EU RTS 6 checklists, which eases a later regulated offering.

**Negative**

- Pre-trade checks share fate with the node process. The independent kill switch mitigates this, but no out-of-process gate exists in scenario 1.
- The kill switch holds extra credentials and a second Shioaji session, which widens the secret surface.
- IBKR emergency cancels via `reqGlobalCancel` also cancel manually entered orders. That is acceptable in an emergency, but the operator must know it.
- Drills (monthly kill-switch drills and quarterly chaos drills) are a standing duty.

### Confirmation

- Property tests: the gate never passes an over-limit order, and an exception inside a check rejects the order. API tests: manual tickets and approved proposals pass the same gate; expired or drifted proposals are refused; Telegram cannot raise a limit; an order that would breach a venue exposure cap is rejected.
- Phase 0 records each crypto venue's Taiwan-resident eligibility, and the go-live checklist records the venue caps.
- Kill-switch drills on all three paths for every venue and product traded, before G3 and then monthly.
- Phase 0 verifies the IBKR cancel semantics, dead-man support per venue and product, and Shioaji cancel latency from a second session. Absences are recorded here.
- Go-live checklist items: limits reviewed, loss breakers tested, dead-man support confirmed or recorded as absent.

### Revisit when

- **T1 or T2:** an out-of-process risk gateway as the single writer per account; a hierarchical kill switch (strategy → account → venue → firm) on an independent network path with a four-eyes reset; intraday VaR/ES and greek grids.
- A second IBKR username proves gateway-independent → move the kill switch's IBKR path onto it.
- A venue adds or removes dead-man support → update `capabilities.yaml` and this table.

## Links

- [Main report: OMS/risk row, design principle 8 and the kill-switch risk](../../README.md)
- [Recommended architecture §3.5, §7 and §8.4](../../architecture/recommended-architecture.md)
- [Evaluation record: concerns 5 and 7; graft 15](../../architecture/evaluation.md)
- Research: [08 Risk, security, operations and compliance](../../research/08-risk-security-ops-compliance.md) · [04 Broker connectivity](../../research/04-broker-exchange-connectivity.md) · [11 Taiwan localization](../../research/11-taiwan-market-localization.md)
- Related ADRs: [ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.md) · [ADR-0008](ADR-0008-key-and-secret-management.md) · [ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.md) · [ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.md) · [ADR-0017](ADR-0017-ai-trust-boundary.md)
