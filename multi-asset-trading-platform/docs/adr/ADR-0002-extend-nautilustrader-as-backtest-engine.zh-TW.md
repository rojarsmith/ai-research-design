[English](ADR-0002-extend-nautilustrader-as-backtest-engine.md) | **繁體中文**

# ADR-0002：回測引擎：擴充 NautilusTrader v2，而非自建或 fork

## 狀態

**提議中（Proposed）** · 2026-10-05 · 範圍：情境 1 與 2。Phase 0 的技術探勘（spike）將會更新本 ADR（見 *確認*）。

## 背景與問題陳述

本平台需要一個事件驅動（event-driven）的回測引擎，與模擬交易（paper trading）及實盤交易共用策略程式碼、委託語意與風控檢查。它必須涵蓋美國／全球市場、加密貨幣交易所與台灣（TWSE/TPEx、TAIFEX）的股票、加密貨幣、選擇權與債券。我們應該自建這個引擎、採用一個開源引擎，還是 fork 一個？

研究的發現（[02](../../research/02-backtesting-engine.zh-TW.md)、[10](../../research/10-open-source-platforms-build-vs-buy.zh-TW.md)）：

- **沒有任何引擎涵蓋完整範圍。** NautilusTrader 與 LEAN 都沒有可交易的債券型別，也都沒有台灣市場規則。兩者皆未提供台灣券商 adapter。唯一具備台灣連接器的引擎 StockSharp，已於 2026-07-16 轉為專有授權（proprietary）。
- **NautilusTrader**（Rust 核心、Python API，v2 採 LGPL-3.0-only 授權）可在回測、sandbox 與實盤中執行相同的策略程式碼。它具備 L1/L2/L3 撮合、依據 `FundingRateUpdate` 資料進行的資金費用結算、17 個整合（IBKR 及主要加密貨幣交易所）、內建對帳（reconciliation）以及確定性（deterministic）核心。它正處於轉換期：1.231.0（2026-08-02）預定為最後一個 1.x 版本，v1 的安全性修補回移（backport）約於 2026 年 11 月結束。PyPI 上最新的 v2 版本為 2.0.0rc5（2026-09-15）；rc6 的版本說明日期為 2026-10-04。這些 RC 會破壞既有設定：rc4 將 `LiveExecClientConfig` 更名為 `ExecutionClientConfig`，而 rc6 強制要求明確指定手續費模型，並移除了 BitMEX。上游建議不要以真實資金使用 RC。其回測中沒有公司行動（corporate actions）、沒有提前指派（early assignment）模型，也沒有台灣撮合規則。截至 2026-10-05，首席維護者約有 19,182 次 commit，而次多的貢獻者僅有 339 次；此外，官方已宣布推出商業版「Nautilus Pro」方案。
- **LEAN**（C#，Apache-2.0）是最穩定的引擎，並擁有最佳的美股與選擇權模型（map 與 factor 檔案、無存活者偏差的美國資料）。然而，其 Python 版本固定於 3.11，其成交模型假設完全成交，其指派模型是一種啟發式方法，且不支援台灣市場或債券。
- **自建引擎**（提案 B（Proposal B）的 Rust 核心與 `SimVenue`）會重複 NautilusTrader 已提供的功能。B 本身估計，採用 NautilusTrader 可節省 30–40 PM（人月）。
- **停滯或授權限制過多的引擎**（backtrader、QSTrader、zipline-reloaded；GPL 授權的 Freqtrade；AGPL 授權的 Backtesting.py）不適合作為基礎。

## 決策驅動因素

- 回測與實盤一致性（backtest–live parity）：在每種模式下使用相同的程式碼與委託語意。
- 1–3 人團隊上線第一個實盤市場所需的時間（路線圖中基準約 12 PM，含應變預備則為 14–16 PM）。
- 模擬的正確性：手續費、資金費用、公司行動、選擇權生命週期，以及台灣的競價與漲跌幅限制規則。
- 控制引擎風險：RC 頻繁變動、關鍵人物風險、open-core 風險與授權。
- 日後能夠更換引擎而無須重寫策略。

## 考慮的選項

