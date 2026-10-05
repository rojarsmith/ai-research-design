[English](08-risk-security-ops-compliance.md) | **繁體中文**

# 風險管理、資安、維運與法規遵循

> 維度 08 · 截至 2026-10-05 · 股票、加密貨幣、債券、選擇權；美國／全球、加密貨幣交易場所、台灣（TWSE/TPEx/TAIFEX）。本文為工程研究，不構成法律或稅務建議。

## 重點摘要（TL;DR）

- **單一、強制且失效即關閉（fail-closed）的風控閘門**位於每個策略與每個執行轉接器（execution adapter）之間，在回測、模擬交易（paper）與實盤（live）中完全一致。交易場所原生的控制機制（dead-man 計時器、價格區間、綁定 IP 的金鑰）是第二層防線；兩者單獨使用都不足夠。
- **憑證是皇冠上的寶石。** 使用僅限交易、設有 IP 白名單且停用提領的金鑰，存放於作業系統鑰匙圈（keychain，桌面端）或 OpenBao／雲端 KMS（伺服器端），絕不放在網頁或行動用戶端中。2025 年 Bybit 遭竊案（約 15 億美元，透過簽章介面）與 npm「Shai-Hulud」蠕蟲（透過相依套件）顯示了攻擊實際的落點。
- **依發展階段決定維運規模。** MVP 只需要 Docker Compose、Prometheus/Grafana/Loki（或 Grafana Cloud 免費方案）與 chrony。Kubernetes、多可用區（multi-AZ）、端到端 OpenTelemetry 與 WORM 封存要到團隊規模才划算。
- **法規關鍵在於自用還是服務他人。** 自用主要受券商規則約束（美國盤中保證金制度已於 2026 年 6 月 4 日取代 PDT；台灣券商 API 契約）。販售交易訊號、跟單交易、代客操作資金或為他人保管加密貨幣則需要執照：美國為 RIA/CTA/broker-dealer；歐盟為 MiCA CASP（過渡期已於 2026 年 7 月 1 日結束）；台灣為投資顧問執照，加密貨幣則適用《虛擬資產服務法》（2026 年 6 月 30 日三讀通過，施行日期待定）。
- **建議路徑：** 以**自用**工具的形式推出 MVP，但在設計稽核日誌、風控閘門與租戶邊界時，就要確保日後的持牌版本或 SaaS 版本無需重寫。

## 關鍵問題

1. 交易前檢查在哪裡執行？若風控元件本身故障，系統是否會失效即關閉（fail closed）？
2. 即使我們自己的程序已經停止運作，如何在約 1 秒內停止所有交易場所上的所有交易？
3. 如何在數個月後，以可偵測竄改（tamper-evident）的方式證明曾經發生過哪些委託、成交與限額變更？
4. API 金鑰在桌面、伺服器、網頁與行動端分別存放在哪裡？攻擊者拿到被竊的金鑰能做什麼？
5. 每種情境需要多少可觀測性（observability）、高可用性（HA）與時間同步精度？
6. 在動用真實資金之前，如何安全地進行測試？
7. 在美國、歐盟、台灣以及加密貨幣領域，哪些活動會落入監管範圍？

## 方案比較

### 1. 交易前風控：控制機制放在哪裡

| 方案 | 範例 | 增加的延遲 | 跨交易場所視野 | 失效模式 | 工作量 | 適用情境 |
|---|---|---|---|---|---|---|
| A. 僅用交易場所原生機制 | 券商委託預設值／預防性設定、交易所價格區間、Binance USDⓈ-M `countdownCancelAll` dead-man 計時器 | 0 | 無；各交易場所不同 | 不在你的掌控之中 | 非常低 | 必要的基本防線，但單獨使用永遠不夠 |
| B. 框架內建引擎 | NautilusTrader `RiskEngine`：精度、最大名目金額、僅減倉（reduce-only）、下單／改單速率限制、`ACTIVE`/`REDUCING`/`HALTED` 狀態；LEAN 風險管理模型 | µs（同程序內） | 有，涵蓋該框架支援的所有交易場所 | 與策略程序命運與共 | 低 | 若採用該框架，是最佳的 MVP 起點 |
| C. 自訂的同程序函式庫 | 你自己的 OMS 在呼叫任何轉接器之前，同步呼叫 `risk.check(order)` | µs | 有 | 只有在程式碼如此撰寫時才會失效即關閉 | 中 | 基於自訂引擎的 MVP |
| D. 獨立程序的風控閘道 | 由獨立服務掌管委託流、部位與限額；策略沒有任何直通交易場所的路徑 | 約 0.1–2 ms（IPC/gRPC） | 有，並可彙總多個帳戶 | 相互隔離；可獨立暫停策略 | 高 | 多策略、團隊或 SaaS |
| E. 券商／廠商／硬體 | 券商 DMA 風控層、FPGA 風控設備、商用 OMS/EMS | ns–µs | 依券商而定 | 受監管且經稽核 | $$$ | 機構級。具市場接取（market access）的 broker-dealer 依 SEC Rule 15c3-5 必須維持此類交易前控制（該規則強制要求的是控制機制，而非特定產品） |

**最低檢查項目。** SEC 15c3-5 要求 broker-dealer 套用信用／資本門檻，並阻擋錯誤委託。EU RTS 6（Reg. 2017/589）要求價格區間（price collar）、最大委託價值與數量、訊息數限制以及強制停止（kill）功能。即使系統僅供自用，也應將兩者當作檢查清單：

