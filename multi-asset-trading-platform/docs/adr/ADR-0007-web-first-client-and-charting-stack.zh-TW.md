[English](ADR-0007-web-first-client-and-charting-stack.md) | **繁體中文**

# ADR-0007：跨平台前端與圖表：以 Web 為優先的 React 交易工作站，搭配寬鬆授權的圖表函式庫

## 狀態

**提議中（Proposed）** · 2026-10-05 · 範圍：情境 1（第 2 階段 Web 用戶端；第 3 階段可選的外殼），並註記情境 2 的路徑。

## 背景與問題陳述

需求說明要求在桌面、Web 與行動裝置上提供跨平台的使用者介面。1–3 人的團隊無法同時維護多套 UI 程式碼庫。交易 UI 的要求也相當嚴苛：串流報價不能卡頓（jank）、委託狀態不得遺失、密集的圖表、選擇權鏈（option chain）與交易明細表（blotter）、台灣慣例（紅漲配色、五檔報價、TAIFEX T 字報價）以及嚴格的精度。我們應該採用哪一套框架與哪些圖表函式庫？

研究發現（[06](../../research/06-cross-platform-client-ui.zh-TW.md)）：

- **2026-10-05 時的外殼選項：**
  - Web/PWA（iOS 主畫面 Web App 自 iOS 16.4 起已支援 Web Push）。
  - Tauri 2.12.1，v3 處於 alpha 階段（3.0.0-alpha.4）。
  - Electron 44（安裝檔 80–150 MB；每 8 週推出一個新的主要版本）。
  - Flutter 3.47（Dart；金融圖表生態系薄弱）。
  - React Native 0.87（其桌面分支落後於核心版本）。
  - Compose Multiplatform 1.12（Web 處於 Beta）。
  - Avalonia 12 / .NET MAUI。
  - Qt 6.12 LTS（Qt Graphs 採 GPLv3 或商業授權）。
- **圖表授權：**

  | 函式庫 | 授權 | 備註 |
  |---|---|---|
  | TradingView Lightweight Charts 5.2 | Apache-2.0 | 必須保留署名聲明與連結 |
  | TradingView Advanced Charts | 專有授權 | 僅授權給公司，且僅在公開、非付費牆的網站上免費。**個人與私有部署不符合資格** |
  | SciChart.js 6 | 商業授權 | Standard 授權綁定網域或 App ID |
  | Highcharts Stock 13 | 商業授權 | 按席次授權 |
  | uPlot | MIT | 密集序列 |
  | ECharts 6.1 | Apache-2.0 | 報表 |
  | AG Grid Community 36 | MIT | Enterprise 版每位開發者 $999 |
  | KLineChart 10 | Apache-2.0 | 內建繪圖工具 |

- **傳輸。** 不可遺失、具序號的通道（委託、成交、部位、風控）必須與可合併（conflatable）的通道（報價、Greeks、損益標記價）分開。解碼應在 UI 執行緒之外進行。
- **精度。** JavaScript 的數字是二進位浮點數，因此價格必須以十進位字串傳輸（[ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.zh-TW.md)）。
- **安全性。** Web 與行動用戶端絕不能持有交易場所（venue）金鑰（[ADR-0008](ADR-0008-key-and-secret-management.zh-TW.md)）。
- **範圍。** 方案 A 將三種外殼（Web、Tauri、PWA 推播）都放進 MVP。可行性評審將此標記為關鍵路徑風險，因此延後實施（[評估](../../architecture/evaluation.zh-TW.md)，嫁接項 36）。

## 決策驅動因素

- 單一程式碼庫，1–3 人團隊即可維護。
- 即時效能，且不遺失委託事件。
- 授權條款既適合現階段自用，也適合日後可能的付費服務。
- 價格與數量的精確顯示。
- 台灣在地化，同時兼顧美股與加密貨幣慣例。
- 不需重寫即可延伸至桌面與行動裝置的路徑。

## 考慮的選項

**外殼**

