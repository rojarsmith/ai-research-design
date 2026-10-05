[English](06-cross-platform-client-ui.md) | **繁體中文**

# 06 — 跨平台用戶端、圖表與即時視覺化

> 研究面向 06。研究日期：2026-10-05。版本與日期取自 npm、crates.io、PyPI 與 pub.dev 套件登錄庫（registry）以及廠商頁面。購買任何產品前，請再次確認授權與價格。

## TL;DR

- **建置一個 TypeScript/React「工作站」網頁應用程式並加以包裝。不要採用原生 UI 工具組。**
  - 將應用程式發佈到瀏覽器。
  - 在桌面端以 **Tauri 2.12** 包裝：安裝檔極小、Rust 核心，並支援 iOS/Android 目標平台。
  - 若需要在每台桌面上固定使用同一版 Chromium，則改用 **Electron 44**。
  - 行動端是精簡的 *監控／警示／核准／全部平倉（flatten）* 輔助應用程式（companion），而非完整移植。
- **預設視覺技術堆疊：**
  - 價格圖表使用 TradingView **Lightweight Charts 5.2**。它採 Apache-2.0 授權，但必須標示來源（attribution）。
  - 密集序列使用 **uPlot**，報表使用 **ECharts 6.1**。
  - 可同時在筆記本（notebook）中執行的串流樞紐分析（pivot）使用 **Perspective 5.5**。它現為 OpenJS Foundation 專案，以 `@perspective-dev/*` 發佈。
  - 交易明細表（blotter）與選擇權鏈（option chain）使用 **AG Grid 36**。
  - **TradingView Advanced Charts 僅授權給公司，且僅在公開、非付費牆（non-paywalled）的網站上免費。** 個人、業餘／測試用途，以及私有或付費牆部署皆不符資格。需要機構級資料密度時，請編列 **SciChart.js 6** 或 **Highcharts Stock 13** 的預算。
- **傳輸：**
  - 市場資料與委託狀態使用二進位 WebSocket：Protobuf 封包（envelope）、快照加上帶序號的增量（delta），並在伺服器端依訂閱者進行合併（conflation）。
  - 指令使用 **Connect RPC**，大量欄式資料使用 **Arrow IPC**。
  - WebTransport 現已在所有主要瀏覽器引擎中提供（Safari 26.4+），但仍為選用。
- **資產類別改變的是元件，而非框架：**
  - 加密貨幣：24/7 L2 深度。
  - 股票：交易時段、公司行動（corporate actions）、台灣紅漲綠跌配色，以及依價格區間而異的升降單位。
  - 選擇權：選擇權鏈、Greeks、波動率曲面，以及 TAIFEX T 字報價（T-quote）。
  - 債券：價格↔殖利率、曲線、詢價（RFQ）。

## 關鍵問題

1. 哪種外殼（shell）能在桌面、網頁與行動裝置間提供最大的重用度，又不會限制圖表效能？
2. 哪些圖表與表格（grid）授權適合各種用途：個人自用、付費服務，或免費公開網站？
3. 如何串流高頻率資料，同時不造成卡頓（jank）也不遺失委託事件？
4. 筆記本與交易 UI 如何共用資料、圖表與結果？
5. 各資產類別有何不同？台灣與美國及加密貨幣市場相比又有何不同？

## 方案比較

### 1. 應用程式外殼

安裝大小僅供參考。

