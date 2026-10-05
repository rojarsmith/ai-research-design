[English](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.md) | **繁體中文**

# ADR-0003：價格與數量的數值表示法，以及時間戳記精度

## 狀態

**提議中（Proposed）** · 2026-10-05 · 範圍：所有情境。本 ADR 亦修正了主報告設計原則 3 與 4 的措辭（見*決策結果*；已於 2026-10-05 套用）。

## 背景與問題陳述

價格、數量與金額會流經引擎、行情資料湖（market-data lake）、PostgreSQL 帳本、API 與瀏覽器。每一層都有不同的原生數值型別。時間戳記也有相同的問題。若每一層各自選擇表示法，結果就是損益出現捨入漂移、成交無法通過升降單位（tick）檢查，以及因時間被截斷而產生的前視（look-ahead）或排序錯誤。

精度需求因資產類別而異（[01](../../research/01-core-language-runtime.zh-TW.md)、[05](../../research/05-instrument-model-pricing-analytics.zh-TW.md)）：

| 資產類別 | 精度的決定因素 |
|---|---|
| 台股與 ETF | 依價格區間，升降單位從 NT$0.01 到 NT$5 不等；ETF 在 NT$50 以下為 0.01，以上為 0.05。升降單位級距比小數位數更重要 |
| 美股 | $1 以下有低於一美分（sub-penny）的報價；股價可達六位數 |
| 加密貨幣 | CEX 數量通常有 ≤8–10 位小數。鏈上 ERC-20 金額為 `uint256`，通常有 18 位小數：1 wei（1e-18）無法放進 16 位小數的型別。大發行量代幣的交易量可能超過 ±92 億單位 |
| 債券 | 美國公債以 1/32 報價，最細到 1/256（0.00390625，八位小數）；價格以面額百分比表示；數量為面額 |
| 選擇權 | 權利金小且升降單位分級（TXO：10 點以下為 0.1 點，1,000 點以上最高為 10 點）；契約乘數使名目金額變大。Greeks 與隱含波動率本質上就是 float64 |

現有格式：NautilusTrader v2 預設使用 16 位小數的 128 位元定點數（`PRICE_MAX` 約為 ±17 兆；比 64 位元、9 位小數模式約慢 3–5%）。Databento DBN 使用以 1e-9 縮放的 int64。

時間陷阱：Python `datetime` 的解析度為 1 µs；pandas 3 會從字串與 `datetime` 物件推斷出 `datetime64[us]`；.NET `DateTime` 的 tick 為 100 ns。JavaScript 數值僅在 2^53（約 9.0e15）以內為精確，而目前的 UTC 奈秒時間戳記約為 1.76e18。TAIFEX 夜盤（15:00–05:00）跨越午夜，加密貨幣則 24/7 交易，因此交易日並不等於日曆日。

兩份來源文件在措辭上略有不一致（現已修正）：

- [主報告](../../README.zh-TW.md)的設計原則 3 表示金額以「引擎與帳本中的定點整數」保存。[建議架構](../../architecture/recommended-architecture.zh-TW.md) §3.6 與 §4.1 則規定帳本使用 PostgreSQL `NUMERIC`。
- 原則 4 表示「處處使用 UTC int64 奈秒」，但 §4.2 與 §4.4 的 schema 對 `valid_from`、`known_at` 與 `ts_recorded` 使用 `TIMESTAMPTZ`。資料湖儲存 `ts_recv`（§4.3），但重播（replay）卻依 `ts_init` 合併（§5.4、§5.5），兩者之間沒有定義對應關係。

## 決策驅動因素

- 凡是決策或入帳涉及金額之處，運算都必須精確且具確定性。
- 與 NautilusTrader 型別及 DBN 相容資料之間能無損交換。
- 在 Python、SQL 與 TypeScript 中皆行為正確。
- 範圍足以容納加密貨幣數量，並能精確表示 1/32 報價。
- 速度：熱路徑使用整數運算；僅在邊界使用精確十進位數。
- 單一且無歧義的事件時間型別，永不截斷，也絕不混淆交易日與日曆日。

## 考慮的選項

