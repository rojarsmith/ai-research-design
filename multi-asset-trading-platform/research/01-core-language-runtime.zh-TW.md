[English](01-core-language-runtime.md) | **繁體中文**

# 核心程式語言與執行環境（Runtime）

*研究面向 01 · 狀態截至 2026-10-05 · 範圍：股票、加密貨幣、債券、選擇權；美國/全球 + 台灣（TWSE/TAIFEX）*

## TL;DR

- **建議分工：Rust 核心引擎、Python 策略/研究 API、TypeScript 前端。** 這與 NautilusTrader 正在轉向的模式相同。v1.231.0（2026-08-02）預定為其最後一個 Cython（v1）版本，而 Rust + PyO3 的 v2 執行環境仍處於候選發行版（release candidate）階段：master 分支的發行說明中 2.0.0rc6 標示的日期為 2026-10-04，但截至 2026-10-05，實際發布於 PyPI/GitHub tags 的最新 RC 為 2.0.0rc5（2026-09-15）。單純執行 `pip install nautilus_trader` 仍會安裝 v1.231.0；v2 需要加上 `--pre`。
- **對單人 MVP 而言，語言問題大致上就是「Python 加上借用現成引擎」。** 以 Python 3.14 撰寫策略（3.13 現已僅提供安全性修補），並採用既有、以 Rust 或 C# 為核心的引擎。唯有在效能剖析（profiling）顯示確有需要時，才自行建置 Rust 元件。**C#/.NET 10（LEAN 風格）** 是最有力的替代核心，對以 Windows 為主的團隊尤其如此。
- **在下單/會計路徑中，絕不要用二進位浮點數表示價格、數量或金額。** 請使用依商品（instrument）設定精度的定點整數：≤9 位小數用 i64，≤16–18 位小數用 i128。鏈上加密貨幣金額使用 U256。float64 僅用於分析與 Greeks。
- **全系統統一使用單一時間型別：** 自 Unix epoch 起算的 i64 UTC 奈秒。.NET `DateTime`（100 ns tick）與 Python `datetime`（µs）會無聲地損失精度。TAIFEX 夜盤跨越午夜，因此「交易日 ≠ 日曆日期」。
- **決定性（determinism）來自單執行緒的事件驅動（event-driven）核心**，邊緣採用非同步 I/O，回測時使用模擬時鐘。自由執行緒（free-threaded）Python（3.14 起正式支援）並不是將策略邏輯多執行緒化的理由。

## 關鍵問題

1. **核心引擎**（事件迴圈、訂單管理系統（OMS）、風控、撮合模擬器、行情資料正規化）要使用哪種（些）語言？
2. **策略作者**使用哪種語言撰寫，且*同一份*策略程式碼能否在回測、模擬交易（paper）與實盤中執行？
3. 跨越 **FFI 邊界**的成本為何？又要如何在 x86 與 ARM 上的 Windows/macOS（Apple Silicon）/Linux 進行封裝？
4. 面對精度需求差異極大的各資產類別，要如何表示**價格/數量**？
5. 如何處理**時間**：奈秒時間戳記、時區、跨越午夜的交易時段、交易所行事曆？
6. 哪種**並行模型**能讓回測保持決定性，同時讓實盤 I/O 維持即時回應？

## 方案比較

### 1. 語言/執行環境概況（2026 年 10 月）

| 語言 | 目前狀態（已查證） | 記憶體 / GC | 尾端延遲 | 量化生態系 | 跨平台建置與封裝 | 人才招募（SO 2025 使用率，全體受訪者） |
|---|---|---|---|---|---|---|
| **Rust** | 1.99.0（2026-10-01）；每 6 週發布一次 | 所有權（ownership）機制、無 GC；預設即記憶體安全 | 極佳、可預測 | 成長中：NautilusTrader、hftbacktest、Polars、Arrow | `cargo` 跨目標平台編譯；透過 maturin 產生 wheel；單一靜態執行檔 | 14.8% |
| **C++** | C++26 已於 2026 年 3 月完成技術定案（reflection、contracts、`std::execution`），正進行 ISO 出版程序 | 手動/RAII；預設不安全（C++26 加入強化（hardening）機制） | 可達到的最佳水準（HFT 標準） | 深厚（QuantLib、供應商 SDK、交易所 API） | 最困難：CMake/vcpkg/Conan、ABI 與工具鏈組合矩陣 | 23.5% |
| **C# / .NET** | .NET 10 LTS（2025-11-11，依官方支援政策支援至 2028-11-14；最新修補版 10.0.12）；.NET 11 STS 預計 2026 年 11 月推出（RC1 已於 2026-09-08 開放正式上線使用（go-live）） | 分代式 GC（DATAS、以 region 為基礎）；值型別/`Span<T>` 可減少記憶體配置 | 良好；GC 暫停可調校，並提供 NativeAOT | LEAN（Apache-2.0）、StockSharp、眾多券商 SDK | 非常好：一套 SDK 涵蓋 win/mac/linux x64+arm64 | 27.8% |
| **Java / Kotlin (JVM)** | Java 25 LTS（僅有 Generational ZGC）；JDK 27 於 2026-09-15 GA | ZGC：「最大暫停時間低於 1 毫秒」（sub-millisecond max pause times） | 搭配 ZGC 與記憶體配置紀律則表現良好（Aeron/Chronicle 風格） | 在銀行業強勢；散戶量化社群薄弱 | JVM 可攜；jlink/GraalVM native-image | 29.4% / Kotlin 10.8% |
| **Go** | 1.27.0（2026-08-19），最新修補版 1.27.1（2026-09-01）；自 1.26 起預設採用 Green Tea GC（GC 開銷降低 10–40%） | 並行 GC、暫停時間短 | 適合閘道器；控制力不如 Rust | 單薄（量化/回測函式庫很少） | 跨平台編譯極為簡單、靜態執行檔 | 16.4% |
| **Python** | 目前為 3.14.8（2026-09-30；3.14 是唯一的錯誤修正分支，3.13 僅提供安全性修補）；3.15.0 正式版延至 2026-10-09（rc3 於 2026-10-02 發布） | 參考計數 + 循環 GC；GIL（預設）或自由執行緒建置版本 | 純 Python 熱迴圈表現差 | 無可匹敵（NumPy、pandas、Polars、SciPy、statsmodels、PyTorch） | 每個平台各自的 wheel；原生相依套件是痛點 | 57.9%（年增 7 個百分點） |
| **Julia** | 1.13.1（2026-09-25）；LTS 1.10.12 | GC；JIT（LLVM） | 暖機後快速；有編譯延遲 | 小眾但數值運算優秀 | 發布獨立執行檔仍不成熟 | 未列入 |