| 方案（2026 年 10 月） | 目標平台 | 繪製方式 | 大小 | 即時圖表 | 與網頁共用 UI | 授權／狀態 |
|---|---|---|---|---|---|---|
| **Web / PWA**（React/TS） | 任何瀏覽器。iOS 主畫面應用程式自 iOS 16.4 起支援 Web Push | DOM、Canvas、WebGL、WebGPU | 無 | 在 Chromium 上表現極佳，但瀏覽器由使用者選擇。無 keychain、無本機 SDK、多視窗支援薄弱 | 100% | 不適用 |
| **Tauri 2.12**（2.12.1，2026-09-30；**v3 alpha 自 2026-09-13 起**，3.0.0-alpha.4 於 2026-10-01） | Win、macOS、Linux、iOS、Android | 作業系統 webview（WebView2、WKWebView、WebKitGTK、Android WebView）。v3 中執行環境（runtime）改為建置時選擇，包括 **CEF（Chromium）** | 最小 <600 KB；實際應用程式 3–15 MB | 在 WebView2 與 WKWebView 上表現良好，在 WebKitGTK 上最弱。Rust→JS **Channels** 可傳遞有序、高吞吐量的資料（events 僅支援 JSON） | ~90–100% | MIT/Apache-2.0；非常活躍 |
| **Electron 44**（44.5.1，2026-09-30） | 桌面 | 內建 Chromium；每 8 週推出新主版本；支援最新 3 個主版本（Electron 45 預計 2026-10-20 推出，屆時 42 將結束支援） | 80–150 MB | 最可預測：各處皆為同一引擎 | 桌面 ~100% | MIT；非常活躍 |
| **Flutter 3.47**（3.47.6） | 全部六個平台 | 自有繪製器（renderer）；Impeller 於 2026-08-12 成為桌面預設 | 15–40 MB | 繪製流暢，但金融圖表函式庫很少（Syncfusion、fl_chart） | 與 TS 網頁共用 0% | BSD-3；活躍 |
| **React Native 0.87**（+ RN-Windows 0.84、RN-macOS 0.83） | 行動端為一等支援；桌面透過 Microsoft 的分支（fork） | 原生 view + Skia（react-native-skia 2.14） | 20–50 MB | 搭配 Skia 表現良好。務實的圖表路線是在 WebView 中使用 Lightweight Charts | 共用邏輯與型別，UI 大多不共用 | MIT；**桌面分支落後核心 3–4 個次版本** |
| **Compose Multiplatform 1.12**（1.12.1，2026-09-22） | Android、iOS 與 Desktop 為穩定版；Web（Wasm）為 **Beta** | Skia | 50+ MB（JVM） | 良好；金融函式庫很少 | 各自獨立 | Apache-2.0 |
| **Avalonia 12**（12.0 於 2026-04-07；最新 12.1.3）／**.NET MAUI 10**（MAUI 11 處於 RC） | Avalonia：桌面、行動、WASM。MAUI：Linux 與網頁僅能透過 Avalonia 後端預覽版 | Skia | 30–80 MB | 桌面表現強；SciChart 提供原生 .NET 圖表 | 各自獨立 | MIT，另有付費附加元件 |
| **Qt 6.12 LTS**（2026-09-30） | 桌面、行動、WASM | C++/QML GPU 場景圖（scene graph） | 20–60 MB | 原始效能最高 | 各自獨立 | LGPLv3、GPLv3 或商業授權。**Qt Graphs 僅提供 GPLv3 或商業授權**。商業 LTS 支援至 2031；6.12 的開源修補支援於 2027-04 結束 |
| **Wails v3**（beta）· **Slint 1.18** · **egui 0.36** | Wails：桌面（行動端為實驗性）。Slint 與 egui：桌面、行動、網頁 | Wails：webview。Slint 與 egui：原生 GPU | 小 | egui 非常適合密集的內部工具 | Wails 高；Slint 與 egui 無 | MIT。Slint 為 GPLv3、免權利金（非嵌入式）或商業授權 |

**機構級桌面容器（未列於上表）：** **interop.io io.Connect Desktop**（前身為 Glue42；Finsemble 也隸屬 interop.io）與 **HERE Core**（前身為 OpenFin）是具備 FDC3 互通能力、以 Chromium 為基礎的商業容器，用於銀行與買方（buy-side）交易台。它們只在情境 (b) 中才有意義，而且僅限應用程式必須與其他廠商的桌面應用程式共享上下文（context）時。它們會增加授權成本並造成廠商鎖定。

### 2. 圖表函式庫

| 函式庫 | 最新版本 | 授權／成本 | 繪製器 | 交易適用性 | 限制 |
|---|---|---|---|---|---|
| **TradingView Lightweight Charts** | 5.2.1（2026-08-12） | Apache-2.0。**必須**顯示 NOTICE 來源標示及指向 tradingview.com 的連結；`attributionLogo` 選項即可滿足連結要求 | Canvas，~35 KB | 多窗格（v5）、外掛與自訂序列、殖利率曲線與選擇權圖表類型、資料合併（v5.1）、命中測試（hit-testing，v5.2）。自 2026-09-16 起提供官方外掛套件（`@tradingview/lwc-toolkit` 加上十個外掛） | 無內建技術指標或繪圖工具 |
| **TradingView Advanced Charts / Trading Platform** | 私有儲存庫，需經核准才能取得 | 專有授權。Advanced Charts **僅對在公開、非付費牆網站上並帶有 TradingView 品牌標示的公司**免費；不供個人、業餘或測試用途。Trading Platform 需付費 | ~670 / ~900 KB | 100+ 種技術指標、繪圖工具。Trading Platform 另加下單面板、DOM 與券商轉接器（broker adapter）。行動端透過 WebView | 不含資料；其他情況費用需另行報價 |
| **SciChart.js** | 6.0.6（2026-10-02） | 商業授權。SciChart 未公布定價；第三方列表（G2）顯示每位開發者每年約 US$1.3k（2D）／1.7k（2D+3D）（未經驗證，請索取報價）。免費的 Community 版帶有浮水印且限非商業用途。**Standard 授權鎖定於已知主機名稱或應用程式 ID，不涵蓋 localhost 部署，且最多涵蓋 5 個應用程式與 15,000 名使用者。** Advanced（套裝）授權不鎖定網域。營收或募資低於 US$1M 且開發者少於 5 人的單一實體可享 50% 折扣 | WebGL + WASM | 即時處理數百萬個資料點、3D 波動率曲面、熱圖。提供原生 WPF、iOS 與 Android 版本 | 成本。Tauri 與 Electron 的來源（origin）（`tauri://localhost`、`http://tauri.localhost`、`file://`）可能需要應用程式 ID 金鑰或 Advanced 授權 |
| **Highcharts Stock** | 13.1.1（2026-09-20） | 依開發者席位計費的商業授權。Core + Stock 的官方商店價格：Internal 用途 US$370/年或 US$850 永久；SaaS/External US$732/年或 US$1,678 永久；OEM 需報價。非商業用途另有條款 | SVG + WebGL 加速（boost） | 導覽器（navigator）、技術指標、無障礙功能。適合報表 | 在逐筆（tick）頻率下速度慢。只有當產品由你的客戶自行安裝或託管時才需要 OEM。你自有服務的桌面用戶端屬於 External（SaaS）應用程式 |
| **Apache ECharts** | 6.1.0（2026-05-19） | Apache-2.0 | Canvas/SVG，另有 GL 用於 3D | 儀表板、績效報告頁（tear sheet）、熱圖 | ~1 MB；並非為逐筆串流而設計 |
| **uPlot** | 1.6.32（2025-03；儲存庫仍活躍） | MIT | Canvas 2D，~50 KB | 冷啟動 25 ms 繪製 166,650 個資料點。權益曲線、延遲圖 | API 極簡；很少發佈新版 |
| **Plotly.js / plotly.py** | 4.1.1 / 7.1.0 | MIT | SVG + WebGL | 筆記本與應用程式使用相同的 figure JSON | 笨重；不適合串流 |
| **Perspective** | 5.5.1（2026-09-18） | Apache-2.0。**已從 FINOS 移至 OpenJS Foundation**（孵化專案，2025-10-30 宣布）；`@finos/perspective` 停在 3.8.0（2025-09） | C++→WASM + WebGL | 串流 Arrow、樞紐分析與聯結（join）。可在 DuckDB、ClickHouse、PostgreSQL 與 Polars 之上建立虛擬伺服器。Jupyter anywidget。wasm64 支援超過 4 GB 的資料 | UI 設計較具主觀取向（opinionated） |
| **KLineChart**（驗證時新增） | 10.0.3（2026-08-27） | Apache-2.0 | Canvas，gzip 後 ~40 KB，零相依套件 | 內建技術指標與畫線工具。由於 Advanced Charts 不提供給個人，對需要繪圖功能的個人使用者而言是免費選項 | 生態系比 TradingView 小；無廠商 SLA |

