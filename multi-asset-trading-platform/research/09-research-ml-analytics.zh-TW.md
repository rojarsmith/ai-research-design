[English](09-research-ml-analytics.md) | **繁體中文**

# 研究環境、量化分析、AI/ML 與績效分析

> 研究快照日期：2026-10-05。版本與日期取自當日查核的 PyPI 與專案頁面（見參考資料）。在鎖定（pin）相依套件之前，請重新確認。

## TL;DR

- **建立在 Arrow 原生（Arrow-native）工具之上。** 以 Parquet 儲存資料，以 DuckDB 處理 SQL 與 as-of join，以 Polars 進行轉換，pandas 3.0 則只留在函式庫邊界使用。三個「reloaded」版 Quantopian 套件（`zipline-reloaded`、`alphalens-reloaded` 與 `pyfolio-reloaded`）仍要求 `pandas<3.0`，Nixtla 的 `statsforecast`/`mlforecast`/`utilsforecast` 以及台灣的 `FinMind` 用戶端也一樣。請在獨立的舊版（legacy）環境中執行它們，或自行重新實作所需的少數指標。
- **投資組合建構與分析。** 使用 skfolio（scikit-learn 風格的 API，內建 purged/combinatorial 交叉驗證）搭配 cvxpy。需要其豐富的風險度量時，再加入 Riskfolio-Lib。PyPortfolioOpt 屬於「成熟」狀態（不再有重大新功能），但目前已改由 PyPortfolio GitHub 組織共同維護，1.6.0 也加入了 pandas 3 支援。QuantStats 自 2025 年中起再度活躍（最新版 0.0.86，2026 年 9 月），很適合產出 tear sheet（績效報表），但請以自己經過測試的指標模組作為唯一可信來源（source of truth）。
- **ML。** 以經過特徵工程、具時點正確性（point-in-time）的特徵訓練梯度提升樹，仍是主力。時間序列基礎模型（TSFM）適合作為基準模型，以及用於波動率、成交量或共變數預測。它們不是 alpha 引擎：2025–26 年的研究發現，零樣本（zero-shot）TSFM 在報酬預測上不是表現較差，就是只帶來微小而零星的增益。最新、排名居首的權重也禁止商業使用（TimesFM 3.0 為非商業授權；Moirai 2.0 為 CC-BY-NC）。
- **MLOps。** 自行架設 MLflow（Apache-2.0），作為實驗登錄庫（experiment registry），也作為 Deflated Sharpe Ratio 等過度擬合統計量所需的試驗次數計數器。以不可變的 Parquet 快照或 DVC 為資料做版本控管。請注意，lakeFS 已於 2026 年 9 月改採 Business Source License（BSL）：只允許未經修改的版本用於內部生產環境，因此它不能放在為組織外部人員提供服務的生產系統之中。
- **LLM 與 GPU。** 只給 LLM 唯讀的 MCP 資料與申報文件工具，並在沙箱中執行 AI 撰寫的策略程式碼。LLM 只產出*提案*。只有確定性的風控引擎加上人工核准，才能觸及訂單管理系統（OMS）。GPU dataframe（RAPIDS cuDF、Polars GPU 引擎）只有在處理 tick 資料、選擇權曲面資料與深度模型時才划算。它們需要 Linux 或 WSL2，且 RAPIDS 26.08 鎖定較舊的 pandas（`<3.0.4`）與 Polars（`<1.43`）版本。

## 關鍵問題

1. 哪一種 notebook/IDE 與 dataframe 技術堆疊能產出可重現的研究，而且不必重寫就能成為正式環境程式碼？
2. 截至 2026 年底，哪些因子與投資組合函式庫仍有人維護，並且相容於 pandas 3？
3. ML（包括基礎模型與 LLM）在金融領域中，哪些地方能帶來可衡量的價值，哪些地方大多只是炒作？
4. 我們如何追蹤實驗、資料與模型版本，讓試驗次數可知、結果可重現？
5. 我們如何讓 AI 助理提供協助，同時絕不給它們任何下單的途徑？
6. 在研究、回測、模擬交易（paper trading）與實盤交易之間，應設置哪些過度擬合控管與晉級關卡（promotion gate）？
7. GPU 加速值得它所帶來的平台限制嗎？

## 選項比較

### 1. 研究環境

| 工具 | 狀態（2026 年 10 月） | 授權 | 優勢 | 劣勢 | 最適用情境 |
|---|---|---|---|---|---|
| JupyterLab | 4.6.4（2026 年 9 月） | BSD-3 | 生態系最大；JupyterHub 支援多使用者；可使用任何 kernel | `.ipynb` JSON 的 diff 難以閱讀；存在隱藏的亂序執行狀態 | 探索性分析；團隊共用 hub |
| VS Code notebooks | 每月發布 | 免費（Code-OSS 為 MIT） | 與正式環境程式碼使用同一個編輯器、除錯器與 AI 助理 | 同樣有 `.ipynb` 隱藏狀態問題 | 同時身兼工程師的個人開發者 |
| marimo | 0.25.1（2026 年 10 月 1 日）；團隊已加入 CoreWeave（2025 年 10 月 30 日）並維持開源 | Apache-2.0 | 反應式資料流圖（reactive dataflow graph）代表沒有隱藏狀態。Notebook 是純 `.py` 檔案：可用 git diff、可作為腳本執行、可作為 app 提供服務 | 生態系較新；耗時的 cell 除非加上防護，否則會被反應式地重新執行 | 可重現的研究 notebook 與內部儀表板 |
| Positron（Posit） | 2026.09 | Elastic License 2.0（原始碼公開，source-available） | 資料瀏覽器；Python 與 R 整合於單一 IDE | ELv2 禁止將其作為託管服務提供 | 混用 R 與 Python 的團隊 |

### 2. Dataframe 與查詢引擎

