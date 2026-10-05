**English** | [繁體中文](08-risk-security-ops-compliance.zh-TW.md)

# Risk Management, Security, Operations & Compliance

> Dimension 08 · As of 2026-10-05 · Stocks, crypto, bonds, options; US/global, crypto venues, Taiwan (TWSE/TPEx/TAIFEX). Engineering research, not legal or tax advice.

## TL;DR

- **One mandatory, fail-closed risk gate** sits between every strategy and every execution adapter, identical in backtest, paper and live. Venue-native controls (dead-man timers, price bands, IP-bound keys) are a second layer; neither is enough alone.
- **Credentials are the crown jewels.** Use trade-only, IP-allow-listed keys with withdrawals disabled, held in the OS keychain (desktop) or OpenBao/cloud KMS (server), never in web or mobile clients. The 2025 Bybit theft (~US$1.5B, via the signing UI) and the npm "Shai-Hulud" worm (via dependencies) show where attacks land.
- **Size operations to the stage.** An MVP needs Docker Compose, Prometheus/Grafana/Loki (or Grafana Cloud free) and chrony. Kubernetes, multi-AZ, end-to-end OpenTelemetry and WORM archives pay off at team scale.
- **Regulation turns on self-use vs. serving others.** Self-use is mostly governed by broker rules (US intraday margin replaced PDT on 4 Jun 2026; Taiwan broker API agreements). Selling signals, copy-trading, managing money or holding crypto for others needs licences: RIA/CTA/broker-dealer (US), MiCA CASP (EU; transition ended 1 Jul 2026), an investment-advisory licence and, for crypto, the Virtual Asset Service Act (Taiwan; passed 30 Jun 2026, effective date pending).
- **Recommended path:** ship the MVP as a **self-use** tool, but design the audit journal, risk gate and tenant boundaries so a licensed or SaaS version needs no rewrite.

## Key questions

1. Where do pre-trade checks run, and does the system fail closed if the risk component itself fails?
2. How do we stop all trading on every venue within about 1 s, even if our own process is dead?
3. How do we prove, tamper-evidently and months later, which orders, fills and limit changes happened?
4. Where do API keys live on desktop, server, web and mobile, and what can an attacker do with a stolen one?
5. How much observability, HA and time-sync precision does each scenario need?
6. How do we test safely before real money is involved?
7. Which activities become regulated in the US, the EU, Taiwan and crypto?

## Options compared

### 1. Pre-trade risk: where the controls live

| Option | Examples | Added latency | Cross-venue view | Failure mode | Effort | Fit |
|---|---|---|---|---|---|---|
| A. Venue-native only | Broker order presets/precautionary settings, exchange price bands, Binance USDⓈ-M `countdownCancelAll` dead-man timer | 0 | No; differs per venue | Outside your control | Very low | Required baseline, never enough alone |
| B. Framework built-in engine | NautilusTrader `RiskEngine`: precision, max notional, reduce-only, submit/modify rate limits, `ACTIVE`/`REDUCING`/`HALTED` states; LEAN risk-management models | µs (in-process) | Yes, for every venue the framework supports | Shares fate with the strategy process | Low | Best MVP start if you adopt that framework |
| C. Custom in-process library | Your own OMS calls `risk.check(order)` synchronously before any adapter | µs | Yes | Fail-closed only if coded that way | Medium | MVP on a custom engine |
| D. Out-of-process risk gateway | A separate service owns order flow, positions and limits; strategies have no direct path to any venue | ~0.1–2 ms (IPC/gRPC) | Yes, plus multi-account aggregation | Isolated; can halt strategies independently | High | Multi-strategy, team or SaaS |
| E. Broker/vendor/hardware | Broker DMA risk layers, FPGA risk appliances, commercial OMS/EMS | ns–µs | Per broker | Regulated and audited | $$$ | Institutional. Broker-dealers with market access must maintain such pre-trade controls under SEC Rule 15c3-5 (the rule mandates the controls, not a specific product) |

**Minimum check set.** SEC 15c3-5 requires broker-dealers to apply credit/capital thresholds and block erroneous orders. EU RTS 6 (Reg. 2017/589) requires price collars, maximum order value and volume, message limits and kill functionality. Use both as checklists even when the system is self-use only:

| Check | MVP default (tune per instrument) | Notes |
|---|---|---|
| Max order qty / notional | e.g. ≤2% of equity per order, plus an absolute USD/TWD cap | Applies per instrument and per account |
| Fat-finger price collar | Reject limits more than k×ATR or X% from mid/last; block market orders on thin books | Also respect venue bands: US LULD, TWSE ±10% daily limit, intraday volatility interruption |
| Position / exposure limits | Per symbol, sector, gross/net and account; per-greek for options | Use broker-confirmed positions, not only internal state |
| Margin / buying power | Simulate post-trade margin and keep a 20–30% buffer | Models differ: Reg T 50% initial; FINRA intraday margin; futures exchange margin; crypto liquidation price |
| Order-rate throttle | Token bucket set below the venue's REST weight and WS message limits | Avoids bans and catches runaway loops |
| Duplicate / runaway detection | Same side, symbol and qty within N ms; caps on open orders and cancel/replace rate | The classic algo failure mode (Knight Capital, 2012) |
| Session / instrument state | Hours, halts, auctions, expiry day, restricted list | TAIFEX after-hours session; crypto is 24/7 |
| Loss circuit breaker | Daily loss limit → `REDUCING`; hard limit → `HALTED` + cancel-all | Manual reset requires a logged reason |

