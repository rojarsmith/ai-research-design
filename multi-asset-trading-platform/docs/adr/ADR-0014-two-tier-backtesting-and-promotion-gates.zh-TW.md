[English](ADR-0014-two-tier-backtesting-and-promotion-gates.md) | **繁體中文**

# ADR-0014：雙層回測，搭配單一指標函式庫、確定性契約與以證據為本的晉升關卡

## 狀態

**提議中（Proposed）** · 2026-10-05 · 範圍：情境 1，並於情境 2 中進行全平台的試驗次數計算。

## 背景與問題陳述

參數掃描（parameter sweep）需要低成本的向量化執行。擬真的成交、手續費、資金費用（funding）、公司行動與選擇權生命週期，則需要事件驅動（event-driven）的執行。若兩層使用不同的指標程式碼，它們就會因與前視偏誤（look-ahead）錯誤無關的原因而產生分歧，使分歧測試淪為雜訊。若不計算試驗次數，Deflated Sharpe Ratio（DSR）等過度擬合統計量就毫無意義。一項記錄了每一次評估的 2026 年研究，否決了其所測試的每一個由 LLM 發現的策略（[02](../../research/02-backtesting-engine.zh-TW.md)）。研究結果要如何安全且可重現地成為實盤策略？

考量因素（[02](../../research/02-backtesting-engine.zh-TW.md)、[09](../../research/09-research-ml-analytics.zh-TW.md)、[評估](../../architecture/evaluation.zh-TW.md)）：

- **可重現性。** CPython 的數學運算、NumPy 的 SIMD 分派（dispatch）與多執行緒歸約（reduction），在不同作業系統與 CPU 之間並非位元層級可重現。提案 B 所承諾的跨平台位元一致，依其原本的表述已被否決。
- **2026-10-05 時的工具狀況：**
  - vectorbt 1.x（Apache-2.0 附加 Commons Clause；單一維護者）；
  - skfolio 1.4.11 的 `CombinatorialPurgedCV`（BSD-3）；
  - MLflow 3.16；
  - R 語言的 `pbo` 套件；
  - 用於呈現的 QuantStats。
- **引擎。** 事件驅動引擎為 NautilusTrader `BacktestNode` 加上我們的模擬擴充（[ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md)）。

## 決策驅動因素

- 沒有任何策略能僅憑向量化的證據就投入真實資金。
- 兩層之間的分歧必須代表真正的錯誤（bug）。
- 每個結果都能由 manifest 重現。
- 誠實的試驗次數，包括 AI 產生的變體。
- 關卡的成本要夠低，讓一個人就能機械式地執行，並為單人作業提供四眼原則（four-eyes）的替代方案。

## 考慮的選項

1. **兩層共用單一指標函式庫（`tp_signals`，含批次與增量版本）、由 CI 強制執行的確定性契約、MLflow 試驗登錄表，以及關卡 G0–G4。**
2. **僅用事件驅動。** 簡單，但對於參數掃描與交叉驗證的各折（fold）而言太慢。
3. **以 vectorbt 篩選、以 NautilusTrader 驗證，並各自使用不同的指標程式碼**（提案 A 的原始設計）。
4. **臨時性的筆記本（notebook）加上人工審查。**

## 決策結果

**選定選項：1。** 讓各層共用 `tp_signals`，可將「10% 以內／正負號不翻轉」的一致性規則，變成真正能偵測前視偏誤與成本模型缺口的檢測器。manifest 與 golden master 讓每個結果都能重現，而登錄表則讓 DSR 與 PBO 誠實可信。

### 分層

| 層 | 實作 | 用途 |
|---|---|---|
| 向量化 | `tp_signals` 批次函式，加上一個以 Polars/NumPy 為基礎的簡易向量化投資組合模擬器。vectorbt 1.x 為選用，且**僅限內部使用**（[ADR-0009](ADR-0009-open-source-licensing-strategy.zh-TW.md)） | 篩選、參數掃描、CPCV 各折 |
| 事件驅動 | `tp backtest run --bundle <sha> --data-manifest <hash> --seed <n>` 透過 runtime factory 建構一個 `BacktestNode`：K 棒加上 L1、悲觀的 K 棒內事件排序、明確的手續費模型、資金費用重播，以及我們的模擬擴充 | **唯一**其結果可獲晉升的層 |
| 一致性 | 對於相同的設定，總報酬必須在 **10% 以內一致，且正負號不翻轉**，否則晉升會被阻擋 | 常見原因：前視偏誤錯誤或成本模型缺口 |

