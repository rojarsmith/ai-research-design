[English](10-open-source-platforms-build-vs-buy.md) | **繁體中文**

# 既有平台（開源與商業）及自建或採購（Build vs. Buy）

> 研究面向 10。快照日期：2026-10-05。GitHub 活動數據於當日透過 GitHub REST API 取得：commits 為 2026-01-01 以來預設分支上的 commits；issue 結案數計算的是 2026 年 4 月至 9 月間開立、並於快照日前已關閉的 issues。授權條款、價格與版本很快就會過時，因此在做任何採購或法律決策之前，請重新查證。

## TL;DR

- **沒有任何既有產品能同時涵蓋四大資產類別、台灣市場以及跨平台 UI。** 所有主流開源引擎都缺少可交易的債券：NautilusTrader 與 LEAN 都沒有債券商品（instrument）類型。（IBKR 等券商確實可透過其 API 接受債券委託單，因此缺口在於商品模型與分析功能，而非交易場所的接入。）所有主流開源引擎也都缺少台灣市場（TWSE/TAIFEX）。唯一具備台灣連接器的引擎 StockSharp **已於 2026-07-16 脫離開源**，且其台灣連接器位於另一個獨立的 `StockSharp/Connectors` repo（建立於 2026-07-13），該 repo 從頭到尾都只附帶專有授權聲明。
- **實際可作為核心的引擎有兩個。** **NautilusTrader**（LGPL-3.0、Rust 核心，最活躍的專案，2026 年 commits 達 4.5k，但其 v2 仍是 release candidate 且帶有破壞性變更，上游也不建議以 RC 進行真實資金的實盤交易）。**QuantConnect LEAN**（Apache-2.0、C#/.NET 10，最穩定的選擇，美國選擇權與期貨的涵蓋度最佳，NuGet 發布頻繁：2026-08-21 至 2026-09-25 之間發布了五次）。
- **建議。** 個人開發者或 1-3 人團隊應 **Extend（擴充）NautilusTrader**；若團隊偏重 C# 或聚焦美國選擇權，則改用 LEAN，並基於 Shioaji 或 Fubon Neo 自行撰寫台灣 adapter。5-20 人或機構級團隊應 **Build（自建）** 自有的 OMS、風控、帳本（ledger）與資料平面（data plane），並將引擎 **Integrate（整合）** 於策略執行環境（strategy-runtime）port 之後。除非有強烈的觸發條件，否則任何人都不應 **fork**。
- **授權陷阱確實存在，而且會變動。** OpenBB 自 2024 年 5 月起採用 AGPL-3.0，直到 v5.0.0（2026-09-29）才改回 Apache-2.0。vectorbt 附帶 Commons Clause。Freqtrade、backtrader 與 Lumibot 為 GPL-3.0。StockSharp 現已轉為專有授權。請鎖定版本，並在 CI 中掃描授權。
- **將商業終端機作為選用的前端或交易訊號來源，而非核心。** 這包括 MT5、cTrader、NinjaTrader、MultiCharts、TradingView、Sierra Chart 與 XQ。每一個都會將你綁定在其腳本語言、其支援的券商與其 EULA 上。

## 關鍵問題

1. 哪個引擎可以作為核心，又不會阻礙未來推出閉源或 SaaS 產品？
2. 哪些引擎能在股票、加密貨幣、債券與選擇權上，提供真正的回測與實盤一致性（backtest-live parity），也就是使用相同的策略程式碼與事件驅動（event-driven）成交？
3. 目前誰涵蓋台股與台灣期交所（TAIFEX）期貨及選擇權？授權成本為何？
4. 2025-2026 年的維護與 bus factor 風險為何？
5. 何時應該 Build（自建）、Fork（分叉）、Extend（擴充；以某產品作為核心）或 Integrate（整合；借用元件）？

## 選項比較

### 1. 開源生態概況：活躍度與授權

