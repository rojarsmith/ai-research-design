[English](02-backtesting-engine.md) | **繁體中文**

# 回測引擎設計與方法論

*多資產（股票、加密貨幣、債券、選擇權）分析、回測與交易平台之研究面向 02。事實查核截至 2026-10-05。*

## 摘要（TL;DR）

- **建置兩層架構，而非單一引擎。** 向量化（vectorized）層（以 Numba 或 Rust 撰寫的陣列運算核心）以低成本篩選大型參數網格。接著由事件驅動（event-driven）層以貼近真實的成交、手續費、資金費、公司行動（corporate actions）與選擇權生命週期，重新執行入圍的策略，**且使用與實盤相同的策略程式碼**。任何策略都不能僅憑向量化結果就晉升。
- **NautilusTrader 是最適合的事件驅動核心**，適用於同時必須進行實盤交易的多資產平台。它具備 LGPL-3.0 授權的 Rust 核心、含佇列位置的 L1/L2/L3 撮合，以及列出的 17 項整合（加密貨幣交易所、Interactive Brokers、Databento、Tardis 等）。它正處於主版本轉換期：1.231.0（2026-08-02）預計為最後一個 1.x 版本，而 2.0 已進入 rc6（發行說明日期為 2026-10-04；2026-10-05 時 PyPI 上最新的 wheel 仍為 rc5）。請鎖定（pin）確切版本。**LEAN**（Apache-2.0，幾乎每日建置）則是專注於美國股票與選擇權、或以 C# 開發之團隊的最強替代方案。
- **受調查的引擎中，沒有任何一個開箱即支援債券或台灣市場規則。** 請規劃自行開發的外掛：以 QuantLib 為基礎的債券商品（應計利息、票息、到期日），以及台灣規則包（±10% 漲跌幅限制、集合競價、零股、0.3%/0.15% 證券交易稅、期交所（TAIFEX）期貨交易稅）。NautilusTrader 與 LEAN 都未提供台灣券商轉接器（adapter），因此台灣實盤交易也需要自訂轉接器（例如透過永豐金證券的 Shioaji API）。
- **將統計驗證做成管線（pipeline）中的一個階段，而不是一份報告。** 記錄每一次試驗。策略晉升前，必須通過前進式（walk-forward）或 CPCV 樣本外測試、平減夏普比率（Deflated Sharpe Ratio）以及回測過度擬合機率（Probability of Backtest Overfitting, PBO）。
- **不要建立在停滯的引擎上。** backtrader（最後提交 2023-04）、QSTrader（最後提交 2024-06）與 zipline-reloaded（維護模式）適合用於學習，但不適合作為基礎。

## 關鍵問題

1. 我們需要哪些模擬方法？又如何讓它們保持一致？
2. 每種策略類型需要多細緻的執行細節（K 棒、L1、L2、L3）？
3. 股票、加密貨幣、債券與選擇權各自有哪些必須以不同方式模擬的部分，包括台灣與期交所（TAIFEX）？
4. 哪個開源引擎可以作為核心？又有哪些部分必須自行開發？
5. 當使用者（或 LLM）執行數百萬次試驗時，如何防止過度擬合？
6. 如何保證可重現性以及回測與實盤的一致性？

## 方案比較

### 1. 模擬範式

| 範式 | 機制 | 吞吐量 | 擬真度 | 最適用於 | 弱點 |
|---|---|---|---|---|---|
| **向量化** | 訊號與部位以陣列形式在所有 K 棒上計算。可選用的編譯迴圈負責處理與路徑相關的現金與停損 | 非常高：在 K 棒資料上每秒可跑數千組設定 | K 棒層級。以收盤價或下一根開盤價成交；停損僅為近似 | 標的池篩選、參數掃描、因子研究、CPCV 分折 | 很容易出現前視（look-ahead）錯誤（例如漏掉 `shift`）。對委託類型、部分成交、保證金與選擇權生命週期的支援薄弱 |
| **事件驅動** | 離散事件迴圈：資料 → 策略 → 委託 → 模擬交易場所 → 成交 → 投資組合 | 慢 1–3 個數量級 | Tick、報價或委託簿。可模擬委託類型、延遲、保證金、公司行動與到期 | 最終驗證、執行研究、模擬／實盤一致性 | 速度太慢，不適合大範圍掃描。正確性取決於交易場所模型的品質 |
| **混合**（建議） | 由向量化層負責搜尋。前 N 名候選再以事件驅動方式重新執行。兩層共用同一套特徵／指標函式庫 | 整體而言高 | 最終數字一律來自事件驅動的執行結果 | 平台預設 | 需要自動化檢查，確認兩層結果一致 |

**一致性規則：** 若兩層對同一組設定的結果不一致（例如總報酬差異超過 10%，或正負號相反），即阻擋晉升。原因幾乎都是前視錯誤或成本模型有缺漏。

### 2. 開源引擎調查：維護狀態

