**English** | [繁體中文](ADR-0007-web-first-client-and-charting-stack.zh-TW.md)

# ADR-0007: Cross-platform front end and charting: a web-first React workstation with permissive chart libraries

## Status

**Proposed** · 2026-10-05 · Scope: scenario 1 (Phase 2 web client; optional Phase 3 shells), with the scenario-2 path noted.

## Context and problem statement

The brief asks for a cross-platform UI on desktop, web and mobile. A 1–3 person team cannot maintain several UI codebases. Trading UIs also have demanding needs: streaming quotes without jank, lossless order state, dense charts, option chains and blotters, Taiwan conventions (red-up colours, five-level book, TAIFEX T-quote) and strict precision. Which framework and which chart libraries should we use?

What the research found ([06](../../research/06-cross-platform-client-ui.md)):

- **Shells on 2026-10-05:**
  - Web/PWA (iOS Home-Screen web apps have supported Web Push since iOS 16.4).
  - Tauri 2.12.1, with v3 in alpha (3.0.0-alpha.4).
  - Electron 44 (80–150 MB installs; a new major every 8 weeks).
  - Flutter 3.47 (Dart; a weak finance-chart ecosystem).
  - React Native 0.87 (its desktop forks lag core).
  - Compose Multiplatform 1.12 (Web in Beta).
  - Avalonia 12 / .NET MAUI.
  - Qt 6.12 LTS (Qt Graphs is GPLv3 or commercial).
- **Chart licences:**

  | Library | Licence | Note |
  |---|---|---|
  | TradingView Lightweight Charts 5.2 | Apache-2.0 | The attribution notice and link are mandatory |
  | TradingView Advanced Charts | Proprietary | Licensed only to companies, and free only on public, non-paywalled sites. **Individuals and private deployments are not eligible** |
  | SciChart.js 6 | Commercial | Domain- or app-ID-locked Standard licences |
  | Highcharts Stock 13 | Commercial | Per-seat licences |
  | uPlot | MIT | Dense series |
  | ECharts 6.1 | Apache-2.0 | Reports |
  | AG Grid Community 36 | MIT | Enterprise costs $999 per developer |
  | KLineChart 10 | Apache-2.0 | Built-in drawing tools |

- **Transport.** Lossless, sequenced channels (orders, fills, positions, risk) must be separated from conflatable ones (quotes, greeks, P&L marks). Decoding belongs off the UI thread.
- **Precision.** JavaScript numbers are binary floats, so prices must travel as decimal strings ([ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md)).
- **Security.** Web and mobile clients must never hold venue keys ([ADR-0008](ADR-0008-key-and-secret-management.md)).
- **Scope.** Proposal A put three shells (web, Tauri, PWA push) in the MVP. The feasibility judge flagged that as critical-path risk, and it was deferred ([evaluation](../../architecture/evaluation.md), graft 36).

## Decision drivers

- One codebase that a 1–3 person team can maintain.
- Real-time performance without dropping order events.
- Licences that fit self-use now and a possible paid service later.
- Exact display of prices and quantities.
- Taiwan localization alongside US and crypto conventions.
- A path to desktop and mobile without a rewrite.

## Considered options

**Shell**

