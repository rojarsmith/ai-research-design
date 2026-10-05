[English](ADR-0015-self-use-regulatory-posture-and-legal-gate.md) | **繁體中文**

# ADR-0015：「自主交易軟體」監理立場，並在任何外部使用者之前設置法律關卡

## 狀態

**提議中（Proposed）** · 2026-10-05 · 範圍：所有情境。本文件屬於工程政策，並非法律意見；在依觸發條件 T1 採取行動之前，每一點都必須經法律顧問確認。

## 背景與問題陳述

平台是否會提供給其他人使用，目前尚未決定。跨越監理界線的是*活動*，而非架構（[08](../../research/08-risk-security-ops-compliance.zh-TW.md)、[11](../../research/11-taiwan-market-localization.zh-TW.md)），而且很容易意外越界：一個原本免費、後來轉為收費的訊號頻道就會越界。平台現在應採取什麼立場？在擁有者以外的任何人使用之前，又必須先做到什麼？

研究發現（非法律意見）：

- **自用主要受券商規則規範。**
  - 美國：FINRA 日內保證金（intraday margin）規則已於 2026-06-04 取代 PDT 規則，並允許券商分階段導入至 2027-10-20。
  - 台灣：API 下單在已簽署風險預告書的前提下視為電子交易，並需使用 CA 憑證。券商會保存原始委託與 IP 位址，且**不得授權第三方**。
- **服務他人需要執照。**
  - 台灣：未經許可提供收費證券投資顧問服務，依《證券投資信託及顧問法》（SITCA Act）第 107 條處罰（最高 5 年有期徒刑，並科新台幣 100 萬元至 5,000 萬元罰金）。未經許可的期貨顧問則適用《期貨交易法》第 112 條（最高 7 年有期徒刑）。全權委託管理需另行取得核准。
  - 美國：視活動而定，需註冊為 RIA、CTA 或 broker-dealer。
  - 歐盟：MiCA CASP 授權（過渡期已於 2026-07-01 結束）。
- **台灣的加密貨幣。** 目前須完成洗錢防制（AML）登記，且未登記的境外交易場所不得招攬台灣使用者。**《虛擬資產服務法》（Virtual Asset Service Act）** 已於 2026-06-30 通過；最快於 2027 年第一季生效，首批執照預計約於 2028 年第一季核發。國內旅行規則（Travel Rule）自 2026 年 10 月起適用。
- **市場資料。** 向其他任何人顯示資料即屬再散布（redistribution）。TWSE 每月收費新台幣 60,000 元另加網際網路費用，TAIFEX 需書面同意，IBKR 則禁止未經核准再散布 TWS API 資料。我們的零售資料方案僅限個人使用。
- **憑證。** 台灣券商憑證屬於個人。由客戶自行託管（customer-hosted）的邊緣連接器（edge connector）*或許*符合券商條款，但這只是一項法律假設，需要法律顧問與券商確認（[評估紀錄](../../architecture/evaluation.zh-TW.md)，疑慮 23）。
- **IBKR** 僅在合規審查後才提供第三方供應商 OAuth 1.0a，並要求自動化交易供應商持有相關註冊。

## 決策驅動因素

- 避免因意外從事顧問、代客管理或資料再散布活動而招致刑事與民事責任。
- 保留讓日後提供服務成為可能的工程接縫（seams），但不主張任何我們尚未驗證的法律立場。
- 提供一個明確、可觀察的觸發條件，標示法律工作必須何時開始。
- 讓情境 1 的建置免於承擔自用所不需要的合規負擔。

## 考慮的選項

1. **僅供擁有者自有帳戶使用的自主交易軟體，並在出現任何第二位使用者之前設有強制性的法律關卡（觸發條件 T1）**，同時現在就建置低成本的接縫。
2. **從第一天起就以持牌服務為設計目標**（預先實作方案 C 的多租戶（tenancy）、權限授予（entitlements）與 OIDC）。
3. **不設明確立場**，等有使用者提出需求時再決定。

## 決策結果

**選定選項：1。** 它在情境 1 幾乎不增加成本，能防止那些罰則最重的意外越界，並透過接縫而非過早的平台化工作，保持演進路徑暢通。

### 立場（情境 1）

- 本平台是**自主交易軟體（self-directed software）**，**只交易擁有者自己的帳戶**，並使用擁有者自己的認證資訊。
- **範圍外：** 造市；低於 10 ms 的策略；保管任何他人的資產；販售訊號（收費頻道，或可能轉為收費的免費頻道）；跟單交易；管理他人資金；向其他任何人顯示受授權（licensed）的市場資料。
- 加密貨幣交易場所列於與金管會（FSC）登記名冊（日後則與 VASP Act 執照制度）連動的**設定式允許清單**上。交易場所是否適格屬於設定，而非程式碼。在任何永續合約或選擇權交易場所成為首個實盤候選之前，Phase 0 會依據金管會 AML 登記名單及該交易場所自身的地區限制條款進行檢查；若沒有任何一個符合資格，則以 IBKR 作為首個實盤市場。
- 資料使用遵循授權登錄表（licence registry）與 `license_tag`（[ADR-0009](ADR-0009-open-source-licensing-strategy.zh-TW.md)）。任何專業身分變更（例如透過公司實體交易）都會觸發資料方案的重新審查。將受授權資料傳送至第三方 LLM API，同樣是登錄表必須允許的用途（`llm_export_allowed`，[ADR-0017](ADR-0017-ai-trust-boundary.zh-TW.md)）。
- 稅務批次（tax-lot）引擎是可插拔、依司法管轄區區分的模組（[ADR-0016](ADR-0016-multi-currency-books-tax-lots-and-tax-plugins.zh-TW.md)）。美國洗售（wash-sale）追蹤只對美國納稅人有意義；台灣居民則使用台灣居民外掛模組（plug-in）。其報表僅為記帳輔助，並非稅務建議。

