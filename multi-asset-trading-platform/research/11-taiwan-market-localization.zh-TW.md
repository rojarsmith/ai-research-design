[English](11-taiwan-market-localization.md) | **繁體中文**

# 台灣市場連線與在地化

*多資產（股票、加密貨幣、債券、選擇權）分析、回測與交易平台的研究面向 11。範圍：台灣股票（TWSE/TPEx）、TAIFEX 期貨與選擇權、台灣債券管道，以及台灣加密貨幣交易所。事實查核截至 2026-10-05。相關文件：[02 回測引擎](02-backtesting-engine.zh-TW.md)。*

## TL;DR

- **「台灣券商 API 只能在 Windows 上執行」的問題，現在主要只存在於第二線 API。** 三家主要券商已支援 Linux：
  - 永豐（SinoPac）**Shioaji**（版本 1.7.7，2026-09-29 發布）提供 Linux、macOS 與 Windows 的 wheel。它以 Rust 為核心，並內建本機 HTTP + SSE 伺服器，因此非 Python 的服務也能使用。
  - **富邦 Fubon Neo** 在 Windows、macOS 與 Linux 上支援 Python、C# 與 Node.js。C++ 與 Go 僅涵蓋證券。自 SDK v2.2.8 起，憑證可從網頁入口匯出，因此取得憑證不再需要 Windows 工具。
  - **元大 Yuanta SPARK** 建構於 .NET 8 之上，可在 Linux x64 上執行。

  群益（Capital）SKCOM 與凱基（KGI）`kgiapp` 仍是 Windows COM / .NET Framework。應將 Windows 閘道規劃為**選用外掛（optional plug-in）**，而不是核心設計。
- **先以 Shioaji 作為主要的台灣券商，再加入 Fubon Neo 作為第二家。** Shioaji 有強制性的模擬環境、細粒度的 API 金鑰、公開的速率限制，以及 14 天的發版週期。富邦則提供 DMA/IDC 選項與 Fugle 等級的行情資料。只有在需要海外期貨或複委託下單路由時，才加入群益（透過 Windows 閘道）。
- **免費的官方 OpenAPI 只涵蓋盤後與參考資料。** TWSE 有 143 個端點、TPEx 有 225 個、TAIFEX 有 135 個。即時資料來自券商或 Fugle（每月 NT$1,499–2,999）。歷史逐筆（tick）資料來自 FinMind 的付費方案（研究用途已足夠），或來自 TWSE 資料商品網（Data E-Shop）（權威來源，五檔委託簿資料每資料月 NT$5,000 起）。
- **台灣在回測器與風控引擎中都需要一套專屬的規則包。** 它必須涵蓋：
  - ±10% 漲跌幅限制、開盤與收盤集合競價，以及 3.5% 的盤中瞬間價格穩定措施（volatility interruption）；
  - 每 5 秒一次的零股集合競價；
  - 處置股與暫停先賣後買當沖；
  - 0.3%/0.15% 的證券交易稅（證交稅）與期貨交易稅（期交稅），以及債券與債券 ETF 的免稅期，除非延長，否則於 2026-12-31 結束；
  - 夜盤的交易日歸屬；
  - 於星期三或星期五到期的 TXO 週選擇權。
- **債券與加密貨幣大多不在券商 API 的範圍內。** 對散戶投資人而言，台灣的債券曝險實務上是指債券 ETF，以及沒有 API 的複委託或銀行櫃檯（OTC）債券。新台幣加密貨幣交易所（MAX、BitoPro）有完善的 REST 與 WebSocket API。然而，**《虛擬資產服務法》已於 2026-06-30 通過**，最快於 2027 年第一季施行。因此交易所是否合格必須以設定（configuration）表達，而不是寫死在程式碼中。

## 關鍵問題

1. 哪些台灣券商可以由 Linux／容器化的核心驅動，哪些需要 Windows 主機？
2. 哪些資料來源提供 TWSE/TPEx/TAIFEX 的即時、歷史逐筆與參考資料，費用為何？
3. 回測器與下單前風控檢查必須模擬哪些台灣市場規則，才能避免虛假的損益？
4. 台灣散戶投資人實際上能交易哪些債券，透過什麼管道？
5. 哪些台灣加密貨幣交易所有可用的 API，2026 年的 VASP 法又如何改變交易對手風險？
6. 憑證、API 金鑰、IP 白名單與個人登入憑據（credentials）應如何處理——無論是自用，或平台日後為其他人提供服務時？

## 方案比較

### 1. 台灣券商交易 API