1. **擴充 NautilusTrader v2：** 不加修改地執行它，將我們的 adapter 與模擬模組放在獨立的套件中，並將它置於 `StrategyRuntime` port 之後。
2. **擴充 LEAN**（自行託管，透過 LEAN CLI）。
3. **自建事件驅動引擎**（提案 B）。
4. **Fork NautilusTrader**，並修補核心以支援債券與台灣規則。
5. **使用向量化或僅限加密貨幣的框架**（vectorbt、Freqtrade、Jesse、hftbacktest）作為唯一引擎。
6. **購買 QuantConnect Cloud。**

## 決策結果

**選定選項：1，「擴充 NautilusTrader v2」。** 對小型團隊而言，這是達成回測與實盤一致性最快且可信的途徑。它的缺口範圍夠窄，可以由我們自己的模擬模組補足，而 `StrategyRuntime` port 則限定了日後脫離它的成本。

此處「擴充」的意義如下：

| 項目 | 決策 |
|---|---|
| 版本 | 精確固定 `nautilus_trader==2.0.0rc5`；在規劃好的升級時段內移至 rc6 或 GA。不要從 1.231.x 起步。真實資金的投入由 [ADR-0010](ADR-0010-real-money-gate-and-dependency-pinning.zh-TW.md) 把關 |
| 設定 | 所有 Nautilus 設定都在 `platform/runtime/` 的 factory 中建構，集中在一處吸收 RC 的更名 |
| 引擎接縫 | `StrategyRuntime` port：`deploy(bundle, account, mode)`、`start()`、`stop()`、`halt(reason)`、`flatten(scope)`、`status()`。在情境 1 中，NautilusTrader 是唯一的實作。LEAN 實作則會以 `QCAlgorithm` 膠合程式碼包裝相同的 `tp_signals` |
| 不 fork | 我們不維護修補過的引擎。我們不針對 Nautilus 內部結構建構 Rust crate（提案 C 的 `nautilus-ext` 已被否決）。在上游願意接受時，修正會回饋至上游 |
| 擬真度 | K 棒加上 L1，並採悲觀的 K 棒內事件排序；選擇權以買價／賣價成交，絕不以中價成交；情境 1 不採用 L2/L3 佇列模型 |
| 我們的模擬擴充（位於 `platform/runtime/nautilus/`） | **手續費：** 依規則包（rules pack）建構明確的手續費模型，包含稅、捨入與最低手續費（自 rc6 起為必要）。**資金費用：** 重播交易所公布的資金費率歷史；只要有歷史資料，就絕不以公式重新計算。**公司行動：** 股票分割、現金與股票股利（包括會產生零股的台灣股票股利）、減資、下市，以及 OCC 調整後交割標的（adjusted deliverables），於除權息日套用，而成交仍維持原始價格（Phase 0 spike）。**台灣規則：** 集合競價以競價價格成交、漲跌停鎖死時不成交、盤中瞬間價格穩定措施（volatility interruption），以及零股委託簿（Phase 0 spike）。**提前指派：** 針對賣出的美式買權進行股利驅動的指派，並對深度價內的賣出賣權採用保守的啟發式方法（Phase 3）。**借券與融資（`BorrowModel`）：** 當該證券在當時無法放空，或規則包的 `short_sale` 檢查未通過時（Rule 201 SSR、台灣平盤以下不得放空規則、融券停券與強制回補日、額度），拒絕放空成交；每日累計借券費以及保證金或融資利息；對放空部位所遇到的股利記錄代償股利（payment in lieu）；以可設定的強制買回（buy-in）機率模擬難借券（hard-to-borrow）的召回（若第一個市場會放空或使用保證金，則為 Phase 1；台灣為 Phase 3a；[ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md)） |
| 債券 | 不在事件驅動引擎中模擬。`Bond` 是我們自己的 `tp_domain` 型別，每日以 QuantLib 評價。債券 ETF 以股票方式模擬。不針對 OTC 指示性報價進行事件驅動回測 |
| 向量化層 | 由我們自建（`tp_signals` 批次函式加上簡易的向量化模擬器）；vectorbt 為選用，且僅限內部使用。詳見 [ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.zh-TW.md) |
| 備援 | LEAN 是文件化的備援方案。它會在 **Phase 3c**（兩人團隊約第 44–56 週，0.5 PM）以一個參考策略演練一次，演練報告將更新下方的移植成本估算 |