### 現在就建置的接縫（不附帶任何法律主張）

每個 schema 中的 `tenant_id` 與 `account_id`；行程內（in-process）下單閘道契約；`StrategyRuntime` 埠（port）；`license_tag` 登錄表；以及日後可能成為邊緣連接器的台灣閘道契約（[ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.zh-TW.md)）。

### 法律關卡（觸發條件 T1）

在出現**任何**第二位使用者、收費或免費的訊號散布、跟單交易或外部租戶之前，以下各項必須全部到位：

1. 針對每個目標司法管轄區的**書面法律審查**（台灣金管會證券與期貨顧問執照及 VASP Act；美國 RIA/CTA/broker-dealer；於相關時涵蓋歐盟 MiCA）、券商條款（第三方授權、憑證、IBKR 供應商規則），以及市場資料散布協議。
2. **法律顧問的簽核**，並記錄為取代或修訂本 ADR 的新 ADR。
3. **在此之後才**進行平台增量：行程外（out-of-process）下單閘道、多租戶、OIDC 與 WebAuthn、權限授予，以及受授權資料散布（[主報告](../../README.zh-TW.md)中的 Phase 4–5 預算）。

**反向觸發條件 R1。** 若建置該增量後約 12 個月內未出現外部使用者，或法律審查結果為否定，則退回精簡設計。

### 後果

**正面**

- 只要平台依預期方式使用，就不會有執照方面的曝險。
- 法律工作必須開始的時間點明確且可觀察。
- 接縫保留了提供服務的路徑，而不必提早負擔平台的營運成本。

**負面**

- 可能有用的活動（與朋友分享訊號、公開的儀表板）在法律審查完成前都會受阻。
- 若想提供服務，仍需付出一項法律專案加上平台工作的成本：團隊平台（Phase 4）約 40–60 人月（PM），對外服務（Phase 5）再加約 60–70 人月。接縫減少的是重工，而非這筆成本。
- 此立場仰賴擁有者的自律。軟體無法偵測每一種範圍外的使用。

### 確認

- 每一筆限額、晉級（promotion）與部署紀錄都帶有 `tenant_id = 'self'`。在 T1 ADR 存在之前，任何其他值都會導致 CI 與執行期檢查失敗。
- API 僅能由擁有者的裝置透過 Tailscale 存取。開放任何公開端點或第二個使用者帳號，都需要 T1 ADR。
- 年度審查會重新核實各項監理日期（VASP Act 生效日、FINRA 分階段導入結束日、台灣稅務規定到期日）。

### 何時重新檢視

- **T1** 觸發（第二位使用者、收費訊號、跟單交易或任何外部租戶）。
- **T10：** 規劃桌面版或自架（self-hosted）產品，這會同時帶來授權（LGPL）以及可能的監理問題。
- 法規變動：VASP Act 的生效日與執照制度、FINRA 規則變更，或台灣券商 API 條款。

## 連結

- [主報告：監理提醒、範圍外清單、觸發條件 T1 與 R1，以及台灣優先 vs 美國／加密貨幣比較表](../../README.zh-TW.md)
- [建議架構 §9（情境 2 目標）](../../architecture/recommended-architecture.zh-TW.md)
- [評估紀錄：嫁接項（grafts）21、22、23 與 25；疑慮 4、22、23 與 24](../../architecture/evaluation.zh-TW.md)
- [方案 C：監理立場與邊緣連接器](../../architecture/proposal-C-platform-scale.zh-TW.md)
- 研究：[08 風險、安全、維運與合規](../../research/08-risk-security-ops-compliance.zh-TW.md) · [11 台灣在地化](../../research/11-taiwan-market-localization.zh-TW.md) · [03 資料授權](../../research/03-market-data-storage.zh-TW.md) · [04 券商條款](../../research/04-broker-exchange-connectivity.zh-TW.md)
- 相關 ADR：[ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.zh-TW.md) · [ADR-0008](ADR-0008-key-and-secret-management.zh-TW.md) · [ADR-0009](ADR-0009-open-source-licensing-strategy.zh-TW.md) · [ADR-0016](ADR-0016-multi-currency-books-tax-lots-and-tax-plugins.zh-TW.md) · [ADR-0017](ADR-0017-ai-trust-boundary.zh-TW.md)
