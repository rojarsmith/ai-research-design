[English](ADR-0008-key-and-secret-management.md) | **繁體中文**

# ADR-0008：金鑰與機密管理

## 狀態

**提議中（Proposed）** · 2026-10-05 · 範圍：情境 1，以及情境 2 改用 OpenBao 的遷移。本 ADR 解決了台灣 `.pfx` 憑證掛載位置的不一致問題（見 *背景與問題陳述*）。

## 背景與問題陳述

認證資訊（credentials）是交易系統最核心的資產。被竊的交易金鑰可能造成資金損失；被竊的提領金鑰可能讓一切化為烏有。2025 年 Bybit 遭竊案（約 15 億美元）是透過簽署 UI 得手的，而 npm「Shai-Hulud」蠕蟲（2025 年 9 月與 11 月）則透過相依套件竊取認證資訊（[08](../../research/08-risk-security-ops-compliance.zh-TW.md)）。機密要存放在哪裡、誰能讀取，以及如何輪替？

情境 1 中的機密：

| 機密 | 使用方 | 備註 |
|---|---|---|
| 加密貨幣交易場所 API 金鑰（HMAC、Ed25519，或 Coinbase 使用的 ES256） | `node-<account>`、`killswitch` | 可限定為僅限交易、停用提領並綁定 IP |
| IBKR 使用者名稱、密碼與 IBC 設定 | `ib-gateway` | 由人工核准週期性的 2FA 推播。IBKR 沒有僅限交易的 API 金鑰 |
| 台灣 CA 憑證（`.pfx`）及其密碼，加上 Shioaji API key 與 secret | `shioaji-sidecar`、`killswitch` | 此憑證為**個人**憑證（與持有人的身分證字號綁定），無法集中共用。Shioaji 金鑰具備權限範圍、到期日與 IP 白名單。Shioaji 每個身分證字號允許 5 個同時連線的工作階段 |
| 資料庫角色、Telegram bot token、S3 匯出認證資訊、Tailscale auth key | `journal`、`api`、`scheduler`、主機 | — |
| 桌面 API token（Phase 3 Tauri 殼層） | 用戶端 | 絕不是交易場所金鑰 |
| AI 專用範圍的 API token | AI 工具（研究助理、程式撰寫代理、LLM 訊號產生器） | 僅能讀取資料與建立提案；沒有下單、核准、控制、限額或升級（promotion）權限；絕不儲存在交易主機上（[ADR-0017](ADR-0017-ai-trust-boundary.zh-TW.md)） |

**來源文件中的不一致（已於 2026-10-05 更正）。**

- [主報告](../../README.zh-TW.md)（資安列）、[建議架構](../../architecture/recommended-architecture.zh-TW.md) §2（「唯一掛載 `.pfx` 的容器」）以及 §8.4 上線檢查清單，都寫著 `.pfx` **只**掛載到 Shioaji sidecar。
- 然而 §3.5 與 §3.12 卻讓 kill switch（緊急停止開關）擁有自己的 Shioaji 工作階段（「kill switch 容器中的 Shioaji 用戶端」；「只掛載到 `shioaji-sidecar`（以及 kill switch 的 Shioaji 用戶端）」）。一個會下單或撤單的 Shioaji 工作階段需要該憑證。
- README 與 §2 也寫著 kill switch 擁有「自己的認證資訊」。但就 IBKR 而言，它實際上共用 IB Gateway 的登入（§3.5），而第二個 IBKR 使用者名稱能否提供獨立的工作階段，仍是 Phase 0 的待解問題。
- 在 §7 的分拆拓撲中，kill switch 執行於東京，而台灣券商的金鑰卻綁定在住家或台北的 IP 上。

2026-10-05 時的機密儲存方案選項：

- 作業系統鑰匙圈；
- SOPS + age（免費）；
- OpenBao 2.7.1（MPL-2.0，Linux Foundation）；
- HashiCorp Vault 2.1（BSL 1.1，IBM；允許內部使用）；
- AWS Secrets Manager（每個機密每月 0.40 美元）；
- Infisical（MIT 授權核心，另有付費功能）。

## 決策驅動因素