1. **A web-first React + TypeScript (Vite) workstation plus Telegram/ntfy**, with an optional Tauri 2 desktop shell and PWA web push in Phase 3.
2. **Tauri 2 desktop and mobile plus PWA, all in the MVP** (Proposal A's original scope).
3. **Electron** desktop.
4. **Flutter** for every target.
5. **React Native** mobile plus a web app.
6. **Native toolkits** (Qt, Avalonia).

**Charts and grids**

1. **A permissive stack:** Lightweight Charts 5.2, uPlot, ECharts 6.1, AG Grid Community 36, and KLineChart when drawing tools are needed.
2. **TradingView Advanced Charts or Trading Platform.**
3. **Commercial WebGL libraries** (SciChart.js or Highcharts Stock).
4. **Plotly or Perspective only.**

## Decision outcome

**Chosen options: shell 1 and charts 1.** A web workstation is the single codebase every later shell wraps. Telegram/ntfy gives mobile alerts and emergency commands without a mobile app, and the chart stack is fully permissive.

| Area | Decision |
|---|---|
| Phase 2 client | React + TypeScript (Vite) **web workstation**, served as static assets by the `api` container and reachable only over Tailscale. It shows positions, orders, fills, charts, backtest reports, limits, reconciliation status, a paper/live banner and the kill switch. A PWA manifest ships early because it costs almost nothing |
| Mobile in scenario 1 | **Telegram/ntfy**: alerts, `/status`, `/halt`, `/flatten` and `/approve` (pending proposals only) with a confirmation PIN. Telegram can never raise a limit or enter a free-form order. An optional **LINE Messaging API** notifier sends alerts only (LINE Notify ended on 2025-03-31) |
| Semi-automated trading | The workstation has an order ticket that shows pre-trade check results before submitting, and a proposal-approval queue with expiry countdowns ([recommended architecture](../../architecture/recommended-architecture.md) §3.13) |
| Phase 3 (optional) | A **Tauri 2.12** desktop shell (pinned to 2.x while v3 is in alpha) for OS-keychain storage of the API token and multi-window use; **PWA web push**. Both wrap the same web code |
| Scenario 2 | A **React Native 0.87** companion (APNs/FCM push, biometric approvals) that shares the TypeScript domain and Protobuf packages; **Electron** if a pinned Chromium or FDC3 interop is required; a design system and widget SDK |
| Charts | **Lightweight Charts 5.2** for price charts, with the TradingView attribution kept visible (`attributionLogo`). **uPlot** for dense series. **ECharts 6.1** for reports and tear sheets. **KLineChart** if interactive drawing tools are needed |
| Grids and widgets | **AG Grid Community 36** for blotters and option chains. Phase 3 adds a custom Canvas TAIFEX T-quote and a DOM ladder |
| Not used now | TradingView Advanced Charts (we are not eligible); SciChart.js and Highcharts Stock (cost, unless density needs justify them in scenario 2); AG Grid Enterprise (scenario 2); Flutter and Qt (a second UI language) |
| Transport | A FastAPI gateway. REST for commands and queries; Connect RPC is the alternative. **One WebSocket** with channels: lossless and sequenced (`orders`, `fills`, `positions`, `risk`, `alerts`; snapshot plus deltas with gap detection and resync) and conflatable (`quotes`, `greeks`, `pnl_marks`, at 4–10 Hz for grids and at most the display rate for charts). Protobuf schemas, JSON mapping first. Arrow IPC for backtest artifacts |
| Precision and time | Prices and quantities as **decimal strings**; nanosecond timestamps as strings parsed to `BigInt` ([ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md)). No float equality on order state |
| Rendering | A Web Worker decodes and merges data. The UI renders once per `requestAnimationFrame`. Charts update the live bar with `series.update()`, never `setData()` per tick |
| Localization | Configurable up/down colours (Taiwan red-up, US and crypto green-up) with a colour-blind palette; Asia/Taipei and New York time zones with DST; a defined daily cut for 24/7 crypto; UI and alert strings externalized with react-i18next (or FormatJS) and a per-user zh-TW/en switch; `Intl.NumberFormat` per locale, including 萬/億 compact notation; a bundled CJK font (Noto Sans TC) for charts, canvas widgets and PDF reports; instrument names from `name_zh_tw`/`name_en` in the security master ([recommended architecture](../../architecture/recommended-architecture.md) §3.11) |
| Safety rules | Clients never hold venue keys and never price instruments. Live commands need a second confirmation. Limit changes need re-authentication and a reason |

### Consequences

**Positive**

- One TypeScript codebase serves browser, desktop (Tauri) and PWA, and a scenario-2 React Native app can share its domain and contract packages.
- About zero licence cost and no licence trap for a paid service later; only the attribution duty.
- The lossless/conflated channel split prevents both dropped fills and UI jank.
- Mobile alerting and emergency control exist from Phase 2 without an app-store project.

**Negative**

- No native mobile app in scenario 1. iOS suspends background sockets, so push depends on Telegram/ntfy until PWA push or React Native arrives.
- The free chart libraries lack built-in indicators (Lightweight Charts) or institutional density (no WebGL million-point charts). Indicators are computed on the backend or in a worker.
- If a Tauri shell is added, webview variance appears (WebKitGTK on Linux is the weakest). It must be tested on all three engines, or Electron used.
- uPlot releases rarely. It is wrapped behind our own component API.

### Confirmation

- CI builds the web bundle and runs a licence check on the npm dependency tree ([ADR-0009](ADR-0009-open-source-licensing-strategy.md)).
- A UI test asserts that the TradingView attribution is visible.
- Contract tests verify snapshot-plus-delta resync and gap detection on the lossless channels.
- A lint rule blocks `Number()`/`parseFloat` on price and quantity fields.

### Revisit when

- Phase 3 needs OS-keychain storage, multi-window desks or web push → add Tauri 2 or PWA push.
- An external offering (T1) → OIDC + PKCE and WebAuthn in a backend-for-frontend, per-user entitlements and delayed-data flags; licensed charting if the service is public.
- Density or 3D volatility surfaces become essential → evaluate SciChart.js or Highcharts within budget.
- Tauri v3 becomes stable → re-evaluate its CEF runtime option.

## Links

- [Main report: front end, charts/grids and API/UI transport rows](../../README.md)
- [Recommended architecture §3.10 and §3.11](../../architecture/recommended-architecture.md)
- [Evaluation record: grafts 18 and 36; concern 20](../../architecture/evaluation.md)
- Research: [06 Cross-platform client and charting](../../research/06-cross-platform-client-ui.md) · [08 Security](../../research/08-risk-security-ops-compliance.md)
- Related ADRs: [ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md) · [ADR-0008](ADR-0008-key-and-secret-management.md) · [ADR-0009](ADR-0009-open-source-licensing-strategy.md) · [ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.md)
