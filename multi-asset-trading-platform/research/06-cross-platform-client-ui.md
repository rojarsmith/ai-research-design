**English** | [繁體中文](06-cross-platform-client-ui.zh-TW.md)

# 06 — Cross-Platform Client, Charting & Real-Time Visualization

> Research dimension 06. Research date: 2026-10-05. Versions and dates come from the npm, crates.io, PyPI and pub.dev registries and from vendor pages. Check licences and prices again before you buy anything.

## TL;DR

- **Build one TypeScript/React "workstation" web app and wrap it. Don't adopt a native UI toolkit.**
  - Ship the app to browsers.
  - On desktop, wrap it in **Tauri 2.12**: tiny installers, a Rust core, and iOS/Android targets.
  - Use **Electron 44** instead when you need one pinned Chromium on every desktop.
  - Mobile is a reduced *monitor / alert / approve / flatten* companion, not a port.
- **Default visual stack:**
  - TradingView **Lightweight Charts 5.2** for price charts. It is Apache-2.0, but attribution is mandatory.
  - **uPlot** for dense series and **ECharts 6.1** for reports.
  - **Perspective 5.5** for streaming pivots that also run in notebooks. It is now an OpenJS Foundation project published as `@perspective-dev/*`.
  - **AG Grid 36** for blotters and option chains.
  - **TradingView Advanced Charts is licensed only to companies, and is free only on public, non-paywalled sites.** Individuals, hobby/testing use and private or paywalled deployments are not eligible. Budget for **SciChart.js 6** or **Highcharts Stock 13** when you need institutional density.
- **Transport:**
  - Binary WebSocket for market data and order state: Protobuf envelopes, a snapshot plus sequenced deltas, and per-subscriber conflation on the server.
  - **Connect RPC** for commands and **Arrow IPC** for bulk columnar data.
  - WebTransport now ships in all major engines (Safari 26.4+) but stays optional.
- **Asset classes change the widgets, not the framework:**
  - Crypto: 24/7 L2 depth.
  - Equities: sessions, corporate actions, Taiwan red-up colours (紅漲綠跌) and price-banded ticks.
  - Options: chains, Greeks, vol surfaces and TAIFEX T-quote (T字報價).
  - Bonds: price↔yield, curves, RFQ.

## Key questions

1. Which shell gives the most reuse across desktop, web and mobile without capping chart performance?
2. Which chart and grid licences fit each use: personal self-use, a paid service, or a free public site?
3. How do we stream high-rate data without jank and without losing order events?
4. How do notebooks and the trading UI share data, charts and results?
5. What differs per asset class, and for Taiwan compared with US and crypto markets?

## Options compared

### 1. Application shells

Install sizes are indicative only.

| Option (Oct 2026) | Targets | Rendering | Size | Real-time charts | UI shared with web | Licence / status |
|---|---|---|---|---|---|---|
| **Web / PWA** (React/TS) | Any browser. iOS Home-Screen apps have had Web Push since iOS 16.4 | DOM, Canvas, WebGL, WebGPU | None | Excellent on Chromium, but the user picks the browser. No keychain, no local SDKs, weak multi-window | 100% | n/a |
| **Tauri 2.12** (2.12.1, 2026-09-30; **v3 alpha since 2026-09-13**, 3.0.0-alpha.4 on 2026-10-01) | Win, macOS, Linux, iOS, Android | OS webview (WebView2, WKWebView, WebKitGTK, Android WebView). In v3 the runtime is a build-time choice, including **CEF (Chromium)** | Minimal <600 KB; real apps 3–15 MB | Good on WebView2 and WKWebView, weakest on WebKitGTK. Rust→JS **Channels** deliver ordered, high-throughput data (events are JSON-only) | ~90–100% | MIT/Apache-2.0; very active |
| **Electron 44** (44.5.1, 2026-09-30) | Desktop | Bundled Chromium; new major every 8 weeks; latest 3 majors supported (Electron 45 is due 2026-10-20, when 42 leaves support) | 80–150 MB | Most predictable: one engine everywhere | ~100% on desktop | MIT; very active |
| **Flutter 3.47** (3.47.6) | All six | Own renderer; Impeller became the desktop default on 2026-08-12 | 15–40 MB | Smooth painting, but few finance chart libraries (Syncfusion, fl_chart) | 0% with TS web | BSD-3; active |
| **React Native 0.87** (+ RN-Windows 0.84, RN-macOS 0.83) | Mobile first-class; desktop through Microsoft forks | Native views + Skia (react-native-skia 2.14) | 20–50 MB | Good with Skia. The pragmatic chart path is Lightweight Charts in a WebView | Logic and types shared, UI mostly not | MIT; **desktop forks trail core by 3–4 minor versions** |
| **Compose Multiplatform 1.12** (1.12.1, 2026-09-22) | Android, iOS and Desktop stable; Web (Wasm) **Beta** | Skia | 50+ MB (JVM) | Good; few finance libraries | Separate | Apache-2.0 |
| **Avalonia 12** (12.0 on 2026-04-07; 12.1.3 latest) / **.NET MAUI 10** (MAUI 11 at RC) | Avalonia: desktop, mobile, WASM. MAUI: Linux and web only through the Avalonia backend preview | Skia | 30–80 MB | Strong desktop; SciChart ships native .NET charts | Separate | MIT, plus paid add-ons |
| **Qt 6.12 LTS** (2026-09-30) | Desktop, mobile, WASM | C++/QML GPU scene graph | 20–60 MB | Highest raw performance | Separate | LGPLv3, GPLv3 or commercial. **Qt Graphs is GPLv3 or commercial only**. Commercial LTS support runs to 2031; open-source patch support for 6.12 ends 2027-04 |
| **Wails v3** (beta) · **Slint 1.18** · **egui 0.36** | Wails: desktop (mobile experimental). Slint and egui: desktop, mobile, web | Wails: webview. Slint and egui: native GPU | Small | egui is ideal for dense internal tools | Wails high; Slint and egui none | MIT. Slint is GPLv3, royalty-free (non-embedded) or commercial |

