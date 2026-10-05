[English](03-market-data-storage.md) | **繁體中文**

# 03 · 市場資料管線、資料供應商與儲存

*研究快照：2026-10-05。價格為 2026 年 9–10 月所見的公開牌價，除另有註明外以美元計。購買前請再次確認。「Pro」指依交易所規則認定的專業訂戶。*

## TL;DR（重點摘要）

- **先建資料湖，再上資料庫。** 以 Parquet 資料湖（Hive 式分區、zstd 壓縮）作為權威資料來源（system of record），並以 DuckDB 或 Polars 查詢。DuckDB 目前為 1.5.x，但 1.5 將於 2026-11-01 終止支援（EOL），而 2.0.0 預定於 2026-10-21 發布，因此請規劃升級至 2.0（或續用 1.4 LTS，直到其於 2026-11-17 終止支援）。僅在需要即時擷取與互動式儀表板時，才加入熱（hot）時序資料庫：小型團隊用 QuestDB（Apache-2.0，v10.0 於 2026 年 8 月發布），團隊或機構規模則用 ClickHouse（Apache-2.0，26.8 LTS）。一旦需要多個寫入者或可重現的快照，再加入表格式（table format：Iceberg、Delta 或 DuckLake）。
- **使用單一正規化事件 schema，搭配兩種編碼。** 以 Databento DBN 與 NautilusTrader 為範本建立紀錄模型：int64 奈秒的 `ts_event`/`ts_recv`、定點數價格，以及數值型 `instrument_id`。記憶體內與傳輸時使用 Arrow，靜態儲存（at rest）使用 Parquet。原始供應商酬載（payload）原封不動保留（bronze 層），以便在正規化出現錯誤時能重新播放（replay）。
- **沒有任何單一平價供應商能涵蓋全部四種資產類別。** 典型的 MVP 組合：
  - 美股：Databento 或 Massive（Polygon.io 已於 2025-10-30 更名為 Massive）。
  - 選擇權：ThetaData 或 ORATS。
  - 加密貨幣：CCXT（免費）加上 Tardis.dev。
  - 債券與利率：FRED/ALFRED 與 Treasury Fiscal Data（皆免費），再加上 TRACE。
  - 台灣：Shioaji 或 Fugle，再加上 FinMind 或 TEJ。
- **授權對設計的限制大於技術。** 非專業與專業費用相差約 30 倍（IBKR 的 NYSE L1 每月 $1.50 對比 $45）。多數零售方案僅限個人使用。向其他使用者顯示資料即構成再散布（redistribution）（TWSE 收取每月 NT$60,000 的授權費，另加每個帳戶的資料費）。多使用者產品從第一天起就需要權限（entitlement）層。
- **時點（point-in-time，PIT）正確性是最重要的資料品質要求。** 它需要：
  - 雙時態（bitemporal）證券主檔
  - 未還原價格加上公司行動（corporate actions）調整因子
  - 原始公告（as reported）的基本面資料
  - 已下市商品
  - 總經資料的版本（vintage，ALFRED）

## 關鍵問題

1. 每個策略需要何種粒度：日 K 棒、1 分 K 棒、L1 成交與報價，還是 L2/L3 委託簿？此選擇會讓成本相差 10–1000 倍。
2. 系統僅供自用，還是第三方也會看到資料？向第三方顯示即意味著再散布與專業分類。
3. 系統會在單一工作站（Windows、macOS 或 Linux）上執行，還是在有並行使用者的伺服器或叢集上執行？
4. 我們如何保證、並在日後重現符合時點且無存活者偏差（survivorship bias）的回測？
5. 回測重播與實盤交易共用哪一套正規化 schema，讓同一套策略程式碼能在兩者上執行？
6. 每個情境的每月資料預算是多少？

## 1. 資料類型與儲存特性

| 資料類型 | 資產類別 | 形態 / 資料量 | 常見來源 | 儲存備註 |
|---|---|---|---|---|
| 成交與報價（L1） | 全部 | 完整美股每日數 GB | Databento、Massive、IBKR、券商 API | 依日期/交易場所分區；依商品、ts 排序 |
| L2（MBP-10）/ L3（MBO） | 股票、期貨、加密貨幣 | L1 的 10–100 倍 | Databento、Tardis.dev、Kaiko | 增量 + 定期快照；重播時重建委託簿 |
| OHLCV K 棒 | 全部 | 小 | 所有供應商 | 盡可能由成交資料推導；供應商 K 棒作為交叉核對 |
| 選擇權鏈、IV/Greeks | 美國選擇權（OPRA）、TAIFEX TXO、Deribit | OPRA：超過 100 萬檔選擇權商品；18 家參與交易所 | Databento、Cboe DataShop、ORATS、ThetaData、OptionMetrics | 以固定頻率擷取選擇權鏈快照；同時儲存自行計算的 IV 與供應商 IV |
| 債券成交/報價 | 債券 | 稀疏、OTC、以 CUSIP 為鍵 | FINRA TRACE、ICE、Bloomberg、LSEG | 量小；評價價格來自模型，而非成交 |
| 利率曲線 | 債券、選擇權 | 極小 | Treasury、FRED/ALFRED | 連同發布（vintage）日期一併儲存 |
| 基本面 | 股票 | 小、會修正 | Sharadar、EODHD、TEJ、FinMind | 保留原始公告值與重編值，以公告日期為鍵 |
| 公司行動 | 股票、ETF、選擇權 | 小、關鍵 | 供應商、交易所、OCC 與 TAIFEX 公告 | 獨立的調整因子表；讀取時調整 |
| 證券主檔 | 全部 | 小、每日變動 | 供應商定義、OpenFIGI | 雙時態（有效時間 + 知悉時間） |
| 鏈上 | 加密貨幣 | 大、僅附加（append-only） | 自建節點/索引器、分析供應商 | 依區塊範圍分區的 Parquet |
| 新聞 / 另類資料 | 股票、加密貨幣 | 文字 + 中繼資料 | Benzinga（Massive 加購，$99/月）、Tiingo News | 物件儲存；時間戳記 = 首次可取得時間 |

