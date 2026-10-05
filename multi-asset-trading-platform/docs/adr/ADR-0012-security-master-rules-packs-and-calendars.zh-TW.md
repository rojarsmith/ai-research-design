[English](ADR-0012-security-master-rules-packs-and-calendars.md) | **繁體中文**

# ADR-0012：自有證券主檔、依生效日期的規則包與單一日曆 Port

## 狀態

**提議中（Proposed）** · 2026-10-05 · 範圍：情境 1，完整的雙時態（bitemporal）查詢延後至情境 2。Phase 0 的檢查（TAIFEX 夜盤規則、以真實對帳單核對的捨入規則、2027 年休市日）將會更新本 ADR。

## 背景與問題陳述

每一層（回測、交易前風控、即時執行、會計）都需要對以下三個問題得到相同的答案：

1. **這是什麼商品**（識別、精度、升降單位級距、交易單位、乘數、狀態），**以特定時點所知者為準**？
2. **市場規則是什麼**（升降單位、漲跌幅限制、競價、手續費、稅、捨入、交割、保證金），**以特定日期生效者為準**？
3. 某個時間戳記屬於**哪一個交易日與交易時段**？

考量因素（[03](../../research/03-market-data-storage.zh-TW.md)、[05](../../research/05-instrument-model-pricing-analytics.zh-TW.md)、[11](../../research/11-taiwan-market-localization.zh-TW.md)）：

- **供應商識別碼會變動。** Databento 將於 2026-10-31 重新指派部分 2023 年以前的 Nasdaq `instrument_id` 值，股票代號（ticker）會被重複使用，而 CUSIP 需要授權。
- **台灣的規則繁多且具有日期效力：**
  - 依商品類別而定的升降單位級距（股票 0.01–5；ETF 在 NT$50 以下為 0.01，以上為 0.05）；
  - ±10% 漲跌幅限制、集合競價，以及 3.5% 的瞬間價格穩定措施（volatility interruption）；
  - 零股為獨立的委託簿，採每 5 秒一次的集合競價；
  - 處置股票與暫停先賣後買（sell-first）的標的，每日更新；
  - 證券交易稅 0.3%，當沖則為 0.15%，**至 2027-12-31 止**；
  - 公司債與債券 ETF 的停徵證券交易稅措施（tax holiday），除非延長，否則**將於 2026-12-31 到期**；
  - 買賣雙方皆課徵的期貨交易稅。

  TWSE 的英文頁面上仍顯示當沖稅率的過時日期。
- **美國的規則也會變動。** SEC Section 31 規費每個會計年度重設一次。FINRA 盤中保證金（intraday margin）已於 2026-06-04 取代 PDT，但券商可在 2027-10-20 前逐步導入。
- **日曆。** `exchange_calendars` 有 XTAI，但沒有 TAIFEX 日曆。`pandas_market_calendars` 補上了 CME 與 SIFMA。QuantLib 的台灣日曆只到 2026 年。TAIFEX 夜盤交易時間為 15:00–05:00；其成交是否歸屬下一個交易日尚未驗證。颱風停市是臨時決定的，而加密貨幣需要一個人為設定的每日日切點。
- **時點（point in time）。** 完整雙時態的證券主檔成本高昂；可行性評審希望加以簡化，而正確性評審則希望保留時點資料（[評估紀錄](../../architecture/evaluation.zh-TW.md)，嫁接項 37）。

## 決策驅動因素

- 回測、風控與即時交易共用單一事實來源（single source of truth）。
- 不得有前視（look-ahead）：記錄當時已知的內容，以及得知的時間。
- 規則可依日期變動而無需修改程式碼，且可審查、可稽核。
- 精確的成本建模，包括捨入與最低手續費。
- 現在成本低廉，日後進行更豐富的查詢時也不會遺失資料。

## 考慮的選項

1. **在 PostgreSQL 中建立我們自己的證券主檔**（內部 `instrument_id`；依生效日期、僅附加（append-only）且記錄 `known_at` 的資料列），加上**以依生效日期之 YAML 形式存放於 git 中的規則包**，再加上**單一 `CalendarPort`**。
2. **以供應商 ID 作為鍵值**，並將規則依市場寫死在程式中。
3. 從第一天起就採用**完整的雙時態參考資料服務**。
4. **規則僅存放於資料庫資料表中**，並透過管理介面（admin UI）編輯。

## 決策結果

**選定選項：1。** 它能保護我們不受供應商重述資料的影響，讓規則成為可審查的資料，並從現在起就記錄 `known_at`，使日後能加入「以當時所知為準（as known at）」的查詢而無需遷移。

### 證券主檔