**解讀：** Rust 與 C++ 是唯二在熱路徑上沒有 GC 的選項。兩者之中，只有 Rust 同時提供記憶體安全與輕鬆的跨平台建置。C#/Java 只要遵守紀律，就能將差距控制在一個數量級以內，且其團隊人才庫較大、較容易招募。Python 在策略作者體驗與研究方面勝出，在其他所有方面則落敗。

### 2. 加速 Python（當 Python 作為策略語言時）

| 技術 | 狀態（2025-2026） | 適用於 | 注意事項 |
|---|---|---|---|
| **NumPy / Polars / Arrow 向量化** | 成熟 | 向量化研究、因子篩選、K 棒層級回測 | 無法表達路徑相依的下單邏輯 |
| **Numba** | 0.63（2025 年 12 月）加入 3.14；0.65（2026 年 3 月）支援 3.14t 自由執行緒；0.68.0（2026-09-30）加入 Python 3.15 | 緊密的數值迴圈、指標運算核心 | 僅支援 Python 的子集；自 0.62 起不支援 Intel SVML（截至 0.65 仍不支援） |
| **Cython** | 3.1+ 支援自由執行緒（實驗性） | 既有的 C 速度擴充模組 | NautilusTrader 已捨棄它、改用 PyO3；需跨兩種語言除錯 |
| **PyO3 + maturin (Rust)** | PyO3 0.29（2026 年 6 月；最新 0.29.3，2026-09-30）：支援 Python 3.15，新的 `abi3t` 穩定 ABI 同時涵蓋自由執行緒與 GIL 建置版本 | 將 Rust 核心公開給 Python 使用 | 每次呼叫都會跨越 ABI 邊界；應設計粗粒度的 API。`abi3t`（PEP 803）僅以 CPython 3.15+ 為目標，因此 3.14t 仍需各版本專屬的 `cp314t` wheel |
| **mypyc** | 隨 mypy 一同維護 | 編譯具型別標註的純 Python 模組（中等程度加速） | 對數值程式碼的效益有限 |
| **自由執行緒 CPython** | 3.14 中正式支援（PEP 779）。單執行緒額外開銷約 1%（macOS arm64）至 8%（x86-64 Linux）。匯入非 FT 的 C 擴充模組會重新啟用 GIL（CPython 會印出警告） | 研究中的平行 CPU 工作（參數掃描） | 非預設。物件標頭較大。執行緒帶來的非決定性對回測而言是毒藥 |
| **CPython JIT** | 實驗性；3.15 回報約 7–8%（x86-64 Linux）、約 11–12%（macOS arm64） | 免費的加速 | 無法取代原生程式碼 |

### 3. 混合架構模式（真正的決策所在）

| 模式 | 參考實作 | 策略語言 | 回測/實盤一致性 | FFI 成本概況 | 封裝 | 最適合 |
|---|---|---|---|---|---|---|
| **A. 純 Python 引擎**（+Numba/Polars） | 自行開發；許多散戶用框架 | Python | 高（同一行程） | Python 內部無 FFI 成本；但每個事件的處理很慢 | 最容易 | 日線/波段策略、以研究為先的 MVP |
| **B. Rust 核心 + Python API（PyO3）** | NautilusTrader v2（LGPL-3.0-only；v1.x 為 LGPL-3.0-or-later；Python 3.12–3.14；Linux x64/arm64、macOS arm64、Windows x64） | Python 或 Rust | 非常高：依設計，回測與實盤使用同一份策略程式碼 | 每次呼叫成本低；資料留在 Rust 中；每個事件呼叫 Python 回呼 | 透過 maturin 產生 wheel；需要 CI 矩陣 | 日內多資產、加密貨幣、長期經營的平台 |
| **C. C# 核心 + Python/C#（pythonnet）** | QuantConnect LEAN（Apache-2.0；.NET 10 SDK；透過 QC 的 pythonnet 分支使用 Python 3.11） | C# 或 Python | 非常高 | 封送處理（marshalling）較重；Python 演算法一般比 C# 慢 | Docker/`lean` CLI；.NET 執行環境 | .NET 團隊、開箱即用的廣泛資產涵蓋 |
| **D. C++ 核心 + Python（pybind11/nanobind）** | 專有 HFT 技術堆疊 | C++（熱路徑）、Python（研究） | 中（常為兩套程式碼庫） | 最低，但不安全 | 最困難 | 主機共置（co-located）HFT、低於 10 µs 的路徑 |
| **E. JVM 核心 + 透過 IPC 的 Python** | 銀行/交易所技術堆疊（Aeron、Chronicle） | Java/Kotlin | 中 | IPC（gRPC/Arrow Flight），非同一行程內 | 容易（JVM），Python 另行處理 | 已有 JVM 基礎設施的團隊 |
| **F. Go 服務 + 透過 IPC 的 Python 策略** | 加密貨幣交易所/閘道器基礎設施 | Python | 中低 | 每則訊息都經過 IPC | 容易 | 圍繞另一個核心的閘道器/連接器 |