## 2. 儲存引擎比較

| 選項 | 版本（2026 年 10 月） | 授權 | 部署 | 寫入 / 查詢 | As-of join | 最適用途 | 注意事項 |
|---|---|---|---|---|---|---|---|
| **Parquet + Arrow + DuckDB/Polars**（+ Iceberg / Delta / DuckLake） | DuckDB 1.5.6（2026-09-28）、1.4 LTS、2.0-dev（2.0.0 預定 2026-10-21 發布；1.5 於 2026-11-01 EOL，1.4 LTS 於 2026-11-17 EOL）；Polars 1.44.2（2.0 處於候選發布版階段）；PyArrow 25.0.1；Iceberg 1.12.0；Delta 4.4.0；DuckLake 1.0（2026-04-13） | MIT / Apache-2.0 | 嵌入式；任何作業系統；從筆電到 S3 | 批次寫入；極快的欄式掃描；無需伺服器 | DuckDB `ASOF JOIN`、Polars `join_asof` | 權威資料來源、研究、回測 | 無即時寫入伺服器；小檔案需壓實（compaction）；多個並行寫入者需要表格式 |
| **QuestDB** | 10.0.1（2026-08-24）；2025 年共 16 次 OSS 發布 | Apache-2.0（Enterprise 為商業版） | 單一執行檔或 Docker | QWP 協定：寫入速度約為 ILP 的 3.6 倍；Arrow 輸出約每秒 2.2 億列（供應商數據） | 原生支援，含 `TOLERANCE`；自 9.2 起採用 dense 演算法 | 即時 tick 擷取、OHLC 物化檢視（materialized views）、儀表板 | 複寫、分層儲存與 OIDC 僅限 Enterprise |
| **ClickHouse** | 26.8 LTS（修補版 2026-10-04） | Apache-2.0 | 伺服器/叢集或 Cloud | 寫入量極高、壓縮率佳、支援大量並行使用者 | `ASOF JOIN`，使用 `hash`、`full_sorting_merge` 或（自 26.6 起）`parallel_hash` 演算法 | 團隊或機構分析、多租戶 | 維運負擔；無原生 Windows 伺服器（使用 Docker/WSL2） |
| **TimescaleDB**（Tiger Data） | 2.30.2（2026-09-29） | Apache-2 核心 + Tiger Data License（TSL），用於 columnstore 與連續聚合（continuous aggregates） | PostgreSQL 擴充套件 | 中等；完整關聯式 SQL | 無原生 ASOF（以 `LATERAL` 變通） | 以 Postgres 為主的團隊；證券主檔與 K 棒放在同一個資料庫 | TSL 版本不得作為資料庫服務出售；tick 掃描較慢 |
| **kdb+ / KDB-X** | KDB-X GA 2025-11-17；5.0.20260723 | 商業授權；免費 Community Edition（允許商業使用），上限為 16 GB RAM、4 個次要執行緒與 8 個連線 | 伺服器 | 長久以來 tick 資料領域的標竿引擎 | 原生 `aj` / `wj` | 具備 q 技能的銀行與 HFT 團隊 | q 人才稀缺；超出上限需付費授權 |
| **ArcticDB** | 6.26.0（2026-09-14；6.27.0 已自 PyPI 撤回（yanked）） | BSL 1.1；每個版本於發布兩年後轉為 Apache-2.0 | 架構於 S3/LMDB 之上的 Python 函式庫 | 原生 DataFrame；內建版本控管 | 透過 pandas | 使用版本化資料集的 Python 研究 | 任何商業用途（即使是研發）都需要商業協議 |
| **InfluxDB 3** | v3.12.0（2026-10-01） | Core 為 MIT/Apache-2；Enterprise 為商業授權 | 伺服器；Parquet 置於物件儲存 | 寫入能力強 | 弱 | 監控平台本身 | Core 為近期資料而設計；金融功能少 |

就單一機器而言，在 Parquet 上使用 DuckDB 或 Polars 最快產生價值，且能在所有作業系統上執行，包括嵌入於桌面應用程式中。在以下兩種情況下，才值得執行伺服器型資料庫：
- 需要具備次秒級新鮮度的持續寫入；
- 許多人同時查詢資料。

## 3. 正規化格式與二進位編碼

| 格式 | 角色 | 主要特性 | 狀態 |
|---|---|---|---|
| **Databento DBN** | 正規化市場資料的傳輸與檔案格式 | 固定寬度結構、自我描述標頭、零複製（zero-copy）、zstd；schema 包含 MBO、MBP-1/10、trades、OHLCV、definitions、statistics | Apache-2.0；`dbn` v0.71.0（2026-09-29）；Rust、Python 與 C 綁定（C++ 則透過獨立的 `databento-cpp` 用戶端） |
| **NautilusTrader 模型** | 引擎型別 + `ParquetDataCatalog` | `QuoteTick`、`TradeTick`、`Bar`、`OrderBookDelta(s)`、`OrderBookDepth10`、`OptionGreeks`、資金費率/標記價格；`ts_event` + `ts_init`；64 或 128 位元定點數 | LGPL-3.0；v1.231.0（2026-08-02）穩定版；2.0（Rust 原生核心，含破壞性變更）處於候選發布版階段，rc5 於 2026-09-15 發布；內建 Databento 轉接器 |
| **Arrow IPC / Flight / ADBC** | 跨 Rust、Python、TypeScript 與 C# 的零複製交換 | 欄式、語言中立；Flight 用於大量資料 RPC | Apache-2.0 |
| **Parquet + 表格式** | 靜態儲存 | 欄統計、述詞下推（predicate pushdown）；Iceberg、Delta 與 DuckLake 增加快照與 schema 演進 | 通用 |
| **QuestDB QWP** | 資料庫寫入與輸出 | 二進位、欄式、透過 WebSocket；以 Arrow 回傳結果 | 10.0 新增 |