**Institutional desktop containers (not in the table above):** **interop.io io.Connect Desktop** (formerly Glue42; Finsemble is also under interop.io) and **HERE Core** (formerly OpenFin) are commercial Chromium-based containers with FDC3 interop, used on bank and buy-side desks. They matter only in scenario (b), and only if the app must share context with other vendors' desktop apps. They add licence cost and vendor lock-in.

### 2. Charting libraries

| Library | Latest | Licence / cost | Renderer | Trading fit | Limits |
|---|---|---|---|---|---|
| **TradingView Lightweight Charts** | 5.2.1 (2026-08-12) | Apache-2.0. **Must** show the NOTICE attribution and a link to tradingview.com; the `attributionLogo` option satisfies the link | Canvas, ~35 KB | Multi-pane (v5), plugins and custom series, yield-curve and options chart types, data conflation (v5.1), hit-testing (v5.2). Official plugin packages (`@tradingview/lwc-toolkit` plus ten plugins) since 2026-09-16 | No built-in indicators or drawing tools |
| **TradingView Advanced Charts / Trading Platform** | Private repo, access on approval | Proprietary. Advanced Charts is free **only for companies on public, non-paywalled sites with TradingView branding**; not for personal, hobby or testing use. Trading Platform is paid | ~670 / ~900 KB | 100+ indicators, drawings. Trading Platform adds an order panel, DOM and broker adapter. Mobile through a WebView | No data included; quote-based fees otherwise |
| **SciChart.js** | 6.0.6 (2026-10-02) | Commercial. SciChart does not publish list prices; a third-party listing (G2) shows about US$1.3k (2D) / 1.7k (2D+3D) per developer per year (unverified, so get a quote). Free Community edition is watermarked and non-commercial. **Standard licences are locked to a known hostname or app ID, exclude localhost deployments, and cover up to 5 apps and 15,000 users.** Advanced (bundle) licences are not domain-locked. 50% off for single entities under US$1M revenue or funding and fewer than 5 developers | WebGL + WASM | Millions of points live, 3D vol surfaces, heatmaps. Native WPF, iOS and Android versions | Cost. Tauri and Electron origins (`tauri://localhost`, `http://tauri.localhost`, `file://`) may need an app-ID key or an Advanced licence |
| **Highcharts Stock** | 13.1.1 (2026-09-20) | Commercial per developer seat. Official shop prices for Core + Stock: Internal use US$370/yr or US$850 perpetual; SaaS/External US$732/yr or US$1,678 perpetual; OEM by quote. Non-commercial use has separate terms | SVG + WebGL boost | Navigator, indicators, accessibility. Good for reports | Slow at tick rates. OEM is needed only for a product your customers install or host. A desktop client of your own service counts as an External (SaaS) application |
| **Apache ECharts** | 6.1.0 (2026-05-19) | Apache-2.0 | Canvas/SVG, plus GL for 3D | Dashboards, tear sheets, heatmaps | ~1 MB; not built for tick streams |
| **uPlot** | 1.6.32 (2025-03; repo active) | MIT | Canvas 2D, ~50 KB | 166,650 points in 25 ms from a cold start. Equity curves, latency plots | Bare API; rare releases |
| **Plotly.js / plotly.py** | 4.1.1 / 7.1.0 | MIT | SVG + WebGL | Same figure JSON in notebook and app | Heavy; poor for streaming |
| **Perspective** | 5.5.1 (2026-09-18) | Apache-2.0. Moved **from FINOS to the OpenJS Foundation** (incubating project, announced 2025-10-30); `@finos/perspective` stopped at 3.8.0 (2025-09) | C++→WASM + WebGL | Streaming Arrow, pivots and joins. Virtual servers over DuckDB, ClickHouse, PostgreSQL and Polars. Jupyter anywidget. wasm64 for data over 4 GB | Opinionated UI |
| **KLineChart** (added in verification) | 10.0.3 (2026-08-27) | Apache-2.0 | Canvas, ~40 KB gzip, zero dependencies | Built-in indicators and line-drawing tools. A free option for a solo user who needs drawings, since Advanced Charts is not available to individuals | Smaller ecosystem than TradingView; no vendor SLA |