| 引擎 | 最新版 | 模型 | 優勢 | 劣勢 | 角色 |
|---|---|---|---|---|---|
| pandas 3.0 | 3.0.0（2026 年 1 月 21 日），目前為 3.0.6（2026 年 9 月 17 日）；3.1.0rc0 於 2026 年 9 月 30 日推出 | Eager（立即執行），NumPy/Arrow | 普遍的互通性。Copy-on-Write 現在是*唯一*模式。預設 `str` dtype（已安裝 PyArrow 時以其為後端）。Datetime 不再強制使用奈秒精度 | 破壞鏈式賦值（chained assignment）；許多量化函式庫鎖定 `<3`；單執行緒 | 函式庫邊界格式、小型資料 |
| Polars | 1.44.2（2026 年 9 月）；2.0.0rc2 於 2026 年 9 月 20 日推出 | Lazy/eager、Rust、多執行緒、串流 | `join_asof` 與滾動視窗速度快；記憶體用量低；GPU 引擎（beta） | API 在次要版本之間仍會變動，且 2.0 主要版本即將推出；GPU 引擎（`cudf-polars` 26.08）要求 `polars<1.43`；能原生接受它的金融函式庫較少 | 與正式環境共用的特徵工程與訊號程式碼 |
| DuckDB | 1.5.6（2026 年 9 月 28 日）；2.0.0 預定於 2026 年 10 月 21 日推出（暫定）；1.5 於 2026 年 11 月 1 日終止支援（end of life）；1.4 LTS 社群支援至 2026 年 11 月 17 日 | 嵌入式 SQL OLAP | 直接就地查詢 Parquet/Iceberg；`ASOF JOIN`；可處理大於記憶體的資料；不需要伺服器 | 單節點；只能有一個寫入程序 | 研究查詢層、本地資料湖、臨時（ad hoc）SQL |
| Ibis | 12.0.0（2026 年 2 月） | 可攜式運算式 API | 單一 API 可編譯至 DuckDB、Polars、Postgres、Spark、BigQuery 等 | 多一層抽象；發布節奏較慢 | 預期會從本地 DuckDB 遷移到資料倉儲的團隊 |

### 3. 因子研究與投資組合建構

| 函式庫 | 最新版（日期） | 授權 | 功能 | 維護狀態與相容性 |
|---|---|---|---|---|
| Alphalens-reloaded | 0.4.6（2025 年 6 月） | Apache-2.0 | 因子 IC、分位數報酬、週轉率 tear sheet | 要求 `pandas<3.0`；自 2024 年 9 月以來只有一次 commit |
| Microsoft Qlib | `pyqlib` 0.9.7（2025 年 8 月 15 日） | MIT | 端到端 ML 因子管線（Alpha158/360 特徵、模型庫、回測器）；RD-Agent 用於 LLM 驅動的因子挖掘 | 仍持續有 commit（最近一次為 2026 年 9 月），但已超過 13 個月未發布新版；資料以中國與美國為主；框架龐大。獨立的 RD-Agent 專案（MIT）已於 2026 年 9 月 23 日達到 1.0.0 |
| cvxpy | 1.9.3（2026 年 9 月） | Apache-2.0 | 通用凸最佳化建模 | 模型需自行撰寫；正式投資組合通常需要商用求解器 |
| Riskfolio-Lib | 7.4.0（2026 年 10 月 4 日） | BSD-3 | 極為廣泛的風險度量（CVaR、CDaR、EVaR …）、HRP/HERC、Black-Litterman | 活躍；API 範圍龐大；基本上只有一位維護者 |
| PyPortfolioOpt | 1.6.0（2026 年 2 月 26 日） | MIT | 均值-變異數、Black-Litterman、HRP、離散配置 | Roadmap 仍稱其為「成熟」（不再有重大新功能）。Repo 已移至 PyPortfolio GitHub 組織並有新的共同維護者；1.6.0 加入 pandas 3 與 Python 3.14 支援 |
| skfolio | 1.4.11（2026 年 10 月 3 日） | BSD-3 | 相容 scikit-learn 的估計器；具 purge 與 embargo 的 `CombinatorialPurgedCV`；walk-forward 驗證；超參數搜尋 | 活躍；最適合以 ML 風格驗證資產配置 |

### 4. 績效分析

| 選項 | 最新版 | 授權 | 備註 |
|---|---|---|---|
| QuantStats | 0.0.86（2026 年 9 月 27 日） | Apache-2.0 | 2023 年 7 月至 2025 年 7 月處於停滯，之後復甦（2025 年 7–9 月推出 0.0.64–0.0.77，2026 年 1 月推出 0.0.78–0.0.81）。0.0.82–0.0.86 於 2026 年 9 月 26–27 日發布，包含「統計修正」（交易統計、滾動 Sharpe/Sortino、回撤、無風險利率處理），因此指標定義已有變動：請鎖定版本。其 HTML tear sheet 很適合用於報告 |
| quantstats-lumi | 1.1.5（2026 年 6 月） | Apache-2.0 | Lumiwealth 的 fork，於 QuantStats 停滯期間建立 |
| pyfolio-reloaded / empyrical-reloaded | 0.9.9 / 0.5.12（2025 年 6 月） | Apache-2.0 | pyfolio 要求 `pandas<3`；empyrical 則沒有。自 2025 年中以來活動甚少 |
| 自建指標模組（Polars） | 不適用 | 不適用 | **建議作為唯一可信來源**：Sharpe/Sortino/回撤/週轉率，以及 probabilistic Sharpe ratio 與 deflated Sharpe ratio，並針對參考值進行單元測試。上述函式庫僅用於呈現 |

### 5. ML 技術堆疊與時間序列基礎模型

核心技術堆疊全部採用寬鬆授權，且皆為最新版本：scikit-learn 1.9.1、LightGBM 4.7.0、XGBoost 3.4.1、PyTorch 2.14.1、Optuna 5.0.0、statsmodels 0.15.0、arch 8.0.0（GARCH 模型；NCSA 授權），以及 Nixtla statsforecast 2.1.1/neuralforecast 3.2.2。注意事項：`statsforecast`、`mlforecast` 1.1.0 與 `utilsforecast` 0.2.16（neuralforecast 的相依套件）全都宣告 `pandas<3.0`，因此 Nixtla 技術堆疊目前應放在舊版（pandas 2.3）環境中。對於雜訊多的表格型金融特徵，梯度提升樹在成本與準確度的取捨上仍是最強的預設選擇。深度序列模型需要多得多的資料與更強的正則化。