| 引擎 | 授權 | 最新版本 | 活躍度 | 結論 |
|---|---|---|---|---|
| NautilusTrader | LGPL-3.0 | 2.0.0rc6（發行說明 2026-10-04；2026-10-05 時 PyPI 仍提供 rc5，2026-09-15）。1.231.0（2026-08-02）預計為最後一個 1.x，且仍是預設（非預發行）的安裝版本 | 非常活躍。已移除 Cython；Rust 核心 + PyO3 | **活躍，處於主版本轉換期** |
| LEAN (QuantConnect) | Apache-2.0 | Build 18155（2026-10-02）。大約每天建置一次 | 非常活躍 | **活躍** |
| vectorbt（開源版） | Apache-2.0 + Commons Clause | 1.1.1（2026-09-26）。1.0.0 發布於 2026-04-22 | 重新活躍；可選用 Rust 引擎 | **活躍** |
| vectorbt PRO | 專有授權，原始碼僅與會員分享 | 日曆式版號（公開網站引用 2026.6.27；更新的建置僅限會員） | 活躍；Rust 後端 | **活躍，商業版**：每月 $25、每年 $240 或終身 $500 起 |
| hftbacktest | MIT | py 2.4.4 / rust 0.9.4（2025-12-10）。最後提交 2025-12-23 | 約 9 個月無新動態 | **放緩**；僅一位維護者 |
| Freqtrade | GPL-3.0 | 2026.9（2026-09-29），每月發布 | 非常活躍 | **活躍（僅限加密貨幣）** |
| Jesse | MIT | 3.2.4（2026-10-01） | 非常活躍 | **活躍（僅限加密貨幣）** |
| bt | MIT | 1.3.0（2026-10-03） | 活躍 | **活躍（投資組合再平衡的利基市場）** |
| Backtesting.py | AGPL-3.0 | 0.6.6（2026-07-22） | 規模小但活躍 | **活躍**；AGPL 對 SaaS 而言是個問題 |
| zipline-reloaded | Apache-2.0 | 3.1.1（2025-07-19）。最後一次提交為 CI 版本更新（2025-11-13） | 維護模式 | **舊版／教學用** |
| QSTrader | MIT | 0.3.0。最後提交 2024-06-24 | 停滯 | 新專案**應避免** |
| backtrader | GPL-3.0 | 1.9.78.123（2023-04-19），同時也是最後一次提交 | 停滯 | 新專案**應避免** |

*同樣活躍但未深入調查：* **VeighNa (vn.py)**（MIT，4.4.0 發布於 2026-05-14，2026-10 仍有提交），為事件驅動的 Python 平台，具備 CTA 與投資組合回測器及多種閘道（gateway），在中國期貨方面最強；**Lumibot**（依其 LICENSE 檔案為 GPL-3.0，但 README 寫的是 MIT；4.6.4 發布於 2026-10-03），以同一套程式碼進行股票、選擇權與加密貨幣的回測與實盤交易；以及 **barter-rs**（MIT，Rust，專注於加密貨幣）。它們都不會改變本文的建議，但在自行開發之前值得一看。

### 3. 主要候選方案深入比較

| 面向 | NautilusTrader | LEAN | vectorbt / PRO | hftbacktest | 自建核心 |
|---|---|---|---|---|---|
| 範式／核心 | 事件驅動。Rust 核心搭配 Python API | 事件驅動。C# 核心；演算法以 C# 或 Python 撰寫 | 向量化。Numba 運算核心，可選用 Rust | 事件驅動，逐筆（tick by tick）。Rust，以及搭配 Numba 的 Python | 依自行設計而定 |
| 資料／撮合 | L3 MBO、L2 MBP、L1、報價、成交與 K 棒。K 棒採用 OHLC 順序模擬 | Tick、秒、分鐘、小時與日資料。市價單立即以最新價格成交（最後一筆 tick、報價 K 棒的買價／賣價，或成交 K 棒的收盤價）；限價單與停損單則於後續 K 棒成交。**預設假設完全成交**；不含委託簿深度或佇列 | 僅 K 棒 | L2 與 L3 委託簿重建 | 必須自行建置 |
| 成交擬真度 | 成交模型（`prob_fill_on_limit`、`prob_slippage`）、佇列位置、延遲模型、自訂手續費模型（v2） | 可依個別證券抽換的模型：成交、滑價、手續費、券商、購買力、交割、可放空數量 | 固定或百分比的手續費與滑價。PRO 增加限價／停損單與槓桿 | 佇列位置模型、行情與委託延遲、部分成交的交易所模型 | 必須自行建置 |
| 股票 | `Equity` 商品。公司行動並非內建的回測功能（需自備還原資料或自訂事件） | **最強。** Map 與 factor 檔案處理分割、股利與代號變更。QuantConnect 上的資料無存活者偏差 | 需自備還原後的陣列 | 不適用 | 必須自行建置 |
| 加密貨幣 | 現貨、永續合約、期貨與選擇權。提供 Binance、Bybit、OKX、Deribit、Hyperliquid 等交易所轉接器。回測依 `FundingRateUpdate` 資料結算永續合約資金費（`FundingSettlement` 事件），因此必須載入各交易所的資金費率歷史 | 加密貨幣與加密貨幣期貨資產類別 | 資金費以現金流陣列輸入（PRO） | 加密貨幣造市的**最佳選擇** | 必須自行建置 |
| 選擇權 | `OptionContract`、`OptionSpread`。v2 RC 版本已處理到期與實物交割。無提前指派模型 | **最強。** 股票、指數與期貨選擇權；履約與指派模型；多腳（multi-leg）策略 | 無生命週期 | 無 | 必須自行建置 |
| 債券 | **無債券商品類型** | **無固定收益資產類別** | 僅能作為價格序列 | 無 | 必要（QuantLib） |
| 實盤一致性 | 回測與實盤使用相同的策略程式碼；列出的 17 項整合（IB、Databento、Tardis …）。BitMEX 在 1.x 清單中，但不在 v2 清單中。無台灣券商轉接器 | 回測、模擬與實盤使用相同的演算法；支援眾多券商 | 無（僅供研究） | 與 Rust 實盤機器人（Binance Futures、Bybit）使用相同程式碼 | 必須自行建置 |
| 擴展性 | 每個行程（process）一個引擎；確定性撮合；可將多次執行分散到多個行程或 Ray | LEAN CLI 最佳化器，或 QuantConnect 雲端 | 參數廣播。PRO 增加分塊（chunking）及平行／分散式引擎 | 每次執行一個行程 | 可自由選擇 |
| 授權風險 | LGPL：若對外散布，對函式庫本身的修改必須公開 | 低 | Commons Clause 禁止販售。PRO 條款禁止開發競爭產品 | 低 | 無 |