**GPU baseline:**
- **WebGL2 is universal.** WebGPU is progressive enhancement only.
- **WebGPU is on by default** in Chrome/Edge (Linux depends on drivers), Safari on iOS 26 and macOS 26+, and Firefox on Windows and on macOS 26 Apple Silicon.
- **Tauri on Linux:** WebKitGTK has no WebGPU by default.

### 3. Grids and specialized widgets

| Grid | Latest | Licence | Use |
|---|---|---|---|
| **AG Grid** | 36.2.0 (2026-09-16) | Community is MIT. Enterprise is **US$999 per developer**, a perpetual licence with 1 year of updates; with AG Charts it is US$1,498 | Blotters, positions, option chains. Uses async transactions and cell flashing. Enterprise adds pivot, a server-side row model and export |
| **Glide Data Grid** | 6.0.3 stable (2024-02); alpha tags until 2026-01 (last npm prerelease 6.0.4-alpha24, 2025-10) | MIT | Canvas, millions of rows. **Maintenance risk** |
| **Perspective datagrid** | 5.5.1 | Apache-2.0 | Ad-hoc pivots, P&L attribution |
| **Custom Canvas/WebGL** | n/a | n/a | DOM ladder, depth heatmap, T-quote: price-indexed rows at 60 fps |

### 4. Backend-to-UI transport and encoding

| Mechanism | Browser capability | Best for | Caveats |
|---|---|---|---|
| **WebSocket** | Bidirectional, universal | Market data, order and position updates | You own subscriptions, sequence numbers, heartbeats, resync and backpressure |
| **SSE** | Server→client, universal | Alerts, backtest progress | Text only; HTTP/1.1 connection caps |
| **gRPC-web** | Unary + server streaming, through a proxy | Teams already on gRPC | No client or bidi streaming |
| **Connect RPC** (connect-es 2.2.0) | Unary + server streaming. In browsers it speaks Connect or gRPC-web; plain gRPC needs a server-side runtime such as Node | Commands, queries, typed contracts (Protobuf-ES 2.16) | Browsers can't stream from the client side; not a tick multiplexer |
| **WebTransport** | Streams + datagrams in Chrome, Edge, Firefox and Safari/iOS 26.4+ | One stream per symbol with no head-of-line blocking | Corporate networks often block QUIC; keep a WebSocket fallback |
| **NATS over WebSocket** | Pub/sub | Fast MVP if NATS is the bus (see [07](07-system-architecture-messaging.md)) | Exposes the bus; entitlements get harder |

**Encodings:**
- **Protobuf** is the default contract for RPC and WebSocket envelopes, with codegen for TS, Rust, Python, Dart, Swift and Kotlin.
- **FlatBuffers** (25.9) gives zero-copy for large book or chain snapshots, *after profiling*.
- **MessagePack** (3.1) is schemaless with weak contracts.
- **Arrow IPC** (apache-arrow 21.2) carries bar history, equity curves and trade lists straight into Perspective, DuckDB-WASM and uPlot typed arrays.
- **JSON** is for debugging only.