| 檢查項目 | MVP 預設值（依商品調整） | 備註 |
|---|---|---|
| 最大委託數量／名目金額 | 例如每筆委託 ≤ 權益的 2%，另加 USD/TWD 絕對上限 | 依商品與依帳戶分別套用 |
| 胖手指（fat-finger）價格區間 | 拒絕偏離中價／最新價超過 k×ATR 或 X% 的限價單；在流動性稀薄的委託簿上封鎖市價單 | 同時須遵守交易場所的價格區間：美國 LULD、TWSE 每日 ±10% 漲跌幅限制、盤中瞬間價格穩定措施 |
| 部位／曝險限額 | 依代碼、產業、總額／淨額與帳戶設定；選擇權則依各項希臘字母設定 | 使用券商確認的部位，而不只是內部狀態 |
| 保證金／購買力 | 模擬成交後的保證金，並保留 20–30% 緩衝 | 模型各不相同：Reg T 原始保證金 50%；FINRA 盤中保證金；期貨交易所保證金；加密貨幣強制平倉價格 |
| 委託速率節流 | 將 token bucket 設定在低於交易場所 REST 權重與 WS 訊息限制的水準 | 避免遭封鎖，並能攔截失控迴圈 |
| 重複／失控偵測 | N ms 內相同方向、代碼與數量；限制未成交委託數量與取消／替換速率 | 典型的演算法交易失效模式（Knight Capital，2012） |
| 交易時段／商品狀態 | 交易時間、暫停交易、集合競價、到期日、限制名單 | TAIFEX 盤後交易時段；加密貨幣全年無休（24/7） |
| 虧損熔斷 | 每日虧損限額 → `REDUCING`；硬性限額 → `HALTED` + 全部取消 | 手動重置須記錄理由 |

**即時風控層**

| 衡量指標 | MVP | 機構級 |
|---|---|---|
| 損益、回撤、曝險 | 即時，依成交與市價評價（marks）計算 | 依交易台／策略／帳戶，盤中計算 |
| VaR / ES | 以 250–500 天資料計算每日歷史 VaR/ES | 盤中歷史模擬 + Monte Carlo，以 ES 97.5% 作為主要指標 |
| 希臘字母 | 由券商或自有模型提供投資組合 Δ/Γ/vega/θ | 現貨 × 波動率情境網格；到期釘價（pin）風險與提前指派（early assignment）風險 |
| 壓力測試 | 固定衝擊：指數跳空 −10%、加密貨幣 ±30%、波動率 ×2、利率 +100 bp | 歷史重演（2008、2020 年 3 月、2022 年 LUNA/FTX）與反向壓力測試 |
| Kill switch（緊急停止開關） | 本機快捷鍵、遠端／行動端指令與交易場所 dead-man 計時器 | 階層式（策略 → 帳戶 → 交易場所 → 公司）、獨立網路路徑、四眼原則重置 |

### 2. 交易後對帳與可偵測竄改的稽核

以三種頻率進行對帳：**即時**（將每筆成交對應至其 client order ID；出現未知的成交時，將該帳戶切換為 `REDUCING`）、**盤中**（每 N 分鐘輪詢交易場所的部位／餘額；偏差超出容忍範圍即發出警示並暫停該帳戶），以及**日終**（對帳單 vs. 帳本：手續費、資金費率、公司行動、履約／指派、債券票息）。

| 方案 | 竄改偵測能力 | 成本／維運 | 備註 |
|---|---|---|---|
| PostgreSQL 僅附加（append-only）日誌 + 雜湊鏈（每一列儲存前一列的 SHA-256；每日摘要另存於主機以外） | 只要摘要存放在別處，即可偵測修改 | 最低；直接在主資料庫上執行 | 撤銷該資料表的 `UPDATE`/`DELETE` 權限。最適合 MVP |
| immudb 1.11.x（1.11.2，2026 年 9 月；自 1.0 起支援 PostgreSQL wire protocol，1.11.0 新增 ORM／`pg_catalog` 相容性與 SQL 驗證函式） | 內建密碼學驗證 | 需多維運一套資料庫 | **BSL 1.1**（自「1.9DOM.2」起，此版本字串照錄上游 LICENSE 檔原文；更早的版本為 Apache-2.0），因此不得作為與 Codenotary 競爭的付費託管／嵌入式產品提供；允許內部使用 |
| S3 Object Lock，合規模式（compliance mode） | WORM：保留期限屆滿前，即使 root 使用者也無法刪除（只有關閉 AWS 帳戶才會移除這些物件）；經 Cohasset 評估符合 SEC 17a-4、CFTC 與 FINRA 要求 | 非常便宜；以批次處理為主 | 兩種情境皆適用的封存層 |

不要以 **Amazon QLDB** 作為規劃基礎：AWS 已停止此服務（2025 年 7 月終止支援；其產品頁面現已重新導向至 Aurora）。託管型替代方案包括 Azure SQL Database/SQL Server 的帳本資料表（ledger tables），或上述的 Postgres 雜湊鏈。

### 3. 機密與金鑰管理

| 方案 | 授權／價格（2026 年 10 月） | 優點 | 缺點 | 適用情境 |
|---|---|---|---|---|
| 作業系統鑰匙圈（Windows Credential Manager/DPAPI、macOS Keychain、Linux Secret Service），透過 `keyring` 類函式庫存取 | 免費 | 綁定使用者帳戶；不需要伺服器 | 以該使用者身分執行的惡意程式可讀取；沒有稽核軌跡 | 桌面應用程式、個人 |
| SOPS + age（在 git 中存放加密檔案） | 開源，免費 | 簡單的 GitOps 工作流程 | 靜態機密；需手動輪替 | 個人／小型伺服器 |
| **OpenBao 2.7**（2.7.1 於 2026 年 10 月 1 日發布） | **MPL-2.0**，Linux Foundation / OpenSSF | 相容 Vault API：動態機密、transit 加密、稽核裝置（audit devices） | 需自行維運（unseal、HA、備份） | 自架的團隊或 SaaS |
| HashiCorp Vault 2.x（2.1.1 於 2026 年 9 月 16 日發布） | **BSL 1.1**，授權方為 IBM；Enterprise/HCP 需付費 | 成熟；具備 HSM 與企業級功能 | BSL 禁止將 Vault 本身作為與 IBM 競爭的付費託管／嵌入式產品提供給第三方；允許內部使用（包括在你自己的交易 SaaS 背後使用）；成本 | 需要廠商支援的企業 |
| 雲端機密管理服務 + KMS/HSM | AWS Secrets Manager：每個機密每月 $0.40 + 每 1 萬次 API 呼叫 $0.05 | 託管服務；IAM 與 CloudTrail 稽核 | 供應商綁定；對桌面端沒有幫助 | 雲端託管的伺服器 |
| Infisical | MIT 核心 + 商業授權 `ee` | 良好的使用者體驗、機密同步、可自架或使用 SaaS | 進階功能需付費 | 小型團隊 |

