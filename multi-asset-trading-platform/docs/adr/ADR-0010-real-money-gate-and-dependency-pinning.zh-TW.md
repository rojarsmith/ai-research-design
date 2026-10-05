[English](ADR-0010-real-money-gate-and-dependency-pinning.md) | **繁體中文**

# ADR-0010：候選發行版引擎的真實資金關卡，以及相依套件版本鎖定

## 狀態

**提議中（Proposed）** · 2026-10-05 · 範圍：情境 1，直到鎖定 NautilusTrader 2.0.0 正式版（GA）為止；版本鎖定政策則適用於所有情境。

## 背景與問題陳述

[ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md) 建構於 NautilusTrader v2 之上，而 v2 目前仍是候選發行版（release candidate，RC）：

- 2.0.0rc5（2026-09-15）是 PyPI 上最新的建置版本；rc6 的發行說明日期為 2026-10-04。尚未公布 GA 日期。
- 上游建議不要以真實資金執行 RC 版本。
- RC 版本會造成破壞性變更。rc3 移除了 Cython 套件，rc4 將 `LiveExecClientConfig` 更名為 `ExecutionClientConfig`，rc6 則強制要求明確指定手續費模型，並移除了 BitMEX。
- 穩定的 1.231.x 系列僅接收重大安全性修補的向後移植（backport），約於 2026 年 11 月結束，早於任何實際可行的上線時間。

其他相依套件同樣變動頻繁（[主報告的風險](../../README.zh-TW.md)）：

- DuckDB 2.0（2026-10-21；1.5 於 2026-11-01 終止支援）。
- Python 3.15（2026-10-09）。
- pandas 3 / 2.3 的分歧，以及 Polars 2.0 的候選發行版。
- Tauri v3 alpha。
- Shioaji 的 14 天發行週期（1.7.6 曾被撤回（yanked））。
- `ibapi` crate 鎖定在 `=3.3.0`，而 crates.io 上已有 5.0.0。
- QuantLib 的台灣行事曆，僅涵蓋到 2026 年。
- LEAN 使用的 Python 3.11，將於 2027-10 終止支援。

此外還有關鍵人物風險：NautilusTrader 的首席維護者約有 19,182 次 commit，而次多的貢獻者僅有 339 次；官方並已宣布推出「Nautilus Pro」方案。

何時才能在這套技術堆疊上投入真實資金？版本又該如何控管？

## 決策驅動因素

- 在沒有補償性控制的情況下，不以連維護者都認為尚未就緒的軟體交易真實資金。
- 不因等待尚未公布的 GA 而拖延路線圖。
- 讓升級對單一操作者而言既安全又可重複。
- 讓相依套件風險保持可見，並有明確的負責人。

## 考慮的選項

1. **以 1.231.x（穩定版 v1）上線**，之後再移植到 v2。
2. **以鎖定的 RC 上線**，不設額外關卡。
3. **等待 GA** 之後才進行任何真實資金交易。
4. **真實資金關卡：** GA，*或*一個已通過 30 天模擬交易浸泡測試（paper soak）且零無法解釋之對帳差異的鎖定 RC，另加一份已簽署的風險承擔 ADR，並在 GA 之前將資金上限設為 10%。同時建立相依套件風險登記簿與嚴格的版本鎖定政策。

## 決策結果

**選定選項：4。** 它將「以 RC 投入真實資金」從一個未受控的風險，轉變為經過衡量、設有上限且有文件記錄的風險。它不會阻礙 Phase 2，也避免把資源投入在一個支援期於上線前就結束的 v1 系列。

### 關卡

投入實盤資金須符合以下**任一**條件：

- **(a)** 鎖定 NautilusTrader **2.0.0 GA**；**或**
- **(b)** 鎖定某個候選發行版，且該版本：
  - 已針對完全相同的 bundle 與引擎鎖定版本，通過 **30 天模擬交易浸泡測試**（sandbox 和/或交易場所的模擬交易），且**零無法解釋的對帳差異（reconciliation break）**；
  - 具備一份**已簽署的風險承擔 ADR**，在動用此關卡時以獨立編號的 ADR 撰寫。單人操作者須依書面檢查清單簽署，並經過 24 小時的冷靜期；
  - 在 GA 之前**資金上限為 10%**。

runtime factory 中的 `assert_real_money_gate(bundle, accounts)` 會在節點以 `LIVE` 模式啟動時檢查鎖定版本、浸泡測試紀錄與資金上限，不符合時即拒絕啟動。退回 1.231.x 只是權宜之計。

### 版本鎖定與升級政策

| 規則 | 細節 |
|---|---|
| 精確鎖定 | `nautilus_trader==2.0.0rc5`（精確版本）以及雜湊鎖定的 lockfile（`uv.lock`、npm lockfile）。容器映像檔以 digest 參照 |
| 單一主要映像檔 | 在 Phase 2 結束前皆使用 Python 3.14 與 pandas 3。僅在 Phase 3 需要時才建立 `legacy-quant` 映像檔 |
| 採用延遲 | 新版本須等待 3–7 天後才採用（供應鏈衛生） |
| 維護時段 | 每月一次：NautilusTrader RC、Shioaji（14 天週期）、Python 修補版本、DuckDB 2.0、QuantLib（每季） |
| 升級測試 | 每次升級在進入實盤節點之前，都必須執行 golden-master 重播（在相同平台上比對事件雜湊）、轉接器（adapter）契約測試與對帳測試 |
| 回復 | 重新部署前一個映像檔 digest 與 bundle。絕不對實盤程式碼進行熱修補 |
| 設定變動 | 所有引擎設定都在 `platform/runtime/` 的 factory 中建構，因此遇到更名時只需修改一處 |