**提案：** 定義一套與 DBN 相容的內部標準（canonical）schema。如此一來，Databento 資料無需轉換即可載入，NautilusTrader 也能直接取用。以 Arrow schema 表達此 schema，並以 Parquet 持久化。每個事件都帶有以下欄位：
- `ts_event`：交易場所時間，UTC 奈秒
- `ts_recv`：我方接收時間
- `instrument_id`：來自證券主檔的內部 ID
- `venue`
- `price` 與 `size`，以縮放後的 int64 表示（1e-9）
- `source` 與 `license_tag`，用於強制執行權限控管

## 4. 各資產類別的供應商

### 股票

| 供應商 | 涵蓋範圍 | 價格 | 授權說明 |
|---|---|---|---|
| **Databento** | 美股（15 家交易所 + ATS）、CME、ICE、OPRA；從 tick 到 L3 | 歷史資料按 GB 計費。US Equities Standard $199/月：上市時（2025 年 1 月）含 7 年 OHLCV、12 個月 L1、1 個月 L2/L3，外加即時資料。頭條價格 Plus $1,750/月與 Unlimited $4,500/月（年約）為 CME 費率。2026-06-22 起的新費率：CME Standard 由 $179 調升至 $199；US Equities 的 Unlimited 方案為 $4,000/月（ICE 交易場所 $2,500/月）；US Equities Standard 與 Plus 不變 | Standard 含即時資料，無另外的授權費；Plus 增加對外散布權 |
| **Massive**（前身為 Polygon.io） | 美國股票、選擇權、指數、期貨、外匯與加密貨幣（加密貨幣歸在 Currencies 方案下販售）；flat files | 股票：Basic 免費（日終資料、2 年）、Starter $29 與 Developer $79（皆延遲 15 分鐘）、Advanced $199/月（即時、20 年以上） | 僅限個人使用（Advanced：僅限非專業）；另有企業方案；`api.polygon.io` 仍與 `api.massive.com` 並行服務 |
| **Tiingo** | 11 萬檔證券、30 年以上 EOD、IEX 盤中資料、加密貨幣、新聞 | 免費；Power $30/月（個人）或 $50/月（內部商業用途） | 再散布需透過業務洽談 |
| **Alpha Vantage** | 全球 EOD/盤中、外匯 | 免費每日 25 次請求；$49.99–249.99/月 | 美國即時資料需另外取得權限 |
| **EODHD** | 15 萬檔以上代碼，含 `.TW` | $19.99–99.99/月（個人） | 商業方案另計 |
| **IBKR** | 全球，含 TWSE/TPEx | 免費的非合併 Cboe One + IEX。US Snapshot & Futures Value Bundle $10/月，佣金達 $30 即免收。NYSE L1 非專業 $1.50 對比專業 $45。TWSE L1 $1/月；TPEx L1 NT$15/月 | 僅限自身交易使用；歷史資料請求有頻率限制 |
| **Alpaca Market Data**（審查時新增） | 美國股票、選擇權（OPRA）、加密貨幣；7 年以上 K 棒 | 免費：僅 IEX、30 個 WebSocket 代碼、選擇權僅提供指示性報價。Algo Trader Plus $99/月：所有美國交易所加上即時 OPRA | 以自主交易者為對象；向他人顯示資料前請檢查再散布條款 |
| **Norgate Data**（審查時新增） | 美國、ASX 與加拿大股票的無存活者偏差日資料 | 6 或 12 個月期約；無盤中或 tick 資料 | 僅限 Windows 的本機資料庫；適用於 PIT 日頻回測，不適用於實盤交易 |
| **Bloomberg / LSEG / ICE** | 所有資產類別、參考資料、債券評價 | Bloomberg Terminal 每位使用者每年約 3 萬美元起；資料源（B-PIPE、LSEG Tick History、ICE）需詢價 | 企業合約，附稽核權 |

### 選擇權

| 供應商 | 涵蓋範圍 | 價格 |
|---|---|---|
| Databento OPRA | 合併 OPRA 資料源：所有美國選擇權交易所（2023 年上市時 17 家，目前為 18 家 OPRA 參與交易所）；歷史資料始於 2023-03-28；時點定義資料 | 包含於訂閱方案中 |
| Cboe DataShop | 2012 年起的 EOD 摘要；盤中報價與成交 | 含 Greeks 的全市場 EOD：$420/月或 $4,200/年；單一代碼：$35/月（2024-12 生效之牌價） |
| ORATS | 2007 年起的 EOD；2020 年 8 月起的 1 分鐘資料；2022 年 9 月起的逐筆成交明細（tick time & sales）；平滑 IV（SMV） | Data API：Delayed $199、Live $299、Live Intraday $599、All-In $899（每月）；工具加購 $99–299 |
| ThetaData | 美國選擇權；Value 為 1 分鐘資料，Standard 與 Pro 為 tick 級；分別提供 6、10 與 14 年歷史 | Value $40、Standard $80、Pro $160（每月）；僅限個人使用，不得再散布或作商業用途 |
| OptionMetrics IvyDB | 1996 年起含 IV 與 Greeks 的 EOD 價格 | 機構或學術（透過 WRDS）；需詢價 |

### 加密貨幣

| 供應商 | 角色 | 價格 |
|---|---|---|
| CCXT | 統一的 REST/WebSocket API，支援 100 多家交易所；即時資料與近期歷史 | 免費，MIT 授權；v4.5.85（2026-10-01） |
| Tardis.dev | tick 級 L2/L3、成交、資金費率、強制平倉、選擇權鏈；50 多家交易所；CSV 檔案與重播 | Academic $350–650、Solo $700–1,200、Professional $1,000–2,200、Business $3,000–6,000（每月；區間 = 從單一資料方案到全部交易所）；Academic 僅能按季或按年計費 |
| CoinAPI | 正規化的 REST、WebSocket 與 FIX 資料源，外加 flat files | Startup $79、Streamer $249、Pro $599（每月） |
| Kaiko | 機構級 L1/L2 資料與參考價格（reference rates），涵蓋 CeFi 與 DeFi | 企業定價，需詢價 |

