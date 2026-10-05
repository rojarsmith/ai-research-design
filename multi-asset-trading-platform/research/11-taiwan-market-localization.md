**English** | [繁體中文](11-taiwan-market-localization.zh-TW.md)

# Taiwan Market Connectivity & Localization

*Research dimension 11 for the multi-asset (stocks, crypto, bonds, options) analysis, backtesting and trading platform. Scope: Taiwan equities (TWSE/TPEx), TAIFEX futures and options, Taiwan bond access, and Taiwan crypto venues. Facts verified as of 2026-10-05. Related: [02 Backtesting engine](02-backtesting-engine.md).*

## TL;DR

- **The "Taiwan broker APIs are Windows-only" problem now applies mainly to second-tier APIs.** Three major brokers support Linux:
  - SinoPac **Shioaji** (version 1.7.7, released 2026-09-29) ships wheels for Linux, macOS and Windows. It has a Rust core and a local HTTP + SSE server, so non-Python services can use it too.
  - **Fubon Neo** supports Python, C# and Node.js on Windows, macOS and Linux. C++ and Go cover securities only. Since SDK v2.2.8 the certificate can be exported from a web portal, so no Windows tool is needed to get it.
  - **Yuanta SPARK** is built on .NET 8 and runs on Linux x64.

  Capital (群益) SKCOM and KGI `kgiapp` are still Windows COM / .NET Framework. Plan the Windows gateway as an **optional plug-in**, not as the core design.
- **Start with Shioaji as the primary Taiwan broker and add Fubon Neo as the second one.** Shioaji has a mandatory simulation environment, fine-grained API keys, published rate limits and a 14-day release cycle. Fubon adds DMA/IDC options and Fugle-quality market data. Add Capital (through a Windows gateway) only when you need overseas futures or sub-brokerage (複委託) order routing.
- **The free official OpenAPIs only cover end-of-day and reference data.** TWSE has 143 endpoints, TPEx 225 and TAIFEX 135. Real-time data comes from the broker or Fugle (NT$1,499–2,999/month). Historical ticks come from FinMind's paid tiers (good enough for research) or from the TWSE Data E-Shop (authoritative, from NT$5,000 per data-month for the 5-level book).
- **Taiwan needs its own rules pack in the backtester and in the risk engine.** It must cover:
  - ±10% price limits, open and close call auctions, and the 3.5% volatility interruption;
  - 5-second odd-lot auctions;
  - disposition stocks (處置股) and suspension of sell-first day trading;
  - the 0.3%/0.15% securities transaction tax (證交稅) and the futures transaction tax (期交稅), plus the bond and bond-ETF tax holiday that ends on 2026-12-31 unless it is extended;
  - night-session trading dates;
  - weekly TXO options expiring on Wednesday or Friday.
- **Bonds and crypto mostly fall outside broker APIs.** For retail investors, Taiwan bond exposure in practice means bond ETFs, plus sub-brokerage or bank OTC bonds that have no API. Crypto TWD venues (MAX, BitoPro) have solid REST and WebSocket APIs. However, the **Virtual Asset Service Act (虛擬資產服務法) passed on 2026-06-30** and takes effect in Q1 2027 at the earliest. Venue eligibility therefore has to be configuration, not code.

## Key questions

1. Which Taiwan brokers can be driven from a Linux/containerized core, and which need a Windows host?
2. Which data sources provide real-time, historical tick and reference data for TWSE/TPEx/TAIFEX, and what do they cost?
3. Which Taiwan market rules must the backtester and the pre-trade risk checks model to avoid fake P&L?
4. What can a Taiwan retail investor actually trade in bonds, and through what channel?
5. Which Taiwan crypto venues have usable APIs, and how does the 2026 VASP Act change counterparty risk?
6. How should certificates, API keys, IP allow-lists and per-person credentials be handled, both for self-use and if the platform later serves other people?

## Options compared

### 1. Taiwan broker trading APIs