**Real-time risk layer**

| Measure | MVP | Institutional |
|---|---|---|
| P&L, drawdown, exposure | Real time, from fills and marks | Per desk/strategy/account, intraday |
| VaR / ES | Daily historical VaR/ES on 250–500 days of data | Intraday historical + Monte Carlo, with ES 97.5% as the primary metric |
| Greeks | Portfolio Δ/Γ/vega/θ from the broker or your own model | Spot × vol scenario grids; pin and early-assignment risk |
| Stress tests | Fixed shocks: index gap −10%, crypto ±30%, vol ×2, rates +100 bp | Historical replays (2008, Mar 2020, LUNA/FTX 2022) and reverse stress tests |
| Kill switch | Local hotkey, remote/mobile command and venue dead-man timer | Hierarchical (strategy → account → venue → firm), independent network path, four-eyes reset |

### 2. Post-trade reconciliation & tamper-evident audit

Reconcile at three cadences: **real time** (match every fill to its client order ID; an unknown execution switches the account to `REDUCING`), **intraday** (poll venue positions/balances every N minutes; drift beyond tolerance alerts and halts that account), and **end of day** (statements vs. ledger: fees, funding, corporate actions, exercise/assignment, coupons).

| Option | Tamper evidence | Cost / ops | Notes |
|---|---|---|---|
| PostgreSQL append-only journal + hash chain (each row stores the SHA-256 of the previous row; daily digest stored off-box) | Detects edits, provided the digests live elsewhere | Lowest; runs on the main DB | Revoke `UPDATE`/`DELETE` on the table. Best fit for the MVP |
| immudb 1.11.x (1.11.2, Sep 2026; PostgreSQL wire protocol since 1.0, with ORM/`pg_catalog` compatibility and SQL verification functions added in 1.11.0) | Built-in cryptographic verification | One more DB to run | **BSL 1.1** (from "1.9DOM.2", the version string exactly as written in the upstream LICENSE file; older releases were Apache-2.0), so it cannot be offered as a paid hosted/embedded product competing with Codenotary's; internal use is allowed |
| S3 Object Lock, compliance mode | WORM: even the root user cannot delete before retention expires (only closing the AWS account removes the objects); assessed by Cohasset for SEC 17a-4, CFTC and FINRA | Very cheap; batch-oriented | Archive tier for both scenarios |

Do not plan around **Amazon QLDB**: AWS discontinued it (end of support July 2025; its product page now redirects to Aurora). Managed alternatives are ledger tables in Azure SQL Database/SQL Server, or the Postgres hash chain above.

### 3. Secrets & key management

| Option | License / price (Oct 2026) | Strengths | Weaknesses | Fit |
|---|---|---|---|---|
| OS keychain (Windows Credential Manager/DPAPI, macOS Keychain, Linux Secret Service) via `keyring`-type libraries | Free | Bound to the user account; no server needed | Readable by malware running as that user; no audit trail | Desktop app, solo |
| SOPS + age (encrypted files in git) | OSS, free | Simple GitOps workflow | Static secrets; manual rotation | Solo/small server |
| **OpenBao 2.7** (2.7.1 released 1 Oct 2026) | **MPL-2.0**, Linux Foundation / OpenSSF | Vault-API compatible: dynamic secrets, transit encryption, audit devices | You operate it (unseal, HA, backups) | Self-hosted team or SaaS |
| HashiCorp Vault 2.x (2.1.1 released 16 Sep 2026) | **BSL 1.1**, licensor IBM; Enterprise/HCP paid | Mature; HSM and enterprise features | BSL prohibits offering Vault itself to third parties as a paid hosted/embedded product competing with IBM's; internal use (including behind your own trading SaaS) is permitted; cost | Enterprises wanting vendor support |
| Cloud secret manager + KMS/HSM | AWS Secrets Manager: $0.40/secret/month + $0.05 per 10k API calls | Managed; IAM and CloudTrail audit | Lock-in; does not help on desktop | Cloud-hosted servers |
| Infisical | MIT core + commercial `ee` | Good UX, secret sync, self-host or SaaS | Advanced features are paywalled | Small teams |

**Venue key hygiene (all scenarios).** One key per strategy or sub-account, trade + read only, withdrawals disabled, IP-bound (on Binance, unrestricted-IP HMAC keys are read-only and withdrawal permission requires an IP allow-list); prefer Ed25519 keys where offered. Rotate every 90 days and after any incident. Taiwan brokers authenticate with `.pfx` CA certificates, and some now add API-key login with IP restriction (Fubon Neo API, May 2026). Put a time-lock on withdrawal-address allow-lists, and use FIDO2 hardware keys on broker, exchange, cloud, GitHub and package-registry accounts.

