[English](ADR-0009-open-source-licensing-strategy.md) | **繁體中文**

# ADR-0009：開源授權策略：保留商業化的選擇空間

## 狀態

**提議中（Proposed）** · 2026-10-05 · 範圍：所有情境。本文件為工程政策，並非法律意見；標記為 *法律顧問（counsel）* 的項目，在任何對外提供或散布之前都需經過法律審查。

## 背景與問題陳述

本平台起初僅供自用，但日後可能成為提供給他人的服務（觸發條件 T1），或成為桌面版或自架（self-hosted）產品（觸發條件 T10）。對這些選項而言，相依套件與資料的授權所造成的限制比技術本身更大（[03](../../research/03-market-data-storage.zh-TW.md)、[10](../../research/10-open-source-platforms-build-vs-buy.zh-TW.md)）。我們可以相依於哪些授權、可以用在系統的哪些部分，才能確保商業化永遠不會迫使我們重寫？

截至 2026-10-05 的事實：

| 授權類別 | 我們技術堆疊中或周邊的例子 | 義務的觸發條件 |
|---|---|---|
| 寬鬆型（Permissive） | MIT、BSD、Apache-2.0：CCXT、ib_async（BSD-2）、Rust `ibapi` crate（MIT）、Polars、DuckDB、Valkey（BSD）、NATS、PostgreSQL、QuantLib（BSD 風格）、MLflow、LEAN、Lightweight Charts（Apache-2.0，**必須標示出處（attribution）**）、uPlot、ECharts、AG Grid Community、KLineChart、Tauri | 授權聲明與出處標示 |
| 弱 copyleft（檔案層級） | MPL-2.0：OpenBao | 若散布，經修改的 MPL 檔案必須公開分享 |
| LGPL | **NautilusTrader v2（LGPL-3.0-only；** v1.x 為 LGPL-3.0-or-later） | **散布。** 無網路條款。其 wheel 以靜態方式連結 Rust crate，因此已散布之二進位檔的重新連結（relinking）義務屬於法律問題（*法律顧問*） |
| GPL | IBKR TWS API 用戶端 10.49+（自 2026-08-03 起）、Freqtrade、backtrader、Lumibot、FinancePy、Qt Graphs | 散布衍生著作 |
| AGPL | Grafana、Loki、Tempo；Redis 8（其三種授權之一）；Backtesting.py；OpenBB 4.2–4.7.x | **透過網路使用修改後的版本** |
| Commons Clause | vectorbt（開源版） | 禁止販售該軟體或以其為基礎的服務 |
| 原始碼可得（source-available，BSL 及類似授權） | HashiCorp Vault、immudb、Redpanda、lakeFS v1.87+、ArcticDB（任何商業用途都需簽訂協議）、KurrentDB、TimescaleDB TSL；Redis 8 RSAL/SSPL | 依授權而定：將產品本身作為服務提供，或商業使用 |
| 專有 SDK、EULA 與條款 | Shioaji、Fubon Neo、Capital SKCOM、IB Gateway、StockSharp（自 2026-07-16 起改為專有）、TradingView Advanced Charts（僅限公司）、vectorbt PRO（個人、非商業）、Nautilus Pro（已宣布） | 依各廠商條款 |
| 非商業，或任何商業用途皆須付費 | Rateslib（任何商業用途每位使用者每年 £251，即使僅作為驗證工具亦然）；TimesFM 3.0 與 Moirai 2.0 模型權重 | 任何商業用途 |
| 資料授權 | Massive 與 ThetaData 個人使用方案；FinMind 資料（教育／非商業）；券商行情源（不得再散布）；TWSE 資訊再散布（每月 NT$60,000，另加每月 NT$100,000 網際網路傳輸費用）；IBKR 禁止再散布 TWS API 資料 | 向他人顯示、專業用途、再散布 |

授權也會變動（drift）。OpenBB 從 MIT → AGPL-3.0（2024-05）→ Apache-2.0（v5.0.0，2026-09-29）。StockSharp 則從 Apache-2.0 → 專有。

## 決策驅動因素