## 數值表示（價格、數量、金額）

| 表示法 | 精度 / 範圍 | 速度 | 決定性 | 結論 |
|---|---|---|---|---|
| **float64（IEEE 754）** | 約 15–17 位有效數字 | 最快、SIMD | 結果取決於運算順序；`0.1+0.2≠0.3` | 僅用於分析、訊號、Greeks、風險模型 |
| **Decimal128 類型**（.NET `decimal`：96 位元整數 + 0–28 的 scale，±7.9×10²⁸；`rust_decimal` 1.43 採相同配置；Java `BigDecimal` 為任意精度；Python `decimal` 透過 libmpdec） | 28–29 位數（BigDecimal 無上限） | 通常比整數運算慢數倍；BigDecimal/Python 每次運算都會配置記憶體 | 具決定性 | 會計、交割、報表、設定/限額 |
| **定點 i64**（縮放整數，依商品設定精度） | NautilusTrader 標準模式：9 位小數，約 ±92 億 | 整數速度、無記憶體配置 | 精確 | 多數股票/期貨/選擇權的預設 |
| **定點 i128** | NautilusTrader 高精度模式：16 位小數，`PRICE_MAX` 約 ±17 兆（17,014,118,346,046）；比 64 位元慢約 3–5%；為官方 v2 wheel 在所有平台上的預設（v1.x Windows wheel 僅有 64 位元） | 接近整數速度（部分目標平台以軟體模擬） | 精確 | 加密貨幣 CEX、外匯、多資產的預設 |
| **U256 / 最小單位整數** | ERC-20 餘額為 `uint256`；`decimals` 由代幣自行定義（常見為 18） | 最慢 | 精確 | 僅用於鏈上/DeFi 金額；在 adapter 處轉換 |

**各資產類別的差異：**

- **股票。** 美股低於 1 美元的報價以低於 1 美分的增量交易，而股價可高達六位數。**台股**採分級跳動單位（依價格區間為 NT$0.01–NT$5）、±10% 漲跌幅限制，以及盤中零股交易。i64 搭配 4–6 位小數已綽綽有餘。困難之處在於跳動單位表，而非精度。
- **加密貨幣。** CEX 的數量通常 ≤8–10 位小數，i128/16 位小數即可涵蓋。鏈上金額需要 18 位小數 × 大整數。1 wei（1e-18）*無法*以 16 位小數的型別表示，因此在 DeFi 邊界應保留原始的 `uint256` 整數。
- **債券。** 美國公債以「三十二分之一」報價（例如 99-16+ = 99 + 16.5/32），更細可至 1/256。這些是**二進分數（dyadic fractions）**：1/256 = 0.00390625 在二進位浮點數中可精確表示，在定點數中則需要 8 位小數。應儲存十進位定點價格，並搭配 32 分位報價的顯示/解析編解碼器。應計利息與計息天數慣例（day-count conventions）應放在以 Decimal 為基礎的函式庫中，而非熱路徑上。
- **選擇權。** 權利金金額小且採分級跳動單位（TAIFEX TXO：10 點以下為 0.1 點，至 1,000 點以上為 10 點；乘數為每點 NT$50）。契約乘數使名目金額很大。Greeks、隱含波動率與定價模型本質上就是 float64。應讓**委託/成交/損益路徑維持定點數**、**模型路徑使用浮點數**，並進行明確的轉換。

**對語言選擇的影響：** Rust 與 C++ 能以原生成本使用定點數與 i128。.NET 內建快速的 `decimal` 與 `Int128`（自 .NET 7 起）。Java 的 `BigDecimal` 每次運算都會配置記憶體，因此低延遲 Java 會改用縮放的 `long`。Go 沒有內建 decimal，需仰賴第三方函式庫。Python `int` 為任意精度，但每個物件的運算都很慢。Python 端的金額運算應交由 Rust 核心處理，或使用向量化的 int64 陣列。

## 時間處理

| 語言 | 原生時間點解析度 | 陷阱 | 建議 |
|---|---|---|---|
| Rust | `std` Duration 為 ns；生態系有 `chrono`、`jiff`（0.2.x，1.0 已延後至 2025 年之後；在 Windows 上內嵌 tzdb） | 兩個相互競爭的時區 crate | `u64` UnixNanos newtype；時區只在顯示/行事曆邊緣處理 |
| C++ | `std::chrono` ns；C++20 時區 | Windows/較舊 libc 上平台 tzdb 的可用性 | int64 ns |
| C# / .NET | `DateTime` tick = **100 ns** | 會截斷交易所的 ns 時間戳記（CME、帶 ns 時間戳記的加密貨幣行情） | 另外攜帶 `long` ns；`DateTimeOffset` 僅用於顯示 |
| Java | `Instant` = long 秒 + int 奈秒 | 每個 `Instant` 都會配置記憶體 | 熱路徑上使用原始型別 `long` ns |
| Go | `time.Time` ns | 混用單調時鐘與牆上時鐘 | int64 ns |
| Python | `datetime` 解析度為 **1 µs** | 無聲截斷；pandas `datetime64[ns]` 僅限 1677–2262 年；pandas 3.0+ 會從字串/`datetime` 物件推斷為 `datetime64[us]`，因此 `.astype("int64")` 得到的是 µs 而非 ns | 在 Arrow/Polars/NumPy 中使用 int64 ns；在 pandas 中明確傳入 `unit="ns"`；時區使用 `zoneinfo` |