### 債券與利率

| 來源 | 內容 | 價格 / 存取方式 |
|---|---|---|
| FRED / ALFRED | 美國公債殖利率、政策利率、總經資料；ALFRED 的 vintage 提供 PIT 歷史 | 免費，需 API 金鑰 |
| Treasury Fiscal Data API | 利率、標售、債務 | 免費；無需金鑰 |
| FINRA TRACE | 公司債、機構債與公債成交。Enhanced Historical 資料於成交 6 個月後發布（證券化商品為 18 個月） | 需簽協議 + 付費。學術資料集：$500/年 + $500 開辦費，延遲 36 個月 |
| ICE / Bloomberg BVAL / LSEG | 評價價格、曲線、參考資料 | 企業定價 |

### 台灣（TWSE / TPEx / TAIFEX）

| 來源 | 內容 | 價格 / 限制 |
|---|---|---|
| Shioaji（Sinopac，永豐金） | 股票、期貨與選擇權的即時 tick 與買賣報價，外加下單路由 | 開立證券帳戶即可免費使用。最多 200 個訂閱。每日流量 500 MB–10 GB，視交易量而定。v1.7.7（2026-09-29） |
| Fugle MarketData（富果） | 透過 WebSocket 提供股票與選擇權資料；2010 年起的歷史資料 | 免費（5 個訂閱）；NT$1,499/月（300 個訂閱）；NT$2,999/月（2,000 個訂閱） |
| FinMind | 彙整開放資料：價格、籌碼（investor flows）、基本面 | 免費，每小時 300–600 次請求；付費贊助方案 |
| TEJ（台灣經濟新報） | 時點量化資料庫；TQuant Lab 平台 | 商業或學術訂閱 |
| TAIFEX（期交所） | 逐筆成交明細（time & sales） | 最近 30 個交易日可免費下載。更早的歷史需填寫申請表，以 DVD 交付。無歷史 tick 資料 API |
| TWSE OpenAPI / TAIFEX OpenAPI（審查時新增） | 官方免費開放資料 REST API（Swagger）：TWSE 每日行情、公司與股利資料；TAIFEX 每日期貨/選擇權報表、法人部位、契約調整 | 免費；日終 / 每日，非即時；適合用於交易日曆、公司行動與日 K 棒 |
| TWSE 資訊廠商授權 | 即時資料再散布 | 非券商：每月 NT$60,000 再散布授權費，另加網際網路資料費（自動更新資料）：5,000 個帳戶以內每月 NT$100,000，每增加一個帳戶 NT$12。資料費超過 NT$200,000 時可抵銷授權費 |

## 5. 四種資產類別的差異

| 面向 | 股票 | 加密貨幣 | 債券 | 選擇權 |
|---|---|---|---|---|
| 結構 | 交易所 + 合併行情（consolidated tape） | 50 多個分散的交易場所；24/7；無合併行情 | OTC、自營商報價、成交稀疏 | 交易所交易；由 OPRA 合併；商品數量龐大 |
| 識別碼 | 代碼會隨時間變動；CUSIP/ISIN/FIGI；台灣為數字代碼 | 每個交易場所有各自的代碼；代碼會被重複使用 | 僅 CUSIP/ISIN | OCC 代碼與 TAIFEX 代碼；契約每日都有新掛牌與到期 |
| 成本 | K 棒便宜；L3 昂貴 | 交易所即時資料免費；tick 歷史需付費 | 利率資料免費；成交層級資料需付費且有延遲 | EOD 負擔得起；tick 資料最昂貴 |
| PIT 陷阱 | 股票分割、股利、下市、重編、指數成分 | 交易所倒閉、已下架交易對、洗量（wash volume） | 被贖回或到期的債券會消失；評價價格 vs 成交價格 | 公司行動後的契約調整；IV 模型的選擇 |
| 授權 | 交易所顯示、非顯示與專業費用 | 主要是交易所服務條款；歷史資料供應商自行授權其資料 | TRACE 協議；評價價格授權 | OPRA 費用；各供應商條款 |
| 分區 | 日期 / 交易場所 | 交易場所 / 日期；無交易時段邊界 | 單一小型表格 | 標的 / 到期日，附標的快照 |

## 6. 時點資料、品質與版本控管

- **證券主檔。** 採用雙時態設計。每一列屬性在 `[valid_from, valid_to)` 區間內有效，並記錄我們得知它的時間（`known_at`）。它將各供應商的代碼（Databento ID、Massive 代碼、CCXT market ID、Shioaji 契約代碼）對應到單一內部 `instrument_id`。
- **價格。** 儲存未還原價格。於讀取時，依回測日期（as of）套用公司行動調整因子。
- **基本面與總經資料。** 以公告或發布時間為鍵。TEJ 與 Sharadar 提供原始公告資料；ALFRED 提供 vintage。
- **存活者偏差。** 日期 *t* 的投資範圍（universe）是在 *t* 日掛牌的所有商品，包括之後下市的標的。也要保留歷史指數成分股。
- **每次寫入都執行品質檢查。** 未通過的分區會被隔離，而非悄悄捨棄。
  - 相對於交易時段日曆的缺漏，包括 TAIFEX 盤後交易時段（夜盤）與 24/7 的加密貨幣
  - 重複或順序錯亂的時間戳記
  - 交叉（crossed）或鎖定（locked）報價
  - 相對於參考價格的價格突波
  - 與供應商每日統計不符的成交量
  - 無法與 tick 對帳的 K 棒
  - 抽樣比對不同供應商