**GPU 基準：**
- **WebGL2 已全面普及。** WebGPU 僅作為漸進式增強（progressive enhancement）。
- **WebGPU 預設啟用**於 Chrome/Edge（Linux 視驅動程式而定）、iOS 26 與 macOS 26+ 上的 Safari，以及 Windows 與 macOS 26 Apple Silicon 上的 Firefox。
- **Linux 上的 Tauri：** WebKitGTK 預設不支援 WebGPU。

### 3. 表格與專用元件

| 表格 | 最新版本 | 授權 | 用途 |
|---|---|---|---|
| **AG Grid** | 36.2.0（2026-09-16） | Community 為 MIT。Enterprise 為**每位開發者 US$999**，屬永久授權並含 1 年更新；搭配 AG Charts 則為 US$1,498 | 交易明細表、部位、選擇權鏈。使用非同步交易（async transactions）與儲存格閃爍。Enterprise 另加樞紐分析、伺服器端資料列模型與匯出 |
| **Glide Data Grid** | 6.0.3 穩定版（2024-02）；alpha 標籤持續至 2026-01（npm 最後一個預發佈版本為 6.0.4-alpha24，2025-10） | MIT | Canvas，數百萬列。**有維護風險** |
| **Perspective datagrid** | 5.5.1 | Apache-2.0 | 臨機（ad-hoc）樞紐分析、損益歸因 |
| **自訂 Canvas/WebGL** | 不適用 | 不適用 | DOM 價格階梯（DOM ladder）、深度熱圖、T 字報價：以價格為索引的資料列，60 fps |

### 4. 後端到 UI 的傳輸與編碼

| 機制 | 瀏覽器能力 | 最適用於 | 注意事項 |
|---|---|---|---|
| **WebSocket** | 雙向、普遍支援 | 市場資料、委託與部位更新 | 訂閱、序號、心跳、重新同步與背壓（backpressure）都需自行處理 |
| **SSE** | 伺服器→用戶端、普遍支援 | 警示、回測進度 | 僅限文字；受 HTTP/1.1 連線數上限限制 |
| **gRPC-web** | Unary + 伺服器串流，需透過代理 | 已使用 gRPC 的團隊 | 不支援用戶端串流或雙向串流 |
| **Connect RPC**（connect-es 2.2.0） | Unary + 伺服器串流。在瀏覽器中使用 Connect 或 gRPC-web 協定；純 gRPC 需要伺服器端執行環境，例如 Node | 指令、查詢、具型別的合約（Protobuf-ES 2.16） | 瀏覽器無法從用戶端串流；不適合作為逐筆資料多工器 |
| **WebTransport** | Chrome、Edge、Firefox 與 Safari/iOS 26.4+ 支援串流 + 資料包（datagram） | 每個商品一條串流，無隊頭阻塞（head-of-line blocking） | 企業網路常封鎖 QUIC；請保留 WebSocket 備援 |
| **NATS over WebSocket** | Pub/sub | 若 NATS 為訊息匯流排，可快速做出 MVP（見 [07](07-system-architecture-messaging.zh-TW.md)） | 會暴露匯流排；權限（entitlements）控管變得更困難 |