**交易場所金鑰衛生（所有情境適用）。** 每個策略或子帳戶各用一把金鑰，僅限交易 + 讀取、停用提領、綁定 IP（在 Binance 上，未限制 IP 的 HMAC 金鑰只能唯讀，且提領權限必須設定 IP 白名單）；若有提供，優先使用 Ed25519 金鑰。每 90 天以及任何資安事件後進行輪替。台灣券商以 `.pfx` CA 憑證進行驗證，部分券商現在也新增了具 IP 限制的 API 金鑰登入（富邦 Neo API，2026 年 5 月）。為提領地址白名單設定時間鎖，並在券商、交易所、雲端、GitHub 與套件登錄庫（package registry）帳戶上使用 FIDO2 硬體金鑰。

**用戶端配置。** 網頁與行動用戶端絕不持有交易場所金鑰；它們只是位於後端前方的監控與 kill switch 操作介面。若為僅限桌面的自用情境，只在交易核心程序內從作業系統鑰匙圈解密金鑰，絕不在 UI/webview 層解密。

**供應鏈。** Shai-Hulud npm 蠕蟲入侵了 500 多個套件，並竊取 GitHub、AWS、GCP 與 Azure 憑證（CISA，2025 年 9 月 23 日）。第二波攻擊（「Shai-Hulud 2.0」，2025 年 11 月 24 日）在 `preinstall` 階段執行，將約 700 個套件植入木馬，並將機密外洩到 25,000 多個 GitHub 儲存庫（Wiz）；npm 此後已將發布機制改為短效期的細粒度權杖（granular tokens）、強制 2FA 與受信任發布（trusted publishing）。緩解措施包括：以雜湊值鎖定的 lockfile、新版本延遲 3–7 天再採用、受信任發布、CycloneDX SBOM、以 Sigstore 簽章並附 SLSA v1.2 來源證明（provenance）的映像檔、經簽章的桌面自動更新，以及將建置機器與持有金鑰的機器分開。

**加密貨幣保管。** 交易所上只保留營運資金，庫存資金（treasury）放在冷儲存（硬體錢包或多重簽章；團隊可採用 MPC 或合格保管機構）。每筆交易都要在裝置螢幕上驗證，而不是在網頁 UI 上；FBI 將 Bybit 遭竊案歸咎於北韓（DPRK）「TraderTraitor」組織。交易系統絕不持有具提領能力的金鑰。

### 4. 可觀測性、HA/DR、部署、時間

| 方案 | 授權／成本 | 優點 | 缺點 | 適用情境 |
|---|---|---|---|---|
| 自架 Prometheus 3.x（3.15.0；3.13 為 LTS）+ Grafana + Loki 3.7 + Tempo，由 OpenTelemetry Collector 匯入資料 | Prometheus 為 Apache-2.0；Grafana/Loki/Tempo 為 AGPL-3.0；只需基礎設施成本 | 事實標準；不按時間序列（series）計費 | 須自行處理資料保留期限與 HA | 團隊的預設選擇；個人也適用 |
| Grafana Cloud | 免費方案：1 萬個活躍時間序列、50 GB 日誌、50 GB 追蹤、14 天保留期、3 位使用者。Pro：每月 $19 起 + 用量計費 | 零維運 | 保留期短；資料會離開你的基礎設施 | 個人 MVP |
| Datadog / New Relic（商用） | 依主機數／GB 計價 | 開箱即用的 APM | 高基數（high-cardinality）的交易指標會讓帳單快速膨脹 | 有預算的機構 |

其他值得一看的自架選項：VictoriaMetrics（Apache-2.0；更輕量、相容 Prometheus，適合長期保留的儲存方案），以及 OTel 原生的技術堆疊，例如 SigNoz（基於 ClickHouse）。

**OpenTelemetry 成熟度。** 追蹤（traces）與指標（metrics）在多數 SDK 中已穩定；日誌（logs）只在部分 SDK 中穩定（Go 為 RC 階段，Python/JS 仍在開發中）；效能剖析（profiles）尚屬早期階段。追蹤與指標使用 OTel，結構化 JSON 日誌則透過 Collector 傳送至 Loki。

**應設定警示的交易 SLI：** 行情資料過時與序號缺口、tick-to-order 與委託確認（order-ack）延遲、拒單率、與交易場所之間的部位偏差、風控閘門拒絕次數、重新連線、遺漏的 dead-man 心跳、時鐘偏移。透過 ntfy/Pushover/Telegram/PagerDuty 發送呼叫通知，每則警示都附上 runbook 連結。

**HA/DR。** 每個帳戶**只能有一個寫入者**；絕不對同一帳戶採用 active-active。以租約（lease）與 fencing token（Kubernetes Lease/etcd 或 Postgres advisory lock）執行 active-passive。新的 leader 在開始交易之前，先從交易場所對帳未成交委託與部位。具決定性（deterministic）的 client order ID 讓重試具備冪等性。目標：委託日誌 RPO ≈ 0（同步複本，並以交易場所為權威資料來源），RTO 以分鐘計。

**部署。** MVP：在一台固定 IP 的 VM 上執行 Docker Compose。團隊：在受支援的次要版本（1.35–1.37；1.34 將於 2026-10-27 結束支援〔EOL〕）上執行 Kubernetes。依實測 RTT 選擇區域：Binance 等級的加密貨幣交易場所選 AWS 東京（`ap-northeast-1`），美國券商選美東，台灣券商選台灣（AWS 台北 `ap-east-2`，需選擇加入〔opt-in〕；或 GCP `asia-east1`）。請確認你的台灣券商是否接受來自雲端 IP 的 API 登入。

**時間同步。** 讓 chrony 與 AWS 的鏈路本地（link-local）位址 `169.254.169.123` 同步。位於 `precision-time` 置放群組（placement group）中、受支援的 Gen7+ 執行個體系列，可免費取得強化的 Stratum-1 NTP 來源，且（僅限 Linux）可取得微秒級精度的 PTP 硬體時鐘（東京與少數其他區域在不使用置放群組的情況下，也仍保留舊版 PHC 存取）。Windows 執行個體必須使用強化的 NTP 來源。Windows `w32time` 精度較粗，因此桌面用戶端需為每個交易場所維護伺服器時間偏移量（用於 `recvWindow`），並以單調時鐘（monotonic clock）量測延遲。基準：FINRA CAT 要求業界成員與 NIST 的誤差保持在 50 ms 以內（僅用於人工委託的時鐘則為 1 秒）。