| 專案 | 語言 | 授權（商業影響） | 最新版本 | 2026 年 commits | 已關閉 issues（2026 年 4-9 月） | Stars | 狀態 |
|---|---|---|---|---|---|---|---|
| NautilusTrader | Rust 核心 + Python（PyO3） | LGPL-3.0：閉源策略沒有問題；若你散布引擎本身，對引擎的修改必須公開 | v1.231.0 穩定版（2026-08-02）；v2.0.0rc5（2026-09-15） | ~4,536 | 531/605（88%） | 29.6k | 非常活躍；v2 為 Rust 原生重寫。v1 僅獲得關鍵安全性修補的回移（backport）（在 `develop_v1` 上，於 v2 切換後約三個月內） |
| QuantConnect LEAN | C#（.NET 10）+ Python | Apache-2.0：最寬鬆 | NuGet 2.5.18127（2026-09-25） | 343 | 78/105（74%） | 21.9k | 活躍；透過 NuGet 持續發布，GitHub 上的 "releases" 已過時 |
| Hummingbot | Python/Cython | Apache-2.0 | v2.17.0（2026-09-22） | 1,541 | 48/69（70%） | 20.3k | 活躍，每 1-2 個月發布一次；加密貨幣造市 |
| Freqtrade | Python | GPL-3.0：copyleft 適用於你散布的任何東西 | 2026.9（2026-09-29） | 2,396 | 103/104（99%） | 55.0k | 非常活躍，每月發布；僅支援加密貨幣 |
| vectorbt（開源版） | Python/Numba | Apache-2.0 **+ Commons Clause**（不得販售它或以它為基礎的服務） | 1.1.1（2026-09-26）；1.0.0 於 2026-04-22 發布 | 154 | 4/5 | 9.3k | 活躍；單一維護者 |
| vectorbt PRO | Python | 專有會員制：個人使用限「個人、非商業」用途，商業使用需另行議約 | 滾動更新 | n/a | n/a | 私有 | $25/月、$240/年或 $500 終身 |
| backtrader | Python | GPL-3.0 | 1.9.78.123（2023-04-19） | 0（最後一次 push 為 2024-08） | n/a | 23.4k | **無人維護** |
| Zipline-reloaded | Python | Apache-2.0 | 3.1.1（2025-07） | 0 | n/a | 2.0k | 僅做維護 |
| QuantRocket | Python、Docker（Zipline/Moonshot） | 商業訂閱（Non-Professional 或 Professional） | 2.11.0（2025-01-28） | n/a | n/a | n/a | 2026 年無新版本 |
| OpenBB（ODP） | Python | **自 v5 起為 Apache-2.0**；2024 年 5 月至 2026 年 9 月為 AGPL-3.0 | 5.0.0（2026-09-29） | 96 | 25/40（63%） | 73.9k | 僅提供資料，無下單執行；repo 現在會解析至 `openbq-org/OpenBB` |
| StockSharp | C# | **自 2026-07-16 起為專有授權**，先前為 Apache-2.0；其 EULA 禁止衍生著作 | 持續有 commits（tags 已過時） | 1,143 | 3/4 | 10.8k | 活躍，但**已不再開源**。免費方案（1 個連接器）；Premium 首年 $995、Ultimate 首年 $1,995 |
| Jesse | Python（Rust 指標） | MIT 核心；**實盤交易需要付費授權外掛** | 3.2.4（2026-10-01） | 377 | 10/17（59%） | 8.6k | 活躍；僅支援加密貨幣 |
| Lumibot | Python | GPL-3.0 | 4.6.4（2026-10-03） | 1,766 | 3/17（18%） | 2.1k | 發布快速，但關閉的 issues 很少 |
| hftbacktest | Rust + Python（Numba） | MIT | Python 2.4.4 / rust-v0.9.4（2025-12-10） | 0（最後一次 push 為 2025-12-23） | 4/10 | 4.8k | 單一維護者，2026 年沉寂 |
| Qlib（Microsoft） | Python | MIT | 0.9.7（2025-08-15） | 16 | 9/30（30%） | 49.1k | 僅限 ML 研究；活躍度正在下降 |
| VeighNa（vn.py） | Python、Qt 桌面 GUI | MIT | 4.4.0（2026-05-14） | 36 | 21/22（95%） | 45.7k | 活躍；以中國大陸市場為主（CTP 期貨與選擇權、A 股、ETF 選擇權），外加 IB gateway；無台灣 gateway |

### 2. 能力矩陣：資產類別、台灣、一致性

圖例：● 原生支援或達正式環境（production）等級，◐ 部分支援、視券商而定或透過社群外掛，○ 無。

| 專案 | 股票 | 加密貨幣 | 債券 | 選擇權 | 台灣（TWSE/TAIFEX） | 交易場所與券商 adapters | 回測與實盤一致性 | 跨平台 |
|---|---|---|---|---|---|---|---|---|
| NautilusTrader | ●（IB、Databento） | ●（Binance、Bybit、OKX、Coinbase、Kraken、Deribit、Hyperliquid、dYdX、Lighter、Polymarket） | ○（無 Bond 類型） | ●（OptionContract/OptionSpread、Greeks） | ○（需自建 adapter） | ~14 個交易場所 + Databento/Tardis 資料 | ●（相同程式碼，奈秒級事件引擎） | Linux、macOS ARM、Windows |
| LEAN | ●（美國與印度股票） | ●（Binance、Bybit、Coinbase、Kraken、Bitfinex、dYdX） | ○ | ●（股票、指數與期貨選擇權） | ○ | 23 個券商項目（含 QC 模擬交易、通用 FIX 及一組 CFD/FX），包括 IB、Schwab、Tradier、Alpaca、Bloomberg EMSX | ● | Windows、Linux、macOS、Docker |
| Hummingbot | ○ | ●（CEX、CLOB DEX 與 AMM DEX 連接器；README 引用使用者在 140+ 個交易場所的交易量） | ○ | ○ | ○ | 僅加密貨幣 | ◐ | Docker |
| Freqtrade | ○ | ●（約 12 個交易所的現貨、7 個交易所的期貨） | ○ | ○ | ○ | 基於 CCXT | ●（dry-run） | Windows、macOS、Linux |
| vectorbt / PRO | ◐（與資料來源無關的研究工具） | ◐ | ◐ | ◐ | ◐（若自備資料） | 無 | ○（僅供研究） | 任何 Python 環境 |
| QuantRocket | ● | ○ | ○ | ● | ○ | IB、Alpaca | ● | Docker |
| OpenBB | 資料 | 資料 | 資料（固定收益 router） | 資料 | ◐（資料供應商） | 無 | ○ | 任何 Python 環境、REST、MCP |
| StockSharp | ● | ● | ◐ | ● | **●**（Yuanta SPARK、Fubon Neo、SinoPac Shioaji、Taishin Nova、TWSE OpenAPI；位於專有的 `StockSharp/Connectors` repo） | 389+ 個連接器 | ● | .NET、以 Windows 為主的 GUI |
| Jesse | ○ | ● | ○ | ○ | ○ | 加密貨幣 | ● | Docker |
| Lumibot | ● | ◐（CCXT） | ○ | ●（ThetaData、Polygon） | ○ | Alpaca、IB、Tradier、Schwab、Tradovate、ProjectX | ● | 任何 Python 環境 |
| hftbacktest | ○ | ●（L2/L3、佇列與延遲模型） | ○ | ○ | ○ | Binance Futures、Bybit | ● | Rust/Python |
| Qlib | ●（中國/美國研究） | ○ | ○ | ○ | ○ | 無 | ○ | 任何 Python 環境 |
| VeighNa（vn.py） | ●（A 股；海外市場透過 IB） | ○（無官方加密貨幣 gateway） | ○（僅資料源） | ●（CTP、ETF 選擇權；OptionMaster Greeks 與波動率曲面） | ○ | CTP 系列、XTP、TORA、IB 等 | ●（相同的 CTA 策略範本） | Windows、Linux、macOS |

