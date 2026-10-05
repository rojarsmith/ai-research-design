**English** | [繁體中文](ADR-0016-multi-currency-books-tax-lots-and-tax-plugins.zh-TW.md)

# ADR-0016: Multi-currency books, tax lots, withholding and jurisdiction tax plug-ins

## Status

**Proposed** · 2026-10-05 · Scope: scenario 1 (self-use), with the Taiwan-resident plug-in first. **This is engineering policy, not tax advice.** A tax adviser must confirm every rule before the plug-in's output is relied on for a filing, and every rate and threshold below is a snapshot to re-verify each tax year.

## Context and problem statement

The working assumption is an owner who is tax-resident in Taiwan and keeps books in TWD, while trading in USD at IBKR, in USDT or USDC on crypto venues and in TWD at a Taiwan broker. Until now the design said only "FX at event time; base currency TWD" and "tax lots through a jurisdiction plug-in (US wash sale only for US taxpayers)". `TaxLot` was referenced in the position model but never defined, no lot method was chosen, and withholding at source had no ledger event. Annual reporting is where a self-trader actually needs the ledger.

What matters for a Taiwan resident (research [08](../../research/08-risk-security-ops-compliance.md), [11](../../research/11-taiwan-market-localization.md); law texts checked on law.moj.gov.tw on 2026-10-05 where stated):

| Topic | What the plug-in must support |
|---|---|
| Overseas income (海外所得) | Under the Income Basic Tax Act (所得基本稅額條例) Art. 12, non-Taiwan-source income is added to basic income unless the household's total for the year is below NT$1 million. Art. 13 taxes basic income above a deduction at 20% (the statute's base is NT$6 million, indexed to CPI and announced yearly; confirm the amount for the tax year). Gains on US stocks held at IBKR and foreign dividends are the usual items |
| US dividends | 30% US withholding for a non-US person (Taiwan has no income-tax treaty with the US), with a W-8BEN on file at the broker. Payment in lieu on shorted US shares is a cost |
| Taiwan dividends | The taxpayer chooses between adding dividends to consolidated income with an 8.5% credit capped at NT$80,000 per household, or separate taxation at 28% (Income Tax Act Art. 15). The plug-in computes both |
| NHI supplementary premium (二代健保補充保險費) | Dividend income is subject to it (National Health Insurance Act Art. 31); payers withhold it on single payments at or above a threshold (NT$20,000 per payment under the implementing rules). The rate is announced by the authority (2.11% since 2021; confirm the current rate) |
| Taiwan-listed securities and futures | No income tax on gains for individuals; the transaction taxes are already in the rules packs ([ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.md)) |
| Crypto | No dedicated statute settles how an individual's crypto gains are classified; realized gains on offshore venues may count as overseas income. The plug-in reports realized gains per venue and leaves the classification to the adviser |
| FX | Year-end figures must be in TWD with a documented conversion rate. Funding offshore brokers is limited by the annual settlement allowance for individuals (US$5 million a year at a bank without approval; 外匯收支或交易申報辦法 Art. 4), which belongs to operations, not tax |

US taxpayers need wash-sale tracking and different reports; other residencies need their own plug-ins.

## Decision drivers

- The ledger is the single source for tax figures; no re-keying from broker PDFs.
- Realized P&L must reconcile with each broker's own figures, so the lot method must match the broker's.
- Reproducible: a report for a past year gives the same result when re-run.
- Pluggable by jurisdiction; nothing Taiwan-specific in the core.
- Cheap: lots in Phase 2a (about 0.2 PM), the Taiwan-resident plug-in in Phase 3c (about 0.3 PM).
- No claim of tax advice.

## Considered options

1. **Tax lots and withholding events in the ledger, plus jurisdiction plug-ins that produce annual summaries in the reporting currency.**
2. **Broker tax documents only** (IBKR annual statements and 1042-S, Taiwan broker statements), with no lots in the ledger.
3. **Export to a third-party portfolio-tax tool.**
4. **A full tax engine** that computes liabilities and fills in returns.

## Decision outcome

**Chosen option: 1.** It reuses events the ledger already records, keeps lots consistent with the brokers, and stops at summaries, so no liability is computed on the owner's behalf. Option 2 cannot combine brokers, venues and currencies into one TWD view; option 3 adds a data export of personal financial records; option 4 would be tax advice in software.

### Multi-currency books