### 相依套件風險登記簿

在程式碼儲存庫中維護的登記簿（Phase 0 的交付項目）。每個項目都有負責人、觸發條件與備案。初始項目：

| 相依套件 | 風險 | 緩解措施或備案 |
|---|---|---|
| NautilusTrader | 關鍵人物集中；open-core（Nautilus Pro）；RC 頻繁變動；沒有 GA 日期 | 精簡的 `tp_signals` 與 `StrategyRuntime` port；至少一名能閱讀 Rust 的成員；於 Phase 3c 演練一次 LEAN 備案，移植估計需 2–4 人月（[ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md)）；觸發條件 T6 |
| Rust `ibapi` crate（`=3.3.0`） | 實質上只有一名維護者；落後 crates.io 兩個主要版本 | ib_async（BSD-2）為獨立實作，且已被緊急停止開關（kill switch）使用；此 MIT 授權的 crate 可納入自有原始碼（vendor）或分叉（fork） |
| Shioaji | 每 14 天發行一次、曾有版本被撤回、流量上限會回傳空值 | Sidecar 邊界、精確鎖定、契約測試、將空回應視為警報、以富邦 Neo 作為備案 |
| DuckDB | 2.0 於 2026-10-21 發布；1.5 於 2026-11-01 終止支援 | Phase 0 升級測試（[ADR-0004](ADR-0004-parquet-lake-for-historical-data.zh-TW.md)） |
| Python | 3.15 於 2026-10-09 發布；LEAN 備案鎖定於 3.11（2027-10 終止支援） | 在確認 wheel 可用後，於 2027 年採用 3.15；保持 `tp_signals` 與 3.11 相容 |
| QuantLib 行事曆 | 台灣行事曆僅涵蓋到 2026 年 | 於年底前載入 2027 年的 TWSE/TAIFEX 休市日（[ADR-0012](ADR-0012-security-master-rules-packs-and-calendars.zh-TW.md)） |
| Tauri | v3 仍為 alpha | 鎖定 2.x |

### 後果

**正面**

- 在 RC 上投入的真實資金最多只占資金的 10%，且僅在有證據顯示對帳無誤後才開始。
- 路線圖不會受制於尚未公布的 GA 日期。
- 升級成為例行、經過測試的每月事件，而不是一次事故。
- 相依套件風險在造成衝擊之前，就已有負責人與備案。

**負面**

- 若 30 天浸泡測試單獨進行，將使首次上線的時程最多延長一個月。路線圖將其安排在 G2 模擬交易期間（Phase 2b）內執行，因此兩人團隊的首次上線仍維持在約第 8–9 個月；但對高周轉率策略而言，它確實會將以交易筆數為依據的路徑延長至至少 30 天。
- 10% 的上限會在 GA 之前限制報酬。
- 每次 RC 版本升級仍會耗費工程時間，而若鎖定版本在上線前變更，浸泡測試可能必須重新開始。
- 每月維護時段與登記簿，對小型團隊而言是長期的維運職責。

### 確認

- `assert_real_money_gate` 具備單元測試，並會在上線演練中透過一次刻意失敗的啟動加以驗證。
- 浸泡測試紀錄與風險承擔 ADR 會附加於 G3 核准紀錄中（[ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.zh-TW.md)）。
- 登記簿會在每次每月維護時段中接受審查。

### 何時重新檢視

- NautilusTrader 2.0.0 GA 發布 → 鎖定該版本、重新執行 golden master，並透過正常的 G4 逐步加碼解除 10% 上限。
- **T6：** GA 延誤至 Phase 2 結束之後，或發生授權或 open-core 變更 → 改用 LEAN 或自有核心。
- 登記簿中某個項目的觸發條件成立。

## 連結

- [主報告：結論（「為真實資金設置關卡」）、情境 1 與風險](../../README.zh-TW.md)
- [建議架構 §3.3、§3.12 與 §8.3](../../architecture/recommended-architecture.zh-TW.md)
- [評估紀錄：嫁接項（graft）1、2 與 33；疑慮（concern）1 與 2；§6 v1 與 v2 的抉擇](../../architecture/evaluation.zh-TW.md)
- 研究：[01 核心語言與執行環境](../../research/01-core-language-runtime.zh-TW.md) · [02 回測引擎](../../research/02-backtesting-engine.zh-TW.md) · [10 自建或採購](../../research/10-open-source-platforms-build-vs-buy.zh-TW.md)
- 相關 ADR：[ADR-0001](ADR-0001-core-engine-and-strategy-language.zh-TW.md) · [ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md) · [ADR-0011](ADR-0011-intent-wal-and-hash-chained-ledger.zh-TW.md) · [ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.zh-TW.md)