1. **以 Web 為優先的 React + TypeScript（Vite）工作站，搭配 Telegram/ntfy**，並在第 3 階段可選擇加入 Tauri 2 桌面外殼與 PWA Web 推播。
2. **Tauri 2 桌面與行動裝置加上 PWA，全部納入 MVP**（方案 A 的原始範圍）。
3. **Electron** 桌面應用。
4. **Flutter** 支援所有目標平台。
5. **React Native** 行動 App 加上一個 Web App。
6. **原生工具組**（Qt、Avalonia）。

**圖表與表格**

1. **寬鬆授權組合：** Lightweight Charts 5.2、uPlot、ECharts 6.1、AG Grid Community 36，需要繪圖工具時再加上 KLineChart。
2. **TradingView Advanced Charts 或 Trading Platform。**
3. **商業 WebGL 函式庫**（SciChart.js 或 Highcharts Stock）。
4. **僅使用 Plotly 或 Perspective。**

## 決策結果

**選定選項：外殼 1 與圖表 1。** Web 工作站是之後所有外殼都會包裝的單一程式碼庫。Telegram/ntfy 不需行動 App 即可提供行動警示與緊急指令，而圖表組合則全部採用寬鬆授權。

| 領域 | 決策 |
|---|---|
| 第 2 階段用戶端 | React + TypeScript（Vite）**Web 工作站**，由 `api` 容器以靜態資源提供，且只能透過 Tailscale 存取。顯示部位、委託、成交、圖表、回測報告、限額、對帳狀態、模擬/實盤橫幅以及緊急停止開關（kill switch）。PWA manifest 幾乎不需成本，因此提早上線 |
| 情境 1 的行動端 | **Telegram/ntfy**：警示、`/status`、`/halt`、`/flatten` 與 `/approve`（僅限待核准的提案），並需輸入確認 PIN。Telegram 永遠不能調高限額或輸入自由格式的委託。可選的 **LINE Messaging API** 通知器僅發送警示（LINE Notify 已於 2025-03-31 終止服務） |
| 半自動交易 | 工作站提供下單介面（order ticket），在送出前顯示交易前檢查結果，並提供附到期倒數計時的提案核准佇列（[建議架構](../../architecture/recommended-architecture.zh-TW.md) §3.13） |
| 第 3 階段（可選） | **Tauri 2.12** 桌面外殼（在 v3 處於 alpha 期間鎖定於 2.x），用於以作業系統鑰匙圈（OS keychain）儲存 API 權杖及多視窗使用；**PWA Web 推播**。兩者都包裝同一套 Web 程式碼 |
| 情境 2 | **React Native 0.87** 輔助 App（APNs/FCM 推播、生物辨識核准），共用 TypeScript 領域套件與 Protobuf 套件；若需要鎖定版本的 Chromium 或 FDC3 互通，則採用 **Electron**；另建立設計系統與小工具（widget）SDK |
| 圖表 | 價格圖表使用 **Lightweight Charts 5.2**，並保持 TradingView 署名可見（`attributionLogo`）。密集序列使用 **uPlot**。報表與績效摘要（tear sheet）使用 **ECharts 6.1**。若需要互動式繪圖工具則使用 **KLineChart** |
| 表格與小工具 | 交易明細表與選擇權鏈使用 **AG Grid Community 36**。第 3 階段新增自訂的 Canvas TAIFEX T 字報價與 DOM 價格階梯（DOM ladder） |
| 目前不採用 | TradingView Advanced Charts（我們不符合資格）；SciChart.js 與 Highcharts Stock（成本考量，除非情境 2 的密度需求足以支持）；AG Grid Enterprise（情境 2）；Flutter 與 Qt（會多出第二種 UI 語言） |
| 傳輸 | FastAPI 閘道。指令與查詢使用 REST；Connect RPC 為替代方案。**單一 WebSocket** 內分通道：不可遺失且具序號的通道（`orders`、`fills`、`positions`、`risk`、`alerts`；快照加增量，具缺口偵測與重新同步）以及可合併的通道（`quotes`、`greeks`、`pnl_marks`，表格為 4–10 Hz，圖表最多為顯示更新率）。Protobuf 結構描述，優先採用 JSON 映射。回測產出物使用 Arrow IPC |
| 精度與時間 | 價格與數量採用**十進位字串**；奈秒時間戳記以字串傳輸並解析為 `BigInt`（[ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.zh-TW.md)）。委託狀態不使用浮點數相等比較 |
| 繪製 | 由 Web Worker 解碼並合併資料。UI 每個 `requestAnimationFrame` 繪製一次。圖表以 `series.update()` 更新即時 K 棒，絕不在每個 tick 呼叫 `setData()` |
| 在地化 | 可設定漲跌配色（台灣紅漲、美股與加密貨幣綠漲），並提供色盲友善配色；Asia/Taipei 與紐約時區（含夏令時間）；為 24/7 的加密貨幣定義每日切點；UI 與警示字串以 react-i18next（或 FormatJS）外部化，並提供每位使用者的 zh-TW/en 切換；依地區設定使用 `Intl.NumberFormat`，包括萬/億簡潔表示法；為圖表、Canvas 小工具與 PDF 報告內嵌 CJK 字型（Noto Sans TC）；商品名稱取自證券主檔中的 `name_zh_tw`/`name_en`（[建議架構](../../architecture/recommended-architecture.zh-TW.md) §3.11） |
| 安全規則 | 用戶端絕不持有交易場所金鑰，也絕不為商品定價。實盤指令需要二次確認。變更限額需要重新驗證身分並填寫原因 |