| 基礎模型 | 發布 | 規模 | 權重授權 | 金融應用備註 |
|---|---|---|---|---|
| TimesFM 2.5（Google） | 2025 年 9 月 | 200M 參數，16k context | Apache-2.0 | 在通用基準測試上表現強勁；單變量 |
| TimesFM 3.0（Google） | 2026 年 8 月 | ≈331M（Hugging Face 權重中繼資料） | **非商業、非生產用途**；僅能透過 Google Cloud（BigQuery ML）用於生產環境 | 原生支援多變量與共變數；據 Google 表示，在 fev-bench、TIME 與 GIFT-Eval 皆排名第一 |
| Chronos-2（Amazon） | 2025 年 10 月 20 日 | 120M | Apache-2.0 | 零樣本的單變量、多變量與共變數輔助預測；可在 CPU 或 GPU 上執行 |
| Moirai 2.0（Salesforce） | 權重 2025 年 8 月；論文 2025 年 11 月 | small 版本（`moirai-2.0-R-small`） | **CC-BY-NC-4.0**，僅限研究 | `uni2ts` 2.0.0 鎖定 `torch<2.5` 與 `numpy~=1.26`，因此需要隔離的環境 |
| Kronos | arXiv 2025 年 8 月；AAAI 2026 | 4.1M–102M 開放；499M 未釋出 | MIT | 金融原生：以 tokenized 的 OHLCV（K 線，candlestick）資料訓練，資料來自 45 個以上交易所 |

**證據顯示：**
- Rahimikia、Ni 與 Wang（2025 年 11 月）進行了首個大規模 TSFM 研究，涵蓋 94 個國家、34 年的每日超額報酬。現成的 TSFM（Chronos、TimesFM）無論是零樣本或經過微調後，都「表現不佳」（perform poorly）。從頭以金融資料預訓練的模型則表現好得多。請注意，該研究測試的是較早的世代（原版 Chronos、最大 500M 的 TimesFM），而非 Chronos-2、TimesFM 2.5 或 3.0。
- Noguer i Alonso 與 Franklin（2026 年 6 月）測試了五檔高流動性的美國股票。預訓練 TSFM（包括較新的 Moirai 2.0 與 TimesFM 2.5）在 10 項任務中有 8 項勝過神經網路基準模型，但相對於隨機漫步的增益「微小且零星」（small and sparse）。

**TSFM 適用於：**
- 基準模型；
- 預測波動率、成交量與流動性；
- 總體經濟或共變數的即時預測（nowcast）；
- 資料量少的團隊。

不要將它們直接當作報酬訊號。

### 6. 實驗追蹤、資料與模型版本控管、特徵儲存庫（feature store）

| 工具 | 最新版 | 授權／所有權 | 優勢 | 注意事項 |
|---|---|---|---|---|
| MLflow | 3.16.1（2026 年 9 月） | Apache-2.0，可自行架設 | Runs、模型登錄庫、LLM/agent 追蹤；自 3.13（2026 年 5 月）起提供 workspace 角色型存取控制（RBAC）；自 3.15 起提供 MCP 伺服器登錄庫 | 需自行維運；深度學習 sweep 的 UI 不如 W&B |
| Weights & Biases | SaaS | 現為 CoreWeave 旗下（「Forge」） | sweep 與深度學習的 UI 最佳。免費方案：最多 5 個席次與 5 GB 儲存空間。Pro 方案每月 60 美元起（最多 10 個席次；僅限員工少於 50 人的團隊） | 除非購買 Enterprise 方案，否則資料會離開你的場域；有供應商整併風險 |
| DVC | 3.67.1（2026 年 3 月） | Apache-2.0；已被 lakeFS 收購（2025 年 11 月 18 日）並維持開源 | 以 Git 為基礎、指向物件儲存中資料的指標；輕量，適合小型團隊 | 用於超大型、頻繁追加的 tick 資料時不太順手 |
| lakeFS | v1.87.0+（最新為 v1.88.0，2026 年 10 月 1 日） | **已從 Apache-2.0 改為 BSL（2026 年 9 月 22 日）**：生產使用僅限*未經修改*的發布版本，且僅限於你組織的內部用途。你不得將 lakeFS 或其功能提供給第三方，且供應商的指引表示它不能在「為組織外部任何人提供服務的生產系統中」執行。v1.86.0 及以前的版本維持 Apache-2.0；每個 BSL 版本會在 4 年後轉為 Apache-2.0 | 在物件儲存之上提供 Git 風格的分支與 commit；可將 agent 與正式環境資料隔離 | 會阻擋「將平台提供給他人」的情境，除非你購買商業授權、停留在 v1.86.0（不會再有後續修正），或改用 Iceberg 快照/DVC |
| Feast | 0.66.0（2026 年 8 月） | Apache-2.0 | 具時點正確 join 的線上與離線特徵服務 | 要求 `pandas<3`；除非低延遲的線上特徵需要在多個模型之間共用，否則殺雞用牛刀 |

### 7. LLM 與 agent 整合

| 使用情境 | 建議模式 | 工具（2026） |
|---|---|---|
| 將申報文件與新聞轉為結構化事件 | 擷取至具型別的 schema（事件、實體、日期、信心度）；連同模型版本與 prompt 雜湊值一併儲存；由人工抽查 | `edgartools` 5.60（MIT；內建 MCP 伺服器；可解析 10-K/10-Q/8-K、13F、Form 4、XBRL）。台灣：公開資訊觀測站（Market Observation Post System, MOPS）申報資料與月營收；FinMind（程式碼為 Apache-2.0；資料僅供教育、非商業用途；每小時 300 次請求，使用 token 則為 600 次；2.0.11 版 Python 用戶端要求 `pandas<3`） |
| 情緒訊號 | 批次評分並快取結果；將公司名稱匿名化，以降低前視偏誤與「分心」偏誤（Glasserman & Lin）；只回測模型訓練截止日*之後*的期間 | 追求品質時使用託管 LLM；低成本大量評分時使用經微調的小型 encoder |
| 提供給 AI 助理的市場資料 | **唯讀** MCP 伺服器；為每個工具配發限定範圍的 API key | Massive（前身為 Polygon.io）MCP 伺服器：僅提供資料（股票、選擇權、外匯、加密貨幣、期貨、美國公債殖利率）。另有一個以 DuckDB 為後端、架在資料湖之上的自建 MCP 伺服器 |
| 券商 MCP 伺服器 | 僅限模擬帳戶，並置於獨立的沙箱中 | Alpaca MCP server V2（2.3.2）*可以下達實盤的股票、加密貨幣與多腳（multi-leg）選擇權委託*。它預設為模擬交易（`ALPACA_PAPER_TRADE=true`）。當助理應為唯讀時，使用 `ALPACA_TOOLSETS` 只開放資料類工具集（排除 `trading`）。絕不可將實盤憑證載入 LLM 用戶端 |
| AI 輔助撰寫策略程式碼 | LLM 依據具型別的策略 SDK 撰寫程式碼。程式碼在無網路、無憑證的容器中執行。必須通過 CI、回測關卡與人工程式碼審查 | 程式撰寫 agent、以 MLflow 追蹤 agent 工作階段；Qlib RD-Agent 用於自動化因子挖掘 |

