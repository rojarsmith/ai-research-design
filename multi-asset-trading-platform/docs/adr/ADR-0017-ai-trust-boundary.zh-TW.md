[English](ADR-0017-ai-trust-boundary.md) | **繁體中文**

# ADR-0017：AI 信任邊界：僅限提案、範圍限定的 token、隔離與稽核

## 狀態

**提議中（Proposed）** · 2026-10-05 · 範圍：情境 1 與 2。此決策自第一個接觸平台的 AI 工具起即適用，而不僅限於觸發條件 T11（自動化策略探勘）觸發之時。

## 背景與問題陳述

AI 工具將被用於撰寫程式、研究，並可能用於產生訊號。研究 [09](../../research/09-research-ml-analytics.zh-TW.md) 列出了它稱為不可妥協的防護措施（guardrails），但已採用的設計只沿用了其中一部分（[ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.zh-TW.md)：唯讀的 MCP 工具、AI 撰寫的程式碼在沙箱中執行、券商 MCP 伺服器僅限模擬交易（paper））。缺少的是那些防止 AI 工具動用資金或洩漏機密的規則。

影響因素：

- **代理程式的行為超出範圍。** 2026 年的 FINRA 報告警告，代理程式可能會「超出使用者實際或預期的範圍」行事；OWASP LLM01:2025 則要求遵循最小權限原則，並在特權操作中保留人工介入（human in the loop）。
- **提示注入（prompt injection）。** 助理所讀取的新聞、申報文件與網頁都可能夾帶指令。遭工具投毒（tool-poisoned）或惡意的 MCP 伺服器則是相關的風險。
- **機密。** 位於交易主機上的程式撰寫代理程式（coding agent）可能讀取 `/run/secrets`、age 金鑰或 Telegram bot token。部分券商 MCP 伺服器能夠下實盤委託（Alpaca MCP 伺服器預設為模擬交易，但具備交易工具組）。
- **授權條款。** 將受授權的市場資料傳送給第三方 LLM API，可能違反資料授權條款。
- **如今已有落腳之處。** 半自動化交易加入了需經人工核准的提案機制（[建議架構](../../architecture/recommended-architecture.zh-TW.md) §3.13），因此 AI 的輸出有了一個安全且可稽核的去處。

## 決策驅動因素

- 任何 AI 工具都不得直接或間接地下單、核准或修改委託，或變更限額。
- 任何 AI 工具都不得讀取機密或連線至交易場所（venue）。
- 每一個可能影響交易的 AI 行為都可歸屬且可稽核。
- 受授權的資料在未經許可的情況下，絕不外流至第三方模型。
- 對單人而言執行成本低（若使用 AI 工具，於 Phase 2a 約需 0.15 PM（人月））。

## 考慮的選項

1. **硬性信任邊界：** AI 輸出僅能成為提案，並搭配範圍限定的 token、網路隔離、不接觸機密、稽核日誌與授權條款檢查。
2. **僅限唯讀 AI：** 完全不提供提案。
3. **在小額風險限額內的自主 AI 交易。**
4. **不使用 AI 工具。**

## 決策結果

**選定選項：1。** 它保留了 AI 有用的部分（研究、程式碼、交易構想），並在模型與市場之間設置了人員以及同一道風控閘門（risk gate）。選項 2 浪費了原本就存在的核准佇列；選項 3 違背研究 09 以及 FINRA 與 OWASP 的指引；選項 4 則沒有必要。

### 規則與執行機制

