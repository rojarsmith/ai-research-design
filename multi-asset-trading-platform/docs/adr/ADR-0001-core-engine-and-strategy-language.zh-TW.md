[English](ADR-0001-core-engine-and-strategy-language.md) | **繁體中文**

# ADR-0001：核心引擎語言與策略語言

## 狀態

**提案中（Proposed）** · 2026-10-05 · 範圍：情境 1（1–3 人，自用），情境 2 的演進方向記於 *重新檢視時機（Revisit when）*。

## 背景與問題陳述

平台需要做出兩項難以逆轉的語言選擇：

1. **核心引擎**的語言：事件迴圈（event loop）、訂單管理系統（OMS）、交易前風控（pre-trade risk）、撮合模擬器，以及市場資料正規化。
2. **策略作者**撰寫策略所用的語言。同一份策略程式碼必須能在回測、模擬交易（paper trading）與實盤交易中執行（[設計原則 1](../../README.zh-TW.md)）。

影響決策的因素（研究 [01](../../research/01-core-language-runtime.zh-TW.md) 與 [10](../../research/10-open-source-platforms-build-vs-buy.zh-TW.md)）：

- **延遲層級。** 情境 1 的目標是從決策到下單的延遲在數十到數百毫秒之間，使用 K 線（bars）與 L1 資料，持有期間從數分鐘到數週。造市（market making）與 10 毫秒以下的策略不在範圍內。在這個層級，券商往返時間佔了延遲的主要部分，因此核心語言並非瓶頸。
- **團隊。** 一到三人，未來可能成長到 5–20 人。Python 的開發者使用率為 57.9%（Stack Overflow 2025），Rust 為 14.8%，C# 為 27.8%。小團隊無法再額外配置人力來維護 Rust 核心。
- **現有核心。** NautilusTrader v2 採用 Rust 核心，並提供 Python（PyO3）策略 API。它支援 Linux x86_64/ARM64、macOS ARM64 與 Windows x86_64 上的 Python 3.12–3.14，在 Linux 上需要 glibc 2.35 以上版本。QuantConnect LEAN 採用 C#/.NET 10 核心，透過其 pythonnet 分支（fork）執行 Python 3.11；Python 3.11 將於 2027 年 10 月終止支援（end of life）。
- **自建 Rust 核心**（方案 B）會讓第一筆實盤交易落在約第 10 個月，且需要約六名工程師，其中包括資深 Rust 人員。可行性評審（feasibility judge）針對小團隊給出 3.0/10 的分數（[評估](../../architecture/evaluation.zh-TW.md)）。
- **Python 版本。** 截至 2026-10-05，3.14 是唯一仍在進行錯誤修正（bugfix）的分支，3.13 僅提供安全性修補，而 3.15.0 將於 2026-10-09 發布。
- **並行（Concurrency）。** 確定性來自單執行緒的事件驅動（event-driven）核心（kernel）。free-threaded CPython 3.14 會引入執行緒的不確定性，這對回測有害。

## 決策驅動因素

- 1–3 人團隊上線第一個實盤市場所需的時間。
- 回測與實盤一致性：所有模式使用同一份策略程式碼庫。
- 研究生態系（NumPy、Polars、DuckDB、SciPy、scikit-learn、QuantLib 繫結）。
- 招募人才庫，以及我們自有程式碼的巴士因子（bus factor）。
- 採用定點數值運算的確定性核心（[ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.zh-TW.md)）。
- 日後被迫更換引擎的成本（關鍵人物風險、開放核心（open-core）風險、授權）。
- 跨平台封裝，涵蓋 Linux 伺服器與 Windows/macOS 桌面環境。

## 考量的選項