**編碼：**
- **Protobuf** 是 RPC 與 WebSocket 封包的預設合約格式，可為 TS、Rust、Python、Dart、Swift 與 Kotlin 產生程式碼。
- **FlatBuffers**（25.9）可為大型委託簿或選擇權鏈快照提供零複製（zero-copy），但應*在效能分析之後*才採用。
- **MessagePack**（3.1）無綱要（schemaless），合約約束力弱。
- **Arrow IPC**（apache-arrow 21.2）將 K 棒歷史、權益曲線與交易清單直接送入 Perspective、DuckDB-WASM 與 uPlot 的具型別陣列（typed array）。
- **JSON** 僅供除錯使用。

**節流與合併規則：**
1. **無損通道：** 委託、成交、部位與風控違規皆帶序號，絕不丟棄。
2. **可合併通道：** 報價、深度、Greeks 與損益評價（P&L marks）每個鍵僅保留最新值。
3. **在伺服器端依訂閱者合併：** 表格 4–10 Hz，圖表最多為螢幕更新率。行動裝置與隱藏分頁使用較低的層級。
4. **解碼不佔用 UI 執行緒：** 由 **Web Worker** 解碼並合併至具型別陣列或 Arrow。UI 每個 `requestAnimationFrame` 繪製一次，絕不每則訊息繪製一次。SharedArrayBuffer 需要 COOP/COEP 標頭。
5. **委託簿**為快照加上帶序號的增量，具備缺口偵測與重新同步。僅繪製前 N 檔。
6. **以增量方式更新圖表：** 即時 K 棒使用 `series.update()`，而非 `setData()`。

### 5. 研究筆記本與 UI

| 模式 | 結論 |
|---|---|
| **共用資料平面。** JupyterLab 4.6.4 與 marimo 0.25.1（見 [09](09-research-ml-analytics.zh-TW.md)）讀取與應用程式相同的 Parquet/Arrow 儲存區與查詢 API。回測輸出 Arrow/Parquet 加上 JSON 清單檔（manifest），由應用程式繪製報告（見 [02](02-backtesting-engine.zh-TW.md)） | **建議採用** |
| **共用元件。** 筆記本中的 Perspective anywidget 與應用程式中的 `<perspective-viewer>` 使用相同的設定 JSON。Plotly figure JSON 可攜 | 建議用於分析 |
| 應用程式內的**嵌入式筆記本** | 之後再做，且僅供進階使用者。kernel 本質上就是程式碼執行，因此需要隔離 |
| 透過相同 OMS API 將**筆記本作為交易用戶端** | 僅能經過相同的風控檢查與模擬／實盤旗標。絕不可將券商金鑰放在筆記本中 |

## 本面向的資產類別差異

| | 股票（美國、TWSE/TPEx） | 加密貨幣 | 選擇權（美國、TAIFEX TXO） | 債券 |
|---|---|---|---|---|
| **更新** | 受交易時段限制；L1 加深度（台灣五檔） | 24/7、多個交易場所、高頻率 L2 | 每個標的有數千個合約；Greeks 每個 tick 都會變動 | 稀疏或僅供參考的報價；詢價（RFQ） |
| **關鍵元件** | K 線、自選清單、DOM 價格階梯、還原權值歷史 | 深度圖、委託簿熱圖、資金費率 | 選擇權鏈表格／**T 字報價**、隱含波動率微笑與曲面、損益圖（payoff）、多腳委託單 | 殖利率曲線、價格↔殖利率、淨價／全價 + 應計利息、DV01 |
| **規則／格式** | 台灣升降單位依價格區間而異；±10% 漲跌停；盤中零股每 5 秒集合競價一次 | 8–18 位小數：使用十進位字串，而非 JS `number` | 契約乘數；週選與月選到期 | 美國公債以 1/32 報價 |
| **時間** | Asia/Taipei；紐約含夏令時間 | UTC，永不收盤 | TAIFEX 盤後交易時段（夜盤） | 交割與計息天數慣例 |
| **串流** | 依商品合併 | 大量合併、前 N 檔深度 | **在伺服器端切片**：僅串流可見的履約價 | 事件驅動（event-driven） |

**台灣：**
- 漲跌顏色必須是使用者設定，因為台灣是紅漲，而美國與加密貨幣市場是綠漲。也應提供色盲友善配色。
- Shioaji（永豐 SinoPac）與富邦 Neo API（Fubon Neo API）可跨平台執行。Fubon Neo SDK 2.4.0 提供 Windows x64 以及 macOS 與 Linux（arm64 與 x64）的 Python wheel，但其憑證輔助工具以 Windows 為基礎。
- 僅支援 Windows 的券商 SDK 應放在後端閘道（[07](07-system-architecture-messaging.zh-TW.md)），絕不放在用戶端。

## 建議

### (a) 個人／1–3 人 MVP

1. **單一程式碼庫：**
   - React + TS + Vite，建置為響應式網頁應用程式，並以 **Tauri 2.12** 封裝。
   - Rust 端負責 keychain 與本機 Parquet。
   - 固定使用 2.x，在 v3 穩定前先跳過。
   - 行動端先以 PWA 起步。只有在需要上架應用程式商店時，才為*精簡*的路由集合加入 Tauri 行動版建置。