**行事曆：** `exchange_calendars` 涵蓋 50 多個交易所，包括 **XTAI**（TWSE），但**沒有 TAIFEX** 行事曆。**TAIFEX 盤後交易時段為 15:00 至次日 05:00**（TX），因此台北時間 01:00 的成交屬於*下一個*交易日的結算。台灣為 UTC+8 且無夏令時間，而美國/歐洲市場會隨夏令時間調整。加密貨幣全年無休 24/7 交易，採用以 UTC 日為準的慣例。債券另外還涉及交割行事曆（T+1）與計息天數。原則：**儲存 UTC ns；透過行事曆服務推導 `trading_date`/`session_id`**，絕不從牆上時鐘的日期推導。

## 並行模型與決定性回測

| 模型 | 決定性 | 實盤回應能力 | 採用者 |
|---|---|---|---|
| **單執行緒事件迴圈核心 + 非同步 I/O 執行緒** | 高（單一有序事件佇列、模擬時鐘） | 良好：網路/序列化在其他執行緒處理（例如 tokio） | NautilusTrader（「single-threaded kernel」）、LEAN |
| **Actor 模型**（各元件間以訊息傳遞溝通） | 若信箱順序與時間戳記具決定性則高 | 極佳；可跨核心與節點擴展 | Akka/Orleans 風格、自訂 Rust actor |
| **共享記憶體多執行緒** | 低（交錯順序取決於排程器） | 高吞吐量 | 研究用的參數掃描，而非引擎 |
| **全面使用 async/await** | 中（執行器的排程順序會滲入結果） | 良好 | 連接器/閘道器 |

**決定性規則：**

- 使用模擬時鐘，策略程式碼中絕不呼叫牆上時鐘時間。
- 時間戳記相同時，以穩定的序號決定先後。
- 為每個 RNG 設定種子。
- 避免以隨機順序迭代雜湊表（Rust 預設的 `HashMap`、Python 的物件集合）。
- 讓浮點數歸約（reduction）的結果與運算順序無關。
- 在回測*之間*平行化（參數掃描、walk-forward 分段），絕不在單一回測*之內*平行化。

## 建議

### 情境 (a)：單人 / 1–3 人 MVP

1. **策略與研究語言：Python 3.14（標準 GIL 建置版本）。** 關鍵 wheel（NumPy、Polars、Numba、NautilusTrader）都已提供 3.14 版本，而 3.13 已於 2026 年 10 月進入僅提供安全性修補的狀態（不再發布二進位檔）。將 3.15（正式版預計 2026-10-09 推出）視為 2027 年的升級項目。
2. **暫時不要自行撰寫引擎核心，而是採用現成的：**
   - **NautilusTrader v2**（Rust 核心、Python 策略）最適合加密貨幣加上日內多資產。請追蹤從 RC 到 2.0 的過渡（在 2.0 正式版之前以 `--pre` 安裝），若日後要散布軟體，請確認 LGPL-3.0-only 條款是否適用。
   - **LEAN**（C#、Apache-2.0）最適合重視廣泛股票/選擇權/期貨資料整合與 C# 友善路徑的情況。選擇它會將你的策略環境綁定在 Python 3.11，而該版本僅提供安全性修補，並將於 2027 年 10 月終止支援。
   - **兩者在債券方面都有缺口。** LEAN 沒有債券的證券類型。NautilusTrader 有 `Bond` 商品類別，但沒有殖利率、應計利息或計息天數的分析功能。請在引擎背後規劃獨立的固定收益定價函式庫（例如 QuantLib）。
3. **研究技術堆疊：** Polars/NumPy，運算核心使用 Numba。從第一天起就將所有價格儲存為 int64 定點數、時間戳記儲存為 int64 UTC ns，日後資料即可原封不動移入 Rust 核心。
4. **台灣市場連線：** 這部分由券商 SDK 的語言決定。
   - Shioaji 有原生 Python binding，並為其他語言提供 HTTP API。
   - Fubon Neo 提供 Python/C#/Node.js SDK（交易另有 C++/Go），支援 Windows/macOS/Linux。
   - 若某家券商的 SDK 與你的執行環境衝突，請將其包裝在精簡的 adapter 行程中。
5. **前端：TypeScript**（React），以 Web 應用程式形式發布，另加 **Tauri 2** 桌面/行動殼層（Rust 後端、JS 前端；Windows/macOS/Linux/iOS/Android）。Tauri 2.12.x 為目前版本，3.0 處於 alpha 階段（3.0.0-alpha.4），因此預期日後需要進行主要版本遷移。若以行動裝置為優先，主要替代方案是 React Native（仍為 TypeScript）或 Flutter；若採用 .NET 核心，C# 的選項則為 Avalonia 或 .NET MAUI。

### 情境 (b)：5–20 人團隊 / 機構等級