| 規則 | 執行機制 |
|---|---|
| **僅限提案。** 建議交易的 LLM 輸出會成為一筆 `TradeProposal`，附帶 `proposer = AI` 與追蹤 ID（trace ID）；它會經過 `tp_risk` 與人工核准佇列。AI 提案沒有自動核准 | API 僅接受來自 AI 範圍 token 的 AI 提案，並加以標記；核准端點拒絕來自 AI 範圍 token 的核准；CI 測試涵蓋這兩者 |
| **範圍限定的 token。** AI 工具取得的 token 僅具備讀取範圍（市場資料、研究結果，以及在擁有者允許時的部位）與 `proposals:create` | API 中的範圍檢查。CI 測試斷言 AI 範圍 token 呼叫 `POST /v1/orders`、提案核准、`/v1/control/*`、`PUT /v1/limits/*` 與 `/v1/promotions/*` 時會得到 HTTP 403 |
| **不得使用控制通道。** AI 工具不能使用 Telegram 或 ntfy 的控制命令 | bot token 絕不掛載至任何 AI 容器；bot 只接受來自擁有者 chat ID 且附帶 PIN 的命令 |
| **不接觸機密。** 任何 AI 容器中都不得有 `/run/secrets`、SOPS 檔案、age 金鑰或交易場所金鑰 | 若有 AI 服務掛載機密，Compose lint 即判定失敗；每次合併時都會執行機密掃描器 |
| **持有金鑰的主機上不得執行程式撰寫代理程式。** | 程式撰寫代理程式在工作站或獨立的建置 VM 上執行（[ADR-0008](ADR-0008-key-and-secret-management.zh-TW.md)：建置機器與持有金鑰的機器彼此分離） |
| **網路隔離。** AI 服務位於獨立的 Docker 網路（程式撰寫代理程式則另有獨立主機），只能連線至唯讀 MCP 伺服器、提案端點，以及允許清單中的 LLM API | Compose 網路定義加上主機防火牆規則；沒有通往交易場所、IB Gateway、Shioaji sidecar、Valkey 控制串流或 PostgreSQL 寫入角色的路由；CI 中的網路測試 |
| **不受信任的輸入。** 新聞、申報文件與網頁文字都被視為提示注入的媒介 | 檢索工具與動作工具分離；檢索到的文字在提示中標示為不受信任；任何 AI 工具唯一能執行的動作是建立提案，而提案由人員審查 |
| **稽核。** 每一個提示、工具呼叫、輸出及其所產生的提案都會被記錄 | MLflow 追蹤（tracing）加上僅可附加（append-only）的日誌；提案附帶追蹤 ID；帳本事件會記錄提案的建立及其結果 |
| **受授權的資料。** 授權登錄表中的每個 `license_tag` 都有一個 `llm_export_allowed` 旗標（預設為 false） | 內部 MCP 伺服器在回傳要送往第三方 LLM API 的資料之前，會先檢查此旗標；本地託管的模型則另行記錄 |
| **券商 MCP 伺服器僅限模擬交易。** | 實盤憑證絕不載入 LLM 用戶端；若有提供，則使用僅含資料的工具組 |
| **MCP 供應鏈。** | MCP 伺服器只取自已固定版本（pinned）且經審查的來源，並在沙箱中執行；不做 token 傳遞（passthrough） |

### 後果

**正面**

- AI 工具即使遭到入侵或操縱，也無法動用資金、變更限額或讀取金鑰；最壞的情況是產生一個被人員否決的糟糕提案。
- 每一筆交易中 AI 的貢獻，都能從帳本一路追溯到提示。
- 資料搭配託管模型使用時，授權義務仍能得到遵守。

**負面**

- 人工核准使 AI 產生的交易變慢；對延遲敏感的 AI 訊號不在範圍內。
- 範圍、網路與稽核日誌都是需要額外維護的設定，而 `llm_export_allowed` 旗標需要逐一閱讀每份授權條款。
- 擁有者仍可能核准一個糟糕的提案；此邊界防範的是工具，而非判斷失誤。

### 確認

- CI：AI 範圍 token 的 403 測試、Compose 機密掛載 lint、網路可達性測試，以及核准拒絕測試。
- Phase 2a 結束時（若使用 AI 工具）：進行一次紅隊演練，在一則新聞中植入指令，試圖讓助理下單；結果最多只能是一個提案。
- 每季：審查稽核日誌樣本與 MCP 伺服器的版本固定（pins）。

### 重新檢視時機

- **T11：** 自動化因子探勘或 AI 產生的策略 → 另外加入全平台的試驗次數計算（trial counting）與沙箱執行（[ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.zh-TW.md)）。
- **T1 或 T2：** 採用具備每位使用者範圍的中央 MCP 閘道、AI 提案的四眼核准（提案者絕不能是核准者），以及每個租戶的資料使用權限（data entitlements）。
- 券商或交易所 API 推出專為代理程式設計的權限模型。

## 連結

- [主報告：安全性列、觸發條件 T11 與 AI 決策](../../README.zh-TW.md)
- [建議架構 §3.8、§3.10、§3.13 與 §3.14](../../architecture/recommended-architecture.zh-TW.md)
- 研究：[09 研究、ML 與分析（防護措施）](../../research/09-research-ml-analytics.zh-TW.md) · [08 安全性](../../research/08-risk-security-ops-compliance.zh-TW.md)
- 相關 ADR：[ADR-0008](ADR-0008-key-and-secret-management.zh-TW.md) · [ADR-0009](ADR-0009-open-source-licensing-strategy.zh-TW.md) · [ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.zh-TW.md) · [ADR-0014](ADR-0014-two-tier-backtesting-and-promotion-gates.zh-TW.md)
