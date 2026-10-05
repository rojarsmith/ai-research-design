[English](05-instrument-model-pricing-analytics.md) | **繁體中文**

# 金融商品建模與定價分析（選擇權、債券、加密貨幣衍生性商品）

*研究面向 05 · 狀態截至 2026-10-05 · 範圍：股票、加密貨幣、債券、選擇權；美國／全球 + 台灣（TWSE/TAIFEX）*

## TL;DR（重點摘要）

- **採用單一標準（canonical）、依生效日期管理（effective-dated）的商品模型**，以內部的 `instrument_id` 為鍵。執行期型別沿用 NautilusTrader 的 18 種具體商品型別（若計入 `SyntheticInstrument` 則為 19 種；沒有債券型別），並由一個雙時態（bitemporal）證券主檔（security master）保存交叉對照識別碼。**FIGI** 是免費的跨供應商鍵值（MIT 授權的開放資料，OpenFIGI API 免費）。**CUSIP** 需向 CUSIP Global Services（由 FactSet 營運）取得授權。美國選擇權使用 21 字元的 **OCC OSI** 代碼。加密貨幣則使用交易所代碼，加上基礎幣、計價幣與結算幣別。
- **QuantLib 1.43（BSD-3，2026-07-14；1.44-rc 2026-10-03）在所有情境中都是預設的定價核心。** 它涵蓋曲線、債券、美式定價引擎（QD+ 不動點法）、Heston、SABR、SVI 與局部波動率（local vol）。另外加上一層向量化的歐式 IV/greeks 計算層：**vollib**（MIT，2026 年恢復維護）或 **fast-vollib**（MIT，支援 NumPy/PyTorch/JAX 後端）。**受調查的函式庫中，沒有任何一個原生支援永續合約資金費率或幣本位（反向）選擇權的建模**，因此這層薄薄的邏輯必須自行撰寫。
- **若要達到機構級規模，加入 ORE**（Modified BSD；1.8.17.0 於 2026-09-15 在 GitHub 上標記版本，PyPI wheel 為 2026-09-14）。它提供 XVA、SIMM 與市場風險，並透過其計算圖（computation graph）支援 AAD 與 OpenCL/CUDA。**Strata**（Apache-2.0，v2.12.76 於 2026-09-30 發布）只適合以 JVM 為主的利率／信用團隊。**Rateslib** 屬於原始碼公開（source-available）授權：僅限私人、非商業用途免費，任何商業、專業或產生營收的用途，每位使用者每年需付 £251。這也包括將其用作企業程式碼的驗證工具。**FinancePy** 採 GPL-3.0：用於研究與內部使用沒問題，但若放進對外散布的閉源應用程式就會有問題。
- **各資產類別需要不同的分析能力。** 股票需要公司行動（corporate actions）與依生效日期管理的跳動點（tick）表。債券需要現金流、曲線與計息天數慣例（day count）引擎。選擇權需要波動率曲面、提前履約定價引擎與保證金模型。加密貨幣需要反向合約數學、資金費率累計與 24/7 交易日曆。
- **精度與速度：** 委託、成交與損益（PnL）以定點數（fixed-point）保存，模型路徑則使用 float64。在單一 CPU 核心上以純 NumPy 計算 100 萬口合約的全鏈 Black-76 價格加上 3 個 greeks，耗時 **0.06 秒**（本機實測）。GPU 只用於情境網格或蒙地卡羅（Monte Carlo）模擬，並請記住 JAX 預設使用 float32，且不原生支援 Windows GPU。

## 關鍵問題

1. 標準商品綱要（schema）是什麼？哪些識別碼免費、哪些需要授權？台灣與加密貨幣的代碼如何納入？
2. 各資產類別實際需要哪些定價模型？哪些可以延後？
3. 在 2026 年，哪個開源函式庫（或組合）能提供正確、持續維護且授權寬鬆的涵蓋範圍？
4. 交易前應如何估算保證金（Reg T、portfolio margin、SPAN、TAIFEX、加密貨幣交易所）？
5. GPU 與向量化在哪些地方值得投入？float32 或簡易求解器又會在哪些地方悄悄破壞數值？

## 方案比較

### 1. 識別碼與代碼體系（symbology）

| 識別碼 | 涵蓋範圍 | 授權／費用 | 在我們模型中的角色 |
|---|---|---|---|
| **FIGI**（OMG 標準；Bloomberg 為註冊機構） | 所有資產類別，包括期貨、選擇權、貸款、加密貨幣與交易所交易對 | 依 MIT 聲明開放資料；OpenFIGI API 免費（無金鑰時每分鐘 25 次請求、每次請求 10 個 job；有金鑰時每 6 秒 25 次請求、100 個 job） | **首選交叉對照鍵**；每個掛牌（listing）一個 FIGI，另有綜合（composite）與股份類別（share-class）層級 |
| **ISIN** | 證券（股票、債券、ETF）；台灣 ISIN 以 `TW` 開頭 | 引用免費；批次檔案來自各國編碼機構 | 用於交割與券商對帳單的債券與股票鍵 |
| **CUSIP** | 美國與加拿大證券 | **需授權**：CGS 由 FactSet 代 ABA 管理，其條款禁止再散布 | 僅在已取得授權時儲存（機構）；否則於執行期由 ISIN 推導，且絕不再散布 |
| **OCC OSI**（自 2010-02-12 起） | 美國上市選擇權：root（6）+ YYMMDD + C/P + 履約價×1000（8）= 21 字元 | 免費 | 美國選擇權的自然鍵。公司行動調整後 root 會改變 |
| **Ticker + MIC** | 交易所掛牌（例如 XTAI 上的 `2330`、XNAS 上的 `AAPL`） | 免費 | 顯示與路由鍵。**不穩定**（更名、重複使用） |
| **TAIFEX 商品代碼** | TX/MTX/TMF 期貨、TXO 選擇權、股票期貨／選擇權 | 免費 | 交易所代碼；月份代碼與週選擇權系列在 adapter 中對應 |
| **加密貨幣交易所代碼** | `BTCUSDT`（Binance）、`BTC-PERPETUAL`、`BTC-5OCT26-74000-C`（Deribit） | 免費 | 以交易所為範圍的鍵，一律搭配基礎幣、計價幣與結算幣別 |