### 被迫遷移至 LEAN 的成本

`StrategyRuntime` port 限定了脫離 NautilusTrader 的成本，但並不會讓遷移變得便宜。先前的說法（「數週，而非重寫」）低估了這項成本。所有與引擎綁定的部分都位於 `platform/runtime/nautilus/` 與 `adapters/` 中，必須針對 LEAN 重寫，且大多以 C# 撰寫。

| 部分 | 重用或重寫 | 估算 |
|---|---|---|
| `tp_signals`、`tp_risk`、`tp_domain`、`tp_rules`、`tp_calendars`、`tp_refdata`、`tp_data`、`tp_pricing`、`tp_metrics`、`tp_tax` | **重用**（正因如此才保持與 Python 3.11 相容的語法） | 0 |
| 規則包 YAML、證券主檔、公司行動表、Parquet 資料湖與 manifest | **重用**；LEAN 需要由公司行動表產生的 map 與 factor 檔案 | 0.2 PM |
| 帳本、日誌（journal）寫入器、對帳、API、UI、TW gateway 契約與 Shioaji sidecar | **重用**；日誌寫入器需要一個 LEAN 事件轉譯器，以取代 Nautilus 的轉譯器 | 0.3 PM |
| 使用 TW gateway 契約進行通訊的 LEAN `IBrokerage`（C#），以及其資料佇列處理器（data queue handler） | **重寫** | 0.6–1.0 PM |
| 以 LEAN reality model 實作的模擬擴充：含捨入的手續費與稅模型、TW 競價與漲跌停鎖死成交模型、零股處理、`BorrowModel`、資金費用重播、提前指派 | **重寫**（LEAN 本身的指派模型為啟發式方法） | 0.7–1.2 PM |
| Runtime 膠合層：包裝 `tp_signals` 的 `QCAlgorithm` wrapper、`GuardedStrategy` 的對等實作、intent-WAL hook、runtime factory、控制 actor | **重寫** | 0.3–0.6 PM |
| 針對 LEAN 重新建立基準的 golden master 與契約測試 | **重寫** | 0.3 PM |
| **合計** | | **≈ 2.4–3.6 PM（對外稱 2–4 PM）**，另需在真實資金投入前經過一段模擬交易期 |

IBKR 與大型加密貨幣交易所已有 LEAN brokerage，因此只需要設定與對帳測試，而不需要新程式碼。遷移至自有 Rust 核心（B）的規模遠大於此，此處不予估算。

**終止準則（Kill criterion，來自提案 B）。** 若台灣模擬擴充的進度落後其階段出口（phase exit）超過三個月，則退回保守的 K 棒層級規則，並評估觸發條件 T7（一個仿照 B 的 `SimVenue` 風格、僅限台灣的模擬器）。

### 後果

**正面**

- 第一個實盤市場約需 12 PM（基準），而非耗時多年的引擎建置。團隊心力可投注於台灣 adapter、規則包與正確性嫁接（grafts）。
- 單一核心即可執行回測、sandbox 與實盤。上游的 IBKR 與加密貨幣 adapter 已附帶對帳功能。
- 引擎專屬程式碼侷限於 `platform/runtime/` 與 `adapters/`，因此遷移至 LEAN 是一次範圍有限、約 2–4 PM 的移植（見上表），而非重寫策略、規則或紀錄。

**負面**

- RC 頻繁變動：每次升級都可能破壞設定，且真實資金必須等到 GA 或通過浸泡測試關卡（soak gate）。
- 關鍵人物與 open-core 風險已被接受，並追蹤於相依性風險登錄表中（[ADR-0010](ADR-0010-real-money-gate-and-dependency-pinning.zh-TW.md)）。
- 若引擎日後被散布，則須履行 LGPL-3.0-only 的義務（[ADR-0009](ADR-0009-open-source-licensing-strategy.zh-TW.md)）。
- 公司行動與台灣撮合擴充仰賴尚未驗證的 v2 擴充點（Phase 0）。
- 債券仍留在引擎之外，因此債券策略僅能進行每日評價與持有收益（carry）分析。
- 模擬擴充、Shioaji adapter、`GuardedStrategy`、runtime factory 與 WAL hook 都是依 NautilusTrader 的 API 撰寫，因此一旦被迫更換引擎，它們就是我們程式碼中需要重寫的部分。