| 券商 / API | 程式語言 | 作業系統 | 商品 | 開戶與驗證 | 模擬 | 限制 / 維護訊號 |
|---|---|---|---|---|---|---|
| **永豐 SinoPac Shioaji** | 建構於 Rust 核心之上的 Python 原生繫結（binding）。任何語言都可透過本機 HTTP API（`localhost:8080`，附 OpenAPI 文件與 SSE 串流）與 CLI 使用 | Windows x64、macOS x64/ARM64、Linux x64/ARM64（glibc wheel）。Python 3.7–3.14 | 台股（含盤中零股）、期貨、選擇權、組合單 | 開戶後，以電子方式簽署證券與期貨 API 條款，再通過**強制性模擬測試**（登入與下單）。API 金鑰具權限範圍、有效期限與 **IP 白名單**。CA `.pfx` 可從跨平台入口網站下載；`activate_ca()` | 有（`simulation=True`）。不支援零股或興櫃股票下單 | 資料查詢 50 次/10 秒；帳務查詢 25 次/5 秒；下單操作 250 次/10 秒；200 個訂閱；每個身分證字號 5 個同時連線；每日 1,000 次登入。超過速率限制會暫停服務 1 分鐘。每日流量上限 500 MB–10 GB，依交易量級距調整（08:00 重置）。**v1.7.7 於 2026-09-29 發布，14 天發版週期**。1.7.6 已被撤回（yanked），且 1.5.x 系列仍於 2026-08-13 收到修補，因此請鎖定確切版本 |
| **富邦新一代 API（Fubon Neo）**，與 Fugle 合作打造 | Python 3.8–3.13、C#（.NET Standard 2.0）、Node.js ≥16。C++ 與 Go 僅涵蓋證券交易、帳務與條件單 | Windows、macOS、Linux SDK（Python 與 C#：x86-64，macOS 與 Linux 另有 ARM64）。自 SDK v2.2.8 起，憑證可**從網頁金鑰管理入口匯出**供跨平台使用，因此僅限 Windows 的 TCEM.exe 不再是唯一途徑。連線測試輔助工具仍只發布 Windows 版本 | 台股（含信用交易）、期貨/選擇權、條件單。行情資料透過 Fugle 建置的 Web API 與 WebSocket 提供 | 開戶、線上風險預告、憑證、連線測試。**API 金鑰登入（SDK ≥ v2.2.7），具 IP 白名單、有效期限、依範圍授權，最多 30 組金鑰**（2026-05 公告） | **提供測試環境**（可下載的測試環境套件；目前僅有證券測試帳號），另需通過強制性的連線測試 | 交易：每秒 50 筆委託、每秒 10 筆批次委託、每秒 5 次帳務查詢，最多 10 個連線。行情資料：盤中每分鐘 300 次、歷史每分鐘 60 次。WebSocket：300 個訂閱 × 7 個連線。DMA/IDC 路由（2025-07）。2026-05 新增 Go。SDK v2.4.0 |
| **元大 Yuanta SPARK API** | C# 與 Python（透過 .NET 8 上的 `pythonnet`）。COM、Delphi 與 WPF 元件僅維護、不再新增功能 | Windows x64/x86、macOS ARM64/x64、Linux x64 | 台股、國內期貨、雲端條件單、報價 | 簽署風險預告書，接著進行 API 測試並上傳結果，然後下載元件。測試與正式環境的憑證分開 | **UAT 環境**（需由你的營業員申請固定 IP 防火牆核准） | 速率限制未公開。新功能僅推出 Python 與 C# 版本 |
| **群益 Capital SKCOM**，CapitalAPI 2.13.x | C#、C++、VB，以及透過 COM 的 Python | **僅限 Windows**。需註冊 COM DLL；程序的位元數必須與 DLL 相符 | 台股、TAIFEX 期貨/選擇權、**海外期貨、海外股票（複委託）** | 在 App 或網站上簽署 API 聲明書，然後使用憑證 | 未公開說明 | 商品涵蓋最廣。社群龐大，範例眾多 |
| **凱基 KGI `kgiapp`** | 基於 .NET Framework 4.5 的 Python 包裝 | **僅限 Windows** | 股票 / 期貨 | 透過分公司營業員設定 | n/a | PyPI 2.0.4 為最新版；**最後上傳於 2024-11-17**。社群回報文件品質不佳 |
| 其他：國泰（Cathay）、兆豐（Mega）、統一期貨（President Futures）、台新（Taishin，已於 2026-04-06 合併元富 Masterlink）等 | 多為 DLL/COM。元富的 API（由 Fugle 打造，2025-01）提供 Python、Node.js 與 C#。請確認合併後在台新旗下是否維持不變 | 多為 Windows（第三方下單工具僅將其列為 Windows 32/64 位元）。前元富 API 為跨平台 | 多以期貨為主 | 憑證，另需獨立的 API 申請 | 不一 | 僅在已於該券商開戶時使用 |

API 交易成長迅速。截至 2024 年 10 月，全市場 API 交易金額已達新台幣 636 億元，而 2023 年為新台幣 506 億元，成長 26%（鉅亨網 cnyes，2025-01-03）。該文章並未說明這是日均值還是期間總額。

### 2. 行情資料來源