### 2. 標準綱要：四種資產類別的差異

| 屬性 | 股票／ETF | 加密貨幣（現貨、永續、交割、選擇權） | 債券 | 上市選擇權（個股、指數、TXO） |
|---|---|---|---|---|
| 價格單位 | 每股的幣值 | 計價幣；**反向**合約以 USD 報價、但以幣結算 | 面額百分比，乾淨價 vs 含息價（clean vs dirty）；殖利率 | 權利金 × 乘數（美國個股 100 股；TXO 每點 NT$50） |
| 跳動點 | 依價格分級（TWSE NT$0.01→NT$5）。美國 $0.01；SEC 修訂後的 Rule 612 對價格 ≥$1 的特定 NMS 股票所訂的半分（$0.005）跳動點已**延後至 2027 年 11 月**，連同調降後的 Rule 610(c) 存取費上限一併延後 | 交易所跳動點表，例如 Deribit BTC 選擇權 0.0001 BTC（高於 0.005 時為 0.0005）；BTC-PERPETUAL 0.5 USD | 1/32（美國公債），其他市場為十進位 | 依權利金分級（TXO：10 點以下為 0.1 點，至 ≥1,000 點時為 10 點） |
| 交易單位 | 1 股（美國）；台灣整股 1,000 股，另有盤中零股 | 最小數量與數量增量（8 位以上小數）；Deribit 選擇權最小 0.1 BTC | 最小面額／面額增量 | 1 口 |
| 交易時段 | 交易所日曆、集合競價、±10% 漲跌幅（台灣） | 24/7，含維護時段 | OTC 自營商營業時間 | TAIFEX 一般交易時段 08:45–13:45 與盤後交易時段 15:00–05:00 |
| 交割／到期 | 美國 T+1，台灣 T+2 | 永續合約永不到期（改以資金費率替代）；Deribit 交割合約於 **08:00 UTC** 到期 | 配息時程、到期日、提前買回／賣回時程 | 履約方式、AM/PM 或平均價結算（TXO：最後 30 分鐘的指數平均）、現金 vs 實物交割 |
| 生命週期事件 | 分割、股利、代碼變更 | 資金費率支付、下架、幣值重新計價（redenomination） | 配息、提前買回、償債基金（sinks）、違約 | 交割標的調整、被指派（assignment）、自動履約 |
| 所需分析 | 很少（標記價格） | 標記／指數價格、資金費率累計、基差 | 價格↔殖利率、應計利息、DV01、曲線 | IV、greeks、曲面、保證金 |

**模型選擇：** 採用 NautilusTrader 的商品型別（`Equity`、`FuturesContract`、`OptionContract`、`CryptoPerpetual`、`CryptoFuture`、`CryptoOption`、`PerpetualContract`、價差（spreads）及其他；截至 2026 年 10 月，`InstrumentAny` 中共有 18 個變體）。NautilusTrader 2.0 仍是發行候選版（2.0.0rc5，2026-09-15），因此請鎖定版本，並預期 2.0 正式版（GA）時型別會有變動。其共同欄位（`price_increment`、`size_increment`、`multiplier`、`lot_size`、`margin_init/maint`、maker/taker 手續費）成為執行期的契約。在此基礎上擴充：

- `Bond` 型別（配息時程、計息天數慣例、交割天數、提前買回時程）；
- `settlement_currency` / `is_inverse`；
- 依生效日期管理的 `tick_scheme_id`；
- `calendar_id`。

Strata 將 product、security 與 trade 分開的做法（OTC 交易內嵌 product；上市交易以 ID 參照 security），是債券與 OTC 端很好的參考設計。

### 3. 定價模型選單

| 模型 | 用途 | 資產類別 | 優先順序 |
|---|---|---|---|
| **Black-76**，搭配隱含遠期價格（由買賣權平價或期貨推得） | 指數選擇權（SPX、TXO）、期貨選擇權、**加密貨幣選擇權**（遠期價格取自交割期貨或永續合約）、利率交換選擇權（swaptions） | 選擇權、加密貨幣 | **MVP** |
| Black-Scholes-Merton | 歐式個股選擇權；快速標價 | 選擇權 | MVP |
| Bachelier（常態模型） | 利率、價差、接近零或為負的遠期價格 | 債券／利率 | 後期 |
| CRR / Leisen-Reimer 樹 | 含離散股利的美式選擇權；教學用途；可贖回債券（HW/BK/BDT 樹） | 選擇權、債券 | MVP（債券：後期） |
| Bjerksund-Stensland / Barone-Adesi-Whaley | 用於篩選的快速美式近似 | 選擇權 | 選用 |
| **ALO「QD+」不動點法**（QuantLib `QdFpAmericanEngine`） | 快速**且**精確的美式定價；美國個股選擇權的預設方法 | 選擇權 | **MVP** |
| 有限差分（Crank-Nicolson） | 含離散股利的美式選擇權、障礙選擇權 | 選擇權 | 透過 QuantLib 列入 MVP |
| **每個到期日的 SVI → SSVI 曲面** | 考量套利的曲面擬合、微笑曲線內插、IV 分析 | 選擇權、加密貨幣選擇權 | **MVP（SVI）**，SSVI 後期 |
| SABR（及無套利 SABR） | 利率／外匯微笑曲線；有時用於加密貨幣微笑曲線 | 利率、外匯、加密貨幣 | 後期 |
| Heston（及 rough Heston，QuantLib 1.44 新增） | 隨機波動率動態、奇異選擇權、遠期偏斜（forward-skew）研究 | 選擇權、加密貨幣 | 後期 |
| Dupire 局部波動率 | 與香草選擇權一致的奇異選擇權定價；需要無套利曲面 | 選擇權 | 機構級 |
| 曲線拔靴（bootstrapping）+ Nelson-Siegel-Svensson | 折現／遠期曲線；擬合的政府公債曲線；貴賤（rich/cheap）分析 | 債券 | 債券的 MVP |
| Z-spread / OAS / 信用利差 | 公司債與可贖回債券 | 債券 | 後期 |