### 5. 測試策略

| 層級 | 工具 | 能抓到的問題 | MVP | 團隊 |
|---|---|---|---|---|
| 單元測試 | pytest / cargo test / xUnit | 損益、保證金、tick/lot 進位 | ✓ | ✓ |
| 基於性質的測試（property-based） | Hypothesis, proptest, FsCheck | 不變量：部位 = Σ 成交；閘門絕不放行超出限額的委託；成交處理具冪等性 | ✓ | ✓ |
| 決定性歷史重播 | 將錄製的原始行情資料 + 委託／成交事件，透過**相同**的程式路徑執行 | 迴歸問題、前視偏差（look-ahead bias）、狀態機錯誤 | ✓ | 每晚 CI |
| 模擬交易所 | 具備延遲、部分成交、拒單、速率限制錯誤與斷線的撮合模擬器；NautilusTrader sandbox | 委託生命週期的邊界情況 | 基本 | 完整 |
| 交易場所沙盒／模擬交易 | IBKR paper、Alpaca paper、Binance 測試網、台灣券商模擬模式（例如 Shioaji `simulation=True`） | API 變動、權限 | ✓ | ✓ |
| 混沌／故障注入 | Toxiproxy、Chaos Mesh/LitmusChaos、時鐘偏移注入、在委託進行中執行 `kill -9` | 孤兒／重複委託、復原路徑 | 手動演練 | 定期的 game day 演練 |

**上線檢查清單**

- [ ] 限額已設定、納入版本控制並經過審查。
- [ ] Kill switch 已在每條路徑上測試（本機、遠端、交易場所 dead-man）。撤銷金鑰**不會**取消仍在掛單中的委託。
- [ ] 金鑰僅限交易、綁定 IP、停用提領。
- [ ] 對帳連續 5 個以上交易時段皆正常；進行 2–4 週的模擬交易或極小部位實盤，並將滑價與回測結果比較。
- [ ] 已完成警示演練與備份還原；備妥斷線、委託卡住、代碼暫停交易與券商服務中斷的 runbook。
- [ ] 資金分階段投入（例如 10% → 25% → 100%），並設有退出條件。

### 6. 法規：自用 vs. 服務他人

| 活動 | 美國 | 歐盟 | 台灣 |
|---|---|---|---|
| **自用**，透過 API 操作自有帳戶 | **無須執照。** 適用券商規則。FINRA Rule 4210 盤中保證金制度取代了 PDT 規則及其 $25k 最低門檻，自 2026 年 6 月 4 日生效，但券商可分階段導入至 **2027 年 10 月 20 日**，因此需同時支援兩種制度。Reg T：原始保證金 50%。洗售規則（wash sale，§1091）適用於股票與選擇權。Form 1099-DA 券商申報已生效（針對 2025 年後取得之數位資產申報成本基礎）；其洗售申報僅涵蓋代幣化證券。 | 依 MiFID II，自營交易一般可豁免。例外：使用 HFT 技術、取得交易場所會員資格或從事造市。 | API 委託屬於電子式交易。你需簽署風險預告書／同意書、通過連線測試並使用 CA 憑證。券商會保留原始委託與你的 IP，並可能因異常委託而暫停 API 使用權限。你不得授權第三方。當日沖銷需具備當沖資格。 |
| **販售訊號、策略或附帶建議的工具** | 須註冊為 **RIA**，除非適用出版者豁免（publisher's exclusion：非個人化、善意（bona fide）、屬一般且定期發行）。期貨建議須註冊 **CTA**（CFTC 4.14 豁免，例如 12 個月內 ≤15 人且未對公眾自我宣傳）。 | 屬 MiFID II 下的投資建議；MAR 關於投資推薦的規則 | 需要顧問執照：證券為證券投資顧問事業（須加入 SITCA／投信投顧公會），期貨為期貨顧問事業（須加入期貨業同業公會，即期貨公會；《期貨交易法》第 89 條）。未經許可經營證券投資顧問業務：《證券投資信託及顧問法》第 107 條，處 5 年以下有期徒刑，併科新臺幣 100 萬元至 5,000 萬元罰金。未經許可經營期貨顧問業務：《期貨交易法》第 112 條（第 5 項第 5 款），處 7 年以下有期徒刑，得併科新臺幣 300 萬元以下罰金。 |
| **代客操作資金／跟單交易／操作使用者帳戶** | 具全權委託權限（discretion）的 RIA，可能還需要 broker-dealer；集合式期貨（pooled futures）須為 CPO | MiFID 投資組合管理執照，或加密貨幣的 CASP 同等資格 | 全權委託執照（期貨則為期貨經理事業）。券商 API 條款禁止授權第三方。 |
| **為他人提供加密貨幣服務**（交易所、保管、轉帳） | FinCEN MSB 登記加上各州執照；Travel Rule | **MiCA CASP** 授權。過渡期已於 **2026 年 7 月 1 日**結束（在縮短過渡期的國家更早結束，例如荷蘭、波蘭與芬蘭為 6 個月；德國與愛爾蘭為 12 個月）。申請審核中不等於已獲授權。TFR Travel Rule。 | 現況：洗錢防制（AML）登記；未登記的境外平台不得招攬台灣使用者。**《虛擬資產服務法》**：2026 年 6 月 30 日三讀通過；7 種執照類型；既有業者有 12 個月可提出申請、21（+3）個月取得執照；施行日期由行政院定之；金管會目標於 2027 年第一季底前完成約 9 項子法，首批正式執照預計約於 2028 年第一季核發（BlockTempo／動區）。在台灣，穩定幣發行僅限銀行。**Travel Rule：** 境內轉帳自 2026 年 10 月起實施，跨境轉帳於 2027 年底前實施，超過新臺幣 30,000 元須附加額外資料。 |
| **轉發行情資料（SaaS）** | 交易所／SIP 經銷商（distributor）協議；專業 vs. 非專業使用者費用；非顯示用途（non-display）費用 | 交易所授權 | TWSE/TAIFEX 資訊廠商合約。券商 API 條款禁止在未經 TAIFEX 書面同意的情況下轉發 TAIFEX 資料。 |