| 來源 | 內容 | 即時？ | 費用（2026） | 適用情境 |
|---|---|---|---|---|
| **TWSE OpenAPI**（`openapi.twse.com.tw/v1`） | 143 個端點。每日行情、本益比、融資融券餘額、零股行情、當沖標的（TWTB4U）、暫停先賣後買（TWTBAU1）、處置與注意股票、休市日程、財務報表、ESG | 否（盤後／定期） | 免費，無需驗證 | 參考資料與交易日曆 |
| **TPEx OpenAPI**（`tpex.org.tw/openapi/v1`） | 225 個端點。上櫃行情、零股、當沖清單、**債券發行（政府、公司、金融、國際／寶島債）**、國際債券盤中報價 | 否 | 免費 | 上櫃股票與債券參考資料 |
| **TAIFEX OpenAPI**（`openapi.taifex.com.tw/v1`） | 135 個端點。期貨／選擇權每日報表、**每日逐筆成交（TimeAndSalesData、OptionsTimeAndSalesData）**、法人與大額交易人未平倉量、保證金、最後結算價、部位限制 | 否 | 免費 | 衍生性商品盤後資料與每日逐筆 |
| **券商行情**（Shioaji、Fubon/Fugle） | 即時逐筆與買賣報價、盤中 K 棒、快照 | 是 | 開戶即免費。依交易量分級設上限 | 實盤交易。不得轉發散布 |
| **Fugle MarketData** | 台灣上市、上櫃與興櫃股票、指數、ETF/ETN、權證；期貨／選擇權歷史資料。股票日 K 自 2010 年起（指數自 2015 年起）；**股票分 K 僅自 2023-05-23 起**；期貨日 K 自 2010 年起、分 K 自 2017-06 起 | 是（WebSocket） | 免費（5 個訂閱）／Developer 每月 NT$1,499（300 個訂閱、每分鐘 600 次呼叫）／Advanced 每月 NT$2,999（2,000 個訂閱）。用戶端 `fugle-marketdata` 2.7.0（MIT，2026-09-30） | 不依附券商的即時行情 |
| **FinMind** | 50 個以上的資料集。**股票逐筆自 2018-12-07 起；期貨／選擇權逐筆自 2011-01-03 起**；股票 K 棒自 2019 年起 | 否 | 使用免費 token 每小時 600 次請求。逐筆資料需 backer/sponsor 方案；SponsorPro 另提供全日 Parquet 下載。用戶端 2.0.11（Apache-2.0，2026-10-04） | 低成本的研究用歷史資料 |
| **TEJ** | 機構級基本面資料與還原股價。TQuant Lab（`zipline-tej` 2.2.2，Apache-2.0，2025-11-25） | 否 | 付費訂閱（價格需洽詢） | 時點正確（point-in-time）的基本面資料，團隊等級 |
| **TWSE 資料商品網（Data E-Shop）** | 15 年以上的全市場歷史資料。**含五檔委託簿的盤中資料每月 NT$5,000**；委託簿日誌 NT$10,000；含委託類別的盤中資料 NT$10,000；盤中零股資料 NT$1,500 | 否（歷史資料） | 依資料月計價 | 供執行研究使用的權威 L2 資料 |
| **XQ（嘉實）／CMoney** | 封閉的散戶終端，具腳本功能（XScript）與籌碼資料 | 是，在終端內 | 散戶訂閱 | 僅適合構想原型驗證。不適合作為整合骨幹 |

### 3. 市場規則及其對引擎的影響

| 規則（查證來源見參考資料） | 對回測引擎的影響 | 下單前風控檢查 |
|---|---|---|
| 交易時段：08:30 起接受委託；**開盤集合競價**；連續交易 09:00–13:25（自 2020 年 3 月起）；**收盤集合競價 13:25–13:30**。盤後定價交易 14:00–14:30 | 開盤與收盤以集合競價價格成交，而不是第一筆或最後一筆逐筆價格。各交易時段分別建模 | 在不允許市價單的集合競價階段阻擋市價單 |
| **±10% 每日漲跌幅限制**（新上市股票前 5 日無漲跌幅限制；公司債 ±5%；政府債券無限制） | 漲跌停鎖死的日子無法交易。在漲跌停價依排隊順位成交的機會很少，因此不要假設能成交 | 拒絕價格超出漲跌幅區間的委託 |
| **盤中瞬間價格穩定措施**：價格偏離 5 分鐘均價超過 3.5% 時，觸發 2 分鐘暫停，之後進行集合競價 | 延後成交並重新競價；剩餘的市價、IOC 與 FOK 委託會被取消 | 對波動劇烈個股的市價單發出警告 |
| 升降單位：股票為 0.01 / 0.05 / 0.10 / 0.50 / 1 / 5，價格分界點為 10 / 50 / 100 / 500 / 1,000。ETF 在 NT$50 以下為 0.01，以上為 0.05 | 依商品類別的升降單位表將價格取整 | 驗證價格是否符合升降單位 |
| 一張（整股交易單位）= 1,000 股。**盤中零股**：09:00–13:30，09:10 首次撮合，之後**每 5 秒定期集合競價**。盤後零股：13:40–14:30 | 獨立的零股委託簿。不要以整股價格撮合零股 | 將數量單位（張 vs 股）視為有型別的欄位 |
| **當沖**：帳戶需開立 ≥3 個月且有 ≥10 筆成交。先賣後買當沖可能依個股暫停（TWTBAU1）。處置股會改為變更交易方式：分盤集合競價撮合、不接受市價單，並需預收款券（門檻依處置等級而定） | 每日標記當沖資格。處置股的撮合方式不同 | 對暫停的個股阻擋先賣後買；對處置股阻擋市價單並要求預收款券 |
| **稅費**：賣出時課徵證券交易稅 0.3%；**股票當沖 0.15%，至 2027-12-31 止**（證券交易稅條例第 2-2 條；TWSE 英文網頁仍寫 2024-12-31）；ETF 0.1%。債券：政府債券依法免稅。**公司債、金融債券與債券 ETF（槓桿型與反向型除外）僅在 2026-12-31 前免稅**（第 2-1 條）。之後除非法律延長，否則恢復為法定的 0.1%。手續費每邊 ≤0.1425%（券商會給予折扣）。期貨交易稅向**買賣雙方**課徵：股價指數期貨為契約金額的 0.002%，選擇權為權利金的 0.1%。這些是行政院在法定範圍內核定的適用稅率。履約時以現金結算的選擇權，依期貨稅率就結算金額課稅 | 成本模型必須依買賣方向與交易類型而定（是否為當沖要到收盤時才確定） | 下單前預估成本 |
| 現股 **T+2 交割**；期貨每日結算（mark to market） | 現金帳本區分 T+2 已交割金額與可用購買力 | 購買力 = 已交割現金 + 券商信用額度 |
| **TAIFEX**：TX 每點 NT$200、MTX 每點 NT$50、TMF 每點 NT$10，TXO 權利金採階梯式升降單位。日盤 08:45–13:45（到期契約於最後交易日 13:30 收盤）；**夜盤 15:00–05:00**。交割月份契約於最後交易日沒有盤後交易時段，但其他月份契約照常交易。月契約於第三個星期三到期；**TXO 週選擇權於星期三或星期五到期** | 夜盤交易歸屬於**下一個交易日**。日曆必須區分交易日與實際日期（wall-clock date）。週到期契約需要獨立的代碼規則 | 保證金與部位限制（來自 TAIFEX OpenAPI）。接近到期時不建立新部位 |
| 臨時休市（例如颱風假） | 使用交易所的休市日端點加上手動覆寫，絕不使用靜態日曆 | 交易時段狀態未知時啟動緊急停止開關（kill switch） |