**護欄（不可妥協）：**
- LLM 永遠不持有 OMS 或券商憑證。它的輸出是一份*交易提案*，和任何策略一樣須經過同一個交易前風控引擎，再交由人工核准。
- 這些控管措施遵循 OWASP LLM01:2025（最小權限，以及對特權操作採取人機協作（human-in-the-loop））與 2026 年 FINRA 報告；該報告警告 agent 可能會「超出使用者實際或預期的範圍」（beyond the user's actual or intended scope）行事。
- 將所有擷取到的新聞、申報文件與網頁文字，視為可能含有 prompt injection 的不可信輸入。將擷取工具與行動工具分開。
- 遵循 MCP 安全性最佳實務：不做 token 直通（token passthrough）、最小化權限範圍、將本地伺服器沙箱化，以及逐一向每個用戶端取得同意。
- 為了稽核與可重現性，記錄每一個 prompt、工具呼叫與輸出。
- 在將有授權限制的市場資料傳送給第三方 LLM API 之前，先確認資料供應商的授權條款。

### 8. GPU 加速

| 工作負載 | CPU（Polars/DuckDB） | GPU 值得嗎？ |
|---|---|---|
| 日線資料，約 5k 檔股票 × 20 年（≈25M 列） | 數秒 | 否 |
| 分鐘線資料，多資產特徵工程 | 使用 lazy/串流執行即可 | 效益有限；需要時再租用 GPU |
| Tick/L2 資料、完整選擇權鏈與隱含波動率曲面 | I/O 與記憶體密集 | **是**，但常受限於 I/O |
| 深度模型、TSFM 微調 | 不切實際 | **是**（PyTorch） |
| 大型面板資料上的 GBDT | CPU 上的 LightGBM 即可 | 規模大時，GPU 上的 XGBoost 有幫助 |

**結論背後的事實：**
- RAPIDS cuDF 26.08（2026 年 8 月）可在 Linux 上執行；在 Windows 11 上則只能透過 WSL2，且僅支援單一 GPU。RAPIDS 列出的需求為 Volta 或更新的 GPU（compute capability 7.0+），以及 CUDA 12 或 13。CUDA 13 本身的函式庫（例如 cuFFT 與 cuSPARSE）已不再支援 Turing 之前的 GPU，因此請以 Turing 或更新的 GPU 做規劃，或在 Volta 上使用 CUDA 12 版本。
- `cudf.pandas` 提供無須修改程式碼的加速，並可退回 CPU 執行，但 cuDF 26.08 鎖定 `pandas>=3.0.0,<3.0.4`。這排除了目前的 pandas 3.0.4–3.0.6，並使你的 pandas 版本與 RAPIDS 綁在一起。
- Polars GPU 引擎處於公開 beta：允許退回 CPU 時通過 99.2% 的 Polars 測試，不允許時則為 88.8%。重新取樣（resampling）與使用者自訂函式會退回 CPU 執行。其後端（`cudf-polars` 26.08）要求 `polars>=1.35,<1.43`，因此 GPU 映像檔無法使用目前的 Polars 1.44.x。

**結論：** 不要圍繞 GPU dataframe 來設計平台。針對選擇權曲面、tick 與深度模型工作，依需求租用 GPU。

### 9. 四種資產類別在此面向的差異

| 面向 | 股票 | 加密貨幣 | 債券 | 選擇權 |
|---|---|---|---|---|
| 研究單位 | 在時點正確的標的池（universe）上進行橫斷面因子分析 | 依交易場所/交易對的時間序列訊號，加上跨代幣的橫斷面因子 | 殖利率曲線因子（水準、斜率、曲率）、利差、carry/roll | 波動率曲面（履約價 × 到期日 × 時間）、Greeks |
| 主要資料陷阱 | 存活者偏誤、公司行動（corporate actions）、申報延遲 | 24/7 交易代表必須自行定義每日收盤（例如 00:00 UTC）；交易場所分散；已下市或遭捲款跑路（rug pull）的代幣；歷史資料短 | 商品會到期，因此沒有連續序列；店頭市場（OTC）報價稀疏；應計利息 | 資料量龐大；過時報價；提前履約與指派；到期效應 |
| 分析函式庫 | Alphalens、Qlib、skfolio | 以 Polars/DuckDB 處理交易所資料，再加上資金費率與鏈上特徵 | QuantLib 1.43（BSD-3）：殖利率曲線、存續期間與凸性 | QuantLib；py_vollib 1.0.12 用於隱含波動率與 Greeks；GPU 在此有幫助 |
| ML 適用性 | 最為人所熟知；基準是以因子訓練的梯度提升 | 雜訊高且有市場狀態轉換（regime shift）；保持模型簡單並經常重新訓練 | 主要為利率與殖利率曲線建模；單一債券層級的 ML 很少 | 波動率預測（GARCH、TSFM）比方向預測更可行 |
| 績效分析 | 以報酬為基礎的指標（QuantStats）適用 | 每小時按市值計價（mark-to-market）；納入手續費與資金費率 | 經存續期間調整；區分 carry 與價格報酬 | 以保證金為基礎的報酬與 Greeks 損益歸因；單純以報酬為基礎的 tear sheet 會造成誤導 |
| 台灣備註 | 證交所/櫃買中心（TWSE/TPEx）±10% 每日漲跌幅限制（新上市股票前五個交易日無漲跌幅限制）；月營收、三大法人與融資融券資料是獨特訊號；資料來自 FinMind 或 TEJ（TQuant Lab 建構於 zipline、pyfolio 與 alphalens 之上，且 FinMind 用戶端同樣鎖定 `pandas<3`，因此預期會受到 pandas-2 限制） | 本地交易所受金融監督管理委員會（FSC，金管會）監管；研究資料以全球交易場所為主 | 本地次級市場交易清淡；主要為公債殖利率曲線 | 臺灣期貨交易所（TAIFEX）臺指選擇權（TXO），包括週三與週五到期的週選擇權系列；盤後交易時段（15:00 至次日 05:00）使「每日」K 棒的邊界變得複雜 |

## 建議

### (a) 個人或 1–3 人 MVP