**需自行掌握的加密貨幣專屬數學（任何函式庫都沒有）：**

- **反向期貨與永續合約：** 以幣計價的損益為 `Q_usd × (1/F_entry − 1/F_exit)`。曝險具有凸性，且擔保品就是標的資產本身。
- **反向選擇權（Deribit「reversed」）：** 權利金以 BTC 報價，因此以幣計價的價格等於以 USD 計算的 Black-76 價值除以標的價格。進行幣本位避險時，delta 必須做權利金調整。
- **資金費率：**
  - Binance USDⓈ-M：對 N 小時的間隔，`F = [P̄ + clamp(I − P̄, ±0.05%)] / (8/N)`，其中 `I` = 每 8 小時 0.01%。預設結算時間為 00/08/16 UTC，但部分合約使用 4 小時，且觸及上限時 Binance 可將合約切換為 1 小時。
  - Hyperliquid 計算 8 小時費率，但**每小時**支付其 1/8，上限為每小時 4%。
- **基差：** 年化基差 = `(F/S − 1) × 365/days`。在回測引擎中，資金費率與基差是現金流事件，而不只是分析指標。
- **Deribit 的所有權：** Coinbase 已於 2025 年 8 月完成對 Deribit 的收購（約 29 億美元）。Deribit 於 2025-08-19 在反向選擇權之外，新增以 USDC 結算的線性 BTC/ETH 選擇權，因此兩種 `settlement_currency` 變體都要建模。

### 4. 函式庫比較

| 函式庫 | 語言／綁定 | 授權 | 維護狀況（已驗證） | 選擇權 | 債券／曲線 | 加密貨幣衍生性商品 | 效能 | 結論 |
|---|---|---|---|---|---|---|---|---|
| **QuantLib** | C++（C++17；1.44 移除 Boost `any`/`optional` 的備援實作）；透過 SWIG 支援 Python、C#、Java | **BSD-3** | 1.40（2025-10-14）→ 1.41 → 1.42/1.42.1 → **1.43（2026-07-14）** → 1.44-rc（2026-10-03）；每季發布 | BSM、Black、Bachelier、樹狀模型、Bjerksund-Stensland、**QD+ 美式**、FD、Heston、SABR、SVI（實驗性）、局部波動率 | 固定／浮動／可贖回／可轉換債券、所有計息天數慣例、多曲線拔靴、NS/Svensson 擬合、台灣日曆 | 無內建支援（僅有 Black-76 基本元件） | 快速的純量 C++。全域評價日（evaluation date）限制了多執行緒，因此請採用行程（process）層級的平行化 | **兩種情境的核心** |
| **ORE**（Open Source Risk Engine，LSEG Post Trade Solutions） | 建構於 QuantLib 之上的 C++；Python 透過 `open-source-risk-engine` wheels | **Modified BSD** | ORE 15（2026-03-04，基於 QuantLib 1.41）；ORE 16（2026-05-28）；**1.8.17.0（GitHub 2026-09-15；PyPI wheel 2026-09-14）** | QuantLib，加上腳本化交易（scripted trades）、Heston、跨資產類別的 SVI | 另加 XVA、SIMM、市場風險、敏感度 | 無 | 多執行緒評價、**AAD**、透過計算圖支援 OpenCL/CUDA | **機構級**風險層 |
| **OpenGamma Strata** | Java 8u40+ | **Apache-2.0** | **v2.12.76（2026-09-30）**，約每月發布 | 外匯香草選擇權、利率交換選擇權、利率上限／下限（caps/floors）；ETD 建模 | 強大的利率、債券、債券期貨、CDS | 無 | JVM，生產等級 | 僅適用於 JVM 利率／信用團隊 |
| **Rateslib** | Python + Rust（PyO3） | **原始碼公開（source-available）**；僅限私人非商業用途免費；任何商業用途（包括作為基準／驗證工具）每位使用者每年 £251 | 2.0.1（2025-06）→ **2.7.1（2026-04-04）** | 外匯選擇權（SABR/spline 微笑曲線）；利率交換選擇權（beta，2.7） | 一流的債券慣例（`spec` 預設集）、債券期貨、具 AD 的曲線求解器 | 無 | Rust 核心、前向模式 AD | 利率／債券專家；需編列授權預算 |
| **FinancePy** | Python + Numba | **GPL-3.0-or-later** | 1.0.0（2025-08-31）→ **1.1.2（2026-08-21）**；Python ≥3.10,<3.14 | 美式、Heston、SABR、**SVI/SSVI 曲面**、Bjerksund-Stensland | 債券、內嵌選擇權（HW/BK/BDT）、NSS 擬合 | 無 | Numba JIT | 僅供研究與交叉核對（copyleft） |
| **vollib** / **fast-vollib** | Python（NumPy）；fast-vollib 另加 PyTorch、JAX 與 Triton kernel | **MIT** | vollib **1.0.11（2026-06-01）**，Python 3.9–3.13（`py_vollib` 1.0.12 為過渡套件）；fast-vollib **0.2.3（2026-09-05）**，為單一維護者的年輕 0.x 專案 | 歐式 Black/BS/BSM、透過「Let's Be Rational」計算 IV、greeks；fast-vollib 0.2.2 新增 SVI/SSVI 與 Heston 曲面擬合 | fast-vollib 0.2.3 新增固定收益合約 | 作為加密貨幣的 Black-76 引擎使用 | 向量化；GPU（fast-vollib） | **全鏈 IV/greeks** |
| **RustQuant** | Rust | MIT / Apache-2.0 | 提交紀錄持續到 2026-10，但**自 2024 年 11 月起未在 crates.io 發布新版**；自稱為「業餘時間專案（free-time project）」 | BS、Heston、SABR 部分功能 | 基本 | 無 | 原生 | 持續觀察；不適合生產環境 |
| **JAX / PyTorch（自行開發）** | Python | Apache / BSD | Google 的 **tf-quant-finance 已宣告停止維護**（其 README 寫著「no longer maintained and has been archived」，但 GitHub 並未將該儲存庫標示為封存）；py_vollib_vectorized 最後一次發布於 2021 年 | 由你自行撰寫：MC、AD greeks | 批次情境風險 | 自訂 | GPU；**預設 float32**（`jax_enable_x64`）；不原生支援 Windows CUDA（WSL2 為實驗性） | 僅用於機構級批次風險 |