### 4. 四大資產類別在此面向的差異

| | 股票（TWSE/TPEx） | 選擇權與期貨（TAIFEX） | 債券 | 加密貨幣（台灣交易所） |
|---|---|---|---|---|
| 連線方式 | 券商 API（Shioaji、富邦、元大） | 同一批券商，但期貨需要獨立帳戶與 API 簽署 | **沒有專門的散戶債券 API**。TWSE 上市的政府債券與 TPEx 自營商（dealer）市場（以機構為主）；外國債券透過複委託或銀行。例外：TPEx 上櫃的**可轉債**透過一般證券帳戶交易，因此請確認你的券商 API 是否接受可轉債委託 | 交易所 REST/WebSocket，使用 HMAC 金鑰；中間沒有券商 |
| 資料 | 免費盤後資料；逐筆需付費 | 免費每日逐筆（TAIFEX OpenAPI）；歷史資料需付費 | 發行與參考資料（TPEx）；債券 ETF 的交易方式與股票相同 | 免費公開的逐筆與委託簿 |
| 特殊規則 | 漲跌幅限制、集合競價、零股、當沖稅率 | 夜盤、週到期、保證金、部位限制 | 應計利息、政府債券無漲跌幅限制。政府債券免稅；公司債、金融債券與債券 ETF 僅在 2026-12-31 前免稅 | 24/7 交易、新台幣出入金、VASP 牌照 |
| 驗證 | 個人憑證 + API 金鑰 + IP 白名單 | 同上 | 手動 | API 金鑰（+ IP 白名單） |
| 建議處理方式 | 一級（first-class）自動化支援 | 一級支援（台灣最大的散戶衍生性商品市場） | **債券 ETF 視同股票；直接持有的債券以手動記帳的部位處理** | 每個交易所一個轉接器（adapter），牌照狀態以設定保存 |

### 5. 台灣加密貨幣交易所

| 交易所 | API | 涵蓋範圍（公開端點，2026-10-05） | 備註 |
|---|---|---|---|
| **MAX（MaiCoin）** | REST v2/v3 + WebSocket；v3 新增 M-wallet（保證金）端點 | 82 個市場：45 個以新台幣報價、36 個以 USDT 報價；6 個支援保證金 | 最大的新台幣流動性池。文件網站會阻擋機器人（HTTP 403） |
| **BitoPro** | REST v3 + WebSocket；HMAC-SHA384；官方 Go 與 Python SDK | 35 個交易對，其中 19 個為新台幣 | 每個 IP 與每個帳戶每分鐘 600 次請求。v2 已淘汰 |
| **ACE（王牌）** 及其他本地 VASP | REST | 我們測試時無法連上公開 API | 優先順序低；請確認該交易所已完成登記 |
| 全球交易所（Binance、OKX…） | 成熟的 API | 深厚的 USDT 流動性 | 必須依洗錢防制制度在本地完成登記（自 2024-11-30 起施行）。VASP 法施行後須依法取得牌照 |

監管：目前有 8 家 VASP 完成洗錢防制登記。VASP 法帶來七類須取得許可的服務、12 個月的申請期與 21 個月的取得牌照期限，無照經營最高可處 7 年有期徒刑／新台幣 1 億元。穩定幣發行需經金管會與中央銀行雙重核准，並須 100% 準備。

## 建議

### (a) 個人／1–3 人 MVP

1. **一開始只使用 Shioaji 作為唯一的台灣券商。** 在 Linux 核心中以原生方式執行（Python），或在核心不是 Python 時以 sidecar 方式執行（`shioaji server start` 會開放 HTTP/SSE）。先完成強制性模擬測試，再以 `simulation=True` 進行模擬交易（paper trade）。
2. **將 Fubon Neo 保留為有文件記載的備援方案。** 它的 Linux SDK 代表不需要額外的基礎設施。略過群益與凱基，因此 **MVP 中沒有 Windows 閘道**。
3. **資料堆疊：** 使用 TWSE/TPEx/TAIFEX OpenAPI 取得參考資料、交易日曆、處置名單與 TAIFEX 每日逐筆。加上 FinMind 贊助方案取得股票與期貨／選擇權的歷史逐筆，即時資料則來自券商行情。只有在需要券商連線時段以外的報價，或需要在另一台機器上取得報價時，才加購 Fugle Developer（每月 NT$1,499）。
4. **撰寫台灣規則包**（漲跌幅限制、集合競價、升降單位、零股、稅費、夜盤交易日），作為回測器與風控引擎共用的資料驅動設定。稅率與到期日放在設定中，而不是程式碼中。
5. **債券：** 將債券 ETF（00679B 等）視同股票支援，並將其 0% 交易稅保存為一條附日期的規則，除非延長，否則於 2026-12-31 失效。外國或複委託債券以手動記帳。可轉債若券商 API 支援，可以比照交易所掛牌商品處理。**加密貨幣：** 新台幣交易使用 MAX。**美股／美股選擇權：** 直接連接美國券商，而不是透過台灣複委託；除了群益之外，複委託沒有主流的 API。