**全球加密貨幣。** FATF 於 2025 年 6 月修訂建議第 16 項（Recommendation 16），實施期限為 2030 年底。截至 2026 年 7 月，受調查的司法管轄區中有 83% 已完成 Travel Rule 立法，但其中僅 40% 曾採取任何監理行動。

**稅務。** 美國的洗售追蹤只對美國納稅人有意義，因此應將稅務批次（tax-lot）引擎設計為可依司法管轄區抽換的外掛模組。

### 7. 四種資產類別的差異

| 面向 | 股票 | 加密貨幣 | 債券 | 選擇權 |
|---|---|---|---|---|
| 交易前特殊事項 | LULD／台股 ±10% 漲跌幅限制；整股（台股：1,000 股）vs. 零股；放空規則（Reg SHO、台股融券／借券） | 各代碼的 tick、step 與最小名目金額篩選條件（filters）；槓桿與強制平倉價格；停用提領 | 價格與殖利率合理性檢查；最低面額；RFQ 報價過時 | 契約口數上限；交易後希臘字母；權利金與內含價值比對檢查；價差寬度防護；選擇權交易權限等級 |
| 即時風險 | Beta、產業集中度、隔夜跳空 | 交易場所／交易對手倒閉、穩定幣脫鉤、全倉保證金（cross-margin）強制平倉、自動減倉（ADL） | DV01、存續期間／凸性、信用利差、流動性 | Δ/Γ/vega/θ、波動率衝擊、到期釘價（pin）風險與提前指派風險 |
| 維運 | 交易時段（台股 09:00–13:30） | 24/7：輪值待命、交易場所維護時段 | OTC/RFQ；API 功能有限 | 到期截止時間；TAIFEX 夜盤 |
| 對帳 | 股利、分割；T+1（美國）／T+2（台灣） | 資金費率支付、多幣別手續費、鏈上確認 | 債券票息、應計利息 | 履約／指派、多腳（multi-leg）部分成交 |
| 保管／資安 | 由券商保管 | **金鑰就是錢**；交易所交易對手風險 | 由券商／銀行保管 | 由券商保管 |

## 建議（依情境）

### (a) 個人／1–3 人 MVP（自用）

1. **風控閘門。** 採用方案 B（框架）或 C，作為強制的同程序閘門，預設為失效即關閉，實作上述完整檢查項目，並具備三種狀態：`ACTIVE`/`REDUCING`/`HALTED`。將限額存放在納入 git 管理的 YAML 檔案中；每次變更都要記錄。
2. **三條路徑的 kill switch：** 桌面快捷鍵、透過行動端／Telegram 對後端下達指令，以及交易場所 dead-man 計時器（例如 Binance USDⓈ-M `countdownCancelAll` 心跳，它以代碼為單位運作，因此每個交易中的代碼都要啟用；若有提供，也啟用斷線即取消〔cancel-on-disconnect〕）。
3. **金鑰。** 僅限交易、停用提領、綁定一台固定 IP 的 VPS。桌面端存放於作業系統鑰匙圈，伺服器端存放於 SOPS+age 或雲端機密管理服務。每個帳戶都使用 FIDO2。
4. **稽核。** Postgres 僅附加、以雜湊鏈串接的日誌，再加上每晚匯出至 S3 Object Lock。自動執行即時、盤中與日終（EOD）對帳。
5. **維運。** Docker Compose、Grafana Cloud 免費方案或自架 Prometheus/Grafana/Loki、chrony，以及一台用於加密貨幣的 AWS 東京 VM。台灣券商則使用鄰近券商的主機代管或家用伺服器。
6. **測試。** 針對風控不變量的基於性質測試、CI 中的決定性重播、交易場所模擬交易／測試網，接著進行 2–4 週的小部位實盤逐步放量。
7. **法規遵循。** 維持自用。在取得各司法管轄區的法律意見之前，不要販售訊號、經營跟單交易或持有他人的金鑰。

### (b) 5–20 人團隊／機構級

1. **風控閘道（方案 D）** 作為獨立服務，再加上即時風險服務：盤中 VaR/ES、希臘字母網格、壓力測試情境庫、階層式 kill switch。限額變更須經四眼原則核准，且各項控制應對應至 SEC 15c3-5 與 EU RTS 6。
2. **機密。** OpenBao（MPL-2.0）或 Vault Enterprise／雲端 KMS，並以 HSM 作為後盾，搭配動態資料庫憑證、稽核裝置與自動輪替。加密貨幣庫存資金交由 MPC 或合格保管機構保管。
3. **供應鏈。** SLSA v1.2 來源證明、經簽章的映像檔、SBOM、相依套件冷卻期、OpenSSF Scorecard 關卡，以及分離的 CI 身分。
4. **平台。** 在受支援的次要版本（1.35+）上執行 Kubernetes、多可用區、每個帳戶採 active-passive 並搭配 fencing、有文件記載的 DR 區域，以及每季的還原與 game day 演練。
5. **可觀測性。** 端到端 OpenTelemetry、交易 SLO、輪值待命、事後檢討（post-mortem）。
6. **稽核。** 若你成為受監管機構，WORM 保留期限須符合 SEC 17a-4／CFTC 紀錄保存要求；採用 immudb（請確認其 BSL 條款），或搭配外部錨定（external anchoring）的雜湊鏈日誌。
7. **法規遵循計畫：** 執照取得路線圖（RIA/CTA；MiCA CASP；台灣投顧執照，以及該法施行後的 VASP 執照）、Travel Rule 服務供應商、行情資料經銷協議、SOC 2／ISO 27001，若服務歐盟金融機構則還需符合 DORA。

## 對整體架構的影響