2. **圖表：** Lightweight Charts 5.2 並顯示來源標示，密集序列使用 uPlot，回測報告使用 ECharts。在後端或 worker 中計算技術指標。若需要互動式繪圖工具，請評估 KLineChart（Apache-2.0），而非自行打造。
3. **表格：** 交易明細表與選擇權鏈使用 AG Grid Community；探索與筆記本使用 Perspective。
4. **傳輸：** 一條使用 Protobuf 並在伺服器端合併的 WebSocket，加上 Connect RPC，再加上用於產出物（artifact）的 Arrow IPC。
5. **此階段應避免：**
   - TradingView Advanced Charts：你不符資格。
   - SciChart 與 Highcharts：成本。
   - Flutter 與 Qt：第二種 UI 語言。
   - 嵌入式 Jupyter。

### (b) 5–20 人團隊／機構級

1. **相同的網頁核心**，加上 monorepo 設計系統與元件 SDK。
2. **桌面外殼：**
   - **Electron**：用於固定版本的 Chromium、多螢幕工作區與 FINOS FDC3 互通。只有在必須與其他廠商的桌面應用程式互通時，才使用商業 FDC3 容器（interop.io，或前身為 OpenFin 的 HERE Core）。
   - **Tauri**：若佔用空間與 Rust 安全邊界更重要。
   - 待 **Tauri v3 CEF 執行環境**穩定後重新評估。
3. **行動端：** 原生 **React Native 0.87** 輔助應用程式，共用 TS 領域（domain）與 Protobuf 套件。提供 APNs/FCM 推播、生物辨識委託核准與緊急停止開關（kill switch）。
4. **圖表：**
   - **SciChart.js** 或 Highcharts Stock：用於資料密度、3D 曲面與廠商 SLA。
   - **TradingView Advanced Charts 或 Trading Platform**：僅適用於經營公開或已授權之對客戶服務的公司。Trading Platform 也要求你自備券商後端來提供資料串流與委託管理。
5. **表格：** AG Grid Enterprise 加上 Perspective。將 DOM 價格階梯與 T 字報價建置為自訂 Canvas/WebGL 元件。
6. **閘道：** UI 閘道／BFF 處理每位使用者的權限、合併層級、重新同步與稽核。WebTransport 為選擇性啟用（opt-in）。
7. **特定語言團隊：**
   - C#：Avalonia 12 搭配 SciChart .NET。
   - 對可見延遲敏感的工具（維運或 HFT 監控器）：商業授權的 Qt 6.12 LTS，或 egui。這些工具應與面向客戶的應用程式分開。

### 單一程式碼庫 vs 最高效能

| 目標 | 技術堆疊 | 共用 UI | 取捨 |
|---|---|---|---|
| 最大化單一程式碼庫 | React/TS + Tauri 2（桌面 + 行動）+ PWA | ~90–95% | webview 差異；行動端 UX 需妥協 |
| **平衡（預設）** | React/TS + Tauri 或 Electron + React Native 輔助應用程式 | UI ~70–80%，邏輯 ~90% | 兩套 UI 層 |
| 最高效能 | Electron + SciChart WebGL + worker 資料平面；延遲工具使用 Qt 或 egui | ≤50% | 成本、技能、授權 |
| 單一非網頁工具組 | Flutter 3.47，全部目標平台 | Dart 中 ~95% | 金融圖表生態系薄弱；無法重用 TS |

## 對整體架構的影響

- **UI 閘道是必要的。** 這與 [07](07-system-architecture-messaging.zh-TW.md) 一致。閘道負責：
  - OIDC + PKCE 驗證
  - 市場資料權限與延遲資料旗標，因為交易所的顯示授權依使用者計算
  - 依訂閱者合併
  - 快照／增量序號管理
  - 將匯流排訊息轉譯為透過 WebSocket 與 Connect 傳輸的 Protobuf
- **合約優先。** 單一 Protobuf 儲存庫，以 `buf breaking` 檢查，產生 TS、Rust、Python 與行動端用戶端。
- **研究與 UI 只透過產出物交會。** 回測與研究輸出為 Arrow/Parquet 加上清單檔。
- **用戶端執行 worker 資料平面，並以每個畫格排程繪製。** 若使用 SharedArrayBuffer，託管環境必須送出 COOP/COEP 標頭，這會限制第三方 iframe。
- **桌面外殼僅提供能力：** keychain、通知、視窗與檔案系統。交易邏輯留在伺服器端。
- **每個用戶端都需要安全控制：** 委託確認、全部平倉、緊急停止開關，以及模擬／實盤橫幅。

## 風險與陷阱

- **TradingView 授權。** Advanced Charts 無法用於私有或付費牆用途。若隱藏 `attributionLogo` 而未在其他地方標示 TradingView，即違反 Lightweight Charts 授權。
- **Webview 差異。** Linux 上的 Tauri（WebKitGTK）較慢且缺少 WebGPU，而 WKWebView 也有其特有問題。請在三種引擎上都進行測試，或以 Electron 或 Tauri v3 CEF 固定 Chromium 版本。
- **變動頻繁。** Tauri v3 改變了執行環境的選擇方式。React Native 桌面分支落後核心。Compose Web 仍為 Beta。Perspective 的 npm scope 已更名。
- **停滯的相依套件。** Glide 自 2024-02 起就沒有穩定版發佈，uPlot 也很少發佈新版。請將兩者包裝在你自己的元件 API 之後。
- **授權陷阱。** Qt Graphs 僅提供 GPLv3 或商業授權，而 LGPL 帶有重新連結（relinking）義務。SciChart Standard 授權鎖定於主機名稱或應用程式 ID，且不涵蓋 localhost 部署。Highcharts 授權取決於使用對象：自用為 Internal，你自己面向客戶的應用程式（包括桌面用戶端）為 SaaS/External，而 OEM 僅適用於由你的客戶安裝或託管的產品。
- **精確度。** 價格與數量請使用十進位字串或縮放整數。絕不可對委託狀態使用浮點數相等比較。
- **更新風暴。** 每個 tick 都解析 JSON 並重新繪製 React，會造成 GC 卡頓。請使用 worker、合併與命令式（imperative）圖表更新。
- **行動端背景限制。** iOS 會暫停 socket，因此警示需要推播。Tauri 官方的通知外掛只能傳送本機通知。
- **時間與交易時段。** 須考量美國夏令時間、TAIFEX 夜盤以及 24/7 的加密貨幣市場。