### (b) 5–20 人團隊或機構等級

1. **使用與券商無關（broker-agnostic）的閘道層：** 每家券商一個閘道，全部位於相同的內部委託／成交／報價契約（gRPC 或 NATS）之後。Shioaji、富邦與元大 SPARK 在 Linux 容器中執行。群益 SKCOM（海外期貨與複委託）及任何舊式 DLL 券商在 **Windows Server VM** 上執行。
2. **延遲分級：** 對延遲敏感的期貨策略使用富邦 DMA/IDC 路由或券商主機共置（co-location）。其他一切都透過網際網路使用 API，並搭配 IP 白名單所要求的固定對外 IP（static egress IP）。
3. **授權資料：** 購買 TWSE 資料商品網的五檔委託簿與委託簿日誌，以及 TAIFEX 歷史資料，用於執行研究。使用 TEJ 取得時點正確的基本面資料。以書面記錄資料授權條款，因為券商行情一般不得轉發散布。
4. **憑證平台：** 以 vault 為後端的憑證與 API 金鑰儲存庫，具備到期提醒、雙人控管與以個人為單位的權限範圍（見下文）。
5. **法遵：** 加密貨幣交易對手白名單由金管會（FSC）VASP 登記名冊驅動。若平台將來為其他人執行交易或提供建議，在開發多租戶功能*之前*，應先就證券投資顧問（投顧）執照與券商 API 條款進行法律審查，因為憑證屬於個人。

## 對整體架構的影響

- **閘道模式。** 跨平台核心絕不直接連結券商 DLL。每個券商轉接器都以獨立程序執行，帶來：
  - 故障隔離，因為 COM 當機與記憶體洩漏都會留在轉接器內；
  - 各自的速率限制器，以 token bucket 對應公開的限制；
  - 工作階段與重新連線邏輯，包括登入次數上限（例如每日 1,000 次登入）；
  - 正規化為標準（canonical）的委託與商品模型。

  Windows 轉接器在常駐的桌面工作階段中執行（部分 COM API 需要訊息迴圈（message pump）或會跳出對話框）。它們需要看門狗（watchdog）、在 08:30 與 15:00 之前排程重新啟動，以及相符的 32/64 位元建置。核心只透過網路與它們通訊。
- **憑證與金鑰。** 台灣券商憑證（`.pfx`）屬於**個人**，通常以持有人的身分證字號命名，並以密碼保護。
  - 將憑證與密碼存放在機密管理系統（Vault、雲端 KMS，或閘道主機上的 Windows DPAPI），絕不放進映像檔或 Git。
  - 只在執行期將其掛載到對應的轉接器。
  - 追蹤到期日，並提前 30 天發出警示。
  - 給予 API 金鑰最小的權限範圍（資料／帳務／交易），並將閘道的固定 IP 加入白名單。
- **商品主檔與代碼規則。** 使用 `venue + local code`（交易場所 + 本地代碼）作為鍵值：
  - 股票如 `2330`，以及槓桿型 ETF 如 `00631L`；
  - TAIFEX 商品根代碼（TXF/MXF/TMF/TXO）加上月份或週別代碼；
  - 加密貨幣交易對。

  將交易單位大小、升降單位表、漲跌幅制度、稅務類別、當沖資格與處置標記，作為每日從 TWSE/TPEx/TAIFEX OpenAPI 更新的屬性附加上去。
- **日曆服務。** 使用 Asia/Taipei 時區（無日光節約時間），並為夜盤區分交易日與實際日期。從交易所 API 載入休市日，並允許手動覆寫以處理颱風休市。加密貨幣採用 24/7 日曆。
- **帳本。** 追蹤股票的 T+2 交割、期貨的每日結算、以新台幣為基準貨幣並以匯率換算美國資產，以及以有型別的數量區分張與股。

## 風險與陷阱

- **模擬 ≠ 正式環境。** Shioaji 的模擬器會拒絕零股與興櫃股票委託，而富邦的測試環境目前只提供證券測試帳號，沒有期貨。請以最小的真實委託測試零股與期貨邏輯。
- **無聲的資料斷供。** 超過 Shioaji 流量上限時，報價查詢會回傳*空值*而不是錯誤，且上限會隨你的交易量調整。應將空回應視為警報，而不是「沒有成交」。
- **速率限制封鎖。** 重複違反 Shioaji 速率限制可能導致 IP 與帳戶 ID 同時被停權。請在用戶端進行節流。
- **過時的官方文件與即將到期的租稅優惠。** TWSE 英文網頁仍顯示當沖減稅於 2024-12-31 結束，但法律現已延長至 2027-12-31。債券與債券 ETF 的免稅期於 2026-12-31 結束。每年依法規資料庫重新查核稅率與到期規則，並以附日期的設定保存。
- **券商合併與整合中斷。** 元富已於 2026-04-06 併入台新證券。據報導，2026-04-14 的系統整合故障隨後造成大規模成交回報中斷，以及約 9,000 筆錯誤委託。請獨立地與券商核對委託與成交，並在任何券商合併後重新確認 API 的延續性。
- **Windows 閘道的脆弱性。** COM API 可能跳出強制回應對話框、依賴登錄檔註冊與位元數，並可能因 Windows 更新而失效。請鎖定版本並加入健康檢查探針。
- **透過 Fugle 技術堆疊造成的廠商鎖定。** Fubon Neo 與前元富 API（現屬台新）都依賴 Fugle，因此單一廠商事故可能同時影響兩家券商。請保留 Shioaji 作為獨立路徑。
- **個人憑證阻礙多租戶。** 你在法律上不能集中他人的登入憑據，也不能透過你的帳戶轉送他們的委託。若要提供服務，需要的是牌照方面的工作，而不只是工程。
- **加密貨幣監管過渡期（2027–2028）。** 交易所在申請牌照期間可能失去合格性。未在本地登記的外國交易所在台灣有刑事責任風險。
- **債券流動性不足。** 銀行與複委託的債券價格是參考性的 OTC 報價。不要把它們當作可成交價格來回測債券策略。

