**English** | [繁體中文](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.zh-TW.md)

# ADR-0003: Numeric representation of prices and quantities, and timestamp precision

## Status

**Proposed** · 2026-10-05 · Scope: all scenarios. This ADR also fixed the wording of design principles 3 and 4 of the main report (see *Decision outcome*; applied 2026-10-05).

## Context and problem statement

Prices, quantities and money flow through the engine, the market-data lake, the PostgreSQL ledger, the API and the browser. Each layer has a different native number type. Timestamps have the same problem. If each layer picks its own representation, the results are rounding drift in P&L, fills that fail tick checks, and look-ahead or ordering bugs from truncated time.

The precision needs differ by asset class ([01](../../research/01-core-language-runtime.md), [05](../../research/05-instrument-model-pricing-analytics.md)):

| Asset class | What drives precision |
|---|---|
| Taiwan stocks and ETFs | Tick ladders from NT$0.01 to NT$5 by price band; ETFs use 0.01 below NT$50 and 0.05 above. The ladder matters more than the digits |
| US equities | Sub-penny quotes under $1; six-figure share prices |
| Crypto | CEX quantities usually have ≤8–10 decimals. On-chain ERC-20 amounts are `uint256` with typically 18 decimals: 1 wei (1e-18) does not fit in a 16-decimal type. Large-supply tokens can have volumes beyond ±9.2 billion units |
| Bonds | US Treasuries quote in 32nds down to 1/256 (0.00390625, eight decimal places); price as % of par; face-value quantities |
| Options | Small premiums with tiered ticks (TXO: 0.1 pt below 10, up to 10 pts at 1,000 and above); multipliers make notional large. Greeks and implied volatility are inherently float64 |

Existing formats: NautilusTrader v2 uses 128-bit fixed point with 16 decimals by default (`PRICE_MAX` about ±17 trillion; about 3–5% slower than the 64-bit, 9-decimal mode). Databento DBN uses int64 scaled by 1e-9.

Time traps: Python `datetime` has 1 µs resolution; pandas 3 infers `datetime64[us]` from strings and `datetime` objects; .NET `DateTime` ticks are 100 ns. JavaScript numbers are exact only up to 2^53 (about 9.0e15), while a current UTC-nanosecond timestamp is about 1.76e18. TAIFEX's night session (15:00–05:00) crosses midnight, and crypto trades 24/7, so the trading date is not the calendar date.

The two source documents disagreed slightly in wording (since corrected):

- Design principle 3 of the [main report](../../README.md) said money is held as "fixed-point integers in the engine and ledger". [Recommended architecture](../../architecture/recommended-architecture.md) §3.6 and §4.1 specify PostgreSQL `NUMERIC` in the ledger.
- Principle 4 said "UTC int64 nanoseconds everywhere", while the schemas in §4.2 and §4.4 use `TIMESTAMPTZ` for `valid_from`, `known_at` and `ts_recorded`. The lake stores `ts_recv` (§4.3), but replay merges by `ts_init` (§5.4, §5.5) without a defined mapping.

## Decision drivers

- Exact and deterministic arithmetic wherever a decision or a booking touches money.
- Lossless interchange with NautilusTrader types and DBN-compatible data.
- Correct behaviour across Python, SQL and TypeScript.
- Enough range for crypto quantities, and exactness for 32nds.
- Speed: integer maths on hot paths; exact decimals only at the edges.
- One unambiguous event-time type that never truncates and never confuses trading date with calendar date.

## Considered options

**Numbers**

1. float64 everywhere.
2. Decimal everywhere (Python `decimal`, PostgreSQL `NUMERIC`), including the engine.
3. **Layered exact representation:** per-instrument fixed-point integers on the engine and storage paths; exact decimals at accounting edges and on the wire; float64 only inside models; explicit, rule-driven conversions.
4. One global int64 scale (1e-9) in every layer.

**Time**

1. Python `datetime` and pandas defaults.
2. **UTC int64 nanoseconds for every event time**, with `trading_date` and `session_id` derived from a calendar service.
3. Exchange-local timestamps.

## Decision outcome

**Chosen options: numbers 3 ("layered exact representation") and time 2 ("UTC int64 nanoseconds plus `CalendarPort`")**. They match the adopted engine, keep every money decision exact, and confine floating point to models whose outputs are rounded before booking.

### Representation per layer

| Layer | Prices, quantities, money | Time |
|---|---|---|
| Engine (NautilusTrader `Price`, `Quantity`, `Money`) | 128-bit raw, 16 decimals (the v2 default), with per-instrument `price_precision` and `size_precision` | `ts_event`, `ts_init`: UTC nanoseconds |
| Engine-agnostic domain (`tp_domain`, `tp_signals`, `tp_risk`) | `Decimal` quantized to the instrument's precision; never `float` | `*_ns` Python `int` |
| Market-data lake (Parquet) | int64 scaled by 1e-9 (DBN-compatible). An instrument whose precision exceeds 9 decimals, or whose values exceed about ±9.2 billion units, declares its own scale in the security master | `ts_event` (venue time) and `ts_recv` (our receipt time) as int64 UTC ns; bars also carry `trading_date` and `session_id` |
| Reference data and ledger (PostgreSQL) | `NUMERIC` quantized to the currency or instrument scale: an exact fixed-point decimal, never `real` or `double precision` | Event times as `*_ns BIGINT`; `trading_date` as `DATE`; administrative metadata (`valid_from`, `valid_to`, `known_at`, `ts_recorded`) as `TIMESTAMPTZ` |
| Wire and UI (Protobuf, JSON mapping first) | Decimal strings, or a scaled integer plus scale; never a JS `number` | int64 ns, which Protobuf's JSON mapping already encodes as strings; the UI parses them as `BigInt` and converts to milliseconds only for display |
| Models (pricing, greeks, IV, VaR) | float64 | Engine timestamps passed in |
| On-chain adapters | `uint256` smallest-unit integers, converted at the adapter boundary | Venue time converted to UTC ns |