### 4. 執行模型擬真度階梯

| 等級 | 資料 | 成交邏輯 | 足以應付 | 支援引擎 |
|---|---|---|---|---|
| 0. K 棒收盤／下一根開盤 | OHLCV | 以下一根開盤價 ± 固定基點成交；數量上限為成交量的一定比例 | 日或週再平衡、低週轉率 | 所有引擎 |
| 1. K 棒內（intra-bar） | OHLCV 或更細的 K 棒 | 假設 OHLC 路徑；悲觀排序（先觸及停損、再觸及目標）；限價單僅在價格穿越限價時才成交 | 波段交易、停損／限價策略 | Nautilus、LEAN、vectorbt PRO、Freqtrade |
| 2. L1 | 最佳一檔報價加上成交 | 跨越價差；數量上限為揭示數量；成交量參與率上限 | 當日交易。**所有選擇權交易**，因為買賣價差是主要成本 | Nautilus、LEAN |
| 3. L2（market-by-price） | 每個價位的深度 | 逐檔吃單（walk the book）；部分成交；暫時性價格衝擊 | 大額委託、加密貨幣 | Nautilus、hftbacktest |
| 4. L3（market-by-order）+ 延遲 | 每一筆委託事件 | 佇列位置、刪改單競態、行情與委託延遲 | 造市、高頻交易 | hftbacktest、Nautilus |

**手續費與稅應作為有版本控管、依生效日期套用的資料**（規則包），而非寫死的常數：

| 市場 | 需模擬的項目 |
|---|---|
| 美國股票 | 佣金。賣出時的 SEC Section 31 規費（費率每個會計年度重設一次；FY2026 公告於 2026-02-27 發布）。FINRA TAF。放空部位的借券費。T+1 交割 |
| 台股 | 券商手續費（法定上限 0.1425%，通常有折扣）。**賣出時課徵 0.3%** 證券交易稅。**當日沖銷（當沖）為 0.15%，延長至 2027-12-31**（證券交易稅條例第 2-2 條）。ETF 為 0.1%；債券 ETF 免稅至 2026-12-31。T+2 交割 |
| 期交所（TAIFEX） | 每口的券商手續費。期貨交易稅：股價指數期貨為**契約價值的 0.002%**，選擇權為**權利金的 0.1%**。持有至結算的選擇權，以契約價值按期貨稅率課稅 |
| 加密貨幣 | Maker/taker 手續費級距與返佣、資金費支付、提領費與 gas 費 |
| 債券 | 自營商的買賣價加碼（markup，通常是最大的成本）。買方須支付應計利息。台灣公債免徵證券交易稅。公司債及金融債券的證券交易稅（一般為 0.1%）僅停徵至 **2026-12-31**（第 2-1 條），因此應將其存為依生效日期套用的規則，並於 2027 年初重新確認 |

### 5. 四大資產類別的差異