**Client placement.** Web and mobile clients never hold venue keys; they are monitoring and kill-switch surfaces in front of a backend. For desktop-only self-use, decrypt keys from the OS keychain only inside the trading-core process, never in the UI/webview layer.

**Supply chain.** The Shai-Hulud npm worm compromised 500+ packages and stole GitHub, AWS, GCP and Azure credentials (CISA, 23 Sep 2025). A second wave ("Shai-Hulud 2.0", 24 Nov 2025) ran in the `preinstall` phase, trojanised ~700 packages and leaked secrets into 25,000+ GitHub repositories (Wiz); npm has since moved publishing to short-lived granular tokens, mandatory 2FA and trusted publishing. Mitigate with hash-pinned lockfiles, a 3–7 day adoption delay for new versions, trusted publishing, CycloneDX SBOMs, Sigstore-signed images with SLSA v1.2 provenance, signed desktop auto-updates, and build machines kept separate from key-holding machines.

**Crypto custody.** Keep only working capital on exchanges and the treasury in cold storage (hardware wallet or multisig; MPC or a qualified custodian for teams). Verify every transaction on the device screen, not in a web UI; the FBI attributed the Bybit theft to the DPRK "TraderTraitor" group. The trading system never holds withdrawal-capable keys.

### 4. Observability, HA/DR, deployment, time

| Option | License / cost | Strengths | Weaknesses | Fit |
|---|---|---|---|---|
| Self-hosted Prometheus 3.x (3.15.0; 3.13 is LTS) + Grafana + Loki 3.7 + Tempo, fed by an OpenTelemetry Collector | Prometheus Apache-2.0; Grafana/Loki/Tempo AGPL-3.0; infrastructure cost only | De-facto standard; no per-series billing | You run retention and HA | Default for team; also works for solo |
| Grafana Cloud | Free tier: 10k active series, 50 GB logs, 50 GB traces, 14-day retention, 3 users. Pro: from $19/month + usage | Zero ops | Short retention; data leaves your infrastructure | Solo MVP |
| Datadog / New Relic (commercial) | Priced per host/GB | Turnkey APM | Bills grow fast with high-cardinality trading metrics | Institutional with budget |

Other self-hosted options worth a look: VictoriaMetrics (Apache-2.0; a lighter, Prometheus-compatible store for long retention) and OTel-native stacks such as SigNoz (ClickHouse-based).

**OpenTelemetry maturity.** Traces and metrics are stable in most SDKs; logs are stable only in some (Go is at RC, Python/JS still in development); profiles are early. Use OTel for traces and metrics, and ship structured JSON logs to Loki through the Collector.

**Trading SLIs to alert on:** market-data staleness and sequence gaps, tick-to-order and order-ack latency, reject rate, position drift vs. venue, risk-gate denials, reconnects, missed dead-man heartbeats, clock offset. Page via ntfy/Pushover/Telegram/PagerDuty, with a runbook link on every alert.

**HA/DR.** Exactly **one writer per account**; never active-active against the same account. Run active-passive with a lease and fencing token (Kubernetes Lease/etcd or a Postgres advisory lock). A new leader reconciles open orders and positions from the venue before it trades. Deterministic client order IDs make retries idempotent. Targets: RPO ≈ 0 for the order journal (synchronous replica, venue as source of truth), RTO in minutes.

**Deployment.** MVP: Docker Compose on one static-IP VM. Team: Kubernetes on a supported minor (1.35–1.37; 1.34 reaches EOL 2026-10-27). Pick regions by measured RTT: AWS Tokyo (`ap-northeast-1`) for Binance-class crypto venues, US East for US brokers, and Taiwan for Taiwan brokers (AWS Taipei `ap-east-2`, opt-in, or GCP `asia-east1`). Check whether your Taiwan broker accepts API logins from cloud IPs.

**Time sync.** Run chrony against AWS's link-local `169.254.169.123`. Supported Gen7+ instance families in a `precision-time` placement group get an enhanced Stratum-1 NTP source and, on Linux only, a PTP hardware clock with microsecond accuracy, at no extra cost (Tokyo and a few other regions also keep legacy PHC access without the placement group). Windows instances must use the enhanced NTP source. Windows `w32time` is coarse, so desktop clients keep a per-venue server-time offset (for `recvWindow`) and measure latency with monotonic clocks. Benchmark: FINRA CAT requires industry members to stay within 50 ms of NIST (1 s for clocks used only for manual orders).

### 5. Testing strategy

| Layer | Tools | What it catches | MVP | Team |
|---|---|---|---|---|
| Unit | pytest / cargo test / xUnit | P&L, margin, tick/lot rounding | ✓ | ✓ |
| Property-based | Hypothesis, proptest, FsCheck | Invariants: position = Σ fills; the gate never passes an over-limit order; fill handling is idempotent | ✓ | ✓ |
| Deterministic historical replay | Recorded raw market data + order/fill events run through the **same** code path | Regressions, look-ahead bias, state-machine bugs | ✓ | Nightly CI |
| Simulated exchange | Matching simulator with latency, partial fills, rejects, rate-limit errors and disconnects; NautilusTrader sandbox | Order-lifecycle edge cases | Basic | Full |
| Venue sandboxes / paper | IBKR paper, Alpaca paper, Binance testnets, Taiwan broker simulation modes (e.g. Shioaji `simulation=True`) | API drift, permissions | ✓ | ✓ |
| Chaos / fault injection | Toxiproxy, Chaos Mesh/LitmusChaos, clock-skew injection, `kill -9` mid-order | Orphaned/duplicate orders, recovery paths | Manual drills | Scheduled game days |