- **版本控管。** 原始檔案不可變更。正規化表格使用 Iceberg、Delta 或 DuckLake 快照，或 ArcticDB 版本。每次回測都記錄其資料集快照 ID 與程式碼 commit。

## 7. 交易所授權如何限制設計

1. **顯示 vs 非顯示。** 由人觀看資料屬於顯示用途。由演算法取用資料（訊號、下單生成、風控）屬於非顯示用途，通常需以專業費率另行授權。
2. **專業 vs 非專業。** 同一個 NYSE L1 資料源在 IBKR 每月要價 $1.50 或 $45。以公司名義營運系統，或管理他人資金，通常會讓使用者被歸類為專業。
3. **再散布。** 向任何其他使用者顯示資料，無論是在網頁或行動 UI 中，或在共用儀表板上，都需要再散布權：
   - TWSE 要求取得其再散布授權。
   - Massive 與 ThetaData 的個人方案禁止再散布。
   - Tiingo 透過其業務團隊提供再散布權。
   - Databento 表示其多數資料集可於 24 小時後再散布，但須遵守各發布者的條款。
4. **設計上的後果：**
   - 為每個資料集加上 `license_tag`，並建立一個供 API 閘道與 UI 檢查的權限服務。
   - 「自備供應商金鑰（bring your own vendor key）」是多使用者情境下最便宜的模式。
   - 公開畫面只顯示延遲或衍生資料。
   - 保留存取日誌，以因應交易所的使用稽核。
   - 絕不從內部儲存匯出原始 tick。

## 8. 依情境的建議

### (a) 個人 / 1–3 人 MVP（約 $0–500/月）

| 層級 | 選擇 |
|---|---|
| 權威資料來源 | 在本機 NVMe 或 S3 相容儲存桶上存放 Parquet（zstd）；DuckDB + Polars；僅在需要時採用 DuckLake 或 Iceberg |
| 熱儲存 | 起初不需要；一旦需要即時 tick 擷取或儀表板，再加入單節點 QuestDB |
| Schema | 與 DBN 相容的 Arrow schema；若以 Nautilus 為引擎，則使用 NautilusTrader catalog |
| 美股 | 研究用 Massive Starter 或 Developer（$29–79，延遲 15 分鐘）；即時用 Massive Advanced（$199）或 Alpaca Algo Trader Plus（$99）；需要 tick 或 L2 資料時用 Databento Standard（$199） |
| 選擇權 | ThetaData（$40–160）或 ORATS（$199 起）；一次性歷史資料用 Cboe DataShop |
| 加密貨幣 | 以 CCXT 擷取即時資料並存入自己的 Parquet；需要 tick 歷史時再加入 Tardis.dev（符合資格者 Academic 每月 $350 起；Solo 每月 $700 起，超出此預算） |
| 債券 / 利率 | FRED/ALFRED + Treasury Fiscal Data + IBKR 報價 |
| 台灣 | 即時資料用 Shioaji 或 Fugle；日頻歷史用 FinMind 與免費的 TWSE/TAIFEX OpenAPI；若 PIT 基本面很重要則用 TEJ；深度期貨與選擇權 tick 則用 TAIFEX DVD |
| 避免 | Kafka、ClickHouse 叢集、付費 kdb+，以及任何商業用途下的 ArcticDB |

### (b) 5–20 人團隊 / 機構

| 層級 | 選擇 |
|---|---|
| 權威資料來源 | 置於物件儲存、由 catalog 管理的 Iceberg（或 Delta），分為 bronze、silver 與 gold 層 |
| 熱 / 互動式 | 多使用者情境用 ClickHouse 叢集，或以 tick 為主並需 HA 時用 QuestDB Enterprise；僅在團隊熟悉 q 時才用 KDB-X |
| 擷取 | 事件匯流排（見訊息傳遞（messaging）面向）→ Arrow/DBN → 資料湖 + 熱資料庫 |
| 證券主檔 | 以 PostgreSQL 建置的專用雙時態服務 |
| 供應商 | Databento Plus/Unlimited 或直連交易所資料源；Bloomberg/LSEG 提供參考資料、基本面與債券；ICE 評價定價；OptionMetrics 或 Cboe 提供選擇權歷史；加密貨幣用 Tardis.dev Business 或 Kaiko；TEJ，若要再散布則另加 TWSE/TAIFEX 資訊廠商授權 |
| 治理 | 資料契約、品質 SLA、權限控管、授權清冊與稽核 |

## 9. 對整體架構的影響

- **資料平台是獨立的限界上下文（bounded context）**，具有穩定的契約。流程為：供應商轉接器 → 正規化器 → 資料湖與熱儲存 → 查詢 API（Arrow Flight/ADBC，另加供 UI 使用的 REST）。
- **回測重播的是與實盤交易相同的正規化資料流。** 策略程式碼永遠不會看到供應商的格式。
- **時鐘。** 全面使用 UTC int64 奈秒。依交易場所維護交易日曆：TWSE 與 TAIFEX 交易時段、美國假日、24/7 運作的加密貨幣。
- **跨平台 UI。** 桌面應用程式可內嵌 DuckDB 進行本機研究。網頁與行動用戶端則透過具權限感知（entitlement-aware）的 API 存取。
- **供應商抽象化。** 供應商每年都會更名並調整價格。

## 10. 風險與陷阱