1. **核心引擎：Rust。** 涵蓋事件核心、OMS、風控檢查、撮合/成交模擬器、行情資料正規化與持久化寫入器。對於主機共置以外的任何延遲等級，無 GC 的記憶體安全與輕鬆的跨平台編譯，其價值都勝過 C++ 微幅的延遲優勢。
2. **策略 API：透過 PyO3 的 Python**（粗粒度、以 Arrow 為基礎）。為延遲敏感的策略提供選用的 **Rust 原生策略 trait**，且在回測與實盤中具有相同的事件語意。
3. **可行的替代核心：C#/.NET 10 LTS。** 若團隊以 .NET 為主，或必須整合僅限 Windows 的券商元件，就選擇它。Python 透過 pythonnet 仍作為策略語言，但需接受 Python 策略執行較慢。
4. **僅在不得不時才使用 C++：** 供應商 SDK、FPGA/kernel-bypass 主機共置（<10 µs）。**Go/JVM** 適合周邊服務（API 閘道器、管理後台、報表），而非具決定性的核心。
5. **前端：TypeScript**，橫跨 Web、桌面（Tauri）與行動裝置。從同一份 schema（Protobuf/FlatBuffers/JSON Schema）產生共用的 DTO 型別，讓 Rust、Python 與 TS 保持同步。

**建議組合：** **核心 = Rust · 策略 = Python（+ 選用 Rust）· 前端 = TypeScript。** 備案：**核心 = C#/.NET 10 · 策略 = Python/C# · 前端 = TypeScript。**

**延遲層級：**

| 策略持有期間 / 延遲需求 | 可接受的核心 | 說明 |
|---|---|---|
| 日–週（多數股票、債券、台灣散戶） | 純 Python 即可 | 券商 API 的往返時間（數十至數百 ms）佔主導 |
| 日內，1–100 ms（加密貨幣 WebSocket、期貨/選擇權） | Rust / C# / Java 核心、Python 策略 | 這是目標設計 |
| 低於 100 µs（造市、主機共置） | Rust/C++、Rust 原生策略 | 透過零售券商無法達成，包括台灣零售券商的 API |

## 對整體架構的影響

- **以核心語言定義標準領域模型（canonical domain model）。** 商品帶有 `price_precision`、`size_precision`、跳動單位表、乘數與行事曆 ID。Python/TS binding 以程式自動產生，而非手寫。
- **數值契約。** 傳輸格式、儲存（Parquet 整數欄位加上精度欄位）與 OMS 中一律使用定點數（i64/i128）。會計/報表邊緣使用 Decimal，模型內部使用 float64。轉換必須明確且經過測試。
- **時間契約。** 每個事件中皆使用 UTC i64 ns（`ts_event`、`ts_init`）。由行事曆/交易時段服務將時間戳記對應到交易日與交易時段，包括 TAIFEX 夜盤。
- **行程拓撲。** 每個策略群組一個單執行緒交易節點，搭配非同步 I/O 執行緒，並以執行更多節點的方式水平擴展。這會影響部署、訊息傳遞與風險彙總等研究面向。
- **資料交換。** Rust 與 Python 之間使用 Apache Arrow 進行零複製的批次傳輸。回測中避免逐 tick 建立 Python 物件。
- **建置/CI。** wheel 矩陣（win-x64、macOS-arm64、linux-x64/arm64；GIL 建置版本使用各版本專屬或 abi3 wheel；`abi3t` 僅自 CPython 3.15 起才涵蓋自由執行緒建置版本，因此 3.14t 需要 `cp314t` wheel）、可重現的工具鏈（`rust-toolchain.toml`、`uv`/lockfile），以及僅在選用時才需要的 .NET/Node 工具鏈。
- **語言不相容時，adapter 採獨立行程。** 使用 gRPC/ZeroMQ 將僅限 Windows 或僅限 Python 的券商 SDK 與核心隔離。

## 風險與陷阱

- **引擎成熟度：** NautilusTrader 2.0 仍是候選發行版（發行說明中 rc6 標示的日期為 2026-10-04；截至 2026-10-05，PyPI 上最新的是 2026-09-15 的 rc5），且 v1 在切換至 v2 後只會獲得約三個月的重大安全性修補回移（backport）。在 2.0 正式版之前，API 很可能持續變動。
- **Python 版本更迭：** LEAN 綁定 Python 3.11（僅提供安全性修補，2027-10 終止支援），NautilusTrader 支援 3.12–3.14，而 3.15 將於 2026-10-09 推出。單一研究環境可能無法同時滿足這些需求，因此請以各專案獨立的環境加以隔離。
- **自由執行緒陷阱：** 只要有一個非 FT 的 C 擴充模組就會重新啟用 GIL。CPython 只會印出警告，在服務日誌中很容易被忽略。FT 建置版本使用更多記憶體（例如在 AMD64 上 `None` 佔 32 位元組，而非 16 位元組）。執行緒會引入非決定性。
- **無聲的精度損失：** 損益與手續費中的浮點累積誤差、.NET `DateTime` 的 100 ns 截斷、Python `datetime` 的 µs 截斷、pandas 3.x 預設為 `datetime64[us]`，以及 16 位小數定點數與 18 位小數代幣之間的落差。
- **FFI 呼叫過於頻繁：** 在數百萬個事件中逐 tick 呼叫 Python 會主導整體執行時間。請批次處理事件，或將指標移入核心。
- **人才招募與巴士因子（bus factor）：** Rust 使用者約只有 Python 使用者的四分之一（14.8% 對 57.9%）。請讓 Rust 的範圍保持精簡且文件完善，讓多數貢獻者以 Python/TS 工作。
- **封裝：** Apple Silicon 與 Windows ARM 建置、glibc 最低版本（NautilusTrader 需要 glibc 2.35+）以及原生相依套件的 wheel 都是反覆發生的成本。請為其編列 CI 預算。
- **授權：** 若日後要將系統以可散布的產品形式提供，LGPL-3.0-only（NautilusTrader v2）與 Apache-2.0（LEAN）的差異就很重要。以託管 SaaS 形式運行則有不同的義務，請與法律顧問確認。
- **行事曆缺口：** `exchange_calendars` 中沒有現成的 TAIFEX 行事曆。台灣的颱風假屬於臨時公告，需要有手動覆寫的途徑。