**Go-live checklist**

- [ ] Limits configured, version-controlled and reviewed.
- [ ] Kill switch tested on every path (local, remote, venue dead-man). Revoking a key does **not** cancel resting orders.
- [ ] Keys trade-only, IP-bound, withdrawals disabled.
- [ ] Reconciliation green for 5+ consecutive sessions; 2–4 weeks of paper or tiny-size live with slippage compared to the backtest.
- [ ] Alert fire-drill and backup restore done; runbooks for disconnect, stuck order, halted symbol and broker outage.
- [ ] Capital ramps in steps (e.g. 10% → 25% → 100%) with exit criteria.

### 6. Regulation: self-use vs. serving others

| Activity | United States | EU | Taiwan |
|---|---|---|---|
| **Self-use**, own accounts via APIs | **No licence.** Broker rules apply. FINRA Rule 4210 intraday margin replaced the PDT rule and its $25k minimum, effective 4 Jun 2026, but brokers may phase in until **20 Oct 2027**, so support both regimes. Reg T: 50% initial margin. Wash sale (§1091) applies to stocks and options. Form 1099-DA broker reporting is in force (basis for digital assets acquired after 2025); its wash-sale reporting covers tokenized securities only. | Own-account dealing is generally exempt under MiFID II. Exceptions: HFT techniques, trading-venue membership or market making. | API orders count as electronic trading (電子式交易). You sign a risk disclosure/consent (風險預告書), pass a connection test and use a CA certificate. Brokers retain raw orders and your IP, and may suspend API access on abnormal orders. You may not authorise third parties. Day trading needs the 當沖 qualification. |
| **Selling signals, strategies or tools with recommendations** | **RIA** registration, unless the publisher's exclusion applies (impersonal, bona fide, of general and regular circulation). **CTA** registration for futures advice (CFTC 4.14 exemptions, e.g. ≤15 persons in 12 months without holding out to the public). | Investment advice under MiFID II; MAR rules on investment recommendations | Requires an advisory licence: 證券投資顧問事業 for securities (SITCA/投信投顧公會 membership), 期貨顧問事業 for futures (membership of the futures industry association 期貨公會, Futures Trading Act Art. 89). Unlicensed securities advisory: SITCA Act Art. 107, up to 5 years' imprisonment plus a fine of NT$1M–50M. Unlicensed futures advisory: Futures Trading Act Art. 112 (para. 5, item 5), up to 7 years plus an optional fine of up to NT$3M. |
| **Managing money / copy-trading / trading users' accounts** | RIA with discretion, possibly also a broker-dealer; CPO for pooled futures | MiFID portfolio-management licence, or the CASP equivalent for crypto | Discretionary-management licence (全權委託; 期貨經理事業 for futures). Broker API terms forbid third-party authorisation. |
| **Crypto services for others** (exchange, custody, transfer) | FinCEN MSB registration plus state licensing; Travel Rule | **MiCA CASP** authorisation. The transition ended **1 Jul 2026** (earlier in states that shortened it, e.g. 6 months in the Netherlands, Poland and Finland; 12 months in Germany and Ireland). A pending application is not an authorisation. TFR Travel Rule. | Today: AML registration; foreign platforms that are not registered may not solicit Taiwan users. **Virtual Asset Service Act** (虛擬資產服務法): passed 30 Jun 2026; 7 licence types; incumbents get 12 months to apply and 21 (+3) months to obtain; effective date to be set by the Executive Yuan; the FSC targets its ~9 implementing regulations by end-Q1 2027, and the first formal licences are expected around Q1 2028 (BlockTempo). Stablecoin issuance is limited to banks in Taiwan. **Travel Rule:** domestic transfers from Oct 2026, cross-border by end-2027, with extra data above NT$30,000. |
| **Redistributing market data (SaaS)** | Exchange/SIP distributor agreements; professional vs. non-professional fees; non-display fees | Exchange licences | TWSE/TAIFEX vendor contracts. Broker API terms forbid redistributing TAIFEX data without TAIFEX's written consent. |

**Global crypto.** FATF revised Recommendation 16 in June 2025, with an implementation deadline at the end of 2030. As of July 2026, 83% of surveyed jurisdictions had Travel Rule legislation, but only 40% of those had taken any supervisory action.

**Tax.** US wash-sale tracking matters only for US taxpayers, so make the tax-lot engine pluggable by jurisdiction.

### 7. How the four asset classes differ