| | 股票 | 加密貨幣 | 選擇權 | 債券 |
|---|---|---|---|---|
| **時間與日曆** | 交易所日曆、假日、半日交易。證交所（TWSE）：開盤集合競價 08:30–09:00，連續交易至 13:25，收盤集合競價 13:25–13:30；盤中零股自 09:10 起每 5 秒進行一次集合競價 | 以 UTC 計、全年無休（24/7）。必須自行定義日 K 棒的邊界。交易所停機與維護 | 到期日曆，包括週選擇權。期交所臺指選擇權（TXO）：歐式、現金結算，週選擇權於週三或週五到期，除一般交易時段外另有盤後交易時段（15:00–05:00） | 計息天數慣例（ACT/ACT、30/360）、營業日規則、交割延遲 |
| **價格** | 儲存**原始價格加上還原因子**。以還原價格計算訊號、以原始價格成交，並在分割日調整部位 | 各交易所價格不同。區分標記價格、指數價格與最新成交價；線性（正向）與反向合約 | 完整的選擇權鏈快照與隱含波動率曲面。**以買價／賣價成交，而非中價。** 留意過時的報價 | 淨價與全價、以殖利率報價。許多報價為評價價格或參考報價，並非可成交的價格 |
| **現金流／持有成本** | 股利（扣除預扣稅後）、合併、分拆（spin-off）、代號變更、借券費 | **資金費。** Binance 預設每 8 小時一次（UTC 00/08/16），但部分合約使用其他間隔，且合約觸及上限或下限時會改為每小時一次。Hyperliquid 每小時支付，上限為每小時 4%。應將資金費模擬為各交易所帶時間戳記的事件 | 履約與指派。美式選擇權的提前履約，尤其是在除息日之前。釘選風險（pin risk）。實物交割與現金結算 | 票息、應計利息、攤銷、買回／賣回條款、到期贖回、違約 |
| **執行特性** | 台灣的**每日 ±10% 漲跌幅限制**（上市後前五個交易日不設限）：個股鎖跌停或鎖漲停時應拒絕成交。盤中瞬間價格穩定措施：若成交價將偏離 5 分鐘參考價超過 3.5%，撮合暫停 2 分鐘，之後以集合競價恢復。升降單位（tick size）級距；1,000 股為一個交易單位（一張） | 交易所的 tick／lot 篩選規則、強制平倉引擎、自動減倉（ADL）、速率限制 | 以淨支出或淨收入（net debit/credit）價格下達的多腳（組合）委託；分腳成交風險；價差寬 | 店頭市場（OTC）詢價（RFQ）交易、最低交易量、成交機率低 |
| **保證金** | 現金或 Reg-T；放空規則 | 全倉與逐倉保證金、階梯式維持保證金。**引擎必須模擬強制平倉** | 策略式或投資組合保證金；交易所保證金規則；組合部位可降低保證金 | 附買回（repo）融資與折扣率（haircut） |
| **資料陷阱** | 存活者偏差（已下市櫃的股票）、重編的基本面資料、指數成分股的歷史變動 | 已下架的交易對、灌水（洗量）的成交量、各交易所之間不一致的歷史資料 | 資料量龐大；公司行動後契約條款會變動 | 成交稀疏與經平滑化的評價價格，使波動率看起來偏低、夏普比率看起來偏高 |

**四大類別共通的偏差控制：** 時點（point-in-time）的雙時態（bitemporal）儲存，每筆紀錄同時具備事件時間與「已知」時間；包含已下市證券的標的池；特徵僅讀取時間戳記嚴格早於決策時點的資料（基本面以*公布*時間為準，而非期末）；以及記錄每一次試驗（包括失敗者）的日誌。

### 6. 驗證方法

| 方法 | 回答的問題 | 運算成本 | 陷阱 | 工具 |
|---|---|---|---|---|
| 前進式（滾動或錨定） | 定期重新最佳化在樣本外是否依然有效？ | 低–中 | 只產生一條路徑；結果取決於視窗的選擇 | 所有引擎；vectorbt splitters |
| Purged K-fold／CPCV | 在以清除（purging）與禁入期（embargo）防止資訊洩漏的前提下，樣本外績效的*分布*為何？ | 高。N 組中取 k 組作為測試組，產生 C(N,k) 種切分與 (k/N)·C(N,k) 條路徑 | 需要標籤期間來設定清除與禁入期；對有狀態的策略不易處理 | skfolio `CombinatorialPurgedCV`（BSD-3，1.4.11） |
| 蒙地卡羅 | 回撤與破產的分布為何？結果對成本與成交雜訊有多敏感？ | 中 | 單純的 i.i.d. 自助法（bootstrap）會破壞自我相關；應使用區塊自助法（block bootstrap） | 自訂；Jesse 內建蒙地卡羅 |
| 平減夏普比率（DSR） | 在考量試驗次數、偏態、峰態與樣本長度後，最佳的夏普比率是否仍然顯著？ | 極低 | 需要誠實的試驗次數 | Bailey & López de Prado（2014）的公式 |
| 以 CSCV 計算的 PBO | 樣本內的贏家在樣本外排名低於中位數的可能性有多高？ | 中。需要包含每一次試驗報酬的矩陣 | 必須儲存所有試驗的報酬 | R `pbo` 套件或自訂程式碼 |

**晉升關卡範例（全部必須成立）：** DSR ≥ 0.95；PBO < 0.2；超過 70% 的 CPCV 路徑為正；手續費與滑價加倍後仍能獲利；樣本外夏普比率至少為樣本內的 50%。

2026 年的證據支持以機制化方式強制執行上述規則。一項研究加入了防範前視偏誤的工具登錄機制並記錄每一次評估，結果否決了所測試的*每一個*由 LLM 發掘的策略，而被動基準則通過檢驗。一位人類交易員的實際上線規則系統，以相同方式評估後，在樣本外同樣站不住腳（arXiv 2608.27734）。**若平台未來會以 AI 產生策略，試驗登錄表即為必要項目。**

### 7. 橫向擴展與可重現性