### 3. 商業平台

| 平台 | 擁有者與模式（2026） | 價格 | 腳本語言 | 涵蓋範圍 | 台灣 | 裝置 | 對我們的適用性 |
|---|---|---|---|---|---|---|---|
| MetaTrader 5 | MetaQuotes；透過券商散布 | 交易者免費；由券商支付授權費 | MQL5；Python 套件**僅支援 Windows**（5.0.6231，2026-09-27）；MCP 與 agentic AI 支援於 build 6060（2026-07-23）推出，AI Assistant 並持續擴充至 build 6230（2026-09-24） | 主要為 FX/CFD；交易所上市的股票、期貨與選擇權僅在券商提供時才有 | 非台灣主流管道 | Windows、Mac、Web、行動裝置 | 選用的 FX/CFD 執行 adapter |
| cTrader | Spotware；透過券商散布 | 透過券商免費使用 | C# 與 Python（cTrader Algo）、雲端 cBots、Open API | FX/CFD | ○ | Windows、Mac、Web、行動裝置 | 選用的 FX/CFD adapter |
| NinjaTrader | **Kraken（Payward）**，於 2025-03-20 宣布以 $1.5B 收購 | 免費、$99/月或 $1,499 終身（付費方案手續費較低） | NinjaScript（C#） | 美國期貨，包括 Micro Bitcoin 與個股期貨（現貨股票與加密貨幣列於 Kraken 的產品路線圖） | ○ | 桌面（Windows）、Web、行動裝置 | 僅作為期貨前端 |
| MultiCharts | 商業 | 訂閱或終身授權（僅於結帳時顯示）；資料 $49/月 | PowerLanguage（類 EasyLanguage）、.NET、Python beta | 50+ 個券商與資料源，包括 IB 與加密貨幣交易所 | ◐ | Windows | 策略原型開發 |
| TradingView | 商業 SaaS | 約 US$13-200/月（Essential 至 Ultimate，按年計費）；所有付費方案（Essential 以上）皆提供 webhooks | Pine Script v6（每月更新，最新為 2026 年 9 月） | 所有資產類別的圖表；透過特定券商交易 | ◐（圖表） | Web、桌面、行動裝置 | 透過 webhooks 作為訊號來源；圖表 UX 標竿 |
| Sierra Chart | 商業 | $26-56/月的方案 | ACSIL（C++） | 以期貨為主（CQG、Rithmic、IB、Denali） | ○ | Windows | 低延遲期貨桌面軟體 |
| XQ 全球贏家（XQ） | 嘉實資訊（SysJust） | 未公開；通常透過券商取得 | XScript（XS） | 台股、台灣期交所期貨與選擇權、美股 | **●**（26 家合作台灣券商；自動交易中心（automated trading）） | Windows、Mac、iPad、iPhone | 實現台灣自動化交易的最快途徑，但為封閉系統 |

### 4. 作為平台核心的主要選項

| 準則 | A. Extend NautilusTrader | B. Extend LEAN（自行託管） | C. 購買 QuantConnect Cloud | D. Build 核心 + Integrate | E. 商業終端機 + webhooks |
|---|---|---|---|---|---|
| 閉源或 SaaS 適用性 | 良好。LGPL：保持引擎不修改，或公開你的修補。若散布的二進位檔靜態連結 Rust crates，會帶來重新連結（relink）義務 | 最佳（Apache-2.0） | 受其服務條款約束；程式碼與資料存放於其基礎設施上 | 完全掌控 | EULA；不得再散布 |
| 股票 / 加密貨幣 / 債券 / 選擇權 | ● / ● / ○ / ● | ● / ● / ○ / ● | ● / ● / ○ / ● | 全部自行建置 | 視券商而定 |
| 台灣 | 撰寫 adapter（Shioaji、Fubon Neo） | 撰寫 brokerage 外掛 | ○ | 自行撰寫 | XQ ● |
| 回測與實盤一致性 | ● | ● | ● | 要達成的代價高昂 | ◐ |
| 延遲上限 | 微秒級 Rust 核心 | 毫秒級（.NET） | 共用雲端 | 取決於設計 | 毫秒級，零售等級 |
| API 穩定性（2026） | ◐（v2 RC 重新命名設定；rc4 造成破壞性變更；上游不建議以 RC 進行真實資金的實盤交易） | ● | ● | 由你自行掌控 | ● |
| MVP 所需時間（估計） | 1-3 個月 | 1-3 個月 | 數週 | 9-18 個月 | 數天 |
| 鎖定（lock-in） | 低至中 | 低 | 高（資料授權權益、基礎設施） | 無 | 高（專有語言） |
| 成本 | 免費；已宣布 Pro 方案（候補名單，未公布價格） | 免費，另加你購買的資料 | Researcher $84/月、Team $168/月、Trading Firm $480/月、Institution $1,272/月 | 工程人員薪資 | 訂閱費 |