**Throttling and conflation rules:**
1. **Lossless channels:** orders, fills, positions and risk breaches are sequenced and never dropped.
2. **Conflatable channels:** quotes, depth, Greeks and P&L marks keep only the latest value per key.
3. **Conflate on the server, per subscriber:** grids at 4–10 Hz, charts at most at display refresh. Mobile and hidden tabs get a lower tier.
4. **Keep decoding off the UI thread:** a **Web Worker** decodes and merges into typed arrays or Arrow. The UI renders once per `requestAnimationFrame`, never once per message. SharedArrayBuffer requires COOP/COEP headers.
5. **Order books** are a snapshot plus sequenced deltas, with gap detection and resync. Render the top N levels.
6. **Update charts incrementally:** use `series.update()` for the live bar, not `setData()`.

### 5. Research notebooks and the UI

| Pattern | Verdict |
|---|---|
| **Shared data plane.** JupyterLab 4.6.4 and marimo 0.25.1 (see [09](09-research-ml-analytics.md)) read the same Parquet/Arrow store and query API as the app. Backtests emit Arrow/Parquet plus a JSON manifest, and the app renders the report (see [02](02-backtesting-engine.md)) | **Recommended** |
| **Shared components.** Perspective anywidget in notebooks and `<perspective-viewer>` in the app use the same config JSON. Plotly figure JSON is portable | Recommended for analytics |
| **Embedded notebook** inside the app | Later, for power users only. A kernel is code execution, so it needs isolation |
| **Notebook as trading client** through the same OMS API | Only through the same risk checks and paper/live flag. Never put broker keys in notebooks |

## Asset-class differences in this dimension

| | Equities (US, TWSE/TPEx) | Crypto | Options (US, TAIFEX TXO) | Bonds |
|---|---|---|---|---|
| **Updates** | Session-bound; L1 plus depth (TW five levels, 五檔) | 24/7, multiple venues, high-rate L2 | Thousands of contracts per underlying; Greeks move on every tick | Sparse or indicative; RFQ |
| **Key widgets** | Candles, watchlist, DOM ladder, adjusted history | Depth chart, book heatmap, funding | Chain grid / **T-quote**, IV smile and surface, payoff, multi-leg ticket | Yield curve, price↔yield, clean/dirty + accrued interest, DV01 |
| **Rules / format** | TW tick size varies by price band (升降單位); ±10% limits (漲跌停); intraday odd-lot (盤中零股) auctions every 5 s | 8–18 decimal places: decimal strings, not JS `number` | Multipliers; weekly and monthly expiries | US Treasuries quoted in 32nds |
| **Time** | Asia/Taipei; New York with DST | UTC, never closes | TAIFEX after-hours session (夜盤) | Settlement and day-count conventions |
| **Streaming** | Conflate per symbol | Heavy conflation, top-N depth | **Slice on the server**: stream only visible strikes | Event-driven |

**Taiwan:**
- Up/down colours must be a user setting, because TW is red-up while US and crypto are green-up. Also offer a colour-blind palette.
- Shioaji (SinoPac 永豐) and Fubon Neo API run cross-platform. Fubon Neo SDK 2.4.0 ships Python wheels for Windows x64 and for macOS and Linux (arm64 and x64), but its certificate helper tool is Windows-based.
- Windows-only broker SDKs belong in a backend gateway ([07](07-system-architecture-messaging.md)), never in the client.

## Recommendations

### (a) Solo / 1–3 person MVP

1. **One codebase:**
   - React + TS + Vite, built as a responsive web app and packaged with **Tauri 2.12**.
   - The Rust side handles the keychain and local Parquet.
   - Pin 2.x and skip v3 until it is stable.
   - Mobile starts as a PWA. Add Tauri mobile builds of a *reduced* route set only if you need app-store presence.
2. **Charts:** Lightweight Charts 5.2 with attribution shown, uPlot for dense series, ECharts for backtest reports. Compute indicators on the backend or in a worker. If you need interactive drawing tools, evaluate KLineChart (Apache-2.0) instead of building them.
3. **Grids:** AG Grid Community for blotters and chains; Perspective for exploration and notebooks.
4. **Transport:** one WebSocket with Protobuf and server-side conflation, plus Connect RPC, plus Arrow IPC for artifacts.
5. **Avoid at this stage:**
   - TradingView Advanced Charts: you are ineligible.
   - SciChart and Highcharts: cost.
   - Flutter and Qt: a second UI language.
   - Embedded Jupyter.

### (b) 5–20 person team / institutional grade