- **供應商變動。** Polygon.io 於 2025 年 10 月更名為 Massive，Databento 則於 2026 年 6 月調漲了數個方案的價格。供應商也會重編歷史資料：Databento 將於 2026-10-31 重新指派 2023-11-28 以前 Nasdaq TotalView-ITCH 資料中的 `instrument_id` 值，並回補缺漏的冬季盤後資料。切勿以供應商的商品 ID 作為自己的鍵，並對供應商快照進行版本控管。
- **原始碼公開（source-available）授權。** ArcticDB 採 BSL，TimescaleDB 的 TSL 版本不得作為資料庫服務轉售，KDB-X Community 上限為 16 GB，而 QuestDB 與 InfluxDB 的高可用性僅限 Enterprise。
- **前視偏差（look-ahead bias）。** 它會透過還原價格、重編後的基本面、當前的指數成分與供應商修正過的 K 棒悄悄滲入。
- **時間戳記語意。** 交易所時間、SIP 時間與供應商接收時間各不相同。台灣使用 UTC+8，而非 UTC。
- **選擇權資料量。** 完整的 OPRA tick 資料極為龐大，因此請先從 EOD 或 1 分鐘選擇權鏈快照開始。
- **債券。** 評價價格是模型輸出，而 TRACE 歷史資料有延遲。
- **加密貨幣。** 交易場所會停擺、代碼會被重複使用、成交量會灌水。CCXT 的歷史深度因交易所而異。
- **台灣。** Shioaji 有流量上限與 200 個訂閱的限制，TAIFEX 的深度歷史資料只能離線取得，而再散布資料需要 TWSE 與 TAIFEX 的授權。
- **Parquet 維護。** 小檔案會不斷累積、schema 會漂移，因此要排程壓實並對 schema 進行版本控管。

## 參考資料

- https://fisd.net/polygon-io-is-now-massive
- https://massive.com/pricing
- https://databento.com/pricing
- https://databento.com/blog/updates-to-subscription-pricing
- https://databento.com/blog/introducing-databento-us-equities
- https://databento.com/blog/opra-data
- https://github.com/databento/dbn
- https://nautilustrader.io/docs/latest/concepts/data
- https://pypi.org/project/nautilus_trader/
- https://github.com/questdb/questdb/releases/tag/10.0.0
- https://questdb.com/blog/questdb-10-release/
- https://questdb.com/blog/questdb-2025-year-in-review/
- https://duckdb.org/news/
- https://duckdb.org/2025/09/16/announcing-duckdb-140.html
- https://duckdb.org/2026/04/13/ducklake-10
- https://pypi.org/project/polars/
- https://pypi.org/project/pyarrow/
- https://github.com/apache/iceberg/releases
- https://github.com/delta-io/delta/releases
- https://github.com/ClickHouse/ClickHouse/releases
- https://clickhouse.com/clickhouse/feature-journey
- https://www.tigerdata.com/docs/about/latest/timescaledb-editions
- https://en.wikipedia.org/wiki/TimescaleDB
- https://code.kx.com/kdb-x/releases/release-notes-latest.html
- https://docs.arcticdb.io/latest/licensing/
- https://pypi.org/project/arcticdb/
- https://influxdata.com/blog/influxdb3-open-source-public-alpha-jan-27
- https://docs.influxdata.com/influxdb3/core/
- https://www.tiingo.com/about/pricing
- https://www.alphavantage.co/premium/
- https://eodhd.com/pricing
- https://www.interactivebrokers.com/en/pricing/market-data-pricing.php
- https://en.wikipedia.org/wiki/Bloomberg_Terminal
- https://datashopcert.livevol.com/option-eod-summary
- https://orats.com/data-api
- https://www.thetadata.net/pricing
- https://wrds-www.wharton.upenn.edu/pages/about/data-vendors/optionmetrics
- https://github.com/ccxt/ccxt
- https://pypi.org/project/ccxt/
- https://tardis.dev/
- https://www.coinapi.io/products/market-data-api/pricing
- https://www.kaiko.com/products
- https://fred.stlouisfed.org/docs/api/fred/
- https://fiscaldata.treasury.gov/api-documentation/
- https://www.finra.org/filing-reporting/trace/historic-academic-data
- https://sinotrade.github.io/tutor/limit/
- https://pypi.org/project/shioaji/
- https://developer.fugle.tw/docs/pricing
- https://pypi.org/project/FinMind/
- https://www.tejwin.com/en/
- https://tquant.tejwin.com/
- https://www.taifex.com.tw/enl/eng9/tradersQAIS
- https://www.twse.com.tw/en/products/information/real-time.html
- https://massive.com/blog/polygon-is-now-massive
- https://databento.com/blog/nasdaq-historical-data-changes-2026-09
- https://duckdb.org/release_calendar
- https://questdb.com/docs/query/sql/asof-join/
- https://clickhouse.com/docs/sql-reference/statements/select/join
- https://github.com/ClickHouse/ClickHouse/blob/master/CHANGELOG.md
- https://kx.com/products/kdb-x/
- https://github.com/influxdata/influxdb/releases/tag/v3.12.0
- https://www.finra.org/rules-guidance/rulebooks/finra-rules/7730
- https://www.opraplan.com/
- https://alpaca.markets/data
- https://norgatedata.com/
- https://openapi.twse.com.tw/
- https://openapi.taifex.com.tw/
- https://github.com/FinMind/FinMind

## 驗證紀錄（2026-10）

於 2026-10-05 依據官方頁面、GitHub 發布頁、PyPI 中繼資料，以及交易所或供應商文件進行對抗式事實查核。共查核 54 項：34 項確認、15 項更正或新增、5 項無法驗證。

### 已確認