### 5. Build / Fork / Extend / Integrate：觸發條件

| 策略 | 意義 | 何時選擇（觸發條件） | 何時避免 |
|---|---|---|---|
| **Extend**（擴充；作為核心使用） | 不修改地執行 Nautilus 或 LEAN，並在**獨立的套件**中加入 adapters、策略與服務 | 團隊 3 人以下；約 6 個月內需要實盤交易；你的商品符合引擎的模型；你接受上游的發布節奏 | 你需要債券或對核心進行深度修改；你必須在未經法律審查的情況下，發布內嵌 LGPL 程式碼的桌面二進位檔 |
| **Fork**（分叉） | 維護一份經修補的引擎副本 | 上游拒絕你需要的變更（例如 Bond 商品類型，或台灣規則，如漲跌幅限制、升降單位（tick ladder）、零股（odd lots）與當沖（day trading））；變更深入撮合或領域模型；你有 2 名以上工程師負責 rebase | 上游演進快速：Nautilus 在 9 個月內約有 4.5k commits，因此 fork 在數週內就會偏離。在 LGPL 下，你必須公開你所散布的、經修改的引擎檔案 |
| **Build**（自建） | 自有的 OMS/EMS、風控、帳本、權限（entitlements）、資料平面與 UI | 你要**對他人提供服務**（多租戶、稽核、法遵）；需要債券或 RFQ 工作流程；跨券商風險淨額計算；嚴格的延遲或 SLA 要求；5 名以上工程師且有 12 個月以上的資金跑道（runway） | MVP 階段；單一交易者 |
| **Integrate**（整合；借用元件） | 在你自己的介面之後使用函式庫 | 對非核心部分一律適用：OpenBB v5（資料，Apache-2.0）、vectorbt（研究參數掃描，內部使用）、Qlib（ML 因子）、hftbacktest（加密貨幣市場微結構）、QuantLib（債券與選擇權定價，BSD 風格授權）、券商 SDK（Shioaji、Fubon Neo、IB） | 在你散布或販售的任何產品中含有 GPL 或 Commons Clause 程式碼 |

## 四大資產類別在此面向上的差異

| 資產類別 | 開源成熟度 | 現有最佳涵蓋 | 你必須自建或採購的部分 |
|---|---|---|---|
| **股票** | 高 | LEAN（美國與印度）、透過 IB 的 Nautilus、Lumibot、Zipline（研究） | **台灣**：券商 adapter 加上市場規則（±10% 漲跌幅限制、升降單位級距、盤中零股（intraday odd lots）、當沖（day trading）、T+2 交割、以交易單位（張）計的整股）。只有 StockSharp（現為專有授權）與 XQ（封閉）具備這些 |
| **加密貨幣** | 最高，且競爭擁擠 | Nautilus、Freqtrade、Hummingbot、Jesse、hftbacktest | 很少。風險在於 API 頻繁變動與交易所倒閉：Freqtrade 2026.8 在 Bitmart 停止營運後將其移除 |
| **債券** | **最低** | 僅有資料（OpenBB 固定收益）；LEAN 與 Nautilus 都沒有可交易的債券類型。QuantLib 提供定價數學，IBKR 的 TWS API 可透過 CUSIP 或 conId 接受 `BOND` 合約 | 商品模型（應計利息、殖利率與存續期間、日數計算慣例）、RFQ/OTC 執行、定價來源。**自建**模型與工作流程；分析功能重用 QuantLib，上市債券的執行則使用 IBKR 等券商 API |
| **選擇權** | 中 | LEAN（選擇權鏈，股票、指數與期貨選擇權）、Nautilus（OptionContract/OptionSpread、Greeks；IB 與 Deribit）、Lumibot（ThetaData） | 透過 Shioaji 或 Fubon Neo 取得 TAIFEX TXO（台指選擇權）選擇權鏈與保證金；波動率曲面與 Greeks 服務；OPRA 規模的資料成本。商業圖表工具在選擇權回測方面表現薄弱 |

## 依情境的建議

### (a) 個人開發者或 1-3 人團隊的 MVP

1. **核心：在 v2 線上 Extend NautilusTrader。** v1 只會收到關鍵安全性修補的回移，且僅限 v2 切換後約三個月內，因此應從 v2 開始。鎖定確切的 RC 或穩定版 tag，並將引擎包裝在一層精簡的策略與 adapter 介面之後，以便吸收重新命名所帶來的變動。上游不建議以 RC 進行真實資金的實盤交易，因此 RC 僅用於開發、回測與模擬交易（paper trading），真實資金交易則須等到穩定版 2.0.0 發布，或通過你自己的長時間穩定性測試（soak test）後才開放。若團隊以 C# 為主，或主要產品為美國股票與指數選擇權，則改選 **LEAN**。
2. **台灣：** 基於 **Shioaji**（1.7.7，2026-09-29；Windows、Linux 與 macOS；股票、期貨與選擇權）撰寫 Nautilus 的資料與執行 adapter。若你是富邦客戶，則使用 Fubon Neo。將台灣市場規則編寫於你自己的模組中。若在任何程式碼完成之前就需要台灣自動化交易，可並行使用 **XQ** 執行手動或 XS 策略。
3. **研究：** 使用 vectorbt 進行快速參數掃描（僅限內部使用），使用 Qlib 進行 ML 因子研究。再將候選策略提升至事件驅動引擎做最終驗證。
4. **資料：** 使用 OpenBB v5（Apache-2.0）作為研究資料閘道。**避免使用 4.2 至 4.7.x**，這些版本為 AGPL-3.0（4.0 與 4.1 仍為 MIT）。
5. **只做加密貨幣，且本週就需要可用的東西？** Freqtrade 用於自用沒有問題。不要在它之上建構多資產產品（GPL、僅支援加密貨幣的模型）。
6. **UI：** 沒有任何引擎附帶跨平台的終端使用者 UI。請針對你自己的 API 建構精簡用戶端（以 Web 優先），並將引擎保留在伺服器端。