1. **Same web core**, plus a monorepo design system and a widget SDK.
2. **Desktop shell:**
   - **Electron** for a pinned Chromium, multi-monitor workspaces and FINOS FDC3 interop. Use a commercial FDC3 container (interop.io, or HERE Core, formerly OpenFin) only if you must interoperate with other vendors' desktop apps.
   - **Tauri** if footprint and a Rust security boundary matter more.
   - Re-evaluate the **Tauri v3 CEF runtime** once it is stable.
3. **Mobile:** a native **React Native 0.87** companion that shares the TS domain and Protobuf packages. It provides APNs/FCM push, biometric order approval and a kill switch.
4. **Charts:**
   - **SciChart.js** or Highcharts Stock for density, 3D surfaces and vendor SLAs.
   - **TradingView Advanced Charts or Trading Platform** only for a company running a public or licensed client-facing service. Trading Platform also expects your own broker back end for the data stream and order management.
5. **Grids:** AG Grid Enterprise plus Perspective. Build the DOM ladder and T-quote as custom Canvas/WebGL components.
6. **Gateway:** a UI gateway/BFF handles per-user entitlements, conflation tiers, resync and audit. WebTransport is opt-in.
7. **Language-specific teams:**
   - C#: Avalonia 12 with SciChart .NET.
   - Visible-latency tools (ops or HFT monitors): Qt 6.12 LTS under a commercial licence, or egui. Keep these separate from the customer-facing app.

### Single codebase vs maximum performance

| Goal | Stack | UI shared | Trade-off |
|---|---|---|---|
| Maximum single codebase | React/TS + Tauri 2 (desktop + mobile) + PWA | ~90–95% | Webview variance; mobile UX compromises |
| **Balanced (default)** | React/TS + Tauri or Electron + React Native companion | UI ~70–80%, logic ~90% | Two UI layers |
| Maximum performance | Electron + SciChart WebGL + worker data plane; Qt or egui for latency tools | ≤50% | Cost, skills, licences |
| One non-web toolkit | Flutter 3.47, all targets | ~95% in Dart | Weak finance chart ecosystem; no TS reuse |

## Impact on overall architecture

- **A UI gateway is mandatory.** This is consistent with [07](07-system-architecture-messaging.md). The gateway owns:
  - OIDC + PKCE auth
  - market-data entitlements and delayed-data flags, because exchange display licences apply per user
  - per-subscriber conflation
  - snapshot/delta sequencing
  - translation from the bus to Protobuf over WebSocket and Connect
- **Contracts come first.** One Protobuf repository, checked with `buf breaking`, generates the TS, Rust, Python and mobile clients.
- **Research and UI meet only through artifacts.** Backtest and research outputs are Arrow/Parquet plus a manifest.
- **The client runs a worker data plane and schedules rendering per frame.** If you use SharedArrayBuffer, hosting must send COOP/COEP headers, which constrains third-party iframes.
- **The desktop shell provides capabilities only:** keychain, notifications, windows and file system. Trading logic stays on the server.
- **Every client needs safety controls:** order confirmation, flatten, kill switch, and a paper/live banner.

## Risks & pitfalls

- **TradingView licensing.** Advanced Charts is unavailable for private or paywalled use. If you hide `attributionLogo` without crediting TradingView elsewhere, you breach the Lightweight Charts licence.
- **Webview variance.** Tauri on Linux (WebKitGTK) is slower and lacks WebGPU, and WKWebView has its own quirks. Test on all three engines, or pin Chromium with Electron or Tauri v3 CEF.
- **Churn.** Tauri v3 changes how the runtime is selected. The React Native desktop forks lag core. Compose Web is still Beta. Perspective's npm scope was renamed.
- **Stagnant dependencies.** Glide has had no stable release since 2024-02, and uPlot releases are rare. Wrap both behind your own component API.
- **Licence traps.** Qt Graphs is GPLv3 or commercial only, and LGPL brings relinking obligations. SciChart Standard licences are locked to a hostname or app ID and exclude localhost deployments. Highcharts licences depend on audience: Internal for self-use, SaaS/External for your own client-facing apps (including desktop clients), and OEM only for products your customers install or host.
- **Precision.** Use decimal strings or scaled integers for prices and quantities. Never use float equality on order state.
- **Update storms.** Parsing JSON and re-rendering React on every tick causes GC jank. Use workers, conflation and imperative chart updates.
- **Mobile background limits.** iOS suspends sockets, so alerts need push. Tauri's official notification plugin only sends local notifications.
- **Time and sessions.** Account for US DST, TAIFEX's overnight session and 24/7 crypto.

## References