1. **在採用的 Rust 核心（NautilusTrader v2）上以 Python 撰寫策略。** 情境 1 中我們不撰寫任何 Rust。
2. **在採用的 C# 核心（LEAN、.NET 10）上以 Python 或 C# 撰寫策略。**
3. **自建 Rust 核心，搭配 PyO3 策略 API**（方案 B）。
4. **純 Python 引擎**，以 Numba 與 Polars 加速。
5. **C++、JVM 或 Go 核心**，透過 FFI 或 IPC 以 Python 撰寫策略。

## 決策結果

**選定選項：1，「在採用的 Rust 核心（NautilusTrader v2）上以 Python 撰寫策略」。** 這是唯一既能提供確定性、定點數、具 Rust 速度的核心，*又*能讓 1–3 人團隊只需使用 Python 與 TypeScript 工作的選項。採用該引擎本身的決策記錄於 [ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md)。

由此決策衍生的規則：

| 領域 | 規則 |
|---|---|
| 核心 | NautilusTrader v2 的 Rust 核心，原封不動採用。情境 1 中我們不撰寫也不修補 Rust。**至少一名團隊成員必須能閱讀 Rust**，因為 v2 的故障會以 Rust 堆疊追蹤（stack trace）的形式呈現 |
| 策略與研究語言 | **Python 3.14，標準（GIL）版本。** 策略或引擎程式碼不使用 free-threaded 版本 |
| 映像檔 | 第 2 階段（Phase 2）結束前使用單一主映像檔（Python 3.14、pandas 3）。只有在第 3 階段的選擇權相關工作需要 vollib 或 alphalens 時，才會出現 `legacy-quant` 映像檔（Python 3.13、pandas 2.3）。Python 3.15 列為 2027 年的升級項目，須在每個鎖定版本的 wheel 都驗證過後才進行 |
| 分層 | 訊號與部位規模（sizing）邏輯位於 **`tp_signals`**：純函式、與引擎無關，並以**相容 Python 3.11 的語法**撰寫，讓 LEAN 執行環境也能承載。`platform/runtime/nautilus/` 中的 `GuardedStrategy` 是精簡的 Nautilus 黏合層。`tp_*` 套件絕不匯入 `nautilus_trader`；由 import linter 強制執行此規則 |
| 熱路徑 | 在研究中以 NumPy/Polars 向量化，或使用 Numba 計算核心（kernel）。只有在觸發條件 T5 成立時才使用 Rust 策略 |
| 並行 | 每個節點一個單執行緒核心。平行化僅在*多次執行之間*進行（參數掃描、交叉驗證折（folds）），絕不在單次執行之內 |
| 其他語言 | 用戶端使用 TypeScript（[ADR-0007](ADR-0007-web-first-client-and-charting-stack.zh-TW.md)）。API 閘道、日誌（journal）、排程器與緊急停止開關（kill switch）使用 Python。其他語言的供應商 SDK 在行程外（out of process）執行（[ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.zh-TW.md)） |

### 後果

**正面**

- 從研究筆記本到實盤節點都使用同一種語言，回測、沙盒（sandbox）與實盤使用相同的策略程式碼。
- 無需維護任何自訂的 Rust 或 C++。團隊只需招募 Python 與 TypeScript 人才。
- 定點 i128 價格、UTC 奈秒時間，以及確定性的單執行緒核心，皆隨引擎一併提供。
- 由於 `tp_signals` 與引擎無關，若被迫轉移到 LEAN（觸發條件 T6/T10），將成為範圍有限的移植工作，估計約 2–4 人月，而非重寫策略：需要重寫的是與引擎綁定的轉接器（adapter）、模擬擴充以及執行環境黏合層（[ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md)）。轉移到自建核心的成本則高得多。

**負面**

- 每個事件的 Python 回呼成本高於原生程式碼。這在我們的延遲層級可以接受，但在沒有 T5 的情況下，便排除了 10 毫秒以下的策略。
- 除錯需要具備 Rust 閱讀能力，這使招募條件略為收窄。
- 必須管理 Python 版本差異：主映像檔為 3.14，`tp_signals` 的語法凍結在 3.11（例如不使用 PEP 695 型別參數語法），而部分供應商 SDK 的版本支援較為落後。富邦 Neo（Fubon Neo）支援 Python 3.8–3.13，因此無法共用主映像檔，必須在自己的 sidecar 中執行。
- 我們依賴 NautilusTrader 的 wheel 支援矩陣及其 glibc 2.35+ 的最低版本需求。