### (b) 5-20 人團隊或機構等級

1. **Build** 平台骨幹：標準化（canonical）的商品與委託單模型（包括債券）、OMS/EMS、交易前風控、部位與現金帳本、權限、稽核日誌、資料目錄。
2. 將引擎作為可插拔的**策略執行環境（strategy runtime）**加以 **Integrate**。Nautilus 適合 Rust/Python 技術棧，以及對延遲敏感的加密貨幣與期貨業務；LEAN 適合 .NET 技術棧與美國選擇權。VeighNa（MIT，Python 搭配 Qt 桌面 GUI）只有在透過 CTP 交易中國大陸期貨很重要時，才是第三個候選；它沒有台灣 gateway，也沒有官方加密貨幣 gateway。將引擎放在 port 之後，且不要 fork。
3. **債券與台灣是你自己的程式碼。** 請明確為其編列預算。只能在 StockSharp 的 EULA 規範下評估其台灣連接器；衍生著作是被禁止的，而 StockSharp 較舊的 Apache-2.0 快照並不包含這些連接器。
4. **將商業選項評估為採購（buy）面的加速方案。** 若資料條款允許，可考慮以 QuantConnect Institution（$1,272/月）進行雲端研究；待 Nautilus Pro（執行演算法、風控、儀表板）達到 GA 並公布條款後，也可納入考量。
5. **法律：** 針對任何要散布的二進位檔，就 LGPL 靜態連結（Rust）取得授權審查。禁止在發布的成品中包含 GPL 與 Commons Clause 程式碼，並在 CI 中執行 SPDX 掃描。

## 對整體架構的影響

- **引擎選擇決定語言技術棧。** Nautilus 代表 Rust 加 Python；LEAN 代表 C#/.NET 加 Python。請優先做出此決策，並記錄為 ADR。
- **採用六角形架構（hexagonal design）。** 定義 `StrategyRuntime`、`ExecutionAdapter`、`MarketDataAdapter` 與 `ReferenceData` 這幾個 ports。領域模型屬於你自己，因此引擎的型別永遠不會洩漏到 UI 或 OMS 中。這也能將授權義務（LGPL）侷限在可替換的模組內。
- **引擎在伺服器端執行。** 桌面與行動用戶端保持精簡（API 加 WebSocket），且絕不內嵌 copyleft 引擎。
- **對 GPL 工具使用行程邊界（process boundary）。** 若你確實要使用 Freqtrade 或 Lumibot，請將其作為 API 後方的獨立服務執行，並請法律顧問確認衍生著作的界線。
- **將資料層視為共用資產。** Nautilus 的 Parquet 目錄、LEAN 的資料格式與 vectorbt 都接受欄式（columnar）資料。統一採用 Arrow/Parquet，讓研究與實盤交易讀取相同的歷史資料。

## 風險與陷阱

- **API 頻繁變動。** Nautilus v2 RC 移除了舊版 Cython 套件（rc3，2026-08-21），並重新命名核心設定（例如在 rc4 中，`LiveDataClientConfig` 改為 `DataClientConfig`，`LiveExecClientConfig` 改為 `ExecutionClientConfig`），且尚未公布 v2 穩定版的日期。
- **授權漂移。** StockSharp 於 2026-07-16 從 Apache-2.0 改為專有授權。OpenBB 先是 MIT，接著改為 AGPL（2024-05），再改為 Apache-2.0（2026-09）。請針對每個鎖定的版本記錄其授權。
- **來源可信度（provenance）。** OpenBB 的 GitHub repo 現在會解析至 `openbq-org`（一個建立於 2026-09-11 的組織）。升級前請驗證套件簽章與來源。
- **Bus factor。** vectorbt 與 hftbacktest 各自依賴單一維護者，且 hftbacktest 在 2026 年沒有任何 commits。backtrader 已停止維護。QuantRocket 自 2025 年 1 月以來沒有新版本。
- **一致性的假象。** 向量化回測忽略了佇列位置、延遲與部分成交。請在具備貼近真實成交模型的事件驅動引擎上進行驗證（市場微結構方面可採 hftbacktest 風格）。
- **鎖定。** Pine（TradingView）、MQL5、NinjaScript 與 XScript 策略無法移植。QuantConnect 雲端資料無法自由匯出。Jesse 的實盤交易需要授權金鑰。
- **平台限制。** MetaTrader5 Python 橋接僅支援 Windows。數個台灣券商 SDK 範例以 Windows（WPF）為目標平台。在設計伺服器部署之前，請先確認 Linux 支援。
- **法規。** 對他人提供訊號或自動化管理，無論使用哪種引擎，都會迫使你需要 Build 等級的稽核與權限功能。在台灣，收費的證券投資建議需要金管會（FSC）許可的證券投資顧問事業（SICE，投顧），全權委託需要金管會另行核准，期貨建議則屬於期貨顧問的許可範疇。在美國，對應的是 RIA 與 CTA 註冊。