**數值**

1. 全面使用 float64。
2. 全面使用 Decimal（Python `decimal`、PostgreSQL `NUMERIC`），包括引擎在內。
3. **分層精確表示法：** 在引擎與儲存路徑上使用逐商品（per-instrument）定點整數；在會計邊界與傳輸線路（wire）上使用精確十進位數；float64 僅限於模型內部；轉換一律明確且依規則進行。
4. 所有層級皆使用單一全域 int64 縮放比例（1e-9）。

**時間**

1. Python `datetime` 與 pandas 的預設值。
2. **所有事件時間皆使用 UTC int64 奈秒**，`trading_date` 與 `session_id` 則由日曆服務推導。
3. 交易所當地時間戳記。

## 決策結果

**選定選項：數值選項 3（「分層精確表示法」）與時間選項 2（「UTC int64 奈秒加上 `CalendarPort`」）**。它們與已採用的引擎相符，讓每個涉及金額的決策都保持精確，並將浮點數限縮在模型之內，而模型的輸出會在入帳前先行捨入。

### 各層的表示法

| 層級 | 價格、數量、金額 | 時間 |
|---|---|---|
| 引擎（NautilusTrader `Price`、`Quantity`、`Money`） | 128 位元原始值（raw）、16 位小數（v2 預設），搭配逐商品的 `price_precision` 與 `size_precision` | `ts_event`、`ts_init`：UTC 奈秒 |
| 與引擎無關的領域層（`tp_domain`、`tp_signals`、`tp_risk`） | 依商品精度量化（quantize）的 `Decimal`；絕不使用 `float` | `*_ns` Python `int` |
| 行情資料湖（Parquet） | 以 1e-9 縮放的 int64（與 DBN 相容）。精度超過 9 位小數，或數值超過約 ±92 億單位的商品，須在商品主檔（security master）中宣告自己的縮放比例 | `ts_event`（交易場所時間）與 `ts_recv`（我方接收時間）為 int64 UTC ns；K 棒另外帶有 `trading_date` 與 `session_id` |
| 參考資料與帳本（PostgreSQL） | 依幣別或商品縮放比例量化的 `NUMERIC`：精確的定點十進位數，絕不使用 `real` 或 `double precision` | 事件時間為 `*_ns BIGINT`；`trading_date` 為 `DATE`；管理用中繼資料（`valid_from`、`valid_to`、`known_at`、`ts_recorded`）為 `TIMESTAMPTZ` |
| 傳輸線路與 UI（Protobuf，JSON 對應優先） | 十進位字串，或縮放整數加上縮放比例；絕不使用 JS `number` | int64 ns，Protobuf 的 JSON 對應本來就會將其編碼為字串；UI 將其解析為 `BigInt`，僅在顯示時才轉換為毫秒 |
| 模型（定價、Greeks、IV、VaR） | float64 | 傳入引擎時間戳記 |
| 鏈上轉接器（adapter） | `uint256` 最小單位整數，於轉接器邊界轉換 | 交易場所時間轉換為 UTC ns |

### 規則

1. **每次轉換都必須明確，並依宣告的規則捨入。** 捨入模式與最低手續費定義在規則包（rules pack）中（[ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md)），絕不寫死在程式的預設值裡。float64 模型輸出（例如 QuantLib 應計利息或模型評價）在入帳前須依交割慣例捨入。
2. **升降單位合規性在捨入之後檢查**，比對商品的 `tick_scheme_id`。
3. **數量具有型別**，以 `quantity_unit`（`SHARE`、`BOARD_LOT`、`CONTRACT`、`FACE_VALUE`、`COIN`）標示。台股零股是獨立的 `instrument_id`。
4. **債券價格**以面額百分比的定點十進位數儲存，並搭配可解析與顯示 1/32 報價的編解碼器（codec）。
5. **資料湖到引擎：** int64 1e-9 數值乘以 1e7 即轉換為 NautilusTrader 的 16 位小數原始值；當商品精度為 9 位小數以下時，此轉換無損。建置 Nautilus catalog 時設定 `ts_init = ts_recv`；若供應商未提供接收時間（例如日 K 棒），則設定 `ts_init = ts_event`。
6. **時間：** 策略與風控程式只讀取引擎時鐘。在決策程式中，`datetime.now`、`time.time`、未設定種子的隨機數與 I/O 皆由 lint 禁用。pandas 呼叫一律明確傳入 `unit="ns"`。主機執行 chrony。
7. **交易日與交易時段（session）** 只能來自 `CalendarPort`。TAIFEX 夜盤成交是否歸屬下一個交易日尚未驗證，將於 Phase 0 依 TAIFEX 規則確認。
8. **`TIMESTAMPTZ` 欄位僅供簿記（bookkeeping）用途。** 絕不用於事件排序或重播。