| 層級 | 選擇 | 理由 |
|---|---|---|
| 環境 | VS Code（或 Positron），任何必須重新執行的 notebook 則使用 **marimo**；JupyterLab 用於臨時草稿；`uv` lockfile | 可在 git 中審查的可重現 notebook |
| 資料 | 本地磁碟或 S3 相容儲存上的 Parquet 分區；以 **DuckDB** 處理查詢與 as-of join，以 **Polars** 處理特徵；pandas 3 僅用於邊界 | 零維運；快速；同一套程式碼日後可直接在正式環境執行 |
| 舊版量化技術堆疊 | 獨立的 `legacy-quant` 環境（pandas 2.3），用於 alphalens/pyfolio/zipline-reloaded、Nixtla 預測套件與 FinMind 用戶端（或直接呼叫 FinMind 的 REST API），*或*以 Polars 重新實作 IC、分位數報酬與 tear sheet 指標（數百行程式碼） | 避開 pandas<3 陷阱 |
| 投資組合 | **skfolio**（搭配 `CombinatorialPurgedCV`）加上 cvxpy；需要特殊風險度量時使用 Riskfolio-Lib | 活躍、寬鬆授權、ML 風格驗證 |
| 績效 | 自建指標，加上鎖定版本的 QuantStats tear sheet | 定義穩定 |
| ML | LightGBM 加上 scikit-learn pipeline 加上 Optuna；Chronos-2 或 TimesFM 2.5（Apache-2.0）僅作為基準模型或波動率特徵 | 兼顧成本與價值；沒有授權陷阱 |
| 追蹤 | MLflow 搭配本地 SQLite 儲存與本地 artifact；DVC *或*不可變、以內容雜湊識別的 Parquet 快照 | 從第一天起就掌握試驗次數並確保可重現性 |
| LLM | 唯讀 MCP（自建 DuckDB、edgartools、資料供應商）；在沙箱中進行 AI 程式撰寫；券商 MCP 僅用於模擬交易 | 提升生產力，且沒有下單風險 |
| GPU | 不使用；深度學習實驗時再租用 | 限制大於效益 |

### (b) 5–20 人團隊或機構等級

- **環境。** JupyterHub 或託管工作區，搭配容器化、版本化的 kernel；產出報告的 notebook 使用 marimo。研究程式碼須經過 pull request 審查與 CI。
- **資料。** Lakehouse（物件儲存上的 Iceberg 或 DuckLake），搭配雙時態（bitemporal）、時點正確的資料表。DuckDB 與 Polars 仍是每位使用者各自的引擎；當資料量超出單一節點時，Ibis 讓查詢可以移轉到資料倉儲。
- **因子工作。** 內部的 Polars 因子函式庫，搭配因子登錄庫。可評估以 Qlib 進行橫斷面股票 ML，但鑑於其發布節奏，請 fork 或將其納入 vendor 目錄自行管理。
- **投資組合。** skfolio 與 cvxpy 搭配商用求解器。最佳化器的輸出須經過與實盤交易相同的風控引擎。
- **MLOps。** 自行架設的 MLflow 伺服器（RBAC、模型登錄庫、LLM 追蹤）作為記錄系統（system of record）；只有在深度學習 sweep 佔主導且可接受 SaaS 時，才使用 W&B Enterprise。以 Iceberg 快照或 lakeFS 為資料做版本控管。lakeFS BSL 只允許未經修改的*內部*使用，因此若平台將服務外部使用者，請改用 Iceberg 快照或 DVC，或購買 lakeFS 商業授權。只有當多個模型共用線上特徵時，才加入 Feast。
- **LLM。** 中央 MCP 閘道，提供唯讀、依使用者限定範圍的工具、完整的稽核日誌，以及 prompt injection 紅隊演練。Agent 的輸出會成為提案，須經過四眼（four-eyes）核准。
- **GPU。** 共用、採排程方式的 Linux GPU 資源池（RAPIDS、Polars GPU、PyTorch），用於選擇權曲面、tick 與深度模型工作。

### 過度擬合控管與晉級關卡

以下門檻為建議的起始值；請依各策略類別進行校準。

| 關卡 | 進入條件 | 證據產出物 |
|---|---|---|
| 0. 研究 | 在測試*之前*寫下假說；記錄資料血緣（data lineage）；每個變體都以 MLflow run 記錄，使試驗次數 *N* 為已知 | 包含所有試驗的 MLflow experiment |
| 1. 回測 | Walk-forward 或具 purge 與 embargo 的組合式淨化交叉驗證（combinatorial purged cross-validation, CPCV）；符合實際的成本、滑價、借券與資金成本；Deflated Sharpe Ratio（依 *N* 計算）≥ 0.95 機率；回測過度擬合機率（Probability of Backtest Overfitting, PBO）≤ 0.2；參數穩定性曲面；容量估計 | 由與實盤相同的訊號程式碼所產生、經簽核的回測報告 |
| 2. 模擬交易 | 至少 3 個月*或* N 筆交易；實盤與回測之間的追蹤誤差及滑價落在議定範圍內；無人工覆寫 | 模擬交易損益對帳 |
| 3. 實盤（小規模） | 資金逐步投入時程；緊急停止開關（kill switch）；由風控引擎強制執行的回撤與曝險限制；獨立核准人 | 核准紀錄、限額設定 |
| 4. 實盤（擴大規模） | 監控策略衰退與市場狀態轉換；指標超出範圍時自動降低風險；每季重新驗證 | 監控儀表板、重新驗證紀錄 |

AI 生成的策略與自動化因子挖掘（例如 RD-Agent）可能使 *N* 增加好幾個數量級。請計入每一個生成的候選，否則 deflated Sharpe ratio 將毫無意義。

## 對整體架構的影響

- **單一訊號程式碼庫。** 將特徵與訊號封裝成版本化的 Python 函式庫（Polars/Arrow），由回測器、模擬交易與實盤交易共同匯入。研究 notebook 只*呼叫*它。這消除了研究與正式環境之間的偏差（skew）。
- **以 Arrow 作為交換格式。** 靜態儲存使用 Parquet，記憶體中使用 Arrow，並以 Arrow Flight 或 IPC 連接以其他語言（Rust、C#、Java）撰寫的核心引擎。時點正確（「as-of」）語意必須存在於儲存層，而不只存在於 notebook 中。
- **實驗登錄庫是一項平台服務。** MLflow run ID 串連起資料快照、程式碼 commit、參數、試驗次數與晉級決策。OMS 應拒絕執行沒有已核准登錄項目的策略版本。
- **在設計上就隔離相依套件。** 預期至少需要三個執行階段映像檔：現代版（pandas 3、Polars）、legacy-quant（pandas 2.3），以及深度學習/TSFM（鎖定 torch 版本）。若使用 GPU dataframe，再加上第四個鎖定 RAPIDS 版本的 GPU 映像檔（針對 RAPIDS 26.08 為 pandas `<3.0.4`、Polars `<1.43`）。使用容器，而不是單一的全域環境。
- **批次推論優先。** 每日與盤中訊號以排程工作執行。只有在延遲需求確實要求時，才進行線上模型服務（行程內的 LightGBM 或 ONNX）。
- **LLM 層位於交易信任邊界之外。** 唯讀 MCP 讓它可以看到資料；它的提案會進入佇列，接著依序經過風控引擎、人工，再到 OMS。LLM 永遠不會取得 OMS 憑證，而且沒有任何從沙箱通往券商的網路路徑。
- **以 Linux 為規劃前提。** GPU 與多數量化基礎設施都預設使用 Linux，因此 Windows 桌面上的研究應使用 WSL2 或遠端 kernel。