## 參考資料

- NautilusTrader repo、授權、adapters、v2 狀態（包括不建議以 RC 進行實盤交易的說明）： https://github.com/nautechsystems/nautilus_trader
- NautilusTrader releases： https://github.com/nautechsystems/nautilus_trader/releases
- NautilusTrader v2.0.0rc4 說明： https://newreleases.io/project/github/nautechsystems/nautilus_trader/release/v2.0.0rc4
- NautilusTrader 商品（instruments）： https://nautilustrader.io/docs/latest/concepts/instruments/
- NautilusTrader Pro： https://nautilustrader.io/pro/
- LEAN repo： https://github.com/QuantConnect/Lean
- LEAN NuGet： https://www.nuget.org/packages/QuantConnect.Lean/
- QuantConnect 券商（brokerages）： https://www.quantconnect.com/docs/v2/cloud-platform/live-trading/brokerages
- QuantConnect 資產類別： https://www.quantconnect.com/docs/v2/writing-algorithms/securities/asset-classes
- QuantConnect 定價： https://www.quantconnect.com/pricing.md
- Hummingbot repo： https://github.com/hummingbot/hummingbot
- Hummingbot release notes： https://hummingbot.org/release-notes/
- Freqtrade repo 與 releases： https://github.com/freqtrade/freqtrade , https://github.com/freqtrade/freqtrade/releases
- vectorbt repo 與 PyPI： https://github.com/polakowo/vectorbt , https://pypi.org/project/vectorbt/
- vectorbt PRO 會員方案與 FAQ： https://vectorbt.pro/become-a-member , https://vectorbt.pro/faq/
- backtrader： https://github.com/mementum/backtrader , https://pypi.org/project/backtrader/
- Zipline-reloaded： https://pypi.org/project/zipline-reloaded/
- QuantRocket： https://www.quantrocket.com/docs/release-notes/ , https://www.quantrocket.com/pricing/
- OpenBB repo、授權歷史、PyPI： https://github.com/openbq-org/OpenBB , https://github.com/openbq-org/OpenBB/commits/develop/LICENSE , https://pypi.org/project/openbb/
- StockSharp repo、授權變更 commit、EULA、定價： https://github.com/StockSharp/StockSharp , https://github.com/StockSharp/StockSharp/commit/81ecf7ad892f43bd39efc1bc0dbdf273bae32bf0 , https://stocksharp.com/en/products/eula/ , https://stocksharp.com/pricing/
- Jesse： https://github.com/jesse-ai/jesse , https://pypi.org/project/jesse/ , https://docs.jesse.trade/docs/livetrade
- Lumibot： https://github.com/Lumiwealth/lumibot , https://pypi.org/project/lumibot/
- hftbacktest： https://github.com/nkaz001/hftbacktest , https://pypi.org/project/hftbacktest/
- Qlib： https://github.com/microsoft/qlib , https://pypi.org/project/pyqlib/
- VeighNa（vn.py）： https://github.com/vnpy/vnpy , https://pypi.org/project/vnpy/
- QuantLib： https://github.com/lballabio/QuantLib
- IBKR TWS API 債券合約： https://interactivebrokers.github.io/tws-api/basic_contracts.html
- StockSharp connectors repo（專有授權聲明）： https://github.com/StockSharp/Connectors
- 台灣《證券投資信託及顧問法》： https://law.moj.gov.tw/ENG/LawClass/LawAll.aspx?pcode=G0400121
- MetaTrader 5： https://www.metatrader5.com/en/releasenotes , https://pypi.org/project/MetaTrader5/
- cTrader Algo： https://help.ctrader.com/ctrader-algo/
- NinjaTrader 定價與 Kraken 收購： https://www.ninjatrader.com/pricing/ , https://blog.kraken.com/news/kraken-to-acquire-ninjatrader
- MultiCharts： https://www.multicharts.com/ , https://www.multicharts.com/purchase/
- TradingView： https://www.tradingview.com/pricing/ , https://www.tradingview.com/pine-script-docs/release-notes/
- Sierra Chart 方案： https://www.sierrachart.com/index.php?page=doc/Packages.php
- XQ： https://www.xq.com.tw/ , https://www.xq.com.tw/broker , https://www.xq.com.tw/xstrader/
- Shioaji（永豐金）： https://pypi.org/project/shioaji/
- Fubon Neo API： https://www.fbs.com.tw/TradeAPI/en/docs/welcome/
- GitHub REST API（活動指標的量測方法）： https://docs.github.com/en/rest

## 驗證紀錄（2026-10）

於 2026-10-05 針對 GitHub（網頁與 REST/GraphQL API）、PyPI JSON 中繼資料、NuGet 及各廠商官方頁面進行對抗式事實查核。摘要：共查核 53 項，33 項確認無誤，13 項已於上文更正或補充，7 項無法驗證。

### 已確認