| Dimension | Stocks | Crypto | Bonds | Options |
|---|---|---|---|---|
| Pre-trade specifics | LULD / TW ±10% limits; board lots (TW: 1,000 shares) vs. odd lots; short-sale rules (Reg SHO, TW 融券/借券) | Per-symbol tick, step and min-notional filters; leverage and liquidation price; withdrawals disabled | Price-vs-yield sanity checks; minimum denominations; RFQ quote staleness | Contract caps; post-trade greeks; premium-vs-intrinsic check; spread-width guard; options approval level |
| Real-time risk | Beta, sector concentration, overnight gaps | Venue/counterparty failure, stablecoin de-peg, cross-margin liquidation, auto-deleveraging (ADL) | DV01, duration/convexity, credit spread, liquidity | Δ/Γ/vega/θ, vol shocks, pin and early-assignment risk |
| Operations | Session hours (TW 09:00–13:30) | 24/7: on-call duty, venue maintenance windows | OTC/RFQ; thin APIs | Expiry cut-offs; TAIFEX night session |
| Reconciliation | Dividends, splits; T+1 (US) / T+2 (TW) | Funding payments, multi-coin fees, on-chain confirmations | Coupons, accrued interest | Exercise/assignment, multi-leg partial fills |
| Custody / security | Broker-held | **Keys are money**; exchange counterparty risk | Broker/bank-held | Broker-held |

## Recommendations (by scenario)

### (a) Solo / 1–3 person MVP (self-use)

1. **Risk gate.** Use framework option B or C as a mandatory in-process gate with fail-closed defaults, the full check set above, and three states: `ACTIVE`/`REDUCING`/`HALTED`. Keep limits in a YAML file under git; every change is logged.
2. **Kill switch on three paths:** desktop hotkey, mobile/Telegram command to the backend, and venue dead-man timers (e.g. Binance USDⓈ-M `countdownCancelAll` heartbeat, which works per symbol, so arm it for every traded symbol; cancel-on-disconnect where available).
3. **Keys.** Trade-only, withdrawals disabled, IP-bound to one static VPS. Store them in the OS keychain (desktop) and in SOPS+age or a cloud secret manager (server). Use FIDO2 on every account.
4. **Audit.** A Postgres append-only hash-chained journal, plus a nightly export to S3 Object Lock. Run automated real-time, intraday and EOD reconciliation.
5. **Operations.** Docker Compose, Grafana Cloud free tier or self-hosted Prometheus/Grafana/Loki, chrony, and an AWS Tokyo VM for crypto. Use broker-proximate hosting or a home server for Taiwan brokers.
6. **Testing.** Property-based tests on risk invariants, deterministic replay in CI, venue paper/testnet, then a 2–4 week small-size live ramp.
7. **Compliance.** Stay self-use. Do not sell signals, run copy-trading or hold others' keys until you have legal advice for each jurisdiction.

### (b) 5–20 person team / institutional grade

1. **Risk gateway (option D)** as a separate service, plus a real-time risk service: intraday VaR/ES, greek grids, stress library, hierarchical kill switch. Limit changes require four-eyes approval, and the controls should be mapped to SEC 15c3-5 and EU RTS 6.
2. **Secrets.** OpenBao (MPL-2.0) or Vault Enterprise/cloud KMS backed by an HSM, with dynamic DB credentials, audit devices and automated rotation. Crypto treasury goes to MPC or a qualified custodian.
3. **Supply chain.** SLSA v1.2 provenance, signed images, SBOM, a dependency cooldown window, OpenSSF Scorecard gates, and separate CI identities.
4. **Platform.** Kubernetes on a supported minor (1.35+), multi-AZ, active-passive per account with fencing, a documented DR region, and quarterly restore and game-day drills.
5. **Observability.** End-to-end OpenTelemetry, trading SLOs, on-call rotation, post-mortems.
6. **Audit.** WORM retention aligned with SEC 17a-4/CFTC record-keeping if you become regulated; immudb (check its BSL terms) or a hash-chained journal with external anchoring.
7. **Compliance programme:** licensing roadmap (RIA/CTA; MiCA CASP; Taiwan advisory licence and VASP licence once the Act takes effect), Travel Rule vendor, market-data distributor agreements, SOC 2 / ISO 27001, and DORA if serving EU financial entities.

## Impact on overall architecture

- **The risk gate is a hard choke point** between the strategy runtime and the execution adapters, and backtest, paper and live share the same code. Adapters must expose venue rate limits, dead-man primitives and position snapshots.
- **Event-sourced order/fill journal** with client order IDs as idempotency keys. It feeds the risk, reconciliation, P&L and audit components.
- **Split the control plane from the trading plane.** UIs (desktop, web, mobile) issue commands such as halt, change limits or deploy a strategy. Only the trading core holds venue credentials.
- **Model accounts and tenants explicitly from day one** (owner, venue, key ID, limits). Converting to SaaS later is then mostly a licensing problem, not a rewrite.
- **The kill switch has its own path,** a minimal separate process and credentials, so it keeps working when the main engine is wedged.
- **Asset-class plug-ins** provide margin models, greek/DV01 calculators, session calendars and reconciliation rules.

## Risks & pitfalls