**解讀：** QuantLib 是唯一持續維護、授權寬鬆，且同時涵蓋選擇權、債券與曲線的函式庫。ORE 則是 QuantLib 再加上一座風險工廠。其餘的不是範圍狹窄（vollib）、受授權限制（Rateslib、FinancePy）、綁定 JVM（Strata），就是尚未成熟（RustQuant）。

**上表未比較：購買而非自建。** 商業選擇權分析與資料，例如供應商提供的 IV 曲面與 greeks（ORATS、OptionMetrics IvyDB、Cboe LiveVol），或 Numerix 等定價函式庫，是情境 (b) 常見的替代方案。購買曲面歷史資料可能比自行建置與驗證更便宜，但會帶來資料授權一節所提到的再散布限制。

### 5. 保證金方法

| 制度 | 適用範圍 | 方法 | 資料 | 自建 vs 使用券商數據 |
|---|---|---|---|---|
| **Reg T** 策略型（strategy-based），加上 FINRA 4210 盤中保證金 | 美國保證金帳戶 | 股票原始保證金 50%；選擇權策略表（價差、跨式、掩護性）。自 2026-06-04 起（SR-FINRA-2025-017），FINRA 4210 已以盤中保證金不足（intraday-margin-deficit）規則取代型態日內交易者（pattern-day-trader）條款 | 規則表 | 建立規則引擎以進行交易前估算，包括盤中保證金 |
| **Portfolio margin（投資組合保證金）**（FINRA 4210(g)、OCC CPM/TIMS） | 經核准的美國帳戶。最低權益門檻屬於券商政策，通常約 $100k 以上；4210(g) 本身僅對非上市衍生性商品設定 $5M 下限 | 價格網格上的最大損失：個股 ±15%，高市值廣基指數 −8%/+6% | OCC 理論價值（需授權，經由券商取得） | 使用券商的數字；以我們自己的曲面近似複製 |
| **SPAN / SPAN 2** | CME（正轉向以 VaR 為基礎的 SPAN 2）、**TAIFEX** | 情境陣列加上跨商品與商品內抵減 | TAIFEX 發布**一般與盤後交易時段的 SPAN 風險參數檔** | 實作 SPAN 檔案載入器（確定性、有文件記載） |
| **加密貨幣交易所保證金** | Deribit 標準／投資組合保證金、Binance/OKX 統一帳戶 | 各交易所專屬的情境或 VaR 模型；強制平倉引擎 | 交易所 API | 從 API 讀取；僅在回測時複製 |

## 建議（依情境）

### (a) 個人／1-3 人 MVP

1. **商品模型：** 以 NautilusTrader 商品型別作為執行期綱要（與研究 01/02 一致）。新增 `Bond` 型別與依生效日期管理的 `tick_scheme`。
2. **證券主檔：** 存放於 PostgreSQL，並建立 `instrument_xref(instrument_id, scheme, value, valid_from, valid_to)` 資料表。
   - 透過 OpenFIGI 填入 FIGI。ISIN 取自券商與交易所的檔案。
   - 由選擇權鏈資料產生 OCC OSI。在各自的 adapter 中對應 TAIFEX 與加密貨幣交易所代碼。
   - **不要**儲存來自未授權來源的 CUSIP。
3. **定價核心：QuantLib-Python 1.43**，鎖定版本並每季升級。用於美式選擇權（`QdFpAmericanEngine`；離散股利影響重大時改用 FD）、債券（應計利息、殖利率、存續期間／凸性、DV01）、曲線拔靴與 NSS 擬合。
4. **選擇權鏈分析：** 使用 **vollib 1.0.11**（`import vollib`，而非 `py_vollib`）或 **fast-vollib** 進行向量化的 IV 與 greeks 計算。所有計算一律採用**搭配隱含遠期價格的 Black-76**，包括 TXO 與 Deribit 選擇權。
5. **撰寫約 500 行的加密貨幣模組：** 反向／線性損益、權利金調整後的 delta、依各交易所規則的資金費率累計，以及基差。以交易所公布的標記價格進行單元測試。
6. **曲面：** 以 SciPy 對每個到期日擬合 SVI，並檢查蝶式套利與日曆套利。SABR、Heston 與局部波動率延後到有策略需要時再處理。
7. **保證金：** 實盤交易時採用券商與交易所提供的數字。回測時使用 Reg T 規則表，加上針對 TX/TXO 的 TAIFEX SPAN 參數載入器。
8. **授權：** 不要將 FinancePy（GPL）放入任何對外散布的產品；在內部當作測試基準（test oracle）使用沒問題。**Rateslib 則不同。** 它的免費授權只涵蓋在非企業電腦上的私人、非商業用途，並禁止商業或產生營收的用途，包括用在交易應用程式中，或作為企業程式碼的驗證工具。真實資金交易可以說屬於此類，因此要嘛購買每位使用者每年 £251 的授權，要嘛就不要使用 Rateslib。