- **風控閘門是策略執行環境（strategy runtime）與執行轉接器之間的硬性咽喉點（choke point）**，且回測、模擬交易與實盤共用相同的程式碼。轉接器必須公開交易場所的速率限制、dead-man 基本操作（primitives）與部位快照。
- **事件溯源（event-sourced）的委託／成交日誌**，以 client order ID 作為冪等鍵（idempotency key）。它為風控、對帳、損益與稽核元件提供資料。
- **將控制平面與交易平面分離。** UI（桌面、網頁、行動端）負責下達諸如暫停、變更限額或部署策略等指令。只有交易核心持有交易場所憑證。
- **從第一天起就明確地為帳戶與租戶建立模型**（擁有者、交易場所、金鑰 ID、限額）。如此一來，日後轉型為 SaaS 主要是執照問題，而不需要重寫。
- **Kill switch 擁有自己的路徑**，也就是一個精簡的獨立程序與獨立憑證，因此當主引擎卡死時，它仍能持續運作。
- **資產類別外掛模組（plug-in）** 提供保證金模型、希臘字母／DV01 計算器、交易時段行事曆與對帳規則。

## 風險與陷阱

- **失效即開放（fail-open）的風控閘門：** 檢查中發生的例外絕不能讓委託通過。
- **將內部狀態視為事實：** 任何重新連線或容錯移轉（failover）之後，一律以交易場所的部位為準。
- **在事件處理中途撤銷金鑰：** 掛單中的委託仍然有效；應先取消委託。
- **規則悄悄變動：** 美國盤中保證金的分階段導入期持續到 2027 年 10 月，台灣券商會修訂 API 條款，加密貨幣交易場所會變更篩選條件與速率限制。
- **軟體授權陷阱：** BSL 產品（Vault、immudb）不得作為與廠商付費版本競爭的付費託管或嵌入式產品提供給第三方；在你自己的交易 SaaS 背後內部使用則是允許的。修改 AGPL 授權的 Grafana/Loki/Tempo 並透過網路提供給使用者，會觸發 AGPL 義務。
- **意外構成顧問業務：** 免費的 Discord 頻道若變成付費訊號服務，在台灣與美國都需要執照。
- **行情資料轉發：** 向 SaaS 使用者顯示交易所資料，需要交易所／資訊廠商合約並支付費用。
- **桌面惡意程式：** 鑰匙圈無法阻擋以同一使用者身分執行的程式碼；請使用專用的交易機器或 VM。
- **24/7 加密貨幣、單一操作者：** 若沒有呼叫通知與自動平倉規則，週末發生的事件可能在無人看管下持續好幾個小時。

## 參考資料

- FINRA Regulatory Notice 26-10（盤中保證金取代 PDT）： https://www.finra.org/sites/default/files/2026-04/Regulatory-Notice-26-10.pdf
- ACA Group，FINRA 終止 PDT 規則（日期、分階段導入）： https://www.acaglobal.com/industry-insights/finra-ends-the-pattern-day-trader-rule/
- FINRA Regulatory Notice 26-11（Rule 4210 解釋）： https://www.finra.org/rules-guidance/notices/26-11
- Regulation T §220.12： https://www.law.cornell.edu/cfr/text/12/220.12
- IRC §1091 洗售： https://www.law.cornell.edu/uscode/text/26/1091
- IRS Form 1099-DA 填報說明： https://www.irs.gov/instructions/i1099da
- SEC Rule 15c3-5（市場接取）： https://www.sec.gov/rules-regulations/2011/06/risk-management-controls-brokers-or-dealers-market-access
- FINRA 市場接取主題頁： https://www.finra.org/rules-guidance/key-topics/market-access
- EU RTS 6，歐盟執委會授權規則（Commission Delegated Regulation）2017/589： https://eur-lex.europa.eu/eli/reg_del/2017/589/oj
- FINRA Rule 6820（CAT 時鐘同步）： https://www.finra.org/rules-guidance/rulebooks/finra-rules/6820
- Seeking Alpha 出版者豁免判決（Greenberg Traurig）： https://www.gtlaw.com/ja/insights/2024/8/no-need-for-seeking-alpha-to-seek-registration
- NFA，CTA 註冊： https://www.nfa.futures.org/registration-membership/who-has-to-register/cta.html
- ESMA MiCA 頁面： https://www.esma.europa.eu/esmas-activities/digital-finance-and-innovation/markets-crypto-assets-regulation-mica
- AGP Law，MiCA 過渡期於 2026 年 7 月 1 日結束： https://www.agplaw.com/?p=32785
- ESMA，各會員國 MiCA 過渡期間（grandfathering periods）清單： https://www.esma.europa.eu/sites/default/files/2024-12/List_of_MiCA_grandfathering_periods_art._143_3.pdf
- 歐盟資金移轉規則（Transfer of Funds Regulation）2023/1113： https://eur-lex.europa.eu/eli/reg/2023/1113/oj
- FATF 第七次虛擬資產／VASP 針對性更新（2026 年 7 月）： https://www.fatf-gafi.org/en/publications/Fatfrecommendations/targeted-updated-virtualassets-vasps-2026.html
- FATF R.16 修訂（2025 年 6 月）： https://www.regulationtomorrow.com/2025/06/fatf-updates-travel-rule/
- 理律法律事務所（Lee and Li），台灣《虛擬資產服務法》： https://www.leeandli.com/EN/NewslettersDetail/7658.htm
- 動區（BlockTempo），VASP 專法三讀解析： https://www.blocktempo.com/taiwan-virtual-asset-act-third-reading-explainer-vasp-stablecoin-licensing/
- Agbrief，台灣通過虛擬資產法： https://agbrief.com/news/taiwan/30/06/2026/taiwan-passes-first-virtual-asset-law-mandates-license-for-exchanges/
- Cointelegraph，台灣 Travel Rule（2026 年 10 月／2027 年底）： https://cointelegraph.com/news/taiwan-crypto-travel-rule-domestic-vasp-transfers
- The Block，台灣限制未登記的境外交易所： https://www.theblock.co/post/252915/taiwan-releases-guidelines-for-crypto-exchanges-restricts-offshore-exchanges-unless-compliant
- 《證券投資信託及顧問法》第 107 條： https://law.moj.gov.tw/LawClass/LawSingle.aspx?pcode=G0400121&flno=107
- 《期貨交易法》第 112 條（未經許可經營期貨顧問業務）： https://law.moj.gov.tw/LawClass/LawSingle.aspx?pcode=G0400100&flno=112
- 《期貨交易法》第 89 條（同業公會會員資格）： https://law.moj.gov.tw/LawClass/LawSingle.aspx?pcode=G0400100&flno=89
- 台灣 API 交易概覽（電子式交易、券商控管）： https://ctyeh.com/finance/15093
- 永豐（SinoPac）期貨 API 風險預告書／同意書： https://www.sinotrade.com.tw/newweb/signCenter/F_openApi/
- 富邦 Neo API 金鑰登入與 IP 限制（2026 年 5 月）： https://www.taiwannews.com.tw/zh/news/6359399
- CTA plan（SIP 行情資料定價）： https://www.ctaplan.com/
- Binance API 金鑰類型與 IP／提領規則： https://www.binance.com/en/support/faq/how-to-create-api-keys-on-binance-360002502072
- Binance 期貨自動取消（dead-man）： https://developers.binance.com/docs/derivatives/usds-margined-futures/trade/rest-api/Auto-Cancel-All-Open-Orders
- NautilusTrader 執行／RiskEngine： https://nautilustrader.io/docs/latest/concepts/execution/
- OpenBao 發布版本： https://github.com/openbao/openbao/releases
- OpenBao 儲存庫（授權、治理）： https://github.com/openbao/openbao
- HashiCorp Vault 發布版本： https://github.com/hashicorp/vault/releases
- HashiCorp Vault LICENSE（BSL 1.1，IBM）： https://github.com/hashicorp/vault/blob/main/LICENSE
- Infisical 儲存庫： https://github.com/Infisical/infisical
- AWS Secrets Manager 定價： https://aws.amazon.com/secrets-manager/pricing/
- immudb 發布版本： https://github.com/codenotary/immudb/releases
- immudb LICENSE（BSL 1.1）： https://github.com/codenotary/immudb/blob/master/LICENSE
- immudb v1.11.0 版本說明（PostgreSQL/ORM 相容性）： https://github.com/codenotary/immudb/releases/tag/v1.11.0
- Amazon S3 Object Lock： https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock.html
- FBI 關於 Bybit 遭竊案的 PSA： https://www.ic3.gov/PSA/2025/PSA250226
- CISA 警示，npm Shai-Hulud： https://www.cisa.gov/news-events/alerts/2025/09/23/widespread-supply-chain-compromise-impacting-npm-ecosystem
- Wiz，Shai-Hulud 2.0（2025 年 11 月）： https://www.wiz.io/blog/shai-hulud-2-0-ongoing-supply-chain-attack
- GitHub，打造更安全 npm 供應鏈的計畫： https://github.blog/security/supply-chain-security/our-plan-for-a-more-secure-npm-supply-chain/
- SLSA 規格： https://slsa.dev/spec/
- Prometheus 發布版本： https://github.com/prometheus/prometheus/releases
- Prometheus 發布週期（LTS 3.13，支援至 2027 年 7 月 31 日）： https://prometheus.io/docs/introduction/release-cycle/
- Grafana Loki 發布版本： https://github.com/grafana/loki/releases
- Grafana Cloud 定價： https://grafana.com/pricing/
- OpenTelemetry 狀態： https://opentelemetry.io/status/
- Kubernetes 發布版本： https://kubernetes.io/releases/
- AWS 區域清單： https://docs.aws.amazon.com/global-infrastructure/latest/regions/aws-regions.html
- Amazon Time Sync Service／PTP 硬體時鐘： https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configure-ec2-ntp.html