## 風險與陷阱

- **pandas 3 遷移使生態系分裂。** reloaded 技術堆疊、Feast、Nixtla（statsforecast、mlforecast、utilsforecast）與 FinMind 用戶端鎖定 `<3`，而 cuDF 26.08 鎖定 `>=3.0.0,<3.0.4`（排除了目前的 3.0.6）；單一環境無法同時滿足兩者。pandas 3.1（rc0 於 2026 年 9 月 30 日）與 Polars 2.0（rc2 於 2026 年 9 月 20 日）即將帶來另一輪變動。
- **授權陷阱。** TimesFM 3.0 與 Moirai 2.0 的權重為非商業授權。lakeFS BSL（v1.87.0+）禁止在生產環境使用修改過的建置版本，也禁止在為組織外部人員提供服務的生產系統中使用。FinMind 資料僅供教育、非商業用途。資料供應商條款可能禁止將資料傳送給 LLM 供應商。
- **維護與整併。** Alphalens 與 pyfolio-reloaded 自 2025 年 6 月以來一直沒有動靜；Qlib 已超過 13 個月未發布新版；QuantStats 於 2026 年 9 月變更了統計計算；DuckDB 1.5 於 2026 年 11 月 1 日終止支援，1.4 LTS 社群支援於 2026 年 11 月 17 日結束，因此請規劃遷移至 2.0。CoreWeave 現在擁有 W&B 與 marimo，而 lakeFS 擁有 DVC。
- **基礎模型炒作。** 在通用基準測試上的優異排名，無法延續到報酬預測。務必在扣除成本後，與隨機漫步及梯度提升基準模型進行比較。
- **LLM 回測受到污染。** 訓練資料包含了「未來」。只使用模型訓練截止日之後的期間，或使用匿名化的輸入。請記錄模型版本，因為託管模型會在沒有通知的情況下悄悄改變。
- **透過新聞與申報文件進行的 prompt injection**，以及遭工具投毒（tool-poisoned）或惡意的 MCP 伺服器。只從鎖定版本、經過審查的來源安裝 MCP 伺服器，並在沙箱中執行。
- **未計入的試驗。** 在 notebook 中東修西改，以及 AI 生成的變體，都會灌水樣本內 Sharpe。沒有記錄，就不算數。
- **誤用的分析方法。** 將以報酬為基礎的 tear sheet 套用在選擇權或槓桿期貨上，或在未定義收盤時間的 24/7 加密貨幣上計算「每日」指標，都會產生誤導性的結果。

## 參考資料

- pandas 3.0 發布： https://pandas.pydata.org/community/blog/pandas-3.0.html ; https://pypi.org/project/pandas/
- Polars GPU 支援： https://docs.pola.rs/user-guide/gpu-support/ ; https://pypi.org/project/polars/
- DuckDB 1.5 / 1.4 LTS / 發布行事曆： https://duckdb.org/2026/09/28/announcing-duckdb-156 ; https://duckdb.org/2025/09/16/announcing-duckdb-140.html ; https://duckdb.org/release_calendar
- Ibis： https://pypi.org/project/ibis-framework/
- marimo 加入 CoreWeave： https://marimo.io/blog/joining-coreweave ; https://pypi.org/project/marimo/
- JupyterLab： https://pypi.org/project/jupyterlab/
- Positron： https://positron.posit.co/
- Qlib： https://github.com/microsoft/qlib ; https://pypi.org/project/pyqlib/ ; https://github.com/microsoft/RD-Agent
- Alphalens-reloaded： https://pypi.org/project/alphalens-reloaded/ ; https://github.com/stefan-jansen/alphalens-reloaded
- pyfolio-reloaded / empyrical-reloaded / zipline-reloaded： https://pypi.org/project/pyfolio-reloaded/ ; https://pypi.org/project/empyrical-reloaded/ ; https://pypi.org/project/zipline-reloaded/
- QuantStats： https://github.com/ranaroussi/quantstats/releases ; https://pypi.org/project/quantstats/ ; https://github.com/Lumiwealth/quantstats_lumi
- skfolio CPCV： https://skfolio.org/generated/skfolio.model_selection.CombinatorialPurgedCV.html ; https://pypi.org/project/skfolio/
- Riskfolio-Lib： https://pypi.org/project/Riskfolio-Lib/
- PyPortfolioOpt： https://pypi.org/project/pyportfolioopt/ ; https://pyportfolioopt.readthedocs.io/en/latest/Roadmap.html
- cvxpy： https://pypi.org/project/cvxpy/
- TimesFM（2.5 / 3.0 授權）： https://github.com/google-research/timesfm
- Chronos-2： https://www.amazon.science/blog/introducing-chronos-2-from-univariate-to-universal-forecasting ; https://huggingface.co/amazon/chronos-2
- Moirai 2.0： https://huggingface.co/Salesforce/moirai-2.0-R-small ; https://arxiv.org/abs/2511.11698
- Kronos： https://github.com/shiyu-coder/Kronos
- Rahimikia、Ni、Wang，"Re(Visiting) Time Series Foundation Models in Finance"： https://arxiv.org/abs/2511.18578
- Noguer i Alonso、Franklin，"Pretrained Time-Series Foundation Models for Financial Return Forecasting"： https://arxiv.org/abs/2606.27100
- Glasserman、Lin，GPT 情緒分析中的前視偏誤： https://arxiv.org/abs/2309.17322
- MLflow 發布版本： https://mlflow.org/releases ; https://github.com/mlflow/mlflow
- W&B / CoreWeave Forge 定價： https://wandb.ai/site/ ; https://coreweave.com/forge-pricing
- lakeFS 收購 DVC： https://lakefs.io/media-mentions/lakefs-acquires-dvc-uniting-data-version-control-pioneers/
- lakeFS BSL 變更： https://lakefs.io/blog/lakefs-business-source-license/
- DVC： https://pypi.org/project/dvc/ ; Feast： https://pypi.org/project/feast/
- RAPIDS 安裝需求： https://docs.nvidia.com/datascience/install/ ; cudf.pandas： https://docs.nvidia.com/cudf/latest/cudf_pandas/ ; https://pypi.org/project/cudf-cu12/
- Alpaca MCP 伺服器： https://github.com/alpacahq/alpaca-mcp-server
- Massive（前身為 Polygon.io）MCP 伺服器： https://github.com/massive-com/mcp_massive
- edgartools： https://github.com/dgunning/edgartools
- FinMind： https://github.com/FinMind/FinMind ; TEJ TQuant Lab： https://github.com/tejtw/TQuant-Lab
- OWASP LLM01:2025 Prompt Injection： https://genai.owasp.org/llmrisk/llm01-prompt-injection/
- MCP 安全性最佳實務： https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices
- FINRA 2026 Annual Regulatory Oversight Report（2026 年度監理監督報告），GenAI 章節： https://www.finra.org/rules-guidance/guidance/reports/2026-finra-annual-regulatory-oversight-report/gen-ai
- Bailey & López de Prado，Deflated Sharpe Ratio： https://www.davidhbailey.com/dhbpapers/deflated-sharpe.pdf
- Bailey、Borwein、López de Prado、Zhu，Probability of Backtest Overfitting（回測過度擬合機率）： https://www.davidhbailey.com/dhbpapers/backtest-prob.pdf
- QuantLib / py_vollib： https://pypi.org/project/QuantLib/ ; https://pypi.org/project/py-vollib/
- Nixtla 的 pandas 版本鎖定： https://pypi.org/project/statsforecast/ ; https://pypi.org/project/mlforecast/ ; https://pypi.org/project/utilsforecast/
- FinMind 用戶端： https://pypi.org/project/FinMind/
- cudf-polars（Polars GPU 後端）版本鎖定： https://pypi.org/project/cudf-polars-cu12/
- CUDA 13.0 架構支援移除項目： https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/index.html
- TimesFM 3.0 權重說明卡： https://huggingface.co/google/timesfm-3.0-pytorch
- lakeFS BSL 條文： https://github.com/treeverse/lakeFS/blob/master/LICENSE
- PyPortfolioOpt 1.6.0 發布： https://github.com/PyPortfolio/PyPortfolioOpt/releases
- RD-Agent 1.0.0： https://github.com/microsoft/RD-Agent/releases ; https://pypi.org/project/rdagent/
- 證交所漲跌幅限制： https://www.twse.com.tw/en/page/products/trading/introduce.html ; 期交所 TXO： https://www.taifex.com.tw/enl/eng2/tXO