## 參考資料

- Shioaji PyPI 頁面（1.7.7，2026-09-29，支援平台）： https://pypi.org/project/shioaji/
- Shioaji 文件總覽： https://sinotrade.github.io/
- Shioaji 使用限制： https://sinotrade.github.io/tutor/limit/
- Shioaji 開戶準備／條款與模擬測試： https://sinotrade.github.io/tutor/prepare/terms/
- Shioaji API 金鑰與 CA： https://sinotrade.github.io/tutor/prepare/token/
- Shioaji 模擬模式： https://sinotrade.github.io/tutor/simulation/
- Shioaji README（HTTP API、SSE、CLI）： https://cdn.jsdelivr.net/gh/Sinotrade/Shioaji@master/README.md
- Fubon Neo API 介紹： https://www.fbs.com.tw/TradeAPI/docs/trading/introduction
- Fubon Neo 開戶準備： https://www.fbs.com.tw/TradeAPI/docs/trading/prepare
- 富邦期貨 API： https://www.fbs.com.tw/TradeAPI/docs/trading-future/introduction
- 富邦行情資料介紹與速率限制： https://www.fbs.com.tw/TradeAPI/docs/market-data/intro , https://www.fbs.com.tw/TradeAPI/docs/market-data/rate-limit
- 富邦安裝與相容性（各語言的作業系統／架構）： https://www.fbs.com.tw/TradeAPI/docs/install-compatibility
- 富邦 SDK 下載與變更紀錄（v2.4.0，測試環境說明）： https://www.fbs.com.tw/TradeAPI/docs/download/download-sdk
- 富邦金鑰管理與網頁憑證匯出（v2.2.8+）： https://www.fbs.com.tw/TradeAPI/docs/key/ , https://www.fbs.com.tw/TradeAPI/docs/trading/api-key-apply
- 富邦測試環境（僅證券測試帳號）： https://www.fbs.com.tw/TradeAPI/docs/welcome/
- 富邦交易速率限制： https://www.fbs.com.tw/TradeAPI/docs/trading/trade-rate-limit
- 富邦 Go + API Key 升級（2026-05-11）： https://www.taiwannews.com.tw/zh/news/6359399
- 富邦 × Fugle 新一代 API，DMA/IDC（2025-07-17）： https://www.taiwannews.com.tw/zh/news/6158263
- 元大 SPARK API 入口網站： https://www.yuanta.com.tw/file-repository/content/API/page/index.html
- 元大 SPARK Python 設定（.NET 8、pythonnet）： https://www.yuanta.com.tw/file-repository/content/sparkapi_docs/2.Python%E8%A8%AD%E5%AE%9A/Windows%E3%80%81Mac%E7%B3%BB%E7%B5%B1/index.html
- 群益 API Python SDK（CapitalAPI 2.13.58，Windows COM）： https://github.com/AlexChiang0208/capital_api
- 群益期貨 API 申請： https://www.topbroker.tw/blog.php?act=view&id=61
- 凱基 kgiapp PyPI 頁面： https://pypi.org/project/kgiapp/
- 第三方券商 API 作業系統／位元數清單： https://www.order-master.com/docs/t03/
- 券商 API 網站清單（2026-08）： https://www.threads.com/@finance_cat/post/DblSTnGCAgh/
- API 交易量與元富 API（2025-01-03）： https://news.cnyes.com/news/id/5825158
- 元富併入台新證券（2026-04-06）與 2026-04-14 的中斷事件： https://zh.wikipedia.org/zh-tw/元富證券 , https://zh.wikipedia.org/zh-tw/台新綜合證券
- TWSE OpenAPI 規格： https://openapi.twse.com.tw/v1/swagger.json
- TPEx OpenAPI 規格： https://www.tpex.org.tw/openapi/swagger.json
- TAIFEX OpenAPI 規格： https://openapi.taifex.com.tw/swagger.json
- TWSE 交易制度（交易時段、漲跌幅、升降單位、零股、T+2、稅費）： https://www.twse.com.tw/en/products/system/trading.html
- TWSE 當日沖銷規則： https://www.twse.com.tw/en/products/system/day-trading.html
- TWSE 資料商品網歷史資料商品： https://eshop.twse.com.tw/en/category/sub/42
- TAIFEX TXO 規格（週三／週五週選擇權、夜盤）： https://www.taifex.com.tw/enl/eng2/tXO
- TAIFEX TX 與 TMF 規格： https://www.taifex.com.tw/enl/eng2/tX , https://www.taifex.com.tw/enl/eng2/tMF
- 臺灣證券交易所沿革（2020 年連續交易、5 秒零股撮合）： https://en.wikipedia.org/wiki/Taiwan_Stock_Exchange
- 當沖稅延長至 2027 年： https://zh.wikipedia.org/zh-tw/當日沖銷
- 證券交易稅條例（第 2-1 條債券／債券 ETF 免稅至 2026-12-31；第 2-2 條當沖 0.15% 至 2027-12-31）： https://law.moj.gov.tw/LawClass/LawAll.aspx?pcode=G0340078
- 期貨交易稅條例（法定範圍、買賣雙方皆課稅）： https://law.moj.gov.tw/LawClass/LawAll.aspx?pcode=G0340079
- FinMind 文件、限制與逐筆資料集： https://finmind.github.io/quickstart/ , https://finmind.github.io/tutor/TaiwanMarket/Technical/ , https://finmind.github.io/tutor/TaiwanMarket/Derivative/
- FinMind / fugle-marketdata / zipline-tej / tejapi 的 PyPI 頁面： https://pypi.org/project/finmind/ , https://pypi.org/project/fugle-marketdata/ , https://pypi.org/project/zipline-tej/ , https://pypi.org/project/tejapi/
- Fugle MarketData 價格方案： https://developer.fugle.tw/docs/pricing
- Fugle 歷史 K 線涵蓋範圍（股票分 K 自 2023-05-23 起）： https://developer.fugle.tw/docs/data/http-api/historical/candles
- BitoPro API 文件： https://github.com/bitoex/bitopro-offical-api-docs
- MAX 公開市場端點： https://max-api.maicoin.com/api/v2/markets
- BitoPro 交易對端點： https://api.bitopro.com/v3/provisioning/trading-pairs
- VASP 法（理律法律事務所 Lee and Li）： https://www.leeandli.com/EN/NewslettersDetail/7658.htm
- VASP 法解析（動區 BlockTempo）： https://www.blocktempo.com/taiwan-virtual-asset-act-third-reading-explainer-vasp-stablecoin-licensing/
- VASP 法與洗錢防制登記制度（TRM Labs）： https://trmlabs.com/resources/blog/unpacking-taiwans-virtual-asset-service-act-what-crypto-and-stablecoin-issuers-need-to-know