### (b) 5-20 人團隊／機構等級

1. 運行**專用的證券主檔服務**（雙時態），由授權參考資料（CUSIP、供應商公司行動資料、OCC 調整後交割標的公告）餵入。FIGI 是公開的串接鍵。
2. 運行**基於 QuantLib C++ / ORE 的定價服務**。它是無狀態的，接收帶版本的市場快照（以 ID 指定曲線與曲面），並透過 gRPC 或 Arrow Flight 存取。使用 ORE 處理敏感度、XVA、SIMM 與壓力測試，並在划算之處使用 AAD 與 GPU 計算圖。
3. 運行**波動率曲面服務**：具套利約束的 SSVI/eSSVI、盤中重新擬合，並保存參數歷史（可重現的回測需要此資料）。利率與外匯使用 SABR，奇異選擇權使用 Heston 或局部波動率。
4. **GPU 批次風險**（JAX x64 或 PyTorch，或 fast-vollib）僅用於全帳簿情境網格與蒙地卡羅模擬。美式與離散股利的定價保留在 CPU 上的 QuantLib。
5. **保證金複製：** SPAN/SPAN 2 引擎、使用我們自己曲面的 OCC CPM 式網格，以及加密貨幣交易所投資組合保證金（PM）的複製。每日與結算機構及券商對帳單核對。
6. **模型風險管理：**
   - 每個生產模型都做雙重實作（QuantLib vs vollib，並以 FinancePy 或*已授權*的 Rateslib 作為基準）。
   - 在 CI 中保留黃金測試向量（golden test vectors）。
   - 為每個模型記錄其假設。
7. **以利率／債券為主的交易台：** 評估 Rateslib 企業授權；若團隊以 JVM 為中心，則評估 Strata。

## 對整體架構的影響

- **證券主檔是一級（first-class）、雙時態的服務。** 其他所有元件都只參照 `instrument_id`。跳動點表、乘數、日曆與交割標的都依生效日期管理，因為制度會改變（例如 Rule 612 的半分跳動點於 2024 年 12 月暫緩實施，之後兩度延後，先延至 2026 年 11 月，現已延至 2027 年 11 月）。
- **兩個數值世界：** Rust 核心中的委託、成交與會計路徑使用定點數（研究 01）。定價服務使用 float64。轉換在邊界處透過 `make_price/make_qty` 明確進行。
- **市場物件即資料：** 曲線、曲面與資金費率歷史都是資料湖中帶版本的產出物（Parquet，研究 03）。回測與實盤執行皆參照快照 ID，因此價格可以重現。
- **生命週期事件存在於引擎內：** 配息、除息、資金費率支付、到期與交割、被指派與自動履約都是引擎事件，而不是事後處理。
- **並行：** QuantLib 的全域評價日使它實際上每個行程只能單執行緒運作，ORE 也指出它必須繞過 QuantLib 的執行緒安全限制。請以依評價日為鍵的行程池（process pool）來擴展 QuantLib。
- **用戶端從不定價：** 桌面、網頁與行動 UI 從伺服器接收 greeks 與 IV。這避免了把原生 QuantLib 打包到行動裝置上，也迴避了 GPL 的問題。
- **日曆：** 金融日期計算使用 QuantLib 日曆，交易時段則使用 `exchange_calendars`（Apache-2.0，含 XTAI）。再疊加人工休市日，例如台灣的颱風假。颱風假的公告往往很臨時，通常在前一晚 22:00 前發布，有時當天才宣布。QuantLib 的 `Taiwan` 日曆逐年寫死農曆與調整後的假日，且截至 2026 年 10 月僅涵蓋到 2026 年。請在年底前載入 TWSE/TAIFEX 公布的 2027 年休市日程，而不要依賴函式庫的預設值。

## 風險與陷阱

- **履約方式或結算方式錯誤：** 美國個股選擇權為美式且有離散股利；TXO 為歐式，並以 30 分鐘平均價結算。指數選擇權在 AM 與 PM 結算上也有所不同。一律使用 BSM 會錯估提前履約與到期損益。
- **簡易 IV 求解器在兩翼（wings）會失效。** 在我們的本機測試中，向量化 Newton 法在 100 萬口隨機合約中僅約 96% 收斂（vega 偏低）。請使用兩次迭代即可達到雙精度的「Let's Be Rational」，或具區間限制（bracketed）的備援方法，並標記違反無套利條件的情況，而不是強行求解。
- **反向合約的凸性與以幣計價的擔保品。** 將以 BTC 結算的合約當作線性合約處理，會得到錯誤的 delta、損益與強制平倉價格。
- **資金費率規則會改變：** 間隔（8 小時 → 1 小時）、上限與公式因交易所與時期而異。請依交易所與期間分別儲存。
- **債券慣例：** 錯誤的計息天數慣例（Act/Act ICMA vs 30/360）、除息期間、交割延遲或假日日曆，所造成的誤差可能與所交易的優勢（edge）一樣大。請使用 QuantLib（或已授權的 Rateslib）的慣例，而不是自行手寫。
- **曲面套利：** 各自獨立擬合的 SVI 切片可能產生日曆套利，進而使局部波動率發散。請強制套用 SSVI 式的約束。
- **GPU 精度：** float32 預設值（JAX、PyTorch）與消費級 GPU 上緩慢的 FP64，可能悄悄降低 greeks 的品質。請以 float64 的 CPU 結果進行驗證。
- **函式庫變動：** QuantLib 會在功能被棄用約五個版本後將其移除（1.43 移除了 1.38 所棄用的功能）。RustQuant 近期沒有發布新版、py_vollib_vectorized 已停滯，tf-quant-finance 已宣告停止維護。vollib 於 2026 年由少數維護者恢復維護。
- **資料授權：** CUSIP、OCC 理論價值與供應商的 IV/greeks 都有再散布限制。多使用者服務需要明確的授權。
- **經公司行動調整的選擇權**（非標準交割標的）會打破「100 × 標的」的簡易假設。