## 驗證紀錄（2026-10）

2026-10-05 針對 PyPI JSON 中繼資料、GitHub 儲存庫與發布版本、Hugging Face 模型中繼資料，以及官方文件與公告，進行了一次對抗式事實查核。

**已確認**
- pandas 3.0.0 於 2026 年 1 月 21 日推出；3.0.6 於 2026 年 9 月 17 日推出。Copy-on-Write 是唯一模式，且在已安裝 pyarrow 時，預設 `str` dtype 以 PyArrow 為後端（pandas 部落格、PyPI）。
- alphalens-reloaded 0.4.6、pyfolio-reloaded 0.9.9 與 zipline-reloaded 3.1.1 宣告 `pandas<3.0`。Feast 0.66.0 宣告 `pandas<3`。cudf-cu12 26.8.1 宣告 `pandas>=3.0.0,<3.0.4a0`。empyrical-reloaded 沒有版本上限鎖定（PyPI `requires_dist`）。
- DuckDB 1.5.0「Variegata」於 2026 年 3 月 9 日推出，1.5.6 於 2026 年 9 月 28 日推出。2.0.0 預定於 2026 年 10 月 21 日推出（暫定）。1.4 LTS 於 2026 年 11 月 17 日終止支援（duckdb.org 發布行事曆）。
- pyqlib 0.9.7 於 2025 年 8 月 15 日推出（MIT）。Qlib 的 commit 持續至 2026 年 9 月 16 日。
- QuantStats 0.0.82–0.0.86 於 2026 年 9 月 26–27 日推出，對交易統計與滾動分析做了「統計修正」（Apache-2.0）。
- skfolio 1.4.11（2026 年 10 月 3 日，BSD-3）提供 `CombinatorialPurgedCV(n_folds, n_test_folds, purged_size, embargo_size)`。Riskfolio-Lib 7.4.0 於 2026 年 10 月 4 日推出（BSD-3），PyPortfolioOpt 1.6.0 於 2026 年 2 月 26 日推出（MIT）。
- TimesFM 2.5（2025 年 9 月，200M 參數，16k context）的權重為 Apache-2.0。TimesFM 3.0 權重（2026 年 8 月，約 331M 參數）採用 `timesfm-non-commercial-license-v1.0`，僅允許非商業、非生產用途；商業使用須透過 Google Cloud/BigQuery ML（GitHub README、Hugging Face）。
- Chronos-2（部落格文章 2025 年 10 月 20 日；120M 參數；CPU 或 GPU）為 Apache-2.0。Moirai 2.0 權重為 CC-BY-NC-4.0，且「僅供研究用途」（for research purposes only）。
- arXiv 2511.18578（Rahimikia、Ni、Wang）：94 個國家、34 年的每日超額報酬；現成 TSFM 表現不佳，而金融原生的預訓練帶來顯著增益。arXiv 2606.27100（Noguer i Alonso、Franklin）：五檔股票，相對神經網路基準模型 10 項中勝出 8 項，相對隨機漫步的增益「微小且零星」（small and sparse）。
- lakeFS 收購了 DVC（2025 年 11 月 18 日），DVC 維持開源。lakeFS v1.87.0（2026 年 9 月 22 日）採用 BSL 1.1，並設有四年後轉為 Apache-2.0 的變更日（change date）。
- Alpaca MCP server v2（2.3.2，MIT）支援股票、加密貨幣以及單腳或多腳選擇權委託，且 `ALPACA_PAPER_TRADE` 預設為 `true`。Massive MCP 伺服器只開放 Massive 的資料 API。
- RAPIDS 需要 Linux 或透過 WSL2 的 Windows 11（單一 GPU）、compute capability 7.0+，以及 CUDA 12 或 13。Polars GPU 引擎處於公開 beta，允許退回 CPU 時通過 99.2% 的測試，不允許時為 88.8%。
- 以下版本與日期與 PyPI 或 GitHub 相符：JupyterLab 4.6.4、marimo 0.25.1（2025 年 10 月 30 日加入 CoreWeave，仍為 Apache-2.0）、Positron 2026.09（Elastic License 2.0）、Polars 1.44.2、Ibis 12.0.0、cvxpy 1.9.3、quantstats-lumi 1.1.5、empyrical-reloaded 0.5.12、scikit-learn 1.9.1、LightGBM 4.7.0、XGBoost 3.4.1、PyTorch 2.14.1、Optuna 5.0.0、statsmodels 0.15.0、arch 8.0.0、MLflow 3.16.1（RBAC 於 3.13，2026 年 5 月；MCP 登錄庫於 3.15，2026 年 7 月）、DVC 3.67.1、Feast 0.66.0、edgartools 5.60.0（MIT，內建 MCP 伺服器）、QuantLib 1.43、py_vollib 1.0.12、uni2ts 2.0.0（`torch<2.5`、`numpy~=1.26`）、cuDF 26.08。
- 另已確認：
  - Kronos：MIT；獲 AAAI 2026 接受；mini、small 與 base 權重（4.1M–102.3M）已開放，499.2M 的 large 模型則未開放；以來自 45 個以上交易所的資料訓練。
  - W&B 現為 CoreWeave Forge 的一部分：免費方案有 5 個席次與 5 GB，Pro 方案每月 60 美元起。
  - FinMind 程式碼為 Apache-2.0；其資料僅供教育、非商業用途；限制為每小時 300 次請求，使用 token 則為 600 次。
  - TQuant Lab 建構於 zipline、pyfolio 與 alphalens 之上。
  - 台灣市場規則：證交所 ±10% 漲跌幅限制；TXO 週選擇權系列與盤後交易時段。
  - 指引文件：OWASP LLM01:2025 要求最小權限與人機協作控管。FINRA 2026 GenAI 章節中確實有所引用的「beyond the user's actual or intended scope」措辭。MCP 2025-11-25 安全性最佳實務涵蓋 token 直通、逐一向用戶端取得同意、權限範圍最小化與本地伺服器沙箱化。
  - Glasserman 與 Lin（匿名化、前視偏誤、「分心效應」）。