| Broker / API | Languages | OS | Products | Onboarding & auth | Simulation | Limits / maintenance signal |
|---|---|---|---|---|---|---|
| **SinoPac Shioaji (永豐)** | Python native binding over a Rust core. Any language through the local HTTP API (`localhost:8080`, OpenAPI docs, SSE streaming) and a CLI | Windows x64, macOS x64/ARM64, Linux x64/ARM64 (glibc wheels). Python 3.7–3.14 | TW stocks (incl. intraday odd lot), futures, options, combo orders | Account, then e-sign the stock and futures API terms, then pass **mandatory simulation tests** (login and orders). API key with permission scopes, expiry and an **IP allow-list**. CA `.pfx` can be downloaded from the cross-platform portal; `activate_ca()` | Yes (`simulation=True`). No odd-lot or emerging-stock orders | 50 data calls/10 s; 25 account queries/5 s; 250 order operations/10 s; 200 subscriptions; 5 concurrent sessions per person ID; 1,000 logins/day. Going over a rate limit suspends the service for 1 minute. Daily traffic cap of 500 MB–10 GB that scales with your trading volume (resets 08:00). **v1.7.7 on 2026-09-29, 14-day release cycle**. 1.7.6 was yanked, and a 1.5.x line still got a patch on 2026-08-13, so pin exact versions |
| **Fubon Neo (富邦新一代 API)**, built with Fugle | Python 3.8–3.13, C# (.NET Standard 2.0), Node.js ≥16. C++ and Go cover securities trading, accounts and conditional orders only | Windows, macOS, Linux SDKs (Python and C#: x86-64, plus ARM64 on macOS and Linux). Since SDK v2.2.8 the certificate can be **exported from the web key-management portal** for cross-platform use, so the Windows-only TCEM.exe is no longer the only path. The connection-test helper is still distributed for Windows | TW stocks (incl. margin), futures/options, conditional orders. Market data through a Fugle-built Web API and WebSocket | Account, online risk disclosure, certificate, connection test. **API-key login (SDK ≥ v2.2.7) with an IP allow-list, validity period, per-scope permissions and up to 30 keys** (announced 2026-05) | **Test environment available** (downloadable test-environment package; currently securities test accounts only), plus the mandatory connection test | Trading: 50 orders/s, 10 batch orders/s, 5 account queries/s, at most 10 connections. Market data: 300/min intraday, 60/min historical. WebSocket: 300 subscriptions × 7 connections. DMA/IDC routing (2025-07). Go added 2026-05. SDK v2.4.0 |
| **Yuanta SPARK API (元大)** | C# and Python (through `pythonnet` on .NET 8). COM, Delphi and WPF components are maintenance-only | Windows x64/x86, macOS ARM64/x64, Linux x64 | TW stocks, domestic futures, cloud conditional orders, quotes | Risk disclosure, then an API test with upload, then component download. Separate test and production certificates | **UAT environment** (needs a fixed-IP firewall approval from your account manager) | Rate limits not public. New features ship only for Python and C# |
| **Capital SKCOM (群益)**, CapitalAPI 2.13.x | C#, C++, VB, Python through COM | **Windows only**. COM DLL registration; the process bitness must match the DLL | TW stocks, TAIFEX futures/options, **overseas futures, overseas stocks (複委託)** | Sign the API declaration in the app or on the website, then use a certificate | Not documented publicly | Widest product coverage. Large community, many samples |
| **KGI `kgiapp` (凱基)** | Python wrapper over .NET Framework 4.5 | **Windows only** | Stocks / futures | Set up through a branch sales representative | n/a | PyPI 2.0.4 is the latest; **last upload 2024-11-17**. Community reports poor documentation |
| Others: Cathay (國泰), Mega (兆豐), President Futures (統一期貨), Taishin (台新, which absorbed Masterlink 元富 on 2026-04-06), etc. | Mostly DLL/COM. Masterlink's API (built by Fugle, 2025-01) offered Python, Node.js and C#. Check that it continues unchanged under Taishin after the merger | Mostly Windows (third-party order tools list them only as Windows 32/64-bit). The ex-Masterlink API is cross-platform | Mostly futures-centric | Certificate plus a separate API application | Varies | Use only when the account already exists at that broker |

API trading is growing quickly. Market-wide API turnover had reached NT$63.6 billion as of October 2024, against NT$50.6 billion in 2023, an increase of 26% (cnyes, 2025-01-03). The article does not say whether this is a daily average or a period total.

### 2. Market data sources

| Source | Content | Real-time? | Cost (2026) | Fit |
|---|---|---|---|---|
| **TWSE OpenAPI** (`openapi.twse.com.tw/v1`) | 143 endpoints. Daily quotes, P/E, margin balances, odd-lot quotes, day-trade eligibility (TWTB4U), sell-first suspensions (TWTBAU1), disposition and notice stocks, holiday schedule, financial statements, ESG | No (end-of-day / periodic) | Free, no auth | Reference data and calendars |
| **TPEx OpenAPI** (`tpex.org.tw/openapi/v1`) | 225 endpoints. OTC quotes, odd lots, day-trade lists, **bond issuance (government, corporate, financial, international/Formosa)**, international-bond intraday quotes | No | Free | OTC stocks and bond reference data |
| **TAIFEX OpenAPI** (`openapi.taifex.com.tw/v1`) | 135 endpoints. Daily futures/options reports, **daily time & sales (TimeAndSalesData, OptionsTimeAndSalesData)**, institutional and large-trader open interest, margins, final settlement prices, position limits | No | Free | Derivatives end-of-day data and daily ticks |
| **Broker feeds** (Shioaji, Fubon/Fugle) | Real-time ticks and bid/ask, intraday k-bars, snapshots | Yes | Free with the account. Volume-tiered caps | Live trading. Redistribution is not allowed |
| **Fugle MarketData** | TW listed, OTC and emerging stocks, indices, ETFs/ETNs, warrants; futures/options history. Stock daily bars from 2010 (indices from 2015); **stock minute bars only from 2023-05-23**; futures daily bars from 2010 and minute bars from 2017-06 | Yes (WebSocket) | Free (5 subscriptions) / Developer NT$1,499/mo (300 subs, 600 calls/min) / Advanced NT$2,999/mo (2,000 subs). Client `fugle-marketdata` 2.7.0 (MIT, 2026-09-30) | Broker-independent real-time feed |
| **FinMind** | 50+ datasets. **Stock ticks from 2018-12-07; futures/options ticks from 2011-01-03**; stock k-bars from 2019 | No | 600 requests/h with a free token. Tick data needs the backer/sponsor tiers; SponsorPro adds full-day Parquet downloads. Client 2.0.11 (Apache-2.0, 2026-10-04) | Cheap research history |
| **TEJ** | Institutional fundamentals and adjusted prices. TQuant Lab (`zipline-tej` 2.2.2, Apache-2.0, 2025-11-25) | No | Paid subscription (priced on request) | Point-in-time fundamentals, team grade |
| **TWSE Data E-Shop** | 15+ years of full-market history. **Intraday data with the 5-level book NT$5,000/month**; order-book log NT$10,000; intraday data with order type NT$10,000; intraday odd-lot data NT$1,500 | No (historical) | Priced per data-month | Authoritative L2 for execution research |
| **XQ (嘉實) / CMoney** | Closed retail terminals with scripting (XScript) and chip data (籌碼) | Yes, inside the terminal | Retail subscriptions | Idea prototyping only. Not an integration backbone |