## 查核紀錄（2026-10）

於 2026-10-05 針對官方文件、PyPI JSON、交易所 OpenAPI 規格、線上公開端點與全國法規資料庫進行了對抗式事實查核。共檢查 39 項：26 項確認、7 項更正、6 項無法查證。

**已確認**

1. Shioaji 1.7.7（2026-09-29）。其 wheel 為 cp37-abi3 加上 cp314t，支援 Windows x64、macOS x64/ARM64 與 Linux x64/ARM64。README 載明 14 天的發版週期（PyPI JSON 與 README）。
2. Shioaji 限制：資料查詢 50 次/10 秒、委託 250 次/10 秒、200 個訂閱、每個身分證字號 5 個連線，以及每日 1,000 次登入。流量上限依交易量級距為 500 MB–10 GB，超過時報價查詢會回傳空值（tutor/limit）。
3. Shioaji 本機 HTTP API 執行於 `localhost:8080`，OpenAPI 文件位於 `/docs`，並支援 SSE 串流與 `shioaji server start`（README）。文件網站也確認其為 Rust 核心。
4. Shioaji 開戶流程：證券與期貨分開簽署、強制性的登入與下單測試、API 金鑰的權限範圍、有效期限與 IP 白名單，以及跨平台的 CA 下載。模擬器不支援零股或興櫃股票委託。
5. Fubon Neo：在 Windows、macOS 與 Linux 上支援 Python 3.8–3.13、C#（.NET Standard 2.0）與 Node.js ≥16。C++ 與 Go 僅支援證券交易、帳務與條件單（介紹頁面）。
6. 富邦於 2026-05-11 宣布支援 Go，以及具 IP 限制與依功能授權的 API 金鑰登入（Taiwan News）。
7. 富邦行情資料：盤中每分鐘 300 次、歷史每分鐘 60 次、300 個訂閱 × 7 個 WebSocket 連線。DMA/IDC 路由於 2025-07-17 宣布。
8. 元大 SPARK 可在 Windows x64/x86、macOS ARM64/x64 與 Linux x64 上執行，基於 .NET 8 與 pythonnet。COM、Delphi 與 WPF 僅維護。UAT 需要固定 IP 防火牆核准，且測試與正式憑證分開。
9. `kgiapp` 2.0.4 於 2024-11-17 上傳，目標為 .NET Framework 4.5，並被分類為僅限 Windows（PyPI）。
10. TWSE 資料商品網價格：五檔盤中資料每月 NT$5,000、委託簿日誌 NT$10,000、零股資料 NT$1,500。
11. TAIFEX OpenAPI 有 135 個路徑，包括 `/TimeAndSalesData` 與 `/OptionsTimeAndSalesData`（期貨與選擇權的每日逐筆成交）。TWSE 規格有 143 個路徑、TPEx 規格有 225 個，皆由 swagger 檔案計算而得。
12. 所列端點皆存在：TWTB4U、TWTBAU1、休市日程、處置與注意股票、TPEx 債券發行與國際債券報價，以及 TAIFEX 保證金、最後結算價與部位限制。
13. Fugle 方案：免費（5 個訂閱）、Developer 每月 NT$1,499（300 個訂閱、每分鐘 600 次呼叫）與 Advanced 每月 NT$2,999（2,000 個訂閱）。
14. TXO：週選擇權於星期三或星期五到期。夜盤為 15:00–05:00，交割月份契約於最後交易日沒有盤後交易時段。內文已釐清其他月份契約仍照常交易。
15. VASP 法：2026-06-30 三讀通過。最快於 2027 年第一季施行，施行日期由行政院訂定。既有的 VASP 有 12 個月可提出申請、21 個月內須取得牌照（可再延長 3 個月）。法案定義七類服務。無照經營最高可處 7 年／新台幣 1 億元。穩定幣需經金管會與中央銀行雙重核准，並須十足準備（TRM Labs、Lee and Li、BlockTempo）。
16. 洗錢防制登記制度自 2024-11-30 起施行，目前仍有 8 家 VASP 維持登記（TRM Labs）。
17. 元富以 Fugle 打造的 API（2025-01）跨平台支援 Python、Node.js 與 C#（鉅亨網）。
18. 社群版群益 SDK 以 CapitalAPI 2.13.58 為目標，需要 Windows COM 註冊且位元數相符。
19. 套件版本：`fugle-marketdata` 2.7.0（MIT，2026-09-30）、`finmind` 2.0.11（Apache-2.0，2026-10-04）、`zipline-tej` 2.2.2（Apache-2.0，2025-11-25）。
20. FinMind：backer/sponsor 方案提供自 2018-12-07 起的股票逐筆與自 2011-01-03 起的期貨／選擇權逐筆；SponsorPro 提供 Parquet 下載；使用 token 每小時 600 次請求。
21. TWSE 規則：08:30 起接受委託、連續交易 09:00–13:25、收盤集合競價 13:25–13:30、定價交易 14:00–14:30。漲跌幅限制為 ±10%（新上市股票前 5 日無限制、公司債 ±5%、政府債券無限制）。瞬間價格穩定措施在偏離 5 分鐘均價 3.5% 時觸發，持續 2 分鐘。升降單位表、每 5 秒一次的盤中零股集合競價、盤後零股 13:40–14:30 與 T+2 交割皆已確認。
22. 當沖資格需帳戶開立滿 3 個月以上，且過去一年有 ≥10 筆成交（TWSE）。
23. 0.15% 的當沖稅率實施至 2027-12-31（證券交易稅條例第 2-2 條，法規資料庫更新至 2026-09-24）。
24. 契約規格：TX 每點 NT$200、TMF 每點 NT$10、TXO 每點 NT$50；月契約於第三個星期三到期；沒有 TMF 週契約。
25. 2026-10-05 的線上端點：
    - MAX 有 82 個市場（45 個新台幣、36 個 USDT），其中 6 個支援保證金，其文件回傳 HTTP 403。
    - BitoPro 有 35 個交易對（19 個新台幣）。每個 IP 與每個帳戶每分鐘允許 600 次請求，以 HMAC-SHA384 簽章，有官方 Go 與 Python SDK，且不再維護 v2。
    - ACE API 無法連線。