1. NautilusTrader 為 LGPL-3.0（GitHub license API；PyPI `LGPL-3.0-or-later`）。最新穩定版為 v1.231.0（2026-08-02），最新預發布版為 v2.0.0rc5（2026-09-15）；v2 為 Rust + PyO3 執行環境（GitHub releases、PyPI）。
2. Nautilus v2.0.0rc4（2026-09-02）將 `LiveDataClientConfig` 重新命名為 `DataClientConfig`（並將 `LiveExecClientConfig` 重新命名為 `ExecutionClientConfig`），且未公布 2.0.0 穩定版日期（newreleases.io rc4 說明、README）。
3. Nautilus 商品類型：Equity、FuturesContract、OptionContract、OptionSpread、CryptoPerpetual、BinaryOption、BettingInstrument 與 Cfd 皆有列出，另有其他類型（CurrencyPair、Commodity、IndexInstrument、TokenizedAsset、CryptoOption 等）。沒有 Bond 類型（nautilustrader.io instruments 頁面）。
4. LEAN 為 Apache-2.0（GitHub）。NuGet `QuantConnect.Lean` 2.5.18127 於 2026-09-25 發布，目標框架為 .NET 10。2026-08-21 至 2026-09-25 之間共有五次 NuGet 發布（nuget.org）。
5. LEAN 列出 11 種資產類別（US Equity、Equity Options、Crypto、Crypto Futures、Forex、Futures、Future Options、Index、Index Options、CFD、India Equity），其中沒有債券；其券商頁面列出 23 個項目，其中沒有台灣券商（quantconnect.com 文件）。
6. QuantConnect 定價：Researcher $84/月、Team $168/月、Trading Firm $480/月、Institution $1,272/月（quantconnect.com/pricing.md）。
7. StockSharp commit 81ecf7a（"Replace Apache license with StockSharp custom notice"）的日期為 2026-07-16T09:29Z。其 EULA 禁止建立衍生著作、修改與再散布（GitHub API；stocksharp.com/en/products/eula/）。
8. StockSharp README 列出 Yuanta SPARK API、Fubon Neo API、SinoPac Shioaji、Taishin Nova API（前身為 MasterLink）與 TWSE OpenAPI（github.com/StockSharp/StockSharp）。
9. OpenBB LICENSE 歷史：MIT，之後為 AGPL-3.0（commit c61d10d，2024-05-14），再於 V5 commit 中改為 Apache-2.0（bbf1ab2，2026-09-29）。PyPI `openbb` 5.0.0 於 2026-09-29 以 Apache-2.0 發布。`OpenBB-finance/OpenBB` 會解析至 `openbq-org/OpenBB`，該組織建立於 2026-09-11，而 PyPI 仍指向舊的 URL（GitHub API、PyPI）。
10. vectorbt 為 Apache 2.0 加 Commons Clause（LICENSE）。1.1.1 於 2026-09-26 發布，1.0.0 於 2026-04-22 發布（PyPI）。PRO 費用為 $25/月、12 個月 $240 或終身 $500，個人會員限個人、非商業用途；商業使用需透過電子郵件洽談（vectorbt.pro）。
11. backtrader：最後一次 PyPI 發布為 1.9.78.123（2023-04-19），最後一次 commit 為 2023-04-19，最後一次 push 為 2024-08-19，GPL-3.0（PyPI、GitHub API）。
12. Kraken 於 2025-03-20 宣布以 $1.5B 收購 NinjaTrader。ninjatrader.com 現已標示為 "NinjaTrader by Payward"。方案：免費、$99/月、$1,499 終身（Kraken 部落格、ninjatrader.com/pricing）。
13. 已重新量測的 GitHub 活動數據：Nautilus（4,536）、LEAN（343）、StockSharp（1,143）、OpenBB（96）與 vectorbt（154）的 2026 年預設分支 commits；Nautilus（531/605）、LEAN（78/105）與 Freqtrade（103/104）的 issue 結案數；所有列出 repo 的 star 數。
14. Hummingbot v2.17.0（2026-09-22），Apache-2.0。
15. Freqtrade 2026.9（2026-09-29），GPL-3.0，12 個現貨交易所與 7 個期貨交易所。2026.8 因 Bitmart 於 7 月底停止營運而將其移除（release notes）。
16. Zipline-reloaded 3.1.1（2025-07-19），2026 年預設分支沒有任何 commits。
17. QuantRocket 最新版本為 2.11.0（2025-01-28），此後沒有新版本。
18. Jesse 為 MIT（3.2.4，2026-10-01）。實盤與模擬交易需要授權外掛（docs.jesse.trade）。
19. Lumibot 為 GPL-3.0（4.6.4，2026-10-03），支援的券商為 Alpaca、IBKR、Tradier、Schwab、Tradovate 與 ProjectX（README）。
20. hftbacktest 為 MIT。Python 2.4.4 與 rust-v0.9.4 於 2025-12-10 發布，最後一次 push 為 2025-12-23，2026 年沒有任何 commits。
21. Qlib 為 MIT（0.9.7，2025-08-15）。
22. MetaTrader5 Python 套件 5.0.6231（2026-09-27）僅提供 `win_amd64` wheels。
23. TradingView 付費方案費用為 $12.95 至 $199.95/月（按年計費）。Pine Script v6 為現行版本，其 release notes 更新至 2026 年 9 月。
24. Sierra Chart 方案費用為 $26 至 $56/月。
25. MultiCharts 市場資料費用為 $49/月（購買頁面）。
26. XQ 列出 26 家合作券商，並設有自動交易中心欄位，可在 Windows、Mac、iPad 與 iPhone 上執行（xq.com.tw）。
27. Shioaji 1.7.7（2026-09-29）提供 Windows、Linux（x86_64 與 aarch64）與 macOS 的 wheels，涵蓋股票、期貨與選擇權。
28. Fubon Neo API 支援 Python、C#、Node.js、C++ 與 Go（後兩者為部分支援）。
29. NautilusTrader Pro 僅開放候補名單，未公布價格，提供執行演算法、風控引擎與儀表板。
30. Nautilus 支援 Linux（x86_64 與 ARM64）、macOS ARM64 與 Windows x86_64，並有 17 個整合，包括 Databento 與 Tardis 資料。
31. LEAN 的 GitHub releases 已過時（v2.4.0.1，2017），StockSharp 的 tags 也一樣（5.0.0，2020）。StockSharp 定價頁面宣稱有 389+ 個連接器。
32. Kraken 的公告將股票定位為 Kraken 多資產布局的目標之一。這與產品路線圖的措辭一致。
33. cTrader Algo 支援 C# 與 Python。