### 確認方式

- CI 中的 import linter 會阻擋在 `platform/runtime/` 與 `adapters/` 以外匯入 `nautilus_trader`。
- 一個 CI 工作會在 Python 3.11 直譯器上執行 `tp_signals` 的單元測試。
- Lint 規則禁止在 `tp_signals`、`tp_risk` 與 `strategies/` 中讀取實際時鐘（wall-clock）、進行 I/O，以及使用未設定種子的隨機數。
- 第 0 階段（Phase 0）的技術驗證（spike）會確認每個鎖定版本的相依套件都有 Python 3.14 wheel。

### 重新檢視時機

- **T5：** 需要約 10 毫秒以下的反應時間，或需要 L2/L3 佇列建模。加入 Rust 策略；這需要 Rust 人員。
- **T6：** NautilusTrader 2.0 GA 延遲到第 2 階段結束之後、上游拒絕我們需要的變更，或專案變更授權條款或將功能移到付費牆之後。轉移到位於 `StrategyRuntime` 之後的 LEAN；若有兩名以上資深 Rust 工程師，則可轉移到自建 Rust 核心。
- **團隊實際上以 C# 為主。** 在同一個 port（介面）之後將 NautilusTrader 換成 LEAN，並接受策略使用 Python 3.11。

## 各選項的優缺點

| 選項 | 優點 | 缺點 |
|---|---|---|
| 1. 在採用的 Rust 核心上使用 Python | 最快上線實盤；不需 Rust 人員即可獲得 Rust 速度；有持續維護的 IB 與加密貨幣轉接器 | RC 版本頻繁變動；關鍵人物風險；需要一名能閱讀 Rust 的成員 |
| 2. LEAN（C#） | Apache-2.0；最穩定；美股與選擇權模型最完整 | Python 鎖定在 3.11（2027-10 終止支援）；Python 策略較慢；不支援台灣市場、不支援債券；需要 C# 技能 |
| 3. 自建 Rust 核心 | 完全掌控；引擎中沒有 LGPL | 第一筆實盤交易約在第 10 個月，且需約六名工程師；對 1–3 人團隊而言是致命的 |
| 4. 純 Python | 最簡單 | 每個事件的處理速度慢；OMS、對帳與轉接器都必須自行建置 |
| 5. C++/JVM/Go | 成熟的效能選項 | 需跨兩種語言除錯；散戶量化生態系薄弱；沒有可直接採用的多資產引擎 |

## 連結

- [主報告：建議技術堆疊與情境 1](../../README.zh-TW.md)
- [建議架構 §2、§3.3 與 §6](../../architecture/recommended-architecture.zh-TW.md)
- [評估記錄：分數，以及嫁接項 19（`StrategyRuntime`）與嫁接項 34（Rust 閱讀者）](../../architecture/evaluation.zh-TW.md)
- [方案 A](../../architecture/proposal-A-lean-mvp.zh-TW.md) · [方案 B](../../architecture/proposal-B-performance-core.zh-TW.md)
- 研究：[01 核心語言與執行環境](../../research/01-core-language-runtime.zh-TW.md) · [10 自建或採購](../../research/10-open-source-platforms-build-vs-buy.zh-TW.md)
- 相關 ADR：[ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md) · [ADR-0003](ADR-0003-fixed-point-numerics-and-nanosecond-timestamps.zh-TW.md) · [ADR-0009](ADR-0009-open-source-licensing-strategy.zh-TW.md) · [ADR-0010](ADR-0010-real-money-gate-and-dependency-pinning.zh-TW.md)