## 參考資料

- Tauri 版本發佈與 2.12 版說明: https://v2.tauri.app/release/tauri/ ; https://v2.tauri.app/blog/tauri-2.12/
- Tauri v3.0.0-alpha.0（執行環境選擇、CEF）: https://newreleases.io/project/github/tauri-apps/tauri/release/tauri-v3.0.0-alpha.0 ; https://crates.io/crates/tauri
- Tauri 應用程式大小與 Channels: https://v2.tauri.app/start/ ; https://v2.tauri.app/develop/calling-frontend/
- Tauri 外掛與通知外掛: https://v2.tauri.app/plugin/ ; https://v2.tauri.app/plugin/notification/
- Electron 支援與版本: https://endoflife.date/electron ; https://releases.electronjs.org/
- Flutter 3.47 桌面版 Impeller: https://startdebugging.net/2026/08/flutter-3-47-impeller-default-renderer-on-desktop/ ; https://docs.flutter.dev/release/release-notes
- React Native 部落格（0.84–0.87）: https://reactnative.dev/blog ; https://www.npmjs.com/package/react-native-windows ; https://www.npmjs.com/package/react-native-macos
- Compose Multiplatform 1.12 與穩定性等級: https://kotlinlang.org/docs/multiplatform/whats-new-compose-112.html ; https://github.com/JetBrains/compose-multiplatform/releases ; https://kotlinlang.org/docs/multiplatform/supported-platforms.html
- Avalonia 12 與 Avalonia MAUI 後端: https://avaloniaui.net/blog ; https://avaloniaui.net/blog/net-maui-is-coming-to-linux-and-the-browser-powered-by-avalonia
- .NET MAUI 支援政策: https://dotnet.microsoft.com/en-us/platform/support/policy/maui
- Qt 版本、Qt Graphs 授權、Small Business 方案: https://endoflife.date/qt ; https://doc.qt.io/qt-6/qtgraphs-index.html ; https://www.qt.io/pricing ; https://www.qt.io/qt-for-small-business
- Wails v3 狀態: https://docs-preview.wails.io/status/
- Slint 授權: https://slint.dev/pricing ; egui: https://crates.io/crates/egui
- 網頁應用程式的 iOS Web Push: https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/
- TradingView 函式庫與授權: https://www.tradingview.com/free-charting-libraries/ ; https://www.tradingview.com/charting-library-docs/latest/introduction/
- Lightweight Charts 授權、NOTICE 與版本說明: https://github.com/tradingview/lightweight-charts ; https://tradingview.github.io/lightweight-charts/docs/release-notes ; https://www.npmjs.com/package/lightweight-charts
- SciChart.js 授權與定價: https://www.scichart.com/documentation/js/v4/user-manual/licensing-scichart-js/getting-started-for-free/ ; https://www.scichart.com/wp-content/uploads/2026/03/scichart-pricing-infographic.pdf ; https://www.g2.com/products/scichart/pricing ; https://www.npmjs.com/package/scichart
- Highcharts 授權類型與定價: https://shop.highcharts.com/license ; https://shop.highcharts.com/
- KLineChart: https://github.com/klinecharts/KLineChart ; https://www.npmjs.com/package/klinecharts
- Lightweight Charts 外掛套件（2026-09-16）: https://github.com/tradingview/lightweight-charts/releases
- 桌面互通容器: https://interop.io/ ; https://developers.openfin.co/ （現為 HERE Core 文件）
- Apache ECharts: https://github.com/apache/echarts/releases
- uPlot README 與效能基準: https://github.com/leeoniya/uPlot
- Plotly.js: https://github.com/plotly/plotly.js/releases ; https://pypi.org/project/plotly/
- Perspective（OpenJS、@perspective-dev）: https://github.com/perspective-dev/perspective ; https://github.com/perspective-dev/perspective/releases ; https://openjsf.org/blog/perspective-joins-openjs
- AG Grid 定價: https://www.ag-grid.com/license-pricing/ ; https://www.npmjs.com/package/ag-grid-community
- Glide Data Grid: https://github.com/glideapps/glide-data-grid
- Connect-ES 瀏覽器支援: https://connectrpc.com/docs/web/getting-started/ ; https://www.npmjs.com/package/@connectrpc/connect
- WebTransport 與 WebGPU 支援: https://caniuse.com/webtransport ; https://caniuse.com/webgpu
- Apache Arrow JS: https://www.npmjs.com/package/apache-arrow ; Protobuf-ES: https://www.npmjs.com/package/@bufbuild/protobuf
- Syncfusion Community 授權: https://www.syncfusion.com/products/communitylicense
- TWSE 交易規則（升降單位、漲跌幅限制、零股）: https://www.twse.com.tw/en/page/products/trading/introduce.html
- Shioaji: https://sinotrade.github.io/ ; Fubon Neo API: https://www.fbs.com.tw/TradeAPI/en/docs/welcome/ ; https://www.fbs.com.tw/TradeAPI/en/docs/download/download-sdk
- 筆記本: https://pypi.org/project/jupyterlab/ ; https://pypi.org/project/marimo/ ; https://pypi.org/project/perspective-python/