## 查核紀錄（2026-10）

於 2026-10-05 對照一手資料來源（監理機關公告、法規條文、GitHub 發布版本與 LICENSE 檔案、廠商定價與文件）進行對抗式事實查核。

**已確認**

1. FINRA Regulatory Notice 26-10（2026 年 4 月 20 日）：Rule 4210 下的盤中保證金標準取代了 PDT 認定與 $25,000 最低門檻；自 2026 年 6 月 4 日生效；可選擇採用 18 個月的分階段導入期，至 2027 年 10 月 20 日（公告 PDF；ACA Group）。Notice 26-11（2026 年 5 月 19 日）發布了相關解釋。
2. 台灣《虛擬資產服務法》於 2026 年 6 月 30 日三讀通過；7 類 VASP；既有業者有 12 個月可提出申請、21 個月（可延長一次，延長 3 個月）取得執照；由行政院訂定施行日期（理律；動區）。
3. 台灣 Travel Rule：境內 VASP 對 VASP 轉帳自 2026 年 10 月起實施，國際轉帳於 2027 年底前實施，超過新臺幣 30,000 元須附加額外的發起人資料（Cointelegraph，2026 年 8 月 5 日）。
4. MiCA 過渡（grandfathering）期已於 2026 年 7 月 1 日結束；未獲授權的 CASP 必須結束在歐盟的業務；申請審核中不等於已獲授權（AGP Law，2026 年 6 月 30 日；ESMA）。較短的各國過渡期已由 ESMA 清單確認。
5. 《證券投資信託及顧問法》第 107 條：未經核准經營顧問業務者，處 5 年以下有期徒刑，併科新臺幣 100 萬元至 5,000 萬元罰金（law.moj.gov.tw）。
6. OpenBao：MPL-2.0，於 OpenSSF（Linux Foundation）下治理；v2.7.0 於 2026 年 9 月 23 日、v2.7.1 於 2026 年 10 月 1 日發布（GitHub releases）。
7. HashiCorp Vault：BSL 1.1，授權方為 IBM；v2.1.1 於 2026 年 9 月 16 日發布（GitHub LICENSE 與 releases）。
8. immudb：BSL 1.1（授權方為 Codenotary）；最新版本 v1.11.2 於 2026 年 9 月 3 日發布（GitHub）。
9. Binance：未限制 IP 的 HMAC 金鑰為唯讀；提領權限必須設定 IPv4 白名單（Binance FAQ）。
10. CISA 2025 年 9 月 23 日警示：Shai-Hulud 入侵了 500 多個 npm 套件，並以 GitHub PAT 與 AWS/GCP/Azure 金鑰為目標。
11. Grafana Cloud 免費方案：1 萬個活躍時間序列、50 GB 日誌、50 GB 追蹤、14 天保留期、3 位活躍使用者；Pro 每月 $19 起，另加用量計費（grafana.com/pricing）。
12. Amazon Time Sync Service：`169.254.169.123`；受支援的 Gen7+ 系列在 `precision-time` 置放群組中可取得微秒級精度的 PHC，所有商業區域皆提供且不另收費（AWS 文件）。
13. IRS Form 1099-DA：針對 2025 年後取得之數位資產申報成本基礎；洗售申報僅限代幣化證券（IRS 填報說明）。
14. FINRA Rule 6820：與 NIST 的容許誤差為 50 ms（人工委託時鐘為 1 秒）。
15. Bybit 於 2025 年 2 月 21 日遭竊約 15 億美元，FBI 將其歸咎於北韓（DPRK）「TraderTraitor」（IC3 PSA250226）。
16. NautilusTrader `RiskEngine` 的檢查項目（精度、名目金額、僅減倉、下單／改單速率限制）與 `ACTIVE`/`REDUCING`/`HALTED` 狀態（官方文件）。
17. Binance USDⓈ-M `POST /fapi/v1/countdownCancelAll` dead-man 計時器（Binance 開發者文件）。
18. AWS Secrets Manager：每個機密每月 $0.40，每 1 萬次 API 呼叫 $0.05。
19. Infisical：`ee/` 以外為 MIT 授權，`ee/` 內為商業授權（GitHub LICENSE）。
20. Prometheus 3.15.0（2026 年 9 月 25 日）為最新版本；3.13 為目前的 LTS，支援至 2027 年 7 月 31 日。Loki 版本為 3.7.x（3.7.8）。Prometheus 為 Apache-2.0；Grafana、Loki 與 Tempo 為 AGPL-3.0。
21. OpenTelemetry 狀態：日誌在 Java、.NET 與 C++ 中已穩定；Go 日誌為候選發布版（release candidate）；Python 與 JS 日誌仍在開發中；Rust 為 beta。
22. Kubernetes 1.35、1.36 與 1.37 仍在維護中；1.34 將於 2026-10-27 結束支援（EOL）。
23. SLSA v1.2 是目前核准的規格。
24. AWS 亞太（台北）區域為 `ap-east-2`，需選擇加入（opt-in）。
25. S3 Object Lock 合規模式：即使 root 使用者也無法刪除；經 Cohasset 針對 SEC 17a-4、CFTC 與 FINRA 進行評估。
26. 富邦 Neo API：具 IP 限制的 API 金鑰登入（Taiwan News，2026 年 5 月 11 日）。
27. 金管會 2023 年指導原則：未登記的境外 VASP 不得招攬台灣使用者（The Block）。
28. Seeking Alpha 出版者豁免判決（S.D.N.Y.，2024 年 8 月；Greenberg Traurig）。
29. GitHub 的 npm 強化計畫（2025 年 9 月 22 日）：本機發布僅限 2FA、7 天效期的細粒度權杖、受信任發布。