| 要素 | 決策 |
|---|---|
| 識別 | `instrument_id`：內部的 BIGINT 代理鍵（surrogate key），永不重複使用。供應商與交易場所的識別碼只存放於 `instrument_xref`（透過 OpenFIGI 取得的 FIGI、ISIN、OCC OSI、TAIFEX 代碼、交易場所代號、IB conId、Shioaji 代碼、CCXT 市場 ID；CUSIP 僅在取得授權後使用） |
| 時間 | 資料列依生效日期（`valid_from`、`valid_to`）、僅附加，並記錄 `known_at`。完整的雙時態查詢延後至情境 2 |
| 屬性 | 資產類別、MIC、市場區隔（整股、零股、日盤或夜盤）、精度、`tick_scheme_id`、`quantity_unit`、交易單位大小、乘數、`calendar_id`、標的、到期日、狀態，以及依生效日期的名稱 `name_en` 與 `name_zh_tw`（更名即新增一列）。台灣的整股與零股委託簿共用同一個 `security_id`，但各自擁有獨立的 `instrument_id` |
| 每日旗標 | `instrument_daily_flag`：處置等級、當沖資格（TWTB4U）、暫停先賣後買（TWTBAU1）、公告（notices）與漲跌幅制度，於開盤前從 TWSE/TPEx/TAIFEX OpenAPI 更新 |
| 借券與信用資料 | 各自帶有 `license_tag` 的資料集，以 `instrument_id` 與時間為鍵：**`borrow_availability`**（美國：來自 generic tick 236 的 IBKR 可放空等級與可放空股數；台灣：來自 TWSE `SBL/TWT96U`、可供借券賣出（SBL short sale）的可借股數）、**`borrow_rate`**（美國：IBKR 的可放空股票費率檔案，因為 TWS API 沒有費率 tick；台灣：券商的融券與借券費率表），以及 **`tw_credit_balance`**（融資融券餘額、額度、暫停融券賣出期間與強制回補日期，來源為 TWSE `MI_MARGN` 與 TPEx `tpex_mainboard_margin_balance`、`tpex_margin_sbl`、`tpex_margin_trading_term`） |
| 公司行動 | `corporate_action` 資料表（股票分割、反分割、現金股利與股票股利、減資、認股權（rights）、代號變更、合併、分拆（spin-off）、下市、交割標的調整（deliverable adjustments）），以 `announce_ns` 為鍵，供時點查詢使用。它同時供應回測模擬模組與即時帳本 |
| 領域型別 | `tp_domain` 中的 `OptionTerms` 與 `BondTerms`。`Bond` 是我們自己的型別，位於引擎之外 |

### 規則包

- **git 中的 YAML 是事實來源（source of truth）**，透過 pull request 審查，並鏡像至 PostgreSQL 以供查詢與 UI 使用。
- 規則包：`us`、`tw`、`taifex`、`crypto`。每條規則都具有 `valid_from`/`valid_to`、`params`、`legal_ref` 與 `verified_at` 日期。
- 涵蓋範圍：
  - 依商品類別而定的升降單位級距、交易單位大小與漲跌幅制度；
  - 競價階段與瞬間價格穩定措施；
  - 手續費與稅，**捨入模式與最低手續費**；
  - 交割延遲（settlement lag）與資金費率結算間隔（funding interval）；
  - 保證金表：Reg T、FINRA 盤中保證金、舊制 PDT、TAIFEX SPAN 參數；
  - `us` 與 `tw` 中的 **`short_sale`** 區段。美國：借券確認（locate）要求（Reg SHO Rule 203(b)）、Rule 201 賣空斷路器（自前一日收盤價下跌 10% 後，當日剩餘時間及次一交易日僅能以高於全國最佳買價（national best bid）的價格賣空）、難借券（hard-to-borrow）的召回與強制買入（buy-in）處理，以及代替股利的補償款（payment in lieu of dividends）。台灣：信用帳戶（信用交易）資格、融券與借券賣出（SBL short sales）為不同的委託類型、平盤以下（below-previous-close）限制及其豁免、股東會與除權息前後的融券暫停與強制回補日期，以及個股額度。金管會（FSC）曾在市場動盪時於短時間內變更台灣的放空規則，因此這些規則是依生效日期的規則，並具備緊急覆寫（emergency-override）路徑；
  - `us` 與 `tw` 中的 **`financing`** 區段：IBKR 融資利息級距與借券費用的應計慣例；融資成數、融券保證金成數與個股調整、維持率（maintenance ratio）與追繳（margin call）規則，以及券商的融資利息與融券/借券費用。在與券商合約及對帳單核對之前，這些數值僅供示意。