26. 第三方下單工具將大多數台灣券商 API 列為 Windows 32/64 位元元件（order-master）。

**已更正（原文 → 更正）**

1. 富邦「沒有獨立的模擬環境」→ Fubon Neo 透過可下載的套件提供測試環境，目前僅有證券測試帳號（fbs.com.tw/TradeAPI/docs/welcome、download-sdk）。
2. 富邦的「憑證工具 TCEM.exe 僅能在 Windows 上執行」被描述為唯一途徑 → 自 SDK v2.2.8 起，憑證可從網頁金鑰管理入口匯出以供跨平台使用。API 金鑰登入需要 SDK ≥ v2.2.7，且最多可建立 30 組金鑰（fbs.com.tw/TradeAPI/docs/key、install-compatibility）。
3. 元富（Masterlink）被列為現存券商 → 已於 2026-04-06 併入台新證券。2026-04-14 的成交回報中斷被歸因於系統整合（zh.wikipedia，元富證券與台新綜合證券）。內文現改稱台新／前元富。
4. 「2024 年 10 月 API 交易金額新台幣 636 億元，年增 26%」→ 來源表示截至 2024 年 10 月交易金額*已達*新台幣 636 億元，而 2023 年為新台幣 506 億元（+26%）。來源並未說明計算基礎（鉅亨網 2025-01-03）。
5. Fugle「分 K 自 2017-06 起」→ 股票分 K 僅回溯至 2023-05-23。2017-06 這個日期適用於期貨分 K（developer.fugle.tw 歷史 K 線與價格方案頁面）。
6. 證券交易稅「債券免稅」→ 只有政府債券永久免稅。公司債、金融債券與非槓桿型債券 ETF 僅在 2026-12-31 前免稅（證券交易稅條例第 1 條與第 2-1 條，law.moj.gov.tw pcode G0340078）。
7. 期貨交易稅被標示為「法定」稅率 → 該條例只規定範圍，適用稅率由行政院訂定。該稅向買賣雙方課徵，且履約時以現金結算的選擇權依期貨稅率課稅（期貨交易稅條例第 2 條，pcode G0340079）。

未涉及更正的補充：Shioaji 的帳務查詢限制（25 次/5 秒）、違反速率限制時暫停 1 分鐘、被撤回的 1.7.6 以及並行的 1.5.x 系列；富邦的交易限制（每秒 50 筆委託、每秒 10 筆批次委託、每秒 5 次帳務查詢、10 個連線）與 SDK v2.4.0；TWSE 資料商品網的「委託類別」商品（NT$10,000）；以及 TPEx 可轉債這個先前遺漏的散戶債券管道。

**無法查證**

1. Shioaji 的 PyO3 繫結。官方文件僅確認為「Rust 核心」，因此內文措辭已放寬。
2. 群益 SKCOM 對海外期貨與海外股票（複委託）的涵蓋。官方 API 頁面回傳 404，社群 SDK 僅列出國內商品。
3. 處置股確切的預收款券規則（「全額預收」）。TWSE 頁面僅確認集合競價撮合與禁止市價單，因此內文概括為「預收門檻依處置等級而定」。
4. 期貨交易稅的適用稅率（股價指數期貨 0.002%、選擇權權利金 0.1%）。兩者皆在法定範圍內，但本次並未對照財政部或 TAIFEX 的稅率表重新查核。
5. 以 Fugle 打造的元富 API 在合併後於台新證券旗下是否維持不變。
6. Threads 上的券商 API 網站清單（2026-08）。這是社群貼文，無法獨立查核。