- Cash is held **per currency**. Conversions are explicit `FxConversion` events with both legs, the rate, fees and the source; deposits, withdrawals and transfers are `CashTransfer` events with the remittance reference.
- Rates come from the `fx_rate` dataset ([recommended architecture](../../architecture/recommended-architecture.md) §3.1): Bank of Taiwan board rates, the Central Bank's NTD/USD closing rate, FRED H.10 and IBKR statement rates, each with a `license_tag`, `as_of_ns` and `known_at`. P&L uses the latest rate before the event; daily valuation and tax reports use the jurisdiction's declared rate rule; reconciliation uses the broker's rate.
- Stablecoins are instruments (positions marked against USD), not cash ([ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.md)).
- The scheduler sums `CashTransfer` settlements per calendar year and alerts at 80% of the annual settlement allowance.

### Tax lots

`TaxLot` is defined in §4.5 of the [recommended architecture](../../architecture/recommended-architecture.md):

| Field | Meaning |
|---|---|
| `acquired_ts_ns`, `acquired_trading_date` | When the lot was opened (fill, corporate action or transfer in) |
| `quantity_open`, `quantity_unit` | Signed remaining quantity; short lots are negative |
| `cost_total`, `currency` | Cost in the instrument's currency **including** commissions and fees |
| `fx_rate_to_base`, `fx_rate_ref`, `cost_total_base` | The rate at acquisition under the jurisdiction's rule, which `fx_rate` row it came from, and the TWD cost |
| `lot_method` | `FIFO` (default), `AVERAGE_COST` or `SPECIFIC_ID`, set **per account to match the broker** |
| `adjustments` | Corporate actions that changed the lot (splits, stock dividends, capital reductions) |
| `wash_sale_adjustment` | Only when the US-taxpayer plug-in is active |

Lots are opened and closed by ledger events (`TaxLotOpened`, `TaxLotClosed`), never edited. Corporate actions adjust lots through the same corporate-action events that adjust positions.

### Withholding and source deductions

`WithholdingTax` events record tax withheld at source (amount, currency, rate, jurisdiction, related dividend or interest event). The NHI supplementary premium withheld on Taiwan dividends is booked the same way with its own type. Payment in lieu, borrow fees and margin interest are separate cost events ([ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.md)).

### Jurisdiction plug-ins (`tp_tax`)

| Plug-in | Output |
|---|---|
| `tw_resident` (Phase 3c) | For a calendar year, in TWD with the rate rule stated: overseas income by type (realized gains per broker and venue, foreign dividends, interest) with the NT$1 million household test flagged; Taiwan dividends with both tax options computed; supplementary premiums withheld; foreign tax withheld; crypto realized gains per venue, unclassified; a reconciliation of realized P&L against each broker's annual statement |
| `us_taxpayer` (only if the owner is a US person) | Wash-sale adjustments, short- and long-term gains per lot |

Reports are bookkeeping aids. Each report states its rate sources, its lot methods and that it is not tax advice.

### Consequences

**Positive**

- One TWD view across brokers, venues and currencies, produced from the same ledger that reconciles daily.
- Lots that match each broker, so realized P&L can be checked line by line.
- The adviser gets complete, reproducible inputs instead of a pile of statements.
- Remittance limits and stablecoin exposure are visible before they become problems.

**Negative**

- Tax rules, thresholds and rates change; each needs a yearly check, like the rules packs.
- Matching the broker's lot method can differ from what a tax adviser prefers; the plug-in reports what the broker did.
- Crypto classification stays open, so the crypto section is raw data, not a conclusion.
- More event types to version forever in the ledger.

### Confirmation

- Property tests: the sum of open lots equals the position; closing a lot never changes another lot; FX conversions conserve value at the booked rate.
- Year-end test: realized P&L from lots matches each broker's annual figures within a stated tolerance.
- The plug-in's thresholds and rates live in a dated configuration with `verified_at`, checked yearly.

### Revisit when

- The owner's residency or US-person status changes, or a company entity starts trading.
- Taiwan legislates the tax treatment of crypto gains, or a US–Taiwan double-taxation arrangement takes effect and changes the withholding rate.
- **T1:** other users' tax reporting would be a regulated service in its own right; out of scope.

## Links

- [Main report: regulatory reminders (tax and FX) and the asset-class table](../../README.md)
- [Recommended architecture §3.1 (`fx_rate`), §3.6, §4.5 (`TaxLot`) and §6 (`tp_tax`)](../../architecture/recommended-architecture.md)
- Research: [08 Risk, security, operations and compliance](../../research/08-risk-security-ops-compliance.md) · [11 Taiwan localization](../../research/11-taiwan-market-localization.md) · [07 Portfolio and accounting](../../research/07-system-architecture-messaging.md)
- Related ADRs: [ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md) · [ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.md) · [ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.md) · [ADR-0015](ADR-0015-self-use-regulatory-posture-and-legal-gate.md)