- Tauri releases and 2.12 notes: https://v2.tauri.app/release/tauri/ ; https://v2.tauri.app/blog/tauri-2.12/
- Tauri v3.0.0-alpha.0 (runtime selection, CEF): https://newreleases.io/project/github/tauri-apps/tauri/release/tauri-v3.0.0-alpha.0 ; https://crates.io/crates/tauri
- Tauri app size and Channels: https://v2.tauri.app/start/ ; https://v2.tauri.app/develop/calling-frontend/
- Tauri plugins and notification plugin: https://v2.tauri.app/plugin/ ; https://v2.tauri.app/plugin/notification/
- Electron support and versions: https://endoflife.date/electron ; https://releases.electronjs.org/
- Flutter 3.47 Impeller on desktop: https://startdebugging.net/2026/08/flutter-3-47-impeller-default-renderer-on-desktop/ ; https://docs.flutter.dev/release/release-notes
- React Native blog (0.84–0.87): https://reactnative.dev/blog ; https://www.npmjs.com/package/react-native-windows ; https://www.npmjs.com/package/react-native-macos
- Compose Multiplatform 1.12 and stability levels: https://kotlinlang.org/docs/multiplatform/whats-new-compose-112.html ; https://github.com/JetBrains/compose-multiplatform/releases ; https://kotlinlang.org/docs/multiplatform/supported-platforms.html
- Avalonia 12 and the Avalonia MAUI backend: https://avaloniaui.net/blog ; https://avaloniaui.net/blog/net-maui-is-coming-to-linux-and-the-browser-powered-by-avalonia
- .NET MAUI support policy: https://dotnet.microsoft.com/en-us/platform/support/policy/maui
- Qt versions, Qt Graphs licence, Small Business tier: https://endoflife.date/qt ; https://doc.qt.io/qt-6/qtgraphs-index.html ; https://www.qt.io/pricing ; https://www.qt.io/qt-for-small-business
- Wails v3 status: https://docs-preview.wails.io/status/
- Slint licensing: https://slint.dev/pricing ; egui: https://crates.io/crates/egui
- iOS Web Push for web apps: https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/
- TradingView libraries and licences: https://www.tradingview.com/free-charting-libraries/ ; https://www.tradingview.com/charting-library-docs/latest/introduction/
- Lightweight Charts licence, NOTICE and release notes: https://github.com/tradingview/lightweight-charts ; https://tradingview.github.io/lightweight-charts/docs/release-notes ; https://www.npmjs.com/package/lightweight-charts
- SciChart.js licensing and pricing: https://www.scichart.com/documentation/js/v4/user-manual/licensing-scichart-js/getting-started-for-free/ ; https://www.scichart.com/wp-content/uploads/2026/03/scichart-pricing-infographic.pdf ; https://www.g2.com/products/scichart/pricing ; https://www.npmjs.com/package/scichart
- Highcharts licence types and pricing: https://shop.highcharts.com/license ; https://shop.highcharts.com/
- KLineChart: https://github.com/klinecharts/KLineChart ; https://www.npmjs.com/package/klinecharts
- Lightweight Charts plugin packages (2026-09-16): https://github.com/tradingview/lightweight-charts/releases
- Desktop interop containers: https://interop.io/ ; https://developers.openfin.co/ (now HERE Core docs)
- Apache ECharts: https://github.com/apache/echarts/releases
- uPlot README and benchmarks: https://github.com/leeoniya/uPlot
- Plotly.js: https://github.com/plotly/plotly.js/releases ; https://pypi.org/project/plotly/
- Perspective (OpenJS, @perspective-dev): https://github.com/perspective-dev/perspective ; https://github.com/perspective-dev/perspective/releases ; https://openjsf.org/blog/perspective-joins-openjs
- AG Grid pricing: https://www.ag-grid.com/license-pricing/ ; https://www.npmjs.com/package/ag-grid-community
- Glide Data Grid: https://github.com/glideapps/glide-data-grid
- Connect-ES browser support: https://connectrpc.com/docs/web/getting-started/ ; https://www.npmjs.com/package/@connectrpc/connect
- WebTransport and WebGPU support: https://caniuse.com/webtransport ; https://caniuse.com/webgpu
- Apache Arrow JS: https://www.npmjs.com/package/apache-arrow ; Protobuf-ES: https://www.npmjs.com/package/@bufbuild/protobuf
- Syncfusion Community Licence: https://www.syncfusion.com/products/communitylicense
- TWSE trading rules (ticks, limits, odd-lot): https://www.twse.com.tw/en/page/products/trading/introduce.html
- Shioaji: https://sinotrade.github.io/ ; Fubon Neo API: https://www.fbs.com.tw/TradeAPI/en/docs/welcome/ ; https://www.fbs.com.tw/TradeAPI/en/docs/download/download-sdk
- Notebooks: https://pypi.org/project/jupyterlab/ ; https://pypi.org/project/marimo/ ; https://pypi.org/project/perspective-python/