1. Polygon.io 於 2025-10-30 更名為 Massive.com。既有 API 金鑰仍然有效，且 `api.polygon.io` 持續與 `api.massive.com` 並行運作（FISD 公告；Massive 部落格）。
2. Massive 股票方案：Basic 免費、Starter $29、Developer $79、Advanced $199/月（即時、20 年以上）。全部皆為個人使用方案，Advanced 僅限非專業人士，企業定價另計（massive.com/pricing）。
3. QuestDB 10.0.0 於 2026-08-06 發布，帶來 QWP（二進位、欄式、透過 WebSocket，用於寫入與查詢結果）與 Live Views。10.0.1 隨後於 2026-08-24 發布，儲存庫採 Apache-2.0 授權（GitHub 發布頁、LICENSE.txt）。
4. DuckDB 1.5.6 於 2026-09-28 發布，2.0-dev 預覽版已推出。1.4.0 LTS（2025-09-16）新增 Iceberg 寫入功能，DuckLake v1.0 於 2026-04-13 推出（duckdb.org 新聞、發布日曆、PyPI）。
5. KDB-X 於 2025-11-17 正式發布（GA）。Community Edition 可免費供個人與商業使用，上限為 16 GiB RAM 與 4 個次要執行緒（另有 8 個連線的上限，現已補上）。最新版本為 5.0.20260723（KX 發布說明、kx.com 產品頁）。
6. ArcticDB 採 BSL 1.1，任何商業用途（包括研究或開發環境）都需要協議。每個版本於兩年後轉為 Apache-2.0。最新可用版本為 6.26.0（2026-09-14）（docs.arcticdb.io、PyPI）。
7. TimescaleDB Community Edition（TSL）可免費自行架設，但不得作為服務出售。Timescale 於 2025-06-17 更名為 Tiger Data，目前版本為 2.30.2（2026-09-29）（tigerdata.com 文件與部落格、GitHub）。
8. Tardis.dev 收費為 Academic $350–650、Solo $700–1,200、Professional $1,000–2,200、Business $3,000–6,000（每月），涵蓋 50 多家交易所（tardis.dev）。
9. ThetaData 選擇權方案：Value $40、Standard $80、Pro $160（每月），分別提供 6、10 與 14 年歷史，僅限個人使用（thetadata.net/pricing）。
10. IBKR：NYSE Network A L1 為 $1.50（非專業）或 $45（專業）。TWSE L1 為 USD 1.00。US Securities Snapshot and Futures Value Bundle 為 USD 10，佣金達 USD 30 即免收。Cboe One 與 IEX 串流免費（IBKR 市場資料定價頁）。
11. TWSE 的非券商資訊廠商需支付每月 NT$60,000 的再散布授權費，另加 0–5,000 個帳戶每月 NT$100,000，每增加一個帳戶 NT$12。TAIFEX 免費提供 30 個交易日的成交資料，更早的歷史需填寫申請表以 DVD 購買，且沒有歷史資料 API（twse.com.tw；taifex.com.tw 問答）。
12. QuestDB QWP 數據：透過網路的寫入速度約為 ILP 的 3.6 倍，輸出至 Arrow 每秒 2.2 億列。ILP 與 PG wire 仍受支援。QuestDB 於 2025 年推出 16 次 OSS 發布，於 9.2 新增 dense ASOF 演算法，並在 ASOF join 中支援 `TOLERANCE`。複寫、冷儲存與 OIDC 僅限 Enterprise（QuestDB 10 部落格、2025 年度回顧、文件）。
13. ClickHouse 26.8 LTS 於 2026-10-04 釋出修補版（v26.8.17.4-lts）。
14. Polars 1.44.2、PyArrow 25.0.1、Apache Iceberg 1.12.0 與 Delta Lake 4.4.0 為目前的穩定版（PyPI、GitHub）。
15. InfluxDB 3 Core 採 MIT/Apache-2.0 授權，為近期資料而設計。歷史查詢、HA 與唯讀副本為 Enterprise 功能（docs.influxdata.com、README）。
16. Databento DBN 採 Apache-2.0 授權，`dbn` v0.71.0 於 2026-09-29 發布（GitHub、PyPI `databento-dbn`）。
17. NautilusTrader 採 LGPL-3.0-or-later 授權。v1.231.0 於 2026-08-02 發布，並具備穩定的 Databento 轉接器（PyPI）。
18. Databento 定價頁列出 Standard $199、Plus $1,750 與 Unlimited $4,500（後兩者為年約），並表示多數資料集可於 24 小時後再散布。2026-05-29 的公告將 CME Standard 自 2026-06-22 起由 $179 調升至 $199，既有客戶可沿用舊價 12 個月（databento.com）。
19. Databento OPRA 歷史始於 2023-03-28，涵蓋超過 100 萬檔選擇權商品，並附時點定義資料（Databento OPRA 部落格）。
20. Databento US Equities Standard（$199）於 2025 年 1 月上市時，包含 7 年 OHLCV、12 個月 L1 與 1 個月 L2/L3，涵蓋 15 家交易所與 30 個 ATS（Databento 部落格）。
21. Massive 的 Benzinga 加購方案每個資料集每月 $99。
22. Tiingo Power 個人每月 $30，內部商業用途每月 $50，涵蓋 110,200 檔證券與 30 年以上歷史。再散布需透過業務洽談。
23. Alpha Vantage：免費方案每日 25 次請求，進階方案每月 $49.99–249.99，美國即時資料需另外取得權限。
24. EODHD 個人方案每月 $19.99–99.99，涵蓋 15 萬檔以上代碼，商業方案另計。
25. Bloomberg Terminal 每位使用者每年約 $24k–30k 以上（Wikipedia，引用 Investopedia 2022）。「約 $30k」的數字是合理的近似值。
26. CCXT 採 MIT 授權，支援 100 多家交易所，v4.5.85 於 2026-10-01 發布（GitHub、PyPI）。
27. CoinAPI：Startup $79、Streamer $249、Pro $599（每月）。
28. Kaiko 販售 L1/L2 CeFi 與 DeFi 資料及參考價格，需詢價或申請試用。
29. FRED/ALFRED API 需要免費金鑰，並提供 vintage 資料。Treasury Fiscal Data API 無需金鑰或註冊。
30. FINRA TRACE 學術資料每年 $500，另加 $500 開辦費，延遲 36 個月。Enhanced historical 資料於成交 6 個月後提供（證券化商品為 18 個月）（FINRA Rule 7730；FINRA TRACE 頁面）。
31. Shioaji 允許 200 個訂閱，每日流量 500 MB–10 GB，視交易量而定。v1.7.7 於 2026-09-29 發布（Shioaji 文件、PyPI）。
32. Fugle：免費（5 個訂閱）、NT$1,499/月（300）、NT$2,999/月（2,000）。股票歷史可回溯至 2010 年（developer.fugle.tw）。
33. FinMind 允許每小時 300 次請求，使用免費 token 則為每小時 600 次（FinMind README）。
34. TEJ TQuant Lab 是以 Zipline 為基礎的 PIT 研究平台，14 天免費試用後需付費（tquant.tejwin.com）。