## 驗證紀錄（2026-10）

2026-10-05 進行的對抗式查核，將每項主張與套件登錄庫（npm、crates.io、PyPI、NuGet、Flutter 版本發佈資訊）、GitHub 版本發佈與標籤、caniuse 原始資料，以及廠商授權與定價頁面逐一比對。

### 已確認

1. **Tauri：** crates.io 上有 2.12.0（2026-09-26）與 2.12.1（2026-09-30）。v3.0.0-alpha.0 於 2026-09-13 發佈，最新 alpha 為 alpha.4（2026-10-01）。v3 將執行環境改為建置時選擇（`tauri::Builder::runtime`；移除了 `wry` 與 `cef` features）。`tauri-runtime-cef` 首次隨 alpha.0 發佈。
2. **TradingView Advanced Charts：** 僅授權給公司，在公開、非付費牆且標示 TradingView 來源的網站上免費。不供個人、業餘、學習或測試用途。Trading Platform 需付費，並連接券商的後端。
3. **Lightweight Charts：** 5.2.1（2026-08-12），採 Apache-2.0 授權。必須顯示 NOTICE 文字與連結，而 `attributionLogo` 可滿足連結要求。資料合併於 5.1.0（2025-12-16）加入，命中測試於 5.2.0（2026-04-24）加入。殖利率曲線與選擇權圖表於 5.0 加入。35 / 670 / 900 KB 的大小與 TradingView 官方的比較相符。
4. **Perspective：** 以孵化專案身分加入 OpenJS Foundation（2025-10-30 宣布）。以 `@perspective-dev/*` 5.5.1（2026-09-18）發佈。`@finos/perspective` 停在 3.8.0，而虛擬伺服器（DuckDB、ClickHouse、PostgreSQL、Polars）、anywidget 與 wasm64 建置皆有文件記載。
5. **AG Grid：** Enterprise 每位開發者 US$999，套裝 US$1,498，兩者皆為永久授權並含 1 年更新。Community 為 MIT。36.2.0 於 2026-09-16 發佈。
6. **SciChart.js：** 6.0.6（2026-10-02）。Community 版免費、帶浮水印且限非商業用途。Standard 授權鎖定網域或應用程式 ID。50% 折扣適用於營收／募資低於 US$1M 且開發者少於 5 人者（官方 2026 定價資訊圖表）。
7. **Electron：** 44.0.0（2026-08-25）與 44.5.1（2026-09-30）。每 8 週推出新主版本，並支援最新 3 個主版本。
8. **Flutter：** 3.47.0（2026-08-12）使 Impeller 成為 macOS、Windows 與 Linux 上的預設（Flutter 部落格）。3.47.6 於 2026-10-01 發佈。
9. **React Native：** 0.87.0（2026-08-11；最新為 0.87.1）。react-native-windows 為 0.84.0（2026-06-18），react-native-macos 為 0.83.0（2026-09-30）。
10. **Qt：** 6.12 LTS（2026-09-30）的商業支援至 2031-10。Qt Graphs 僅以商業授權或 GPLv3 提供。
11. **瀏覽器支援（caniuse 原始資料）：** WebTransport 自 26.4 起可在 Safari 與 iOS Safari 使用。WebGPU 在 Firefox 中僅於 Windows 與 macOS 26 Apple Silicon 上預設啟用（Firefox 145+）。在桌面版 Safari 中，僅於 macOS 26 或更新版本預設啟用。
12. **Connect-ES：** 瀏覽器只能進行 unary 與伺服器串流呼叫，使用 Connect 或 gRPC-web 協定。
13. **其他版本：** Highcharts 13.1.1（2026-09-20）、ECharts 6.1.0（2026-05-19）、uPlot 1.6.32（2025-03-14；儲存庫提交持續至 2026-09）、Plotly.js 4.1.1 與 plotly.py 7.1.0、react-native-skia 2.14.0、Slint 1.18.1、egui 0.36.2、Wails v3 beta.27（行動端為實驗性）、connect-es 2.2.0、Protobuf-ES 2.16.0、FlatBuffers 25.9.23、MessagePack 3.1.3、apache-arrow 21.2.0、JupyterLab 4.6.4、marimo 0.25.1 與 perspective-python 5.5.1。
14. **uPlot README：** ~50 KB，冷啟動 25 ms 繪製 166,650 個資料點。
15. **Glide Data Grid：** 最後一個穩定版為 6.0.3（2024-02-03）。措辭已釐清：git alpha 標籤持續至 2026-01，但 npm 最後一個預發佈版本為 6.0.4-alpha24（2025-10-08）。
16. **Compose Multiplatform：** Android、iOS 與 Desktop 為 Stable，Web（Wasm）為 Beta。
17. **Avalonia 與 MAUI：** Avalonia 12 於 2026-04-07 發佈（最新為 12.1.3），而基於 Avalonia、支援 Linux 與 WASM 的 MAUI 處於預覽階段。
18. **Slint 授權：** GPLv3、免權利金（不適用於嵌入式）或商業授權。
19. **Tauri 文件：** 最小應用程式可小於 600 KB。Events 僅攜帶 JSON，且並非為高吞吐量設計，而 Channels 快速且有序。通知外掛僅傳送本機通知。
20. **iOS Web Push：** 主畫面網頁應用程式自 iOS/iPadOS 16.4 起支援 Web Push。
21. **TWSE 規則：** 依價格區間而異的升降單位、±10% 漲跌幅限制、盤中零股每 5 秒集合競價一次，以及最佳五檔買賣價。
22. **台灣券商 API：** Shioaji 支援 Windows、macOS 與 Linux。Fubon Neo SDK 2.4.0 提供 Windows x64 以及 macOS 與 Linux arm64/x64 的 Python wheel。
23. **Syncfusion Community 授權：** 營收低於 US$1M、開發者 5 人以下且員工 10 人以下。包含 Flutter。