## 參考資料

- NautilusTrader PyPI（版本、Python/平台支援、精度模式、LGPL）： https://pypi.org/project/nautilus-trader/
- NautilusTrader 發行說明（2.0.0rc6，2026-10-04）： https://raw.githubusercontent.com/nautechsystems/nautilus_trader/master/RELEASES.md
- NautilusTrader v1.231.0，最後一個 Cython 版本： https://newreleases.io/project/github/nautechsystems/nautilus_trader/release/v1.231.0
- NautilusTrader 安裝/精度文件： https://nautilustrader.io/docs/latest/getting_started/installation/
- NautilusTrader 概念總覽： https://nautilustrader.io/docs/latest/concepts/overview/
- QuantConnect LEAN 儲存庫： https://github.com/QuantConnect/Lean
- LEAN Python 設定（Python 3.11、pythonnet）： https://github.com/QuantConnect/Lean/blob/master/Algorithm.Python/readme.md
- QuantConnect.pythonnet NuGet（LEAN master 引用 2.0.66）： https://www.nuget.org/packages/QuantConnect.pythonnet/
- LEAN `SecurityType` 列舉（無債券類型）： https://github.com/QuantConnect/Lean/blob/master/Common/Global.cs
- NautilusTrader PyPI 發行歷史（最新已發布的 RC）： https://pypi.org/project/nautilus-trader/#history
- NautilusTrader v2 `pyproject.toml`（授權為 `LGPL-3.0-only`）： https://github.com/nautechsystems/nautilus_trader/blob/master/python/pyproject.toml
- NautilusTrader `Price` 上下限（`PRICE_MAX`）： https://github.com/nautechsystems/nautilus_trader/blob/master/crates/model/src/types/price.rs
- Python 下載 / 發行狀態： https://www.python.org/downloads/
- Python devguide，支援中的版本（3.13 僅提供安全性修補）： https://devguide.python.org/versions/
- PEP 803（`abi3t`，CPython 3.15+）： https://peps.python.org/pep-0803/
- pandas 3.0 發行說明（datetime 解析度推斷）： https://pandas.pydata.org/docs/whatsnew/v3.0.0.html
- Python 3.15.0 rc3 公告： https://blog.python.org/2026/10/python-3150-rc3/
- Python 自由執行緒 HOWTO（3.14）： https://docs.python.org/3.14/howto/free-threading-python.html
- PEP 779 解說： https://pydevtools.com/handbook/explanation/what-is-pep-779/
- 自由執行緒相容性追蹤： https://py-free-threading.github.io/tracking/
- Python `datetime` 文件： https://docs.python.org/3/library/datetime.html
- PyO3 發行版本（0.29）： https://github.com/PyO3/pyo3/releases
- Numba 0.65.0 發行說明： https://numba.readthedocs.io/en/latest/release/0.65.0-notes.html
- Numba 0.63.0 發行說明： https://numba.readthedocs.io/en/stable/release/0.63.0-notes.html
- Numba 0.68.0 發行說明（Python 3.15）： https://numba.readthedocs.io/en/stable/release/0.68.0-notes.html
- Cython 自由執行緒指南： https://cython.readthedocs.io/en/latest/src/userguide/freethreading.html
- Rust 部落格（1.99.0）： https://blog.rust-lang.org/
- `rust_decimal` 文件： https://docs.rs/rust_decimal/latest/rust_decimal/
- Jiff： https://github.com/BurntSushi/jiff
- Herb Sutter，"C++26 is done!"： https://herbsutter.com/
- .NET 10 公告： https://devblogs.microsoft.com/dotnet/announcing-dotnet-10/
- .NET 支援政策（終止支援日期）： https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core
- .NET 11 RC1 新聞： https://visualstudiomagazine.com/articles/2026/09/14/net-11-rc1-gets-go-live-support-ahead-of-november-launch.aspx
- .NET `DateTime.Ticks`： https://learn.microsoft.com/en-us/dotnet/api/system.datetime.ticks
- .NET `Decimal`： https://learn.microsoft.com/en-us/dotnet/api/system.decimal
- Oracle Java 27 新聞稿： https://www.oracle.com/sg/news/announcement/oracle-releases-java-27-and-strengthens-post-quantum-cryptography-support-2026-09-15/
- OpenJDK ZGC： https://openjdk.org/projects/zgc/
- Java `Instant`： https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/time/Instant.html
- Go 1.26 發行說明（Green Tea GC）： https://go.dev/doc/go1.26
- Go 1.27 發行說明： https://go.dev/doc/go1.27
- Go 發行歷史： https://go.dev/doc/devel/release
- Julia 下載： https://julialang.org/downloads/manual-downloads/
- Stack Overflow 2025 開發者調查，技術： https://survey.stackoverflow.co/2025/technology
- hftbacktest： https://github.com/nkaz001/hftbacktest
- `exchange_calendars`： https://github.com/gerrymanoim/exchange_calendars
- TAIFEX TX 規格： https://www.taifex.com.tw/enl/eng2/tX
- TAIFEX TXO 規格： https://www.taifex.com.tw/enl/eng2/tXO
- TWSE 交易制度： https://www.twse.com.tw/en/page/products/trading/introduce.html
- Shioaji 文件： https://sinotrade.github.io/
- Fubon Neo API： https://www.fbs.com.tw/TradeAPI/en/
- EIP-20（ERC-20）： https://eips.ethereum.org/EIPS/eip-20
- 美國公債（32 分位報價）： https://en.wikipedia.org/wiki/United_States_Treasury_security
- Tauri 2： https://v2.tauri.app/
- `tauri` crate 版本（2.12.1 穩定版、3.0.0-alpha.4）： https://crates.io/crates/tauri

