[English](ADR-0004-parquet-lake-for-historical-data.md) | **繁體中文**

# ADR-0004：歷史資料的儲存與格式：以 DuckDB 與 Polars 查詢的 Parquet 資料湖

## 狀態

**提議中（Proposed）** · 2026-10-05 · 範圍：情境 1，並包含觸發條件 T4 下的成長路徑。Phase 0 的 DuckDB 2.0 升級檢查將會更新本 ADR。

## 背景與問題陳述

研究、兩個回測層級以及 golden-master 重播都需要相同的歷史資料：成交與報價（L1）、K 棒、資金費率歷史、選擇權鏈快照、利率與總經資料的版本（vintage），以及之後的 L2/L3 委託簿。這些資料必須具備時點（point-in-time，PIT）正確性，且在多年後仍可重現。它必須讓單一操作者能以低成本運行，並能在從筆電到雲端 VM 的任何作業系統上執行。這些資料應存放在何處、採用何種格式？

考量因素（[03](../../research/03-market-data-storage.zh-TW.md)、[09](../../research/09-research-ml-analytics.zh-TW.md)）：

- **工作負載。** 單一寫入者（我們的匯入（ingest）流程）、以批次為主的讀取、情境 1 的精細度為 K 棒加 L1，且歷史儲存不需要次秒級的資料新鮮度。即時擷取的資料只需錄製下來以供重播。
- **2026-10-05 時的候選方案：**
  - Parquet + Arrow + DuckDB/Polars：MIT/Apache-2.0，嵌入式，任何作業系統皆可執行。
  - QuestDB 10.0.1：Apache-2.0；複寫與 OIDC 僅限 Enterprise 版。
  - ClickHouse 26.8 LTS：Apache-2.0；需要伺服器維運；沒有原生的 Windows 伺服器。
  - TimescaleDB 2.30：其 TSL 功能不得作為資料庫服務販售。
  - KDB-X：免費的 Community 版上限為 16 GB RAM。
  - ArcticDB：BSL 1.1，任何商業用途都需要簽訂協議。
  - InfluxDB 3 Core：專為近期資料而設計。
- **DuckDB 生命週期。** DuckDB 1.5.6 為目前版本，2.0.0 預定於 2026-10-21 發布，1.5 於 2026-11-01 終止支援（end of life），1.4 LTS 系列則於 2026-11-17 終止支援。
- **Schema。** Databento DBN（Apache-2.0）與 NautilusTrader 採用相同的結構：int64 奈秒 `ts_event`/`ts_recv`、縮放整數價格，以及數值型的商品 ID。
- **PIT 與供應商異動。** 供應商會重述（restate）歷史資料。Databento 將於 2026-10-31 重新指派部分 2023 年以前的 Nasdaq `instrument_id` 值。因此，供應商 ID 不能作為我們的鍵值，且必須保留原始酬載（raw payload）。
- **授權。** 多數零售資料方案僅限個人使用，且預設禁止再散布，因此每一列資料都需要授權標籤。

## 決策驅動因素

- 對單一人員而言零維運；可在 Linux、macOS 與 Windows 上執行。
- 可重現性：回測會鎖定（pin）其所讀取的確切位元組。
- 時點正確性，以及能夠重播正規化錯誤。
- 相同的檔案同時供應研究、向量化層級與 NautilusTrader catalog。
- 依資料集進行授權合規。
- 通往多寫入者或大量並行使用者的明確升級路徑。

## 考慮的選項

1. **採用 DBN 相容 schema、內容雜湊資料集清單（manifest），並以 DuckDB 加 Polars 查詢的 Parquet 資料湖（bronze/silver/gold）。** 僅在觸發條件成立時才加入表格式（table format）與熱資料庫。
2. **以時序資料庫作為權威資料來源（system of record）**（QuestDB、ClickHouse 或 TimescaleDB）。
3. **kdb+/KDB-X。**
4. **ArcticDB。**
5. **從第一天起就採用 Iceberg 或 DuckLake 快照的資料湖。**

## 決策結果

**選定選項：1，「以 DuckDB 與 Polars 查詢的 Parquet 資料湖」。** 它在任何作業系統上都零維運，其欄式掃描對 K 棒與 L1 研究而言速度已足夠，而內容雜湊清單無需表格式 catalog 即可提供單一寫入者情境下的可重現性。