- **Fail-open risk gate:** an exception inside a check must never let the order through.
- **Internal state treated as truth:** after any reconnect or failover, venue positions win.
- **Revoking a key mid-incident:** resting orders stay live; cancel first.
- **Silent rule drift:** the US intraday-margin phase-in runs to Oct 2027, Taiwan brokers revise API terms, crypto venues change filters and rate limits.
- **License traps:** BSL products (Vault, immudb) may not be offered to third parties as a paid hosted or embedded product that competes with the vendor's paid versions; using them internally behind your own trading SaaS is allowed. Modifying and serving AGPL Grafana/Loki/Tempo to users over a network triggers AGPL obligations.
- **Accidental advisory activity:** a free Discord channel that becomes a paid signal service needs a licence in Taiwan and the US.
- **Market-data redistribution:** showing exchange data to SaaS users needs exchange/vendor contracts and fees.
- **Desktop malware:** a keychain does not stop code running as the same user; use a dedicated trading machine or VM.
- **24/7 crypto, one operator:** without paging and auto-flatten rules, a weekend incident runs unattended for hours.

## References

- FINRA Regulatory Notice 26-10 (intraday margin replaces PDT): https://www.finra.org/sites/default/files/2026-04/Regulatory-Notice-26-10.pdf
- ACA Group, FINRA ends PDT rule (dates, phase-in): https://www.acaglobal.com/industry-insights/finra-ends-the-pattern-day-trader-rule/
- FINRA Regulatory Notice 26-11 (Rule 4210 interpretations): https://www.finra.org/rules-guidance/notices/26-11
- Regulation T §220.12: https://www.law.cornell.edu/cfr/text/12/220.12
- IRC §1091 wash sales: https://www.law.cornell.edu/uscode/text/26/1091
- IRS Instructions for Form 1099-DA: https://www.irs.gov/instructions/i1099da
- SEC Rule 15c3-5 (market access): https://www.sec.gov/rules-regulations/2011/06/risk-management-controls-brokers-or-dealers-market-access
- FINRA market access topic: https://www.finra.org/rules-guidance/key-topics/market-access
- EU RTS 6, Commission Delegated Regulation 2017/589: https://eur-lex.europa.eu/eli/reg_del/2017/589/oj
- FINRA Rule 6820 (CAT clock synchronisation): https://www.finra.org/rules-guidance/rulebooks/finra-rules/6820
- Seeking Alpha publisher-exclusion ruling (Greenberg Traurig): https://www.gtlaw.com/ja/insights/2024/8/no-need-for-seeking-alpha-to-seek-registration
- NFA, CTA registration: https://www.nfa.futures.org/registration-membership/who-has-to-register/cta.html
- ESMA MiCA page: https://www.esma.europa.eu/esmas-activities/digital-finance-and-innovation/markets-crypto-assets-regulation-mica
- AGP Law, MiCA transition ends 1 Jul 2026: https://www.agplaw.com/?p=32785
- ESMA, list of MiCA grandfathering periods by member state: https://www.esma.europa.eu/sites/default/files/2024-12/List_of_MiCA_grandfathering_periods_art._143_3.pdf
- EU Transfer of Funds Regulation 2023/1113: https://eur-lex.europa.eu/eli/reg/2023/1113/oj
- FATF Seventh Targeted Update on VAs/VASPs (Jul 2026): https://www.fatf-gafi.org/en/publications/Fatfrecommendations/targeted-updated-virtualassets-vasps-2026.html
- FATF R.16 revision (Jun 2025): https://www.regulationtomorrow.com/2025/06/fatf-updates-travel-rule/
- Lee and Li, Taiwan Virtual Asset Service Act: https://www.leeandli.com/EN/NewslettersDetail/7658.htm
- BlockTempo, VASP Act third-reading explainer: https://www.blocktempo.com/taiwan-virtual-asset-act-third-reading-explainer-vasp-stablecoin-licensing/
- Agbrief, Taiwan passes virtual asset law: https://agbrief.com/news/taiwan/30/06/2026/taiwan-passes-first-virtual-asset-law-mandates-license-for-exchanges/
- Cointelegraph, Taiwan Travel Rule (Oct 2026 / end-2027): https://cointelegraph.com/news/taiwan-crypto-travel-rule-domestic-vasp-transfers
- The Block, Taiwan restricts unregistered offshore exchanges: https://www.theblock.co/post/252915/taiwan-releases-guidelines-for-crypto-exchanges-restricts-offshore-exchanges-unless-compliant
- Securities Investment Trust and Consulting Act Art. 107: https://law.moj.gov.tw/LawClass/LawSingle.aspx?pcode=G0400121&flno=107
- Futures Trading Act Art. 112 (unlicensed futures advisory): https://law.moj.gov.tw/LawClass/LawSingle.aspx?pcode=G0400100&flno=112
- Futures Trading Act Art. 89 (association membership): https://law.moj.gov.tw/LawClass/LawSingle.aspx?pcode=G0400100&flno=89
- Taiwan API trading overview (電子式交易, broker controls): https://ctyeh.com/finance/15093
- SinoPac futures API risk disclosure/consent: https://www.sinotrade.com.tw/newweb/signCenter/F_openApi/
- Fubon Neo API key login and IP restriction (May 2026): https://www.taiwannews.com.tw/zh/news/6359399
- CTA plan (SIP market-data pricing): https://www.ctaplan.com/
- Binance API key types and IP/withdrawal rules: https://www.binance.com/en/support/faq/how-to-create-api-keys-on-binance-360002502072
- Binance Futures auto-cancel (dead-man): https://developers.binance.com/docs/derivatives/usds-margined-futures/trade/rest-api/Auto-Cancel-All-Open-Orders
- NautilusTrader execution/RiskEngine: https://nautilustrader.io/docs/latest/concepts/execution/
- OpenBao releases: https://github.com/openbao/openbao/releases
- OpenBao repository (license, governance): https://github.com/openbao/openbao
- HashiCorp Vault releases: https://github.com/hashicorp/vault/releases
- HashiCorp Vault LICENSE (BSL 1.1, IBM): https://github.com/hashicorp/vault/blob/main/LICENSE
- Infisical repository: https://github.com/Infisical/infisical
- AWS Secrets Manager pricing: https://aws.amazon.com/secrets-manager/pricing/
- immudb releases: https://github.com/codenotary/immudb/releases
- immudb LICENSE (BSL 1.1): https://github.com/codenotary/immudb/blob/master/LICENSE
- immudb v1.11.0 release notes (PostgreSQL/ORM compatibility): https://github.com/codenotary/immudb/releases/tag/v1.11.0
- Amazon S3 Object Lock: https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock.html
- FBI PSA on the Bybit theft: https://www.ic3.gov/PSA/2025/PSA250226
- CISA alert, npm Shai-Hulud: https://www.cisa.gov/news-events/alerts/2025/09/23/widespread-supply-chain-compromise-impacting-npm-ecosystem
- Wiz, Shai-Hulud 2.0 (Nov 2025): https://www.wiz.io/blog/shai-hulud-2-0-ongoing-supply-chain-attack
- GitHub, plan for a more secure npm supply chain: https://github.blog/security/supply-chain-security/our-plan-for-a-more-secure-npm-supply-chain/
- SLSA specification: https://slsa.dev/spec/
- Prometheus releases: https://github.com/prometheus/prometheus/releases
- Prometheus release cycle (LTS 3.13, supported to 31 Jul 2027): https://prometheus.io/docs/introduction/release-cycle/
- Grafana Loki releases: https://github.com/grafana/loki/releases
- Grafana Cloud pricing: https://grafana.com/pricing/
- OpenTelemetry status: https://opentelemetry.io/status/
- Kubernetes releases: https://kubernetes.io/releases/
- AWS Regions list: https://docs.aws.amazon.com/global-infrastructure/latest/regions/aws-regions.html
- Amazon Time Sync Service / PTP hardware clock: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configure-ec2-ntp.html