**已更正**

- immudb「自 1.11.0 起相容 PostgreSQL」→ PostgreSQL wire protocol 自 v1.0 起即已存在；v1.11.0 新增的是 ORM（`pg_catalog`/`information_schema`）相容性與 SQL 驗證函式。來源：immudb v1.0.0 與 v1.11.0 版本說明。
- 台灣期貨顧問原被列在「須加入 SITCA／投信投顧公會」之下，且暗示第 107 條為唯一罰則 → 期貨顧問必須加入期貨業同業公會（《期貨交易法》第 89 條）。未經許可經營期貨顧問業務依《期貨交易法》第 112 條處罰（7 年以下有期徒刑，得併科新臺幣 300 萬元以下罰金）。來源：law.moj.gov.tw（G0400100）。
- VASP 專法「施行日期預計於 2027 年」→ 金管會目標於 2027 年第一季底前完成約 9 項子法，首批正式執照預計約於 2028 年第一季核發。來源：BlockTempo（動區）。
- BSL 摘要（「不得用於支撐與之競爭的託管服務」）→ 該限制涵蓋的是將產品本身作為與廠商付費版本競爭的*付費*託管或嵌入式產品提供給第三方。內部使用（包括在你自己的 SaaS 背後使用）是允許的。來源：Vault 與 immudb 的 LICENSE 檔案。
- 時間同步「Gen7+ 執行個體可取得 PTP 硬體時鐘」→ 只有列出的 Gen7+ 系列才能取得，且 PHC 僅限 Linux；Windows 使用強化的 NTP 來源。來源：AWS EC2 使用者指南。
- SEC 15c3-5「必須執行這些 [FPGA／廠商設備]」→ 該規則強制要求的是風險控制，而非特定產品。來源：SEC Rule 15c3-5。

**新增（缺漏或過時的背景資訊）**

- Shai-Hulud 2.0（2025 年 11 月 24 日；約 700 個套件、25,000 多個儲存庫；Wiz）。
- Amazon QLDB 已停止服務，因此不要以它作為規劃基礎；已列出帳本資料表替代方案。
- VictoriaMetrics/SigNoz 作為自架可觀測性的替代方案。
- Binance `countdownCancelAll` 以代碼為單位運作。
- 各國 MiCA 過渡期間（ESMA 清單）。

**無法查證（維持原樣或已標註）**

- FATF 2026 年 7 月針對性更新的數據（83% 已有 Travel Rule 立法；其中 40% 曾採取監理行動）：FATF 網站有機器人驗證機制阻擋，因此無法取得這些數據。
- FATF 修訂後 R.16（2025 年 6 月）的 2030 年底實施期限：所引用的來源回傳 HTTP 403。
- Amazon QLDB 確切的終止支援日期（2025 年 7 月）：產品頁面重新導向至 Aurora、開發者指南回傳 404，足以證明已停止服務，但該日期本身並未從 AWS 公告中取得。
- 台灣券商 API 契約細節（ctyeh.com 概覽、永豐同意書頁面）以及 Shioaji `simulation=True` 模式，在本次查核中未重新確認。