| 面向 | 決策 |
|---|---|
| 分層 | `bronze/`：原始供應商酬載，不可變更。`silver/`：正規化後的標準（canonical）schema。`gold/`：K 棒、特徵與 NautilusTrader `ParquetDataCatalog`。`quarantine/`：未通過檢查的分區，並附上原因 |
| 標準 schema | 與 DBN 相容的 Arrow schema。共用欄位：`ts_event`、`ts_recv`（int64 UTC 奈秒）、`instrument_id`（我們的內部 ID）、`venue`、`source`、`license_tag`、`ingest_batch`。價格與數量為以 1e-9 縮放的 int64，除非該商品宣告了其他縮放比例（[ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.zh-TW.md)）。資料表：`trades`、`quotes`（MBP-1）、`bars`、`funding`、`option_chain_snap`、`instrument_status`、`macro_vintage`；之後再加入 `book_mbp10`/`book_mbo` |
| 檔案 | 採 zstd 壓縮的 Parquet、Hive 式分區（股票依日期與交易場所；加密貨幣依交易場所與日期；選擇權鏈依標的與到期日），以及排程壓實（compaction） |
| 可重現性 | 每個分區都經過內容雜湊。**資料集清單（dataset manifest）** 列出各分區的雜湊值，而其本身的雜湊值會鎖定於每一份執行清單（run manifest）中（`data_manifest_hash`） |
| 時點 | 僅使用原始（未調整）價格。公司行動為獨立事件（[ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md)）。調整後序列是僅供訊號使用的衍生檢視。基本面資料以公告時間為鍵，總經資料以 ALFRED vintage 為鍵，且投資範圍（universe）包含已下市標的 |
| 品質 | 每次匯入都執行的檢查：相對於交易時段行事曆的缺口（包含 TAIFEX 夜盤與 24/7 的加密貨幣）、重複或亂序的時間戳記、交叉報價（crossed quotes）、異常尖峰、成交量與供應商統計的比對、K 棒與逐筆資料的比對，以及抽樣的跨供應商比較。未通過者會送入隔離區，絕不默默捨棄。匯入對每個 `(source, partition)` 皆具冪等性 |
| 查詢引擎 | DuckDB 1.5.6，**於 2026-10-21 發布後轉換至 2.0**（不要在 2026-11-01 之後仍停留在 1.5）；Polars 1.44.x；PyArrow。pandas 3 僅用於函式庫邊界 |
| 即時擷取 | NautilusTrader 資料客戶端與 CCXT 擷取會錄製至 `bronze/`，以供 golden 重播。情境 1 中沒有熱時序資料庫 |
| 存放位置 | 交易或研究主機上的本機 NVMe，並鏡像至 S3 相容的儲存桶（bucket）。原始逐筆資料絕不從內部儲存匯出 |
| 不存放於此處的資料 | 證券主檔（security master）、規則包（rules packs）、公司行動表與交易帳本存放於 PostgreSQL 18（[ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.zh-TW.md)、[ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md)） |
| 授權 | 每個 row group 與清單上都帶有 `license_tag`，並依 `data/licence-registry.yaml` 解析（[ADR-0009](ADR-0009-open-source-licensing-strategy.zh-TW.md)） |
| 避免 | ArcticDB（BSL；商業用途需簽訂協議）；若日後規劃提供服務，則避免 TimescaleDB TSL 功能；付費的 kdb+；以 Kafka 作為儲存；若日後規劃提供服務，則避免 lakeFS v1.87+（BSL） |

**成長路徑（觸發條件 T4：即時逐筆擷取、多個並行儀表板，或多個寫入者）：**

- 以 QuestDB 10 進行即時擷取。
- DuckLake 或 Iceberg 資料表，其快照 ID 取代執行清單中的清單雜湊。
- 以 ClickHouse 26.8 LTS 支援大量並行使用者。
- 視預算採用授權資料供應商（Databento 散布方案層級、Tardis、TEJ、TWSE Data E-Shop）。

### 後果

**正面**

- 歷史資料無需運行資料庫伺服器。相同的檔案可同時供 notebook、向量化層級與 `BacktestNode` 使用。
- 任何日期的回測都可依其清單逐位元組重現。原始的 bronze 資料讓我們能重播正規化修正。
- DBN 相容性意味著若日後購買 Databento 資料，可直接載入而無需轉換。
- 我們自己的 ID 在供應商重述資料後仍能保持不變。

**負面**

- 沒有即時匯入伺服器，也不支援並行寫入者。兩者都需要 T4 的擴充項目。
- 小檔案與 schema 漂移需要排程壓實與版本化 schema。
- DuckDB 2.0 遷移發生在決策後數週內，且必須經過測試（Phase 0）。
- 內容雜湊清單是我們自己的慣例，而非標準的表格式，因此相關工具必須由我們自行維護。

### 確認

- 匯入測試套件會演練每一項品質檢查與隔離路徑。
- Golden-master 回測會鎖定清單雜湊，並在 CI 中重現其事件雜湊。
- Schema 檢查會拒絕非整數的價格與數量欄位，以及缺少 `license_tag` 的資料列。
- Phase 0 的 DuckDB 2.0 檢查會在 2.0 上執行研究與匯入測試套件。

### 何時重新檢視

- **T4** 觸發（即時逐筆擷取、大量並行讀取者，或多個寫入者）。
- L2/L3 資料到位（T5）：加入 `book_mbp10`/`book_mbo`，並搭配定期快照。
- 對外提供服務（T1）：權限服務（entitlement service）必須在 API 層強制執行 `license_tag`，且資料方案必須為商業或散布授權。

## 連結

- [主報告：市場資料儲存列與成本表](../../README.zh-TW.md)
- [建議架構 §3.1、§4.3 與 §4.9](../../architecture/recommended-architecture.zh-TW.md)
- [評估紀錄：嫁接項（graft）28 與疑慮（concern）10](../../architecture/evaluation.zh-TW.md)
- 研究：[03 市場資料儲存](../../research/03-market-data-storage.zh-TW.md) · [09 研究與機器學習](../../research/09-research-ml-analytics.zh-TW.md) · [11 台灣在地化](../../research/11-taiwan-market-localization.zh-TW.md)
- 相關 ADR：[ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.zh-TW.md) · [ADR-0009](ADR-0009-open-source-licensing-strategy.zh-TW.md) · [ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md) · [ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.zh-TW.md)