**已更正**
- QuantStats 曾被描述為在 2026 年 9 月「沉寂多年後復甦」。實際上它在 2023 年 7 月至 2025 年 7 月處於停滯，並以 0.0.64–0.0.77（2025 年 7–9 月）與 0.0.78–0.0.81（2026 年 1 月）復甦，2026 年 9 月的密集發布則是最新一輪（來源：PyPI 發布歷史、GitHub releases）。
- Moirai 2.0 發布日期：「2025 年 11 月」改為「權重 2025 年 8 月（Hugging Face repo 建立於 2025 年 8 月 6 日）；論文 2025 年 11 月」（來源：Hugging Face commit 歷史、arXiv 2511.11698）。
- TimesFM 3.0 規模：「~330M（據報導）」改為「≈331M」（來源：Hugging Face safetensors 中繼資料，330,710,976 個參數）。
- lakeFS BSL 範圍：草稿寫的是「內部使用沒問題，但禁止將其作為服務託管或轉售」。實際條款為：只有未經修改的發布版本可用於生產環境，且僅限內部使用。不得將 lakeFS 或其功能提供給第三方，且供應商的指引排除了任何為組織外部人員提供服務的生產系統（來源：lakeFS LICENSE、lakeFS BSL 部落格文章）。
- 「核心 ML 技術堆疊全部……皆為最新版本」：Nixtla `statsforecast` 2.1.1、`mlforecast` 1.1.0 與 `utilsforecast` 0.2.16（neuralforecast 的相依套件）宣告 `pandas<3.0`。已將它們加入舊版環境與風險項目（來源：PyPI `requires_dist`）。
- FinMind 用戶端（2.0.11）宣告 `pandas<3.0.0`；台灣資料路徑中原本漏列此點（來源：PyPI）。
- 「cuDF 26.08 鎖定 3.0.x」改為「`>=3.0.0,<3.0.4`，排除了目前的 3.0.4–3.0.6」（來源：PyPI cudf-cu12）。
- Polars GPU 引擎原本漏列一項版本耦合：`cudf-polars` 26.08 要求 `polars>=1.35,<1.43`，因此無法與目前的 Polars 1.44.x 一同執行（來源：PyPI cudf-polars-cu12/cu13）。
- RAPIDS「Volta+ 搭配 CUDA 12 或 13」：CUDA 13 的函式庫（cuFFT、cuSPARSE）已不再支援 Turing 之前的 GPU，因此 Volta 實務上需要使用 CUDA 12 版本（來源：CUDA Toolkit 版本說明）。
- PyPortfolioOpt「成熟（僅修正錯誤）」：repo 已移至 PyPortfolio 組織並有新的共同維護者，且 1.6.0 加入了 pandas 3 與 Python 3.14 支援（來源：GitHub release v1.6.0）。
- 補充了原本會過時的項目：
  - pandas 3.1.0rc0（2026 年 9 月 30 日）。
  - Polars 2.0.0rc2（2026 年 9 月 20 日）。
  - DuckDB 1.5 終止支援（2026 年 11 月 1 日）。
  - RD-Agent 1.0.0（2026 年 9 月 23 日）。
  - lakeFS v1.88.0（2026 年 10 月 1 日）。
  - Alpaca 的 `ALPACA_TOOLSETS` 篩選功能，用於唯讀用途。
  - arXiv 2511.18578 測試的是較早世代 TSFM 這一事實。
  - W&B Pro 的團隊規模限制。
  - TXO 週三與週五到期的週選擇權。

**無法驗證**
- 台灣加密貨幣交易所的法律地位。「受金管會監管」是合理的說法：它們依金管會的防制洗錢（AML）規範向金管會登記。但無法確認《虛擬資產服務法》是否已於 2026 年 10 月前通過。
- pandas 3 與 skfolio、Riskfolio-Lib 及 QuantStats 實際搭配的運作情況。它們並未宣告 pandas 的版本上限（skfolio `>=2.1`、Riskfolio `>=2.2.2`、QuantStats `>=2.0`），但未查核任何 pandas-3 的 CI 結果。
- 其他託管式實驗追蹤工具（例如 Neptune.ai）的現況無法查核，因為該網站封鎖了自動化存取。它們未納入比較，因此在採用其中任何一個之前，請先確認供應商能否持續經營。