## 參考資料

- PyPI 上的 QuantLib（版本、BSD-3）: https://pypi.org/project/QuantLib/
- QuantLib 發布版本（1.42、1.43、1.44-rc 說明）: https://github.com/lballabio/QuantLib/releases
- QuantLib 1.40（Zenodo）: https://zenodo.org/records/17347020
- QuantLib `QdFpAmericanEngine`: https://www.quantlib.org/reference/class_quant_lib_1_1_qd_fp_american_engine.html
- QuantLib `BjerksundStenslandApproximationEngine`: https://www.quantlib.org/reference/class_quant_lib_1_1_bjerksund_stensland_approximation_engine.html
- QuantLib-Python 期限結構（NS/Svensson、SABR、SVI）: https://quantlib-python-docs.readthedocs.io/en/latest/termstructures.html
- QuantLib-Python 定價引擎: https://quantlib-python-docs.readthedocs.io/en/latest/pricing_engines.html
- ORE 儲存庫與授權: https://github.com/OpenSourceRisk/Engine
- ORE 效能（AAD、OpenCL/GPU、多執行緒）: https://github.com/OpenSourceRisk/Engine/blob/master/Examples/Performance/Readme.md
- ORE 15 公告: https://www.lseg.com/en/about-us/new-at-lseg/post-trade-solutions-strengthen-open-source-innovation-with-the-15th-release-of-open-source-risk-engine-ore
- ORE 16 公告: https://www.lseg.com/en/about-us/new-at-lseg/post-trade-solutions-advances-open-source-capabilities-with-release-of-open-source-risk-engine-ore-16
- ORE Python wheels: https://pypi.org/project/open-source-risk-engine/
- OpenGamma Strata: https://github.com/OpenGamma/Strata
- Strata 發布版本（Maven Central）: https://repo1.maven.org/maven2/com/opengamma/strata/strata-pricer/
- Strata 產品模型: https://strata.opengamma.io/product_model/
- Rateslib 發布說明: https://rateslib.com/py/en/latest/i_whatsnew.html
- Rateslib 授權: https://rateslib.com/py/en/latest/_sources/i_licence.rst.txt
- PyPI 上的 Rateslib: https://pypi.org/project/rateslib/
- FinancePy: https://github.com/domokane/FinancePy
- PyPI 上的 FinancePy: https://pypi.org/project/financepy/
- PyPI 上的 vollib: https://pypi.org/project/vollib/
- PyPI 上的 py_vollib: https://pypi.org/project/py-vollib/
- fast-vollib: https://pypi.org/project/fast-vollib/
- fast-vollib 論文（arXiv 2604.27210）: https://arxiv.org/abs/2604.27210
- RustQuant: https://github.com/avhz/RustQuant
- crates.io 上的 RustQuant: https://crates.io/crates/RustQuant
- TF Quant Finance（已宣告停止維護）: https://github.com/google/tf-quant-finance
- JAX 雙精度: https://docs.jax.dev/en/latest/notebooks/Common_Gotchas_in_JAX.html
- JAX 平台支援: https://docs.jax.dev/en/latest/installation.html
- Jäckel，"Let's Be Rational": http://www.jaeckel.org/LetsBeRational.pdf
- Gatheral & Jacquier，"Arbitrage-free SVI volatility surfaces": https://arxiv.org/abs/1204.0646
- NautilusTrader 商品（instruments）: https://nautilustrader.io/docs/latest/concepts/instruments/
- NautilusTrader `InstrumentAny`（18 個變體）: https://github.com/nautechsystems/nautilus_trader/blob/develop/crates/model/src/instruments/any.rs
- PyPI 上的 NautilusTrader（2.0 發行候選版）: https://pypi.org/project/nautilus_trader/
- OpenFIGI（FIGI 標準）: https://www.openfigi.com/about/figi
- OpenFIGI API 限制: https://www.openfigi.com/api/documentation
- CUSIP Global Services 條款: https://www.cusip.com/about/index.html
- OCC 選擇權代碼（OSI）: https://en.wikipedia.org/wiki/Option_symbol
- SEC Rule 612 豁免救濟（半分跳動點延後至 2027 年 11 月）: https://www.federalregister.gov/documents/2026/06/15/2026-11997/order-granting-temporary-exemptive-relief-pursuant-to-section-36a1-of-the-securities-exchange-act-of
- Regulation T §220.12: https://www.law.cornell.edu/cfr/text/12/220.12
- FINRA Rule 4210（投資組合保證金、盤中保證金）: https://www.finra.org/rules-guidance/rulebooks/finra-rules/4210
- SR-FINRA-2025-017（日內交易保證金由盤中保證金取代，2026-06-04 生效）: https://www.finra.org/rules-guidance/rule-filings/sr-finra-2025-017
- 投資組合保證金概述: https://en.wikipedia.org/wiki/Portfolio_margin
- CME SPAN 2: https://www.cmegroup.com/solutions/risk-management/performance-bonds-margins/span-2.html
- TAIFEX TXO 規格: https://www.taifex.com.tw/enl/eng2/tXO
- TAIFEX TX 規格: https://www.taifex.com.tw/enl/eng2/tX
- TAIFEX TMF 規格: https://www.taifex.com.tw/enl/eng2/tMF
- TAIFEX 保證金制度與 SPAN 參數檔: https://www.taifex.com.tw/enl/eng5/indexMargining
- TWSE 交易制度: https://www.twse.com.tw/en/products/system/trading.html
- exchange_calendars: https://github.com/gerrymanoim/exchange_calendars
- QuantLib 台灣日曆原始碼（假日表至 2026 年）: https://github.com/lballabio/QuantLib/blob/master/ql/time/calendars/taiwan.cpp
- 台灣颱風假宣布規則（中文）: https://zh.wikipedia.org/zh-tw/颱風假
- Deribit 商品 API（即時規格）: https://www.deribit.com/api/v2/public/get_instruments?currency=BTC&kind=option&expired=false
- Deribit BTC-PERPETUAL 規格（API）: https://www.deribit.com/api/v2/public/get_instrument?instrument_name=BTC-PERPETUAL
- Deribit USDC 線性選擇權上線: https://insights.deribit.com/education/usdc-settled-btc-eth-options-launch/
- Coinbase–Deribit 收購完成（The Block）: https://www.theblock.co/post/367106/deribit-linear-bitcoin-ether-options
- Binance 資金費率: https://www.binance.com/en/support/faq/detail/360033525031
- Hyperliquid 資金費率: https://hyperliquid.gitbook.io/hyperliquid-docs/trading/funding
- 計息天數慣例: https://en.wikipedia.org/wiki/Day_count_convention