對[主報告](../../README.zh-TW.md)的**措辭修訂**（已於 2026-10-05 套用）：

- 原則 3 現為「精確的定點數值：引擎與資料湖中為逐商品縮放整數，帳本中為依縮放比例量化的 `NUMERIC`/`Decimal`」。
- 原則 4 現為「所有事件時間皆使用 UTC int64 奈秒」；管理用時間戳記可使用 `TIMESTAMPTZ`。

### 影響

**正面**

- 每個涉及金額的決策與入帳都精確且可重現。損益可與券商對帳單核對到分。
- 對一般商品而言，與 NautilusTrader 及 Databento DBN 之間的交換是無損的。
- 傳輸格式對 JavaScript 安全，奈秒級排序也能一路保留到 UI。
- 夜盤與加密貨幣 24/7 的日切點由單一服務處理，而非臨時拼湊的日期邏輯。

**負面**

- 存在多種表示法，因此可能出現轉換錯誤。必須採用屬性測試（property-based tests）。
- 128 位元定點數比 64 位元模式約慢 3–5%。此代價可以接受。
- 16 位小數無法容納 wei，因此 DeFi 金額必須在轉接器中維持 `uint256`。
- `NUMERIC` 比整數欄位慢。以帳本的資料量而言，這無關緊要。
- UI 需要十進位函式庫與 `BigInt` 處理。

### 確認

- 屬性測試（Hypothesis）：資料湖、引擎、`Decimal`、`NUMERIC` 與傳輸字串之間的轉換往返；捨入後的升降單位合規性；部位等於成交量總和。
- `tp_domain` 啟用 `decimal.FloatOperation` 陷阱（trap），因此混用 `float` 與 `Decimal` 會引發錯誤。
- 資料湖 schema 檢查會在匯入時拒絕以浮點欄位儲存價格與數量。
- CI 中執行 wall-clock 與 I/O lint；針對日光節約時間切換、TAIFEX 夜盤、颱風停市覆寫與加密貨幣每日日切進行日曆測試。

### 重新檢視時機

- 某個鏈下商品需要超過 16 位小數，或超過 ±17 兆的範圍。
- NautilusTrader 變更其精度模式。
- 效能剖析顯示 JSON 對應成為瓶頸。屆時改用搭配縮放整數的二進位 Protobuf。

## 連結

- [主報告：設計原則 3 與 4](../../README.zh-TW.md)
- [建議架構 §3.6、§4.1、§4.3、§5.3 與 §5.5](../../architecture/recommended-architecture.zh-TW.md)
- [評估紀錄：疑慮 14 與 16；嫁接項目 31、32 與 40](../../architecture/evaluation.zh-TW.md)
- 研究：[01 核心語言與執行環境](../../research/01-core-language-runtime.zh-TW.md) · [03 行情資料儲存](../../research/03-market-data-storage.zh-TW.md) · [05 商品與定價](../../research/05-instrument-model-pricing-analytics.zh-TW.md) · [06 用戶端 UI](../../research/06-cross-platform-client-ui.zh-TW.md) · [07 訊息傳遞](../../research/07-system-architecture-messaging.zh-TW.md)
- 相關 ADR：[ADR-0004](ADR-0004-parquet-lake-for-historical-data.zh-TW.md) · [ADR-0007](ADR-0007-web-first-client-and-charting-stack.zh-TW.md) · [ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.zh-TW.md) · [ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md)