### 確認

Phase 0 spike 會將其結論以更新本 ADR 的方式記錄下來：

1. v2 樹外（out-of-tree）adapter API 的成熟度（供 Shioaji adapter 使用）。
2. 台灣集合競價、漲跌停鎖死時的拒絕成交、盤中瞬間價格穩定措施與零股委託簿，能否以 Nautilus 成交／撮合擴充來表達。若不能，則觸發 T7。
3. 在 `BacktestNode` 內進行公司行動現金與部位調整的 v2 機制。
4. 參考策略的回測可在 CI 中執行，並重現其 golden event hash。
5. NautilusTrader 的在途委託（in-flight order）對帳，對我們所使用的每個上游 adapter 都能正常運作，並依照[建議架構](../../architecture/recommended-architecture.zh-TW.md) §3.4 中的各交易場所復原表進行檢查（[ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.zh-TW.md)）。

Phase 3c 會記錄 LEAN 演練的結果，並更新移植成本表。

### 重新檢視時機

- **T6：** GA 延遲超過 Phase 2 出口、上游拒絕我們需要的變更、主要維護者離開，或授權或 open-core 模式改變。改為遷移至位於 `StrategyRuntime` 之後的 LEAN；若有兩名以上資深 Rust 工程師可用，則改為 B 的自有核心。
- **T7：** 台灣規則無法以擴充方式表達。
- **T10：** 桌面版或自行託管的產品必須隨附此引擎。改用不含 LGPL 的核心。
- **T5：** 需要 L2/L3 佇列建模。使用 Nautilus L3 或 hftbacktest。

## 各選項的優缺點

| 選項 | 優點 | 缺點 |
|---|---|---|
| 1. 擴充 NautilusTrader v2 | 設計上即具一致性；內含 adapter 與對帳；以 Python 撰寫策略；最活躍的專案 | RC 頻繁變動；關鍵人物風險；未內建公司行動、提前指派、台灣規則或債券 |
| 2. 擴充 LEAN | Apache-2.0；穩定；最佳的美股與選擇權 reality model | Python 3.11（2027-10 EOL）；C# 核心；預設完全成交；啟發式指派；不支援台灣，也不支援債券 |
| 3. 自建引擎 | 完全掌控；位元層級的設計自由 | 1–3 人無法實現；新的撮合器無法以 oracle 驗證 |
| 4. Fork NautilusTrader | 可進行深度修改 | 上游 9 個月內約有 4.5k 次 commit，因此 fork 數週內就會偏離；若散布則有 LGPL 公開義務 |
| 5. 向量化或僅限加密貨幣 | 起步快 | 無法跨資產類別達成回測與實盤一致性；GPL 或 Commons Clause 授權 |
| 6. QuantConnect Cloud | 數週即可起步 | 高度鎖定（資料授權、基礎架構）；不支援台灣；程式碼與資料存放在對方的基礎架構上 |

## 連結

- [主報告：回測列、風險與路線圖](../../README.zh-TW.md)
- [建議架構 §3.3、§5.4 與 §5.6](../../architecture/recommended-architecture.zh-TW.md)
- [評估紀錄：嫁接項目 1、13、14、29 與 30；§4.3 中被否決的項目](../../architecture/evaluation.zh-TW.md)
- 研究：[02 回測引擎](../../research/02-backtesting-engine.zh-TW.md) · [10 自建或採購](../../research/10-open-source-platforms-build-vs-buy.zh-TW.md) · [11 台灣市場在地化](../../research/11-taiwan-market-localization.zh-TW.md)
- 相關 ADR：[ADR-0001](ADR-0001-core-engine-and-strategy-language.zh-TW.md) · [ADR-0010](ADR-0010-real-money-gate-and-dependency-pinning.zh-TW.md) · [ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md) · [ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.zh-TW.md)