| 選項 | 適用 | 備註 |
|---|---|---|
| multiprocessing／joblib | 單一機器 | 無需基礎設施；MVP 階段已足夠 |
| Ray（2.59.0，2026-10-02，Apache-2.0） | 全叢集的參數掃描與 CPCV；Ray Tune 搭配 Optuna | Actor 會將已載入的資料保留在記憶體中；可在 Kubernetes 上自動擴展 |
| Dask | 以 DataFrame 為基礎的特徵計算 | 較不適合大量獨立且有狀態的模擬 |
| vectorbt PRO 引擎 | 內建分塊與平行／分散式執行 | 會被綁定在 vectorbt API 上 |
| GPU（CuPy、cuDF、JAX） | 大型向量化指標網格、蒙地卡羅 | 依賴價格路徑的事件邏輯難以對應到 GPU。加速效果僅適用於向量化層 |

**確定性檢查清單：** 每次執行都寫出一份清單（manifest）（引擎版本與 lockfile、git SHA、容器摘要值（digest）、資料快照雜湊值、設定與參數、亂數種子、規則包版本）。使用定點數或十進位價格（Nautilus 使用定點數型別）、同一時間戳記的事件採固定順序、不讀取系統時鐘（wall-clock）、合併平行結果時採用順序穩定的歸約（reduction），並在 CI 中執行「golden-master」回歸回測。

### 8. 回測與實盤一致性機制

1. **單一的策略 API 與領域模型**（商品、委託、事件），供回測、模擬與實盤共用。NautilusTrader、LEAN、hftbacktest、Freqtrade 與 Jesse 都遵循此模式。
2. **由引擎掌管時鐘與計時器。** 策略絕不直接呼叫 `now()`。
3. **交易場所模擬器與實盤轉接器共用設定**：tick 與 lot 篩選規則、委託類型、手續費級距與速率限制。
4. **錄製與重播。** 擷取實盤的市場資料與委託事件，再透過回測引擎重播並比較成交結果。
5. **影子交易與模擬交易期間，搭配交易成本分析（TCA）。** 比較實盤成交與模擬成交（執行落差，implementation shortfall），並將量測到的滑價回饋至成交模型。
6. 與券商進行部位與現金的**每日對帳**。當策略的實盤損益落在回測蒙地卡羅 95% 區間之外時，**偏移警報**會暫停該策略。

## 建議

### (a) 個人／1–3 人 MVP

1. **事件驅動核心：NautilusTrader 2.x。** 鎖定確切的 RC 或 GA 版本，且不要在 1.x 上展開新工作。若主要聚焦於美國股票與選擇權，並希望開箱即有資料與貼近真實的模擬模型，則改用**透過 LEAN CLI 執行的 LEAN**。
2. **篩選層：vectorbt 1.x（免費）。** 若需要限價單、分塊與 Rust 後端，可升級至 PRO（每年 $240 起）。在以服務形式提供任何功能之前，請先審閱兩者的授權條款。
3. **擬真度：** K 棒加上 L1 報價、悲觀的 K 棒內排序，成本採用價差 + 固定基點 + 參與率上限。略過 L2/L3。
4. **資產推出順序：** 先以日 K 或分 K 進行加密貨幣永續合約（含資金費事件）以及美股與台股；接著是選擇權，搭配 L1 選擇權鏈、到期與指派；債券初期僅透過 ETF 或期貨代理標的處理。
5. **從第一天起就進行驗證：** 前進式測試、DSR 與 PBO，並以 Parquet 或 SQLite 儲存試驗登錄表。
6. **運算：** 一台工作站，使用 multiprocessing 或本機 Ray。

### (b) 5–20 人團隊或機構等級

1. **以 NautilusTrader 2.x GA 作為共用的執行與領域核心**（專注於美國選擇權的 C# 團隊則改用 LEAN）。圍繞它建置自有的擴充層：以 QuantLib（1.43，BSD-3）為基礎的債券商品與現金流引擎、台灣／期交所市場規則包、各交易所的資金費事件，以及依生效日期套用的手續費與稅率表。
2. **微結構交易團隊（desk）：** 使用 Nautilus 或 hftbacktest 的 L3 撮合。以自身的實盤成交資料校準佇列與延遲模型。由於 hftbacktest 只有一位維護者，應將其 fork 並納入專案原始碼（vendor）。
3. **共用研究網格：** Kubernetes 上的 Ray 叢集、為每位使用者與每個團隊建立並供 DSR 計算使用的試驗登錄表，以及儲存每次試驗的報酬以便計算 PBO。
4. **強制執行的晉升關卡**（CPCV、PBO、DSR、成本壓力測試），搭配模型風險簽核與稽核軌跡。
5. **一致性基礎設施：** 錄製與重播、影子交易、TCA 回饋迴圈與 golden-master CI。

## 對整體架構的影響

- **引擎決定了領域模型。** 其商品、委託與事件會成為模擬、實盤、風控與 UI 的標準資料結構（schema），因此應在設計 OMS 與風控服務之前選定引擎。
- **資料層必須提供：** 雙時態的時點儲存；原始價格加上還原因子；包含已下市證券與公司行動的證券主檔；各交易所的資金費率歷史；選擇權鏈快照；債券參考資料。以兩層皆可讀取的 Parquet/Arrow 格式儲存（DuckDB/Polars；Nautilus 資料目錄）。
- **市場規則服務**以有版本控管、依生效日期套用的設定，將日曆、tick／lot 大小、漲跌幅限制與手續費／稅率表，一致地提供給回測、風控檢查與實盤的交易前檢查。
- **運算平面：** 工作佇列、Ray 叢集、結果／實驗儲存庫與試驗登錄表。回測一律在伺服器端執行；桌面、網頁與行動用戶端只負責提交工作與顯示結果。
- **語言分工：** 研究使用 Python；核心使用 Rust（Nautilus）或 C#（LEAN）。自訂的成交、手續費與商品模型以外掛形式實作，並各自擁有測試套件。