## 驗證紀錄（2026-10）

2026-10-05 進行了一次對抗式（adversarial）事實查核，使用的來源包括 PyPI、crates.io 與 GitHub API、Deribit 即時 API、Federal Register 與 FINRA 規則原文、供應商授權頁面，以及交易所規格頁面。

**已確認（29）**

1. QuantLib 1.43 於 2026-07-14 以 BSD-3-Clause 發布。先前版本：1.42.1（2026-04-17）、1.42（2026-04-14）、1.41（2026-01-13）、1.40（2025-10-14）。來源：PyPI JSON、GitHub releases。
2. QuantLib v1.44-rc 於 2026-10-03 發布（預發布版）。它新增 rough Heston 模型，且無法再選用 Boost `any`/`optional` 實作（僅限 std）。來源：GitHub release、`News.md`。
3. QuantLib 的棄用節奏：1.43 移除了 1.38 所棄用的功能，1.44 移除 1.39 所棄用的功能，而 1.44 的棄用項目預計約在 1.49 移除。來源：發布說明。
4. QuantLib 需要 C++17，且 `QdFpAmericanEngine`、實驗性的 SVI smile section 與 `Taiwan` 日曆皆存在。來源：QuantLib `CMakeLists.txt` 與原始碼樹。
5. ORE 的功能：透過計算圖支援 AAD 與外部運算裝置（OpenCL，以及 QuantExt 中的 CUDA 環境）。其多執行緒引擎「works around QuantLib's thread-safety limitations」（繞過 QuantLib 的執行緒安全限制）。來源：ORE `Examples/Performance/Readme.md`、`QuantExt/qle/math`。
6. ORE 16 為腳本化交易新增 Heston，並在股票、外匯、商品與信用領域新增 SVI。來源：LSEG ORE 16 公告（2026-05-28）。
7. Strata 採 Apache-2.0。v2.12.76 已上架 Maven Central（2026-09-30），README 要求 Java 8u40+。來源：Maven Central、GitHub。
8. Rateslib 屬「not open source」（非開源）：原始碼公開的非商業條款，加上每位使用者每年 £251 的商業訂閱。版本：2.7.1（2026-04-04）、2.7.0（2026-03-30，beta 版利率波動率，含 SABR/spline cube 與交換選擇權）、2.0.1（2025-06-10）。來源：授權頁面、PyPI JSON、發布說明。
9. FinancePy 1.1.2（2026-08-21）採 GPL-3.0-or-later，需要 Python >=3.10,<3.14。它使用 Numba，具備 SVI/SSVI、BAW 與 Bjerksund-Stensland，並有 HW/BK/BDT 內嵌選擇權模型。來源：PyPI JSON、GitHub 原始碼。
10. vollib 1.0.11（2026-06-01）採 MIT，建構於 Jäckel 的 LetsBeRational 之上。`py-vollib` 1.0.12 是「deprecated transition package」（已棄用的過渡套件）。來源：PyPI。
11. fast-vollib 0.2.3（2026-09-05）採 MIT，具備 NumPy、PyTorch 與 JAX 後端，以及一項 CUDA 融合核心（fused-kernel）的 Triton 貢獻。來源：PyPI、arXiv 2604.27210。
12. RustQuant 採 MIT OR Apache-2.0。其最後一次 crates.io 發布為 0.3.1（2024-11-19），提交紀錄持續到 2026-10-04，README 附有「free-time project … not recommend … for trading」的免責聲明。來源：crates.io API、GitHub。
13. py_vollib_vectorized 最後一次發布於 2021-02-28（0.1.1）。來源：PyPI。
14. SEC 於 2026-06-15 發布的命令，將 Rule 612 $0.005 價格增量與 Rule 610(c) 存取費上限的豁免延長至 2027 年 11 月的第一個營業日。沿革：2024 年 12 月部分暫緩，2025 年 10 月核准豁免至 2026 年 11 月。來源：Federal Register 2026-11997。
15. Deribit BTC 選擇權為 `reversed`（反向）：以 BTC 結算、合約規模 1、跳動點 0.0001（高於 0.005 時為 0.0005）、最小 0.1，於 08:00 UTC 到期。來源：Deribit 即時 API。
16. Deribit 於 2025-08-19 新增以 USDC 結算的線性 BTC/ETH 選擇權，Coinbase 則於 2025 年 8 月完成約 29 億美元的 Deribit 收購。來源：The Block、Deribit Insights。
17. BTC-PERPETUAL 為反向合約，跳動點 0.5 USD。來源：Deribit API。
18. FIGI 附有 MIT 開放資料聲明，Bloomberg 為註冊機構。OpenFIGI 對應（mapping）限制為：無金鑰時每分鐘 25 次請求、每次 10 個 job；有金鑰時每 6 秒 25 次請求、每次 100 個 job。來源：openfigi.com。
19. CGS 由 FactSet 代 ABA 管理，其條款禁止再散布與建立主檔。來源：cusip.com。
20. OCC OSI 於 2010-02-12 以 21 字元格式實施。來源：Wikipedia，Option symbol。
21. TWSE：跳動點 NT$0.01 至 NT$5、±10% 漲跌幅、1,000 股為一整股交易單位、自 2020-10-26 起開放盤中零股交易、T+2 交割。來源：TWSE 交易制度。
22. TXO：每點 NT$50、跳動點 0.1 至 10 點、歐式履約、以 30 分鐘平均價結算、交易時段 08:45–13:45 與 15:00–05:00。來源：TAIFEX 規格。
23. TAIFEX 同時發布一般與盤後交易時段的 SPAN 參數檔。來源：TAIFEX 保證金制度頁面。
24. Hyperliquid 每小時支付 8 小時費率的 1/8 作為資金費用，上限為每小時 4%。來源：Hyperliquid 文件。
25. FINRA 4210(g) 評價區間：股票與窄基指數為 ±15%，高市值廣基指數為 +6%/−8%。來源：FINRA Rule 4210。
26. JAX 預設為 32 位元，且原生 Windows 不支援 NVIDIA GPU（WSL2 為實驗性）。來源：JAX 文件。
27. `exchange_calendars` 採 Apache-2.0 且包含 XTAI。來源：GitHub。
28. ORE 15 於 2026-03-04 發布，基於 QuantLib 1.41，ORE 的 README 標示為 Modified BSD。來源：LSEG、GitHub。
29. 在 NumPy 單執行緒下，100 萬口合約的 Black-76 價格加 3 個 greeks 重新量測為 0.066–0.072 秒，與文中所述的約 0.06 秒一致。來源：本機重新執行。