### 已更正或補充

| 原文 | 更正 | 來源 |
|---|---|---|
| Nautilus v2.0.0rc4 移除了 Cython | 舊版 Cython 套件是在 **rc3**（2026-08-21）中移除的。rc4 說明僅提及它已被移除 | https://github.com/nautechsystems/nautilus_trader/releases |
| v1 僅接收安全性修補（無期限） | v2 切換後**約三個月**內，在 `develop_v1` 上提供關鍵安全性修補回移 | v1.231.0 release notes |
| 建議：鎖定確切的 v2 RC 作為核心（隱含用於實盤交易） | 上游不建議在正式環境中使用 release candidates，例如以真實資金進行實盤交易。內文現已改為建議將 RC 用於開發與模擬交易，真實資金交易則須等到 2.0.0 穩定版或通過 soak test 後才開放 | https://github.com/nautechsystems/nautilus_trader（README） |
| TradingView 的 webhooks 限 Plus 以上方案 | **所有付費方案（Essential 以上）**皆有 webhooks；只有 Basic 沒有 | https://www.tradingview.com/pricing/（比較表） |
| MT5 AI Assistant 於 builds 6140-6230（2026 年 8-9 月）加入 | MCP 與 agentic AI 支援**於 build 6060（2026-07-23）推出**，並持續擴充至 build 6230（2026-09-24） | https://www.metatrader5.com/en/releasenotes |
| NinjaTrader 涵蓋美國期貨；加密貨幣與股票在產品路線圖上 | 它已列出 **Micro Bitcoin 期貨與個股期貨**。現貨股票與加密貨幣仍由 Kraken 提供 | https://ninjatrader.com/ |
| OpenBB：避免 4.x，其為 AGPL | 只有 **4.2.0 至 4.7.x** 為 AGPL-3.0。4.0 與 4.1 發布時 repo 仍為 MIT | PyPI `openbb` 中繼資料；LICENSE 歷史 |
| 台灣法規：「SITE/FSC 許可」 | 收費提供訊號需要金管會許可的**證券投資顧問事業（SICE，投顧）**，全權委託需要金管會另行核准，期貨建議則需要期貨顧問許可 | https://law.moj.gov.tw/ENG/LawClass/LawAll.aspx?pcode=G0400121 |
| 債券在所有地方都缺席 | 開源引擎缺少可交易的債券類型，但 IBKR TWS 等券商 API 接受 `BOND` 合約，且 QuantLib 涵蓋債券分析 | https://interactivebrokers.github.io/tws-api/basic_contracts.html |
| StockSharp，唯一具備台灣連接器的引擎，「脫離開源」（暗示台灣連接器曾經開源） | 台灣連接器位於 `StockSharp/Connectors`（建立於 2026-07-13，專有授權聲明），且未出現在 2026-07-15 變更前的 README 中，因此它們**從未是 Apache-2.0** | GitHub API（`StockSharp/Connectors`、README 歷史） |
| LEAN：23 個券商 | 23 個**項目**，包含 QC Paper Trading、通用 FIX 以及一組 "CFD and FOREX Brokerages" | https://www.quantconnect.com/docs/v2/cloud-platform/live-trading/brokerages |
| Hummingbot：140+ 個 CEX/DEX/AMM 交易場所 | README 中的 140+ 數字計算的是使用者曾交易過的交易場所，而非已提供的連接器 | https://github.com/hummingbot/hummingbot |
| 缺漏的選項 | 新增 **VeighNa（vn.py）**（MIT，45.7k stars，4.4.0 於 2026-05-14 發布，無台灣 gateway）、**QuantLib**（債券與選擇權定價）以及 StockSharp 定價（免費方案含 1 個連接器；Premium 首年 $995 或 Ultimate 首年 $1,995） | https://github.com/vnpy/vnpy ; https://github.com/lballabio/QuantLib ; https://stocksharp.com/pricing/ |

### 無法驗證

- Kraken 收購 NinjaTrader 交易的完成日期。ninjatrader.com 已確認由 Payward 擁有，但未取得交易完成的公告。
- QuantRocket 的方案名稱（Non-Professional 或 Professional）。定價頁面需要登入才能顯示方案等級。
- MultiCharts 的 Python beta 與終身授權價格。兩者皆未出現在公開的購買頁面上。
- XQ 定價「通常透過券商」提供。未找到公開價格，這與該說法一致，但無法證明其為真。
- cTrader Web 與行動版的可用性以及 Open API。在所查閱的 cTrader Algo 文件頁面上並未顯示。
- 未重新量測之專案的 issue 結案比例與 2026 年 commit 數（Hummingbot、Freqtrade commits、Jesse、Lumibot、hftbacktest issues、Qlib）。
- 靜態連結 Rust crates 時的 LGPL「重新連結義務」。這是法律解釋，而非可查核的事實；請取得法律顧問的審查。