- 現在的自用不得阻礙日後的服務（T1）或散布型產品（T10）。
- 在授權無害之處保留最好的工具（例如在伺服器上使用 LGPL 的 NautilusTrader）。
- 讓違規在機制上無法被合併，而不只是不鼓勵。
- 將資料授權視為一等公民，因為它們對設計的限制最大。
- 讓這套政策的成本低到一個人就能運作。

## 考慮的選項

1. **依散布情境分層的政策**：引擎留在伺服器端；任何可散布的內容都不含 LGPL、GPL、AGPL 或 Commons Clause 程式碼；在 CI 中執行 SPDX 授權掃描；每個資料集都帶有 `license_tag`。
2. **全面僅用寬鬆授權**，這意味著現在就捨棄 NautilusTrader，改用 LEAN 或自有核心。
3. **商業化之前不設任何政策**，屆時再審查。
4. **以強 copyleft 授權釋出我們的平台**（例如 AGPL），讓引入的 copyleft 元件不再構成問題。

## 決策結果

**選定選項：1，「依散布情境分層的政策」。** 它保留了 NautilusTrader：LGPL 沒有網路條款，在我們的伺服器上無害。它只在 copyleft 真正會造成影響之處（散布出去的成品）禁止 copyleft，並以機械化方式強制執行此規則。

### 政策矩陣

| 授權類別 | 伺服器端、內部（情境 1 與 2） | 對他人提供的網路服務（T1） | 散布出去的成品：桌面或行動 App、自架套件包、客戶端邊緣連接器 |
|---|---|---|---|
| 寬鬆型、MPL-2.0 | 允許 | 允許 | 允許，須附授權聲明與出處標示 |
| LGPL（NautilusTrader） | 允許；保持不修改，修正回饋上游 | 允許（無網路條款） | 未經法律審查一律**禁止**（T10） |
| GPL | 僅限作為獨立、不連結的工具（例如以 FinancePy 作為內部測試基準（test oracle））。絕不連結 IBKR 的 GPL 用戶端 | 同內部 | **禁止** |
| AGPL | Grafana、Loki 與 Tempo **不修改**，僅供我們自己的維運使用。不使用 Redis 8、Backtesting.py 與 OpenBB 4.2–4.7.x | 絕不向外部使用者公開**修改過的** AGPL 服務 | **禁止** |
| Commons Clause | vectorbt 僅限內部研究 | **禁止** | **禁止** |
| BSL 與原始碼可得 | 優先選擇寬鬆授權的替代方案：以 OpenBao 取代 Vault、以 PostgreSQL 雜湊鏈取代 immudb、以 NATS 取代 Redpanda、以 Parquet 搭配 DuckLake 或 Iceberg 取代 ArcticDB。若計畫提供服務，避免使用 lakeFS v1.87+ | 避免 | **禁止** |
| 專有 SDK 與 EULA | 依廠商條款，僅供自用 | 僅在廠商核准下（IBKR 第三方 OAuth 1.0a 需經合規審查；券商條款禁止授權第三方存取） | 僅在取得廠商書面同意下。邊緣連接器未經同意不得綁入券商 SDK（*法律顧問*） |
| 非商業或商業付費 | 排除 Rateslib；排除 TimesFM 3.0 與 Moirai 2.0 權重；vectorbt PRO 僅限個人使用 | 排除 | 排除 |

### 規則

1. **引擎留在伺服器端。** 用戶端保持精簡（[ADR-0007](ADR-0007-web-first-client-and-charting-stack.zh-TW.md)）。
2. **任何可散布的內容都不含 LGPL、GPL、AGPL 或 Commons Clause 程式碼**（主報告的設計原則 11）。若引擎本身必須隨產品發行（T10），則在授權審查後改用 LEAN（Apache-2.0）或提案 B 的自有核心。
3. **IBKR：** 使用 NautilusTrader 以 MIT 授權的 `ibapi` crate 與 ib_async（BSD-2）。IB Gateway 以廠商軟體的形式執行。
4. **每次合併都執行 SPDX 授權掃描**（Python、npm、容器映像檔；若日後出現 Rust 程式碼則使用 `cargo-deny`）。允許清單與拒絕清單存放在儲存庫中，並記錄每個鎖定版本的授權，因此授權變動會以 diff 的形式呈現。
5. **資料：** 每個資料集與 row group 都帶有 `license_tag`，並對照 `data/licence-registry.yaml` 解析（條款、允許用途、顯示或非顯示用途、專業身分、再散布，以及 `llm_export_allowed`，即是否允許將資料傳送至第三方 LLM API，[ADR-0017](ADR-0017-ai-trust-boundary.zh-TW.md)）。預設禁止再散布與 LLM 匯出。透過公司實體交易可能使我們被歸類為專業訂閱者，因此需重新檢查各方案。權限管理（entitlement）服務於 T1 時導入。
6. **出處標示：** UI 套件包隨附 NOTICE 檔案，且 TradingView 的出處標示保持可見。
7. **我們自己的程式碼：** 其對外授權**不在本 ADR 決定**。在情境 1 中儲存庫保持私有，並於 T1 或 T10 時與法律顧問共同做出選擇。