**已更正（11）**

1. 「NautilusTrader 的 21 種商品型別」更正為 `InstrumentAny` 中的 **18** 種具體型別，若計入 `SyntheticInstrument` 則為 19 種。並新增註記：NautilusTrader 2.0 仍處於 RC 階段（2.0.0rc5，2026-09-15）。來源：`crates/model/src/instruments/any.rs`、PyPI。
2. 「ORE 1.8.17.0 的 GitHub release 與 PyPI wheel 日期皆為 2026-09-15」更正為：GitHub release 為 2026-09-15，**PyPI wheel 為 2026-09-14**（17:35 UTC）。來源：GitHub releases API、PyPI JSON。
3. 「tf-quant-finance 已封存」更正為：其 README 宣告「no longer maintained and has been archived」，但 GitHub 儲存庫**並未**被標示為封存（偶有建置相關的提交，持續到 2026-08）。仍將其視為停止維護。來源：GitHub API、README。
4. 「Rateslib 與 FinancePy 都適合研究用途，只有在對外散布的應用程式中才有問題；可作為測試基準使用」更正為：此說法對 FinancePy 成立（GPL，內部使用沒問題）。Rateslib 的免費授權**禁止任何商業／專業用途、用於交易應用程式，以及作為企業程式碼的基準或驗證工具**，因此擔任基準角色需要付費授權。已更新 TL;DR、建議 (a)8 與 (b)6，以及風險一節。來源：Rateslib 授權頁面。
5. 「Portfolio margin：權益 ≥$100k（依券商而定）」更正為：Rule 4210(g) 僅對非上市衍生性商品設定 $5M 下限，約 $100k 以上的最低門檻屬於券商政策。來源：FINRA Rule 4210 原文。
6. 補上遺漏的法規變更：FINRA 以盤中保證金標準取代了型態日內交易者保證金條款（SR-FINRA-2025-017，SEC 於 2026 年 4 月核准，2026-06-04 生效）。這會影響美國的交易前保證金檢查。來源：FINRA Rule 4210、SR-FINRA-2025-017。
7. 「台灣颱風假於當天宣布」更正為：通常在前一晚 22:00 前宣布，有時當天才宣布。來源：zh.wikipedia 颱風假，引用《天然災害停止上班及上課作業辦法》。
8. 新增一項風險：QuantLib 的 `Taiwan` 日曆僅寫死到 2026 年的假日，因此需載入 TWSE/TAIFEX 的 2027 年日程。來源：QuantLib `taiwan.cpp`。
9. Binance 資金費率公式原本不完整，更正為 `[P̄ + clamp(I − P̄, ±0.05%)] / (8/N)`，且間隔可能是 4 小時或 1 小時，而不僅是 8 小時。來源：Binance FAQ。
10. 函式庫比較表內容過時或不完整。新增：vollib 1.0.11 僅支援 Python 3.9–3.13；fast-vollib 0.2.2 新增 SVI/SSVI 與 Heston 曲面擬合，且為單一維護者的 0.x 專案。來源：PyPI。
11. 補上遺漏的選項：新增「購買而非自建」註記，涵蓋情境 (b) 的商業 IV 曲面資料與定價函式庫。

**無法驗證（5）**

1. CME SPAN 2 的遷移狀態（「正轉向以 VaR 為基礎的 SPAN 2」）。CME 頁面封鎖了自動化存取，且本輪無法使用網路搜尋。
2. 本機測試中，向量化 Newton 法在 100 萬口隨機合約中約 96% 收斂的結果。該結果取決於抽樣分布，且未重新執行。
3. 典型券商的投資組合保證金最低門檻（約 $100k 以上）屬於一般市場常識，並未逐一向券商查證。
4. 「購買而非自建」註記中提到的商業供應商（ORATS、OptionMetrics IvyDB、Cboe LiveVol、Numerix）來自一般知識，其產品與價格並未逐一查證。
5. Rateslib 債券慣例屬「一流（best-in-class）」是編輯判斷，並非可查核的事實。