### 3. Market rules and what they mean for the engine

| Rule (verified source in References) | Backtest engine implication | Pre-trade risk check |
|---|---|---|
| Sessions: orders from 08:30; **opening call auction**; continuous trading 09:00–13:25 (since March 2020); **closing call auction 13:25–13:30**. Fixed-price after-hours session 14:00–14:30 | Fill opens and closes at the auction price, not the first or last tick. Model the sessions separately | Block market orders during the auction phases where they are not allowed |
| **±10% daily price limit** (IPOs have no limit for their first 5 days; corporate bonds ±5%; government bonds no limit) | Limit-locked days are untradeable. Queue-position fills at the limit price are rarely available, so do not assume fills | Reject orders priced outside the limit band |
| **Intraday volatility interruption**: a price more than 3.5% away from the 5-minute average triggers a 2-minute halt and then a call auction | Delay fills and re-auction; leftover market, IOC and FOK orders are cancelled | Warn about market orders in volatile names |
| Tick sizes: stocks 0.01 / 0.05 / 0.10 / 0.50 / 1 / 5 at price breaks of 10 / 50 / 100 / 500 / 1,000. ETFs use 0.01 below NT$50 and 0.05 above | Round prices to the instrument-class tick table | Validate tick conformity |
| Board lot = 1,000 shares. **Intraday odd lots**: 09:00–13:30, first auction at 09:10, then **periodic call auctions every 5 seconds**. After-hours odd lots: 13:40–14:30 | Separate odd-lot order book. Do not fill odd lots at board-lot prices | Treat quantity unit (lots vs shares) as a typed field |
| **Day trading (當沖)**: account needs ≥3 months' history and ≥10 trades. Sell-first day trades can be suspended per stock (TWTBAU1). Disposition stocks (處置股) move to altered trading: periodic call-auction matching, no market orders, and prepayment of cash or shares (the thresholds depend on the disposition level) | Mark eligibility per day. Disposition stocks have different matching | Block sell-first trades on suspended stocks; block market orders and require prepayment for disposition stocks |
| **Taxes and fees**: securities transaction tax 0.3% on sells; **0.15% for stock day trades until 2027-12-31** (Securities Transaction Tax Act Art. 2-2; TWSE's English page still says 2024-12-31); ETFs 0.1%. Bonds: government bonds are exempt by law. **Corporate bonds, financial debentures and bond ETFs (except leveraged and inverse ones) are tax-free only until 2026-12-31** (Art. 2-1). After that they revert to the statutory 0.1% unless the law is extended. Commission ≤0.1425% per side (brokers discount it). Futures transaction tax, charged to **both buyer and seller**: index futures 0.002% of contract value and options 0.1% of premium. These are the applied rates, set by the Executive Yuan within the statutory ranges. Options that are cash-settled at exercise are taxed at the futures rate on the settlement value | The cost model must depend on side and trade type (a day trade is decided at end of day) | Estimate costs before the order |
| **Settlement T+2** for cash equities; futures are marked to market daily | Cash ledger with T+2 settled versus available buying power | Buying power = settled cash + broker credit line |
| **TAIFEX**: TX NT$200/pt, MTX NT$50/pt, TMF NT$10/pt, TXO premium tick ladder. Day session 08:45–13:45 (the expiring contract closes at 13:30 on its last trading day); **night session 15:00–05:00**. There is no after-hours session for the delivery-month contract on its last trading day, but other contract months still trade. Monthly contracts expire on the third Wednesday; **weekly TXO options expire on Wednesday or Friday** | Night-session trades belong to the **next trading date**. The calendar must separate the trading date from the wall-clock date. Weekly expiries need their own symbology | Margin and position limits (from the TAIFEX OpenAPI). No new positions near expiry |
| Ad-hoc closures (for example typhoon days) | Use the exchange holiday endpoint plus manual overrides, never a static calendar | Kill switch when the session status is unknown |

### 4. How the four asset classes differ in this dimension

| | Stocks (TWSE/TPEx) | Options & futures (TAIFEX) | Bonds | Crypto (TW venues) |
|---|---|---|---|---|
| Connectivity | Broker API (Shioaji, Fubon, Yuanta) | Same brokers, but futures needs its own account and API signature | **No dedicated retail bond API**. TWSE-listed government bonds and TPEx dealer market (mostly institutional); foreign bonds through sub-brokerage or banks. Exception: TPEx-listed **convertible bonds (可轉債)** trade through an ordinary securities account, so check whether your broker API accepts CB orders | Exchange REST/WebSocket with HMAC keys; no broker in between |
| Data | Free end-of-day data; paid ticks | Free daily ticks (TAIFEX OpenAPI); paid history | Issuance and reference data (TPEx); bond ETFs trade like stocks | Free public ticks and order books |
| Special rules | Limits, auctions, odd lots, day-trade tax | Night session, weekly expiries, margin, position limits | Accrued interest, no limit for government bonds. Government bonds are tax-exempt; corporate bonds, financial debentures and bond ETFs are tax-free only until 2026-12-31 | 24/7, TWD on/off-ramp, VASP licensing |
| Auth | Personal certificate + API key + IP allow-list | Same | Manual | API key (+ IP allow-list) |
| Recommended handling | First-class automated support | First-class (largest Taiwan retail derivatives market) | **Bond ETFs as equities; direct bonds as manually booked positions** | Adapter per venue, with licensing status kept as configuration |

### 5. Taiwan crypto venues

| Venue | API | Coverage (public endpoints, 2026-10-05) | Notes |
|---|---|---|---|
| **MAX (MaiCoin)** | REST v2/v3 + WebSocket; v3 adds M-wallet (margin) endpoints | 82 markets: 45 TWD-quoted, 36 USDT-quoted; 6 with margin | Largest TWD liquidity pool. Docs site blocks bots (HTTP 403) |
| **BitoPro** | REST v3 + WebSocket; HMAC-SHA384; official Go and Python SDKs | 35 pairs, 19 TWD | 600 requests/min per IP and per account. v2 deprecated |
| **ACE (王牌)** and other local VASPs | REST | The public API could not be reached in our test | Low priority; check that the venue is registered |
| Global venues (Binance, OKX…) | Mature APIs | Deep USDT liquidity | Must register locally under the AML regime (in force since 2024-11-30). Licensing under the VASP Act after it takes effect |

Regulation: 8 VASPs are currently AML-registered. The VASP Act brings seven licensed service categories, 12 months to apply and 21 months to obtain a licence, and up to 7 years' imprisonment / NT$100M for operating unlicensed. Stablecoin issuance needs approval from both the FSC and the central bank, with 100% reserves.

## Recommendations

### (a) Solo / 1–3 person MVP

1. **Use Shioaji as the only Taiwan broker at first.** Run it natively in the Linux core (Python) or as a sidecar (`shioaji server start` exposes HTTP/SSE) if the core is not in Python. Finish the mandatory simulation tests first, then paper trade on `simulation=True`.
2. **Keep Fubon Neo as the documented fallback.** Its Linux SDK means no extra infrastructure. Skip Capital and KGI, so there is **no Windows gateway in the MVP**.
3. **Data stack:** use the TWSE/TPEx/TAIFEX OpenAPIs for reference data, calendars, disposition lists and daily TAIFEX ticks. Add FinMind sponsor tiers for historical stock and futures/options ticks, and real-time data from the broker feed. Add Fugle Developer (NT$1,499/mo) only if you need quotes outside broker sessions or on another machine.
4. **Write a Taiwan rules pack** (limits, auctions, ticks, odd lots, taxes, night-session trading date) as data-driven configuration shared by the backtester and the risk engine. Keep tax rates and expiry dates in configuration, not in code.
5. **Bonds:** support bond ETFs (00679B etc.) as equities, and keep their 0% transaction tax as a dated rule that expires on 2026-12-31 unless extended. Book foreign or sub-brokerage bonds by hand. Convertible bonds (可轉債) can be handled like exchange-traded instruments if the broker API supports them. **Crypto:** use MAX for TWD. **US stocks/options:** connect to a US broker directly instead of going through Taiwan sub-brokerage, which has no mainstream API except Capital's.

### (b) 5–20 person team or institutional grade

1. **Use a broker-agnostic gateway layer:** one gateway per broker, all behind the same internal order/execution/quote contract (gRPC or NATS). Run Shioaji, Fubon and Yuanta SPARK in Linux containers. Run Capital SKCOM (overseas futures and 複委託) and any legacy DLL broker on **Windows Server VMs**.
2. **Latency tier:** Fubon DMA/IDC routing or broker co-location for latency-sensitive futures strategies. Everything else uses the API over the internet with static egress IPs, which the IP allow-lists require.
3. **Licensed data:** buy the TWSE Data E-Shop 5-level book and order-book logs, plus TAIFEX history, for execution research. Use TEJ for point-in-time fundamentals. Keep a written log of data-licence terms, because broker feeds generally may not be redistributed.
4. **Credential platform:** vault-backed certificate and API-key store with expiry alerts, dual control and per-person scoping (see below).
5. **Compliance:** crypto counterparty allow-list driven by the FSC VASP register. If the platform ever executes or advises for other people, get legal review on securities investment consulting (投顧) licensing and broker API terms *before* building multi-tenant features, because certificates are personal.

## Impact on overall architecture

- **Gateway pattern.** The cross-platform core never links broker DLLs directly. Each broker adapter runs as its own process, which gives:
  - fault isolation, because COM crashes and memory leaks stay inside the adapter;
  - its own rate limiter, as token buckets that mirror the published limits;
  - session and reconnect logic, including the login caps (for example 1,000 logins/day);
  - normalization into the canonical order and instrument model.

  Windows adapters run in a persistent desktop session (some COM APIs need a message pump or show dialogs). They need a watchdog, scheduled restarts before 08:30 and 15:00, and matching 32/64-bit builds. The core talks to them only over the network.
- **Certificates and keys.** Taiwan broker certificates (`.pfx`) are **personal**, often named after the holder's national ID, and protected by a password.
  - Store the certificates and passwords in a secrets manager (Vault, a cloud KMS, or Windows DPAPI for the gateway host), never in images or Git.
  - Mount them only into the matching adapter at runtime.
  - Track expiry dates and alert 30 days ahead.
  - Give API keys the narrowest scopes (data / account / trade) and allow-list the gateway's static IPs.
- **Instrument master and symbology.** Use a `venue + local code` key:
  - stocks such as `2330` and leveraged ETFs such as `00631L`;
  - TAIFEX roots (TXF/MXF/TMF/TXO) plus month or weekly codes;
  - crypto pairs.

  Attach the board-lot size, tick table, price-limit regime, tax class, day-trade eligibility and disposition flag as daily-refreshed attributes from the TWSE/TPEx/TAIFEX OpenAPIs.
- **Calendar service.** Use the Asia/Taipei time zone (no DST) and separate the trading date from the wall-clock date for the night session. Load holidays from the exchange APIs and allow manual overrides for typhoon closures. Crypto runs on a 24/7 calendar.
- **Ledger.** Track T+2 settlement for equities, daily mark-to-market for futures, TWD as the base currency with FX for US assets, and lots versus shares as typed quantities.

## Risks & pitfalls

- **Simulation ≠ production.** Shioaji's simulator rejects odd-lot and emerging-stock orders, and Fubon's test environment currently provides securities test accounts only, with no futures. Test odd-lot and futures logic with the smallest real orders.
- **Silent data starvation.** When the Shioaji traffic cap is exceeded, quote queries return *empty values* instead of errors, and the cap scales with your trading volume. Treat empty responses as an alarm, not as "no trades".
- **Rate-limit bans.** Repeated Shioaji rate-limit violations can suspend both the IP and the account ID. Throttle on the client side.
- **Stale official docs and expiring tax holidays.** TWSE's English page still shows 2024-12-31 as the end of the day-trade tax cut, but the law now runs it to 2027-12-31. The bond and bond-ETF tax holiday ends on 2026-12-31. Re-verify tax rates and expiry rules against the law database each year, and keep them as dated configuration.
- **Broker mergers and integration outages.** Masterlink was absorbed into Taishin Securities on 2026-04-06. A system-integration fault on 2026-04-14 then reportedly caused a large trade-report outage and about 9,000 erroneous orders. Reconcile orders and fills against the broker independently, and re-check API continuity after any broker merger.
- **Windows gateway fragility.** COM APIs can show modal dialogs, depend on registry registration and bitness, and break on Windows updates. Pin versions and add health probes.
- **Vendor lock-in through the Fugle stack.** Fubon Neo and the ex-Masterlink API (now Taishin) both rely on Fugle, so one vendor incident can affect two brokers. Keep Shioaji as an independent path.
- **Personal certificates block multi-tenancy.** You cannot legally pool other people's credentials or route their orders through your account. A service offering would need licensing work, not just engineering.
- **Crypto regulatory transition (2027–2028).** Venues may lose eligibility during the licensing window. Foreign exchanges without local registration carry criminal-law exposure in Taiwan.
- **Bond illiquidity.** Bond prices from banks and sub-brokerage are indicative OTC quotes. Do not backtest bond strategies on them as if they were executable prices.

## References

- Shioaji on PyPI (1.7.7, 2026-09-29, platforms): https://pypi.org/project/shioaji/
- Shioaji docs overview: https://sinotrade.github.io/
- Shioaji usage limits: https://sinotrade.github.io/tutor/limit/
- Shioaji onboarding / terms & simulation tests: https://sinotrade.github.io/tutor/prepare/terms/
- Shioaji API key & CA: https://sinotrade.github.io/tutor/prepare/token/
- Shioaji simulation mode: https://sinotrade.github.io/tutor/simulation/
- Shioaji README (HTTP API, SSE, CLI): https://cdn.jsdelivr.net/gh/Sinotrade/Shioaji@master/README.md
- Fubon Neo API introduction: https://www.fbs.com.tw/TradeAPI/docs/trading/introduction
- Fubon Neo onboarding: https://www.fbs.com.tw/TradeAPI/docs/trading/prepare
- Fubon futures API: https://www.fbs.com.tw/TradeAPI/docs/trading-future/introduction
- Fubon market data intro and rate limits: https://www.fbs.com.tw/TradeAPI/docs/market-data/intro , https://www.fbs.com.tw/TradeAPI/docs/market-data/rate-limit
- Fubon install & compatibility (OS/arch per language): https://www.fbs.com.tw/TradeAPI/docs/install-compatibility
- Fubon SDK download & changelog (v2.4.0, test environment note): https://www.fbs.com.tw/TradeAPI/docs/download/download-sdk
- Fubon key management & web certificate export (v2.2.8+): https://www.fbs.com.tw/TradeAPI/docs/key/ , https://www.fbs.com.tw/TradeAPI/docs/trading/api-key-apply
- Fubon test environment (securities test accounts only): https://www.fbs.com.tw/TradeAPI/docs/welcome/
- Fubon trading rate limits: https://www.fbs.com.tw/TradeAPI/docs/trading/trade-rate-limit
- Fubon Go + API Key upgrade (2026-05-11): https://www.taiwannews.com.tw/zh/news/6359399
- Fubon × Fugle new-generation API, DMA/IDC (2025-07-17): https://www.taiwannews.com.tw/zh/news/6158263
- Yuanta SPARK API portal: https://www.yuanta.com.tw/file-repository/content/API/page/index.html
- Yuanta SPARK Python setup (.NET 8, pythonnet): https://www.yuanta.com.tw/file-repository/content/sparkapi_docs/2.Python%E8%A8%AD%E5%AE%9A/Windows%E3%80%81Mac%E7%B3%BB%E7%B5%B1/index.html
- Capital API Python SDK (CapitalAPI 2.13.58, Windows COM): https://github.com/AlexChiang0208/capital_api
- Capital futures API application: https://www.topbroker.tw/blog.php?act=view&id=61
- KGI kgiapp on PyPI: https://pypi.org/project/kgiapp/
- Third-party broker API OS/bitness list: https://www.order-master.com/docs/t03/
- Broker API site list (2026-08): https://www.threads.com/@finance_cat/post/DblSTnGCAgh/
- API trading volume & Masterlink API (2025-01-03): https://news.cnyes.com/news/id/5825158
- Masterlink merged into Taishin Securities (2026-04-06) and the 2026-04-14 outage: https://zh.wikipedia.org/zh-tw/元富證券 , https://zh.wikipedia.org/zh-tw/台新綜合證券
- TWSE OpenAPI spec: https://openapi.twse.com.tw/v1/swagger.json
- TPEx OpenAPI spec: https://www.tpex.org.tw/openapi/swagger.json
- TAIFEX OpenAPI spec: https://openapi.taifex.com.tw/swagger.json
- TWSE trading mechanism (sessions, limits, ticks, odd lots, T+2, taxes): https://www.twse.com.tw/en/products/system/trading.html
- TWSE day-trading rules: https://www.twse.com.tw/en/products/system/day-trading.html
- TWSE Data E-Shop historical products: https://eshop.twse.com.tw/en/category/sub/42
- TAIFEX TXO specs (weekly Wed/Fri, night session): https://www.taifex.com.tw/enl/eng2/tXO
- TAIFEX TX and TMF specs: https://www.taifex.com.tw/enl/eng2/tX , https://www.taifex.com.tw/enl/eng2/tMF
- Taiwan Stock Exchange history (continuous trading 2020, 5-second odd-lot matching): https://en.wikipedia.org/wiki/Taiwan_Stock_Exchange
- Day-trade tax extension to 2027: https://zh.wikipedia.org/zh-tw/當日沖銷
- Securities Transaction Tax Act (Art. 2-1 bond / bond-ETF holiday to 2026-12-31; Art. 2-2 day-trade 0.15% to 2027-12-31): https://law.moj.gov.tw/LawClass/LawAll.aspx?pcode=G0340078
- Futures Transaction Tax Act (statutory ranges, both sides taxed): https://law.moj.gov.tw/LawClass/LawAll.aspx?pcode=G0340079
- FinMind docs, limits and tick datasets: https://finmind.github.io/quickstart/ , https://finmind.github.io/tutor/TaiwanMarket/Technical/ , https://finmind.github.io/tutor/TaiwanMarket/Derivative/
- FinMind / fugle-marketdata / zipline-tej / tejapi on PyPI: https://pypi.org/project/finmind/ , https://pypi.org/project/fugle-marketdata/ , https://pypi.org/project/zipline-tej/ , https://pypi.org/project/tejapi/
- Fugle MarketData pricing: https://developer.fugle.tw/docs/pricing
- Fugle historical candles coverage (stock minute bars from 2023-05-23): https://developer.fugle.tw/docs/data/http-api/historical/candles
- BitoPro API docs: https://github.com/bitoex/bitopro-offical-api-docs
- MAX public markets endpoint: https://max-api.maicoin.com/api/v2/markets
- BitoPro trading pairs endpoint: https://api.bitopro.com/v3/provisioning/trading-pairs
- VASP Act (Lee and Li): https://www.leeandli.com/EN/NewslettersDetail/7658.htm
- VASP Act explainer (BlockTempo): https://www.blocktempo.com/taiwan-virtual-asset-act-third-reading-explainer-vasp-stablecoin-licensing/
- VASP Act & AML registration regime (TRM Labs): https://trmlabs.com/resources/blog/unpacking-taiwans-virtual-asset-service-act-what-crypto-and-stablecoin-issuers-need-to-know

## Verification log (2026-10)

An adversarial fact-check was run on 2026-10-05 against official docs, PyPI JSON, exchange OpenAPI specs, live public endpoints and the national law database. It checked 39 items: 26 confirmed, 7 corrected and 6 unverifiable.

**Confirmed**

1. Shioaji 1.7.7 (2026-09-29). Its wheels are cp37-abi3 plus cp314t, for Windows x64, macOS x64/ARM64 and Linux x64/ARM64. The README states a 14-day release cycle (PyPI JSON and README).
2. Shioaji limits: 50 data calls/10 s, 250 orders/10 s, 200 subscriptions, 5 connections per person ID and 1,000 logins/day. The traffic cap is 500 MB–10 GB by volume tier, and quote queries return empty values when it is exceeded (tutor/limit).
3. The Shioaji local HTTP API runs on `localhost:8080`, with OpenAPI docs at `/docs`, SSE streaming and `shioaji server start` (README). The docs site also confirms a Rust core.
4. Shioaji onboarding: separate stock and futures signing, mandatory login and order tests, API-key scopes, expiry and an IP allow-list, and a cross-platform CA download. The simulator does not support odd-lot or emerging-stock orders.
5. Fubon Neo: Python 3.8–3.13, C# (.NET Standard 2.0) and Node.js ≥16 on Windows, macOS and Linux. C++ and Go support securities trading, accounts and conditional orders only (introduction page).
6. On 2026-05-11 Fubon announced Go support and API-key login with IP restriction and per-function permissions (Taiwan News).
7. Fubon market data: 300/min intraday, 60/min historical, 300 subscriptions × 7 WebSocket connections. DMA/IDC routing was announced on 2025-07-17.
8. Yuanta SPARK runs on Windows x64/x86, macOS ARM64/x64 and Linux x64, on .NET 8 with pythonnet. COM, Delphi and WPF are maintenance-only. UAT needs a fixed-IP firewall approval, and test and production certificates are separate.
9. `kgiapp` 2.0.4 was uploaded 2024-11-17, targets .NET Framework 4.5 and is classified Windows-only (PyPI).
10. TWSE Data E-Shop prices: 5-level intraday data NT$5,000/month, order-book log NT$10,000, odd-lot data NT$1,500.
11. The TAIFEX OpenAPI has 135 paths, including `/TimeAndSalesData` and `/OptionsTimeAndSalesData` (daily futures and options time & sales). The TWSE spec has 143 paths and the TPEx spec 225, all counted from the swagger files.
12. The named endpoints exist: TWTB4U, TWTBAU1, the holiday schedule, disposition and notice stocks, TPEx bond issuance and international-bond quotes, and TAIFEX margins, final settlement prices and position limits.
13. Fugle plans: free (5 subscriptions), Developer NT$1,499/month (300 subscriptions, 600 calls/min) and Advanced NT$2,999/month (2,000 subscriptions).
14. TXO: weekly options expire on Wednesday or Friday. The night session runs 15:00–05:00, with no after-hours session for the delivery-month contract on its last trading day. The text was clarified to say that other contract months still trade.
15. VASP Act: third reading on 2026-06-30. It takes effect in Q1 2027 at the earliest, on a date the Executive Yuan will set. Existing VASPs get 12 months to apply and 21 months to be licensed (+3 months possible). It defines seven service categories. Operating without a licence carries up to 7 years / NT$100M. Stablecoins need approval from both the FSC and the central bank, with full reserves (TRM Labs, Lee and Li, BlockTempo).
16. The AML registration regime has been in force since 2024-11-30, and 8 VASPs remain registered (TRM Labs).
17. Masterlink's Fugle-built API (2025-01) supported Python, Node.js and C# across platforms (cnyes).
18. The community Capital SDK targets CapitalAPI 2.13.58 and needs Windows COM registration with matching bitness.
19. Package versions: `fugle-marketdata` 2.7.0 (MIT, 2026-09-30), `finmind` 2.0.11 (Apache-2.0, 2026-10-04), `zipline-tej` 2.2.2 (Apache-2.0, 2025-11-25).
20. FinMind: stock ticks from 2018-12-07 and futures/options ticks from 2011-01-03 on the backer/sponsor tiers; SponsorPro has Parquet downloads; 600 requests/hour with a token.
21. TWSE rules: order entry from 08:30, continuous trading 09:00–13:25, closing auction 13:25–13:30, fixed-price session 14:00–14:30. Price limits are ±10% (none for IPOs in their first 5 days, ±5% for corporate bonds, none for government bonds). The volatility interruption triggers at 3.5% against the 5-minute average and lasts 2 minutes. The tick tables, the 5-second intraday odd-lot auctions, after-hours odd lots 13:40–14:30 and T+2 settlement were all confirmed.
22. Day-trade eligibility needs ≥3 full months of account history and ≥10 trades in the past year (TWSE).
23. The 0.15% day-trade tax runs until 2027-12-31 (Securities Transaction Tax Act Art. 2-2, law database current to 2026-09-24).
24. Contract specs: TX NT$200/pt, TMF NT$10/pt, TXO NT$50/pt; monthly expiry on the third Wednesday; no weekly TMF contracts.
25. Live endpoints on 2026-10-05:
    - MAX has 82 markets (45 TWD, 36 USDT), 6 of them with margin, and its docs return HTTP 403.
    - BitoPro has 35 pairs (19 TWD). It allows 600 requests/min per IP and per account, signs with HMAC-SHA384, has official Go and Python SDKs, and no longer maintains v2.
    - The ACE API was unreachable.
26. The third-party order tool lists most Taiwan broker APIs as Windows 32/64-bit components (order-master).

**Corrected (original → correction)**

1. Fubon had "no separate simulation environment" → Fubon Neo provides a test environment through a downloadable package. It currently has securities test accounts only (fbs.com.tw/TradeAPI/docs/welcome, download-sdk).
2. Fubon's "certificate tool TCEM.exe runs on Windows only" was presented as the only path → since SDK v2.2.8 the certificate can be exported from the web key-management portal for cross-platform use. API-key login needs SDK ≥ v2.2.7, and up to 30 keys are allowed (fbs.com.tw/TradeAPI/docs/key, install-compatibility).
3. Masterlink (元富) was listed as a current broker → it was merged into Taishin Securities (台新證券) on 2026-04-06. A trade-report outage on 2026-04-14 was attributed to the system integration (zh.wikipedia, 元富證券 and 台新綜合證券). The text now refers to Taishin / ex-Masterlink.
4. "NT$63.6 billion of API turnover in October 2024, up 26% year on year" → the source says turnover had reached NT$63.6 billion *as of* October 2024, against NT$50.6 billion in 2023 (+26%). It does not state the averaging basis (cnyes 2025-01-03).
5. Fugle "minute bars from 2017-06" → stock minute bars only go back to 2023-05-23. The 2017-06 date applies to futures minute bars (developer.fugle.tw historical candles and pricing pages).
6. "Bonds exempt" from securities transaction tax → only government bonds are permanently exempt. Corporate bonds, financial debentures and non-leveraged bond ETFs are tax-free only until 2026-12-31 (Securities Transaction Tax Act Art. 1 and 2-1, law.moj.gov.tw pcode G0340078).
7. Futures transaction tax labelled "statutory" → the Act sets only ranges, and the applied rates are set by the Executive Yuan. The tax is charged to both buyer and seller, and options cash-settled at exercise are taxed at the futures rate (Futures Transaction Tax Act Art. 2, pcode G0340079).

Additions without a correction: Shioaji's 25/5 s accounting limit, the 1-minute suspension on rate-limit breaches, the yanked 1.7.6 and the parallel 1.5.x line; Fubon's trading limits (50 orders/s, 10 batch orders/s, 5 account queries/s, 10 connections) and SDK v2.4.0; the TWSE E-Shop "order type" product (NT$10,000); TPEx convertible bonds as a missing retail bond channel.

**Unverifiable**

1. The PyO3 binding for Shioaji. Official docs confirm only a "Rust core", so the text was softened.
2. Capital SKCOM coverage of overseas futures and overseas stocks (複委託). The official API page returned 404, and the community SDK lists only domestic products.
3. The exact prepayment rules for disposition stocks ("full prepayment"). The TWSE page confirms only call-auction matching and the ban on market orders, so the text was generalised to "prepayment thresholds depend on the disposition level".
4. The applied futures-tax rates (0.002% for index futures, 0.1% of option premium). Both sit inside the statutory ranges, but they were not re-checked against an MOF or TAIFEX rate table in this pass.
5. Whether the Fugle-built Masterlink API continues unchanged under Taishin Securities after the merger.
6. The Threads broker-API site list (2026-08). It is a social post and was not independently checkable.
