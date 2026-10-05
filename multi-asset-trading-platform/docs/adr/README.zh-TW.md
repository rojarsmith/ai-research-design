[English](README.md) | **繁體中文**

# 架構決策紀錄（Architecture Decision Records）

*索引 · 狀態截至 2026-10-05 · 搭配[主報告](../../README.zh-TW.md)、[建議架構](../../architecture/recommended-architecture.zh-TW.md)與[評估紀錄](../../architecture/evaluation.zh-TW.md)閱讀。*

這些紀錄記載建議架構背後的關鍵決策：決定了什麼、權衡過哪些替代方案，以及每項選擇的代價。它們採用 [MADR](https://adr.github.io/madr/) 結構：

- 狀態
- 背景與問題陳述
- 決策驅動因素
- 考量的選項
- 決策結果，包含後果（正面與負面）、確認方式與重新檢視的觸發條件
- 連結

每份紀錄在專案負責人接受之前，狀態皆為**提議中（Proposed）**。Phase 0 的 spike 將會更新其中數份。版本與價格為 2026-10-05 的快照；正式採用前請重新驗證。本文內容皆不構成法律、稅務或投資建議。

## 索引

| # | 標題 | 狀態 | 一句話摘要 |
|---|---|---|---|
| 0001 | [核心引擎語言與策略語言](ADR-0001-core-engine-and-strategy-language.zh-TW.md) | 提議中 | 以 Python 3.14 撰寫策略，執行於 NautilusTrader v2 所採用的 Rust 核心之上；我們不撰寫 Rust，但必須有一個人讀得懂它；`tp_signals` 保持與引擎無關（engine-agnostic）且相容於 3.11 |
| 0002 | [回測引擎：擴充 NautilusTrader v2，而非自建或分叉（fork）](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md) | 提議中 | 在 `StrategyRuntime` 埠（port）之後執行未經修改的 NautilusTrader；加入我們自己的手續費、資金費率（funding）、公司行動（corporate action）、台灣規則與提前指派（early assignment）模組；LEAN 為備援方案 |
| 0003 | [數值表示法與時間戳記精度](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.zh-TW.md) | 提議中 | 各層使用精確的定點數值（引擎用 i128、資料湖用 int64 1e-9、帳本用 `NUMERIC`、傳輸時（on the wire）用十進位字串），float64 僅用於模型，所有事件時間皆使用 UTC int64 奈秒 |
| 0004 | [歷史資料儲存與格式](ADR-0004-parquet-lake-for-historical-data.zh-TW.md) | 提議中 | bronze/silver/gold 三層 Parquet 資料湖，採用 DBN 相容的 schema 與內容雜湊（content-hashed）的 manifest，以 DuckDB（2026-10-21 之後為 2.0）與 Polars 查詢；熱資料庫僅在 T4 才引入 |
| 0005 | [即時訊息傳遞與部署形式](ADR-0005-messaging-and-deployment-topology.zh-TW.md) | 提議中 | 每個帳戶一個節點，節點內使用行程內（in-process）匯流排；Valkey streams 負責對外輸出（egress）與控制（NATS 為備援）；約十個容器部署於單一具固定 IP 的 Docker Compose Linux 主機 |
| 0006 | [券商與交易所連線](ADR-0006-broker-connectivity-and-gateway-contract.zh-TW.md) | 提議中 | 埠（ports）與能力旗標（capability flags）；IBKR 與加密貨幣使用上游 adapter；由平台定義的台灣閘道（gateway）合約，由 Shioaji sidecar 提供服務，並在 T3 由 Windows 閘道 VM 為僅支援 Windows 的券商 API 提供服務 |
| 0007 | [跨平台前端與圖表](ADR-0007-web-first-client-and-charting-stack.zh-TW.md) | 提議中 | 先做 React + TypeScript 網頁工作站加上 Telegram/ntfy；之後再做 Tauri 2 與 PWA 推播；Lightweight Charts、uPlot、ECharts、AG Grid Community 與 KLineChart；不使用 TradingView Advanced Charts |
| 0008 | [金鑰與機密管理](ADR-0008-key-and-secret-management.zh-TW.md) | 提議中 | 以 SOPS + age 逐容器掛載；僅限交易、停用提領、綁定 IP 的金鑰，每 90 天輪替；`.pfx` 僅存在於 Shioaji sidecar 與 kill switch（緊急停止開關）；情境 2 改用 OpenBao |
| 0009 | [開源授權策略](ADR-0009-open-source-licensing-strategy.zh-TW.md) | 提議中 | 依散布情境制定的政策：引擎在伺服器端執行；任何會散布的東西中都不含 LGPL、GPL、AGPL 或 Commons Clause 程式碼；在 CI 中進行 SPDX 掃描；所有資料皆標記 `license_tag` |
| 0010 | [真實資金閘門與相依套件版本鎖定](ADR-0010-real-money-gate-and-dependency-pinning.zh-TW.md) | 提議中 | 投入實盤資金需要 NautilusTrader GA，或鎖定版本的 RC 加上 30 天無異常的 soak 測試、已簽署的風險接受書與 10% 上限；精確版本鎖定、每月升級時段、相依性風險登記冊 |
| 0011 | [意圖 WAL、雜湊鏈帳本與對帳](ADR-0011-intent-wal-and-hash-chained-ledger.zh-TW.md) | 提議中 | 每筆下單意圖（order intent）送出前先 fsync；僅能附加（append-only）、以 SHA-256 串鏈的 PostgreSQL 帳本，並提供 WORM 匯出；啟動、盤中與收盤後對帳，作為發布阻擋條件（release blocker） |
| 0012 | [證券主檔、規則包與交易日曆](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md) | 提議中 | 自有商品 ID，採用記錄 `known_at` 的生效日期（effective-dated）資料列；市場規則以生效日期 YAML 規則包表示（包含捨入與最低手續費）；單一 `CalendarPort` |
| 0013 | [風控閘門與三路徑 kill switch](ADR-0013-risk-gate-and-three-path-kill-switch.zh-TW.md) | 提議中 | 在所有模式中都相同的失效即關閉（fail-closed）檢查，再加上 NautilusTrader 的 `RiskEngine` 與交易場所端控制；kill switch 經由節點、獨立服務（每個站點一個）以及交易場所的 dead-man 計時器觸發 |
| 0014 | [雙層回測與晉級閘門](ADR-0014-two-tier-backtesting-and-promotion-gates.zh-TW.md) | 提議中 | 共用 `tp_signals` 的向量化層與事件驅動（event-driven）層；由 CI 強制執行的確定性（determinism）合約；MLflow 試驗登錄；G0–G4 閘門，要求 DSR ≥ 0.95 且 PBO ≤ 0.2 |
| 0015 | [自用監理定位與法律閘門](ADR-0015-self-use-regulatory-posture-and-legal-gate.zh-TW.md) | 提議中 | 僅供擁有者自有帳戶使用的自主操作軟體（self-directed software）；不提供訊號、跟單交易或資料再散布；在開放任何外部使用者（T1）之前，須先完成法律審查並簽核 ADR |
| 0016 | [多幣別帳冊、稅務批次、扣繳與司法管轄區稅務外掛](ADR-0016-multi-currency-books-tax-lots-and-tax-plugins.zh-TW.md) | 提議中 | 各幣別分別記錄現金，並明確記錄匯兌換算；`TaxLot` 採用與券商一致的批次計算方法；扣繳事件；台灣居民外掛，產出年度新台幣（TWD）摘要；不構成稅務建議 |
| 0017 | [AI 信任邊界](ADR-0017-ai-trust-boundary.zh-TW.md) | 提議中 | AI 輸出僅能成為提案，須經過 `tp_risk` 與人工核准；AI 專用 token 不具下單、控制或限額權限；不接觸機密；網路隔離；稽核日誌；`llm_export_allowed` 授權檢查 |

## 與建議架構中候選清單的對應

[建議架構](../../architecture/recommended-architecture.zh-TW.md)的 §10 列出 19 項候選決策，涵蓋情形如下：

| 候選項目（§10） | 涵蓋於 |
|---|---|
| 1. 在 `StrategyRuntime` 之後擴充 NautilusTrader v2，LEAN 為備援 | [ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md) |
| 2. 針對 release candidate 引擎的真實資金閘門 | [ADR-0010](ADR-0010-real-money-gate-and-dependency-pinning.zh-TW.md) |
| 3. Python 3.14 主映像檔；舊版量化（legacy-quant）映像檔視需求提供 | [ADR-0001](ADR-0001-core-engine-and-strategy-language.zh-TW.md) |
| 4. Parquet 資料湖、DBN 相容 schema、DuckDB/Polars、manifest | [ADR-0004](ADR-0004-parquet-lake-for-historical-data.zh-TW.md) |
| 5. 具 `known_at` 的生效日期證券主檔；自有 ID | [ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md) |
| 6. 以生效日期資料表示的規則包，包含捨入與最低手續費 | [ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md) |
| 7. 意圖 WAL、雜湊鏈帳本、對帳作為發布阻擋條件 | [ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.zh-TW.md) |
| 8. 節點對外輸出使用 Valkey streams（NATS 為備援） | [ADR-0005](ADR-0005-messaging-and-deployment-topology.zh-TW.md) |
| 9. 依循邊緣連接器（edge-connector）合約的 Shioaji sidecar；MVP 不含 Windows 閘道 | [ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.zh-TW.md) |
| 10. 三路徑 kill switch 與各交易場所的 dead-man 語意 | [ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.zh-TW.md) |
| 11. 公司行動與提前指派模擬；台灣撮合擴充（或 T7） | [ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md)、[ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.zh-TW.md) |
| 12. 共用指標函式庫的雙層回測；G0–G4 閘門 | [ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.zh-TW.md) |
| 13. 網頁優先 UI；之後再做 Tauri 與 PWA 推播；傳輸時使用十進位字串 | [ADR-0007](ADR-0007-web-first-client-and-charting-stack.zh-TW.md)、[ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.zh-TW.md) |
| 14. 授權政策 | [ADR-0009](ADR-0009-open-source-licensing-strategy.zh-TW.md) |
| 15. 單主機 Compose 部署與可部署規則（deployable rule） | [ADR-0005](ADR-0005-messaging-and-deployment-topology.zh-TW.md) |
| 16. 相依性風險登記冊 | [ADR-0010](ADR-0010-real-money-gate-and-dependency-pinning.zh-TW.md) |
| 17. 「自主操作軟體」監理定位與法律閘門 | [ADR-0015](ADR-0015-self-use-regulatory-posture-and-legal-gate.zh-TW.md) |
| 18. 多幣別帳冊、稅務批次與司法管轄區稅務外掛 | [ADR-0016](ADR-0016-multi-currency-books-tax-lots-and-tax-plugins.zh-TW.md) |
| 19. AI 信任邊界 | [ADR-0017](ADR-0017-ai-trust-boundary.zh-TW.md) |

後續新增的項目是擴充既有紀錄，而非另立新紀錄：半自動交易與外部訂單政策（[ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.zh-TW.md)、[ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.zh-TW.md)）；放空、借券與融資（[ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md)、[ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md)）；加密貨幣交易場所的交易對手風險（[ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.zh-TW.md)）；災難復原（[ADR-0005](ADR-0005-messaging-and-deployment-topology.zh-TW.md)、[ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.zh-TW.md)）；LEAN 移植成本表（[ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md)）。

## 對主要文件的修訂（已套用）

撰寫這些紀錄時，發現[主報告](../../README.zh-TW.md)與[建議架構](../../architecture/recommended-architecture.zh-TW.md)之間，或後者內部，共有五處不一致。每份 ADR 都提出了解決方式。**這五項以及下方較小的訊息傳遞列問題，皆已於 2026-10-05 套用至主要文件**；「狀態」欄說明套用位置。

| # | 不一致之處 | 解決方式 | 狀態 |
|---|---|---|---|
| 1 | README 的安全性列、§2 與 §8.4 檢查清單指出，台灣的 `.pfx` **僅**掛載至 Shioaji sidecar。§3.5 與 §3.12 讓 kill switch 擁有自己的 Shioaji 工作階段，而這需要該憑證。§7 的分離式拓撲將 kill switch 放在東京，遠離券商白名單中的 IP | [ADR-0008](ADR-0008-key-and-secret-management.zh-TW.md)、[ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.zh-TW.md)：將 `.pfx` 恰好掛載至兩個容器（sidecar 與 kill switch），並在每個站點執行一個 kill switch 執行個體 | **已套用：** README 安全性列與元件圖；架構文件 §2、§3.5、§3.12、§7（每個站點一個 kill switch 執行個體）以及 §8.4 檢查清單 |
| 2 | README 與 §2 稱 kill switch 擁有「自己的登入憑證」，但就 IBKR 而言，它與 IB Gateway 共用登入（§3.5），而獨立工作階段尚未經過驗證 | [ADR-0008](ADR-0008-key-and-secret-management.zh-TW.md)、[ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.zh-TW.md)：在 Phase 0 驗證第二個使用者名稱之前，明確載明 IBKR 的但書 | **已套用：** 該但書（「在 Phase 0 驗證第二個使用者名稱之前，路徑 2 並未獨立於 IB Gateway；券商 App 是最後手段」）已寫入 README 的控制（Control）條目、元件圖與風險表，以及架構文件 §2、§3.5 與 §8.4 |
| 3 | README 稱台灣 sidecar「依邊緣連接器合約建構」，而 T3 將 Windows 閘道置於「HTTP/gRPC 或 NATS leaf node」之後。§2 將 sidecar 定義為永豐金（SinoPac）自家的 `shioaji server start`，§7 則說 Windows shim 提供「與 Shioaji sidecar 相同的閘道合約（HTTP/SSE）」。但該合約從未被定義 | [ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.zh-TW.md)：定義一份由平台擁有的台灣閘道合約（Protobuf；情境 1 採 HTTP + SSE，情境 2 採 NATS leaf node）；sidecar 在 Shioaji 之上執行一層 shim | **已套用：** README 結論段、券商列、接縫（seams）表與 T3；架構文件 §2（合約 shim）、§3.4（合約定義）與 §7 |
| 4 | README 原則 3 稱金額以「引擎**與帳本**中的定點整數」保存；§3.6 與 §4.1 則規定帳本使用 PostgreSQL `NUMERIC` 與 `Decimal` | [ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.zh-TW.md)：「精確的定點數值」，意指引擎與資料湖中使用縮放整數（scaled integers），帳本中使用依小數位數量化（scale-quantized）的 `NUMERIC`/`Decimal` | **已套用：** README 原則 3 |
| 5 | README 原則 4 稱「**所有地方**都使用 UTC int64 奈秒」，但 §4.2 與 §4.4 的 schema 對 `valid_from`、`known_at` 與 `ts_recorded` 使用 `TIMESTAMPTZ`。資料湖儲存 `ts_recv`，而重播（replay）依 `ts_init` 合併，兩者之間未定義對應關係 | [ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.zh-TW.md)：所有*事件*時間使用 int64 奈秒；`TIMESTAMPTZ` 僅用於簿記用的中繼資料；catalog 建置時設定 `ts_init = ts_recv`（若無接收時間則使用 `ts_event`） | **已套用：** README 原則 4 |

一個較小的用詞問題：README 的訊息傳遞列在 Valkey streams 旁列出「Protobuf 合約」，然而 §5.1 規定這些 streams 上使用 NautilusTrader 的 JSON/MessagePack。[ADR-0005](ADR-0005-messaging-and-deployment-topology.zh-TW.md) 在 Valkey 上保留引擎原生的酬載（payload），並在日誌（journal）與 API 邊界才套用 Protobuf。已**套用**至 README 的訊息傳遞列。

## 將更新這些紀錄的 Phase 0 驗證項目

| 驗證項目 | ADR |
|---|---|
| NautilusTrader v2 的樹外（out-of-tree）adapter API；台灣撮合擴充（否則採 T7）；`BacktestNode` 中的公司行動模組 | [0002](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md)、[0006](ADR-0006-broker-connectivity-and-gateway-contract.zh-TW.md) |
| 以 Valkey 作為 NautilusTrader 的 Redis 後端，以及對外輸出格式 | [0005](ADR-0005-messaging-and-deployment-topology.zh-TW.md) |
| IBKR `reqGlobalCancel` 與 master client ID 的比較；2FA 頻率；第二個使用者名稱 | [0008](ADR-0008-key-and-secret-management.zh-TW.md)、[0013](ADR-0013-risk-gate-and-three-path-kill-switch.zh-TW.md) |
| 各交易場所與各產品對 dead-man 及斷線取消（cancel-on-disconnect）的支援 | [0013](ADR-0013-risk-gate-and-three-path-kill-switch.zh-TW.md) |
| Shioaji shim 做法、以極小額真實訂單測試零股、第二工作階段的取消路徑；台灣券商是否接受雲端 IP | [0006](ADR-0006-broker-connectivity-and-gateway-contract.zh-TW.md)、[0005](ADR-0005-messaging-and-deployment-topology.zh-TW.md) |
| TAIFEX（臺灣期貨交易所）夜盤交易日規則；2027 年假日；以真實對帳單核對捨入與最低手續費 | [0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.zh-TW.md)、[0012](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md) |
| 每個鎖定版本皆有 Python 3.14 wheel；DuckDB 2.0 升級 | [0001](ADR-0001-core-engine-and-strategy-language.zh-TW.md)、[0004](ADR-0004-parquet-lake-for-historical-data.zh-TW.md) |
| NautilusTrader 2.0 GA 日期與 rc6 的變更 | [0010](ADR-0010-real-money-gate-and-dependency-pinning.zh-TW.md) |
| FinMind 贊助方案（sponsor tier）用於個人實盤交易的條款；FinMind 與 TEJ 報價 | [0009](ADR-0009-open-source-licensing-strategy.zh-TW.md) |
| NautilusTrader 對每個上游 adapter 的在途訂單（in-flight order）對帳；IB adapter 對 `orderRef` 的使用方式 | [0002](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md)、[0006](ADR-0006-broker-connectivity-and-gateway-contract.zh-TW.md)、[0011](ADR-0011-intent-wal-and-hash-chained-ledger.zh-TW.md) |
| 各加密貨幣永續合約與選擇權交易場所對台灣居民的適格性（金管會 FSC 洗錢防制登記名單、交易場所的地區條款） | [0006](ADR-0006-broker-connectivity-and-gateway-contract.zh-TW.md)、[0013](ADR-0013-risk-gate-and-three-path-kill-switch.zh-TW.md)、[0015](ADR-0015-self-use-regulatory-posture-and-legal-gate.zh-TW.md) |
| 依券商合約與對帳單核對放空與融資的規則及費用；借券資料來源 | [0012](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md) |
| Massive 對已下市美股代號的公司行動涵蓋範圍 | [0004](ADR-0004-parquet-lake-for-historical-data.zh-TW.md)、[0012](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md) |
| IBKR 串流方案組合（streaming bundles）、OPRA 與市場資料線（market-data line）上限 | [0006](ADR-0006-broker-connectivity-and-gateway-contract.zh-TW.md) |
| 該稅務年度的台灣居民稅率與門檻 | [0016](ADR-0016-multi-currency-books-tax-lots-and-tax-plugins.zh-TW.md) |

## 新增紀錄

1. 複製上方任一紀錄的章節結構。使用下一個可用編號與 kebab-case 名稱：`ADR-NNNN-short-title.md`。
2. 第一行為語言切換列（`**English** | [繁體中文](ADR-NNNN-short-title.zh-TW.md)`），接著一個空行，然後是 H1 標題。（對應的繁體中文版 `ADR-NNNN-short-title.zh-TW.md`，第一行則為 `[English](ADR-NNNN-short-title.md) | **繁體中文**`。）
3. 以**提議中（Proposed）**狀態起始。當某份紀錄變更了某項決策時，將舊紀錄標記為**已由 ADR-NNNN 取代（Superseded by ADR-NNNN）**，而非修改其決策結果。
4. 路線圖要求日後補上的紀錄包括：針對 RC 引擎的已簽署風險接受 ADR（[ADR-0010](ADR-0010-real-money-gate-and-dependency-pinning.zh-TW.md)）、G3 的單人營運者晉級檢查清單（[ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.zh-TW.md)），以及 T1 法律簽核（[ADR-0015](ADR-0015-self-use-regulatory-posture-and-legal-gate.zh-TW.md)）。
5. 在上方索引中新增一列。