## 查證紀錄（2026-10）

於 2026-10-05 以主要來源進行對抗式事實查核：官方文件、PyPI/crates.io/NuGet 中繼資料、GitHub 儲存庫檔案與發行頁面。共查核 51 項陳述：34 項確認無誤、14 項已更正或補充、3 項無法查證。

### 已確認

- NautilusTrader v1.231.0（2026-08-02）預定為最後一個 1.x/Cython 版本。`develop` 轉為僅支援 v2，而 `develop_v1` 在切換後約三個月內接收重大安全性修補回移（newreleases.io 發行說明；PyPI 上傳日期 2026-08-02）。
- NautilusTrader 支援 Linux x86_64/ARM64、macOS ARM64 與 Windows x86_64 上的 Python 3.12–3.14。提供 128 位元（16 位小數）與 64 位元（9 位小數）兩種精度模式。標準模式約快 3–5%，標準模式下 `PRICE_MAX` 約為 ±92 億，Linux 需要 glibc 2.35+（PyPI、README、安裝文件、`price.rs`）。
- NautilusTrader 核心的事件迴圈在呼叫端執行緒上執行，非同步 I/O 則在 Tokio runtime 上執行（概念總覽）。
- LEAN 採 Apache-2.0 授權，目標框架為 `net10.0`（.NET 10 SDK），並透過 QuantConnect 的 pythonnet 分支執行 Python 3.11（README、`QuantConnect.csproj`、`DockerfileLeanFoundation`、Algorithm.Python readme）。
- Python 3.15.0rc3 於 2026-10-02 發布，正式版因 lazy-import 相關的發布阻斷問題（release blocker）延至 2026-10-09。目前版本為 3.14.8（2026-09-30）（blog.python.org、python.org）。
- 3.15 的 JIT 加速在 x86-64 Linux 上約 7–8%，在 AArch64 macOS 上約 11–12%（3.15.0rc3 公告）。
- 自由執行緒在 3.14 中獲正式支援但屬選用（PEP 779，Final）。額外開銷約為 1%（macOS aarch64）至 8%（x86-64 Linux），非 FT 的 C 擴充模組會重新啟用 GIL，且在 AMD64 上 `None` 佔 32 位元組而非 16 位元組（free-threading HOWTO）。
- PyO3 0.29.0（2026-06-11）加入 Python 3.15 與 `abi3t`（GitHub releases、crates.io）。
- Numba 0.63.0（2025-12-08）加入 3.14，0.65.0（2026-03-31）加入 3.14t。0.65 中 SVML 仍不受支援（發行說明）。
- Cython 的自由執行緒支援仍為實驗性（Cython 文件）。
- Rust 1.99.0 於 2026-10-01 發布（Rust 部落格）。
- .NET 10 於 2025-11-11 以 LTS 版本發布（公告）。.NET 11 RC1 於 2026-09-08 開放正式上線使用（.NET releases index）。
- `System.Int128` 自 .NET 7 起即已存在（Microsoft Learn）。
- Go 1.26 將 Green Tea GC 設為預設，預期 GC 開銷可降低 10–40%。Go 1.27.0 於 2026-08-19 發布（go.dev）。
- .NET `DateTime` 的一個 tick 為 100 ns（Microsoft Learn）。
- C++26 於 2026-03-29 完成技術定案，目前處於 DIS 投票階段（herbsutter.com）。
- JEP 490 在 JDK 24 中移除了非分代式 ZGC，因此 Java 25 LTS 僅有分代式 ZGC。JDK 27 於 2026-09-15 GA。ZGC 宣稱「最大暫停時間低於 1 毫秒」（sub-millisecond max pause times）（openjdk.org）。
- Julia 1.13.1 於 2026-09-25 發布，LTS 為 1.10.12（julialang.org）。
- Stack Overflow 2025 全體受訪者的使用率：Python 57.9%（+7 個百分點）、Rust 14.8%、C# 27.8%、C++ 23.5%、Java 29.4%、Kotlin 10.8%、Go 16.4%（調查頁面）。
- 目前的 crate 版本：`rust_decimal` 1.43.0（2026-09-02）與 `jiff` 0.2.37，後者仍未達 1.0（crates.io）。
- `exchange_calendars` 涵蓋 50 多個交易所並包含 XTAI，但沒有 TAIFEX 行事曆（GitHub README）。
- TAIFEX TX 盤後交易時段為 15:00 至次日 05:00。TXO 乘數為 NT$50，跳動單位從 0.1 點（10 點以下）至 10 點（1,000 點以上）（TAIFEX 規格頁面）。
- TWSE：±10% 漲跌幅限制、分級跳動單位，以及盤中零股交易（TWSE 交易制度）。
- Shioaji 提供原生 Python binding，並為其他語言提供 HTTP API（以及 CLI）。Fubon Neo 提供 Python/C#/Node.js SDK，交易另有 C++/Go，支援 Windows/macOS/Linux（廠商文件）。
- Tauri 2 支援 Linux、macOS、Windows、Android 與 iOS（v2.tauri.app）。