### Rules

1. **Every conversion is explicit and rounded by a declared rule.** Rounding modes and minimum fees live in the rules pack ([ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.md)), never in code defaults. Float64 model outputs (for example QuantLib accrued interest or model marks) are rounded to the settlement convention before booking.
2. **Tick conformity is checked after rounding**, against the instrument's `tick_scheme_id`.
3. **Quantities are typed** with `quantity_unit` (`SHARE`, `BOARD_LOT`, `CONTRACT`, `FACE_VALUE`, `COIN`). Taiwan odd lots are a separate `instrument_id`.
4. **Bond prices** are stored as % of par in fixed-point decimal, with a codec that parses and displays 32nds.
5. **Lake to engine:** int64 1e-9 values convert to NautilusTrader's 16-decimal raw values by multiplying by 1e7, which is lossless when the instrument's precision is 9 or fewer decimals. Building the Nautilus catalog sets `ts_init = ts_recv`, or `ts_init = ts_event` when the vendor supplies no receipt time (for example end-of-day bars).
6. **Time:** strategy and risk code read only the engine clock. `datetime.now`, `time.time`, unseeded randomness and I/O are lint-banned in decision code. pandas calls pass `unit="ns"` explicitly. Hosts run chrony.
7. **Trading date and session** come only from `CalendarPort`. Whether TAIFEX night-session fills belong to the next trading date is unverified and is confirmed against TAIFEX rules in Phase 0.
8. **`TIMESTAMPTZ` columns are bookkeeping only.** They are never used to order or replay events.

**Wording amendments** to the [main report](../../README.md) (applied on 2026-10-05):

- Principle 3 now says "exact fixed-point values: per-instrument scaled integers in the engine and lake, and scale-quantized `NUMERIC`/`Decimal` in the ledger".
- Principle 4 now says "UTC int64 nanoseconds for every event time"; administrative timestamps may be `TIMESTAMPTZ`.

### Consequences

**Positive**

- Every decision and booking that touches money is exact and reproducible. P&L reconciles to the cent with broker statements.
- Interchange with NautilusTrader and Databento DBN is lossless for ordinary instruments.
- The wire format is safe for JavaScript, and nanosecond ordering survives all the way to the UI.
- Night sessions and the 24/7 crypto cut are handled by one service instead of ad-hoc date logic.

**Negative**

- There are several representations, so conversion bugs are possible. Property-based tests are mandatory.
- 128-bit fixed point is about 3–5% slower than the 64-bit mode. That is accepted.
- 16 decimals cannot hold wei, so DeFi amounts must stay as `uint256` at the adapter.
- `NUMERIC` is slower than integer columns. That is irrelevant at ledger volumes.
- The UI needs a decimal library and `BigInt` handling.

### Confirmation

- Property-based tests (Hypothesis): conversion round trips between lake, engine, `Decimal`, `NUMERIC` and wire strings; tick conformity after rounding; position equals the sum of fills.
- `tp_domain` enables the `decimal.FloatOperation` trap, so mixing `float` and `Decimal` raises an error.
- Lake schema checks reject float columns for prices and sizes at ingest.
- Wall-clock and I/O lint in CI; calendar tests for DST shifts, the TAIFEX night session, typhoon overrides and the crypto daily cut.

### Revisit when

- An off-chain instrument needs more than 16 decimals or more range than ±17 trillion.
- NautilusTrader changes its precision modes.
- Profiling shows the JSON mapping is a bottleneck. Then move to binary Protobuf with scaled integers.

## Links

- [Main report: design principles 3 and 4](../../README.md)
- [Recommended architecture §3.6, §4.1, §4.3, §5.3 and §5.5](../../architecture/recommended-architecture.md)
- [Evaluation record: concerns 14 and 16; grafts 31, 32 and 40](../../architecture/evaluation.md)
- Research: [01 Core language and runtime](../../research/01-core-language-runtime.md) · [03 Market data storage](../../research/03-market-data-storage.md) · [05 Instruments and pricing](../../research/05-instrument-model-pricing-analytics.md) · [06 Client UI](../../research/06-cross-platform-client-ui.md) · [07 Messaging](../../research/07-system-architecture-messaging.md)
- Related ADRs: [ADR-0004](ADR-0004-parquet-lake-for-historical-data.md) · [ADR-0007](ADR-0007-web-first-client-and-charting-stack.md) · [ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.md) · [ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.md)