`tp_signals` 收錄純粹的指標與訊號函式，提供批次與增量兩種版本，並以彼此互相對照進行測試。

### 確定性契約（於 CI 中強制執行）

1. **無環境隱含輸入（ambient inputs）。** 決策程式碼中不得有掛鐘時間（wall clock）、I/O 或未設定種子的隨機性（以 lint 檢查）。回測 worker 中的 `PYTHONHASHSEED` 是固定的，且決策程式碼不對 set 進行迭代。
2. **穩定的排序。** 多來源資料依 `(ts_init, source priority, sequence)` 合併。
3. 凡決策涉及金額之處，一律使用**定點數**（[ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.zh-TW.md)）。
4. **每次執行都有一份 run manifest：** bundle（`git SHA + config hash + rules-pack hash + engine pin`）、lockfile 雜湊、映像檔 digest、資料 manifest 雜湊、種子、`trial_group_id` 與輸出事件雜湊。
5. **Golden master。** 在相同的平台與映像檔上，事件雜湊必須**完全**相符。跨作業系統與 CPU 架構時，結果必須維持在**文件化的容許誤差**之內。
6. **平行化僅限於不同執行之間**（multiprocessing 或本機 Ray），絕不在單次執行之內。

### 試驗登錄表與指標

- **MLflow 3.16**：Phase 0–1 使用 SQLite，自 Phase 2 起使用 PostgreSQL 後端。**每個變體都是一次 run**，包括 AI 產生的變體，並依 `trial_group_id` 分組。
- `tp_metrics`（Sharpe、Sortino、回撤、週轉率、PSR、DSR、透過 CSCV 計算的 PBO）是唯一可信來源（source of truth），並以參考值進行單元測試。QuantStats 固定版本，且僅用於呈現。
- 交叉驗證使用 skfolio 的 `CombinatorialPurgedCV`，搭配淨化（purge）與禁入期（embargo），或採用前推（walk-forward）驗證。

### 晉升關卡

| 關卡 | 進入準則（起始值，依策略類別校準） |
|---|---|
| **G0 研究** | 在測試前寫下假設與資料血緣（data lineage）；記錄每個變體 |
| **G1 回測** | 前推或 CPCV；**DSR ≥ 0.95**；**PBO ≤ 0.2**；超過 70% 的 CPCV 路徑為正報酬；樣本外 Sharpe 至少為樣本內的 50%；在手續費、滑價及借券與融資成本加倍的情況下仍能獲利，且在無法借券時拒絕放空（`BorrowModel`，[ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md)）；兩層一致；容量估算；對跨除權息日持有的股票涵蓋公司行動；對賣出的美式選擇權涵蓋提前指派；永續合約的資金費用經過重播 |
| **G2 模擬交易** | 至少 3 個月，*或*依策略類別採用交易次數路徑：當沖（每天 ≥ 3 次來回交易）≥ 200 次來回且 ≥ 6 週；波段 ≥ 60 次來回且 ≥ 8 週；部位型（position）策略沒有交易次數路徑；風險有限（defined-risk）的選擇權策略 ≥ 30 個已平倉部位且 ≥ 2 個到期週期。當引擎仍為候選發行版（release candidate）時，絕不短於 30 天的浸泡測試（soak）。滑價與追蹤誤差在範圍之內；對帳無誤；沒有人工覆寫（[建議架構](../../architecture/recommended-architecture.zh-TW.md) §8.2） |
| **G3 實盤（小規模）** | 真實資金關卡（[ADR-0010](ADR-0010-real-money-gate-and-dependency-pinning.zh-TW.md)）；上線檢查清單；10% 資金；一位獨立核准者，或對單人營運者而言，一份經簽署的檢查清單 ADR 加上 24 小時冷靜期 |
| **G4 實盤（擴大規模）** | 25%，接著 100%，前提是實盤損益維持在回測的蒙地卡羅 95% 區間之內；每季重新驗證；超出區間時自動進入 `REDUCING`/`HALTED` |