### 已更正或補充

| 原始內容 | 更正 | 來源 |
|---|---|---|
| 「最新版本為 2.0.0rc6（2026-10-04）」；NautilusTrader「已全面採用」v2 | rc6 在 master 的 `RELEASES.md`/`version.json` 中標示的日期為 2026-10-04，但截至 2026-10-05，PyPI 與 GitHub tags 上最新的 RC 是 2.0.0rc5（2026-09-15）。Nautech 套件索引只有 `2.0.0rc6.devYYYYMMDD` 開發版 wheel。PyPI 上最新的穩定版仍為 1.231.0，因此 v2 需要 `--pre` | https://pypi.org/project/nautilus-trader/#history ; https://github.com/nautechsystems/nautilus_trader/tags |
| NautilusTrader「LGPL-3.0-or-later」 | 這僅適用於 v1.x。v2（`python/pyproject.toml`、`Cargo.toml`、rc5 的 PyPI 中繼資料）宣告為 `LGPL-3.0-only` | https://github.com/nautechsystems/nautilus_trader/blob/master/python/pyproject.toml |
| .NET 10「支援至 2028-11-10」 | 官方支援政策與 `releases-index.json` 列出的終止支援日為 **2028-11-14**（Patch Tuesday）。公告部落格中的「2028 年 11 月 10 日」與該政策不一致 | https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core |
| i128 模式「約 ±17 千兆（quadrillion）」、「官方 wheel 的預設」 | `PRICE_MAX` = 17,014,118,346,046，亦即**約 ±17 兆**。128 位元是 v2 wheel 在所有平台上的預設，但 v1.x 的 Windows wheel 僅有 64 位元 | `crates/model/src/types/price.rs`；NautilusTrader README / PyPI |
| 非 FT 的 C 擴充模組會「無聲地」重新啟用 GIL | 發生這種情況時，CPython 會印出警告 | https://docs.python.org/3.14/howto/free-threading-python.html |
| 使用「Python 3.13/3.14」；「待關鍵 wheel 可用後再鎖定 3.14」 | 3.13 現已僅提供安全性修補（不再發布二進位檔），且關鍵 wheel 已支援 3.14。建議使用 3.14 | https://devguide.python.org/versions/ |
| LEAN 綁定 Python 3.11（未提及生命週期背景） | 3.11 僅提供安全性修補，將於 2027-10 終止支援，對 LEAN 使用者構成中期風險 | https://devguide.python.org/versions/ |
| Numba：引用的最新版本為 0.65 | 最新版本為 0.68.0（2026-09-30），加入了 Python 3.15 | https://numba.readthedocs.io/en/stable/release/0.68.0-notes.html |
| CI：「abi3t 用於自由執行緒」 | `abi3t`（PEP 803）只能以 CPython 3.15+ 為目標。3.14t 需要各版本專屬的 `cp314t` wheel | https://peps.python.org/pep-0803/ |
| QuantConnect.pythonnet NuGet 2.0.64 | LEAN master 引用的是 2.0.66 | `Common/QuantConnect.csproj`；NuGet |
| Python 時間陷阱只列出 µs 的 `datetime` 與 ns 範圍 | pandas 3.0+ 會從字串/`datetime` 推斷為 `datetime64[us]`，因此轉為整數會得到 µs（小 1000 倍）。請明確使用 `unit="ns"` | https://pandas.pydata.org/docs/whatsnew/v3.0.0.html |
| 推薦用於包含債券在內之多資產的引擎，卻未附任何但書 | LEAN 沒有債券的 `SecurityType`。NautilusTrader 有 `Bond` 商品類別，但沒有固定收益分析功能。已補充說明需規劃獨立的定價函式庫 | `Common/Global.cs`（LEAN）；`crates/model/src/enums.rs`（NautilusTrader） |
| Go 以「1.27.0」作為目前狀態 | 最新修補版為 1.27.1（2026-09-01） | https://go.dev/doc/devel/release |
| 推薦 Tauri 2，未列出替代方案 | Tauri 2.12.1 為目前版本，且已有 3.0.0-alpha.4（未來需進行主要版本遷移）。已補充 React Native/Flutter（行動裝置）與 Avalonia/.NET MAUI（若核心為 .NET）的簡短說明 | https://crates.io/crates/tauri |

### 無法查證

- TAIFEX 盤後交易的成交歸屬於*下一個*交易日結算的確切規則。規格頁面僅確認 15:00–05:00 的交易時段，在實作行事曆服務之前，應對照 TAIFEX 交易規則確認此規則。
- Numba 0.66–0.68 是否仍不支援 Intel SVML。0.68.0 的發行說明未提及此事，僅能確認至 0.65 為止。
- Stack Overflow 2025 語言表格中的「Julia：未列入」。該頁面僅在自行填寫（write-in）的項目中列出 Julia，沒有可比較的百分比。