### 影響

**正面**

- 我們保留 NautilusTrader 帶來的上市速度，同時不關上提供服務或推出產品的大門。
- 授權違規會讓 CI 失敗，而不是到盡職調查（due diligence）時才浮現。
- 每個資料集上都能看到資料授權的限制，而這本來就是任何對外產品都需要的。
- 授權變動（OpenBB、StockSharp）會在升級時被攔截。

**負面**

- 必須包含引擎的散布型產品（T10）仍意味著要更換引擎。`StrategyRuntime` 埠（port）能將此工作控制在數週內，但並非沒有成本。
- 允許清單與登錄表需要維護，而且部分授權含糊不清（Lumibot 的 LICENSE 檔案寫的是 GPL-3.0，README 卻寫 MIT），因此必須人工審查。
- 有用的工具被隔離在外：vectorbt 不能用來支撐付費服務，Rateslib 則完全被排除。
- 在法律顧問審查之前，有幾個問題仍懸而未決：LGPL 靜態連結、券商 SDK 的再散布，以及邊緣連接器的法律依據。

### 確認

- SPDX 掃描與拒絕清單為每一次合併把關（建議架構 §8.1，「授權與供應鏈」）。
- 上線檢查清單要求：策略所讀取的每個資料集，都必須在授權登錄表中有允許該用途的項目。
- 在 T1 或 T10 之前：完成涵蓋政策矩陣每一列的書面授權審查，並取得法律顧問簽核（[ADR-0015](ADR-0015-self-use-regulatory-posture-and-legal-gate.zh-TW.md)）。

### 重新檢視時機

- **T1：** 對外提供服務 → 權限管理、散布用途的資料授權、對所有對外公開的部分進行 AGPL 稽核。
- **T10：** 桌面版或自架產品必須隨附引擎 → 不含 LGPL 的核心。
- 某個相依套件變更授權或推出付費方案（例如 Nautilus Pro 的功能從開源版移出）→ T6 審查。

## 連結

- [主報告：設計原則 11、成本排除項目與資料授權風險](../../README.zh-TW.md)
- [建議架構 §4.1（授權）、§8.1 與 §9](../../architecture/recommended-architecture.zh-TW.md)
- [評估紀錄：嫁接項 22 與 26；疑慮 4、21、23 與 26；§4.3 中的 Rateslib 與 lakeFS](../../architecture/evaluation.zh-TW.md)
- 研究：[10 自建或採購](../../research/10-open-source-platforms-build-vs-buy.zh-TW.md) · [03 市場資料儲存](../../research/03-market-data-storage.zh-TW.md) · [04 券商連線](../../research/04-broker-exchange-connectivity.zh-TW.md) · [06 用戶端 UI](../../research/06-cross-platform-client-ui.zh-TW.md) · [07 訊息傳遞](../../research/07-system-architecture-messaging.zh-TW.md) · [08 安全與合規](../../research/08-risk-security-ops-compliance.zh-TW.md) · [09 研究與 ML](../../research/09-research-ml-analytics.zh-TW.md)
- 相關 ADR：[ADR-0002](ADR-0002-extend-nautilustrader-as-backtest-engine.zh-TW.md) · [ADR-0004](ADR-0004-parquet-lake-for-historical-data.zh-TW.md) · [ADR-0007](ADR-0007-web-first-client-and-charting-stack.zh-TW.md) · [ADR-0015](ADR-0015-self-use-regulatory-posture-and-legal-gate.zh-TW.md)