## Verification log (2026-10)

Adversarial fact-check run on 2026-10-05 against primary sources (regulator notices, statutes, GitHub releases and LICENSE files, vendor pricing and docs).

**Confirmed**

1. FINRA Regulatory Notice 26-10 (20 Apr 2026): intraday margin standards under Rule 4210 replace the PDT designation and the $25,000 minimum; effective 4 Jun 2026; optional 18-month phase-in to 20 Oct 2027 (notice PDF; ACA Group). Notice 26-11 (19 May 2026) published the interpretations.
2. Taiwan Virtual Asset Service Act passed 30 Jun 2026; 7 VASP categories; incumbents have 12 months to apply and 21 months (extendable once by 3) to be licensed; the Executive Yuan sets the effective date (Lee and Li; BlockTempo).
3. Taiwan Travel Rule: domestic VASP-to-VASP transfers from Oct 2026, international by end-2027, extra originator data above NT$30,000 (Cointelegraph, 5 Aug 2026).
4. MiCA grandfathering ended 1 Jul 2026; unauthorised CASPs must wind down EU business; a pending application is not an authorisation (AGP Law, 30 Jun 2026; ESMA). Shorter national periods confirmed from ESMA's list.
5. SITCA Act Art. 107: up to 5 years' imprisonment plus a fine of NT$1M–50M for unapproved advisory business (law.moj.gov.tw).
6. OpenBao: MPL-2.0, governed under OpenSSF (Linux Foundation); v2.7.0 on 23 Sep 2026, v2.7.1 on 1 Oct 2026 (GitHub releases).
7. HashiCorp Vault: BSL 1.1 with IBM as licensor; v2.1.1 on 16 Sep 2026 (GitHub LICENSE and releases).
8. immudb: BSL 1.1 (Codenotary as licensor); latest release v1.11.2 on 3 Sep 2026 (GitHub).
9. Binance: unrestricted-IP HMAC keys are read-only; an IPv4 allow-list is mandatory for withdrawal permission (Binance FAQ).
10. CISA alert of 23 Sep 2025: Shai-Hulud compromised 500+ npm packages and targeted GitHub PATs and AWS/GCP/Azure keys.
11. Grafana Cloud free tier: 10k active series, 50 GB logs, 50 GB traces, 14-day retention, 3 active users; Pro from $19/month plus usage (grafana.com/pricing).
12. Amazon Time Sync Service: `169.254.169.123`; `precision-time` placement groups on supported Gen7+ families give microsecond-accurate PHC, in all commercial regions at no extra cost (AWS docs).
13. IRS Form 1099-DA: basis reporting for digital assets acquired after 2025; wash-sale reporting only for tokenized securities (IRS instructions).
14. FINRA Rule 6820: 50 ms tolerance to NIST (1 s for manual-order clocks).
15. Bybit theft of about US$1.5B on 21 Feb 2025, attributed by the FBI to DPRK "TraderTraitor" (IC3 PSA250226).
16. NautilusTrader `RiskEngine` checks (precision, notional, reduce-only, submit/modify rate limits) and `ACTIVE`/`REDUCING`/`HALTED` states (docs).
17. Binance USDⓈ-M `POST /fapi/v1/countdownCancelAll` dead-man timer (Binance developer docs).
18. AWS Secrets Manager: $0.40 per secret per month and $0.05 per 10k API calls.
19. Infisical: MIT outside `ee/`, commercial licence inside `ee/` (GitHub LICENSE).
20. Prometheus 3.15.0 (25 Sep 2026) is the latest release; 3.13 is the current LTS, supported to 31 Jul 2027. Loki is at 3.7.x (3.7.8). Prometheus is Apache-2.0; Grafana, Loki and Tempo are AGPL-3.0.
21. OpenTelemetry status: logs are stable in Java, .NET and C++; Go logs are at release candidate; Python and JS logs are in development; Rust is beta.
22. Kubernetes 1.35, 1.36 and 1.37 are maintained; 1.34 reaches EOL on 2026-10-27.
23. SLSA v1.2 is the current approved specification.
24. AWS Asia Pacific (Taipei) is `ap-east-2` and is opt-in.
25. S3 Object Lock compliance mode: not even the root user can delete; Cohasset assessment for SEC 17a-4, CFTC and FINRA.
26. Fubon Neo API: API-key login with IP restriction (Taiwan News, 11 May 2026).
27. FSC 2023 guidelines: unregistered offshore VASPs may not solicit Taiwan users (The Block).
28. Seeking Alpha publisher's-exclusion ruling (S.D.N.Y., Aug 2024; Greenberg Traurig).
29. GitHub's npm hardening plan (22 Sep 2025): 2FA-only local publishing, 7-day granular tokens, trusted publishing.