## Verification log (2026-10)

An adversarial check on 2026-10-05 compared each claim with registries (npm, crates.io, PyPI, NuGet, the Flutter release feed), GitHub releases and tags, raw caniuse data, and vendor licence and pricing pages.

### Confirmed

1. **Tauri:** 2.12.0 (2026-09-26) and 2.12.1 (2026-09-30) on crates.io. v3.0.0-alpha.0 shipped 2026-09-13, and the latest alpha is alpha.4 (2026-10-01). v3 makes the runtime a build-time choice (`tauri::Builder::runtime`; the `wry` and `cef` features were removed). `tauri-runtime-cef` was first published with alpha.0.
2. **TradingView Advanced Charts:** licensed only to companies, free on public, non-paywalled sites with TradingView attribution. It is not for personal, hobby, study or testing use. Trading Platform is paid and connects to the broker's back end.
3. **Lightweight Charts:** 5.2.1 (2026-08-12) under Apache-2.0. You must show the NOTICE text and a link, and `attributionLogo` satisfies the link. Data conflation arrived in 5.1.0 (2025-12-16) and hit-testing in 5.2.0 (2026-04-24). Yield-curve and options charts arrived in 5.0. The 35 / 670 / 900 KB sizes match TradingView's own comparison.
4. **Perspective:** joined the OpenJS Foundation as an incubating project (announced 2025-10-30). It is published as `@perspective-dev/*` 5.5.1 (2026-09-18). `@finos/perspective` stopped at 3.8.0, and the virtual servers (DuckDB, ClickHouse, PostgreSQL, Polars), anywidget and wasm64 builds are all documented.
5. **AG Grid:** Enterprise costs US$999 per developer and the bundle US$1,498, both perpetual with 1 year of updates. Community is MIT. 36.2.0 was released 2026-09-16.
6. **SciChart.js:** 6.0.6 (2026-10-02). The Community edition is free, watermarked and non-commercial. Standard licences are domain- or app-ID-locked. The 50% discount applies under US$1M revenue/funding and fewer than 5 developers (official 2026 pricing infographic).
7. **Electron:** 44.0.0 (2026-08-25) and 44.5.1 (2026-09-30). A new major ships every 8 weeks, and the latest 3 majors are supported.
8. **Flutter:** 3.47.0 (2026-08-12) made Impeller the default on macOS, Windows and Linux (Flutter blog). 3.47.6 was released 2026-10-01.
9. **React Native:** 0.87.0 (2026-08-11; 0.87.1 is the latest). react-native-windows is at 0.84.0 (2026-06-18) and react-native-macos at 0.83.0 (2026-09-30).
10. **Qt:** 6.12 LTS (2026-09-30) has commercial support to 2031-10. Qt Graphs is available only under a commercial licence or GPLv3.
11. **Browser support (caniuse raw data):** WebTransport works in Safari and iOS Safari from 26.4. WebGPU is on by default in Firefox only on Windows and on macOS 26 Apple Silicon (Firefox 145+). In desktop Safari it is on by default only on macOS 26 or later.
12. **Connect-ES:** browsers can make only unary and server-streaming calls, using the Connect or gRPC-web protocols.
13. **Other versions:** Highcharts 13.1.1 (2026-09-20), ECharts 6.1.0 (2026-05-19), uPlot 1.6.32 (2025-03-14; repo commits through 2026-09), Plotly.js 4.1.1 and plotly.py 7.1.0, react-native-skia 2.14.0, Slint 1.18.1, egui 0.36.2, Wails v3 beta.27 (mobile experimental), connect-es 2.2.0, Protobuf-ES 2.16.0, FlatBuffers 25.9.23, MessagePack 3.1.3, apache-arrow 21.2.0, JupyterLab 4.6.4, marimo 0.25.1 and perspective-python 5.5.1.
14. **uPlot README:** ~50 KB, and 166,650 points in 25 ms from a cold start.
15. **Glide Data Grid:** the last stable release is 6.0.3 (2024-02-03). Wording clarified: git alpha tags continue to 2026-01, but the last npm prerelease is 6.0.4-alpha24 (2025-10-08).
16. **Compose Multiplatform:** Android, iOS and Desktop are Stable and Web (Wasm) is Beta.
17. **Avalonia and MAUI:** Avalonia 12 shipped 2026-04-07 (12.1.3 is the latest), and MAUI on Avalonia for Linux and WASM is in preview.
18. **Slint licensing:** GPLv3, royalty-free (not for embedded) or commercial.
19. **Tauri docs:** a minimal app can be under 600 KB. Events carry JSON only and are not meant for high throughput, while Channels are fast and ordered. The notification plugin sends local notifications only.
20. **iOS Web Push:** Home Screen web apps have had Web Push since iOS/iPadOS 16.4.
21. **TWSE rules:** tick sizes by price band, ±10% limits, intraday odd-lot call auctions every 5 s, and five best bid/ask levels.
22. **Taiwan broker APIs:** Shioaji supports Windows, macOS and Linux. Fubon Neo SDK 2.4.0 ships Python wheels for Windows x64 and for macOS and Linux arm64/x64.
23. **Syncfusion Community Licence:** under US$1M revenue, 5 or fewer developers and 10 or fewer employees. Flutter is included.