## 風險與陷阱

- **NautilusTrader v2 的頻繁變動。** RC 版本仍包含設定與列舉（enum）的破壞性變更（例如 rc6 規定回測交易場所必須明確指定 `fee_model`）。部分較少使用的功能延後至切換之後才提供。1.x 版（現位於 `develop_v1` 分支）在 v2 切換後約三個月內僅接收關鍵安全性修補的向後移植，而 v2 切換發生在 2026-08-02 的 1.231.0 之後。預計該期間將於 2026 年 11 月左右結束。
- **授權陷阱：** Backtesting.py 為 AGPL（以 SaaS 形式使用即觸發）；Freqtrade 與 backtrader 為 GPL；vectorbt 的 Commons Clause 禁止販售；vectorbt PRO 的條款禁止開發競爭產品；NautilusTrader 為 LGPL，因此應將對函式庫的修改分開維護，或將其公開。
- **過於樂觀的預設值：** 只要請求價格落在 K 棒的價格範圍內，Freqtrade 就以該價格成交，且不計滑價。LEAN 內建的成交模型假設完全成交，其預設的指派模型為啟發式（每小時掃描；距到期 4 天內且價內至少 5% 的美式選擇權），而實際的提前履約主要受股利驅動。
- **加密貨幣交易所的規則差異與變動。** 資金費間隔會動態變動，強制平倉與 ADL 規則也因交易所而異。以某一交易所的規則來回測另一交易所，結果是錯誤的。
- **台灣特有事項：** 忽略跌停鎖死的個股，會嚴重低估出場難度；0.15% 的當沖稅率將於 2027-12-31 到期，除非再次延長；涵蓋台灣已下市股票、無存活者偏差的資料，通常需要向付費供應商取得。
- **債券的假象。** 評價價格經過平滑化，會灌高夏普比率。應使用買賣價差、報價過時旗標與成交機率。
- **平台規模下的多重檢定問題。** 使用者眾多時，試驗次數會急速增加。應同時針對每位使用者與整個平台對結果進行平減（deflate）。
- **僅由單一維護者維護的相依套件**（hftbacktest、vectorbt）會帶來延續性風險。可透過將其納入專案原始碼（vendor）並以自有介面包裝來降低風險。

## 參考資料