**Corrected**

- immudb "PostgreSQL compatibility since 1.11.0" → the PostgreSQL wire protocol has existed since v1.0; v1.11.0 added ORM (`pg_catalog`/`information_schema`) compatibility and SQL verification functions. Source: immudb v1.0.0 and v1.11.0 release notes.
- Taiwan futures advisory listed under "SITCA/投信投顧公會 membership", with Art. 107 implied as the only penalty → futures advisers must join the futures industry association (Futures Trading Act Art. 89). Unlicensed futures advisory is punished under Futures Trading Act Art. 112 (up to 7 years, plus an optional fine of up to NT$3M). Source: law.moj.gov.tw (G0400100).
- VASP Act "effective date expected in 2027" → the FSC targets its ~9 implementing regulations by end-Q1 2027, and the first formal licences are expected around Q1 2028. Source: BlockTempo.
- BSL summary ("cannot back a competing hosted offering") → the restriction covers offering the product itself to third parties as a *paid* hosted or embedded product that competes with the vendor's paid versions. Internal use, including behind your own SaaS, is permitted. Source: Vault and immudb LICENSE files.
- Time sync "Gen7+ instances get a PTP hardware clock" → only listed Gen7+ families get it, and the PHC is Linux-only; Windows uses the enhanced NTP source. Source: AWS EC2 User Guide.
- SEC 15c3-5 "must run these [FPGA/vendor appliances]" → the rule mandates risk controls, not a particular product. Source: SEC Rule 15c3-5.

**Added (missing or stale context)**

- Shai-Hulud 2.0 (24 Nov 2025; ~700 packages, 25,000+ repos; Wiz).
- Amazon QLDB discontinued, so do not plan around it; ledger-table alternatives listed.
- VictoriaMetrics/SigNoz as self-hosted observability alternatives.
- Binance `countdownCancelAll` is per symbol.
- National MiCA grandfathering periods (ESMA list).

**Unverifiable (left as is, or flagged)**

- FATF July 2026 targeted update figures (83% with Travel Rule legislation; 40% of those with supervisory action): the FATF site sits behind a bot challenge, so the figures could not be fetched.
- FATF revised R.16 (June 2025) end-2030 implementation deadline: the cited source returned HTTP 403.
- Exact Amazon QLDB end-of-support date (July 2025): discontinuation is evidenced by the product page redirecting to Aurora and the developer guide returning 404, but the date itself was not fetched from an AWS notice.
- Taiwan broker API agreement details (ctyeh.com overview, SinoPac consent page) and the Shioaji `simulation=True` mode were not re-checked in this pass.