### 更正或新增

1. Databento：原文寫「US Equities plan $4,000/mo」，暗示這是獨立方案。在 2026-05-29 的公告中，$4,000/月是 Databento US Equities 的 **Unlimited** 方案，而頭條價格 Plus $1,750 與 Unlimited $4,500 為 **CME** 費率。US Equities Standard 與 Plus 不變。來源：databento.com/blog/updates-to-subscription-pricing（清單依 Standard、Plus 與 Unlimited 標題分組）。
2. InfluxDB 3：「v3.11.4 (2026-09-08)」改為「v3.12.0 (2026-10-01)」。來源：GitHub tag v3.12.0；文件中的發布說明。
3. ClickHouse：「ASOF JOIN; sort-merge algorithm; spills to disk since 26.6」改為 ASOF 透過 `hash`、`full_sorting_merge` 或 `parallel_hash`（26.6 新增）。雜湊 join 的自動溢寫至磁碟於 26.4/26.5 推出，且並非 ASOF 專屬。來源：ClickHouse 文件（JOIN）與 CHANGELOG.md（26.4、26.5、26.6）。
4. ORATS：「$99 / $199 / $399 per month」改為 Delayed $199、Live $299、Live Intraday $599、All-In $899（每月）。情境 (a) 的「ORATS ($99)」改為「$199 起」。來源：orats.com/data-api。
5. ThetaData：「tick-level on Pro」改為 Standard **與** Pro 皆為 tick 級（Value 為 1 分鐘資料）。來源：thetadata.net/pricing。
6. Databento OPRA：「All 17 US options exchanges」（2023 年數字）改為目前的 18 家 OPRA 參與交易所（此後新增了 MIAX Sapphire 等）。來源：opraplan.com 參與者名單。
7. 選擇權資料形態：「>2M active symbols/day」原被歸於 OPRA。Databento 的「>2M active symbols」是其所有資料集的合計，因此已從 OPRA 列中移除。來源：databento.com/blog/opra-data。
8. DBN 語言：「Rust, Python, C++」改為 Rust、Python 與 C 綁定，C++ 則透過獨立的 `databento-cpp` 用戶端。來源：github.com/databento/dbn。
9. Massive：涵蓋清單原本缺少期貨（加密貨幣歸在 Currencies 方案下販售）。Starter 與 Developer 延遲 15 分鐘，Basic 僅提供日終資料，因此情境 (a) 不再暗示 $29–79 的方案支援實盤交易。來源：massive.com/pricing。
10. DuckDB 生命週期：「DuckDB 1.5.x」的建議現已註明 2.0.0 預定於 2026-10-21 發布，1.5 於 2026-11-01 EOL，1.4 LTS 於 2026-11-17 EOL。來源：duckdb.org/release_calendar。
11. TAIFEX：「No API」改為「無歷史 tick 資料 API」。官方免費的 TAIFEX OpenAPI（以及 TWSE OpenAPI）確實存在，提供每日報表、法人部位與契約調整資料，並已新增一列。來源：openapi.taifex.com.tw、openapi.twse.com.tw（Swagger 規格）。
12. TWSE 資訊廠商授權：補充說明資料費超過 NT$200,000 時可抵銷 NT$60,000 的授權費，且 NT$100,000 的網際網路資料費適用於自動更新資料。來源：twse.com.tw 即時資料頁面。
13. 情境 (a) 的內部矛盾：每月 $0–500 的預算原本建議 Tardis.dev「Academic 或 Solo」，但 Solo 每月 $700 起，而 Academic 僅能按季或按年計費，且以學術使用者為對象。內文現已如實說明。來源：tardis.dev 定價。
14. 新增遺漏的選項：Alpaca Market Data（免費 IEX；所有美國交易所加 OPRA 每月 $99）、Norgate Data（無存活者偏差的日資料，僅限 Windows），以及 TWSE/TAIFEX OpenAPI。來源：alpaca.markets/data、norgatedata.com、openapi.twse.com.tw、openapi.taifex.com.tw。
15. 新增遺漏的風險：Databento 將於 2026-10-31 追溯重新指派 2023-11-28 以前 Nasdaq TotalView-ITCH 資料中的 `instrument_id` 值，並回補冬季盤後資料。這支持保留我們自己的證券主檔 ID，並對供應商快照進行版本控管。來源：databento.com/blog/nasdaq-historical-data-changes-2026-09。

### 無法驗證

1. Cboe DataShop 牌價（含 Greeks 的全市場 EOD $420/月或 $4,200/年；單一代碼 $35/月）。定價頁位於 Cloudflare 防護之後，公開頁面未顯示牌價。僅確認了「available from January 2012」（自 2012 年 1 月起提供）。
2. EODHD 對台灣（`.TW`）的涵蓋。公開的交易所清單（截至 2026 年 8 月共 70 家交易所）在沒有 API 金鑰時不會顯示。
3. Databento「exchange fees passed through without markup」（交易所費用按原價轉嫁、不加價）。在目前的定價頁上找不到此說法，因此已改為經驗證的陳述：Standard 含即時資料，無另外的授權費。
4. OptionMetrics IvyDB 自 1996 年起的涵蓋範圍，以及僅能透過 WRDS 存取。本輪未重新查核。
5. Databento US Equities Standard 在 2025 年 1 月上市數據之外的目前歷史深度（定價頁僅顯示 CME 表格）。