- 最小權限：每個容器只看得到它所需要的機密。
- 單一操作者無需額外維運任何服務。
- 交易場所金鑰絕不會進入網頁、行動或桌面用戶端。
- 即使節點卡死，緊急路徑（kill switch）仍能運作。
- 可稽核的輪替與到期追蹤。
- 當團隊或租戶加入時，能乾淨地升級到具備稽核軌跡的 vault。

## 考慮的選項

1. **以 SOPS + age 加密的檔案存放於 git，只在交易主機上解密，並以 Docker secrets 逐容器掛載**，搭配嚴格的金鑰政策。
2. **從第一天起就自行架設 OpenBao（或 Vault）。**
3. **雲端機密管理服務**（AWS Secrets Manager 加 KMS）。
4. 主機上的**純 `.env` 檔案**。
5. **僅使用作業系統鑰匙圈**（以桌面為中心）。

## 決策結果

**選定選項：1，「SOPS + age 搭配逐容器掛載」**，並加上下列金鑰衛生規則。它不需要額外維運任何服務，在 git 中保留可稽核的歷史紀錄，並提供逐容器的最小權限。OpenBao 是情境 2 的目標方案。

### 儲存與分發

- 機密以 SOPS 加密的 YAML 存放於 `config/secrets/`。age 的接收者（recipients）為交易主機的金鑰，加上一把離線復原金鑰。這兩把私鑰都不存在於建置機器或 CI 上。
- 部署時，機密在交易主機上解密，並以**唯讀的 Compose secrets**（位於 `/run/secrets` 下的檔案）掛載到需要它們的容器中。機密不以環境變數傳遞，因為環境變數會洩漏到 `docker inspect` 輸出、日誌與當機傾印（crash dump）中。
- PostgreSQL 角色遵循最小權限：journal 寫入者只能對 `ledger_event` 執行 `INSERT`，而 API 則讀取投影（projections）。

### 台灣憑證（解決不一致問題）

- `.pfx` 及其密碼**只掛載到兩個容器：`shioaji-sidecar` 與 `killswitch`**。它們絕不會掛載到節點、API 或映像檔中，絕不以明文存放於 git，也絕不會出現在任何用戶端。
- kill switch 開啟自己的 Shioaji 工作階段（每個身分證字號允許的五個工作階段之一）。
- **修訂（已於 2026-10-05 套用）：** README 資安列、§2、§3.12 與 §8.4 檢查清單現在都寫著「只掛載到 Shioaji sidecar 與 kill switch 容器」，且 README 與 §2 在描述 kill switch 之處都註明了 IBKR 的例外說明。
- 在分拆拓撲中，kill switch **每個站點執行一個實例**。台灣與 IBKR 路徑執行於其固定 IP 位於券商白名單上的主機（[ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.zh-TW.md)）。

### 交易場所金鑰政策

| 規則 | 細節 |
|---|---|
| 權限 | 僅限交易與讀取。所有地方都停用提領。系統絕不持有具提領能力的金鑰 |
| 綁定 | 綁定主機的固定對外 IP。若有提供則使用 Ed25519（例如 Binance）；Coinbase 使用 ES256 |
| 粒度 | 每個策略或子帳戶各一把金鑰。kill switch 在每個加密貨幣（子）帳戶上都擁有**自己獨立的僅限交易金鑰** |
| IBKR 例外說明 | IBKR 沒有僅限交易的 API 金鑰。kill switch 透過共用的 IB Gateway 登入，使用自己的 TWS API 用戶端工作階段，因此在 Phase 0 驗證第二個使用者名稱之前，「自己的認證資訊」對 IBKR 並不成立。runbook 中以 IBKR 行動 App 或網頁用戶端作為人工的最後手段 |
| 輪替 | 每 90 天以及任何資安事件後輪替。scheduler 會在 `.pfx` 到期、API 金鑰到期與輪替日期前 30 天發出警示 |
| 事件處理順序 | **先取消掛單中的委託，再撤銷金鑰。** 撤銷金鑰並不會取消掛單中的委託 |
| 帳戶 | 每個券商、交易所、雲端、GitHub 與套件登錄庫（package registry）帳戶都使用 FIDO2 硬體金鑰 |
| 加密貨幣保管 | 只有營運資金留在交易場所上。庫存資金（treasury）留在冷儲存。提領地址白名單使用時間鎖 |