### 影響

**正面**

- 單一 TypeScript 程式碼庫即可服務瀏覽器、桌面（Tauri）與 PWA，情境 2 的 React Native App 也能共用其領域套件與合約套件。
- 授權成本近乎為零，日後提供付費服務時也沒有授權陷阱；唯一的義務是署名。
- 不可遺失/可合併通道的分離，可同時避免成交遺失與 UI 卡頓。
- 從第 2 階段起即具備行動警示與緊急控制，不需要另外進行 App Store 上架專案。

**負面**

- 情境 1 沒有原生行動 App。iOS 會暫停背景 socket，因此在 PWA 推播或 React Native 到位之前，推播依賴 Telegram/ntfy。
- 免費圖表函式庫缺乏內建技術指標（Lightweight Charts）或機構等級的密度（沒有 WebGL 百萬點圖表）。技術指標改在後端或 worker 中計算。
- 若加入 Tauri 外殼，會出現 webview 差異（Linux 上的 WebKitGTK 最弱）。必須在三種引擎上都進行測試，否則就改用 Electron。
- uPlot 很少發布新版本。因此以我們自己的元件 API 加以包裝。

### 驗證

- CI 建置 Web bundle，並對 npm 相依樹執行授權檢查（[ADR-0009](ADR-0009-open-source-licensing-strategy.zh-TW.md)）。
- 以 UI 測試斷言 TradingView 署名為可見。
- 以合約測試驗證不可遺失通道上的快照加增量重新同步與缺口偵測。
- 以 lint 規則禁止在價格與數量欄位上使用 `Number()`/`parseFloat`。

### 何時重新檢視

- 第 3 階段需要作業系統鑰匙圈儲存、多視窗交易桌面或 Web 推播 → 加入 Tauri 2 或 PWA 推播。
- 對外提供服務（T1）→ 在 backend-for-frontend 中導入 OIDC + PKCE 與 WebAuthn、每位使用者的權限設定與延遲資料旗標；若服務公開，則採用需授權的圖表方案。
- 密度或 3D 波動率曲面成為必要功能 → 在預算範圍內評估 SciChart.js 或 Highcharts。
- Tauri v3 進入穩定版 → 重新評估其 CEF 執行環境選項。

## 連結

- [主報告：前端、圖表/表格以及 API/UI 傳輸相關列](../../README.zh-TW.md)
- [建議架構 §3.10 與 §3.11](../../architecture/recommended-architecture.zh-TW.md)
- [評估紀錄：嫁接項 18 與 36；疑慮 20](../../architecture/evaluation.zh-TW.md)
- 研究：[06 跨平台用戶端與圖表](../../research/06-cross-platform-client-ui.zh-TW.md) · [08 安全性](../../research/08-risk-security-ops-compliance.zh-TW.md)
- 相關 ADR：[ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.zh-TW.md) · [ADR-0008](ADR-0008-key-and-secret-management.zh-TW.md) · [ADR-0009](ADR-0009-open-source-licensing-strategy.zh-TW.md) · [ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.zh-TW.md)