**機制。** 一次晉升會為該 bundle 寫入 MLflow 的 stage 標籤。實盤節點只會載入帶有該帳戶模式所要求之 stage 的 bundle，並**拒絕未登錄的 bundle**。設定變更會產生新的 bundle 版本；實盤程式碼絕不熱修補（hot-patch）。回滾（rollback）意指先平倉或移交，再重新部署前一個 bundle。

**AI 輔助。** 對資料湖提供唯讀的 MCP 工具。AI 撰寫的程式碼在沒有網路、沒有憑證的容器中執行。券商 MCP 伺服器僅允許用於模擬交易帳戶。這些規則只是研究 09 所稱「不可妥協」之防護措施（guardrails）的一部分；完整的 **AI 信任邊界**見 [ADR-0017](ADR-0017-ai-trust-boundary.zh-TW.md)：LLM 輸出只能成為提案，並須經過 `tp_risk` 與人工核准；AI 專用的 token 不具下單、控制或限額權限；無法存取 Telegram 控制或 SOPS/age 金鑰；新聞與申報文件被視為提示注入（prompt injection）的媒介；提示與工具呼叫的稽核日誌；`llm_export_allowed` 授權檢查；以及持有金鑰的主機上不得執行程式撰寫代理（coding agent）。

### 後果

**正面**

- 前視偏誤錯誤與成本模型缺口，會在任何資金承擔風險之前，以兩層分歧的形式浮現。
- 任何結果，無論是實盤或回測，都能由其 manifest 重現。Golden master 會在每次合併時捕捉回歸問題。
- DSR 與 PBO 建立在誠實的試驗次數之上，可防止自我欺騙以及 AI 產生的過度擬合。
- 實盤節點無法執行未通過關卡的程式碼。

**負面**

- 每個指標都必須撰寫兩次（批次與增量），並以測試維持兩者等價。
- 關卡證據需要日曆時間：上線實盤前至少需要 3 個月的模擬交易，或依類別的交易次數路徑。投入更多心力也無法縮短這段時間，這也是路線圖將 Phase 2 拆分為建置模擬交易堆疊（2a）、模擬交易期間（2b）與首次實盤（2c）的原因。
- 跨平台比較需要維護容許誤差，而非精確的雜湊值。
- MLflow 與登錄表的紀律會為每個實驗增加額外負擔。

### 確認

- CI 工作：掛鐘時間與 I/O lint、每次合併時的 golden master 重播、G1 之前的兩層一致性檢查，以及 `tp_metrics` 參考測試。
- `assert_real_money_gate` 與 bundle stage 檢查會在節點啟動時執行。
- 晉升紀錄（MLflow 標籤加上經簽署的檢查清單）會附加至每個 G3 或 G4 決策。

### 重新檢視時機

- **T11：** AI 產生的策略或自動化因子挖掘 → 在 Phase 2 之前，導入全平台的試驗次數計算、沙箱化的程式碼執行，以及任何委託送出前的人工核准。
- 情境 2：具沙箱化 kernel 的 JupyterHub、Kubernetes 上的 Ray、MLflow 角色型存取控制（RBAC）、全平台的 DSR 平減，以及用於美股的選用 LEAN 差異比對 oracle。
- **T5：** 對佇列敏感的策略 → L2/L3 擬真度與經 TCA 校準的成交模型。

## 連結

- [主報告：回測列、設計原則 2 與 10、資料流表，以及 Phase 1–2](../../README.zh-TW.md)
- [建議架構 §3.8、§4.9、§5.5、§8.1 與 §8.2](../../architecture/recommended-architecture.zh-TW.md)
- [評估紀錄：嫁接項目 11、12、15 與 16；疑慮 9](../../architecture/evaluation.zh-TW.md)
- 研究：[02 回測引擎](../../research/02-backtesting-engine.zh-TW.md) · [09 研究、ML 與分析](../../research/09-research-ml-analytics.zh-TW.md) · [01 確定性](../../research/01-core-language-runtime.zh-TW.md)
- 相關 ADR：[ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md) · [ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.zh-TW.md) · [ADR-0004](ADR-0004-parquet-lake-for-historical-data.zh-TW.md) · [ADR-0010](ADR-0010-real-money-gate-and-dependency-pinning.zh-TW.md) · [ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md) · [ADR-0017](ADR-0017-ai-trust-boundary.zh-TW.md)