### 用戶端與供應鏈

- 網頁、PWA 與 Telegram 用戶端不持有任何交易場所金鑰。它們透過 Tailscale，以綁定裝置的 token 向 API 進行驗證；Phase 3 的 Tauri 殼層將其 token 儲存在作業系統鑰匙圈中。
- 以雜湊值釘選的 lockfile（`uv.lock`、npm lockfile）；採用新版本前延遲 3–7 天；建置機器與持有金鑰的機器分開；從 Phase 2 起提供 SBOM。
- 日誌會遮蔽機密，且機密絕不出現在 URL 或查詢字串中。

### 情境 2

- **OpenBao 2.7**（MPL-2.0），搭配雲端 KMS 根金鑰、稽核裝置（audit devices）、動態資料庫認證資訊、自動輪替與逐租戶的政策。
- 在對外提供的服務中，個人的台灣憑證保留在客戶自行託管的邊緣連接器（edge connector）上，絕不放在我們的伺服器上。
- HashiCorp Vault（BSL 1.1）用於內部使用是可接受的，但並未選用，因為 OpenBao 在沒有使用限制的授權下提供相同的 API。對於完全託管於雲端的部署，雲端機密管理服務是另一種選擇。

### 影響

**正面**

- 在情境 1 中，不需要執行、備份或解封（unseal）任何機密儲存服務。
- 每一次機密變更都是一個經加密、可審查的 git commit。
- API、UI 或節點遭入侵時，不會暴露台灣憑證。
- 節點卡死時 kill switch 仍能持續運作，因為它持有自己的加密貨幣金鑰與自己的 Shioaji 工作階段。

**負面**

- 機密是靜態的，輪替需人工進行（搭配 scheduler 提醒），而且與 OpenBao 不同，沒有逐次讀取的稽核軌跡。
- 交易主機的 age 金鑰是高價值目標。主機遭入侵會暴露所有機密，因此主機必須專用且經過強化。
- 現在有兩個容器持有 `.pfx`，而不是一個。
- 就 IBKR 而言，在驗證第二個使用者名稱之前，kill switch 並不獨立於 IB Gateway。

### 確認

- 上線檢查清單會驗證每個交易場所的金鑰權限範圍（僅限交易、停用提領、綁定 IP）、每個帳戶都啟用 FIDO2，以及 `.pfx` 只出現在上述兩個指定的容器中。
- 每次合併時執行 CI 機密掃描器。若機密透過 `environment:` 傳遞，Compose lint 會判定失敗。
- 在 Phase 2 結束前，輪替與到期警示須在測試中成功觸發。

### 重新檢視時機

- **T1 或 T2：** 出現團隊、租戶或多台主機 → 改用以雲端 KMS 為基礎的 OpenBao。
- Phase 0 證實第二個 IBKR 使用者名稱能提供不依賴 gateway 的工作階段 → 給予 kill switch 自己的 IBKR 登入。
- 若曾考慮讓桌面殼層直接從桌面端交易 → 金鑰只在交易核心程序中解密，絕不在 webview 中解密。目前並無此規劃。

## 連結

- [主報告：資安列、法規提醒與風險](../../README.zh-TW.md)
- [建議架構 §2、§3.5、§3.12、§7 與 §8.4](../../architecture/recommended-architecture.zh-TW.md)
- [評估紀錄：關注事項 3 與 7](../../architecture/evaluation.zh-TW.md)
- 研究：[08 風險、資安、維運與合規](../../research/08-risk-security-ops-compliance.zh-TW.md) · [04 券商連線](../../research/04-broker-exchange-connectivity.zh-TW.md) · [11 台灣在地化](../../research/11-taiwan-market-localization.zh-TW.md)
- 相關 ADR：[ADR-0005](ADR-0005-messaging-and-deployment-topology.zh-TW.md) · [ADR-0006](ADR-0006-broker-connectivity-and-gateway-contract.zh-TW.md) · [ADR-0013](ADR-0013-risk-gate-and-three-path-kill-switch.zh-TW.md) · [ADR-0015](ADR-0015-self-use-regulatory-posture-and-legal-gate.zh-TW.md)