### Corrected

| Original | Correction | Source |
|---|---|---|
| Compose Multiplatform 1.11 | Current stable is **1.12.1** (2026-09-22). 1.12.0 shipped 2026-08-25 | https://github.com/JetBrains/compose-multiplatform/releases ; https://kotlinlang.org/docs/multiplatform/whats-new-compose-112.html |
| Highcharts Stock: "resellers list it from about US$833" | Official shop prices per developer seat for Core + Stock: Internal US$370/yr or US$850 perpetual; SaaS/External US$732/yr or US$1,678 perpetual; OEM by quote | https://shop.highcharts.com/ |
| Highcharts: "a desktop app needs OEM" | OEM applies only to products customers install or host. Desktop clients of your own service are External (SaaS) applications, and self-use is Internal | https://shop.highcharts.com/license (Standard License Agreement, definitions and §4) |
| Connect RPC in browsers "speaks Connect, gRPC and gRPC-web" | In browsers it speaks only Connect or gRPC-web (`@connectrpc/connect-web`). Plain gRPC needs a server-side runtime | https://connectrpc.com/docs/web/choosing-a-protocol/ |
| SciChart Standard licence: "domain- or app-ID-locked" (incomplete) | It also excludes localhost deployments and is capped at 5 apps and 15,000 users. Advanced (bundle) licences are not domain-locked, which matters for Tauri and Electron origins | https://www.scichart.com/wp-content/uploads/2026/03/scichart-pricing-infographic.pdf |
| TL;DR: Advanced Charts "not free for personal, private or paywalled use" (this implies you could pay for it) | Licensed only to companies and free only on public, non-paywalled sites. Individuals and private or paywalled deployments are not eligible | https://www.tradingview.com/free-charting-libraries/ |
| Omission: no institutional desktop containers | Added interop.io io.Connect (formerly Glue42/Finsemble) and HERE Core (formerly OpenFin) as FDC3 container options for scenario (b) | https://interop.io/ ; https://developers.openfin.co/ |
| Omission: no free chart library with built-in drawing tools | Added KLineChart 10.0.3 (Apache-2.0, ~40 KB gzip, built-in indicators and drawing tools). Also noted the official Lightweight Charts plugin packages (2026-09-16) | https://github.com/klinecharts/KLineChart ; https://github.com/tradingview/lightweight-charts/releases |

Minor additions: Tauri 3.0.0-alpha.4, Electron 45 due 2026-10-20, Avalonia 12.1.3, MAUI 11 at RC, Qt 6.12 open-source patch support ending 2027-04, Perspective's OpenJS incubating status, and Fubon Neo's Windows-based certificate tool.

### Unverifiable

- **SciChart.js per-developer prices (~US$1.3k / 1.7k per year):** SciChart publishes no list prices, and the G2 and SciChart shop pages returned HTTP 403. The figure is kept, labelled as a third-party listing.
- **"WebKitGTK has no WebGPU by default":** no explicit official statement was found. The WebKitGTK 2.54.0 release notes (2026-09-16) do not mention enabling WebGPU, and caniuse does not track WebKitGTK.
- **Installed sizes per shell (Electron 80–150 MB, Flutter 15–40 MB, and so on):** indicative only. No authoritative 2026 measurement was found.
- **TAIFEX after-hours session details:** not re-checked in this pass because the TAIFEX trading-hours page redirected to a 404. The session is long-established (since 2017).