- NautilusTrader 發行說明: https://raw.githubusercontent.com/nautechsystems/nautilus_trader/master/RELEASES.md
- NautilusTrader 1.231.0（最後一個 1.x）: https://newreleases.io/project/github/nautechsystems/nautilus_trader/release/v1.231.0
- NautilusTrader 2.0.0rc4: https://newreleases.io/project/github/nautechsystems/nautilus_trader/release/v2.0.0rc4
- NautilusTrader 儲存庫（授權、整合）: https://github.com/nautechsystems/nautilus_trader
- NautilusTrader 回測概念: https://nautilustrader.io/docs/latest/concepts/backtesting
- NautilusTrader 商品: https://nautilustrader.io/docs/latest/concepts/instruments
- LEAN 儲存庫: https://github.com/QuantConnect/Lean
- LEAN 版本發布動態: https://releasealert.dev/github/QuantConnect/Lean
- LEAN 真實性模型（reality models）: https://www.quantconnect.com/docs/v2/writing-algorithms/reality-modeling/key-concepts
- LEAN 成交模型: https://www.quantconnect.com/docs/v2/writing-algorithms/reality-modeling/trade-fills/key-concepts
- LEAN 選擇權指派模型: https://www.quantconnect.com/docs/v2/writing-algorithms/reality-modeling/options-models/assignment
- LEAN 資產類別: https://www.quantconnect.com/docs/v2/writing-algorithms/securities/asset-classes
- PyPI 上的 vectorbt: https://pypi.org/project/vectorbt/
- vectorbt 儲存庫: https://github.com/polakowo/vectorbt
- vectorbt PRO（定價、條款）: https://vectorbt.pro/
- vectorbt PRO Rust 後端: https://vectorbt.pro/documentation/rust
- hftbacktest 儲存庫: https://github.com/nkaz001/hftbacktest
- hftbacktest 版本發布: https://github.com/nkaz001/hftbacktest/releases
- backtrader 提交紀錄: https://api.github.com/repos/mementum/backtrader/commits?per_page=1
- QSTrader 提交紀錄: https://api.github.com/repos/mhallsmoore/qstrader/commits?per_page=1
- PyPI 上的 zipline-reloaded: https://pypi.org/project/zipline-reloaded/
- zipline-reloaded 提交紀錄: https://api.github.com/repos/stefan-jansen/zipline-reloaded/commits?per_page=1
- PyPI 上的 Backtesting.py: https://pypi.org/project/backtesting/
- PyPI 上的 bt: https://pypi.org/project/bt/
- PyPI 上的 Jesse: https://pypi.org/project/jesse/
- PyPI 上的 Freqtrade: https://pypi.org/project/freqtrade/
- Freqtrade 回測假設: https://www.freqtrade.io/en/stable/backtesting/
- LEAN 股票成交模型: https://www.quantconnect.com/docs/v2/writing-algorithms/reality-modeling/trade-fills/supported-models/equity-model
- NautilusTrader 回測中的資金費: https://github.com/nautechsystems/nautilus_trader/blob/master/docs/concepts/backtesting/accounts-and-margin.md
- VeighNa (vn.py): https://github.com/vnpy/vnpy
- Lumibot: https://github.com/Lumiwealth/lumibot
- barter-rs: https://github.com/barter-rs/barter-rs
- PyPI 上的 Shioaji: https://pypi.org/project/shioaji/
- PyPI 上的 Ray: https://pypi.org/project/ray/
- skfolio CombinatorialPurgedCV: https://skfolio.org/generated/skfolio.model_selection.CombinatorialPurgedCV.html
- PyPI 上的 skfolio: https://pypi.org/project/skfolio/
- PyPI 上的 QuantLib: https://pypi.org/project/QuantLib/
- 平減夏普比率（SSRN）: https://papers.ssrn.com/abstract=2460551
- 回測過度擬合機率（SSRN）: https://papers.ssrn.com/abstract=2326253
- Purged 交叉驗證概述: https://en.wikipedia.org/wiki/Purged_cross-validation
- 對 LLM 發掘策略的誠實評估（2026）: https://arxiv.org/abs/2608.27734
- Binance 資金費率: https://www.binance.com/en/support/faq/introduction-to-binance-futures-funding-rates-360033525031
- Hyperliquid 資金費: https://hyperliquid.gitbook.io/hyperliquid-docs/trading/funding
- 證交所（TWSE）交易制度: https://www.twse.com.tw/en/products/system/trading.html
- 期交所 TXO 契約規格: https://www.taifex.com.tw/enl/eng2/tXO
- 台灣期貨交易稅（財政部稅務入口網 eTax）: https://www.etax.nat.gov.tw/etwmain/tax-info/understanding/tax-q-and-a/national/future-transaction-tax/filing-payment-and-collection-reward/jDxbO8a
- 台灣當沖稅延長至 2027 年: https://taipeitimes.com/News/biz/archives/2025/01/01/2003829438
- 證券交易稅條例（全國法規資料庫）: https://law.moj.gov.tw/LawClass/LawAll.aspx?pcode=G0340078
- 期貨交易稅條例: https://law.moj.gov.tw/LawClass/LawAll.aspx?pcode=G0340079
- SEC Section 31 規費費率公告: https://www.sec.gov/rules-regulations/fee-rate-advisories

## 查核紀錄（2026-10）

2026-10-05 進行了一次對抗式事實查核。查核來源包括 GitHub（API、標籤與分支）、PyPI JSON、官方文件、全國法規資料庫以及所引用的文章。共查核 30 項：22 項確認、5 項更正、3 項無法查證。

**已確認**