- 載入器會回傳一個**不可變且經雜湊的 `RulesPack`**，其雜湊值是每一個策略套件（strategy bundle）與執行清單（run manifest）的一部分。
- 已知的到期日以 `valid_to` 日期編碼（例如債券 ETF 停徵措施為 2026-12-31，0.15% 當沖稅率為 2027-12-31），並每年依法規資料庫重新驗證。

### 日曆 Port

- `CalendarPort`（`session_at`、`trading_date`、`sessions`、`next_open_ns`、`is_trading_day`）是交易日與交易時段階段的**唯一**來源。
- 實作：`exchange_calendars`（XTAI、美國）、`pandas_market_calendars`（CME、SIFMA），以及我們自己的 TAIFEX 日盤/夜盤、台灣零股與加密貨幣（24/7，00:00 UTC 日切）日曆，再加上用於颱風停市的版本化覆寫檔案。
- **於年底前載入 2027 年 TWSE/TAIFEX 休市日**。
- 在實作之前，**先依 TAIFEX 的規則確認 TAIFEX 夜盤的交易日歸屬規則**。
- 排程器與所有工作（job）都使用此 Port；不寫死任何時鐘時間。

### 後果

**正面**

- 供應商重述資料與代號重複使用，都無法破壞我們的歷史資料或部位。
- 稅率變更或休市日是經過審查的資料變更，而非程式發布，且在回測、風控與即時交易中的套用方式完全相同。
- 包含捨入與最低手續費在內的精確成本建模，補上了三份提案都遺漏的缺口。
- 交易前檢查與回測的 `BorrowModel`（[ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md)）讀取相同的放空與融資規則，因此回測不可能從即時交易會拒絕的放空中獲利，而 G1 成本壓力測試也納入了借券與融資成本（[ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.zh-TW.md)）。
- 現在就記錄 `known_at`，意味著情境 2 的雙時態查詢無需進行資料遷移。

**負面**

- 代號對應（symbology mapping）、每日旗標更新與自訂日曆都由我們自行負責，這是持續性的工作。
- 規則包需要每年進行法規重新驗證，且每條規則都需要一項測試。錯誤的規則會默默產生錯誤的損益。
- 缺少完整雙時態查詢的依生效日期資料列，目前還無法回答所有「以當時所知為準」的問題。
- 日曆覆寫檔案仰賴人工對臨時停市做出反應。
- 歷史借券可用量與費率資料稀少；在每日擷取累積出歷史資料之前，回測會採用保守的預設值，並在執行清單中加以標示。

### 確認

- 每條規則的單元測試：升降單位、漲跌幅限制、稅、捨入與最低手續費，並於 Phase 0 以真實的券商對帳單核對。放空測試：在無法放空、處於 SSR 限制下、在台灣低於前一日收盤價，或位於融券暫停期間內時，放空委託會被拒絕；借券費用與融資利息與券商對帳單相符。
- 日曆測試：日光節約時間切換、TAIFEX 夜盤交易日、颱風覆寫、2027 年休市日，以及加密貨幣每日日切。
- CI 檢查每條規則都具有 `legal_ref` 與 `verified_at`，並對 `valid_to` 落在 60 天內的規則發出排程警示。
- Golden-master 回測會鎖定規則包雜湊值。

### 何時重新檢視

- 情境 2：專用的雙時態參考資料服務，具備「以當時所知為準」查詢、授權的 CUSIP 與公司行動資料源、OCC 調整後交割標的通知，以及 gRPC 或 Connect API。
- **T8：** ETF 以外的債券與手動入帳 → 擴充 `BondTerms` 工作流程。
- 法律變更了某條具有日期效力的規則（延長或到期）→ 提交規則包 PR。

## 連結

- [主報告：參考資料列、設計原則 5 與 9，以及台灣表格](../../README.zh-TW.md)
- [建議架構 §3.2、§4.2、§5.3 與 §5.6](../../architecture/recommended-architecture.zh-TW.md)
- [評估紀錄：嫁接項 29、31、37 與 40；§6 關於稅務日期的矛盾；§7 待驗證項目 8、11 與 13](../../architecture/evaluation.zh-TW.md)
- 研究：[03 市場資料儲存](../../research/03-market-data-storage.zh-TW.md) · [05 商品與定價](../../research/05-instrument-model-pricing-analytics.zh-TW.md) · [02 回測](../../research/02-backtesting-engine.zh-TW.md) · [07 日曆](../../research/07-system-architecture-messaging.zh-TW.md) · [11 台灣在地化](../../research/11-taiwan-market-localization.zh-TW.md)
- 相關 ADR：[ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.zh-TW.md) · [ADR-0004](ADR-0004-parquet-lake-for-historical-data.zh-TW.md) · [ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.zh-TW.md) · [ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.zh-TW.md)