### 已更正

| 原內容 | 更正 | 來源 |
|---|---|---|
| Compose Multiplatform 1.11 | 目前穩定版為 **1.12.1**（2026-09-22）。1.12.0 於 2026-08-25 發佈 | https://github.com/JetBrains/compose-multiplatform/releases ; https://kotlinlang.org/docs/multiplatform/whats-new-compose-112.html |
| Highcharts Stock：「經銷商標價約從 US$833 起」 | 每個開發者席位的 Core + Stock 官方商店價格：Internal US$370/年或 US$850 永久；SaaS/External US$732/年或 US$1,678 永久；OEM 需報價 | https://shop.highcharts.com/ |
| Highcharts：「桌面應用程式需要 OEM」 | OEM 僅適用於由客戶安裝或託管的產品。你自有服務的桌面用戶端屬於 External（SaaS）應用程式，自用則屬 Internal | https://shop.highcharts.com/license （Standard License Agreement，定義與 §4） |
| 瀏覽器中的 Connect RPC「使用 Connect、gRPC 與 gRPC-web」 | 在瀏覽器中僅使用 Connect 或 gRPC-web（`@connectrpc/connect-web`）。純 gRPC 需要伺服器端執行環境 | https://connectrpc.com/docs/web/choosing-a-protocol/ |
| SciChart Standard 授權：「鎖定網域或應用程式 ID」（不完整） | 它也不涵蓋 localhost 部署，且上限為 5 個應用程式與 15,000 名使用者。Advanced（套裝）授權不鎖定網域，這對 Tauri 與 Electron 的來源（origin）很重要 | https://www.scichart.com/wp-content/uploads/2026/03/scichart-pricing-infographic.pdf |
| TL;DR：Advanced Charts「個人、私有或付費牆用途不免費」（這暗示你可以付費取得） | 僅授權給公司，且僅在公開、非付費牆網站上免費。個人以及私有或付費牆部署皆不符資格 | https://www.tradingview.com/free-charting-libraries/ |
| 遺漏：未列出機構級桌面容器 | 新增 interop.io io.Connect（前身為 Glue42/Finsemble）與 HERE Core（前身為 OpenFin），作為情境 (b) 的 FDC3 容器選項 | https://interop.io/ ; https://developers.openfin.co/ |
| 遺漏：未列出內建繪圖工具的免費圖表函式庫 | 新增 KLineChart 10.0.3（Apache-2.0，gzip 後 ~40 KB，內建技術指標與繪圖工具）。另註記官方 Lightweight Charts 外掛套件（2026-09-16） | https://github.com/klinecharts/KLineChart ; https://github.com/tradingview/lightweight-charts/releases |

次要補充：Tauri 3.0.0-alpha.4、Electron 45 預計於 2026-10-20 推出、Avalonia 12.1.3、MAUI 11 處於 RC、Qt 6.12 開源修補支援於 2027-04 結束、Perspective 的 OpenJS 孵化狀態，以及 Fubon Neo 以 Windows 為基礎的憑證工具。

### 無法驗證

- **SciChart.js 每位開發者價格（每年約 US$1.3k / 1.7k）：** SciChart 未公布定價，G2 與 SciChart 商店頁面皆回傳 HTTP 403。保留此數字，並標註為第三方列表資料。
- **「WebKitGTK 預設不支援 WebGPU」：** 未找到明確的官方說明。WebKitGTK 2.54.0 版本說明（2026-09-16）未提及啟用 WebGPU，而 caniuse 不追蹤 WebKitGTK。
- **各外殼的安裝大小（Electron 80–150 MB、Flutter 15–40 MB 等）：** 僅供參考。未找到權威的 2026 年量測資料。
- **TAIFEX 盤後交易時段細節：** 本輪未重新查核，因為 TAIFEX 交易時間頁面重新導向至 404。該時段已行之有年（自 2017 年起）。