1. NautilusTrader 2.0.0rc6 發行說明日期為 2026-10-04。1.231.0（2026-08-02）「預計」為最後一個 1.x。`develop_v1` 上的關鍵安全性向後移植會在 v2 切換後持續約 3 個月。
2. NautilusTrader 為 LGPL-3.0（GitHub 授權 API；PyPI 列為 LGPL-3.0-or-later）。
3. NautilusTrader 的商品清單中沒有債券或固定收益類型。
4. NautilusTrader v2 細節：已移除 Cython（rc4 說明）、rc4 新增自訂 Python 手續費模型、v2 RC 版本已處理選擇權的實物履約與交割，且 RC 版本包含破壞性的設定變更。
5. LEAN 為 Apache-2.0。標籤 18155 位於 2026-10-02 的提交上，自 2026-08-13 以來已出現約 155 個建置標籤。
6. LEAN 預建的成交模型在回測中假設完全成交，且其資產類別清單中不含固定收益。
7. LEAN 的 `DefaultOptionAssignmentModel` 每小時掃描一次，考量距到期 4 天內且價內超過 5% 的美式選擇權（原始碼預設值為 `0.05m` 與 4 天）。
8. LEAN 的美股資料無存活者偏差，且包含已下市股票。分割、股利與代號變更資料來自 US Equity Security Master。
9. vectorbt 1.0.0 於 2026-04-22 發布，1.1.1 於 2026-09-26 發布。它具備可選用的 `vectorbt-rust` 引擎，授權為 Apache-2.0 加上 Commons Clause。
10. vectorbt PRO 的價格為每月 $25、每年 $240 或終身 $500 起。其條款禁止開發競爭產品。
11. hftbacktest py 2.4.4 與 rust-v0.9.4 於 2025-12-10 發布。其最後一次提交為 2025-12-23，採 MIT 授權。在約 1,000 次提交中，約 900 次出自同一位維護者。它支援 L2/L3 資料、佇列與延遲模型，以及 Binance Futures 與 Bybit 的實盤機器人。
12. backtrader 1.9.78.123（2023-04-19，GPL-3.0）同時也是其最後一次提交。QSTrader 0.3.0 的最後一次提交為 2024-06-24。zipline-reloaded 3.1.1 於 2025-07-19 發布，其最後一次提交為 2025-11-13 的 CI 版本更新。
13. Freqtrade 2026.9（2026-09-29，GPLv3）、Jesse 3.2.4（2026-10-01，MIT）、bt 1.3.0（2026-10-03，MIT）與 Backtesting.py 0.6.6（2026-07-22，AGPL-3.0）均為最新版本，且各儲存庫在 2026 年 8–10 月皆有提交。
14. 只要請求價格位於 K 棒的最高價／最低價範圍內，Freqtrade 就以該價格成交，且不計滑價。Jesse 內建蒙地卡羅分析。
15. 台灣 0.15% 的當沖證券交易稅實施至 2027-12-31（證券交易稅條例第 2-2 條）。一般稅率為股票 0.3%，ETF 與公司債 0.1%（第 2 條）。
16. 期交所的期貨交易稅：股價指數期貨為 0.002%，選擇權為權利金的 0.1%。於到期前或到期時以現金結算的選擇權，以結算價值按期貨稅率課稅（期貨交易稅條例第 2 條）。
17. TXO 為歐式、現金結算，盤後交易時段為 15:00 至 05:00，週選擇權於週三或週五到期。
18. Binance 資金費預設每 8 小時一次（UTC 00/08/16），觸及上限或下限時改為每小時一次。Hyperliquid 每小時支付資金費，上限為每小時 4%。
19. SEC 的 FY2026 Section 31 規費費率公告於 2026-02-27 發布。
20. 證交所（TWSE）：集合競價 08:30–09:00 與 13:25–13:30、±10% 每日漲跌幅限制、1,000 股為一個交易單位、T+2 交割。
21. 工具版本：skfolio 1.4.11（2026-10-03，BSD-3）、Ray 2.59.0（2026-10-02，Apache-2.0）、QuantLib 1.43（2026-07-14，BSD-3），以及 R `pbo` 套件（CRAN 1.3.5）。
22. arXiv 2608.27734（2026-08-27）確實存在。在防範洩漏且記錄所有試驗的評估下，它否決了每一個由 LLM 發掘的策略，並認可被動基準。

**已更正**

1. 「20+ / 21+ 項 NautilusTrader 整合」→ README 在 v1 與 v2 分支上皆列出 17 項，且 v2 移除了 BitMEX（來源：`develop`/`develop_v1` 上的 README.md）。
2. LEAN「於下一根 K 棒成交」→ 市價單立即以最新 tick、報價 K 棒的買價／賣價或成交 K 棒的收盤價成交，只有限價單與停損單才會等待後續 K 棒（來源：LEAN 股票成交模型文件）。
3. arXiv 2608.27734：「一位人類交易員的實際上線系統通過檢驗」→ 該系統在樣本外未能延續，且與持有黃金的配對檢定也否決了它（來源：arxiv.org/html/2608.27734，表 7）。
4. NautilusTrader 資金費：「確認你的版本是否會模擬資金費支付」→ 回測依 `FundingRateUpdate` 資料，以 `FundingSettlement` 事件結算永續合約資金費（來源：docs/concepts/backtesting/accounts-and-margin.md）。
5. NautilusTrader 版本：「1.231.0 是最後一個 1.x；rc6 於 2026-10-04 發布」→ 1.231.0 *預計*作為最後一個 1.x。2026-10-05 時 rc6 的發布建置仍在執行中，尚無 rc6 的 GitHub release 或 PyPI wheel。最新可安裝的預發行版本為 rc5（2026-09-15）（來源：PyPI JSON、GitHub releases/actions）。

**新增（遺漏或容易過時的細節）**

- 台灣對公司債、金融債券與債券 ETF 停徵證券交易稅的措施於 2026-12-31 結束（第 2-1 條），公債則為免稅（第 1 條）。
- 證交所盤中零股自 09:10 起每 5 秒集合競價一次。證交所設有 ±3.5% 的盤中瞬間價格穩定措施（暫停 2 分鐘，之後以集合競價恢復）。新上市股票前五天無漲跌幅限制（來源：證交所交易制度頁面）。
- NautilusTrader 與 LEAN 皆無台灣券商轉接器。Shioaji 1.7.7 於 2026-09-29 發布。
- 其他值得一看的引擎：VeighNa（vn.py，MIT，4.4.0）、Lumibot（依其 LICENSE 檔案為 GPL-3.0，4.6.4）與 barter-rs（MIT）。
- vectorbt PRO 的價格現改以「起」標示。

**無法查證**

1. vectorbt PRO 的「2026.9.x」日曆式版號。公開網站僅顯示 2026.6.27，且發行說明僅限會員閱覽，因此表格現改為引用公開版本。
2. 「LEAN 不模擬委託簿深度或佇列位置。」成交模型文件並未明確說明這一點，但這與 LEAN 的 tick／K 棒資料模型一致。
3. 「NautilusTrader 沒有提前指派模型。」文件或發行說明中並未出現提前指派功能，但也未找到明確的說明。
